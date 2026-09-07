<script setup>
import { ref, computed, watch } from 'vue';

import Modal from 'dashboard/components/Modal.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

import OptionsForm from './OptionsForm.vue';
import LocationForm from './LocationForm.vue';
import CarouselForm from './CarouselForm.vue';
import ButtonsForm from './ButtonsForm.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  // Only Evolution GO exposes the carousel endpoint; the Cloud API and the unofficial default
  // provider are limited to reply buttons, lists and a native location message. A link needs no
  // form of its own: the service spots one in the message text and routes it to /send/link.
  availableTypes: { type: Array, default: () => ['options'] },
});

const emit = defineEmits(['onSend', 'cancel', 'update:show']);

const FORMS = {
  options: OptionsForm,
  buttons: ButtonsForm,
  location: LocationForm,
  carousel: CarouselForm,
};

const TYPE_ICONS = {
  options: 'i-lucide-list-checks',
  buttons: 'i-lucide-mouse-pointer-click',
  location: 'i-lucide-map-pin',
  carousel: 'i-lucide-gallery-horizontal-end',
};

const types = computed(() =>
  props.availableTypes.filter(type => FORMS[type])
);

const activeType = ref(types.value[0]);
const formState = ref({ valid: false, payload: null });
// Bumping the key remounts the form, which is what clears it. Switching back to the type that
// is already selected has to clear it too, so the counter cannot be the type itself.
const formKey = ref(0);

const activeForm = computed(() => FORMS[activeType.value]);

const selectType = type => {
  activeType.value = type;
  formKey.value += 1;
  formState.value = { valid: false, payload: null };
};

// Reopening the modal should not resume a half-filled form from the previous conversation.
watch(
  () => props.show,
  isShown => {
    if (isShown) selectType(types.value[0]);
  }
);

const onFormUpdate = state => {
  formState.value = state;
};

const onCancel = () => emit('cancel');

const onSend = () => {
  if (!formState.value.valid) return;

  emit('onSend', formState.value.payload);
};
</script>

<template>
  <Modal :show="show" @update:show="emit('update:show', $event)">
    <div class="flex flex-col gap-6 p-8 min-w-[420px] max-h-[80vh] overflow-y-auto">
      <div class="flex flex-col gap-1">
        <h2 class="text-lg font-semibold text-n-slate-12">
          {{ $t('CONVERSATION.RICH_MESSAGE.TITLE') }}
        </h2>
      </div>

      <div v-if="types.length > 1" class="flex flex-wrap gap-2">
        <NextButton
          v-for="type in types"
          :key="type"
          sm
          :solid="activeType === type"
          :faded="activeType !== type"
          :blue="activeType === type"
          :slate="activeType !== type"
          :icon="TYPE_ICONS[type]"
          :label="$t(`CONVERSATION.RICH_MESSAGE.TYPES.${type.toUpperCase()}`)"
          @click="selectType(type)"
        />
      </div>

      <component
        :is="activeForm"
        v-if="activeForm"
        :key="formKey"
        @update="onFormUpdate"
      />

      <div class="flex justify-end gap-2">
        <NextButton
          faded
          slate
          :label="$t('CONVERSATION.RICH_MESSAGE.CANCEL')"
          @click="onCancel"
        />
        <NextButton
          solid
          blue
          :disabled="!formState.valid"
          :label="$t('CONVERSATION.RICH_MESSAGE.SEND')"
          @click="onSend"
        />
      </div>
    </div>
  </Modal>
</template>
