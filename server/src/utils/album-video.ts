export type SlideshowOptions = {
  width: number;
  height: number;
  fps: number;
  perImageSeconds: number;
  transitionSeconds: number;
  /** Apply Ken-Burns-style zoom on each still. */
  kenBurns: boolean;
  /** Optional one-line overlay shown during the first segment. */
  title?: string;
  subtitle?: string;
  /** Path to a fontfile drawtext can find inside the container. */
  fontFile?: string;
  /** Path to an audio track to mix into the slideshow. Looped if shorter than
   *  the video, trimmed to fit, faded 1s in / 1s out at -3dB. */
  audioPath?: string;
  /** Linear gain multiplier applied to the audio (1.0 = unchanged). */
  audioVolume?: number;
  /** Integer seed used to pick xfade transitions deterministically. Same seed
   *  → same sequence; pass a hash of memoryId/clusterId for stable re-renders. */
  transitionSeed?: number;
  /** Explicit ordered list of xfade transition names. When set and length
   *  equals N-1, used verbatim. Otherwise we fall back to `pickTransition`
   *  driven by `transitionSeed`. */
  transitions?: string[];
};

/**
 * Tasteful subset of ffmpeg xfade transitions, annotated with a short
 * description and a set of mood/scenario tags so the LLM can choose by
 * intent ("warm, contemplative" → fadewhite, smoothup) rather than by
 * shuffle. The string keys (`name`) are the only thing ffmpeg sees.
 *
 * Scenario tag vocabulary the LLM is told to use:
 *   - scenic:        landscapes, slow pans, panoramic mood
 *   - warm:          family, intimate, golden-hour feeling
 *   - contemplative: reflective, quiet, meditative
 *   - nostalgic:     memory-album feel, soft handoff between moments
 *   - action:        sports, motion, kids running, bikes
 *   - energetic:     parties, celebrations, kinetic mood
 *   - playful:       whimsical, lighthearted
 *   - cinematic:     dramatic reveal or close
 *   - urban:         city, street, architectural
 *   - natural:       outdoors, hikes, forests, gardens
 */
export type TransitionEntry = {
  name: string;
  description: string;
  scenarios: ReadonlyArray<string>;
};

export const TRANSITION_POOL: ReadonlyArray<TransitionEntry> = [
  {
    name: 'fade',
    description: 'gentle cross-fade — the most universal calm transition',
    scenarios: ['scenic', 'warm', 'contemplative', 'nostalgic'],
  },
  {
    name: 'fadeblack',
    description: 'fade through black — cinematic chapter break',
    scenarios: ['contemplative', 'cinematic', 'nostalgic'],
  },
  {
    name: 'fadewhite',
    description: 'fade through white — bright, ethereal, golden-hour',
    scenarios: ['warm', 'scenic', 'contemplative'],
  },
  {
    name: 'dissolve',
    description: 'pixel dissolve — soft memory-album handoff',
    scenarios: ['nostalgic', 'warm', 'contemplative'],
  },
  {
    name: 'slideleft',
    description: 'incoming photo slides in from the right',
    scenarios: ['action', 'energetic', 'urban'],
  },
  {
    name: 'slideright',
    description: 'incoming photo slides in from the left',
    scenarios: ['action', 'energetic', 'urban'],
  },
  {
    name: 'slideup',
    description: 'incoming photo slides up — forward momentum',
    scenarios: ['action', 'energetic', 'playful'],
  },
  {
    name: 'slidedown',
    description: 'incoming photo slides down — descending mood',
    scenarios: ['contemplative', 'nostalgic'],
  },
  {
    name: 'smoothleft',
    description: 'softened horizontal slide — gentler than slideleft',
    scenarios: ['scenic', 'warm', 'natural'],
  },
  {
    name: 'smoothright',
    description: 'softened horizontal slide — gentler than slideright',
    scenarios: ['scenic', 'warm', 'natural'],
  },
  {
    name: 'smoothup',
    description: 'softened upward slide — graceful',
    scenarios: ['scenic', 'warm', 'natural', 'contemplative'],
  },
  {
    name: 'smoothdown',
    description: 'softened downward slide — graceful',
    scenarios: ['contemplative', 'nostalgic'],
  },
  {
    name: 'circleopen',
    description: 'circular iris opens to reveal — gentle, lens-like',
    scenarios: ['warm', 'cinematic', 'nostalgic'],
  },
  {
    name: 'circleclose',
    description: 'circular iris closes — dramatic chapter close',
    scenarios: ['cinematic', 'contemplative'],
  },
  {
    name: 'radial',
    description: 'sweeping radial wipe — kinetic and modern',
    scenarios: ['action', 'energetic', 'urban', 'playful'],
  },
  {
    name: 'wipeleft',
    description: 'hard wipe from right to left — punchy',
    scenarios: ['action', 'energetic', 'urban'],
  },
  {
    name: 'wiperight',
    description: 'hard wipe from left to right — punchy',
    scenarios: ['action', 'energetic', 'urban'],
  },
];

