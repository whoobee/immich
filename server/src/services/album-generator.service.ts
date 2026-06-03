import { BadRequestException, Injectable, NotFoundException, StreamableFile } from '@nestjs/common';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { StorageCore } from 'src/cores/storage.core';
import { OnEvent, OnJob } from 'src/decorators';
import { AlbumGeneratorUserConfigDto } from 'src/dtos/album-generator.dto';
import { AuthDto } from 'src/dtos/auth.dto';
import {
  AssetType,
  AssetVisibility,
  ChecksumAlgorithm,
  CronJob,
  DatabaseLock,
  ImmichWorker,
  JobName,
  JobStatus,
  MemoryType,
  QueueName,
  StorageFolder,
  SystemMetadataKey,
  UserMetadataKey,
} from 'src/enum';
import { ArgOf } from 'src/repositories/event.repository';
import { BaseService } from 'src/services/base.service';
import {
  AiStoryData,
  AlbumGeneratorState,
  AlbumGeneratorUserConfig,
  JobOf,
  UserMetadataItem,
} from 'src/types';
import {
  AssetCluster,
  CandidateAsset,
  appendRecentlyUsed,
  buildSegmentedClusters,
  pickRepresentatives,
  rankClusters,
} from 'src/utils/album-generator';
import {
  CANDIDATE_FONTS,
  DEFAULT_SLIDESHOW,
  TRANSITION_POOL,
  buildFfmpegSlideshowArgs,
  pickAudioForTheme,
  slideshowDurationSeconds,
  uuidToSeed,
  validateTransitions,
  videoStillCount,
} from 'src/utils/album-video';
import { handlePromiseError } from 'src/utils/misc';

const SEARCH_RESULTS_PER_TERM = 60;
/** Vision LLM input thumbnail count — kept at the gemma4 sweet spot. The
 * video slideshow uses a separate, cluster-size-scaled count (see
 * videoStillCount) so larger memories get proportionally longer videos. */
const LLM_INPUT_THUMBS = 5;
const RECENT_WINDOW_DAYS = 30;
const RECENT_CANDIDATES_LIMIT = 80;
const ANNIVERSARY_YEARS_BACK = 5;
const ANNIVERSARY_CANDIDATES_LIMIT = 40;

function defaultedUserConfig(stored: AlbumGeneratorUserConfig | null): AlbumGeneratorUserConfig {
  return {
    optIn: stored?.optIn ?? false,
    maxPerNight: stored?.maxPerNight ?? 2,
    hints: stored?.hints ?? [],
  };
}

function firstSentence(text: string): string {
  const match = text.match(/[^.!?]+[.!?]/);
  return (match?.[0] ?? text).trim().slice(0, 140);
}

@Injectable()
export class AlbumGeneratorService extends BaseService {
  private lock = false;

  @OnEvent({ name: 'ConfigInit', workers: [ImmichWorker.Microservices] })
  async onConfigInit({
    newConfig: { albumGenerator },
  }: ArgOf<'ConfigInit'>) {
    // Cron lease — held session-wide so only one microservices instance schedules
    // the cron. Distinct from DatabaseLock.AlbumGeneratorRun (which guards
    // serial run execution via withLock inside handleRun); reusing the same ID
    // would self-deadlock when the worker connection != the cron-holder
    // connection.
    this.lock = await this.databaseRepository.tryLock(DatabaseLock.AlbumGeneratorCronLease);
    if (!this.lock) {
      return;
    }

    this.cronRepository.create({
      name: CronJob.AlbumGeneratorRun,
      expression: albumGenerator.cronExpression,
      onTick: () =>
        handlePromiseError(
          this.jobRepository.queue({ name: JobName.AlbumGeneratorRun }),
          this.logger,
        ),
      start: albumGenerator.enabled,
    });
  }

  @OnEvent({ name: 'ConfigUpdate', server: true })
  onConfigUpdate({ newConfig: { albumGenerator } }: ArgOf<'ConfigUpdate'>) {
    if (!this.lock) {
      return;
    }

    this.cronRepository.update({
      name: CronJob.AlbumGeneratorRun,
      expression: albumGenerator.cronExpression,
      start: albumGenerator.enabled,
    });
  }

