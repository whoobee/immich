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
}
