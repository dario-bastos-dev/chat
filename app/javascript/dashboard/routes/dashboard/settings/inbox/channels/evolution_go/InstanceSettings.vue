<script>
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Modal from 'dashboard/components/Modal.vue';
import SettingsSection from 'dashboard/components/SettingsSection.vue';

export default {
  components: {
    NextButton,
    WootSwitch,
    NextInput,
    Modal,
    SettingsSection,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      evolutionConnected: false,
      connectionStatus: '',
      evolutionQRCode: '',
      pairingCode: '',
      showConnectOptions: false,
      showQRCodeModal: false,
      isLoadingQRCode: false,
      isDisconnecting: false,
      statusPollingInterval: null,
      isUpdatingSettings: false,
      settings: {
        always_online: false,
        read_messages: false,
        delay_enabled: true,
        delay_time: 2,
      },
      settingsList: [
        { key: 'always_online', i18n: 'ALWAYS_ONLINE' },
        { key: 'read_messages', i18n: 'READ_MESSAGES' },
      ],
    };
  },
  computed: {
    showQRCode() {
      return this.evolutionQRCode && this.connectionStatus !== 'open';
    },
    statusText() {
      const statusMap = {
        open: this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.CONNECTED'),
        close: this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.DISCONNECTED'),
        connecting: this.$t(
          'INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.CONNECTING'
        ),
      };
      return (
        statusMap[this.connectionStatus] ||
        this.connectionStatus ||
        this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.DISCONNECTED')
      );
    },
  },
  mounted() {
    this.initializeSettings();
    this.checkStatus();
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    initializeSettings() {
      const config = this.inbox.provider_config || {};
      let delayTime = config.delay_time || 2;
      // If legacy value is in ms, convert to seconds for display
      if (delayTime > 100) {
        delayTime = delayTime / 1000;
      }
      this.settings = {
        always_online: config.always_online || false,
        read_messages: config.read_messages || false,
        delay_enabled: config.delay_enabled !== false,
        delay_time: delayTime,
      };
    },
    async checkStatus() {
      try {
        const { data } = await InboxesAPI.getEvolutionGoStatus(this.inbox.id);
        this.connectionStatus = data.status || 'close';
        this.evolutionConnected = data.connected || false;
      } catch (error) {
        this.connectionStatus = 'close';
        this.evolutionConnected = false;
      }
    },
    async fetchQRCode() {
      this.isLoadingQRCode = true;
      this.evolutionQRCode = '';
      this.pairingCode = '';

      try {
        const { data } = await InboxesAPI.getEvolutionGoQRCode(this.inbox.id);

        if (!data.success) {
          useAlert(data.error || 'Erro ao buscar QR Code');
          return;
        }

        if (data.qr_code) {
          this.evolutionQRCode = data.qr_code;
          this.showQRCodeModal = true;
          this.startPolling();
        } else {
          useAlert('Evolution GO API não retornou QR Code');
        }
      } catch (error) {
        const errorMsg =
          error.response?.data?.error || error.message || 'Erro ao conectar';
        useAlert(errorMsg);
      } finally {
        this.isLoadingQRCode = false;
        this.showConnectOptions = false;
      }
    },
    async fetchPairingCode() {
      this.isLoadingQRCode = true;
      this.evolutionQRCode = '';
      this.pairingCode = '';

      try {
        const number = this.inbox.phone_number.replace(/^\+/, '');

        const { data } = await InboxesAPI.getEvolutionGoPairingCode(
          this.inbox.id,
          { number }
        );

        if (!data.success) {
          useAlert(data.error || 'Erro ao buscar Código');
          return;
        }

        if (data.pairing_code) {
          this.pairingCode = data.pairing_code;
          this.showQRCodeModal = true;
          this.startPolling();
        } else if (data.qr_code) {
          this.evolutionQRCode = data.qr_code;
          this.showQRCodeModal = true;
          this.startPolling();
        } else {
          useAlert('Evolution GO API não retornou Código nem QR Code');
        }
      } catch (error) {
        const errorMsg =
          error.response?.data?.error || error.message || 'Erro ao conectar';
        useAlert(errorMsg);
      } finally {
        this.isLoadingQRCode = false;
        this.showConnectOptions = false;
      }
    },
    toggleConnectOptions() {
      this.showConnectOptions = !this.showConnectOptions;
      this.evolutionQRCode = '';
      this.pairingCode = '';
    },
    closeQRCodeModal() {
      this.showQRCodeModal = false;
      this.evolutionQRCode = '';
      this.pairingCode = '';
      this.stopPolling();
    },
    async disconnectInstance() {
      this.isDisconnecting = true;
      try {
        const { data } = await InboxesAPI.disconnectEvolutionGo(this.inbox.id);

        if (data.success) {
          useAlert(this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.DISCONNECT_SUCCESS'));
          this.connectionStatus = 'close';
          this.evolutionConnected = false;
          this.evolutionQRCode = '';
          this.pairingCode = '';
          this.stopPolling();
        } else {
          useAlert(data.error || 'Erro ao desconectar');
        }
      } catch (error) {
        useAlert(error.response?.data?.error || 'Erro ao desconectar');
      } finally {
        this.isDisconnecting = false;
      }
    },
    startPolling() {
      if (this.statusPollingInterval) return;

      this.statusPollingInterval = setInterval(async () => {
        if (!this.evolutionConnected) {
          await this.checkStatus();
          if (this.evolutionConnected && this.showQRCodeModal) {
            this.showQRCodeModal = false;
            this.evolutionQRCode = '';
            this.pairingCode = '';
            this.stopPolling();
            useAlert(
              this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.CONNECTED')
            );
          }
        }
      }, 5000);
    },
    stopPolling() {
      if (this.statusPollingInterval) {
        clearInterval(this.statusPollingInterval);
        this.statusPollingInterval = null;
      }
    },
    async updateSettings() {
      this.isUpdatingSettings = true;
      try {
        const payload = {
          id: this.inbox.id,
          formData: false,
          channel: {
            provider: 'evolution_go',
            provider_config: this.settings,
          },
        };
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
      } finally {
        this.isUpdatingSettings = false;
      }
    },
  },
};
</script>