  @OnJob({ name: JobName.AlbumGeneratorRun, queue: QueueName.BackgroundTask })
  async handleRun(): Promise<JobStatus> {
    const config = await this.getConfig({ withCache: false });
    const { albumGenerator, machineLearning } = config;
    if (!albumGenerator.enabled) {
      return JobStatus.Skipped;
    }
    if (!machineLearning.enabled || !machineLearning.clip.enabled) {
      this.logger.warn('AlbumGenerator skipped: smart search / CLIP is disabled');
      return JobStatus.Skipped;
    }

    await this.databaseRepository.withLock(DatabaseLock.AlbumGeneratorRun, async () => {
      const state: AlbumGeneratorState = (await this.systemMetadataRepository.get(
        SystemMetadataKey.AlbumGeneratorState,
      )) ?? { perUser: {} };

      const users = await this.userRepository.getList({ withDeleted: false });
      const now = new Date();

      for (const user of users) {
        const userConfig = await this.readUserConfig(user.id);
        if (!userConfig?.optIn) {
          continue;
        }
        const terms = this.collectQueryTerms(userConfig, albumGenerator.themeVocabulary);
        if (terms.hints.length === 0 && terms.themes.length === 0) {
          this.logger.debug(`User ${user.id}: no hints or themes — skipping`);
          continue;
        }

        const picks = await this.pickClustersForUser({
          userId: user.id,
          hints: terms.hints,
          themes: terms.themes,
          clipModelName: machineLearning.clip.modelName,
          maxPerNight: Math.max(1, userConfig.maxPerNight ?? 2),
          recentlyUsed: new Set(state.perUser[user.id]?.recentlyUsedAssetIds ?? []),
          now,
        });

        const usedAssetIds: string[] = [];
        for (const pick of picks) {
          try {
            const memoryId = await this.materialiseMemory({
              ownerId: user.id,
              cluster: pick,
              hints: terms.hints,
              ollama: albumGenerator.ollama,
              now,
            });
            usedAssetIds.push(...pick.assetIds);
            this.logger.log(
              `User ${user.id}: created AI memory ${memoryId} (n=${pick.assetIds.length}, score=${pick.score.toFixed(2)})`,
            );
            // Queue video composition. Phase 4 will fill in the handler.
            await this.jobRepository.queue({
              name: JobName.MemoryVideoCompose,
              data: { id: memoryId },
            });
          } catch (error) {
            this.logger.warn(`User ${user.id}: cluster (n=${pick.assetIds.length}) failed — ${error}`);
          }
        }

        state.perUser[user.id] = {
          recentlyUsedAssetIds: appendRecentlyUsed(
            state.perUser[user.id]?.recentlyUsedAssetIds ?? [],
            usedAssetIds,
          ),
          lastRunAt: now.toISOString(),
        };
      }

      await this.systemMetadataRepository.set(SystemMetadataKey.AlbumGeneratorState, state);
    });

    return JobStatus.Success;
  }

  @OnJob({ name: JobName.AlbumGeneratorOnDemand, queue: QueueName.BackgroundTask })
  async handleOnDemand(job: JobOf<JobName.AlbumGeneratorOnDemand>): Promise<JobStatus> {
    const config = await this.getConfig({ withCache: false });
    const { machineLearning } = config;
    if (!machineLearning.enabled || !machineLearning.clip.enabled) {
      this.logger.warn('AlbumGeneratorOnDemand skipped: smart search / CLIP is disabled');
      return JobStatus.Skipped;
    }

    const trimmedHint = job.hint.trim();
    if (!trimmedHint) {
      this.logger.warn('AlbumGeneratorOnDemand skipped: empty hint');
      return JobStatus.Skipped;
    }

    const now = new Date();
    const picks = await this.pickClustersForUser({
      userId: job.userId,
      hints: [trimmedHint],
      themes: [],
      clipModelName: machineLearning.clip.modelName,
      maxPerNight: 1,
      // On-demand intentionally ignores the recently-used FIFO so the same
      // photos can recur if that's what the user's hint surfaces.
      recentlyUsed: new Set<string>(),
      // Skip recency + anniversary pulls so the explicit hint isn't drowned
      // out by an untagged time+geo cluster that would otherwise outscore it.
      includeBroadSources: false,
      now,
    });

    if (picks.length === 0) {
      this.logger.warn(
        `AlbumGeneratorOnDemand: user ${job.userId} hint="${trimmedHint}" — no clusters surfaced`,
      );
      return JobStatus.Failed;
    }

    const pick = picks[0];
    const memoryId = await this.materialiseMemory({
      ownerId: job.userId,
      cluster: pick,
      hints: [trimmedHint],
      ollama: config.albumGenerator.ollama,
      now,
    });
    this.logger.log(
      `AlbumGeneratorOnDemand: user ${job.userId} hint="${trimmedHint}" → memory ${memoryId} (n=${pick.assetIds.length}, score=${pick.score.toFixed(2)})`,
    );
    await this.jobRepository.queue({
      name: JobName.MemoryVideoCompose,
      data: { id: memoryId },
    });
    return JobStatus.Success;
  }

