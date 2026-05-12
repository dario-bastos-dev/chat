<script setup>
import { computed, onMounted, onUnmounted, reactive, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import QRCode from 'qrcode';
import EmptyState from '../../../../components/widgets/EmptyState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import DuplicateInboxBanner from './channels/instagram/DuplicateInboxBanner.vue';
import EmailInboxFinish from './channels/emailChannels/EmailInboxFinish.vue';
import { useInbox } from 'dashboard/composables/useInbox';
import { INBOX_TYPES } from 'dashboard/helper/inbox';
import InboxesAPI from 'dashboard/api/inboxes';

const { t } = useI18n();
const route = useRoute();
const store = useStore();

const qrCodes = reactive({
  whatsapp: '',
  messenger: '',
  telegram: '',
});

// Evolution state
const evolutionQRCode = ref('');
const evolutionPairingCode = ref('');
const showConnectOptions = ref(false);
const evolutionConnected = ref(false);
const evolutionLoading = ref(false);
const evolutionError = ref('');
const evolutionPollingInterval = ref(null);
const evolutionQRRefreshInterval = ref(null);

// Evolution GO state
const evoGoQRCode = ref('');
const evoGoPairingCode = ref('');
const showEvoGoConnectOptions = ref(false);
const evoGoConnected = ref(false);
const evoGoLoading = ref(false);
const evoGoError = ref('');
const evoGoPollingInterval = ref(null);
const evoGoQRRefreshInterval = ref(null);

const currentInbox = computed(() =>
  store.getters['inboxes/getInbox'](route.params.inbox_id)
);

// Use useInbox composable with the inbox ID
const {
  isAWhatsAppCloudChannel,
  isATwilioChannel,
  isASmsInbox,
  isALineChannel,
  isAnEmailChannel,
  isAWhatsAppChannel,
  isAFacebookInbox,
  isATelegramChannel,
  isATwilioWhatsAppChannel,
} = useInbox(route.params.inbox_id);

const hasDuplicateInstagramInbox = computed(() => {
  const instagramId = currentInbox.value.instagram_id;
  const facebookInbox =
    store.getters['inboxes/getFacebookInboxByInstagramId'](instagramId);

  return (
    currentInbox.value.channel_type === INBOX_TYPES.INSTAGRAM && facebookInbox
  );
});

const shouldShowWhatsAppWebhookDetails = computed(() => {
  return (
    isAWhatsAppCloudChannel.value &&
    currentInbox.value.provider_config?.source !== 'embedded_signup'
  );
});

const isWhatsAppEmbeddedSignup = computed(() => {
  return (
    isAWhatsAppCloudChannel.value &&
    currentInbox.value.provider_config?.source === 'embedded_signup'
  );
});

const isEvolutionChannel = computed(() => {
  return (
    isAWhatsAppChannel.value && currentInbox.value.provider === 'evolution'
  );
});

const isEvolutionGoChannel = computed(() => {
  return (
    isAWhatsAppChannel.value && currentInbox.value.provider === 'evolution_go'
  );
});

const isEvolutionApiConfigured = computed(() => {
  return window.chatwootConfig?.evolutionApiConfigured === true;
});

const message = computed(() => {
  if (isATwilioChannel.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.TWILIO.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (isASmsInbox.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.SMS.BANDWIDTH.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (isALineChannel.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.LINE_CHANNEL.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (isAWhatsAppCloudChannel.value && shouldShowWhatsAppWebhookDetails.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.SUBTITLE'
    )}`;
  }

  if (currentInbox.value.web_widget_script) {
    return t('INBOX_MGMT.FINISH.WEBSITE_SUCCESS');
  }

  if (isWhatsAppEmbeddedSignup.value) {
    return `${t('INBOX_MGMT.FINISH.MESSAGE')}. ${t(
      'INBOX_MGMT.FINISH.WHATSAPP_QR_INSTRUCTION'
    )}`;
  }

  return t('INBOX_MGMT.FINISH.MESSAGE');
});

async function generateQRCode(platform, identifier) {
  if (!identifier || !identifier.trim()) {
    // eslint-disable-next-line no-console
    console.warn(`Invalid identifier for ${platform} QR code`);
    return;
  }

  try {
    const platformUrls = {
      whatsapp: id => `https://wa.me/${id}`,
      messenger: id => `https://m.me/${id}`,
      telegram: id => `https://t.me/${id}`,
    };

    const url = platformUrls[platform](identifier);
    const qrDataUrl = await QRCode.toDataURL(url);
    qrCodes[platform] = qrDataUrl;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(`Error generating ${platform} QR code:`, error);
    qrCodes[platform] = '';
  }
}

async function generateQRCodes() {
  if (!currentInbox.value) return;

  // WhatsApp (both Cloud and Twilio)
  if (currentInbox.value.phone_number && isAWhatsAppChannel.value) {
    // For Twilio WhatsApp, phone_number format is "whatsapp:+1234567890"
    // Extract just the phone number part for QR code generation
    const phoneNumber = currentInbox.value.phone_number.replace(
      'whatsapp:',
      ''
    );
    await generateQRCode('whatsapp', phoneNumber);
  }

  // Facebook Messenger
  if (currentInbox.value.page_id && isAFacebookInbox.value) {
    await generateQRCode('messenger', currentInbox.value.page_id);
  }

  // Telegram
  if (isATelegramChannel.value && currentInbox.value.bot_name) {
    await generateQRCode('telegram', currentInbox.value.bot_name);
  }
}

// Evolution connection functions
async function createEvolutionInstance() {
  if (!isEvolutionChannel.value) return;

  evolutionLoading.value = true;
  evolutionError.value = '';

  try {
    const { data } = await InboxesAPI.createEvolutionInstance(
      route.params.inbox_id
    );
    if (data.success) {
      showConnectOptions.value = true;
    } else {
      evolutionError.value = data.error || 'Failed to create instance';
    }
  } catch (error) {
    evolutionError.value =
      error.message || 'Failed to create Evolution instance';
  } finally {
    evolutionLoading.value = false;
  }
}

async function fetchEvolutionQRCode() {
  if (!isEvolutionChannel.value) return;

  evolutionLoading.value = true;
  evolutionQRCode.value = '';
  evolutionPairingCode.value = '';

  try {
    console.log('[Evolution] Requesting QR code');
    const { data } = await InboxesAPI.getEvolutionQRCode(route.params.inbox_id);
    console.log('[Evolution] Response:', data);

    if (!data.success) {
      console.error('[Evolution] Error:', data.error);
      return;
    }

    if (data.qr_code) {
      console.log('[Evolution] QR Code received');
      evolutionQRCode.value = data.qr_code;
      startEvolutionPolling();
    } else if (data.pairing_code) {
      console.log('[Evolution] Pairing code received');
      evolutionPairingCode.value = data.pairing_code;
      startEvolutionPolling();
    }
  } catch (error) {
    console.error('[Evolution] Exception:', error);
  } finally {
    evolutionLoading.value = false;
  }
}

async function fetchEvolutionPairingCode() {
  if (!isEvolutionChannel.value) return;

  evolutionLoading.value = true;
  evolutionQRCode.value = '';
  evolutionPairingCode.value = '';

  try {
    const number = currentInbox.value.phone_number.replace(/^\+/, '');
    console.log('[Evolution] Requesting pairing code, number:', number);

    const { data } = await InboxesAPI.getEvolutionQRCode(
      route.params.inbox_id,
      { number }
    );
    console.log('[Evolution] Response:', data);

    if (!data.success) {
      console.error('[Evolution] Error:', data.error);
      return;
    }

    if (data.pairing_code) {
      console.log('[Evolution] Pairing code received');
      evolutionPairingCode.value = data.pairing_code;
      startEvolutionPolling();
    } else if (data.qr_code) {
      console.log('[Evolution] QR Code received (fallback)');
      evolutionQRCode.value = data.qr_code;
      startEvolutionPolling();
    }
  } catch (error) {
    console.error('[Evolution] Exception:', error);
  } finally {
    evolutionLoading.value = false;
  }
}

async function checkEvolutionStatus() {
  if (!isEvolutionChannel.value) return;

  try {
    const { data } = await InboxesAPI.getEvolutionStatus(route.params.inbox_id);
    if (data.connected) {
      evolutionConnected.value = true;
      stopEvolutionPolling();
    }
  } catch (error) {
    console.log('Status check error:', error.message);
  }
}

function startEvolutionPolling() {
  if (evolutionPollingInterval.value) return;

  // Polling para verificar status a cada 5 segundos
  evolutionPollingInterval.value = setInterval(() => {
    if (!evolutionConnected.value) {
      checkEvolutionStatus();
    }
  }, 5000);

  // Refresh do QR code a cada 40 segundos
  evolutionQRRefreshInterval.value = setInterval(async () => {
    if (evolutionQRCode.value && !evolutionConnected.value) {
      console.log('[Evolution] Refreshing QR code...');
      try {
        const { data } = await InboxesAPI.getEvolutionQRCode(
          route.params.inbox_id
        );
        if (data.success && data.qr_code) {
          console.log('[Evolution] QR Code refreshed');
          evolutionQRCode.value = data.qr_code;
        } else if (data.status === 'open') {
          console.log('[Evolution] Already connected');
          evolutionConnected.value = true;
          stopEvolutionPolling();
        }
      } catch (error) {
        console.error('[Evolution] Error refreshing QR code:', error);
      }
    }
  }, 40000);
}

function stopEvolutionPolling() {
  if (evolutionPollingInterval.value) {
    clearInterval(evolutionPollingInterval.value);
    evolutionPollingInterval.value = null;
  }
  if (evolutionQRRefreshInterval.value) {
    clearInterval(evolutionQRRefreshInterval.value);
    evolutionQRRefreshInterval.value = null;
  }
}

async function connectEvolution() {
  evolutionError.value = '';
  await createEvolutionInstance();
}

// --- Evolution GO connection functions ---

async function fetchEvoGoQRCode() {
  if (!isEvolutionGoChannel.value) return;

  evoGoLoading.value = true;
  evoGoQRCode.value = '';
  evoGoPairingCode.value = '';

  try {
    const { data } = await InboxesAPI.getEvolutionGoQRCode(route.params.inbox_id);

    if (!data.success) {
      evoGoError.value = data.error || 'Erro ao buscar QR Code';
      return;
    }

    if (data.qr_code) {
      evoGoQRCode.value = data.qr_code;
      startEvoGoPolling();
    }
  } catch (error) {
    evoGoError.value = error.message || 'Erro ao conectar';
  } finally {
    evoGoLoading.value = false;
  }
}

async function fetchEvoGoPairingCode() {
  if (!isEvolutionGoChannel.value) return;

  evoGoLoading.value = true;
  evoGoQRCode.value = '';
  evoGoPairingCode.value = '';

  try {
    const number = currentInbox.value.phone_number.replace(/^\+/, '');
    const { data } = await InboxesAPI.getEvolutionGoPairingCode(
      route.params.inbox_id,
      { number }
    );

    if (!data.success) {
      evoGoError.value = data.error || 'Erro ao buscar código';
      return;
    }

    if (data.pairing_code) {
      evoGoPairingCode.value = data.pairing_code;
      startEvoGoPolling();
    } else if (data.qr_code) {
      evoGoQRCode.value = data.qr_code;
      startEvoGoPolling();
    }
  } catch (error) {
    evoGoError.value = error.message || 'Erro ao conectar';
  } finally {
    evoGoLoading.value = false;
  }
}

async function checkEvoGoStatus() {
  if (!isEvolutionGoChannel.value) return;

  try {
    const { data } = await InboxesAPI.getEvolutionGoStatus(route.params.inbox_id);
    if (data.connected) {
      evoGoConnected.value = true;
      stopEvoGoPolling();
    }
  } catch (error) {
    // silent
  }
}

function startEvoGoPolling() {
  if (evoGoPollingInterval.value) return;

  evoGoPollingInterval.value = setInterval(() => {
    if (!evoGoConnected.value) {
      checkEvoGoStatus();
    }
  }, 5000);

  evoGoQRRefreshInterval.value = setInterval(async () => {
    if (evoGoQRCode.value && !evoGoConnected.value) {
      try {
        const { data } = await InboxesAPI.getEvolutionGoQRCode(
          route.params.inbox_id
        );
        if (data.success && data.qr_code) {
          evoGoQRCode.value = data.qr_code;
        }
      } catch (error) {
        // silent refresh error
      }
    }
  }, 40000);
}

function stopEvoGoPolling() {
  if (evoGoPollingInterval.value) {
    clearInterval(evoGoPollingInterval.value);
    evoGoPollingInterval.value = null;
  }
  if (evoGoQRRefreshInterval.value) {
    clearInterval(evoGoQRRefreshInterval.value);
    evoGoQRRefreshInterval.value = null;
  }
}

// Watch for currentInbox changes and regenerate QR codes when available
watch(
  currentInbox,
  newInbox => {
    if (newInbox) {
      generateQRCodes();
      if (isEvolutionChannel.value) {
        checkEvolutionStatus();
      }
      if (isEvolutionGoChannel.value) {
        checkEvoGoStatus();
      }
    }
  },
  { immediate: true }
);

onMounted(() => {
  generateQRCodes();
  if (isEvolutionChannel.value) {
    checkEvolutionStatus();
  }
  if (isEvolutionGoChannel.value) {
    checkEvoGoStatus();
  }
});

onUnmounted(() => {
  stopEvolutionPolling();
  stopEvoGoPolling();
});
</script>

<template>
  <div class="overflow-auto col-span-6 p-6 w-full h-full">
    <DuplicateInboxBanner
      v-if="hasDuplicateInstagramInbox"
      :content="$t('INBOX_MGMT.ADD.INSTAGRAM.NEW_INBOX_SUGGESTION')"
    />
    <EmptyState
      :title="$t('INBOX_MGMT.FINISH.TITLE')"
      :message="isAnEmailChannel && !currentInbox.provider ? '' : message"
      :button-text="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
    >
      <div class="w-full text-center">
        <div class="my-4 mx-auto max-w-[70%]">
          <woot-code
            v-if="currentInbox.web_widget_script"
            :script="currentInbox.web_widget_script"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isATwilioWhatsAppChannel"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div
          v-if="shouldShowWhatsAppWebhookDetails"
          class="w-[50%] max-w-[50%] ml-[25%]"
        >
          <p class="mt-8 font-medium text-n-slate-11">
            {{ $t('INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_URL') }}
          </p>
          <woot-code lang="html" :script="currentInbox.callback_webhook_url" />
          <p class="mt-8 font-medium text-n-slate-11">
            {{
              $t(
                'INBOX_MGMT.ADD.WHATSAPP.API_CALLBACK.WEBHOOK_VERIFICATION_TOKEN'
              )
            }}
          </p>
          <woot-code
            lang="html"
            :script="currentInbox.provider_config.webhook_verify_token"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isALineChannel"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <div class="w-[50%] max-w-[50%] ml-[25%]">
          <woot-code
            v-if="isASmsInbox"
            lang="html"
            :script="currentInbox.callback_webhook_url"
          />
        </div>
        <EmailInboxFinish
          v-if="isAnEmailChannel && !currentInbox.provider"
          :inbox="currentInbox"
          :inbox-id="$route.params.inbox_id"
        />
        <!-- Evolution Connection Section -->
        <div
          v-if="isEvolutionChannel"
          class="flex flex-col gap-4 items-center mt-8 p-6 rounded-xl border border-n-weak bg-n-alpha-1"
        >
          <h3 class="text-lg font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.FINISH.EVOLUTION.TITLE') }}
          </h3>

          <!-- Connected State -->
          <div
            v-if="evolutionConnected"
            class="flex flex-col gap-2 items-center"
          >
            <div class="flex items-center gap-2 text-n-teal-11">
              <span class="i-lucide-check-circle size-6" />
              <span class="text-base font-medium">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.CONNECTED') }}
              </span>
            </div>
            <p class="text-sm text-n-slate-10">
              {{ $t('INBOX_MGMT.FINISH.EVOLUTION.CONNECTED_DESC') }}
            </p>
          </div>

          <!-- Not Connected State -->
          <div v-else class="flex flex-col gap-4 items-center">
            <!-- Error Message -->
            <div
              v-if="evolutionError"
              class="text-sm text-n-ruby-10 bg-n-ruby-3 px-4 py-2 rounded-lg"
            >
              {{ evolutionError }}
            </div>

            <!-- QR Code Display -->
            <div
              v-if="evolutionQRCode && !evolutionPairingCode"
              class="flex flex-col gap-2 items-center"
            >
              <p class="text-sm text-n-slate-11">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.SCAN_QR') }}
              </p>
              <div
                class="rounded-lg shadow outline-1 outline-n-strong outline bg-white p-2"
              >
                <img
                  :src="evolutionQRCode"
                  alt="Evolution WhatsApp QR Code"
                  class="rounded-lg size-48"
                />
              </div>
              <p class="text-xs text-n-slate-9 mt-2">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.WAITING') }}
              </p>
            </div>

            <!-- Pairing Code Display -->
            <div
              v-if="evolutionPairingCode && !evolutionQRCode"
              class="flex flex-col gap-2 items-center"
            >
              <p class="text-sm text-n-slate-11 mb-2">
                {{ $t('INBOX_MGMT.EVOLUTION_INSTANCE.PAIRING_CODE') }}
              </p>
              <h4
                class="text-2xl font-bold tracking-widest text-center text-slate-800 bg-white p-4 rounded border"
              >
                {{ evolutionPairingCode }}
              </h4>
              <p class="text-xs text-n-slate-9 mt-2">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.WAITING') }}
              </p>
            </div>

            <!-- Loading State -->
            <div
              v-if="evolutionLoading"
              class="flex flex-col gap-2 items-center"
            >
              <span
                class="i-lucide-loader-2 size-8 animate-spin text-n-blue-11"
              />
              <p class="text-sm text-n-slate-10">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.LOADING') }}
              </p>
            </div>

            <!-- Connection Options (QR Code / Pairing Code) -->
            <div
              v-if="
                !evolutionQRCode && !evolutionPairingCode && !evolutionLoading
              "
              class="flex flex-col gap-4 items-center"
            >
              <p class="text-sm text-n-slate-10 text-center">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.DESCRIPTION') }}
              </p>
              <div class="flex gap-3">
                <NextButton
                  :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_QR')"
                  @click="fetchEvolutionQRCode"
                  solid
                  blue
                  icon="i-lucide-qr-code"
                />
                <NextButton
                  :label="
                    $t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_PAIRING')
                  "
                  @click="fetchEvolutionPairingCode"
                  solid
                  blue
                  icon="i-lucide-smartphone"
                />
              </div>
            </div>
          </div>
        </div>
        <!-- Evolution GO Connection Section -->
        <div
          v-if="isEvolutionGoChannel"
          class="flex flex-col gap-4 items-center mt-8 p-6 rounded-xl border border-n-weak bg-n-alpha-1"
        >
          <h3 class="text-lg font-medium text-n-slate-12">
            {{ $t('INBOX_MGMT.FINISH.EVOLUTION.TITLE') }}
          </h3>

          <!-- Connected State -->
          <div
            v-if="evoGoConnected"
            class="flex flex-col gap-2 items-center"
          >
            <div class="flex items-center gap-2 text-n-teal-11">
              <span class="i-lucide-check-circle size-6" />
              <span class="text-base font-medium">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.CONNECTED') }}
              </span>
            </div>
            <p class="text-sm text-n-slate-10">
              {{ $t('INBOX_MGMT.FINISH.EVOLUTION.CONNECTED_DESC') }}
            </p>
          </div>

          <!-- Not Connected State -->
          <div v-else class="flex flex-col gap-4 items-center">
            <!-- Error Message -->
            <div
              v-if="evoGoError"
              class="text-sm text-n-ruby-10 bg-n-ruby-3 px-4 py-2 rounded-lg"
            >
              {{ evoGoError }}
            </div>

            <!-- QR Code Display -->
            <div
              v-if="evoGoQRCode && !evoGoPairingCode"
              class="flex flex-col gap-2 items-center"
            >
              <p class="text-sm text-n-slate-11">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.SCAN_QR') }}
              </p>
              <div
                class="rounded-lg shadow outline-1 outline-n-strong outline bg-white p-2"
              >
                <img
                  :src="evoGoQRCode"
                  alt="Evolution GO WhatsApp QR Code"
                  class="rounded-lg size-48"
                />
              </div>
              <p class="text-xs text-n-slate-9 mt-2">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.WAITING') }}
              </p>
            </div>

            <!-- Pairing Code Display -->
            <div
              v-if="evoGoPairingCode && !evoGoQRCode"
              class="flex flex-col gap-2 items-center"
            >
              <p class="text-sm text-n-slate-11 mb-2">
                {{ $t('INBOX_MGMT.EVOLUTION_INSTANCE.PAIRING_CODE') }}
              </p>
              <h4
                class="text-2xl font-bold tracking-widest text-center text-slate-800 bg-white p-4 rounded border"
              >
                {{ evoGoPairingCode }}
              </h4>
              <p class="text-xs text-n-slate-9 mt-2">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.WAITING') }}
              </p>
            </div>

            <!-- Loading State -->
            <div
              v-if="evoGoLoading"
              class="flex flex-col gap-2 items-center"
            >
              <span
                class="i-lucide-loader-2 size-8 animate-spin text-n-blue-11"
              />
              <p class="text-sm text-n-slate-10">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.LOADING') }}
              </p>
            </div>

            <!-- Connection Options -->
            <div
              v-if="
                !evoGoQRCode && !evoGoPairingCode && !evoGoLoading
              "
              class="flex flex-col gap-4 items-center"
            >
              <p class="text-sm text-n-slate-10 text-center">
                {{ $t('INBOX_MGMT.FINISH.EVOLUTION.DESCRIPTION') }}
              </p>
              <div class="flex gap-3">
                <NextButton
                  :label="$t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_QR')"
                  @click="fetchEvoGoQRCode"
                  solid
                  blue
                  icon="i-lucide-qr-code"
                />
                <NextButton
                  :label="
                    $t('INBOX_MGMT.EVOLUTION_INSTANCE.CONNECT_WITH_PAIRING')
                  "
                  @click="fetchEvoGoPairingCode"
                  solid
                  blue
                  icon="i-lucide-smartphone"
                />
              </div>
            </div>
          </div>
        </div>
        <div
          v-if="isAWhatsAppChannel && qrCodes.whatsapp && !isEvolutionChannel && !isEvolutionGoChannel"
          class="flex flex-col gap-3 items-center mt-8"
        >
          <p class="mt-2 text-sm text-n-slate-9">
            {{ $t('INBOX_MGMT.FINISH.WHATSAPP_QR_INSTRUCTION') }}
          </p>
          <div class="rounded-lg shadow outline-1 outline-n-strong outline">
            <img
              :src="qrCodes.whatsapp"
              alt="WhatsApp QR Code"
              class="rounded-lg size-48 dark:invert"
            />
          </div>
        </div>
        <div
          v-if="isAFacebookInbox && qrCodes.messenger"
          class="flex flex-col gap-3 items-center mt-8"
        >
          <p class="mt-2 text-sm text-n-slate-9">
            {{ $t('INBOX_MGMT.FINISH.MESSENGER_QR_INSTRUCTION') }}
          </p>
          <div class="rounded-lg shadow outline-1 outline-n-strong outline">
            <img
              :src="qrCodes.messenger"
              alt="Messenger QR Code"
              class="rounded-lg size-48 dark:invert"
            />
          </div>
        </div>
        <div
          v-if="isATelegramChannel && qrCodes.telegram"
          class="flex flex-col gap-4 items-center mt-8"
        >
          <p class="mt-2 text-sm text-n-slate-9">
            {{ $t('INBOX_MGMT.FINISH.TELEGRAM_QR_INSTRUCTION') }}
          </p>

          <div class="rounded-lg shadow outline-1 outline-n-strong outline">
            <img
              :src="qrCodes.telegram"
              alt="Telegram QR Code"
              class="rounded-lg size-48 dark:invert"
            />
          </div>
        </div>
        <div class="flex gap-2 justify-center mt-4">
          <router-link
            :to="{
              name: 'settings_inbox_show',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              outline
              slate
              :label="$t('INBOX_MGMT.FINISH.MORE_SETTINGS')"
            />
          </router-link>
          <router-link
            :to="{
              name: 'inbox_dashboard',
              params: { inboxId: $route.params.inbox_id },
            }"
          >
            <NextButton
              solid
              teal
              :label="$t('INBOX_MGMT.FINISH.BUTTON_TEXT')"
            />
          </router-link>
        </div>
      </div>
    </EmptyState>
  </div>
</template>
