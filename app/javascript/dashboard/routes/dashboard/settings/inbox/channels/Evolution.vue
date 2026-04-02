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

      ignoreGroups: false,
      alwaysOnline: false,
      readMessages: false,
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
        const evolutionChannel = await this.$store.dispatch(
          'inboxes/createChannel',
          {
            name: this.inboxName?.trim(),
            channel: {
              type: 'whatsapp',
              phone_number: this.phoneNumber,
              provider: 'evolution',
              provider_config: {
                reject_calls: false,
                msg_call: '',
                ignore_groups: this.ignoreGroups,
                always_online: this.alwaysOnline,
                read_messages: this.readMessages,
                read_status: false,
                sync_full_history: false,
                delay_enabled: true,
                delay_time: 2000,
              },
            },
          }
        );

        // Instance creation is triggered automatically by the backend via after_create callback
        // so we don't need to manually trigger it here anymore.

        router.replace({
          name: 'settings_inboxes_add_agents',
          params: {
            page: 'new',
            inbox_id: evolutionChannel.id,
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

    <!-- Evolution Behavior Settings -->
    <div class="mt-6">
      <h3 class="text-base font-medium text-n-slate-12 mb-4">
        {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.TITLE') }}
      </h3>

      <div
        class="flex flex-col gap-4 border border-n-slate-3 rounded-lg p-4 bg-n-alpha-1"
      >
        <!-- Ignore Groups -->
        <div class="flex items-center justify-between">
          <div class="flex flex-col">
            <span class="text-sm font-medium text-n-slate-12">{{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.IGNORE_GROUPS.TITLE'
              )
            }}</span>
            <span class="text-xs text-n-slate-10">{{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.IGNORE_GROUPS.DESC'
              )
            }}</span>
          </div>
          <WootSwitch v-model="ignoreGroups" />
        </div>

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