  async triggerOnDemand(auth: AuthDto, hint: string): Promise<{ queued: true }> {
    await this.jobRepository.queue({
      name: JobName.AlbumGeneratorOnDemand,
      data: { userId: auth.user.id, hint },
    });
    return { queued: true };
  }

  @OnJob({ name: JobName.MemoryVideoCompose, queue: QueueName.BackgroundTask })
  async handleVideoCompose(job: JobOf<JobName.MemoryVideoCompose>): Promise<JobStatus> {
    const memoryId = job.id;
    const config = await this.getConfig({ withCache: true });
    const audioConfig = config.albumGenerator.audio;
    const memory = await this.memoryRepository.get(memoryId);
    if (!memory) {
      this.logger.warn(`MemoryVideoCompose: memory ${memoryId} not found`);
      return JobStatus.Skipped;
    }
    if (memory.type !== MemoryType.AiStory) {
      this.logger.debug(`MemoryVideoCompose: ${memoryId} is not AiStory — skipping`);
      return JobStatus.Skipped;
    }
    if (!memory.assets || memory.assets.length === 0) {
      this.logger.warn(`MemoryVideoCompose: memory ${memoryId} has no assets`);
      return JobStatus.Skipped;
    }

    const storyData = memory.data as AiStoryData;
    if (storyData.videoFilePath) {
      this.logger.debug(`MemoryVideoCompose: ${memoryId} already has video — skipping`);
      return JobStatus.Skipped;
    }

    // The memory.assets array comes from getByIdBuilder and lacks files; refetch.
    const assetIds = memory.assets.map((a) => a.id);
    // Cluster-size-scaled still count: ~⌈√N⌉ stills, clamped to [5, 12].
    // A 9-photo cluster keeps the 16s baseline; an 87-photo cluster gets
    // ~10 stills → ~31s; a 144-photo cluster gets the 12 cap → ~37s.
    const videoStills = videoStillCount(assetIds.length);
    const repIds = pickRepresentatives(
      {
        assetIds,
        startsAt: new Date(),
        endsAt: new Date(),
        centerLat: null,
        centerLon: null,
        city: null,
        country: null,
        hints: [],
        themes: [],
        score: 0,
      },
      videoStills,
    );

    const imagePaths = await this.previewPathsInOrder(repIds);
    if (imagePaths.length === 0) {
      this.logger.warn(`MemoryVideoCompose: no preview thumbnails for memory ${memoryId}`);
      return JobStatus.Failed;
    }

    const outputPath = StorageCore.getNestedPath(
      StorageFolder.EncodedVideo,
      memory.ownerId,
      `memory-${memoryId}.mp4`,
    );
    this.storageRepository.mkdirSync(dirname(outputPath));

    const fontFile = await this.detectFontFile();
    const tmpDir = join('/tmp', `album-generator-${memoryId}`);
    this.storageRepository.mkdirSync(tmpDir);
    const titlePath = join(tmpDir, 'title.txt');
    const subtitlePath = join(tmpDir, 'subtitle.txt');

    try {
      await this.storageRepository.createOrOverwriteFile(titlePath, Buffer.from(storyData.title, 'utf8'));
      const subtitle = firstSentence(storyData.story);
      if (subtitle) {
        await this.storageRepository.createOrOverwriteFile(subtitlePath, Buffer.from(subtitle, 'utf8'));
      }

      const audioPath = audioConfig.enabled
        ? await this.pickAudio({
            libraryPath: audioConfig.libraryPath,
            theme: storyData.theme ?? 'highlights',
          })
        : null;

      const opts = {
        ...DEFAULT_SLIDESHOW,
        fontFile: fontFile ?? undefined,
        title: fontFile ? titlePath : undefined,
        subtitle: fontFile && subtitle ? subtitlePath : undefined,
        audioPath: audioPath ?? undefined,
        audioVolume: audioConfig.volume,
        // Stable shuffle of xfade transitions keyed off the memory id so
        // re-renders look identical, but each memory has its own sequence.
        transitionSeed: uuidToSeed(memoryId),
        // Use the LLM's editorial picks when present and valid for THIS
        // still count; otherwise fall through to the seeded picker.
        transitions: validateTransitions(storyData.videoTransitions, videoStills - 1) ?? undefined,
      };
      const ffmpegArgs = buildFfmpegSlideshowArgs(imagePaths, outputPath, opts);

      await this.runFfmpeg(ffmpegArgs);

      const duration = slideshowDurationSeconds(imagePaths.length, DEFAULT_SLIDESHOW);
      const { videoAssetId, finalPath } = await this.promoteToAsset({
        ownerId: memory.ownerId,
        memoryId,
        ffmpegOutputPath: outputPath,
        memoryAt: memory.memoryAt,
      });
      await this.memoryRepository.update(memoryId, {
        data: {
          ...storyData,
          videoAssetId,
          videoFilePath: finalPath,
          videoDurationSeconds: duration,
        },
      });

      this.logger.log(
        `MemoryVideoCompose: composed memory ${memoryId} (${imagePaths.length} stills, ${duration}s, ${outputPath})`,
      );
      return JobStatus.Success;
    } finally {
      handlePromiseError(
        this.storageRepository.unlinkDir(tmpDir, { recursive: true, force: true }),
        this.logger,
      );
    }
  }

