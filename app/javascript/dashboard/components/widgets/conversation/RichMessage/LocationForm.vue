<script setup>
import { ref, computed, watchEffect } from 'vue';

const emit = defineEmits(['update']);

const MAX_NAME_LENGTH = 60;
const MAX_ADDRESS_LENGTH = 200;

const name = ref('');
const address = ref('');
const latitude = ref('');
const longitude = ref('');

// The coordinates travel to WhatsApp as numbers, so anything that is not a finite decimal in
// range would be silently dropped by the provider.
const parsedLatitude = computed(() => Number(latitude.value.replace(',', '.')));
const parsedLongitude = computed(() =>
  Number(longitude.value.replace(',', '.'))
);

const isLatitudeValid = computed(
  () =>
    latitude.value.trim().length > 0 &&
    Number.isFinite(parsedLatitude.value) &&
    Math.abs(parsedLatitude.value) <= 90
);

const isLongitudeValid = computed(
  () =>
    longitude.value.trim().length > 0 &&
    Number.isFinite(parsedLongitude.value) &&
    Math.abs(parsedLongitude.value) <= 180
);

const isValid = computed(() => isLatitudeValid.value && isLongitudeValid.value);

const payload = computed(() => ({
  message: address.value.trim(),
  contentType: 'text',
  contentAttributes: {
    location: {
      latitude: parsedLatitude.value,
      longitude: parsedLongitude.value,
      name: name.value.trim() || undefined,
    },
  },
}));

watchEffect(() =>
  emit('update', { valid: isValid.value, payload: payload.value })
);
</script>

<template>
  <div class="flex flex-col gap-6">
    <p class="text-sm text-n-slate-11">
      {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.HINT') }}
    </p>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.NAME_LABEL') }}
      </span>
      <input
        v-model="name"
        type="text"
        class="!mb-0"
        :maxlength="MAX_NAME_LENGTH"
        :placeholder="$t('CONVERSATION.RICH_MESSAGE.LOCATION.NAME_PLACEHOLDER')"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium text-n-slate-12">
        {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.ADDRESS_LABEL') }}
      </span>
      <input
        v-model="address"
        type="text"
        class="!mb-0"
        :maxlength="MAX_ADDRESS_LENGTH"
        :placeholder="
          $t('CONVERSATION.RICH_MESSAGE.LOCATION.ADDRESS_PLACEHOLDER')
        "
      />
    </label>

    <div class="flex gap-3">
      <label class="flex flex-col flex-1 gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.LATITUDE_LABEL') }}
        </span>
        <input v-model="latitude" type="text" class="!mb-0" placeholder="-23.5505" />
      </label>
      <label class="flex flex-col flex-1 gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.LONGITUDE_LABEL') }}
        </span>
        <input v-model="longitude" type="text" class="!mb-0" placeholder="-46.6333" />
      </label>
    </div>

    <p
      v-if="(latitude && !isLatitudeValid) || (longitude && !isLongitudeValid)"
      class="text-sm text-n-ruby-11"
    >
      {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.COORDINATES_ERROR') }}
    </p>
  </div>
</template>
