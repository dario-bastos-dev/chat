<script setup>
import { computed } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  templates: { type: Array, default: () => [] },
});

defineEmits(['delete']);

const STATUS_CLASSES = {
  APPROVED: 'bg-n-teal-3 text-n-teal-11',
  PENDING: 'bg-n-amber-3 text-n-amber-11',
  REJECTED: 'bg-n-ruby-3 text-n-ruby-11',
  DISABLED: 'bg-n-ruby-3 text-n-ruby-11',
  PAUSED: 'bg-n-amber-3 text-n-amber-11',
};

const sortedTemplates = computed(() =>
  [...props.templates].sort((a, b) => a.name.localeCompare(b.name))
);

const statusClass = status =>
  STATUS_CLASSES[status?.toUpperCase()] || 'bg-n-slate-3 text-n-slate-11';

const bodyText = template =>
  template.components?.find(component => component.type === 'BODY')?.text || '';
</script>

<template>
  <div class="overflow-x-auto">
    <table class="min-w-full text-sm">
      <thead>
        <tr class="text-left text-n-slate-11">
          <th class="py-2 pr-4 font-medium">
            {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.TABLE.NAME') }}
          </th>
          <th class="py-2 pr-4 font-medium">
            {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.TABLE.CATEGORY') }}
          </th>
          <th class="py-2 pr-4 font-medium">
            {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.TABLE.LANGUAGE') }}
          </th>
          <th class="py-2 pr-4 font-medium">
            {{ $t('INBOX_MGMT.MESSAGE_TEMPLATES.TABLE.STATUS') }}
          </th>
          <th class="py-2 font-medium" />
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="template in sortedTemplates"
          :key="`${template.name}-${template.language}`"
          class="border-t border-n-weak"
        >
          <td class="py-3 pr-4 align-top">
            <span class="block font-medium text-n-slate-12">
              {{ template.name }}
            </span>
            <span class="block max-w-md truncate text-n-slate-11">
              {{ bodyText(template) }}
            </span>
          </td>
          <td class="py-3 pr-4 align-top text-n-slate-11">
            {{ template.category }}
          </td>
          <td class="py-3 pr-4 align-top text-n-slate-11">
            {{ template.language }}
          </td>
          <td class="py-3 pr-4 align-top">
            <span
              class="inline-flex px-2 py-0.5 text-xs font-medium rounded-full"
              :class="statusClass(template.status)"
            >
              {{ template.status }}
            </span>
          </td>
          <td class="py-3 align-top text-right">
            <NextButton
              variant="ghost"
              color="ruby"
              size="sm"
              icon="i-lucide-trash"
              @click="$emit('delete', template)"
            />
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
