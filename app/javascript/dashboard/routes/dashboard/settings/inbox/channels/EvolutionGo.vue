<script setup>
import { ref, computed } from 'vue';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';
import router from '../../../../index';

import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();

const uiFlags = computed(() => getters['inboxes/getUIFlags'].value);

const inboxName = ref('');
const phoneNumber = ref('');
const alwaysOnline = ref(false);
const readMessages = ref(false);
const delayEnabled = ref(true);
const delayTime = ref(2);

const rules = {
  inboxName: { required },
  phoneNumber: { required, isPhoneE164OrEmpty },
};

const v$ = useVuelidate(rules, { inboxName, phoneNumber });

const createChannel = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const channel = await store.dispatch('inboxes/createChannel', {
      name: inboxName.value?.trim(),
      channel: {
        type: 'whatsapp',
        phone_number: phoneNumber.value,
        provider: 'evolution_go',
        provider_config: {
          always_online: alwaysOnline.value,
          read_messages: readMessages.value,
          delay_enabled: delayEnabled.value,
          delay_time: delayTime.value,
        },
      },
    });

    router.replace({
      name: 'settings_inboxes_add_agents',
      params: { page: 'new', inbox_id: channel.id },
    });
  } catch (error) {
    useAlert(
      error.message || t('INBOX_MGMT.ADD.WHATSAPP_LITE.API.ERROR_MESSAGE')
    );
  }
};
</script>

<template>
  <form class="flex flex-col flex-wrap mx-0" @submit.prevent="createChannel">
    <div class="flex-grow-0 flex-shrink-0">
      <label :class="{ error: v$.inboxName.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.INBOX_NAME.LABEL') }}
        <input
          v-model="inboxName"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP_LITE.INBOX_NAME.PLACEHOLDER')
          "
          @blur="v$.inboxName.$touch"
        />
        <span v-if="v$.inboxName.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.INBOX_NAME.ERROR') }}
        </span>
      </label>
    </div>

    <div class="flex-grow-0 flex-shrink-0">
      <label :class="{ error: v$.phoneNumber.$error }">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.PHONE_NUMBER.LABEL') }}
        <input
          v-model="phoneNumber"
          type="text"
          :placeholder="
            $t('INBOX_MGMT.ADD.WHATSAPP_LITE.PHONE_NUMBER.PLACEHOLDER')
          "
          @blur="v$.phoneNumber.$touch"
        />
        <span v-if="v$.phoneNumber.$error" class="message">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.PHONE_NUMBER.ERROR') }}
        </span>
      </label>
    </div>

    <div class="mt-6">
      <h3 class="mb-4 text-base font-medium text-n-slate-12">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.TITLE') }}
      </h3>

      <div
        class="flex flex-col gap-4 p-4 border rounded-lg border-n-weak bg-n-alpha-1"
      >
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                $t(
                  'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.ALWAYS_ONLINE.TITLE'
                )
              }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{
                $t(
                  'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.ALWAYS_ONLINE.DESC'
                )
              }}
            </span>
          </div>
          <WootSwitch v-model="alwaysOnline" />
        </div>

        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                $t(
                  'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.READ_MESSAGES.TITLE'
                )
              }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{
                $t(
                  'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.READ_MESSAGES.DESC'
                )
              }}
            </span>
          </div>
          <WootSwitch v-model="readMessages" />
        </div>

        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TITLE')
              }}
            </span>
            <span class="text-xs text-n-slate-10">
              {{
                $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.DESC')
              }}
            </span>
          </div>
          <WootSwitch v-model="delayEnabled" />
        </div>

        <NextInput
          v-if="delayEnabled"
          v-model="delayTime"
          type="number"
          :label="
            $t(
              'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TIME_LABEL'
            )
          "
          :placeholder="
            $t(
              'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TIME_PLACEHOLDER'
            )
          "
        />
      </div>
    </div>

    <div class="w-full mt-4">
      <NextButton
        :is-loading="uiFlags.isCreating"
        type="submit"
        solid
        blue
        :label="$t('INBOX_MGMT.ADD.WHATSAPP_LITE.SUBMIT_BUTTON')"
      />
    </div>
  </form>
</template>
