<script setup>
import { ref, computed, watch, watchEffect } from 'vue';
import {
  parseMapLocation,
  isShortMapLink,
} from 'dashboard/helper/mapLocationHelper';

const emit = defineEmits(['update']);

const MAX_NAME_LENGTH = 60;
const MAX_ADDRESS_LENGTH = 200;

const name = ref('');
const address = ref('');
const source = ref('');

const location = computed(() => parseMapLocation(source.value));
const hasCoordinates = computed(() => location.value !== null);

// Evolution GO answers /send/location with "address is required", so the address is part of the
// message rather than a nicety. A Maps link for an address fills it in on its own.
const isMissingAddress = computed(() => address.value.trim().length === 0);
const isValid = computed(
  () => hasCoordinates.value && !isMissingAddress.value
);

// A shortened link only reveals its destination by following a redirect, which the browser cannot
// read. Saying so is more useful than calling the input invalid.
const isShortLink = computed(
  () => !hasCoordinates.value && isShortMapLink(source.value)
);
const hasError = computed(
  () =>
    source.value.trim().length > 0 && !hasCoordinates.value && !isShortLink.value
);

// Opens Maps already searching for what the agent typed, so the lookup starts one step further
// along. Coordinates still come back by copy and paste: turning an address into them needs a
// geocoding service, which this installation does not have.
const mapsSearchUrl = computed(() => {
  const query = address.value.trim();
  return query
    ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}`
    : 'https://www.google.com/maps';
});

const mapPreviewUrl = computed(() =>
  hasCoordinates.value
    ? `https://maps.google.com/?q=${location.value.latitude},${location.value.longitude}`
    : ''
);

// A Google place URL names either the place or the whole address, depending on what the agent
// searched for. Each one fills its own field, and only while that field is still empty, so
// pasting a link never overwrites what they typed.
watch(location, value => {
  if (!value) return;
  if (value.name && !name.value.trim()) name.value = value.name;
  if (value.address && !address.value.trim()) address.value = value.address;
});

const payload = computed(() => ({
  message: address.value.trim(),
  contentType: 'text',
  contentAttributes: {
    location: {
      latitude: location.value?.latitude,
      longitude: location.value?.longitude,
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
      <span
        v-if="hasCoordinates && isMissingAddress"
        class="text-sm text-n-ruby-11"
      >
        {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.ADDRESS_REQUIRED') }}
      </span>
    </label>

    <div class="flex flex-col gap-1">
      <div class="flex items-center justify-between gap-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.SOURCE_LABEL') }}
        </span>
        <a
          :href="mapsSearchUrl"
          target="_blank"
          rel="noopener noreferrer"
          class="flex items-center gap-1 text-sm shrink-0 text-n-blue-11"
        >
          <span class="i-lucide-external-link size-4" />
          {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.OPEN_MAPS') }}
        </a>
      </div>
      <input
        v-model="source"
        type="text"
        class="!mb-0"
        :placeholder="
          $t('CONVERSATION.RICH_MESSAGE.LOCATION.SOURCE_PLACEHOLDER')
        "
      />
      <a
        v-if="hasCoordinates"
        :href="mapPreviewUrl"
        target="_blank"
        rel="noopener noreferrer"
        class="text-sm text-n-blue-11 w-fit"
      >
        {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.PREVIEW') }}
        ({{ location.latitude }}, {{ location.longitude }})
      </a>
      <span v-else-if="isShortLink" class="text-sm text-n-amber-11">
        {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.SHORT_LINK_ERROR') }}
      </span>
      <span v-else-if="hasError" class="text-sm text-n-ruby-11">
        {{ $t('CONVERSATION.RICH_MESSAGE.LOCATION.SOURCE_ERROR') }}
      </span>
    </div>

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
  </div>
</template>
