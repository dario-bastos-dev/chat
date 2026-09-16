<script setup>
import { computed } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  modelValue: { type: String, default: 'personal' },
  teamId: { type: [Number, String], default: null },
  teams: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'update:teamId']);

const options = computed(() => [
  {
    key: 'global',
    label: 'VISIBILITY_SELECTOR.OPTIONS.GLOBAL.LABEL',
    description: 'VISIBILITY_SELECTOR.OPTIONS.GLOBAL.DESCRIPTION',
  },
  {
    key: 'team_visibility',
    label: 'VISIBILITY_SELECTOR.OPTIONS.TEAM.LABEL',
    description: 'VISIBILITY_SELECTOR.OPTIONS.TEAM.DESCRIPTION',
  },
  {
    key: 'personal',
    label: 'VISIBILITY_SELECTOR.OPTIONS.PERSONAL.LABEL',
    description: 'VISIBILITY_SELECTOR.OPTIONS.PERSONAL.DESCRIPTION',
  },
]);

const isActive = key => props.modelValue === key;

const selectVisibility = key => {
  if (props.disabled) return;
  emit('update:modelValue', key);
  if (key !== 'team_visibility') {
    emit('update:teamId', null);
  }
};

const onTeamChange = event => {
  const { value } = event.target;
  emit('update:teamId', value ? Number(value) : null);
};
</script>

<template>
  <div class="w-full">
    <p class="block m-0 mb-1 text-sm font-medium text-n-slate-12">
      {{ $t('VISIBILITY_SELECTOR.LABEL') }}
    </p>
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-2">
      <button
        v-for="option in options"
        :key="option.key"
        type="button"
        class="p-2 relative rounded-md border border-solid justify-between items-start gap-1 flex flex-col text-start"
        :class="
          isActive(option.key)
            ? 'bg-n-blue-2 dark:bg-n-blue-1 border-n-blue-3 dark:border-n-blue-4'
            : 'bg-white dark:bg-n-solid-2 border-n-weak dark:border-n-strong'
        "
        :disabled="disabled"
        @click="selectVisibility(option.key)"
      >
        <div class="flex items-center gap-2 min-w-0 justify-between w-full">
          <p class="block m-0 text-heading-3 text-n-slate-12 line-clamp-1">
            {{ $t(option.label) }}
          </p>
          <Icon
            v-if="isActive(option.key)"
            icon="i-lucide-circle-check-big"
            class="text-n-brand size-4"
          />
        </div>
        <p class="m-0 text-n-slate-11 text-label-small">
          {{ $t(option.description) }}
        </p>
      </button>
    </div>
    <div v-if="modelValue === 'team_visibility'" class="mt-2">
      <label class="block m-0 text-sm font-medium text-n-slate-12">
        {{ $t('VISIBILITY_SELECTOR.TEAM.LABEL') }}
        <select
          :value="teamId || ''"
          :disabled="disabled"
          @change="onTeamChange"
        >
          <option value="" disabled>
            {{ $t('VISIBILITY_SELECTOR.TEAM.PLACEHOLDER') }}
          </option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>
      <p v-if="!teams.length" class="mt-1 text-n-slate-11 text-label-small">
        {{ $t('VISIBILITY_SELECTOR.TEAM.EMPTY') }}
      </p>
    </div>
  </div>
</template>