  /** Promote the ffmpeg output to a real Immich Asset (Hidden visibility so it
   * stays out of the timeline). Returns the new asset id + canonical path. */
  private async promoteToAsset(args: {
    ownerId: string;
    memoryId: string;
    ffmpegOutputPath: string;
    memoryAt: Date | string;
  }): Promise<{ videoAssetId: string; finalPath: string }> {
    const checksum = await this.cryptoRepository.hashFile(args.ffmpegOutputPath);
    const fileStat = await this.storageRepository.stat(args.ffmpegOutputPath);

    const assetId = this.cryptoRepository.randomUUID();
    const finalPath = StorageCore.getNestedPath(
      StorageFolder.EncodedVideo,
      args.ownerId,
      `${assetId}-AI.mp4`,
    );
    this.storageRepository.mkdirSync(dirname(finalPath));
    if (finalPath !== args.ffmpegOutputPath) {
      await this.storageRepository.rename(args.ffmpegOutputPath, finalPath);
    }

    const fileCreatedAt = new Date(args.memoryAt);
    const now = new Date();

    await this.assetRepository.create({
      id: assetId,
      ownerId: args.ownerId,
      type: AssetType.Video,
      // Archive (not Hidden) — Hidden assets skip thumbnail generation entirely
      // (see media.service.ts:219); we want a poster for the memory player.
      visibility: AssetVisibility.Archive,
      originalPath: finalPath,
      originalFileName: `memory-${args.memoryId}.mp4`,
      checksum,
      checksumAlgorithm: ChecksumAlgorithm.sha1File,
      fileCreatedAt,
      fileModifiedAt: now,
      localDateTime: fileCreatedAt,
      libraryId: null,
      isExternal: false,
    });

    // Minimal asset_exif row — required by getForGenerateThumbnailJob's
    // INNER JOIN on asset_exif (see asset-job.repository.ts:117). Include
    // `description` (which has a default of '') so upsertExif's onConflict
    // SET clause is non-empty; otherwise it would emit `DO UPDATE SET` with
    // no assignments and Postgres rejects it as a syntax error.
    await this.assetRepository.upsertExif({
      exif: { assetId, description: '' },
      lockedPropertiesBehavior: 'skip',
    });

    await this.userRepository.updateUsage(args.ownerId, fileStat.size);
    // Mirror the upload chain so the asset gets full processing:
    // ExtractMetadata writes asset_video → StorageTemplateMigration → GenerateThumbnails
    // → SmartSearch/Faces/OCR/AssetEncodeVideo. We use source='upload' so the
    // StorageTemplateMigration onDone branch fires and thumbnails get queued.
    await this.jobRepository.queue({
      name: JobName.AssetExtractMetadata,
      data: { id: assetId, source: 'upload' },
    });

    return { videoAssetId: assetId, finalPath };
  }

