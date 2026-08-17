<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';

import NextButton from 'dashboard/components-next/button/Button.vue';
import WootSwitch from 'dashboard/components-next/switch/Switch.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Modal from 'dashboard/components/Modal.vue';
import SettingsSection from 'dashboard/components/SettingsSection.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const store = useStore();
const { t } = useI18n();

const STATUS_POLL_INTERVAL = 5000;
const TOGGLES = [
  { key: 'always_online', i18n: 'ALWAYS_ONLINE' },
  { key: 'read_messages', i18n: 'READ_MESSAGES' },
];

const connectionStatus = ref('');
const isConnected = ref(false);
const qrCode = ref('');
const pairingCode = ref('');
const showConnectOptions = ref(false);
const showCodeModal = ref(false);
const isLoadingCode = ref(false);
const isDisconnecting = ref(false);
const isUpdatingSettings = ref(false);
const pollingInterval = ref(null);

const settings = ref({
  always_online: false,
  read_messages: false,
  delay_enabled: true,
  delay_time: 2,
});

const statusText = computed(() => {
  const map = {
    open: t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.STATUS.CONNECTED'),
    close: t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.STATUS.DISCONNECTED'),
    connecting: t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.STATUS.CONNECTING'),
  };
  return (
    map[connectionStatus.value] ||
    t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.STATUS.DISCONNECTED')
  );
});

const errorMessage = (error, fallbackKey) =>
  error?.response?.data?.error ||
  t(`INBOX_MGMT.EVOLUTION_GO_INSTANCE.${fallbackKey}`);

const stopPolling = () => {
  if (!pollingInterval.value) return;
  clearInterval(pollingInterval.value);
  pollingInterval.value = null;
};

const checkStatus = async () => {
  try {
    const { data } = await InboxesAPI.getEvolutionGoStatus(props.inbox.id);
    connectionStatus.value = data.status || 'close';
    isConnected.value = data.connected || false;
  } catch (error) {
    connectionStatus.value = 'close';
    isConnected.value = false;
  }
};

const closeCodeModal = () => {
  showCodeModal.value = false;
  qrCode.value = '';
  pairingCode.value = '';
  stopPolling();
};

