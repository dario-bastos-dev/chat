<script setup>
/**
 * This component handles parsing and sending WhatsApp message templates.
 * It works as follows:
 * 1. Displays the template text with variable placeholders.
 * 2. Generates input fields for each variable in the template.
 * 3. Validates that all variables are filled before sending.
 * 4. Replaces placeholders with user-provided values.
 * 5. Emits events to send the processed message or reset the template.
 */
import { ref, computed, onMounted, watch } from 'vue';
import { useVuelidate } from '@vuelidate/core';
import { requiredIf } from '@vuelidate/validators';
import { useI18n } from 'vue-i18n';

import { isWhatsAppComplete } from '@chatwoot/utils';
import Input from 'dashboard/components-next/input/Input.vue';
import {
  buildTemplateParameters,
  mergeTemplateParameters,
  allKeysRequired,
  DEFAULT_LANGUAGE,
  DEFAULT_CATEGORY,
  COMPONENT_TYPES,
  MEDIA_FORMATS,
  findComponentByType,
  renderTemplatePreview,
} from 'dashboard/helper/templateHelper';

const props = defineProps({
  template: {
    type: Object,
    default: () => ({}),
    validator: value => {
      if (!value || typeof value !== 'object') return false;
      if (!value.components || !Array.isArray(value.components)) return false;
      return true;
    },
  },
  sendRenderedContent: {
    type: Boolean,
    default: false,
  },
  // Variable values saved earlier for this template, when the parser is reopened
  // on something that already stores them (an automation rule, a sequence step).
  // Without this the inputs are rebuilt empty on mount and the saved values are
  // lost on the next save.
  initialParams: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['sendMessage', 'resetTemplate', 'back']);

const { t } = useI18n();

const processedParams = ref({});

const languageLabel = computed(() => {
  return `${t('WHATSAPP_TEMPLATES.PARSER.LANGUAGE')}: ${props.template.language || DEFAULT_LANGUAGE}`;
});

const categoryLabel = computed(() => {
  return `${t('WHATSAPP_TEMPLATES.PARSER.CATEGORY')}: ${props.template.category || DEFAULT_CATEGORY}`;
});

const headerComponent = computed(() => {
  return findComponentByType(props.template, COMPONENT_TYPES.HEADER);
});

const bodyComponent = computed(() => {
  return findComponentByType(props.template, COMPONENT_TYPES.BODY);
});

const bodyText = computed(() => {
  return bodyComponent.value?.text || '';
});

// Buttons are part of what the contact will see, so the preview shows them even
// though their only editable piece (a URL suffix, a copy code) is handled by the
// parameter inputs further down.
const templateButtons = computed(
  () =>
    findComponentByType(props.template, COMPONENT_TYPES.BUTTONS)?.buttons || []
);

const headerText = computed(() => {
  return headerComponent.value?.format === 'TEXT'
    ? headerComponent.value?.text || ''
    : '';
});

const hasMediaHeader = computed(() =>
  MEDIA_FORMATS.includes(headerComponent.value?.format)
);

// Meta requires the header media on every send — omitting it answers #132000 —
// so the URL comes from the template instead of being asked for again.
//
// A template created through Chatwoot keeps its own copy of the media, which is
// the stable source. Otherwise the approval sample is used, but only when Meta
// returned it as a fetchable URL: it can also come back as the raw upload
// handle
// (`4::aW1hZ2Uv…`), which is not usable as a link. Anything that is not a URL
// falls back to asking.
const boundMediaUrl = computed(() => {
  if (!hasMediaHeader.value) return '';
  const storedUrl = props.template.chatwoot_media_url;
  if (storedUrl) return storedUrl;

  const handle = headerComponent.value?.example?.header_handle?.[0] || '';
  return /^https?:\/\//.test(handle) ? handle : '';
});

// Meta signs these URLs and they can expire, so the media stays replaceable.
const isOverridingMedia = ref(false);

const isMediaFromTemplate = computed(
  () =>
    !!boundMediaUrl.value &&
    processedParams.value.header?.media_url === boundMediaUrl.value
);

const showMediaInputs = computed(
  () => !isMediaFromTemplate.value || isOverridingMedia.value
);

// A payment template carries its order in the button component instead of text
// parameters, so the parser collects the charge here and hands it over under
// `order_details`.
const GOODS_TYPES = ['digital-goods', 'physical-goods'];
const PAYMENT_TYPES = ['pix_dynamic_code', 'boleto', 'payment_link'];
const PIX_KEY_TYPES = ['CNPJ', 'CPF', 'EMAIL', 'PHONE', 'EVP'];

const hasOrderDetails = computed(() =>
  (findComponentByType(props.template, COMPONENT_TYPES.BUTTONS)?.buttons || [])
    .some(button => button.type?.toUpperCase() === 'ORDER_DETAILS')
);

const orderDetails = computed(() => processedParams.value.order_details || {});

const updateOrderDetail = (key, value) => {
  processedParams.value.order_details ??= {};
  processedParams.value.order_details[key] = value;
};

// Mirrors the backend rule: whichever separator comes last is the decimal one.
// Diverging here would let a value through that the send reads differently.
const parseAmount = value => {
  const digits = String(value ?? '').replace(/[^\d.,]/g, '');
  if (!digits) return 0;

  const lastComma = digits.lastIndexOf(',');
  const lastDot = digits.lastIndexOf('.');
  if (lastComma > -1 && lastDot > -1) {
    return lastComma > lastDot
      ? Number(digits.replace(/\./g, '').replace(',', '.'))
      : Number(digits.replace(/,/g, ''));
  }
  return Number(digits.replace(',', '.'));
};

const isOrderDetailsIncomplete = computed(() => {
  if (!hasOrderDetails.value) return false;

  const order = orderDetails.value;
  if (!order.reference_id?.trim() || !parseAmount(order.total_amount)) {
    return true;
  }

  if (order.payment_type === 'pix_dynamic_code') {
    return !(
      order.pix_code?.trim() &&
      order.pix_merchant_name?.trim() &&
      order.pix_key?.trim() &&
      order.pix_key_type
    );
  }
  if (order.payment_type === 'boleto') {
    return !order.boleto_digitable_line?.trim();
  }
  if (order.payment_type === 'payment_link') {
    return !order.payment_link_uri?.trim();
  }
  return true;
});

const formatType = computed(() => {
  const format = headerComponent.value?.format;
  return format ? format.charAt(0) + format.slice(1).toLowerCase() : '';
});

const isDocumentTemplate = computed(() => {
  return headerComponent.value?.format?.toLowerCase() === 'document';
});

const hasBodyVariables = computed(() => {
  return bodyText.value?.match(/{{([^}]+)}}/g) !== null;
});

