export type CandidateAsset = {
  id: string;
  takenAt: Date;
  lat: number | null;
  lon: number | null;
  city?: string | null;
  country?: string | null;
  matchedHints: string[];
  matchedThemes: string[];
};

export type AssetCluster = {
  assetIds: string[];
  startsAt: Date;
  endsAt: Date;
  centerLat: number | null;
  centerLon: number | null;
  /** Most common non-null city across the cluster, if any. */
  city: string | null;
  country: string | null;
  hints: string[];
  themes: string[];
  /** Filled by scoreCluster(). */
  score: number;
};

export type ClusterOptions = {
  /** Max wall-clock gap (hours) between two neighbours in the same event. */
  epsHours: number;
  /** Max physical distance (km) between two GPS-tagged neighbours. */
  epsKm: number;
  /** A cluster must contain at least this many candidates. */
  minPoints: number;
};

export const DEFAULT_CLUSTER_OPTIONS: ClusterOptions = {
  epsHours: 48,
  epsKm: 100,
  minPoints: 4,
};

const EARTH_RADIUS_KM = 6371;

function haversineKm(
  a: { lat: number; lon: number },
  b: { lat: number; lon: number },
): number {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLon = toRad(b.lon - a.lon);
  const s =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.sqrt(s));
}

function isNeighbour(a: CandidateAsset, b: CandidateAsset, opts: ClusterOptions): boolean {
  const hours = Math.abs(a.takenAt.getTime() - b.takenAt.getTime()) / 3_600_000;
  if (hours > opts.epsHours) {
    return false;
  }
  if (a.lat != null && a.lon != null && b.lat != null && b.lon != null) {
    return haversineKm({ lat: a.lat, lon: a.lon }, { lat: b.lat, lon: b.lon }) <= opts.epsKm;
  }
  // No GPS on at least one side — fall back to time-only adjacency.
  return true;
}

function neighbours(idx: number, points: CandidateAsset[], opts: ClusterOptions): number[] {
  const result: number[] = [];
  for (let j = 0; j < points.length; j++) {
    if (j === idx) continue;
    if (isNeighbour(points[idx], points[j], opts)) {
      result.push(j);
    }
  }
  return result;
}

/**
 * DBSCAN over candidates. Two candidates are neighbours when within
 * `epsHours` time AND `epsKm` distance (when both have GPS).
 * Noise points are dropped — only proper clusters are returned.
 */
export function clusterEvents(
  candidates: CandidateAsset[],
  opts: ClusterOptions = DEFAULT_CLUSTER_OPTIONS,
): AssetCluster[] {
  const visited = new Array<boolean>(candidates.length).fill(false);
  const assignment = new Array<number>(candidates.length).fill(-1);
  let clusterId = 0;

  for (let i = 0; i < candidates.length; i++) {
    if (visited[i]) continue;
    visited[i] = true;
    const seeds = neighbours(i, candidates, opts);
    if (seeds.length + 1 < opts.minPoints) {
      continue;
    }
    assignment[i] = clusterId;
    const queue = [...seeds];
    while (queue.length > 0) {
      const j = queue.shift()!;
      if (!visited[j]) {
        visited[j] = true;
        const moreSeeds = neighbours(j, candidates, opts);
        if (moreSeeds.length + 1 >= opts.minPoints) {
          queue.push(...moreSeeds);
        }
      }
      if (assignment[j] === -1) {
        assignment[j] = clusterId;
      }
    }
    clusterId++;
  }

  const buckets: CandidateAsset[][] = Array.from({ length: clusterId }, () => []);
  for (let i = 0; i < candidates.length; i++) {
    if (assignment[i] !== -1) {
      buckets[assignment[i]].push(candidates[i]);
    }
  }

  return buckets.map((bucket) => summarise(bucket));
}

/** `primary` pins a single hint or theme as the cluster's lead identity
 *  (used by buildSegmentedClusters). Without it the cluster carries every
 *  matched tag aggregated from its members. */
function summarise(
  bucket: CandidateAsset[],
  primary?: { hint?: string; theme?: string },
): AssetCluster {
  const sorted = [...bucket].sort((a, b) => a.takenAt.getTime() - b.takenAt.getTime());
  const withGeo = bucket.filter((c) => c.lat != null && c.lon != null);
  const centerLat = withGeo.length
    ? withGeo.reduce((s, c) => s + (c.lat as number), 0) / withGeo.length
    : null;
  const centerLon = withGeo.length
    ? withGeo.reduce((s, c) => s + (c.lon as number), 0) / withGeo.length
    : null;

  // When a cluster is bucketed primarily by a hint or a theme, surface ONLY
  // that bucketing key as the cluster's identity. Otherwise the user's hint
  // (which tends to match a lot of photos) bleeds into every theme cluster
  // and overshadows the actual theme.
  const hints =
    primary?.hint != null
      ? [primary.hint]
      : primary?.theme != null
        ? []
        : unique(bucket.flatMap((c) => c.matchedHints));
  const themes =
    primary?.theme != null
      ? [primary.theme]
      : primary?.hint != null
        ? []
        : unique(bucket.flatMap((c) => c.matchedThemes));
  const city = mostCommon(bucket.map((c) => c.city ?? null));
  const country = mostCommon(bucket.map((c) => c.country ?? null));

  return {
    assetIds: sorted.map((c) => c.id),
    startsAt: sorted[0].takenAt,
    endsAt: sorted[sorted.length - 1].takenAt,
    centerLat,
    centerLon,
    city,
    country,
    hints,
    themes,
    score: 0,
  };
}