const startPolling = () => {
  if (pollingInterval.value) return;

  pollingInterval.value = setInterval(async () => {
    if (isConnected.value) return;

    await checkStatus();
    if (!isConnected.value || !showCodeModal.value) return;

    closeCodeModal();
    useAlert(t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.STATUS.CONNECTED'));
  }, STATUS_POLL_INTERVAL);
};

const fetchQrCode = async () => {
  isLoadingCode.value = true;
  qrCode.value = '';
  pairingCode.value = '';

  try {
    const { data } = await InboxesAPI.getEvolutionGoQRCode(props.inbox.id);

    if (!data.success) {
      useAlert(data.error || t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.QR_ERROR'));
      return;
    }

    if (!data.qr_code) {
      useAlert(t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.QR_EMPTY'));
      return;
    }

    qrCode.value = data.qr_code;
    showCodeModal.value = true;
    startPolling();
  } catch (error) {
    useAlert(errorMessage(error, 'CONNECT_ERROR'));
  } finally {
    isLoadingCode.value = false;
    showConnectOptions.value = false;
  }
};

const fetchPairingCode = async () => {
  isLoadingCode.value = true;
  qrCode.value = '';
  pairingCode.value = '';

  try {
    const number = props.inbox.phone_number.replace(/^\+/, '');
    const { data } = await InboxesAPI.getEvolutionGoPairingCode(
      props.inbox.id,
      { number }
    );

    if (!data.success) {
      useAlert(
        data.error || t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.PAIRING_ERROR')
      );
      return;
    }

    if (!data.pairing_code && !data.qr_code) {
      useAlert(t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.PAIRING_EMPTY'));
      return;
    }

    pairingCode.value = data.pairing_code || '';
    qrCode.value = data.pairing_code ? '' : data.qr_code;
    showCodeModal.value = true;
    startPolling();
  } catch (error) {
    useAlert(errorMessage(error, 'CONNECT_ERROR'));
  } finally {
    isLoadingCode.value = false;
    showConnectOptions.value = false;
  }
};

const disconnectInstance = async () => {
  isDisconnecting.value = true;
  try {
    const { data } = await InboxesAPI.disconnectEvolutionGo(props.inbox.id);

    if (!data.success) {
      useAlert(
        data.error || t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.DISCONNECT_ERROR')
      );
      return;
    }

    useAlert(t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.DISCONNECT_SUCCESS'));
    connectionStatus.value = 'close';
    isConnected.value = false;
    closeCodeModal();
  } catch (error) {
    useAlert(errorMessage(error, 'DISCONNECT_ERROR'));
  } finally {
    isDisconnecting.value = false;
  }
};

const updateSettings = async () => {
  isUpdatingSettings.value = true;
  try {
    // Only the behaviour toggles: instance credentials and connection state belong to the
    // server, and echoing a stale copy of them back would rewind whatever it wrote since.
    await store.dispatch('inboxes/updateInbox', {
      id: props.inbox.id,
      formData: false,
      channel: {
        provider: 'evolution_go',
        provider_config: { ...settings.value },
      },
    });
    useAlert(t('INBOX_MGMT.EDIT.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.EDIT.API.ERROR_MESSAGE'));
  } finally {
    isUpdatingSettings.value = false;
  }
};

// provider_config only records what we last tried to write, so the toggles are realigned with
// what the instance is actually running. Failing is not worth an alert: the stored values are
// still a reasonable view.
const syncSettingsFromInstance = async () => {
  try {
    const { data } = await InboxesAPI.getEvolutionGoSettings(props.inbox.id);
    if (!data.success || !data.settings) return;

    settings.value.always_online = Boolean(data.settings.alwaysOnline);
    settings.value.read_messages = Boolean(data.settings.readMessages);
  } catch (error) {
    // keep the stored values
  }
};

onMounted(() => {
  const config = props.inbox.provider_config || {};
  settings.value = {
    always_online: config.always_online || false,
    read_messages: config.read_messages || false,
    delay_enabled: config.delay_enabled !== false,
    // Always seconds — legacy millisecond values were normalized by migration.
    delay_time: config.delay_time || 2,
  };
  checkStatus();
  syncSettingsFromInstance();
});

onBeforeUnmount(stopPolling);
</script>

<template>
  <div class="mx-8">
    <SettingsSection
      :title="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.TITLE')"
      :sub-title="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.SUB_TITLE')"
    >
      <div class="p-4 mb-8 border rounded-lg border-n-weak bg-n-alpha-1">
        <h4 class="mb-4 text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.STATUS.TITLE') }}
        </h4>

        <div class="flex flex-col gap-4">
          <div
            class="flex items-center gap-2 font-medium"
            :class="
              connectionStatus === 'open' ? 'text-n-teal-11' : 'text-n-ruby-11'
            "
          >
            <Icon
              :icon="
                connectionStatus === 'open' ? 'i-lucide-check' : 'i-lucide-x'
              "
              class="size-5"
            />
            <span>{{ statusText }}</span>
          </div>

          <div v-if="connectionStatus === 'open'">
            <NextButton
              ruby
              :label="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.DISCONNECT_BUTTON')"
              :is-loading="isDisconnecting"
              @click="disconnectInstance"
            />
          </div>
          <div v-else>
            <NextButton
              teal
              :label="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.CONNECT_BUTTON')"
              @click="showConnectOptions = true"
            />
          </div>
        </div>

        <Modal v-model:show="showConnectOptions">
          <div class="relative p-8">
            <div
              v-if="isLoadingCode"
              class="absolute inset-0 z-10 flex items-center justify-center rounded-lg bg-n-alpha-3"
            >
              <span class="text-sm font-medium text-n-slate-12">
                {{ $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.LOADING') }}
              </span>
            </div>

            <h2 class="mb-6 text-lg font-semibold text-n-slate-12">
              {{
                $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.SELECT_CONNECTION_METHOD')
              }}
            </h2>
            <div class="flex gap-3">
              <NextButton
                solid
                blue
                class="flex-1"
                :label="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.CONNECT_WITH_QR')"
                :disabled="isLoadingCode"
                @click="fetchQrCode"
              />
              <NextButton
                faded
                blue
                class="flex-1"
                :label="
                  $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.CONNECT_WITH_PAIRING')
                "
                :disabled="isLoadingCode"
                @click="fetchPairingCode"
              />
            </div>
          </div>
        </Modal>

        <Modal v-model:show="showCodeModal">
          <div class="p-8 min-w-[320px]">
            <div v-if="qrCode" class="flex flex-col items-center gap-4">
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.CONNECT_WITH_QR') }}
              </h2>
              <div class="p-4 bg-white rounded-lg">
                <img :src="qrCode" class="object-contain size-64" alt="" />
              </div>
              <p class="text-sm text-center text-n-slate-11">
                {{ $t('INBOX_MGMT.FINISH.SCAN_QR_CODE') }}
              </p>
              <NextButton
                faded
                slate
                :label="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.CLOSE_BUTTON')"
                @click="closeCodeModal"
              />
            </div>

            <div
              v-else-if="pairingCode"
              class="flex flex-col items-center gap-4"
            >
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.PAIRING_CODE') }}
              </h2>
              <div class="p-6 rounded-lg bg-n-alpha-2">
                <h3
                  class="text-3xl font-bold tracking-widest text-center text-n-slate-12"
                >
                  {{ pairingCode }}
                </h3>
              </div>
              <p class="text-sm text-center text-n-slate-11">
                {{ $t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.PAIRING_CODE_HINT') }}
              </p>
              <NextButton
                faded
                slate
                :label="$t('INBOX_MGMT.EVOLUTION_GO_INSTANCE.CLOSE_BUTTON')"
                @click="closeCodeModal"
              />
            </div>
          </div>
        </Modal>
      </div>

      <div class="mt-8">
        <h4 class="mb-4 text-base font-medium text-n-slate-12">
          {{ $t('INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.TITLE') }}
        </h4>
        <div
          class="flex flex-col gap-4 p-4 border rounded-lg border-n-weak bg-n-alpha-1"
        >
          <div
            v-for="toggle in TOGGLES"
            :key="toggle.key"
            class="flex items-center justify-between"
          >
            <div class="flex flex-col">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  $t(
                    `INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.${toggle.i18n}.TITLE`
                  )
                }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{
                  $t(
                    `INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.${toggle.i18n}.DESC`
                  )
                }}
              </span>
            </div>
            <WootSwitch v-model="settings[toggle.key]" />
          </div>

          <div class="flex items-center justify-between">
            <div class="flex flex-col">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  $t(
                    'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.TITLE'
                  )
                }}
              </span>
              <span class="text-xs text-n-slate-10">
                {{
                  $t(
                    'INBOX_MGMT.ADD.WHATSAPP_LITE.EVOLUTION_SETTINGS.DELAY.DESC'
                  )
                }}
              </span>
            </div>
            <WootSwitch v-model="settings.delay_enabled" />
          </div>

          <NextInput
            v-if="settings.delay_enabled"
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