const hasTextHeaderVariables = computed(() => {
  return headerText.value?.match(/{{([^}]+)}}/g) !== null;
});

const hasVariables = computed(
  () => hasBodyVariables.value || hasTextHeaderVariables.value
);

const renderedHeader = computed(() => {
  return renderTemplatePreview(
    headerText.value,
    processedParams.value.header || {}
  );
});

const renderedTemplate = computed(() => {
  return renderTemplatePreview(
    bodyText.value,
    processedParams.value.body || {}
  );
});

// Completeness validation is shared with the mobile app via @chatwoot/utils,
// which only knows about text parameters — the order is stripped out and
// checked separately.
const isFormInvalid = computed(() => {
  const { order_details: _order, ...textParams } = processedParams.value;
  return (
    !isWhatsAppComplete(props.template, textParams) ||
    isOrderDetailsIncomplete.value
  );
});

const v$ = useVuelidate(
  {
    processedParams: {
      requiredIfKeysPresent: requiredIf(hasVariables),
      allKeysRequired,
    },
  },
  { processedParams }
);

const initializeTemplateParameters = () => {
  const params = mergeTemplateParameters(
    buildTemplateParameters(props.template, hasMediaHeader.value),
    props.initialParams
  );

  if (boundMediaUrl.value && params.header && !params.header.media_url) {
    params.header.media_url = boundMediaUrl.value;
  }

  if (hasOrderDetails.value) {
    // mergeTemplateParameters only walks the skeleton, which has no order, so a
    // charge saved on an automation or sequence step is taken straight from
    // initialParams or it would be lost here.
    params.order_details = {
      goods_type: GOODS_TYPES[0],
      payment_type: PAYMENT_TYPES[0],
      pix_key_type: PIX_KEY_TYPES[0],
      ...(props.initialParams?.order_details || {}),
      ...(params.order_details || {}),
    };
  }

  isOverridingMedia.value = false;
  processedParams.value = params;
};

const updateMediaUrl = value => {
  processedParams.value.header ??= {};
  processedParams.value.header.media_url = value;
};

const updateMediaName = value => {
  processedParams.value.header ??= {};
  processedParams.value.header.media_name = value;
};

const sendMessage = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  const { name, category, language, namespace } = props.template;

  const payload = {
    message: props.sendRenderedContent
      ? renderedTemplate.value
      : bodyText.value,
    pendingMessageContent: renderedTemplate.value,
    templateParams: {
      name,
      category,
      language,
      namespace,
      content_mode: props.sendRenderedContent ? 'rendered' : 'raw_template',
      processed_params: processedParams.value,
    },
  };
  emit('sendMessage', payload);
};

