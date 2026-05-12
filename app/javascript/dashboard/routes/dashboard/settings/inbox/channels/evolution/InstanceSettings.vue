<script>
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Modal from 'dashboard/components/Modal.vue';
import ModalHeader from 'dashboard/components/ModalHeader.vue';
import SettingsSection from 'dashboard/components/SettingsSection.vue';

export default {
  components: {
    NextButton,
    WootSwitch,
    NextInput,
    Modal,
    ModalHeader,
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
      qrRefreshInterval: null,
      statusPollingInterval: null,
      isUpdatingSettings: false,
      settings: {
        reject_calls: false,
        msg_call: '',
        ignore_groups: false,
        always_online: false,
        read_messages: false,
        read_status: false,
        sync_full_history: false,
        delay_enabled: true,
        delay_time: 2,
      },
      settingsList: [
        { key: 'ignore_groups', i18n: 'IGNORE_GROUPS' },
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
        connecting: this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.CONNECTING'),
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
        reject_calls: false,
        msg_call: '',
        ignore_groups: config.ignore_groups || false,
        always_online: config.always_online || false,
        read_messages: config.read_messages || false,
        read_status: false,
        sync_full_history: false,
        delay_enabled: config.delay_enabled !== false,
        delay_time: delayTime,
      };
    },
    async checkStatus() {
      try {
        const { data } = await InboxesAPI.getEvolutionStatus(this.inbox.id);
        this.connectionStatus = data.status || 'close';
        this.evolutionConnected = data.connected || false;
        console.log(
          '[Evolution] Status loaded:',
          this.connectionStatus,
          'Connected:',
          this.evolutionConnected
        );
      } catch (error) {
        console.error('[Evolution] Status check error:', error);
        this.connectionStatus = 'close';
        this.evolutionConnected = false;
      }
    },
    async fetchQRCode() {
      this.isLoadingQRCode = true;
      this.evolutionQRCode = '';
      this.pairingCode = '';

      try {
        console.log('[Evolution] ===== QR CODE REQUEST =====');
        console.log('[Evolution] Inbox ID:', this.inbox.id);

        const { data } = await InboxesAPI.getEvolutionQRCode(this.inbox.id);

        console.log('[Evolution] ===== RESPONSE RECEIVED =====');
        console.log('[Evolution] Full response:', data);
        console.log('[Evolution] Success:', data.success);
        console.log('[Evolution] Has qr_code:', !!data.qr_code);
        console.log('[Evolution] Has pairing_code:', !!data.pairing_code);

        // Se houve erro, mostra mensagem
        if (!data.success) {
          const errorMsg = data.error || 'Erro ao buscar QR Code';
          console.error('[Evolution] ❌ Error:', errorMsg);
          useAlert(errorMsg);
          return;
        }

        // Se recebeu QR Code, usa QR Code
        if (data.qr_code) {
          console.log('[Evolution] ✅ QR Code received!');
          console.log('[Evolution] QR Code length:', data.qr_code.length);
          console.log(
            '[Evolution] QR Code starts with:',
            data.qr_code.substring(0, 50)
          );
          console.log('[Evolution] Setting evolutionQRCode...');

          this.evolutionQRCode = data.qr_code;

          console.log(
            '[Evolution] evolutionQRCode value:',
            this.evolutionQRCode.substring(0, 50)
          );
          console.log('[Evolution] showQRCode computed:', this.showQRCode);

          this.showQRCodeModal = true;
          this.startPolling();
          return;
        }

        // Se recebeu Pairing Code, usa Pairing Code
        if (data.pairing_code) {
          console.log(
            '[Evolution] ✅ Pairing code received:',
            data.pairing_code
          );
          this.pairingCode = data.pairing_code;
          this.showQRCodeModal = true;
          this.startPolling();
          return;
        }

        // Se não recebeu nenhum, erro
        console.error('[Evolution] ❌ No QR code or pairing code in response');
        useAlert('Evolution API não retornou QR Code nem Código');
      } catch (error) {
        console.error('[Evolution] ❌ Exception:', error);
        console.error('[Evolution] Error details:', {
          message: error.message,
          response: error.response?.data,
          status: error.response?.status,
        });
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
        console.log(
          '[Evolution] Requesting pairing code for inbox:',
          this.inbox.id,
          'number:',
          number
        );

        const { data } = await InboxesAPI.getEvolutionQRCode(this.inbox.id, {
          number,
        });

        console.log('[Evolution] Response received:', data);

        // Se houve erro, mostra mensagem
        if (!data.success) {
          const errorMsg = data.error || 'Erro ao buscar Código';
          console.error('[Evolution] Error:', errorMsg);
          useAlert(errorMsg);
          return;
        }

        // Se recebeu Pairing Code, usa Pairing Code (prioridade para pairing)
        if (data.pairing_code) {
          console.log('[Evolution] Pairing code received:', data.pairing_code);
          this.pairingCode = data.pairing_code;
          this.showQRCodeModal = true;
          this.startPolling();
          return;
        }

        // Se recebeu QR Code, usa QR Code
        if (data.qr_code) {
          console.log('[Evolution] QR Code received (fallback)');
          this.evolutionQRCode = data.qr_code;
          this.showQRCodeModal = true;
          this.startPolling();
          return;
        }

        // Se não recebeu nenhum, erro
        console.error('[Evolution] No pairing code or QR code in response');
        useAlert('Evolution API não retornou Código nem QR Code');
      } catch (error) {
        console.error('[Evolution] Exception:', error);
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
        console.log('[Evolution] Disconnecting instance...');
        const { data } = await InboxesAPI.disconnectEvolution(this.inbox.id);

        if (data.success) {
          console.log('[Evolution] Instance disconnected');
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
        console.error('[Evolution] Error disconnecting:', error);
        useAlert(error.response?.data?.error || 'Erro ao desconectar');
      } finally {
        this.isDisconnecting = false;
      }
    },
    startPolling() {
      if (this.qrRefreshInterval || this.statusPollingInterval) return;

      // Polling para verificar status a cada 5 segundos
      this.statusPollingInterval = setInterval(async () => {
        if (!this.evolutionConnected) {
          await this.checkStatus();
          // Se na checagem descobrir que conectou, removemos o modal
          if (this.evolutionConnected && this.showQRCodeModal) {
            this.showQRCodeModal = false;
            this.evolutionQRCode = '';
            this.pairingCode = '';
            this.stopPolling();
            useAlert(this.$t('INBOX_MGMT.EVOLUTION_INSTANCE.STATUS.CONNECTED'));
          }
        }
      }, 5000);

      // Refresh do QR code a cada 40 segundos (somente se modal estiver aberto)
      this.qrRefreshInterval = setInterval(async () => {
        if (
          this.showQRCodeModal &&
          this.evolutionQRCode &&
          !this.evolutionConnected
        ) {
          await this.refreshQRCode();
        }
      }, 40000);
    },
    async refreshQRCode() {
      try {
        console.log('[Evolution] Refreshing QR code...');
        const { data } = await InboxesAPI.getEvolutionQRCode(this.inbox.id);

        if (data.success && data.qr_code) {
          console.log('[Evolution] QR Code refreshed successfully');
          this.evolutionQRCode = data.qr_code;
        } else if (data.status === 'open' || data.connected) {
          console.log(
            '[Evolution] ✅ Connected during refresh! Closing modal...'
          );
          this.connectionStatus = 'open';
          this.evolutionConnected = true;
          this.showQRCodeModal = false;
          this.evolutionQRCode = '';
          this.pairingCode = '';
          this.stopPolling();
        }
      } catch (error) {
        console.error('[Evolution] Error refreshing QR code:', error);
      }
    },
    stopPolling() {
      if (this.qrRefreshInterval) {
        clearInterval(this.qrRefreshInterval);
        this.qrRefreshInterval = null;
      }
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
          formData: false, // Importante: não usar FormData para provider_config
          channel: {
            provider: 'evolution',
            provider_config: this.settings,
          },
        };
        console.log('[Evolution] Updating settings:', payload);
        await this.$store.dispatch('inboxes/updateInbox', payload);
        useAlert(this.$t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
      } catch (error) {
        console.error('[Evolution] Error updating settings:', error);
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
      :title="$t('INBOX_MGMT.EVOLUTION_INSTANCE.TITLE')"
      :sub-title="$t('INBOX_MGMT.EVOLUTION_INSTANCE.SUB_TITLE')"
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

          <!-- Botão Desconectar quando conectado -->
          <div>
            <NextButton
              :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.DISCONNECT_BUTTON')"
              @click="disconnectInstance"
              color-scheme="alert"
              :isLoading="isDisconnecting"
            />
          </div>
        </div>

        <div
          v-else-if="connectionStatus === 'connecting'"
          class="flex flex-col gap-4"
        >
          <div class="flex items-center text-yellow-600 gap-2">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-6 h-6"
            >
              <path
                fill-rule="evenodd"
                d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zM12.75 6a.75.75 0 00-1.5 0v6c0 .414.336.75.75.75h4.5a.75.75 0 000-1.5h-3.75V6z"
                clip-rule="evenodd"
              />
            </svg>
            <span class="font-medium">
              {{ statusText }}
            </span>
          </div>

          <!-- Botões Conectar e Desconectar para status connecting -->
          <div v-if="!showQRCode && !pairingCode" class="flex gap-3">
            <NextButton
              :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_BUTTON')"
              @click="toggleConnectOptions"
              color-scheme="success"
            />
            <NextButton
              :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.DISCONNECT_BUTTON')"
              @click="disconnectInstance"
              color-scheme="alert"
              :isLoading="isDisconnecting"
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
              @click="toggleConnectOptions"
              color-scheme="success"
            />
          </div>

          <Modal v-model:show="showConnectOptions">
            <div class="p-8 relative">
              <!-- Overlay de carregamento -->
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
                  @click="fetchQRCode"
                  color-scheme="primary"
                  class="flex-1"
                  :disabled="isLoadingQRCode"
                />
                <NextButton
                  :label="
                    $t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_PAIRING')
                  "
                  @click="fetchPairingCode"
                  color-scheme="primary"
                  class="flex-1"
                  :disabled="isLoadingQRCode"
                />
              </div>
            </div>
          </Modal>

          <!-- Modal para exibir QR Code ou Código de Pareamento -->
          <Modal v-model:show="showQRCodeModal">
            <div class="p-8 relative min-w-[320px]">
              <!-- Conteúdo do QR Code -->
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
                  @click="closeQRCodeModal"
                  color-scheme="secondary"
                  class="mt-2"
                />
              </div>

              <!-- Conteúdo do Código de Pareamento -->
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
                  @click="closeQRCodeModal"
                  color-scheme="secondary"
                  class="mt-2"
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
            <div
              v-if="setting.key === 'reject_calls' && settings.reject_calls"
              class="ml-0 mt-2 p-2"
            >
              <NextInput
                v-model="settings.msg_call"
                type="text"
                :label="
                  $t(
                    'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.REJECT_CALLS.MSG_LABEL'
                  )
                "
                :placeholder="
                  $t(
                    'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.REJECT_CALLS.MSG_PLACEHOLDER'
                  )
                "
              />
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
            @click="updateSettings"
            :isLoading="isUpdatingSettings"
          />
        </div>
      </div>
    </SettingsSection>
  </div>
</template>
