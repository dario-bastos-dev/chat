<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';

const props = defineProps({
  sequence: {
    type: Object,
    required: true,
  },
});
defineEmits(['delete']);
const { t } = useI18n();

const activationLabel = computed(() => {
  if (props.sequence.activation_type === 'tag') {
    return `Tag: ${props.sequence.activation_tag}`;
  }
  if (props.sequence.activation_type === 'manual') {
    return t('MESSAGE_SEQUENCES.RULES.MANUAL');
  }
  return t('MESSAGE_SEQUENCES.RULES.ALWAYS');
});

const statusLabel = computed(() => {
  return props.sequence.active
    ? t('MESSAGE_SEQUENCES.TABLE.STATUS_ACTIVE', 'Ativa')
    : t('MESSAGE_SEQUENCES.TABLE.STATUS_INACTIVE', 'Inativa');
});
</script>

<template>
  <BaseTableRow :item="sequence">
    <template #default>
      <BaseTableCell class="max-w-0 min-w-0">
        <span class="text-body-main text-n-slate-12 truncate block">
          {{ sequence.name }}
        </span>
      </BaseTableCell>

      <BaseTableCell class="max-w-0">
        <span
          class="px-2 py-0.5 rounded text-xs bg-n-blue-3 text-n-blue-11 whitespace-nowrap"
        >
          {{ activationLabel }}
        </span>
      </BaseTableCell>

      <BaseTableCell class="max-w-0">
        <span
          class="px-2 py-0.5 rounded text-xs whitespace-nowrap"
          :class="
            sequence.active
              ? 'bg-n-green-3 text-n-green-11'
              : 'bg-n-slate-3 text-n-slate-11'
          "
        >
          {{ statusLabel }}
        </span>
      </BaseTableCell>

      <BaseTableCell align="end" class="w-24">
        <div class="flex gap-3 justify-end flex-shrink-0">
          <router-link
            :to="{
              name: 'message_sequences_edit',
              params: { sequenceId: sequence.id },
            }"
          >
            <Button
              v-tooltip.top="$t('MESSAGE_SEQUENCES.EDIT.TOOLTIP')"
              icon="i-woot-edit-pen"
              slate
              sm
            />
          </router-link>
          <Button
            v-tooltip.top="$t('MESSAGE_SEQUENCES.DELETE.TOOLTIP')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            @click="$emit('delete')"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>