const resetTemplate = () => {
  emit('resetTemplate');
};

const goBack = () => {
  emit('back');
};

onMounted(initializeTemplateParameters);

watch(
  () => props.template,
  () => {
    initializeTemplateParameters();
    v$.value.$reset();
  },
  { deep: true }
);

defineExpose({
  processedParams,
  hasOrderDetails,
  isOrderDetailsIncomplete,
  hasVariables,
  hasMediaHeader,
  isDocumentTemplate,
  headerComponent,
  renderedHeader,
  renderedTemplate,
  isFormInvalid,
  v$,
  updateMediaUrl,
  updateMediaName,
  sendMessage,
  resetTemplate,
  goBack,
});
</script>

<template>
  <div>
    <div class="flex flex-col gap-4 p-4 mb-4 rounded-lg bg-n-alpha-black2">
      <div class="flex justify-between items-center">
        <h3 class="text-sm font-medium text-n-slate-12">
          {{ template.name }}
        </h3>
        <span class="text-xs text-n-slate-11">
          {{ languageLabel }}
        </span>
      </div>

      <div class="flex flex-col gap-2">
        <div class="rounded-md">
          <div
            v-if="renderedHeader"
            class="mb-2 text-sm font-medium whitespace-pre-wrap text-n-slate-12"
          >
            {{ renderedHeader }}
          </div>
          <div class="text-sm whitespace-pre-wrap text-n-slate-12">
            {{ renderedTemplate }}
          </div>
        </div>
      </div>

      <div
        v-if="templateButtons.length"
        class="flex flex-col gap-1 pt-3 border-t border-n-strong"
      >
        <span
          v-for="(button, index) in templateButtons"
          :key="index"
          class="text-sm font-medium text-center text-n-brand"
        >
          {{ button.text || button.title }}
        </span>
      </div>

      <div class="text-xs text-n-slate-11">
        {{ categoryLabel }}
      </div>
    </div>

    <div v-if="hasVariables || hasMediaHeader || hasOrderDetails">
      <div v-if="hasMediaHeader" class="mb-4">
        <p class="mb-2.5 text-sm font-semibold">
          {{
            $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_HEADER_LABEL', {
              type: formatType,
            }) || `${formatType} Header`
          }}
        </p>
        <div
          v-if="!showMediaInputs"
          class="flex gap-2 items-center mb-2.5 text-sm text-n-slate-11"
        >
          <span class="flex-1">
            {{ $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_FROM_TEMPLATE') }}
          </span>
          <button
            type="button"
            class="font-medium text-n-brand"
            @click="isOverridingMedia = true"
          >
            {{ $t('WHATSAPP_TEMPLATES.PARSER.MEDIA_REPLACE') }}
          </button>
        </div>
        <div v-if="showMediaInputs" class="flex items-center mb-2.5">
          <Input
            :model-value="processedParams.header?.media_url || ''"
            type="url"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.MEDIA_URL_LABEL', {
                type: formatType,
              })
            "
            @update:model-value="updateMediaUrl"
          />
        </div>
        <div
          v-if="showMediaInputs && isDocumentTemplate"
          class="flex items-center mb-2.5"
        >
          <Input
            :model-value="processedParams.header?.media_name || ''"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.DOCUMENT_NAME_PLACEHOLDER')
            "
            @update:model-value="updateMediaName"
          />
        </div>
      </div>

      <!-- Text Header Variables Section -->
      <div v-if="hasTextHeaderVariables && processedParams.header">
        <p class="mb-2.5 text-sm font-semibold">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.HEADER_VARIABLES_LABEL') }}
        </p>
        <div
          v-for="(variable, key) in processedParams.header"
          :key="`header-${key}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.header[key]"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
                variable: key,
              })
            "
          />
        </div>
      </div>

      <!-- Body Variables Section -->
      <div v-if="processedParams.body">
        <p class="mb-2.5 text-sm font-semibold">
          {{ $t('WHATSAPP_TEMPLATES.PARSER.VARIABLES_LABEL') }}
        </p>
        <div
          v-for="(variable, key) in processedParams.body"
          :key="`body-${key}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.body[key]"
            type="text"
            class="flex-1"
            :placeholder="
              t('WHATSAPP_TEMPLATES.PARSER.VARIABLE_PLACEHOLDER', {
                variable: key,
              })
            "
          />
        </div>
      </div>

      <!-- Button Variables Section -->
      <div v-if="processedParams.buttons">
        <p class="mb-2.5 text-sm font-semibold">
          {{ t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETERS') }}
        </p>
        <div
          v-for="(button, index) in processedParams.buttons"
          :key="`button-${index}`"
          class="flex items-center mb-2.5"
        >
          <Input
            v-model="processedParams.buttons[index].parameter"
            type="text"
            class="flex-1"
            :placeholder="t('WHATSAPP_TEMPLATES.PARSER.BUTTON_PARAMETER')"
          />
        </div>
      </div>
    <div v-if="hasOrderDetails" class="flex flex-col gap-2.5 mb-4">
      <p class="text-sm font-semibold">
        {{ $t('WHATSAPP_TEMPLATES.PARSER.ORDER.TITLE') }}
      </p>

      <div class="grid gap-2.5 sm:grid-cols-2">
        <Input
          :model-value="orderDetails.reference_id || ''"
          type="text"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.REFERENCE_ID')"
          @update:model-value="
            value => updateOrderDetail('reference_id', value)
          "
        />
        <Input
          :model-value="orderDetails.total_amount || ''"
          type="text"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.TOTAL_AMOUNT')"
          @update:model-value="
            value => updateOrderDetail('total_amount', value)
          "
        />
      </div>

      <div class="grid gap-2.5 sm:grid-cols-2">
        <select
          :value="orderDetails.goods_type"
          class="py-2 px-3 w-full text-sm rounded-lg border outline-none border-n-weak bg-n-alpha-black2 text-n-slate-12"
          @change="event => updateOrderDetail('goods_type', event.target.value)"
        >
          <option v-for="type in GOODS_TYPES" :key="type" :value="type">
            {{ $t(`WHATSAPP_TEMPLATES.PARSER.ORDER.GOODS_TYPES.${type}`) }}
          </option>
        </select>
        <select
          :value="orderDetails.payment_type"
          class="py-2 px-3 w-full text-sm rounded-lg border outline-none border-n-weak bg-n-alpha-black2 text-n-slate-12"
          @change="
            event => updateOrderDetail('payment_type', event.target.value)
          "
        >
          <option v-for="type in PAYMENT_TYPES" :key="type" :value="type">
            {{ $t(`WHATSAPP_TEMPLATES.PARSER.ORDER.PAYMENT_TYPES.${type}`) }}
          </option>
        </select>
      </div>

      <template v-if="orderDetails.payment_type === 'pix_dynamic_code'">
        <Input
          :model-value="orderDetails.pix_code || ''"
          type="text"
          :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.PIX_CODE')"
          @update:model-value="value => updateOrderDetail('pix_code', value)"
        />
        <div class="grid gap-2.5 sm:grid-cols-3">
          <Input
            :model-value="orderDetails.pix_merchant_name || ''"
            type="text"
            :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.PIX_MERCHANT')"
            @update:model-value="
              value => updateOrderDetail('pix_merchant_name', value)
            "
          />
          <Input
            :model-value="orderDetails.pix_key || ''"
            type="text"
            :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.PIX_KEY')"
            @update:model-value="value => updateOrderDetail('pix_key', value)"
          />
          <select
            :value="orderDetails.pix_key_type"
            class="py-2 px-3 w-full text-sm rounded-lg border outline-none border-n-weak bg-n-alpha-black2 text-n-slate-12"
            @change="
              event => updateOrderDetail('pix_key_type', event.target.value)
            "
          >
            <option v-for="type in PIX_KEY_TYPES" :key="type" :value="type">
              {{ type }}
            </option>
          </select>
        </div>
      </template>

      <Input
        v-else-if="orderDetails.payment_type === 'boleto'"
        :model-value="orderDetails.boleto_digitable_line || ''"
        type="text"
        :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.BOLETO_LINE')"
        @update:model-value="
          value => updateOrderDetail('boleto_digitable_line', value)
        "
      />

      <Input
        v-else
        :model-value="orderDetails.payment_link_uri || ''"
        type="url"
        :placeholder="$t('WHATSAPP_TEMPLATES.PARSER.ORDER.PAYMENT_LINK')"
        @update:model-value="
          value => updateOrderDetail('payment_link_uri', value)
        "
      />
    </div>

      <p
        v-if="v$.$dirty && v$.$invalid"
        class="p-2.5 text-center rounded-md bg-n-ruby-9/20 text-n-ruby-9"
      >
        {{ $t('WHATSAPP_TEMPLATES.PARSER.FORM_ERROR_MESSAGE') }}
      </p>
    </div>

    <slot
      name="actions"
      :send-message="sendMessage"
      :reset-template="resetTemplate"
      :go-back="goBack"
      :is-valid="!v$.$invalid"
      :disabled="isFormInvalid"
    />
  </div>
</template>