/** Allowed xfade names — convenience for validators. */
export const TRANSITION_NAMES: ReadonlyArray<string> = TRANSITION_POOL.map((t) => t.name);

/**
 * Validate a list of transition names against the allowed pool. Returns the
 * cleaned list when ALL picks are valid (and `expectedCount` matches when
 * provided), or `null` if anything looks off — callers should then fall back
 * to the deterministic `pickTransition`. We're strict on purpose: a partial
 * LLM output would produce a worse video than the fallback.
 */
export function validateTransitions(
  picks: unknown,
  expectedCount?: number,
): string[] | null {
  if (!Array.isArray(picks)) return null;
  if (expectedCount != null && picks.length !== expectedCount) return null;
  const allowed = new Set<string>(TRANSITION_NAMES);
  for (const p of picks) {
    if (typeof p !== 'string' || !allowed.has(p)) return null;
  }
  return picks as string[];
}

export function pickTransition(seed: number, index: number): string {
  // Pool size (17) is prime. Step 7 is coprime to it, so over 17 indices we
  // cycle every transition exactly once. The seed shifts the starting offset
  // so different memories get different sequences. Big multipliers were a bad
  // idea here: they overflow uint32 and collapse the residue mod the pool size.
  const n = TRANSITION_POOL.length;
  const idx = ((seed % n) + index * 7) % n;
  return TRANSITION_POOL[(idx + n) % n].name;
}

/** Stable per-cluster seed from a UUID string (first 8 hex chars as a uint32). */
export function uuidToSeed(uuid: string): number {
  const hex = uuid.replace(/[^0-9a-f]/gi, '').slice(0, 8);
  return parseInt(hex || '0', 16) >>> 0;
}

export const DEFAULT_SLIDESHOW: SlideshowOptions = {
  width: 1280,
  height: 720,
  fps: 30,
  perImageSeconds: 4,
  transitionSeconds: 1,
  kenBurns: true,
};

/** Candidate font paths inside Debian-derived images, tried in order. */
export const CANDIDATE_FONTS: string[] = [
  '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
  '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
];

/**
 * Build the argument array for an ffmpeg invocation that composes a slideshow
 * from `imagePaths`. Returns a flat string[] suitable for `spawn('ffmpeg', args)`.
 *
 * Math:
 *   per-segment frames = fps * perImageSeconds
 *   total = N * perImage - (N-1) * transition
 *   xfade offsets accumulate at (perImage - transition, 2*(perImage - transition), ...)
 */
