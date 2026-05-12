<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required } from '@vuelidate/validators';
import router from '../../../../index';
import { isPhoneE164OrEmpty } from 'shared/helpers/Validators';

import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';

export default {
  components: {
    NextButton,
    WootSwitch,
    NextInput,
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      inboxName: '',
      phoneNumber: '',
      alwaysOnline: false,
      readMessages: false,
      delayEnabled: true,
      delayTime: 2,
    };
  },
  computed: {
    ...mapGetters({ uiFlags: 'inboxes/getUIFlags' }),
  },
  validations: {
    inboxName: { required },
    phoneNumber: { required, isPhoneE164OrEmpty },
  },
  methods: {
    async createChannel() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }

      try {
        const channel = await this.$store.dispatch('inboxes/createChannel', {
          name: this.inboxName?.trim(),
          channel: {
            type: 'whatsapp',
            phone_number: this.phoneNumber,
            provider: 'evolution_go',
            provider_config: {
              always_online: this.alwaysOnline,
              read_messages: this.readMessages,
              delay_enabled: this.delayEnabled,
              delay_time: this.delayTime,
            },
          },
        });

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: channel.id,
          },
        });
      } catch (error) {
        useAlert(
          error.message ||
            this.$t('INBOX_MGMT.ADD.WHATSAPP_LITE.API.ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <form class="flex flex-wrap flex-col mx-0" @submit.prevent="createChannel()">
    <div class="flex-shrink-0 flex-grow-0">
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

    <div class="flex-shrink-0 flex-grow-0">
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

    <!-- Evolution GO Behavior Settings -->
    <div class="mt-6">
      <h3 class="text-base font-medium text-n-slate-12 mb-4">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.TITLE') }}
      </h3>

      <div
        class="flex flex-col gap-4 border border-n-slate-3 rounded-lg p-4 bg-n-alpha-1"
      >
        <!-- Always Online -->
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">{{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.ALWAYS_ONLINE.TITLE'
              )
            }}</span>
            <span class="text-xs text-n-slate-10">{{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.ALWAYS_ONLINE.DESC'
              )
            }}</span>
          </div>
          <WootSwitch v-model="alwaysOnline" />
        </div>

        <!-- Read Messages -->
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">{{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.READ_MESSAGES.TITLE'
              )
            }}</span>
            <span class="text-xs text-n-slate-10">{{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.READ_MESSAGES.DESC'
              )
            }}</span>
          </div>
          <WootSwitch v-model="readMessages" />
        </div>

        <!-- Delay Setting -->
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">{{
              $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TITLE')
            }}</span>
            <span class="text-xs text-n-slate-10">{{
              $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.DESC')
            }}</span>
          </div>
          <WootSwitch v-model="delayEnabled" />
        </div>

        <div v-if="delayEnabled" class="ml-0 mt-2 p-2">
          <NextInput
            v-model="delayTime"
            type="number"
            :label="$t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TIME_LABEL')"
            :placeholder="$t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TIME_PLACEHOLDER')"
          />
        </div>
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