<template>
  <div class="mx-8">
    <SettingsSection
      :title="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.TITLE')"
      :sub-title="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.SUB_TITLE')"
    >
      <!-- Connection Status -->
      <div
        class="mb-8 p-4 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-100 dark:border-slate-700"
      >
        <h4
          class="text-base font-medium mb-4 text-slate-800 dark:text-slate-100"
        >
          {{ $t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.TITLE') }}
        </h4>

        <div v-if="connectionStatus === 'open'" class="flex flex-col gap-4">
          <div class="flex items-center text-green-600 gap-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-6 h-6"
            >
              <path
                fill-rule="evenodd"
                d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm13.36-1.814a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 12.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z"
                clip-rule="evenodd"
              />
            </svg>
            <span class="font-medium">{{ statusText }}</span>
          </div>
          <div>
            <NextButton
              :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.DISCONNECT_BUTTON')"
              color-scheme="alert"
              :is-loading="isDisconnecting"
              @click="disconnectInstance"
            />
          </div>
        </div>

        <div v-else class="flex flex-col gap-4">
          <div class="flex items-center text-red-600 gap-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-6 h-6"
            >
              <path
                fill-rule="evenodd"
                d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm-1.72 6.97a.75.75 0 10-1.06 1.06L10.94 12l-1.72 1.72a.75.75 0 101.06 1.06L12 13.06l1.72 1.72a.75.75 0 101.06-1.06L13.06 12l1.72-1.72a.75.75 0 10-1.06-1.06L12 10.94l-1.72-1.72z"
                clip-rule="evenodd"
              />
            </svg>
            <span class="font-medium">{{ statusText }}</span>
          </div>

          <div v-if="!showQRCode && !pairingCode" class="mt-2">
            <NextButton
              :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_BUTTON')"
              color-scheme="success"
              @click="toggleConnectOptions"
            />
          </div>

          <Modal v-model:show="showConnectOptions">
            <div class="p-8 relative">
              <!-- Loading overlay -->
              <div
                v-if="isLoadingQRCode"
                class="absolute inset-0 bg-black/50 rounded-lg flex items-center justify-center z-10"
              >
                <div class="flex flex-col items-center gap-3">
                  <svg
                    class="animate-spin h-10 w-10 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    />
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    />
                  </svg>
                  <span class="text-white text-sm font-medium"
                    >Carregando...</span
                  >
                </div>
              </div>

              <h2 class="text-lg font-semibold text-n-slate-12 mb-6">
                {{
                  $t('INBOX_MGMT.EVOLUTION_INSTANCE.SELECT_CONNECTION_METHOD')
                }}
              </h2>
              <div class="flex gap-3">
                <NextButton
                  :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_QR')"
                  color-scheme="primary"
                  class="flex-1"
                  :disabled="isLoadingQRCode"
                  @click="fetchQRCode"
                />
                <NextButton
                  :label="
                    $t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_PAIRING')
                  "
                  color-scheme="primary"
                  class="flex-1"
                  :disabled="isLoadingQRCode"
                  @click="fetchPairingCode"
                />
              </div>
            </div>
          </Modal>

          <!-- Modal for QR Code or Pairing Code -->
          <Modal v-model:show="showQRCodeModal">
            <div class="p-8 relative min-w-[320px]">
              <!-- QR Code content -->
              <div
                v-if="evolutionQRCode"
                class="flex flex-col items-center gap-4"
              >
                <h2 class="text-lg font-semibold text-n-slate-12">
                  {{ $t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_QR') }}
                </h2>
                <div class="p-4 bg-white rounded-lg shadow">
                  <img
                    :src="evolutionQRCode"
                    class="w-64 h-64 object-contain"
                    alt="QR Code"
                  />
                </div>
                <p class="text-sm text-n-slate-10 text-center">
                  {{ $t('INBOX_MGMT.FINISH.SCAN_QR_CODE') }}
                </p>
                <NextButton
                  :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CLOSE_BUTTON')"
                  color-scheme="secondary"
                  class="mt-2"
                  @click="closeQRCodeModal"
                />
              </div>

              <!-- Pairing Code content -->
              <div
                v-else-if="pairingCode"
                class="flex flex-col items-center gap-4"
              >
                <h2 class="text-lg font-semibold text-n-slate-12">
                  {{ $t('INBOX_MGMT.EVOLUTION_INSTANCE.PAIRING_CODE') }}
                </h2>
                <div class="p-6 bg-white rounded-lg shadow">
                  <h3
                    class="text-3xl font-bold tracking-widest text-center text-slate-800"
                  >
                    {{ pairingCode }}
                  </h3>
                </div>
                <p class="text-sm text-n-slate-10 text-center">
                  Digite este código no seu WhatsApp
                </p>
                <NextButton
                  :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CLOSE_BUTTON')"
                  color-scheme="secondary"
                  class="mt-2"
                  @click="closeQRCodeModal"
                />
              </div>
            </div>
          </Modal>
        </div>
      </div>

      <!-- Settings Switches -->
      <div class="mt-8">
        <h4
          class="text-base font-medium mb-4 text-slate-800 dark:text-slate-100"
        >
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.TITLE') }}
        </h4>
        <div
          class="flex flex-col gap-4 border border-slate-200 dark:border-slate-700 rounded-lg p-4 bg-slate-50 dark:bg-slate-800"
        >
          <template v-for="setting in settingsList" :key="setting.key">
            <div class="flex items-center justify-between">
              <div class="flex flex-col">
                <span
                  class="text-sm font-medium text-slate-700 dark:text-slate-200"
                >
                  {{
                    $t(
                      `INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.${setting.i18n}.TITLE`
                    )
                  }}
                </span>
                <span class="text-xs text-slate-500 dark:text-slate-400">
                  {{
                    $t(
                      `INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.${setting.i18n}.DESC`
                    )
                  }}
                </span>
              </div>
              <WootSwitch v-model="settings[setting.key]" />
            </div>
          </template>

          <!-- Delay Setting -->
          <div class="flex items-center justify-between">
            <div class="flex flex-col">
              <span
                class="text-sm font-medium text-slate-700 dark:text-slate-200"
              >
                {{
                  $t(
                    'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TITLE'
                  )
                }}
              </span>
              <span class="text-xs text-slate-500 dark:text-slate-400">
                {{
                  $t(
                    'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.DESC'
                  )
                }}
              </span>
            </div>
            <WootSwitch v-model="settings.delay_enabled" />
          </div>
          <div
            v-if="settings.delay_enabled"
            class="ml-0 mt-2 p-2"
          >
            <NextInput
              v-model="settings.delay_time"
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
        <div class="mt-4">
          <NextButton
            :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
            :is-loading="isUpdatingSettings"
            @click="updateSettings"
          />
        </div>
      </div>
    </SettingsSection>
  </div>
</template>
