<template>
  <div class="flex flex-col flex-1 h-full overflow-hidden">
    <div class="flex flex-col w-full h-full md:flex-row">
      <!-- Left panel: Steps (like MacroNodes) -->
      <div
        class="flex-1 w-full h-full px-4 py-4 overflow-y-auto md:px-12 sequence-gradient-radial dark:sequence-dark-gradient-radial sequence-gradient-radial-size"
      >
        <div class="flex flex-col items-start gap-4 py-6">
          <!-- Start label -->
          <span
            class="inline-block px-3 py-1 text-xs font-medium border rounded-md text-n-teal-11 border-n-teal-9 bg-n-teal-3"
          >
            {{ $t('MESSAGE_SEQUENCES.STEPS.TITLE') }}
          </span>

          <!-- Connector line -->
          <div class="w-px h-6 ml-6 border-l border-dashed border-n-slate-9" />

          <!-- Steps -->
          <div
            v-for="(step, index) in visibleSteps"
            :key="index"
            class="w-full max-w-xl"
          >
            <div
              class="relative p-4 border rounded-lg border-n-weak bg-n-solid-2 shadow-sm"
            >
              <button
                v-if="visibleSteps.length > 1"
                class="absolute text-n-slate-9 hover:text-n-red-11 top-3 right-3 clear"
                @click="removeStep(getActualIndex(step))"
              >
                <span class="i-lucide-trash size-4" />
              </button>
              <div class="flex gap-4">
                <div class="w-full">
                  <label class="block mb-1 text-xs text-n-slate-11">{{
                    $t('MESSAGE_SEQUENCES.STEPS.TYPE')
                  }}</label>
                  <select
                    v-model="step.step_type"
                    class="w-full p-2 text-sm border rounded-md input border-n-weak"
                  >
                    <option value="send_message">Enviar mensagem</option>
                    <option value="send_image">Enviar imagem</option>
                    <option value="send_document">Enviar documento</option>
                    <option value="send_audio">Enviar áudio</option>
                    <option value="execute_macro">{{ $t('MESSAGE_SEQUENCES.STEPS.TYPE_MACRO') }}</option>
                    <option value="send_template">{{ $t('MESSAGE_SEQUENCES.STEPS.TYPE_TEMPLATE') }}</option>
                  </select>
                </div>
              </div>
              <div class="mt-3">
                <label class="block mb-1 text-xs text-n-slate-11">
                  {{ $t('MESSAGE_SEQUENCES.STEPS.WAIT_TIME') }}
                </label>
                <div class="flex items-end gap-2">
                  <div class="flex flex-col items-center">
                    <span class="mb-1 text-[10px] text-n-slate-10">Dias</span>
                    <input
                      :value="parseWaitTime(step.wait_time).days"
                      type="number"
                      min="0"
                      class="w-16 p-2 text-sm text-center border rounded-md input border-n-weak"
                      @input="e => updateWaitTimePart(step, 'days', e.target.value)"
                    />
                  </div>
                  <span class="pb-2 text-n-slate-10">:</span>
                  <div class="flex flex-col items-center">
                    <span class="mb-1 text-[10px] text-n-slate-10">Horas</span>
                    <input
                      :value="parseWaitTime(step.wait_time).hours"
                      type="number"
                      min="0"
                      max="23"
                      class="w-16 p-2 text-sm text-center border rounded-md input border-n-weak"
                      @input="e => updateWaitTimePart(step, 'hours', e.target.value)"
                    />
                  </div>
                  <span class="pb-2 text-n-slate-10">:</span>
                  <div class="flex flex-col items-center">
                    <span class="mb-1 text-[10px] text-n-slate-10">Min</span>
                    <input
                      :value="parseWaitTime(step.wait_time).minutes"
                      type="number"
                      min="0"
                      max="59"
                      class="w-16 p-2 text-sm text-center border rounded-md input border-n-weak"
                      @input="e => updateWaitTimePart(step, 'minutes', e.target.value)"
                    />
                  </div>
                  <span class="pb-2 text-n-slate-10">:</span>
                  <div class="flex flex-col items-center">
                    <span class="mb-1 text-[10px] text-n-slate-10">Seg</span>
                    <input
                      :value="parseWaitTime(step.wait_time).seconds"
                      type="number"
                      min="0"
                      max="59"
                      class="w-16 p-2 text-sm text-center border rounded-md input border-n-weak"
                      @input="e => updateWaitTimePart(step, 'seconds', e.target.value)"
                    />
                  </div>
                </div>
              </div>
              <div class="mt-3">
                <label
                  v-if="step.step_type === 'send_message'"
                  class="block mb-1 text-xs text-n-slate-11"
                  >{{ $t('MESSAGE_SEQUENCES.STEPS.CONTENT') }}</label
                >
                <label
                  v-else-if="step.step_type === 'execute_macro'"
                  class="block mb-1 text-xs text-n-slate-11"
                >
                  {{ $t('MESSAGE_SEQUENCES.STEPS.MACRO_CONFIG') }}
                </label>
                <label
                  v-else-if="step.step_type === 'send_template'"
                  class="block mb-1 text-xs text-n-slate-11"
                >
                  {{ $t('MESSAGE_SEQUENCES.STEPS.TEMPLATE_CONFIG') }}
                </label>
                <label v-else class="block mb-1 text-xs text-n-slate-11">
                  Conteúdo do Arquivo
                </label>

                <!-- Message Input -->
                <textarea
                  v-if="step.step_type === 'send_message'"
                  v-model="step.content"
                  class="w-full input border border-n-weak bg-white dark:bg-n-solid-1 rounded-md p-2 text-sm min-h-[80px] outline-none focus:ring-1 focus:ring-n-blue-11"
                />

                <div v-else-if="step.step_type === 'execute_macro'">
                  <label class="block mb-1 text-xs text-n-slate-11">
                    {{ $t('MESSAGE_SEQUENCES.STEPS.CHOOSE_MACRO') }}
                  </label>
                  <select
                    v-model="step.macro_id"
                    class="w-full p-2 text-sm border rounded-md input border-n-weak bg-white dark:bg-n-solid-1"
                  >
                    <option value="" disabled>{{ $t('MESSAGE_SEQUENCES.STEPS.SELECT_MACRO') }}</option>
                    <option
                      v-for="macro in macros"
                      :key="macro.id"
                      :value="macro.id"
                    >
                      {{ macro.name }}
                    </option>
                  </select>
                </div>

                <!-- Send Template Option -->
                <div v-else-if="step.step_type === 'send_template'" class="flex flex-col gap-3">
                  <!-- Select Reference Inbox -->
                  <div>
                    <label class="block mb-1 text-xs text-n-slate-11">
                      {{ $t('MESSAGE_SEQUENCES.STEPS.CHOOSE_INBOX') }}
                    </label>
                    <select
                      v-model="step.template_inbox_id"
                      class="w-full p-2 text-sm border rounded-md input border-n-weak bg-white dark:bg-n-solid-1"
                      @change="onTemplateInboxChange(step)"
                    >
                      <option value="" disabled>{{ $t('MESSAGE_SEQUENCES.STEPS.SELECT_INBOX') }}</option>
                      <option
                        v-for="inbox in whatsappInboxes"
                        :key="inbox.id"
                        :value="inbox.id"
                      >
                        {{ inbox.name }}
                      </option>
                    </select>
                  </div>

                  <!-- Select Template -->
                  <div v-if="step.template_inbox_id">
                    <label class="block mb-1 text-xs text-n-slate-11">
                      {{ $t('MESSAGE_SEQUENCES.STEPS.CHOOSE_TEMPLATE') }}
                    </label>
                    <select
                      v-model="step.template_id"
                      class="w-full p-2 text-sm border rounded-md input border-n-weak bg-white dark:bg-n-solid-1"
                      @change="e => onTemplateChange(step, e)"
                    >
                      <option value="" disabled>{{ $t('MESSAGE_SEQUENCES.STEPS.SELECT_TEMPLATE') }}</option>
                      <option
                        v-for="tpl in getInboxTemplates(step.template_inbox_id)"
                        :key="tpl.id"
                        :value="tpl.id"
                      >
                        {{ formatTemplateName(tpl.name) }} ({{ tpl.language }})
                      </option>
                    </select>
                  </div>

                  <!-- Template Parser component -->
                  <WhatsAppTemplateParser
                    v-if="step.template_inbox_id && getSelectedTemplate(step)"
                    :ref="`templateParser_${index}`"
                    :template="getSelectedTemplate(step)"
                  />
                </div>

                <!-- Audio Input Options -->
                <div v-else-if="step.step_type === 'send_audio'" class="flex flex-col gap-2">
                  <div v-if="!step.file" class="flex items-center gap-2">
                    <button
                      v-if="recordingStepIndex !== index"
                      class="flex items-center gap-1 px-3 py-1.5 text-xs font-medium border rounded-md text-n-slate-11 border-n-weak hover:bg-n-alpha-1"
                      @click.prevent="startRecording(index)"
                    >
                      <span class="i-lucide-mic size-3" />
                      Gravar Áudio
                    </button>
                    <button
                      v-else
                      class="flex items-center gap-1 px-3 py-1.5 text-xs font-medium border rounded-md text-n-ruby-11 border-n-ruby-5 bg-n-ruby-2 hover:bg-n-ruby-3"
                      @click.prevent="stopRecording"
                      :disabled="isProcessingAudio"
                    >
                      <span v-if="isProcessingAudio" class="i-lucide-loader size-3 animate-spin" />
                      <span v-else class="i-lucide-square size-3" />
                      {{ isProcessingAudio ? 'Processando...' : `Parar (${recordingProgress})` }}
                    </button>
                    
                    <span v-if="recordingStepIndex !== index" class="text-xs text-n-slate-10">ou enviar arquivo:</span>
                    
                    <input
                      v-if="recordingStepIndex !== index"
                      :id="`file-input-${index}`"
                      type="file"
                      :accept="getAcceptType(step.step_type)"
                      class="block w-full text-xs text-n-slate-11 file:mr-2 file:py-1.5 file:px-3 file:rounded-md file:border-0 file:text-xs file:font-medium file:bg-n-blue-3 file:text-n-blue-11 hover:file:bg-n-blue-4"
                      @change="e => handleFileUpload(e, step)"
                    />
                  </div>

                  <div v-show="recordingStepIndex === index && !isProcessingAudio" class="w-full bg-n-solid-2 border border-n-weak rounded-md mt-2">
                    <AudioRecorder
                      v-if="recordingStepIndex === index"
                      ref="audioRecorder"
                      audio-record-format="audio/mp3"
                      @recorderProgressChanged="updateRecordingProgress"
                      @finishRecord="(fileObj) => handleRecordFinish(fileObj, step)"
                    />
                  </div>
                  
                  <div v-if="step.file" class="flex items-center justify-between mt-2 text-xs font-medium text-n-green-11 bg-n-green-2 border border-n-green-4 p-2 rounded-md">
                    <div>
                      <span class="i-lucide-check-circle size-3 align-middle mr-1" />
                      Mídia carregada: {{ step.file.name }}
                    </div>
                    <button class="text-n-ruby-9 hover:text-n-ruby-11" @click.prevent="removeFile(step, index)">
                      <span class="i-lucide-x size-4" />
                    </button>
                  </div>
                </div>

                <!-- Attachment/Document Input -->
                <div v-else class="flex flex-col gap-2">
                  <input
                    :id="`file-input-${index}`"
                    type="file"
                    :accept="getAcceptType(step.step_type)"
                    class="block w-full text-sm text-n-slate-11 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-n-blue-3 file:text-n-blue-11 hover:file:bg-n-blue-4"
                    @change="e => handleFileUpload(e, step)"
                  />
                  
                  <div v-if="step.file" class="flex items-center justify-between mt-1 text-xs font-medium text-n-green-11">
                    <span>Arquivo: {{ step.file.name }}</span>
                    <button class="text-n-ruby-9 hover:text-n-ruby-11" @click.prevent="removeFile(step, index)">
                      <span class="i-lucide-x size-4" />
                    </button>
                  </div>

                  <!-- Optional text content along with attachment -->
                  <textarea
                    v-model="step.content"
                    placeholder="Mensagem opcional com a mídia"
                    class="w-full mt-2 input border border-n-weak bg-white dark:bg-n-solid-1 rounded-md p-2 text-sm min-h-[60px] outline-none focus:ring-1 focus:ring-n-blue-11"
                  />
                </div>
              </div>
            </div>
            <!-- Connector line between steps -->
            <div
              class="w-px h-6 ml-6 border-l border-dashed border-n-slate-9"
            />
          </div>

          <!-- Add step button -->
          <button
            class="inline-flex items-center gap-1 px-4 py-2 text-sm font-medium border rounded-md text-n-blue-11 border-n-blue-9 bg-n-blue-3 hover:bg-n-blue-4"
            @click="addStep"
          >
            <span class="i-lucide-circle-plus size-4" />
            {{ $t('MESSAGE_SEQUENCES.STEPS.ADD') }}
          </button>

          <!-- Connector line -->
          <div class="w-px h-6 ml-6 border-l border-dashed border-n-slate-9" />

          <!-- End label -->
          <span
            class="inline-block px-3 py-1 text-xs font-medium border rounded-md text-n-blue-11 border-n-blue-9 bg-n-blue-3"
          >
            Fim da Sequência
          </span>
        </div>
      </div>

      <!-- Right panel: Properties (like MacroProperties) -->
      <div class="w-full h-full p-4 overflow-y-auto md:w-1/3 lg:w-1/4 min-w-[320px]">
        <div
          class="flex flex-col min-h-full p-4 border rounded-lg shadow-sm bg-n-solid-2 border-n-weak"
        >
          <!-- Name -->
          <div class="mb-4">
            <label
              class="block m-0 text-sm font-medium leading-[1.8] text-n-slate-12"
              >{{ $t('MESSAGE_SEQUENCES.FORM.NAME') }}</label
            >
            <input
              v-model="form.name"
              type="text"
              class="w-full p-2 text-sm border rounded-md input border-n-weak bg-n-alpha-1"
              placeholder="Ex: Onboarding Day 1"
            />
          </div>

          <!-- Activation Mode -->
          <div class="mb-4">
            <p
              class="block m-0 text-sm font-medium leading-[1.8] text-n-slate-12"
            >
              {{ $t('MESSAGE_SEQUENCES.RULES.ACTIVATION') }}
            </p>
            <select
              v-model="form.activation_type"
              class="w-full p-2 mb-3 text-sm border rounded-md input border-n-weak"
            >
              <option value="tag">
                {{ $t('MESSAGE_SEQUENCES.RULES.TAG') }}
              </option>
              <option value="always_active">
                {{ $t('MESSAGE_SEQUENCES.RULES.ALWAYS') }}
              </option>
              <option value="manual">
                {{ $t('MESSAGE_SEQUENCES.RULES.MANUAL') }}
              </option>
            </select>
            <p
              v-if="form.activation_type === 'manual'"
              class="text-xs text-n-slate-10"
            >
              {{ $t('MESSAGE_SEQUENCES.RULES.MANUAL_HELP') }}
            </p>
            <div v-if="form.activation_type === 'tag'">
              <label class="block mb-1 text-xs text-n-slate-11">
                Tags de Ativação (Qualquer uma delas ativará)
              </label>
              <div
                v-if="activationTagsList.length > 0"
                class="flex flex-wrap items-center gap-2 mb-2 p-2 rounded-md border border-n-weak bg-white dark:bg-n-solid-1"
              >
                <div
                  v-for="tag in activationTagsList"
                  :key="tag"
                  class="flex items-center gap-1 px-2 py-1 text-xs border rounded-md border-n-weak bg-n-alpha-1"
                >
                  <span class="text-n-slate-12">{{ tag }}</span>
                  <button
                    @click="removeTag(tag)"
                    class="text-n-ruby-9 hover:text-n-ruby-10 font-bold"
                  >
                    ✕
                  </button>
                </div>
              </div>
              <div
                class="relative w-full rounded-md border border-n-weak bg-white dark:bg-n-solid-1 p-2"
              >
                <LabelDropdown
                  :account-labels="accountLabels"
                  :selected-labels="activationTagsList"
                  :allow-creation="true"
                  @add="onAddLabel"
                  @remove="removeTag"
                />
              </div>
            </div>
          </div>

          <!-- Inbox scope -->
          <div class="mb-4">
            <p
              class="block m-0 text-sm font-medium leading-[1.8] text-n-slate-12"
            >
              {{ $t('MESSAGE_SEQUENCES.RULES.INBOX') }}
            </p>
            <select
              v-model="form.inbox_scope"
              class="w-full p-2 mb-3 text-sm border rounded-md input border-n-weak"
            >
              <option value="all_inboxes">
                {{ $t('MESSAGE_SEQUENCES.RULES.ALL_INBOXES') }}
              </option>
              <option value="selected_inboxes">
                {{ $t('MESSAGE_SEQUENCES.RULES.SELECTED_INBOXES') }}
              </option>
            </select>
            <div v-if="form.inbox_scope === 'selected_inboxes'">
              <label class="block mb-2 text-xs text-n-slate-11">
                Selecione as Inboxes
              </label>
              <div
                class="h-32 overflow-y-auto border border-n-weak rounded-md bg-white dark:bg-n-solid-1 p-2 space-y-2"
              >
                <label
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  class="flex items-center gap-2 cursor-pointer p-1 hover:bg-n-alpha-1 rounded-sm text-sm text-n-slate-12"
                >
                  <input
                    type="checkbox"
                    :value="inbox.id"
                    v-model="selectedInboxIds"
                    class="size-4"
                  />
                  <span
                    >{{ inbox.name }}
                    <span class="text-xs text-n-slate-10"
                      >({{ inbox.channel_type.split('::').pop() }})</span
                    ></span
                  >
                </label>
              </div>
            </div>
          </div>

          <!-- Configure Macro at the end -->
          <div class="mb-4 p-3 border rounded-md border-n-weak bg-n-solid-3">
            <label
              class="flex items-center gap-2 text-sm font-medium cursor-pointer mb-2"
            >
              <input
                v-model="form.enable_macro"
                type="checkbox"
                class="size-4"
              />
              <span class="text-n-slate-12"> Configurar macro ao final </span>
            </label>

            <div
              v-if="form.enable_macro"
              class="flex flex-col gap-3 mt-3 pt-3 border-t border-n-weak"
            >
              <div>
                <label class="block mb-1 text-xs text-n-slate-11">
                  Escolha o Macro
                </label>
                <select
                  v-model="form.macro_id"
                  class="w-full p-2 text-sm border rounded-md input border-n-weak"
                >
                  <option value="" disabled>Selecione um macro</option>
                  <option
                    v-for="macro in macros"
                    :key="macro.id"
                    :value="macro.id"
                  >
                    {{ macro.name }}
                  </option>
                </select>
              </div>
              <div>
                <label class="block mb-1 text-xs text-n-slate-11">
                  Tempo de ativação (minutos após a última mensagem)
                </label>
                <input
                  v-model.number="form.macro_execution_time"
                  type="number"
                  min="0"
                  class="w-full p-2 text-sm border rounded-md input border-n-weak"
                  placeholder="Ex: 0 para imediato"
                />
              </div>
            </div>
          </div>

          <!-- Active toggle -->
          <div class="p-3 mb-4 border rounded-md border-n-weak bg-n-solid-3">
            <label
              class="flex items-center gap-2 text-sm font-medium cursor-pointer"
            >
              <input v-model="form.active" type="checkbox" class="size-4" />
              <span
                :class="form.active ? 'text-n-green-11' : 'text-n-slate-11'"
              >
                {{ form.active ? 'Sequência Ativada' : 'Sequência Desativada' }}
              </span>
            </label>
          </div>

          <!-- Execution Interval Limit -->
          <div class="p-3 mb-4 border rounded-md border-n-weak bg-n-solid-3">
            <label
              class="flex items-center gap-2 text-sm font-medium cursor-pointer mb-2"
            >
              <input
                v-model="form.restrict_execution_time"
                type="checkbox"
                class="size-4"
              />
              <span class="text-n-slate-12"> Limitar horário de envio </span>
            </label>

            <div
              v-if="form.restrict_execution_time"
              class="flex items-center gap-3 mt-3 pt-3 border-t border-n-weak"
            >
              <div class="flex-1">
                <label class="block mb-1 text-xs text-n-slate-11">
                  Das (hora)
                </label>
                <input
                  v-model.number="form.execution_start_hour"
                  type="number"
                  min="0"
                  max="23"
                  class="w-full p-2 text-sm border rounded-md input border-n-weak"
                  placeholder="Ex: 8"
                />
              </div>
              <span class="mt-4 text-n-slate-11 text-sm">até</span>
              <div class="flex-1">
                <label class="block mb-1 text-xs text-n-slate-11">
                  Às (hora)
                </label>
                <input
                  v-model.number="form.execution_end_hour"
                  type="number"
                  min="0"
                  max="23"
                  class="w-full p-2 text-sm border rounded-md input border-n-weak"
                  placeholder="Ex: 19"
                />
              </div>
            </div>
            <p v-if="form.restrict_execution_time" class="mt-2 text-[10px] text-n-slate-10 leading-tight">
              Mensagens serão disparadas apenas neste intervalo. Fora dele, o sistema aguardará o início do próximo ciclo.
            </p>
          </div>

          <!-- Save Button at bottom -->
          <div class="w-full mt-auto pt-4">
            <button
              class="flex items-center justify-center w-full gap-2 px-4 py-2 text-sm font-medium text-white rounded-md bg-n-blue-11 hover:bg-n-blue-10"
              :disabled="uiFlags.isCreating || uiFlags.isUpdating"
              @click="save"
            >
              <span
                v-if="uiFlags.isCreating || uiFlags.isUpdating"
                class="i-lucide-loader animate-spin"
              />
              {{ $t('MESSAGE_SEQUENCES.SAVE') }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import LabelDropdown from 'shared/components/ui/label/LabelDropdown.vue';
import AudioRecorder from 'dashboard/components/widgets/WootWriter/AudioRecorder.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

export default {
  components: {
    LabelDropdown,
    AudioRecorder,
    WhatsAppTemplateParser,
  },
  data() {
    return {
      selectedInboxIds: [],
      recordingStepIndex: null,
      recordingProgress: '00:00',
      isProcessingAudio: false,
      form: {
        name: '',
        activation_type: 'tag',
        activation_tag: '',
        inbox_scope: 'all_inboxes',
        active: true,
        enable_macro: false,
        macro_id: '',
        macro_execution_time: 0,
        restrict_execution_time: false,
        execution_start_hour: 8,
        execution_end_hour: 19,
        steps_attributes: [
          {
            position: 1,
            step_type: 'send_message',
            content: '',
            wait_time: '0:00:00:00',
            macro_id: '',
            template_inbox_id: null,
            template_id: null,
            template_params: null,
          },
        ],
        message_sequence_inboxes_attributes: [],
      },
    };
  },
  computed: {
    ...mapGetters({
      records: 'messageSequences/getMessageSequences',
      uiFlags: 'messageSequences/getUIFlags',
      accountLabels: 'labels/getLabels',
      inboxes: 'inboxes/getInboxes',
      macros: 'macros/getMacros',
    }),
    isEditMode() {
      return !!this.$route.params.sequenceId;
    },
    visibleSteps() {
      return this.form.steps_attributes.filter(s => !s._destroy);
    },
    activationTagsList() {
      if (!this.form.activation_tag) return [];
      return this.form.activation_tag.split(',').filter(t => t.trim());
    },
    whatsappInboxes() {
      return this.inboxes.filter(
        inbox => inbox.channel_type === 'Channel::Whatsapp'
      );
    },
  },
  watch: {
    inboxes: {
      immediate: true,
      handler() {
        this.form.steps_attributes.forEach(step => {
          if (step.step_type === 'send_template' && !step.template_inbox_id) {
            this.resolveTemplateReference(step);
          }
        });
      }
    }
  },
  mounted() {
    this.$store.dispatch('labels/get');
    this.$store.dispatch('inboxes/get');
    this.$store.dispatch('macros/get');
    if (this.isEditMode) {
      this.fetchSequence();
    }
  },
  methods: {
    parseWaitTime(waitTime) {
      const parts = (waitTime || '0:00:00:00').split(':');
      return {
        days: parseInt(parts[0], 10) || 0,
        hours: parseInt(parts[1], 10) || 0,
        minutes: parseInt(parts[2], 10) || 0,
        seconds: parseInt(parts[3], 10) || 0,
      };
    },
    updateWaitTimePart(step, part, value) {
      const parsed = this.parseWaitTime(step.wait_time);
      let num = parseInt(value, 10) || 0;
      if (num < 0) num = 0;
      if (part === 'hours' && num > 23) num = 23;
      if ((part === 'minutes' || part === 'seconds') && num > 59) num = 59;
      parsed[part] = num;
      step.wait_time = `${parsed.days}:${String(parsed.hours).padStart(2, '0')}:${String(parsed.minutes).padStart(2, '0')}:${String(parsed.seconds).padStart(2, '0')}`;
    },
    normalizeWaitTime(waitTime) {
      if (!waitTime) return '0:00:00:00';
      const parts = waitTime.split(':');
      if (parts.length === 2) {
        return `0:${parts[0].padStart(2, '0')}:${parts[1].padStart(2, '0')}:00`;
      }
      return waitTime;
    },
    onAddLabel(label) {
      const tag = label.title || label;
      const currentTags = this.form.activation_tag
        ? this.form.activation_tag.split(',').filter(Boolean)
        : [];
      if (!currentTags.includes(tag)) {
        currentTags.push(tag);
        this.form.activation_tag = currentTags.join(',');
      }
    },
    removeTag(tagToRemove) {
      const tag =
        typeof tagToRemove === 'string'
          ? tagToRemove
          : tagToRemove.title || tagToRemove;
      const currentTags = this.form.activation_tag
        ? this.form.activation_tag.split(',').filter(Boolean)
        : [];
      this.form.activation_tag = currentTags.filter(t => t !== tag).join(',');
    },
    getActualIndex(step) {
      return this.form.steps_attributes.indexOf(step);
    },
    async fetchSequence() {
      try {
        await this.$store.dispatch(
          'messageSequences/getSingle',
          this.$route.params.sequenceId
        );
        const seq = this.$store.getters['messageSequences/getMessageSequence'](
          this.$route.params.sequenceId
        );
        if (seq) {
          this.form = {
            name: seq.name,
            activation_type: seq.activation_type,
            activation_tag: seq.activation_tag,
            inbox_scope: seq.inbox_scope,
            active: seq.active,
            enable_macro: !!seq.macro_id,
            macro_id: seq.macro_id || '',
            macro_execution_time: seq.macro_execution_time || 0,
            restrict_execution_time: seq.restrict_execution_time || false,
            execution_start_hour: seq.execution_start_hour ?? 8,
            execution_end_hour: seq.execution_end_hour ?? 19,
            steps_attributes: seq.steps
              ? seq.steps.map(s => {
                  const step = {
                    ...s,
                    macro_id: s.macro_id || '',
                    wait_time: this.normalizeWaitTime(s.wait_time),
                    template_inbox_id: null,
                    template_id: null,
                  };
                  if (step.step_type === 'send_template') {
                    this.resolveTemplateReference(step);
                  }
                  return step;
                })
              : [],
            message_sequence_inboxes_attributes: seq.inbox_ids
              ? seq.inbox_ids.map(id => ({ inbox_id: id }))
              : [],
          };
          this.selectedInboxIds = seq.inbox_ids ? seq.inbox_ids : [];
        }
      } catch (error) {
        useAlert(this.$t('MESSAGE_SEQUENCES.EDIT.FETCH_ERROR'));
      }
    },
    addStep() {
      this.form.steps_attributes.push({
        position: this.form.steps_attributes.length + 1,
        step_type: 'send_message',
        content: '',
        wait_time: '0:00:00:00',
        macro_id: '',
        template_inbox_id: null,
        template_id: null,
        template_params: null,
      });
    },
    removeStep(index) {
      if (this.isEditMode && this.form.steps_attributes[index].id) {
        this.form.steps_attributes[index]._destroy = 1;
      } else {
        this.form.steps_attributes.splice(index, 1);
      }
      this.reorderSteps();
    },
    reorderSteps() {
      let currentPosition = 1;
      this.form.steps_attributes.forEach(step => {
        if (!step._destroy) {
          step.position = currentPosition++;
        }
      });
    },
    parseInboxes() {
      if (
        this.form.inbox_scope === 'selected_inboxes' &&
        this.selectedInboxIds.length > 0
      ) {
        this.form.inbox_ids = this.selectedInboxIds;
      } else {
        this.form.inbox_ids = [];
      }
    },
    buildFormData() {
      const formData = new FormData();
      formData.append('name', this.form.name);
      formData.append('activation_type', this.form.activation_type);
      formData.append('activation_tag', this.form.activation_tag || '');
      formData.append('inbox_scope', this.form.inbox_scope);
      formData.append('active', this.form.active);

      if (this.form.enable_macro && this.form.macro_id) {
        formData.append('macro_id', this.form.macro_id);
        formData.append(
          'macro_execution_time',
          this.form.macro_execution_time || 0
        );
      } else {
        formData.append('macro_id', '');
        formData.append('macro_execution_time', 0);
      }

      formData.append('restrict_execution_time', this.form.restrict_execution_time);
      if (this.form.restrict_execution_time) {
        formData.append('execution_start_hour', this.form.execution_start_hour);
        formData.append('execution_end_hour', this.form.execution_end_hour);
      }

      this.form.steps_attributes.forEach((step, index) => {
        if (step.id) {
          formData.append(`steps_attributes[${index}][id]`, step.id);
        }
        formData.append(`steps_attributes[${index}][position]`, step.position);
        formData.append(
          `steps_attributes[${index}][step_type]`,
          step.step_type
        );
        formData.append(
          `steps_attributes[${index}][content]`,
          step.content || ''
        );
        formData.append(
          `steps_attributes[${index}][wait_time]`,
          step.wait_time || ''
        );
        formData.append(
          `steps_attributes[${index}][macro_id]`,
          step.macro_id || ''
        );

        if (step.template_params) {
          formData.append(`steps_attributes[${index}][template_params][name]`, step.template_params.name || '');
          formData.append(`steps_attributes[${index}][template_params][namespace]`, step.template_params.namespace || '');
          formData.append(`steps_attributes[${index}][template_params][category]`, step.template_params.category || 'UTILITY');
          formData.append(`steps_attributes[${index}][template_params][language]`, step.template_params.language || 'en');
          
          if (step.template_params.processed_params) {
            Object.keys(step.template_params.processed_params).forEach(key => {
              formData.append(`steps_attributes[${index}][template_params][processed_params][${key}]`, step.template_params.processed_params[key]);
            });
          }
        }

        if (step.file && step.file instanceof File) {
          formData.append(`steps_attributes[${index}][file]`, step.file);
        }
        if (step._destroy) {
          formData.append(`steps_attributes[${index}][_destroy]`, 1);
        }
      });

      this.form.inbox_ids.forEach((id) => {
        formData.append('inbox_ids[]', id);
      });

      return formData;
    },
    async save() {
      if (!this.form.name) {
        useAlert(this.$t('MESSAGE_SEQUENCES.FORM.NAME_REQUIRED'));
        return;
      }

      this.parseInboxes();
      this.reorderSteps();

      // Atualiza os processedParams com os dados digitados no componente parser de template do WhatsApp
      this.form.steps_attributes.forEach((step, idx) => {
        if (step.step_type === 'send_template' && step.template_params) {
          const parser = this.$refs[`templateParser_${idx}`];
          const parserInstance = Array.isArray(parser) ? parser[0] : parser;
          if (parserInstance) {
            step.template_params.processed_params = parserInstance.processedParams || {};
          }
        }
      });

      const payload = this.buildFormData();

      try {
        if (this.isEditMode) {
          payload.append('id', this.$route.params.sequenceId);
          await this.$store.dispatch('messageSequences/update', payload);
          useAlert(this.$t('MESSAGE_SEQUENCES.EDIT.SUCCESS'));
        } else {
          await this.$store.dispatch('messageSequences/create', payload);
          useAlert(this.$t('MESSAGE_SEQUENCES.NEW.SUCCESS'));
          this.$router.push({ name: 'message_sequences_wrapper' });
        }
      } catch (error) {
        useAlert(error.message || this.$t('MESSAGE_SEQUENCES.FORM.ERROR'));
      }
    },
    handleFileUpload(event, step) {
      const file = event.target.files[0];
      if (!file) return;

      step.file = file;
    },
    removeFile(step, index) {
      step.file = null;
      
      const fileInput = document.getElementById(`file-input-${index}`);
      if (fileInput) {
        fileInput.value = '';
      }
    },
    startRecording(index) {
      this.recordingStepIndex = index;
      this.recordingProgress = '00:00';
      this.isProcessingAudio = false;
    },
    stopRecording() {
      if (this.$refs.audioRecorder && this.$refs.audioRecorder[0]) {
        this.$refs.audioRecorder[0].stopRecording();
      }
      this.isProcessingAudio = true;
    },
    updateRecordingProgress(timeString) {
      this.recordingProgress = timeString;
    },
    handleRecordFinish(fileObj, step) {
      step.file = fileObj.file;
      this.recordingStepIndex = null;
      this.isProcessingAudio = false;
    },
    getAcceptType(type) {
      if (type === 'send_image') return 'image/*';
      if (type === 'send_audio') return 'audio/*,video/mp4';
      if (type === 'send_document') return '.pdf,.doc,.docx,.xls,.xlsx,.txt,.csv';
      return '*/*';
    },
    onTemplateInboxChange(step) {
      step.template_id = '';
      step.template_params = null;
    },
    onTemplateChange(step, event) {
      const templateId = event.target.value;
      step.template_id = templateId;
      
      const templates = this.getInboxTemplates(step.template_inbox_id);
      const template = templates.find(t => t.id === templateId || t.name === templateId);

      if (template) {
        step.template_params = {
          name: template.name,
          namespace: template.namespace,
          category: template.category || 'UTILITY',
          language: template.language || 'en',
          processed_params: {}
        };
      } else {
        step.template_params = null;
      }
    },
    getInboxTemplates(inboxId) {
      const inbox = this.inboxes.find(i => i.id === inboxId);
      return inbox ? (inbox.message_templates || []) : [];
    },
    getSelectedTemplate(step) {
      if (!step.template_inbox_id || !step.template_id) return null;
      const templates = this.getInboxTemplates(step.template_inbox_id);
      return templates.find(t => t.id === step.template_id || t.name === step.template_id);
    },
    formatTemplateName(name) {
      if (!name) return '';
      return name
        .replace(/_/g, ' ')
        .replace(/\b\w/g, l => l.toUpperCase());
    },
    resolveTemplateReference(step) {
      if (!step.template_params || !step.template_params.name) return;

      const name = step.template_params.name;
      const language = step.template_params.language;

      const matchedInbox = this.whatsappInboxes.find(inbox => {
        const templates = inbox.message_templates || [];
        return templates.some(t => t.name === name);
      });

      if (matchedInbox) {
        step.template_inbox_id = matchedInbox.id;
        const templates = matchedInbox.message_templates || [];
        const matchedTemplate = templates.find(t => t.name === name && (!language || t.language === language));
        if (matchedTemplate) {
          step.template_id = matchedTemplate.id || matchedTemplate.name;
        }
      }
    },
  },
};
</script>

<style scoped>
@tailwind components;

@layer components {
  .sequence-gradient-radial {
    background-image: radial-gradient(#ebf0f5 1.2px, transparent 0);
  }

  .sequence-dark-gradient-radial {
    background-image: radial-gradient(#293f51 1.2px, transparent 0);
  }

  .sequence-gradient-radial-size {
    background-size: 1rem 1rem;
  }
}
</style>
