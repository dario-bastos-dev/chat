<script setup>
import { useAlert } from 'dashboard/composables';
import { picoSearch } from '@scmmishra/pico-search';
import SequencesTableRow from './SequencesTableRow.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import { BaseTable } from 'dashboard/components-next/table';

const getters = useStoreGetters();
const store = useStore();
const { t } = useI18n();

const showDeleteConfirmationPopup = ref(false);
const selectedSequence = ref({});
const searchQuery = ref('');

const records = computed(
  () => getters['messageSequences/getMessageSequences'].value
);
const uiFlags = computed(() => getters['messageSequences/getUIFlags'].value);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, ['name']);
});

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
    t('MESSAGE_SEQUENCES.TABLE.ACTIONS'),
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
        v-model:search-query="searchQuery"
        :title="$t('MESSAGE_SEQUENCES.HEADER')"
        :description="$t('MESSAGE_SEQUENCES.DESCRIPTION')"
        :search-placeholder="$t('MESSAGE_SEQUENCES.SEARCH_PLACEHOLDER')"
        feature-name="message_sequences"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('MESSAGE_SEQUENCES.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <router-link :to="{ name: 'message_sequences_new' }">
            <Button
              :label="$t('MESSAGE_SEQUENCES.NEW_BUTTON')"
              size="sm"
            />
          </router-link>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          searchQuery
            ? $t('MESSAGE_SEQUENCES.NO_RESULTS')
            : $t('MESSAGE_SEQUENCES.EMPTY')
        "
      >
        <template #row="{ items }">
          <SequencesTableRow
            v-for="sequence in items"
            :key="sequence.id"
            :sequence="sequence"
            @delete="openDeletePopup(sequence)"
          />
        </template>
      </BaseTable>
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