/**
 * Build clusters segmented by hint/theme first (so each topic becomes its own
 * memory), then fall back to time+geo DBSCAN for untagged candidates. Each
 * themed cluster is capped at `maxPerCluster` and members are taken by
 * recency-then-takenAt-asc to keep the slideshow chronological.
 *
 * Why not just DBSCAN on everything: time+geo groups *events* (a weekend
 * away), not *topics* (the beach photos vs the food photos). With many
 * candidates within the eps window, everything collapses into one cluster
 * regardless of theme.
 */
export function buildSegmentedClusters(
  candidates: CandidateAsset[],
  opts: ClusterOptions = DEFAULT_CLUSTER_OPTIONS,
  maxPerCluster = 30,
): AssetCluster[] {
  const clusters: AssetCluster[] = [];

  const byHint = bucketBy(candidates, (c) => c.matchedHints);
  for (const [hint, members] of byHint) {
    if (members.length < opts.minPoints) continue;
    clusters.push(summarise(takeMostRecent(members, maxPerCluster), { hint }));
  }

  const byTheme = bucketBy(candidates, (c) => c.matchedThemes);
  for (const [theme, members] of byTheme) {
    if (members.length < opts.minPoints) continue;
    clusters.push(summarise(takeMostRecent(members, maxPerCluster), { theme }));
  }

  // Untagged candidates (recency + anniversary fallbacks) → DBSCAN time+geo.
  const untagged = candidates.filter(
    (c) => c.matchedHints.length === 0 && c.matchedThemes.length === 0,
  );
  if (untagged.length >= opts.minPoints) {
    clusters.push(...clusterEvents(untagged, opts));
  }

  return clusters;
}

function bucketBy(
  candidates: CandidateAsset[],
  keys: (c: CandidateAsset) => string[],
): Map<string, CandidateAsset[]> {
  const out = new Map<string, CandidateAsset[]>();
  for (const c of candidates) {
    for (const key of keys(c)) {
      const list = out.get(key) ?? [];
      list.push(c);
      out.set(key, list);
    }
  }
  return out;
}

function takeMostRecent(members: CandidateAsset[], n: number): CandidateAsset[] {
  return [...members].sort((a, b) => b.takenAt.getTime() - a.takenAt.getTime()).slice(0, n);
}

/** Pick up to `n` assets evenly spaced through a cluster's time order. */
export function pickRepresentatives(cluster: AssetCluster, n: number): string[] {
  if (cluster.assetIds.length <= n) {
    return [...cluster.assetIds];
  }
  const step = (cluster.assetIds.length - 1) / (n - 1);
  const picks: string[] = [];
  for (let i = 0; i < n; i++) {
    picks.push(cluster.assetIds[Math.round(i * step)]);
  }
  return picks;
}

function unique(items: string[]): string[] {
  return [...new Set(items)];
}

function mostCommon(items: Array<string | null>): string | null {
  const counts = new Map<string, number>();
  for (const item of items) {
    if (item == null) continue;
    counts.set(item, (counts.get(item) ?? 0) + 1);
  }
  let best: string | null = null;
  let bestCount = 0;
  for (const [item, count] of counts) {
    if (count > bestCount) {
      bestCount = count;
      best = item;
    }
  }
  return best;
}

/**
 * Score a cluster for ranking. Higher = more interesting "memory candidate".
 *
 *  - size: log scale (more is better, with diminishing returns)
 *  - recency: exponential decay over ~90 days from the cluster end
 *  - signal: number of distinct hints + themes that surfaced this cluster
 *  - geo bonus: a cluster with GPS is more legible to the LLM (better stories)
 */
export function scoreCluster(cluster: AssetCluster, now: Date = new Date()): number {
  const sizeScore = Math.log1p(cluster.assetIds.length);
  const daysSince = (now.getTime() - cluster.endsAt.getTime()) / 86_400_000;
  const recencyScore = Math.exp(-Math.max(daysSince, 0) / 90);
  // Hints and themes weighted equally so the user's hint cluster doesn't
  // monopolise picks — we want themed variety.
  const signalScore = cluster.hints.length * 0.5 + cluster.themes.length * 0.5;
  const geoBonus = cluster.centerLat != null ? 0.5 : 0;
  return sizeScore + recencyScore + signalScore + geoBonus;
}

export function rankClusters(clusters: AssetCluster[], now?: Date): AssetCluster[] {
  return clusters
    .map((c) => ({ ...c, score: scoreCluster(c, now) }))
    .sort((a, b) => b.score - a.score);
}

/**
 * FIFO-cap the per-user recently-used asset ID buffer. New IDs go to the front,
 * old IDs drop off the back. Avoids the same photo appearing in back-to-back
 * AI memories.
 */
export function appendRecentlyUsed(
  prev: string[],
  newlyUsed: string[],
  cap = 500,
): string[] {
  const dedup = new Set(prev);
  const merged = [...newlyUsed.filter((id) => !dedup.has(id)), ...prev];
  return merged.slice(0, cap);
}
