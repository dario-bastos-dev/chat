<script setup>
import { computed } from 'vue';

defineProps({
  stages: { type: Array, default: () => [] },
  agents: { type: Array, default: () => [] },
  labels: { type: Array, default: () => [] },
  customFields: { type: Array, default: () => [] },
  hasActiveFilters: { type: Boolean, default: false },
  showUnassigned: { type: Boolean, default: false },
});

const emit = defineEmits(['clear']);

const filters = defineModel({ type: Object, required: true });

// Cada campo emite o objeto inteiro com so aquele valor trocado, para o board
// continuar observando um unico objeto de filtros.
const field = key =>
  computed({
    get: () => filters.value[key],
    set: value => {
      filters.value = { ...filters.value, [key]: value };
    },
  });

const stageId = field('stageId');
const assigneeId = field('assigneeId');
const status = field('status');
const tag = field('tag');
const minValue = field('minValue');
const maxValue = field('maxValue');
const createdFrom = field('createdFrom');
const createdTo = field('createdTo');
const customFieldValue = field('customFieldValue');

// O valor digitado pertence ao campo anterior; aplicado ao novo, o filtro
// buscaria algo que nada tem a ver com ele.
const customFieldKey = computed({
  get: () => filters.value.customFieldKey,
  set: value => {
    filters.value = {
      ...filters.value,
      customFieldKey: value,
      customFieldValue: '',
    };
  },
});

const LABEL_CLASS =
  'text-[10px] font-bold text-n-slate-11 uppercase tracking-wider';
const SELECT_CLASS =
  'w-full px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8';
const INPUT_CLASS =
  'flex-1 min-w-0 px-3 py-1.5 text-xs bg-n-alpha-1 border border-n-weak rounded-lg text-n-slate-12 placeholder-n-slate-11 focus:border-n-brand focus:ring-1 focus:ring-n-brand transition-colors duration-150 h-8';
</script>

<template>
  <div
    class="absolute left-0 right-0 top-full mt-2 z-50 bg-n-solid-2 border border-n-weak rounded-xl shadow-xl p-4 flex flex-col gap-4 text-left max-h-[70vh] overflow-y-auto"
  >
    <div class="flex items-center justify-between pb-2 border-b border-n-weak">
      <span class="text-xs font-bold text-n-slate-12">
        {{ $t('CRM.FILTERS.TITLE') }}
      </span>
      <button
        v-if="hasActiveFilters"
        data-test="clear-filters"
        class="text-[11px] font-semibold text-n-ruby-9 hover:text-n-ruby-10 cursor-pointer"
        @click="emit('clear')"
      >
        {{ $t('CRM.FILTERS.CLEAR') }}
      </button>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="deal-filter-stage" :class="LABEL_CLASS">
        {{ $t('CRM.FILTERS.BY_STAGE') }}
      </label>
      <select id="deal-filter-stage" v-model="stageId" :class="SELECT_CLASS">
        <option :value="null">{{ $t('CRM.FILTERS.ALL_STAGES') }}</option>
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="deal-filter-assignee" :class="LABEL_CLASS">
        {{ $t('CRM.FILTERS.BY_ASSIGNEE') }}
      </label>
      <select
        id="deal-filter-assignee"
        v-model="assigneeId"
        :class="SELECT_CLASS"
      >
        <option :value="null">{{ $t('CRM.FILTERS.ALL_ASSIGNEES') }}</option>
        <!-- Espelha Deals::Finder::UNASSIGNED no backend. -->
        <option v-if="showUnassigned" value="none">
          {{ $t('CRM.FILTERS.UNASSIGNED') }}
        </option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.name }}
        </option>
      </select>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="deal-filter-status" :class="LABEL_CLASS">
        {{ $t('CRM.FILTERS.BY_STATUS') }}
      </label>
      <select id="deal-filter-status" v-model="status" :class="SELECT_CLASS">
        <option :value="null">{{ $t('CRM.FILTERS.ALL_STATUSES') }}</option>
        <option value="open">{{ $t('CRM.DEALS.STATUS_OPEN') }}</option>
        <option value="won">{{ $t('CRM.DEALS.STATUS_WON') }}</option>
        <option value="lost">{{ $t('CRM.DEALS.STATUS_LOST') }}</option>
      </select>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="deal-filter-tag" :class="LABEL_CLASS">
        {{ $t('CRM.FILTERS.BY_TAG') }}
      </label>
      <select id="deal-filter-tag" v-model="tag" :class="SELECT_CLASS">
        <option :value="null">{{ $t('CRM.FILTERS.ALL_TAGS') }}</option>
        <option v-for="label in labels" :key="label.id" :value="label.title">
          {{ label.title }}
        </option>
      </select>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="deal-filter-min-value" :class="LABEL_CLASS">
        {{ $t('CRM.DEALS.FILTER_VALUE_RANGE') }}
      </label>
      <div class="flex gap-2">
        <input
          id="deal-filter-min-value"
          v-model.number="minValue"
          type="number"
          min="0"
          :placeholder="$t('CRM.DEALS.FILTER_MIN')"
          :class="INPUT_CLASS"
        />
        <input
          v-model.number="maxValue"
          type="number"
          min="0"
          :placeholder="$t('CRM.DEALS.FILTER_MAX')"
          :aria-label="$t('CRM.DEALS.FILTER_MAX')"
          :class="INPUT_CLASS"
        />
      </div>
    </div>

    <div class="flex flex-col gap-1.5">
      <label for="deal-filter-created-from" :class="LABEL_CLASS">
        {{ $t('CRM.FILTERS.CREATED_AT') }}
      </label>
      <div class="flex gap-2">
        <input
          id="deal-filter-created-from"
          v-model="createdFrom"
          type="date"
          :max="createdTo || undefined"
          :aria-label="$t('CRM.FILTERS.CREATED_FROM')"
          :title="$t('CRM.FILTERS.CREATED_FROM')"
          :class="INPUT_CLASS"
        />
        <input
          id="deal-filter-created-to"
          v-model="createdTo"
          type="date"
          :min="createdFrom || undefined"
          :aria-label="$t('CRM.FILTERS.CREATED_TO')"
          :title="$t('CRM.FILTERS.CREATED_TO')"
          :class="INPUT_CLASS"
        />
      </div>
    </div>

    <div v-if="customFields.length > 0" class="flex flex-col gap-1.5">
      <label for="deal-filter-custom-field" :class="LABEL_CLASS">
        {{ $t('CRM.FILTERS.CUSTOM_FIELD') }}
      </label>
      <div class="flex gap-2">
        <select
          id="deal-filter-custom-field"
          v-model="customFieldKey"
          class="flex-1 min-w-0"
          :class="SELECT_CLASS"
        >
          <option :value="null">{{ $t('CRM.FILTERS.NO_FIELD') }}</option>
          <option
            v-for="customField in customFields"
            :key="customField.key"
            :value="customField.key"
          >
            {{ customField.name }}
          </option>
        </select>
        <input
          v-if="customFieldKey"
          v-model="customFieldValue"
          type="text"
          :placeholder="$t('CRM.FILTERS.VALUE_PLACEHOLDER')"
          :aria-label="$t('CRM.FILTERS.VALUE_PLACEHOLDER')"
          :class="INPUT_CLASS"
        />
      </div>
    </div>
  </div>
</template>
