<script lang="ts">
  import SettingAccordion from '$lib/components/shared-components/settings/SettingAccordion.svelte';
  import SettingInputField from '$lib/components/shared-components/settings/SettingInputField.svelte';
  import SettingSwitch from '$lib/components/shared-components/settings/SettingSwitch.svelte';
  import SettingButtonsRow from '$lib/components/shared-components/settings/SystemConfigButtonRow.svelte';
  import SettingSelect from './SettingSelect.svelte';
  import SettingTextarea from './SettingTextarea.svelte';
  import { SettingInputFieldType } from '$lib/constants';
  import FormatMessage from '$lib/elements/FormatMessage.svelte';
  import { featureFlagsManager } from '$lib/managers/feature-flags-manager.svelte';
  import { systemConfigManager } from '$lib/managers/system-config-manager.svelte';
  import { Link } from '@immich/ui';
  import { isEqual } from 'lodash-es';
  import { t } from 'svelte-i18n';
  import { fade } from 'svelte/transition';

  const disabled = $derived(featureFlagsManager.value.configFile);
  const config = $derived(systemConfigManager.value);
  let configToEdit = $state(systemConfigManager.cloneValue());

  // One theme per line. Kept in sync with the array via $effect so it
  // flows through SystemConfigButtonRow's pick(configToEdit, ['albumGenerator']).
  let themeVocabularyText = $state(configToEdit.albumGenerator.themeVocabulary.join('\n'));
  $effect(() => {
    const lines = themeVocabularyText
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
    if (!isEqual(lines, configToEdit.albumGenerator.themeVocabulary)) {
      configToEdit.albumGenerator.themeVocabulary = lines;
    }
  });

  let cronExpressionOptions = $derived([
    { text: $t('interval.night_at_midnight'), value: '0 0 * * *' },
    { text: $t('interval.night_at_twoam'), value: '0 2 * * *' },
    { text: $t('interval.day_at_onepm'), value: '0 13 * * *' },
    { text: $t('interval.hours', { values: { hours: 6 } }), value: '0 */6 * * *' },
  ]);
</script>

