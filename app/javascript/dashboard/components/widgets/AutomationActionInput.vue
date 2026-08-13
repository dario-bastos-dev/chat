<script>
import { mapGetters } from 'vuex';
import AutomationActionTeamMessageInput from './AutomationActionTeamMessageInput.vue';
import AutomationActionMessageInput from './AutomationActionMessageInput.vue';
import AutomationActionFileInput from './AutomationFileInput.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SingleSelect from 'dashboard/components-next/filter/inputs/SingleSelect.vue';
import MultiSelect from 'dashboard/components-next/filter/inputs/MultiSelect.vue';
import NextInput from 'dashboard/components-next/input/Input.vue';
import { useAccount } from 'dashboard/composables/useAccount';

export default {
  components: {
    AutomationActionTeamMessageInput,
    AutomationActionMessageInput,
    AutomationActionFileInput,
    WootMessageEditor,
    NextButton,
    SingleSelect,
    MultiSelect,
    NextInput,
  },
  setup() {
    const { isCloudFeatureEnabled } = useAccount();
    return { isCloudFeatureEnabled };
  },
  props: {
    modelValue: {
      type: Object,
      default: () => null,
    },
    actionTypes: {
      type: Array,
      default: () => [],
    },
    dropdownValues: {
      type: Array,
      default: () => [],
    },
    errorMessage: {
      type: String,
      default: '',
    },
    showActionInput: {
      type: Boolean,
      default: true,
    },
    initialFileName: {
      type: String,
      default: '',
    },
    isMacro: {
      type: Boolean,
      default: false,
    },
    dropdownMaxHeight: {
      type: String,
      default: 'max-h-80',
    },
  },
  emits: ['update:modelValue', 'input', 'removeAction', 'resetAction'],
  computed: {
    ...mapGetters({
      pipelines: 'pipelines/getPipelines',
      dealAttributes: 'attributes/getDealAttributes',
    }),
    action_name: {
      get() {
        if (!this.modelValue) return null;
        return this.modelValue.action_name;
      },
      set(value) {
        const payload = this.modelValue || {};
        this.$emit('update:modelValue', { ...payload, action_name: value });
        this.$emit('input', { ...payload, action_name: value });
      },
    },
    action_params: {
      get() {
        if (!this.modelValue) return null;
        return this.modelValue.action_params;
      },
      set(value) {
        const payload = this.modelValue || {};
        this.$emit('update:modelValue', { ...payload, action_params: value });
        this.$emit('input', { ...payload, action_params: value });
      },
    },
    inputType() {
      const found = this.actionTypes.find(action => action.key === this.action_name);
      return found ? found.inputType : '';
    },
    actionNameAsSelectModel: {
      get() {
        if (!this.action_name) return null;
        const found = this.actionTypes.find(a => a.key === this.action_name);
        return found ? { id: found.key, name: found.label } : null;
      },
      set(value) {
        this.action_name = value?.id || value;
      },
    },
    actionTypesAsOptions() {
      return this.actionTypes.map(a => ({ id: a.key, name: a.label }));
    },
    isVerticalLayout() {
      return ['team_message', 'textarea', 'deal_update'].includes(this.inputType);
    },
    dealTitle: {
      get() {
        const rawParams = this.action_params;
        if (!rawParams || !rawParams[0]) return '';
        return rawParams[0].title || '';
      },
      set(value) {
        const rawParams = this.action_params || [];
        const currentObj = rawParams[0] && typeof rawParams[0] === 'object' ? rawParams[0] : {};
        this.action_params = [{
          ...currentObj,
          title: value,
        }];
      },
    },
    dealCustomAttributes: {
      get() {
        const rawParams = this.action_params;
        if (!rawParams || !rawParams[0]) return {};
        return rawParams[0].custom_attributes || {};
      },
      set(value) {
        const rawParams = this.action_params || [];
        const currentObj = rawParams[0] && typeof rawParams[0] === 'object' ? rawParams[0] : {};
        this.action_params = [{
          ...currentObj,
          custom_attributes: value,
        }];
      },
    },
    castMessageVmodel: {
      get() {
        if (Array.isArray(this.action_params)) {
          return this.action_params[0];
        }
        return this.action_params;
      },
      set(value) {
        this.action_params = value;
      },
    },
    pipelineOptions() {
      return (this.pipelines || []).map(p => ({
        id: p.id,
        name: p.name,
      }));
    },
    stageOptions() {
      const pId = this.currentPipelineId;
      if (!pId) return [];
      const pipeline = (this.pipelines || []).find(p => p.id === pId);
      return (pipeline?.stages || []).map(s => ({
        id: s.id,
        name: s.name,
      }));
    },
    currentPipelineId() {
      const rawParams = this.action_params;
      if (!rawParams) return null;
      const rawStr = Array.isArray(rawParams)
        ? (typeof rawParams[0] === 'object' ? rawParams[0]?.id : rawParams[0])
        : (typeof rawParams === 'object' ? rawParams?.id : rawParams);
      if (typeof rawStr !== 'string' || !rawStr.includes(':')) return null;
      return Number(rawStr.split(':')[0]);
    },
    currentStageId() {
      const rawParams = this.action_params;
      if (!rawParams) return null;
      const rawStr = Array.isArray(rawParams)
        ? (typeof rawParams[0] === 'object' ? rawParams[0]?.id : rawParams[0])
        : (typeof rawParams === 'object' ? rawParams?.id : rawParams);
      if (typeof rawStr !== 'string' || !rawStr.includes(':')) return null;
      return Number(rawStr.split(':')[1]);
    },
    selectedPipeline: {
      get() {
        const pId = this.currentPipelineId;
        if (!pId) return null;
        const pipeline = (this.pipelines || []).find(p => p.id === pId);
        return pipeline ? { id: pipeline.id, name: pipeline.name } : null;
      },
      set(value) {
        const pId = value?.id || value;
        if (!pId) {
          this.action_params = [];
          return;
        }
        const pipeline = (this.pipelines || []).find(p => p.id === pId);
        const firstStage = pipeline?.stages?.[0];
        if (firstStage) {
          this.action_params = [`${pId}:${firstStage.id}`];
        } else {
          this.action_params = [];
        }
      },
    },
    selectedStage: {
      get() {
        const pId = this.currentPipelineId;
        const sId = this.currentStageId;
        if (!pId || !sId) return null;
        const pipeline = (this.pipelines || []).find(p => p.id === pId);
        const stage = (pipeline?.stages || []).find(s => s.id === sId);
        return stage ? { id: stage.id, name: stage.name } : null;
      },
      set(value) {
        const sId = value?.id || value;
        const pId = this.currentPipelineId;
        if (pId && sId) {
          this.action_params = [`${pId}:${sId}`];
        }
      },
    },
  },
  mounted() {
    if (this.isCloudFeatureEnabled('crm')) {
      if (!this.pipelines || this.pipelines.length === 0) {
        this.$store.dispatch('pipelines/get');
      }
    }
    this.$store.dispatch('attributes/get');
  },
  methods: {
    removeAction() {
      this.$emit('removeAction');
    },
    resetAction() {
      this.$emit('resetAction');
    },
    onActionNameChange(value) {
      this.actionNameAsSelectModel = value;
      this.resetAction();
    },
    getAttributeSelectModel(key) {
      const found = (this.dealAttributes || []).find(attr => attr.attributeKey === key);
      return found ? { id: found.attributeKey, name: found.attributeDisplayName } : { id: key, name: key };
    },
    dealAttributeOptions() {
      return (this.dealAttributes || []).map(attr => ({
        id: attr.attributeKey,
        name: attr.attributeDisplayName,
      }));
    },
    updateAttributeKey(oldKey, newKey) {
      if (!newKey || oldKey === newKey) return;
      const currentAttrs = { ...this.dealCustomAttributes };
      const val = currentAttrs[oldKey];
      delete currentAttrs[oldKey];
      currentAttrs[newKey] = val;
      this.dealCustomAttributes = currentAttrs;
    },
    updateAttributeValue(key, value) {
      const currentAttrs = { ...this.dealCustomAttributes };
      currentAttrs[key] = value;
      this.dealCustomAttributes = currentAttrs;
    },
    removeAttributeKey(key) {
      const currentAttrs = { ...this.dealCustomAttributes };
      delete currentAttrs[key];
      this.dealCustomAttributes = currentAttrs;
    },
    addNewAttribute() {
      const availableAttr = (this.dealAttributes || []).find(attr => !this.dealCustomAttributes[attr.attributeKey]);
      const newKey = availableAttr ? availableAttr.attributeKey : `custom_attr_${Date.now()}`;
      this.updateAttributeValue(newKey, '');
    },
  },
};
</script>

