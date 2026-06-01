<script setup>
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import CustomAttribute from 'dashboard/components/CustomAttribute.vue';

const props = defineProps({
  deal: {
    type: Object,
    required: true,
  },
  attribute: {
    type: Object,
    required: true,
  },
  isEditingView: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['updated']);
const store = useStore();

const handleDelete = async (key) => {
  try {
    const updatedCustomAttributes = { ...props.deal.custom_attributes };
    delete updatedCustomAttributes[key];

    const updatedDeal = await store.dispatch('deals/update', {
      id: props.deal.id,
      custom_attributes: updatedCustomAttributes,
    });
    useAlert('Atributo personalizado removido com sucesso!');
    emit('updated', updatedDeal);
  } catch (error) {
    useAlert(error?.response?.message || 'Erro ao remover atributo.');
  }
};

const handleUpdate = async (key, value) => {
  try {
    const updatedDeal = await store.dispatch('deals/update', {
      id: props.deal.id,
      custom_attributes: {
        ...props.deal.custom_attributes,
        [key]: value,
      },
    });
    useAlert('Atributo personalizado atualizado com sucesso!');
    emit('updated', updatedDeal);
  } catch (error) {
    useAlert(error?.response?.message || 'Erro ao atualizar atributo.');
  }
};

const onCopy = async value => {
  await copyTextToClipboard(value);
  useAlert('Atributo personalizado copiado com sucesso!');
};
</script>

<template>
  <div class="w-full">
    <CustomAttribute
      :attribute-key="attribute.attributeKey"
      :attribute-type="attribute.attributeDisplayType"
      :values="attribute.attributeValues || attribute.attribute_values || []"
      :label="attribute.attributeDisplayName"
      :description="attribute.attributeDescription || ''"
      :value="attribute.value"
      show-actions
      :attribute-regex="attribute.regexPattern || attribute.regex_pattern"
      :regex-cue="attribute.regexCue || attribute.regex_cue"
      @update="handleUpdate"
      @delete="handleDelete"
      @copy="onCopy"
    />
  </div>
</template>
