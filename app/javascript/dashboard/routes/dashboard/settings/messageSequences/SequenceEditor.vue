<template>
  <div class="flex flex-col flex-1 h-full overflow-auto">
    <div class="flex flex-col w-full h-auto md:flex-row md:h-full">
      <!-- Left panel: Steps (like MacroNodes) -->
      <div
        class="flex-1 w-full h-full max-h-full px-12 py-4 overflow-y-auto md:w-auto sequence-gradient-radial dark:sequence-dark-gradient-radial sequence-gradient-radial-size"
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
                <div class="w-1/2">
                  <label class="block mb-1 text-xs text-n-slate-11">{{
                    $t('MESSAGE_SEQUENCES.STEPS.TYPE')
                  }}</label>
                  <select
                    v-model="step.step_type"
                    class="w-full p-2 text-sm border rounded-md input border-n-weak"
                  >
                    <option value="send_message">Enviar mensagem</option>
                    <option value="send_attachment">Enviar anexo</option>
                  </select>
                </div>
                <div class="w-1/2">
                  <label class="block mb-1 text-xs text-n-slate-11"
                    >{{
                      $t('MESSAGE_SEQUENCES.STEPS.WAIT_TIME')
                    }}
                    (HH:MM)</label
                  >
                  <input
                    v-model="step.wait_time"
                    type="time"
                    class="w-full p-2 text-sm border rounded-md input border-n-weak"
                  />
                </div>
              </div>
              <div class="mt-3">
                <label
                  v-if="step.step_type === 'send_message'"
                  class="block mb-1 text-xs text-n-slate-11"
                  >{{ $t('MESSAGE_SEQUENCES.STEPS.CONTENT') }}</label
                >
                <label v-else class="block mb-1 text-xs text-n-slate-11">
                  Conteúdo do Anexo
                </label>

                <!-- Message Input -->
                <textarea
                  v-if="step.step_type === 'send_message'"
                  v-model="step.content"
                  class="w-full input border border-n-weak bg-white dark:bg-n-solid-1 rounded-md p-2 text-sm min-h-[80px] outline-none focus:ring-1 focus:ring-n-blue-11"
                />

                <!-- Attachment Input -->
                <div v-else class="flex flex-col gap-2">
                  <input
                    type="file"
                    class="block w-full text-sm text-n-slate-11 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-n-blue-3 file:text-n-blue-11 hover:file:bg-n-blue-4"
                    @change="e => handleFileUpload(e, step)"
                  />
                  <!-- Optional text content along with attachment -->
                  <textarea
                    v-model="step.content"
                    placeholder="Mensagem opcional com o anexo"
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
      <div class="w-full pb-4 md:w-1/3">
        <div
          class="flex flex-col h-full p-4 border rounded-lg shadow-sm bg-n-solid-2 border-n-weak"
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
            </select>
            <div v-if="form.activation_type === 'tag'">
              <label class="block mb-1 text-xs text-n-slate-11">
                Nome da Tag
              </label>
              <div
                v-if="form.activation_tag"
                class="flex items-center gap-2 mb-2 p-2 rounded-md border border-n-weak bg-white dark:bg-n-solid-1"
              >
                <span class="text-sm text-n-slate-12">{{
                  form.activation_tag
                }}</span>
                <button
                  @click="form.activation_tag = ''"
                  class="ml-auto text-xs text-n-ruby-9 hover:text-n-ruby-10"
                >
                  ✕
                </button>
              </div>
              <div
                v-else
                class="relative w-full rounded-md border border-n-weak bg-white dark:bg-n-solid-1 p-2"
              >
                <LabelDropdown
                  :account-labels="accountLabels"
                  :selected-labels="[]"
                  :allow-creation="true"
                  @add="onAddLabel"
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

          <!-- Save Button at bottom -->
          <div class="w-full mt-auto">
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

export default {
  components: {
    LabelDropdown,
  },
  data() {
    return {
      selectedInboxIds: [],
      form: {
        name: '',
        activation_type: 'tag',
        activation_tag: '',
        inbox_scope: 'all_inboxes',
        active: true,
        enable_macro: false,
        macro_id: '',
        macro_execution_time: 0,
        steps_attributes: [
          {
            position: 1,
            step_type: 'send_message',
            content: '',
            wait_time: '00:00',
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
    onAddLabel(label) {
      this.form.activation_tag = label.title || label;
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
            steps_attributes: seq.steps ? [...seq.steps] : [],
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
        wait_time: '00:00',
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
        this.form.message_sequence_inboxes_attributes =
          this.selectedInboxIds.map(id => ({
            inbox_id: id,
          }));
      } else {
        this.form.message_sequence_inboxes_attributes = [];
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

        if (step.file) {
          formData.append(`steps_attributes[${index}][file]`, step.file);
        }
        if (step._destroy) {
          formData.append(`steps_attributes[${index}][_destroy]`, 1);
        }
      });

      this.form.message_sequence_inboxes_attributes.forEach(
        (inboxAssoc, index) => {
          formData.append(
            `message_sequence_inboxes_attributes[${index}][inbox_id]`,
            inboxAssoc.inbox_id
          );
        }
      );

      return formData;
    },
    async save() {
      if (!this.form.name) {
        useAlert(this.$t('MESSAGE_SEQUENCES.FORM.NAME_REQUIRED'));
        return;
      }

      this.parseInboxes();
      this.reorderSteps();

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