export function buildFfmpegSlideshowArgs(
  imagePaths: string[],
  outputPath: string,
  opts: SlideshowOptions = DEFAULT_SLIDESHOW,
): string[] {
  if (imagePaths.length === 0) {
    throw new Error('buildFfmpegSlideshowArgs: at least one image is required');
  }

  const args: string[] = ['-hide_banner', '-y'];
  for (const path of imagePaths) {
    // Single-frame input. zoompan below extends it to perImageSeconds.
    // Do NOT use `-loop 1 -t N` here — that emits N*fps input frames and
    // zoompan multiplies each by d, producing N*fps*d output frames.
    args.push('-i', path);
  }
  const audioInputIndex = imagePaths.length;
  if (opts.audioPath) {
    // Stream-copy the audio source; we'll loop/trim/fade it in the filter
    // graph below. -stream_loop -1 lets aloop be replaced by container-level
    // looping, which is simpler than aloop's frame-counting math.
    args.push('-stream_loop', '-1', '-i', opts.audioPath);
  }

  const N = imagePaths.length;
  const segFrames = opts.fps * opts.perImageSeconds;
  // Ken Burns: zoom 1.0 → ~1.18 over the segment, progressing per OUTPUT
  // frame (`on`). The total zoom delta scales with segFrames so the visual
  // pace is consistent regardless of duration.
  const zoomStep = (0.18 / segFrames).toFixed(6);
  const zoomExpr = opts.kenBurns ? `'1+${zoomStep}*on'` : `'1.0'`;

  const filterParts: string[] = [];

  for (let i = 0; i < N; i++) {
    const base =
      `[${i}:v]scale=${opts.width}:${opts.height}:force_original_aspect_ratio=increase,` +
      `crop=${opts.width}:${opts.height}`;
    const motion = `,zoompan=z=${zoomExpr}:d=${segFrames}:s=${opts.width}x${opts.height}:fps=${opts.fps}`;
    filterParts.push(`${base}${motion},setpts=PTS-STARTPTS,format=yuv420p[v${i}]`);
  }

  let lastLabel = 'v0';
  const seed = opts.transitionSeed ?? 0;
  const explicit =
    opts.transitions && opts.transitions.length === N - 1 ? opts.transitions : undefined;
  if (N >= 2) {
    for (let i = 1; i < N; i++) {
      const nextLabel = i === N - 1 ? 'chain' : `x${i}`;
      const offset = (i * (opts.perImageSeconds - opts.transitionSeconds)).toFixed(3);
      const transition = explicit ? explicit[i - 1] : pickTransition(seed, i - 1);
      filterParts.push(
        `[${lastLabel}][v${i}]xfade=transition=${transition}:duration=${opts.transitionSeconds}:` +
          `offset=${offset}[${nextLabel}]`,
      );
      lastLabel = nextLabel;
    }
  } else {
    lastLabel = 'v0';
  }

  const overlays: string[] = [];
  if (opts.fontFile) {
    if (opts.title) {
      overlays.push(
        `drawtext=fontfile=${opts.fontFile}:textfile=${opts.title}:reload=0:fontsize=42:` +
          `fontcolor=white:borderw=2:bordercolor=black@0.7:x=(w-text_w)/2:y=h*0.08:` +
          `enable='between(t,0.5,3.5)'`,
      );
    }
    if (opts.subtitle) {
      overlays.push(
        `drawtext=fontfile=${opts.fontFile}:textfile=${opts.subtitle}:reload=0:fontsize=24:` +
          `fontcolor=white:borderw=2:bordercolor=black@0.7:x=(w-text_w)/2:y=h*0.08+56:` +
          `enable='between(t,0.5,3.5)'`,
      );
    }
  }

  let finalLabel = lastLabel;
  if (overlays.length > 0) {
    const overlayChain = overlays.join(',');
    filterParts.push(`[${lastLabel}]${overlayChain}[final]`);
    finalLabel = 'final';
  }

  // Audio chain — trim the looped audio to the slideshow duration with 1s
  // fade-in and 1s fade-out at the very end.
  const totalDuration = slideshowDurationSeconds(N, opts);
  if (opts.audioPath) {
    const fadeOutStart = Math.max(totalDuration - 1, 0).toFixed(3);
    const volume = (opts.audioVolume ?? 0.7).toFixed(3);
    filterParts.push(
      `[${audioInputIndex}:a]atrim=0:${totalDuration.toFixed(3)},` +
        `asetpts=PTS-STARTPTS,` +
        `volume=${volume},` +
        `afade=t=in:st=0:d=1,` +
        `afade=t=out:st=${fadeOutStart}:d=1[a]`,
    );
  }

  args.push('-filter_complex', filterParts.join(';'));
  args.push('-map', `[${finalLabel}]`);
  if (opts.audioPath) {
    args.push('-map', '[a]', '-c:a', 'aac', '-b:a', '128k');
  }
  args.push(
    '-r',
    String(opts.fps),
    '-c:v',
    'libx264',
    '-pix_fmt',
    'yuv420p',
    '-preset',
    'fast',
    '-crf',
    '26',
    '-movflags',
    '+faststart',
    '-shortest',
    outputPath,
  );

  return args;
}