  private static readonly AUDIO_EXTS = ['.mp3', '.m4a', '.aac', '.ogg', '.opus', '.wav', '.flac'];

  private async pickAudio(args: { libraryPath: string; theme: string }): Promise<string | null> {
    let entries;
    try {
      entries = await this.storageRepository.readdirWithTypes(args.libraryPath);
    } catch (error) {
      this.logger.debug(`audio library ${args.libraryPath} unreadable: ${error}`);
      return null;
    }
    const files = entries
      .filter((e) => e.isFile())
      .map((e) => e.name)
      .filter((name) =>
        AlbumGeneratorService.AUDIO_EXTS.includes(name.slice(name.lastIndexOf('.')).toLowerCase()),
      )
      .map((name) => ({ name, path: join(args.libraryPath, name) }));
    if (files.length === 0) {
      this.logger.debug(`audio library ${args.libraryPath} has no audio files`);
      return null;
    }
    const picked = pickAudioForTheme(files, args.theme);
    if (picked) {
      this.logger.debug(`pickAudio(theme="${args.theme}") → ${picked.split('/').pop()}`);
    }
    return picked;
  }

  private async detectFontFile(): Promise<string | null> {
    for (const candidate of CANDIDATE_FONTS) {
      try {
        await this.storageRepository.stat(candidate);
        return candidate;
      } catch {
        // not present
      }
    }
    return null;
  }

