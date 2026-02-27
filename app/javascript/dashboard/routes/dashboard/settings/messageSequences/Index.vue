<script setup>
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const showDeleteConfirmationPopup = ref(false);
const selectedSequence = ref({});

const records = computed(
  () => getters['messageSequences/getMessageSequences'].value
);
const uiFlags = computed(() => getters['messageSequences/getUIFlags'].value);

const deleteMessage = computed(() => ` ${selectedSequence.value.name}?`);

onMounted(() => {
  store.dispatch('messageSequences/get');
});

const deleteSequence = async id => {
  try {
    await store.dispatch('messageSequences/delete', id);
    useAlert(t('MESSAGE_SEQUENCES.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(t('MESSAGE_SEQUENCES.DELETE.ERROR'));
  }
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  selectedSequence.value = response;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const confirmDeletion = () => {
  closeDeletePopup();
  deleteSequence(selectedSequence.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('MESSAGE_SEQUENCES.TABLE.NAME'),
    t('MESSAGE_SEQUENCES.TABLE.ACTIVATION'),
    t('MESSAGE_SEQUENCES.TABLE.STATUS'),
  ];
});
</script>

<template>
  <SettingsLayout
    :no-records-message="$t('MESSAGE_SEQUENCES.EMPTY')"
    :no-records-found="!records.length"
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('MESSAGE_SEQUENCES.LOADING')"
    feature-name="message_sequences"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('MESSAGE_SEQUENCES.HEADER')"
        :description="$t('MESSAGE_SEQUENCES.DESCRIPTION')"
        feature-name="message_sequences"
      >
        <template #actions>
          <router-link :to="{ name: 'message_sequences_new' }">
            <Button
              icon="i-lucide-circle-plus"
              :label="$t('MESSAGE_SEQUENCES.NEW_BUTTON')"
            />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <table class="min-w-full divide-y divide-n-weak">
        <thead>
          <th
            v-for="thHeader in tableHeaders"
            :key="thHeader"
            class="py-4 ltr:pr-4 rtl:pl-4 text-left font-semibold text-n-slate-11"
          >
            {{ thHeader }}
          </th>
        </thead>
        <tbody class="divide-y divide-n-weak text-n-slate-11">
          <tr
            v-for="sequence in records"
            :key="sequence.id"
            class="hover:bg-n-alpha-1 transition-colors"
          >
            <td class="py-3 ltr:pr-4 rtl:pl-4 font-medium text-n-slate-12">
              {{ sequence.name }}
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4">
              <span
                class="px-2 py-0.5 rounded text-xs bg-n-blue-3 text-n-blue-11"
              >
                {{
                  sequence.activation_type === 'tag'
                    ? `Tag: ${sequence.activation_tag}`
                    : $t('MESSAGE_SEQUENCES.RULES.ALWAYS')
                }}
              </span>
            </td>
            <td class="py-3 ltr:pr-4 rtl:pl-4">
              <span
                class="px-2 py-0.5 rounded text-xs"
                :class="
                  sequence.active
                    ? 'bg-n-green-3 text-n-green-11'
                    : 'bg-n-slate-3 text-n-slate-11'
                "
              >
                {{ sequence.active ? 'Ativa' : 'Inativa' }}
              </span>
            </td>
            <td class="py-3 ltr:pl-4 rtl:pr-4 text-right">
              <div class="flex items-center justify-end gap-2">
                <router-link
                  :to="{
                    name: 'message_sequences_edit',
                    params: { sequenceId: sequence.id },
                  }"
                  class="text-n-slate-10 hover:text-n-blue-11"
                >
                  <span class="i-lucide-pencil block size-4" />
                </router-link>
                <button
                  class="text-n-slate-10 hover:text-n-red-10 px-1 py-0 clear"
                  @click="openDeletePopup(sequence)"
                >
                  <span class="i-lucide-trash block size-4" />
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <woot-delete-modal
        v-model:show="showDeleteConfirmationPopup"
        :on-close="closeDeletePopup"
        :on-confirm="confirmDeletion"
        :title="$t('MESSAGE_SEQUENCES.DELETE.TITLE')"
        :message="$t('MESSAGE_SEQUENCES.DELETE.MESSAGE')"
        :message-value="deleteMessage"
        :confirm-text="$t('MESSAGE_SEQUENCES.DELETE.CONFIRM')"
        :reject-text="$t('MESSAGE_SEQUENCES.DELETE.CANCEL')"
      />
    </template>
  </SettingsLayout>
</template>