<template>
  <li class="list-none py-2 first:pt-0 last:pb-0">
    <div
      class="flex flex-col gap-2"
      :class="{ 'animate-wiggle': errorMessage }"
    >
      <div class="flex items-center gap-2">
        <SingleSelect
          :model-value="actionNameAsSelectModel"
          :options="actionTypesAsOptions"
          :dropdown-max-height="dropdownMaxHeight"
          disable-deselect
          class="flex-shrink-0"
          @update:model-value="onActionNameChange"
        />
        <template v-if="showActionInput && !isVerticalLayout">
          <template v-if="isCloudFeatureEnabled('crm') && (action_name === 'create_deal' || action_name === 'move_deal_stage')">
            <!-- No min-width here: the dropdown root would reserve the space while the trigger
                 button stays content-sized, leaving a visible gap between the two selects. -->
            <SingleSelect
              v-model="selectedPipeline"
              :options="pipelineOptions"
              placeholder="Selecionar pipeline"
              :dropdown-max-height="dropdownMaxHeight"
              class="flex-shrink-0"
            />
            <SingleSelect
              v-if="selectedPipeline"
              v-model="selectedStage"
              :options="stageOptions"
              placeholder="Selecionar etapa"
              :dropdown-max-height="dropdownMaxHeight"
              class="flex-shrink-0"
            />
          </template>
          <template v-else>
            <SingleSelect
              v-if="inputType === 'search_select'"
              v-model="action_params"
              :options="dropdownValues"
              :dropdown-max-height="dropdownMaxHeight"
            />
            <MultiSelect
              v-else-if="inputType === 'multi_select'"
              v-model="action_params"
              :options="dropdownValues"
              :dropdown-max-height="dropdownMaxHeight"
            />
            <NextInput
              v-else-if="inputType === 'email'"
              v-model="action_params"
              type="email"
              size="sm"
              :placeholder="$t('AUTOMATION.ACTION.EMAIL_INPUT_PLACEHOLDER')"
            />
            <NextInput
              v-else-if="inputType === 'url'"
              v-model="action_params"
              type="url"
              size="sm"
              :placeholder="$t('AUTOMATION.ACTION.URL_INPUT_PLACEHOLDER')"
            />
            <AutomationActionFileInput
              v-else-if="inputType === 'attachment'"
              v-model="action_params"
              :initial-file-name="initialFileName"
            />
          </template>
        </template>
        <NextButton
          v-if="!isMacro"
          sm
          solid
          slate
          icon="i-lucide-trash"
          class="flex-shrink-0"
          @click="removeAction"
        />
      </div>
      <AutomationActionTeamMessageInput
        v-if="inputType === 'team_message'"
        v-model="action_params"
        :teams="dropdownValues"
        :dropdown-max-height="dropdownMaxHeight"
      />
      <AutomationActionMessageInput
        v-if="inputType === 'textarea' && action_name === 'send_message'"
        v-model="castMessageVmodel"
        :dropdown-max-height="dropdownMaxHeight"
      />
      <WootMessageEditor
        v-else-if="inputType === 'textarea'"
        v-model="castMessageVmodel"
        rows="4"
        enable-variables
        :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
        class="[&_.ProseMirror-menubar]:hidden px-3 py-1 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong"
      />
      <div v-if="isCloudFeatureEnabled('crm') && inputType === 'deal_update'" class="w-full flex flex-col gap-3 p-4 bg-n-alpha-1 rounded-lg outline outline-1 outline-n-weak dark:outline-n-strong">
        <!-- Campo: Título do Negócio -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">
            {{ $t('AUTOMATION.ACTION.DEAL_TITLE_LABEL') }}
          </label>
          <NextInput
            v-model="dealTitle"
            type="text"
            size="sm"
            placeholder="Ex: Negócio de {{contact.name}}"
          />
        </div>

        <!-- Campo: Atributos Personalizados do Negócio -->
        <div class="flex flex-col gap-2">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wider">
            {{ $t('AUTOMATION.ACTION.DEAL_CUSTOM_ATTRIBUTES_LABEL') }}
          </label>
          <div v-for="(val, key) in dealCustomAttributes" :key="key" class="flex items-center gap-2">
            <SingleSelect
              :model-value="getAttributeSelectModel(key)"
              :options="dealAttributeOptions()"
              placeholder="Selecionar atributo"
              class="w-[200px]"
              @update:model-value="(attr) => updateAttributeKey(key, attr?.id || attr)"
            />
            <NextInput
              :model-value="val"
              type="text"
              size="sm"
              class="flex-1"
              placeholder="Valor ou variável (ex: {{contact.custom_attributes.cnpj}})"
              @input="(e) => updateAttributeValue(key, e.target.value)"
            />
            <NextButton
              sm
              solid
              slate
              icon="i-lucide-trash"
              @click="removeAttributeKey(key)"
            />
          </div>
          <div class="mt-1">
            <NextButton
              sm
              outlined
              slate
              icon="i-lucide-plus"
              @click="addNewAttribute"
            >
              {{ $t('AUTOMATION.ACTION.ADD_DEAL_ATTRIBUTE_BTN') }}
            </NextButton>
          </div>
        </div>
      </div>
    </div>
    <span v-if="errorMessage" class="text-sm text-n-ruby-11">
      {{ errorMessage }}
    </span>
  </li>
</template>