  private runFfmpeg(args: string[]): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const proc = this.processRepository.spawn('ffmpeg', args);
      let stderr = '';
      proc.stderr?.on('data', (chunk: Buffer) => {
        stderr += chunk.toString();
        if (stderr.length > 4096) {
          stderr = stderr.slice(-4096);
        }
      });
      proc.on('error', (error) => reject(error));
      proc.on('close', (code) => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`ffmpeg exited ${code}: ${stderr.slice(-500)}`));
        }
      });
    });
  }

  async getUserConfig(auth: AuthDto): Promise<AlbumGeneratorUserConfigDto> {
    const stored = await this.readUserConfig(auth.user.id);
    return defaultedUserConfig(stored);
  }

  async updateUserConfig(
    auth: AuthDto,
    dto: AlbumGeneratorUserConfigDto,
  ): Promise<AlbumGeneratorUserConfigDto> {
    const cleaned: AlbumGeneratorUserConfig = {
      optIn: dto.optIn,
      maxPerNight: dto.maxPerNight,
      hints: dto.hints.map((s) => s.trim()).filter(Boolean),
    };
    await this.userRepository.upsertMetadata(auth.user.id, {
      key: UserMetadataKey.AlbumGenerator,
      value: cleaned,
    });
    return cleaned;
  }

  async getMemoryVideoStream(auth: AuthDto, memoryId: string): Promise<StreamableFile> {
    const memory = await this.memoryRepository.get(memoryId);
    if (!memory) {
      throw new NotFoundException(`Memory ${memoryId} not found`);
    }
    if (memory.ownerId !== auth.user.id) {
      throw new NotFoundException(`Memory ${memoryId} not found`);
    }
    if (memory.type !== MemoryType.AiStory) {
      throw new BadRequestException(`Memory ${memoryId} has no AI-generated video`);
    }
    const data = memory.data as AiStoryData;
    if (!data.videoFilePath) {
      throw new NotFoundException(`Memory ${memoryId} video not yet composed`);
    }

    let fileStat;
    try {
      fileStat = await stat(data.videoFilePath);
    } catch {
      throw new NotFoundException(`Memory ${memoryId} video file missing on disk`);
    }

    const stream = createReadStream(data.videoFilePath);
    return new StreamableFile(stream, {
      type: 'video/mp4',
      length: fileStat.size,
      disposition: `inline; filename="memory-${memoryId}.mp4"`,
    });
  }

  private async readUserConfig(userId: string): Promise<AlbumGeneratorUserConfig | null> {
    const items = await this.userRepository.getMetadata(userId);
    const match = items.find(
      (item): item is UserMetadataItem<UserMetadataKey.AlbumGenerator> =>
        item.key === UserMetadataKey.AlbumGenerator,
    );
    return match?.value ?? null;
  }

  private collectQueryTerms(
    userConfig: AlbumGeneratorUserConfig,
    themeVocabulary: string[],
  ): { hints: string[]; themes: string[] } {
    const hints = (userConfig.hints ?? []).map((s) => s.trim()).filter(Boolean);
    const themes = themeVocabulary.map((s) => s.trim()).filter(Boolean);
    return { hints, themes };
  }

  private async pickClustersForUser(args: {
    userId: string;
    hints: string[];
    themes: string[];
    clipModelName: string;
    maxPerNight: number;
    recentlyUsed: Set<string>;
    now: Date;
    /** When false, skip the recency + anniversary candidate sources — the
     *  pool stays strictly hint+theme matches. Used by on-demand so the
     *  untagged time+geo cluster doesn't outscore the explicit hint. */
    includeBroadSources?: boolean;
  }): Promise<AssetCluster[]> {
    const candidates = await this.gatherCandidates({
      ...args,
      includeBroadSources: args.includeBroadSources ?? true,
    });
    if (candidates.length === 0) {
      return [];
    }
    const fresh = candidates.filter((c) => !args.recentlyUsed.has(c.id));
    if (fresh.length === 0) {
      return [];
    }
    const clusters = buildSegmentedClusters(fresh);
    if (clusters.length === 0) {
      return [];
    }
    return rankClusters(clusters, args.now).slice(0, args.maxPerNight);
  }

  private async gatherCandidates(args: {
    userId: string;
    hints: string[];
    themes: string[];
    clipModelName: string;
    /** When false, skip the recency + anniversary pulls — the candidate pool
     *  stays strictly the union of hint + theme CLIP matches. */
    includeBroadSources?: boolean;
  }): Promise<CandidateAsset[]> {
    const includeBroad = args.includeBroadSources ?? true;
    const candidates = new Map<string, CandidateAsset>();
    const upsert = (data: Omit<CandidateAsset, 'matchedHints' | 'matchedThemes'>) => {
      const existing = candidates.get(data.id);
      if (existing) {
        return existing;
      }
      const next: CandidateAsset = { ...data, matchedHints: [], matchedThemes: [] };
      candidates.set(data.id, next);
      return next;
    };

    // -- Source 1: CLIP semantic search per hint + theme --------------------
    const tagsById = new Map<string, { hints: Set<string>; themes: Set<string> }>();

    const runQuery = async (text: string, tag: 'hint' | 'theme') => {
      let embedding;
      try {
        embedding = await this.machineLearningRepository.encodeText(text, {
          modelName: args.clipModelName,
        });
      } catch (error) {
        this.logger.warn(`encodeText("${text}") failed: ${error}`);
        return;
      }
      const { items } = await this.searchRepository.searchSmart(
        { page: 1, size: SEARCH_RESULTS_PER_TERM },
        { userIds: [args.userId], embedding },
      );
      for (const item of items) {
        const entry = tagsById.get(item.id) ?? { hints: new Set(), themes: new Set() };
        if (tag === 'hint') {
          entry.hints.add(text);
        } else {
          entry.themes.add(text);
        }
        tagsById.set(item.id, entry);
      }
    };

    for (const hint of args.hints) {
      await runQuery(hint, 'hint');
    }
    for (const theme of args.themes) {
      await runQuery(theme, 'theme');
    }

    if (tagsById.size > 0) {
      const assets = await this.assetRepository.getByIdsWithAllRelationsButStacks([...tagsById.keys()]);
      for (const asset of assets) {
        const tags = tagsById.get(asset.id);
        if (!tags) continue;
        const takenAt = asset.localDateTime ?? asset.fileCreatedAt;
        if (!takenAt) continue;
        const exif = asset.exifInfo;
        const c = upsert({
          id: asset.id,
          takenAt: new Date(takenAt),
          lat: (exif?.latitude as number | null) ?? null,
          lon: (exif?.longitude as number | null) ?? null,
          city: (exif?.city as string | null) ?? null,
          country: (exif?.country as string | null) ?? null,
        });
        c.matchedHints = [...tags.hints];
        c.matchedThemes = [...tags.themes];
      }
    }

    // -- Source 2: recency-weighted sample ---------------------------------
    // Pull the most recent N timeline photos with exif joined. Untagged
    // (no hints/themes), but the cluster scorer's recency term pushes
    // recent events to the top regardless.
    const recentSince = new Date(Date.now() - RECENT_WINDOW_DAYS * 86_400_000);
    const recent = includeBroad
      ? await this.assetRepository.getForAlbumGeneratorRecent(
          args.userId,
          recentSince,
          RECENT_CANDIDATES_LIMIT,
        )
      : [];
    for (const row of recent) {
      upsert({
        id: row.id,
        takenAt: row.localDateTime instanceof Date ? row.localDateTime : new Date(row.localDateTime),
        lat: row.latitude,
        lon: row.longitude,
        city: row.city,
        country: row.country,
      });
    }

    // -- Source 3: anniversary (same calendar day, past N years) -----------
    const now = new Date();
    const anniversary = includeBroad
      ? await this.assetRepository.getForAlbumGeneratorAnniversary(
          args.userId,
          now.getMonth() + 1,
          now.getDate(),
          ANNIVERSARY_YEARS_BACK,
          ANNIVERSARY_CANDIDATES_LIMIT,
        )
      : [];
    for (const row of anniversary) {
      upsert({
        id: row.id,
        takenAt: row.localDateTime instanceof Date ? row.localDateTime : new Date(row.localDateTime),
        lat: row.latitude,
        lon: row.longitude,
        city: row.city,
        country: row.country,
      });
    }

    this.logger.debug(
      `gatherCandidates: tagged=${tagsById.size} recent=${recent.length} anniversary=${anniversary.length} total=${candidates.size}`,
    );

    return [...candidates.values()];
  }

  private async materialiseMemory(args: {
    ownerId: string;
    cluster: AssetCluster;
    hints: string[];
    ollama: { endpoint: string; textModel: string; visionModel: string };
    now: Date;
  }): Promise<string> {
    const repIds = pickRepresentatives(args.cluster, LLM_INPUT_THUMBS);
    const imagePaths = await this.previewPathsInOrder(repIds);
    const images = await this.readImagesAsBase64(imagePaths);
    if (images.length === 0) {
      throw new Error('no preview thumbnails available for cluster');
    }

    // The LLM also gets to curate the slideshow's transition sequence — N-1
    // picks where N is the planned video still count for this cluster.
    const plannedStills = videoStillCount(args.cluster.assetIds.length);
    const expectedTransitionCount = Math.max(0, plannedStills - 1);
    const prompt = buildStoryPrompt({
      cluster: args.cluster,
      hints: args.hints,
      photoCount: args.cluster.assetIds.length,
      expectedTransitionCount,
    });

    const llmResult = await this.ollamaRepository.generateMemoryStory({
      endpoint: args.ollama.endpoint,
      model: args.ollama.visionModel,
      images,
      prompt,
    });
    const { title, story } = llmResult;
    const validatedTransitions = validateTransitions(llmResult.transitions, expectedTransitionCount);
    if (llmResult.transitions && !validatedTransitions) {
      this.logger.debug(
        `LLM transitions rejected (expected ${expectedTransitionCount}, got ${JSON.stringify(llmResult.transitions).slice(0, 200)})`,
      );
    }

    const heroAssetId = repIds[Math.floor(repIds.length / 2)] ?? args.cluster.assetIds[0];
    // The cluster's primary theme is the bucketing key (one hint OR one theme
    // when from buildSegmentedClusters). Fall back to "highlights" for the
    // untagged time+geo clusters.
    const clusterTheme =
      args.cluster.hints[0] ?? args.cluster.themes[0] ?? 'highlights';
    const data: AiStoryData = {
      title,
      story,
      theme: clusterTheme,
      hints: args.hints.length > 0 ? args.hints : undefined,
      heroAssetId,
      videoTransitions: validatedTransitions ?? undefined,
      model: args.ollama.visionModel,
      generatedAt: args.now.toISOString(),
    };

    const memory = await this.memoryRepository.create(
      {
        ownerId: args.ownerId,
        type: MemoryType.AiStory,
        data,
        memoryAt: args.cluster.endsAt.toISOString(),
        showAt: args.now.toISOString(),
        hideAt: null,
      },
      new Set(args.cluster.assetIds),
    );
    return memory.id;
  }

  private async previewPathsInOrder(assetIds: string[]): Promise<string[]> {
    const files = await this.assetRepository.getPreviewFilesByIds(assetIds);
    const byId = new Map(files.map((f) => [f.id, f.path]));
    const paths: string[] = [];
    for (const id of assetIds) {
      const path = byId.get(id);
      if (path) {
        paths.push(path);
      } else {
        this.logger.debug(`asset ${id}: no preview file — skipping`);
      }
    }
    return paths;
  }

  private async readImagesAsBase64(paths: string[]): Promise<string[]> {
    const images: string[] = [];
    for (const path of paths) {
      try {
        const bytes = await this.storageRepository.readFile(path);
        images.push(bytes.toString('base64'));
      } catch (error) {
        this.logger.debug(`preview read failed at ${path}: ${error} — skipping`);
      }
    }
    return images;
  }
}

