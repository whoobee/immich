import { createZodDto } from 'nestjs-zod';
import { z } from 'zod';

const AlbumGeneratorUserConfigSchema = z
  .object({
    optIn: z.boolean().describe('Whether this user opts into nightly AI memory generation'),
    maxPerNight: z
      .int()
      .min(1)
      .max(10)
      .describe('Maximum number of AI memories to create for this user per nightly run'),
    hints: z
      .array(z.string().min(1).max(80))
      .max(20)
      .describe(
        'Soft directives passed to the LLM and used as searchSmart queries when discovering memory candidates',
      ),
  })
  .meta({ id: 'AlbumGeneratorUserConfigDto' });

export class AlbumGeneratorUserConfigDto extends createZodDto(AlbumGeneratorUserConfigSchema) {}

const AlbumGeneratorOnDemandRequestSchema = z
  .object({
    hint: z
      .string()
      .min(2)
      .max(200)
      .describe('Free-form prompt — passed as the lone hint to CLIP search and the LLM story prompt'),
  })
  .meta({ id: 'AlbumGeneratorOnDemandRequestDto' });

const AlbumGeneratorOnDemandResponseSchema = z
  .object({
    queued: z.literal(true).describe('Job accepted; check the Memories page in 1–3 minutes'),
  })
  .meta({ id: 'AlbumGeneratorOnDemandResponseDto' });

export class AlbumGeneratorOnDemandRequestDto extends createZodDto(AlbumGeneratorOnDemandRequestSchema) {}
export class AlbumGeneratorOnDemandResponseDto extends createZodDto(AlbumGeneratorOnDemandResponseSchema) {}

const AlbumGeneratorAudioScanRequestSchema = z
  .object({
    force: z.boolean().describe('Re-analyse every track even if the sha1 matches a cached entry'),
  })
  .partial()
  .meta({ id: 'AlbumGeneratorAudioScanRequestDto' });

const AlbumGeneratorAudioScanResponseSchema = z
  .object({
    queued: z.literal(true).describe('Scan job accepted; check server logs / settings for progress'),
  })
  .meta({ id: 'AlbumGeneratorAudioScanResponseDto' });

export class AlbumGeneratorAudioScanRequestDto extends createZodDto(AlbumGeneratorAudioScanRequestSchema) {}
export class AlbumGeneratorAudioScanResponseDto extends createZodDto(AlbumGeneratorAudioScanResponseSchema) {}
