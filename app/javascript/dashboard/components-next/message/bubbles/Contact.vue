<script setup>
import { computed, ref, nextTick } from 'vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useMessageContext } from '../provider.js';
import BaseAttachmentBubble from './BaseAttachment.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';

import {
  DuplicateContactException,
  ExceptionWithMessage,
} from 'shared/helpers/CustomErrors';

const { attachments, inboxId } = useMessageContext();

const $store = useStore();
const { t } = useI18n();

const attachment = computed(() => {
  return attachments.value[0];
});

const phoneNumber = computed(() => {
  return attachment.value.fallbackTitle;
});

const contactName = computed(() => {
  const { meta } = attachment.value ?? {};
  const { firstName, lastName } = meta ?? {};
  return `${firstName ?? ''} ${lastName ?? ''}`.trim();
});

const formattedPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\s|-|[A-Za-z]/g, '');
});

const rawPhoneNumber = computed(() => {
  return phoneNumber.value.replace(/\D/g, '');
});

function getContactObject() {
  const contactItem = {
    name: contactName.value,
    phone_number: `+${rawPhoneNumber.value}`,
  };
  return contactItem;
}

async function filterContactByNumber(searchCandidate) {
  const query = {
    attribute_key: 'phone_number',
    filter_operator: 'equal_to',
    values: [searchCandidate],
    attribute_model: 'standard',
    custom_attribute_type: '',
  };

  const queryPayload = { payload: [query] };
  const contacts = await $store.dispatch('contacts/filter', {
    queryPayload,
    resetState: false,
  });
  return contacts.shift();
}

function openContactNewTab(contactId) {
  const accountId = window.location.pathname.split('/')[3];
  const url = `/app/accounts/${accountId}/contacts/${contactId}`;
  window.open(url, '_blank');
}

async function findOrCreateContact() {
  const contact = await filterContactByNumber(rawPhoneNumber.value);
  if (contact) return contact;

  const createdContact = await $store.dispatch(
    'contacts/create',
    getContactObject()
  );
  useAlert(t('CONTACT_FORM.SUCCESS_MESSAGE'));
  return createdContact;
}

function alertContactError(error) {
  if (error instanceof DuplicateContactException) {
    if (error.data.includes('phone_number')) {
      useAlert(t('CONTACT_FORM.FORM.PHONE_NUMBER.DUPLICATE'));
    }
  } else if (error instanceof ExceptionWithMessage) {
    useAlert(error.data);
  } else {
    useAlert(t('CONTACT_FORM.ERROR_MESSAGE'));
  }
}

async function addContact() {
  try {
    const contact = await findOrCreateContact();
    openContactNewTab(contact.id);
  } catch (error) {
    alertContactError(error);
  }
}

const composeRef = ref(null);
const composeContactId = ref(null);
const isStartingConversation = ref(false);

// The compose form reads the contact, and the inboxes that can reach it, from the store.
// fetchContactableInbox runs last so its list is not overwritten by the one show returns.
async function startConversation() {
  // A second click while the first is loading would try to create the same contact twice.
  if (isStartingConversation.value) return;

  isStartingConversation.value = true;
  try {
    const { id } = await findOrCreateContact();
    await $store.dispatch('contacts/show', { id });
    await $store.dispatch('contacts/fetchContactableInbox', id);
    composeContactId.value = String(id);
    await nextTick();
    composeRef.value.open();
  } catch (error) {
    alertContactError(error);
  } finally {
    isStartingConversation.value = false;
  }
}

const action = computed(() => ({
  label: t('CONVERSATION.SAVE_CONTACT'),
  onClick: addContact,
}));
</script>

<template>
  <BaseAttachmentBubble
    icon="i-teenyicons-user-circle-solid"
    icon-bg-color="bg-[#D6409F]"
    sender-translation-key="CONVERSATION.SHARED_ATTACHMENT.CONTACT"
    :title="contactName"
    :content="phoneNumber"
    :action="formattedPhoneNumber ? action : null"
  >
    <template v-if="formattedPhoneNumber" #actions>
      <ComposeConversation
        ref="composeRef"
        :contact-id="composeContactId"
        :inbox-id="inboxId"
      >
        <template #trigger>
          <!-- .stop: the popover opens once the contact is loaded, not on click -->
          <button
            class="w-full bg-n-solid-3 px-4 py-2 rounded-lg text-sm text-center border border-n-container disabled:opacity-50 disabled:cursor-wait"
            :disabled="isStartingConversation"
            @click.stop="startConversation"
          >
            {{ t('CONVERSATION.START_CONVERSATION') }}
          </button>
        </template>
      </ComposeConversation>
    </template>
  </BaseAttachmentBubble>
</template>
