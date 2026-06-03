import { Injectable } from '@nestjs/common';
import { LoggingRepository } from 'src/repositories/logging.repository';

export type GenerateMemoryStoryOptions = {
  endpoint: string;
  model: string;
  /** base64-encoded image bytes (no data: prefix) */
  images: string[];
  prompt: string;
  /** request timeout in ms */
  timeoutMs?: number;
};

export type AnalyzeAudioOptions = {
  endpoint: string;
  model: string;
  /** base64-encoded audio bytes (no data: prefix) */
  audio: string;
  /** request timeout in ms */
  timeoutMs?: number;
};

export type AudioAnalysisResult = {
  mood: string;
  tags: string[];
  scenarios: string[];
  description?: string;
};

export type MemoryStoryResult = {
  title: string;
  story: string;
  /** Optional editorial picks from the LLM — ffmpeg xfade transition names,
   *  one per cut. Validated against the allowed pool by the caller. */
  transitions?: string[];
  /** Optional audio pick — the LLM nominates a filename from the supplied
   *  library. Validated against the actual file list by the caller; falls
   *  back to tag-based pickAudioForTheme when missing or invalid. */
  audioFile?: string;
};

const DEFAULT_TIMEOUT_MS = 120_000;

@Injectable()
export class OllamaRepository {
  constructor(private logger: LoggingRepository) {
    this.logger.setContext(OllamaRepository.name);
  }

  async generateMemoryStory(opts: GenerateMemoryStoryOptions): Promise<MemoryStoryResult> {
    const url = `${opts.endpoint.replace(/\/$/, '')}/api/chat`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? DEFAULT_TIMEOUT_MS);

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          model: opts.model,
          stream: false,
          format: 'json',
          messages: [
            {
              role: 'user',
              content: opts.prompt,
              images: opts.images,
            },
          ],
        }),
      });

      if (!response.ok) {
        const text = await response.text().catch(() => '');
        throw new Error(`Ollama ${response.status} ${response.statusText}: ${text.slice(0, 200)}`);
      }

      const payload = (await response.json()) as {
        message?: { content?: string };
      };
      const raw = payload.message?.content;
      if (!raw) {
        throw new Error('Ollama response missing message.content');
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch (error) {
        throw new Error(`Ollama returned non-JSON content: ${(error as Error).message}`);
      }

      const result = parsed as Partial<MemoryStoryResult>;
      if (typeof result.title !== 'string' || typeof result.story !== 'string') {
        throw new Error(`Ollama response missing title/story fields: ${raw.slice(0, 200)}`);
      }
      const transitions = Array.isArray(result.transitions)
        ? result.transitions.filter((t): t is string => typeof t === 'string')
        : undefined;
      const audioFile = typeof result.audioFile === 'string' ? result.audioFile : undefined;
      return { title: result.title, story: result.story, transitions, audioFile };
    } finally {
      clearTimeout(timer);
    }
  }

  /** Send one audio clip to an audio-capable model and ask it to categorise
   * the track's mood and scenarios. Used by the AlbumGeneratorAudioScan job
   * to enrich the music library catalogue. */
  async analyzeAudio(opts: AnalyzeAudioOptions): Promise<AudioAnalysisResult> {
    const url = `${opts.endpoint.replace(/\/$/, '')}/api/chat`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? DEFAULT_TIMEOUT_MS);

    const prompt = [
      'Listen to this audio track and categorise it for a personal photo-memory slideshow library.',
      '',
      'Reply with a JSON object of this exact shape:',
      '{',
      '  "mood": "single word — calm | energetic | contemplative | playful | cinematic | warm | melancholic",',
      '  "tags": ["short", "free-form", "descriptors"],',
      '  "scenarios": [/* any subset of: scenic, warm, contemplative, nostalgic, action, energetic, playful, cinematic, urban, natural */],',
      '  "description": "one short sentence about feel and instrumentation"',
      '}',
      '',
      'Output the JSON only, nothing else.',
    ].join('\n');

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: controller.signal,
        body: JSON.stringify({
          model: opts.model,
          stream: false,
          format: 'json',
          messages: [
            {
              role: 'user',
              content: prompt,
              audios: [opts.audio],
            },
          ],
        }),
      });

      if (!response.ok) {
        const text = await response.text().catch(() => '');
        throw new Error(`Ollama ${response.status} ${response.statusText}: ${text.slice(0, 200)}`);
      }

      const payload = (await response.json()) as { message?: { content?: string } };
      const raw = payload.message?.content;
      if (!raw) {
        throw new Error('Ollama analyzeAudio response missing message.content');
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch (error) {
        throw new Error(`Ollama analyzeAudio non-JSON content: ${(error as Error).message}`);
      }

      const result = parsed as Partial<AudioAnalysisResult>;
      const mood = typeof result.mood === 'string' ? result.mood : 'unknown';
      const tags = Array.isArray(result.tags)
        ? result.tags.filter((t): t is string => typeof t === 'string')
        : [];
      const scenarios = Array.isArray(result.scenarios)
        ? result.scenarios.filter((s): s is string => typeof s === 'string')
        : [];
      const description = typeof result.description === 'string' ? result.description : undefined;
      return { mood, tags, scenarios, description };
    } finally {
      clearTimeout(timer);
    }
  }
}