function buildStoryPrompt(args: {
  cluster: AssetCluster;
  hints: string[];
  photoCount: number;
  expectedTransitionCount: number;
}): string {
  const { cluster, hints, photoCount, expectedTransitionCount } = args;
  const startDate = cluster.startsAt.toISOString().slice(0, 10);
  const endDate = cluster.endsAt.toISOString().slice(0, 10);
  const dateRange = startDate === endDate ? startDate : `${startDate} to ${endDate}`;
  const location = [cluster.city, cluster.country].filter(Boolean).join(', ') || 'unknown';
  // The "requested topic" is the cluster's bucketing key — the user's hint
  // when present, otherwise the theme that surfaced this cluster. Untagged
  // time+geo clusters fall back to "highlights".
  const requestedTopic =
    hints[0] ?? cluster.hints[0] ?? cluster.themes[0] ?? 'highlights';

  return [
    "You are an AI memory keeper AND the editor of a short slideshow video for someone's personal photo library.",
    '',
    `THE TOPIC FOR THIS MEMORY IS: "${requestedTopic}".`,
    'This was chosen by the user or by a theme search. Your job is to deliver a',
    'memory ABOUT THIS TOPIC. The title MUST contain or directly evoke the topic',
    'word — do not substitute a generic "sunny day" or "summer memories" phrasing.',
    'The story should anchor on the topic too.',
    '',
    `You will see up to ${photoCount} photos. The photos were retrieved by CLIP`,
    'similarity, so most should fit the topic — but with a small or mismatched',
    `library some may not match obviously. When that happens, BRIDGE the photos`,
    'to the topic creatively: find an aspect that fits (e.g. for "food" → meals',
    'on the trail; for "city skyline" → the horizon glimpsed between trees).',
    'Never silently default to describing only nature/sunshine when the topic',
    'is something else.',
    '',
    'Cluster context (background, not the topic):',
    `- Date range: ${dateRange}`,
    `- Approximate location: ${location}`,
    '',
    'Editorial transitions: pick an ordered list of exactly',
    `${expectedTransitionCount} ffmpeg xfade transition names that match the mood of your story.`,
    'Allowed (and only these):',
    `  ${TRANSITION_POOL.join(', ')}`,
    'Guidance: prefer slow types (`fade`, `fadeblack`, `fadewhite`, `dissolve`,',
    '`smooth*`, `circleopen`) for calm / contemplative moments, and `slide*`,',
    '`wipe*`, `radial`, `circleclose` for upbeat / energetic moments. Mix them',
    'so the rhythm matches the arc of your story; avoid repeating the same',
    'transition three times in a row.',
    '',
    'Generate a JSON object with this exact shape:',
    '{',
    `  "title": "5-8 word evocative title that contains or clearly evokes \\"${requestedTopic}\\"",`,
    '  "story": "warm 60-100 word second-person narrative using \\"you\\"/\\"your\\". Anchor on the topic above. Reference specific visual details. Do not invent names of people. No preamble.",',
    `  "transitions": [/* exactly ${expectedTransitionCount} strings from the allowed list */]`,
    '}',
    '',
    'Output the JSON object only, nothing else.',
  ].join('\n');
}