<div>
  <div in:fade={{ duration: 500 }}>
    <form autocomplete="off" onsubmit={(event) => event.preventDefault()}>
      <div class="ms-4 mt-4 flex flex-col gap-4">
        <SettingSwitch
          title={$t('admin.album_generator_enabled')}
          subtitle={$t('admin.album_generator_enabled_description')}
          {disabled}
          bind:checked={configToEdit.albumGenerator.enabled}
        />

        <hr />

        <SettingSelect
          options={cronExpressionOptions}
          disabled={disabled || !configToEdit.albumGenerator.enabled}
          name="expression"
          label={$t('admin.cron_expression_presets')}
          bind:value={configToEdit.albumGenerator.cronExpression}
        />

        <SettingInputField
          inputType={SettingInputFieldType.TEXT}
          required={true}
          disabled={disabled || !configToEdit.albumGenerator.enabled}
          label={$t('admin.cron_expression')}
          bind:value={configToEdit.albumGenerator.cronExpression}
          isEdited={configToEdit.albumGenerator.cronExpression !== config.albumGenerator.cronExpression}
        >
          {#snippet descriptionSnippet()}
            <p class="text-sm dark:text-immich-dark-fg">
              <FormatMessage key="admin.cron_expression_description">
                {#snippet children({ message })}
                  <Link
                    href="https://crontab.guru/#{configToEdit.albumGenerator.cronExpression.replaceAll(' ', '_')}"
                  >
                    {message}
                  </Link>
                {/snippet}
              </FormatMessage>
            </p>
          {/snippet}
        </SettingInputField>

        <SettingInputField
          inputType={SettingInputFieldType.NUMBER}
          label={$t('admin.album_generator_jitter_minutes')}
          description={$t('admin.album_generator_jitter_minutes_description')}
          bind:value={configToEdit.albumGenerator.jitterMinutes}
          min={0}
          max={360}
          disabled={disabled || !configToEdit.albumGenerator.enabled}
          isEdited={configToEdit.albumGenerator.jitterMinutes !== config.albumGenerator.jitterMinutes}
        />

        <SettingInputField
          inputType={SettingInputFieldType.NUMBER}
          label={$t('admin.album_generator_extra_runs_per_week')}
          description={$t('admin.album_generator_extra_runs_per_week_description')}
          bind:value={configToEdit.albumGenerator.extraRunsPerWeek}
          min={0}
          max={21}
          disabled={disabled || !configToEdit.albumGenerator.enabled}
          isEdited={configToEdit.albumGenerator.extraRunsPerWeek !== config.albumGenerator.extraRunsPerWeek}
        />

        <SettingAccordion
          key="album-generator-ollama"
          title={$t('admin.album_generator_ollama')}
          subtitle={$t('admin.album_generator_ollama_description')}
        >
          <div class="ms-4 mt-4 flex flex-col gap-4">
            <SettingInputField
              inputType={SettingInputFieldType.TEXT}
              required={true}
              disabled={disabled || !configToEdit.albumGenerator.enabled}
              label={$t('admin.album_generator_ollama_endpoint')}
              bind:value={configToEdit.albumGenerator.ollama.endpoint}
              isEdited={configToEdit.albumGenerator.ollama.endpoint !== config.albumGenerator.ollama.endpoint}
            />

            <SettingInputField
              inputType={SettingInputFieldType.TEXT}
              required={true}
              disabled={disabled || !configToEdit.albumGenerator.enabled}
              label={$t('admin.album_generator_ollama_text_model')}
              bind:value={configToEdit.albumGenerator.ollama.textModel}
              isEdited={configToEdit.albumGenerator.ollama.textModel !== config.albumGenerator.ollama.textModel}
            />

            <SettingInputField
              inputType={SettingInputFieldType.TEXT}
              required={true}
              disabled={disabled || !configToEdit.albumGenerator.enabled}
              label={$t('admin.album_generator_ollama_vision_model')}
              bind:value={configToEdit.albumGenerator.ollama.visionModel}
              isEdited={configToEdit.albumGenerator.ollama.visionModel !== config.albumGenerator.ollama.visionModel}
            />
          </div>
        </SettingAccordion>

        <SettingAccordion
          key="album-generator-themes"
          title={$t('admin.album_generator_theme_vocabulary')}
          subtitle={$t('admin.album_generator_theme_vocabulary_description')}
        >
          <div class="ms-4 mt-4 flex flex-col gap-4">
            <SettingTextarea
              label={$t('admin.album_generator_theme_vocabulary')}
              description={$t('admin.album_generator_theme_vocabulary_description')}
              bind:value={themeVocabularyText}
              disabled={disabled || !configToEdit.albumGenerator.enabled}
              isEdited={!isEqual(
                configToEdit.albumGenerator.themeVocabulary,
                config.albumGenerator.themeVocabulary,
              )}
            />
          </div>
        </SettingAccordion>

        <SettingAccordion
          key="album-generator-audio"
          title={$t('admin.album_generator_audio')}
          subtitle={$t('admin.album_generator_audio_description')}
        >
          <div class="ms-4 mt-4 flex flex-col gap-4">
            <SettingSwitch
              title={$t('admin.album_generator_audio_enabled')}
              bind:checked={configToEdit.albumGenerator.audio.enabled}
              disabled={disabled || !configToEdit.albumGenerator.enabled}
            />

            <SettingInputField
              inputType={SettingInputFieldType.TEXT}
              required={true}
              disabled={disabled ||
                !configToEdit.albumGenerator.enabled ||
                !configToEdit.albumGenerator.audio.enabled}
              label={$t('admin.album_generator_audio_library_path')}
              description={$t('admin.album_generator_audio_library_path_description')}
              bind:value={configToEdit.albumGenerator.audio.libraryPath}
              isEdited={configToEdit.albumGenerator.audio.libraryPath !== config.albumGenerator.audio.libraryPath}
            />

            <SettingInputField
              inputType={SettingInputFieldType.NUMBER}
              label={$t('admin.album_generator_audio_volume')}
              description={$t('admin.album_generator_audio_volume_description')}
              bind:value={configToEdit.albumGenerator.audio.volume}
              min={0}
              max={1}
              step="0.05"
              disabled={disabled ||
                !configToEdit.albumGenerator.enabled ||
                !configToEdit.albumGenerator.audio.enabled}
              isEdited={configToEdit.albumGenerator.audio.volume !== config.albumGenerator.audio.volume}
            />
          </div>
        </SettingAccordion>

        <SettingButtonsRow bind:configToEdit keys={['albumGenerator']} {disabled} />
      </div>
    </form>
  </div>
</div>
