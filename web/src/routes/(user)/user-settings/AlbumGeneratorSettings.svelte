<script lang="ts">
  import { handleError } from '$lib/utils/handle-error';
  import { getAlbumGeneratorConfig, triggerOnDemand, updateAlbumGeneratorConfig } from '@immich/sdk';
  import { Button, Field, Switch, toastManager } from '@immich/ui';
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { fade } from 'svelte/transition';

  let optIn = $state(false);
  let maxPerNight = $state(2);
  let hints = $state<string[]>([]);
  let newHint = $state('');
  let loading = $state(true);

  onMount(async () => {
    try {
      const config = await getAlbumGeneratorConfig();
      optIn = config.optIn;
      maxPerNight = config.maxPerNight;
      hints = [...config.hints];
    } catch (error) {
      handleError(error, $t('ai_album_generator_load_failed'));
    } finally {
      loading = false;
    }
  });

  const addHint = () => {
    const trimmed = newHint.trim();
    if (!trimmed) return;
    if (hints.includes(trimmed)) {
      newHint = '';
      return;
    }
    if (hints.length >= 20) {
      toastManager.primary($t('ai_album_generator_max_hints_reached'));
      return;
    }
    hints = [...hints, trimmed];
    newHint = '';
  };

  const removeHint = (hint: string) => {
    hints = hints.filter((h) => h !== hint);
  };

  const onHintKeydown = (event: KeyboardEvent) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      addHint();
    }
  };

  const handleSave = async () => {
    try {
      await updateAlbumGeneratorConfig({
        albumGeneratorUserConfigDto: { optIn, maxPerNight, hints },
      });
      toastManager.primary($t('saved_settings'));
    } catch (error) {
      handleError(error, $t('ai_album_generator_save_failed'));
    }
  };

  const onsubmit = (event: Event) => {
    event.preventDefault();
  };

  let onDemandPrompt = $state('');
  let onDemandSubmitting = $state(false);
  const handleGenerateOnDemand = async () => {
    const prompt = onDemandPrompt.trim();
    if (prompt.length < 2) {
      toastManager.primary($t('ai_album_generator_on_demand_prompt_too_short'));
      return;
    }
    try {
      onDemandSubmitting = true;
      await triggerOnDemand({ albumGeneratorOnDemandRequestDto: { hint: prompt } });
      toastManager.primary($t('ai_album_generator_on_demand_queued'));
      onDemandPrompt = '';
    } catch (error) {
      handleError(error, $t('ai_album_generator_on_demand_failed'));
    } finally {
      onDemandSubmitting = false;
    }
  };
  const onPromptKeydown = (event: KeyboardEvent) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      handleGenerateOnDemand();
    }
  };
</script>

<section class="my-4">
  <div in:fade={{ duration: 500 }}>
    {#if loading}
      <p class="text-sm text-gray-500">{$t('loading')}</p>
    {:else}
      <div class="mb-6 rounded-xl border border-immich-primary/20 bg-immich-primary/5 p-4">
        <p class="text-sm font-medium">{$t('ai_album_generator_on_demand_title')}</p>
        <p class="mt-1 mb-3 text-xs text-gray-500 max-w-xl">
          {$t('ai_album_generator_on_demand_description')}
        </p>
        <div class="flex gap-2">
          <input
            type="text"
            placeholder={$t('ai_album_generator_on_demand_placeholder')}
            bind:value={onDemandPrompt}
            onkeydown={onPromptKeydown}
            disabled={onDemandSubmitting}
            maxlength="200"
            class="flex-1 rounded border bg-immich-bg px-2 py-1 text-sm"
          />
          <Button
            shape="round"
            size="small"
            onclick={handleGenerateOnDemand}
            disabled={onDemandSubmitting || onDemandPrompt.trim().length < 2}
          >
            {onDemandSubmitting
              ? $t('ai_album_generator_on_demand_submitting')
              : $t('ai_album_generator_on_demand_generate')}
          </Button>
        </div>
      </div>

      <form autocomplete="off" {onsubmit}>
        <div class="flex flex-col gap-6 sm:ms-8">
          <Field
            label={$t('ai_album_generator_enabled')}
            description={$t('ai_album_generator_enabled_description')}
          >
            <Switch bind:checked={optIn} />
          </Field>

          <Field
            label={$t('ai_album_generator_max_per_night')}
            description={$t('ai_album_generator_max_per_night_description')}
          >
            <input
              type="number"
              min="1"
              max="10"
              bind:value={maxPerNight}
              class="rounded border bg-immich-bg px-2 py-1 text-sm w-20"
              disabled={!optIn}
            />
          </Field>

          <div class="flex flex-col gap-2" class:opacity-50={!optIn}>
            <label class="text-sm font-medium">{$t('ai_album_generator_hints')}</label>
            <p class="text-xs text-gray-500 max-w-xl">
              {$t('ai_album_generator_hints_description')}
            </p>
            <div class="flex flex-wrap gap-2">
              {#each hints as hint (hint)}
                <span
                  class="inline-flex items-center gap-1 rounded-full bg-immich-primary/10 px-3 py-1 text-xs"
                >
                  {hint}
                  <button
                    type="button"
                    class="text-xs leading-none hover:text-immich-error"
                    aria-label={$t('ai_album_generator_remove_hint', { values: { hint } })}
                    onclick={() => removeHint(hint)}
                    disabled={!optIn}
                  >
                    ✕
                  </button>
                </span>
              {/each}
              {#if hints.length === 0}
                <span class="text-xs text-gray-400 italic">{$t('ai_album_generator_hints_empty')}</span>
              {/if}
            </div>
            <div class="flex gap-2">
              <input
                type="text"
                placeholder={$t('ai_album_generator_hints_placeholder')}
                bind:value={newHint}
                onkeydown={onHintKeydown}
                disabled={!optIn}
                maxlength="80"
                class="flex-1 rounded border bg-immich-bg px-2 py-1 text-sm"
              />
              <Button
                shape="round"
                size="small"
                color="secondary"
                onclick={addHint}
                disabled={!optIn || newHint.trim().length === 0}
              >
                {$t('add')}
              </Button>
            </div>
          </div>
        </div>

        <div class="mt-4 flex justify-end">
          <Button shape="round" type="submit" size="small" onclick={() => handleSave()}>
            {$t('save')}
          </Button>
        </div>
      </form>
    {/if}
  </div>
</section>