/**
 * Filename convention: `<space-separated-tags>__<track-name>.<ext>`. Returns
 * tag tokens lowercased, or null if the filename doesn't follow the convention.
 */
export function parseAudioTags(filename: string): string[] | null {
  const sep = filename.indexOf('__');
  if (sep <= 0) return null;
  return filename
    .slice(0, sep)
    .toLowerCase()
    .split(/\s+/)
    .filter(Boolean);
}

/** Tokenise a free-form theme string for tag matching. */
export function themeTokens(theme: string): string[] {
  return theme
    .toLowerCase()
    .split(/[\s,]+/)
    .filter(Boolean);
}

/**
 * Pick an audio track from `files` whose tag-token overlap with `theme` is
 * highest. Random tie-break. Falls back to a `default`-tagged track or a
 * uniform pick from all files when nothing matches.
 */
export function pickAudioForTheme(
  files: { name: string; path: string }[],
  theme: string,
  rng: () => number = Math.random,
): string | null {
  if (files.length === 0) return null;
  const tokens = new Set(themeTokens(theme));

  type Scored = { path: string; score: number; isDefault: boolean };
  const scored: Scored[] = [];
  for (const f of files) {
    const tags = parseAudioTags(f.name);
    if (!tags) continue;
    const overlap = tags.filter((t) => tokens.has(t)).length;
    scored.push({ path: f.path, score: overlap, isDefault: tags.includes('default') });
  }
  if (scored.length === 0) return null;

  const maxScore = Math.max(...scored.map((s) => s.score));
  if (maxScore > 0) {
    const top = scored.filter((s) => s.score === maxScore);
    return top[Math.floor(rng() * top.length)].path;
  }

  const defaults = scored.filter((s) => s.isDefault);
  const pool = defaults.length > 0 ? defaults : scored;
  return pool[Math.floor(rng() * pool.length)].path;
}

/** Total duration in seconds. */
export function slideshowDurationSeconds(n: number, opts: SlideshowOptions): number {
  if (n === 0) return 0;
  return n * opts.perImageSeconds - Math.max(0, n - 1) * opts.transitionSeconds;
}

/**
 * How many still frames to put in the video for a cluster of the given size.
 *
 * Linear ramp `ceil(N/divisor)`, floor at `min`, cap at `max`. The default
 * divisor=4 means every 4 photos add 1 still (~3s of video). Targets:
 *   N=10 → 5 stills (~16s) — bottom of the ramp
 *   N=20 → 5 stills (~16s) — still at floor
 *   N=30 → 8 stills (~25s)
 *   N=50 → 12 stills (~37s) — hits cap
 *
 * The LLM-input thumbnail count stays at 5 — this only affects the video.
 */
export function videoStillCount(
  clusterSize: number,
  opts?: { min?: number; max?: number; divisor?: number },
): number {
  const lo = opts?.min ?? 5;
  const hi = opts?.max ?? 12;
  const div = opts?.divisor ?? 4;
  return Math.min(hi, Math.max(lo, Math.ceil(Math.max(0, clusterSize) / div)));
}
