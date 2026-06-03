import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Put, StreamableFile } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Endpoint, HistoryBuilder } from 'src/decorators';
import {
  AlbumGeneratorOnDemandRequestDto,
  AlbumGeneratorOnDemandResponseDto,
  AlbumGeneratorUserConfigDto,
} from 'src/dtos/album-generator.dto';
import { AuthDto } from 'src/dtos/auth.dto';
import { ApiTag, Permission } from 'src/enum';
import { Auth, Authenticated } from 'src/middleware/auth.guard';
import { AlbumGeneratorService } from 'src/services/album-generator.service';
import { UUIDParamDto } from 'src/validation';

@ApiTags(ApiTag.AlbumGenerator)
@Controller('album-generator')
export class AlbumGeneratorController {
  constructor(private service: AlbumGeneratorService) {}

  @Get('config')
  @Authenticated()
  @Endpoint({
    summary: "Retrieve the current user's AI album generator settings",
    description:
      'Returns the opt-in flag, maxPerNight cap, and persistent hint list. Returns sensible defaults for users that have never set these.',
    history: new HistoryBuilder().added('v2'),
  })
  getAlbumGeneratorConfig(@Auth() auth: AuthDto): Promise<AlbumGeneratorUserConfigDto> {
    return this.service.getUserConfig(auth);
  }

  @Put('config')
  @Authenticated()
  @Endpoint({
    summary: "Update the current user's AI album generator settings",
    description:
      'Set opt-in, max nightly memories, and hint list. Hints are soft directives — they bias both candidate selection (via CLIP search) and the LLM prompt.',
    history: new HistoryBuilder().added('v2'),
  })
  updateAlbumGeneratorConfig(
    @Auth() auth: AuthDto,
    @Body() dto: AlbumGeneratorUserConfigDto,
  ): Promise<AlbumGeneratorUserConfigDto> {
    return this.service.updateUserConfig(auth, dto);
  }

  @Post('runs')
  @HttpCode(HttpStatus.ACCEPTED)
  @Authenticated()
  @Endpoint({
    summary: 'Queue an on-demand AI memory for a custom hint',
    description:
      'Triggers a one-off generation for the authenticated user. The provided hint is used verbatim — persistent hints, the admin theme vocabulary, the maxPerNight cap, and the recently-used filter are all ignored. The pipeline runs asynchronously; the new memory appears on the Memories page when CLIP search + clustering + LLM + ffmpeg finish (typically 1–3 minutes).',
    history: new HistoryBuilder().added('v2'),
  })
  triggerOnDemand(
    @Auth() auth: AuthDto,
    @Body() dto: AlbumGeneratorOnDemandRequestDto,
  ): Promise<AlbumGeneratorOnDemandResponseDto> {
    return this.service.triggerOnDemand(auth, dto.hint);
  }

  @Get('memories/:id/video')
  @Authenticated({ permission: Permission.MemoryRead })
  @Endpoint({
    summary: 'Stream the composed AI memory video',
    description:
      'Returns an mp4 stream of the slideshow video generated for an AI memory. Available only after the MemoryVideoCompose job has completed.',
    history: new HistoryBuilder().added('v2'),
  })
  getMemoryAiVideo(@Auth() auth: AuthDto, @Param() { id }: UUIDParamDto): Promise<StreamableFile> {
    return this.service.getMemoryVideoStream(auth, id);
  }
}
