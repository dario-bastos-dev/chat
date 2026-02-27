<template>
  <div class="flex flex-col gap-4">
    <div class="flex items-center gap-2">
      <div class="w-1/2">
        <label>
          {{ $t('SCHEDULED_MESSAGES.FORM.DATE') }}
          <input type="date" v-model="form.date" class="w-full mt-1 input" />
        </label>
      </div>
      <div class="w-1/2">
        <label>
          {{ $t('SCHEDULED_MESSAGES.FORM.TIME') }}
          <input type="time" v-model="form.time" class="w-full mt-1 input" />
        </label>
      </div>
    </div>

    <div>
      <label>
        {{ $t('SCHEDULED_MESSAGES.FORM.TITLE') }}
        <input
          type="text"
          v-model="form.title"
          class="w-full mt-1 input"
          placeholder="Ex: Aviso mensal"
        />
      </label>
    </div>

    <div>
      <label>
        {{ $t('SCHEDULED_MESSAGES.FORM.CONTENT') }}
        <textarea
          v-model="form.content"
          class="w-full mt-1 min-h-[100px] input"
          placeholder="Escreva a mensagem aqui..."
        />
      </label>
    </div>

    <!-- WhatsApp Business Cloud Template Selection -->
    <div v-if="isWhatsAppBusinessCloud">
      <label class="text-sm font-medium text-n-slate-12">
        {{ $t('SCHEDULED_MESSAGES.FORM.TEMPLATE') }}
        <span v-if="isTemplateRequired" class="text-n-ruby-9">*</span>
      </label>
      <p v-if="isTemplateRequired" class="text-xs text-n-ruby-9 mt-1 mb-2">
        {{ $t('SCHEDULED_MESSAGES.FORM.TEMPLATE_REQUIRED') }}
      </p>

      <div
        v-if="selectedTemplate"
        class="mt-2 p-3 rounded-md border border-n-blue-5 bg-n-blue-2"
      >
        <div class="flex items-center justify-between">
          <span class="text-sm text-n-blue-11">
            {{
              $t('SCHEDULED_MESSAGES.FORM.TEMPLATE_SELECTED', {
                name: selectedTemplate.name,
              })
            }}
          </span>
          <button
            @click="clearTemplate"
            class="text-xs text-n-ruby-9 hover:text-n-ruby-10"
          >
            ✕
          </button>
        </div>
      </div>

      <div v-if="showTemplatePicker" class="mt-2">
        <TemplatesPicker :inbox-id="inboxId" @on-select="onTemplateSelect" />
      </div>
      <button
        v-else-if="!selectedTemplate"
        @click="showTemplatePicker = true"
        class="mt-2 px-3 py-1.5 text-sm rounded-md border border-n-weak bg-n-alpha-1 text-n-slate-12 hover:border-n-slate-8 transition-colors"
      >
        {{ $t('SCHEDULED_MESSAGES.FORM.SELECT_TEMPLATE') }}
      </button>
    </div>

    <div class="flex items-center justify-end gap-2">
      <button
        @click="$emit('cancel')"
        class="px-4 py-1.5 text-sm font-medium rounded-md text-white bg-n-ruby-9 hover:bg-n-ruby-10 transition-colors"
      >
        {{ $t('SCHEDULED_MESSAGES.FORM.CANCEL') }}
      </button>
      <button
        @click="submit"
        class="px-4 py-1.5 text-sm font-medium rounded-md text-white bg-n-blue-11 hover:bg-n-blue-10 transition-colors"
        :disabled="isSubmitting || !isFormValid"
      >
        {{ $t('SCHEDULED_MESSAGES.FORM.CONFIRM') }}
      </button>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import TemplatesPicker from 'dashboard/components/widgets/conversation/WhatsappTemplates/TemplatesPicker.vue';

export default {
  components: {
    TemplatesPicker,
  },
  props: {
    initialData: {
      type: Object,
      default: () => ({}),
    },
    isSubmitting: {
      type: Boolean,
      default: false,
    },
    conversationId: {
      type: [Number, String],
      default: null,
    },
  },
  data() {
    return {
      form: {
        date: '',
        time: '',
        title: '',
        content: '',
      },
      selectedTemplate: null,
      showTemplatePicker: false,
    };
  },
  computed: {
    ...mapGetters({
      currentChat: 'getSelectedChat',
      getInbox: 'inboxes/getInbox',
    }),
    inbox() {
      const inboxId = this.currentChat?.inbox_id;
      return inboxId ? this.getInbox(inboxId) : {};
    },
    inboxId() {
      return this.currentChat?.inbox_id;
    },
    isWhatsAppBusinessCloud() {
      return (
        this.inbox?.channel_type === 'Channel::Whatsapp' &&
        this.inbox?.provider !== 'evolution'
      );
    },
    scheduledAt() {
      if (!this.form.date || !this.form.time) return null;
      const date = new Date(`${this.form.date}T${this.form.time}`);
      return date.toISOString();
    },
    isMoreThan24Hours() {
      if (!this.scheduledAt) return false;
      const scheduledDate = new Date(this.scheduledAt);
      const now = new Date();
      const diffMs = scheduledDate - now;
      const diffHours = diffMs / (1000 * 60 * 60);
      return diffHours > 24;
    },
    isTemplateRequired() {
      return this.isWhatsAppBusinessCloud && this.isMoreThan24Hours;
    },
    isFormValid() {
      const baseValid =
        this.form.date &&
        this.form.time &&
        this.form.title &&
        this.form.content;
      if (this.isTemplateRequired) {
        return baseValid && this.selectedTemplate;
      }
      return baseValid;
    },
  },
  mounted() {
    if (this.initialData.id) {
      this.form.title = this.initialData.title;
      this.form.content = this.initialData.content;
      if (this.initialData.scheduled_at) {
        const d = new Date(this.initialData.scheduled_at * 1000);
        this.form.date = d.toISOString().split('T')[0];
        this.form.time = d.toISOString().split('T')[1].substring(0, 5);
      }
      if (this.initialData.template_params) {
        this.selectedTemplate = this.initialData.template_params;
      }
    }
  },
  methods: {
    onTemplateSelect(template) {
      this.selectedTemplate = template;
      this.showTemplatePicker = false;
    },
    clearTemplate() {
      this.selectedTemplate = null;
      this.showTemplatePicker = false;
    },
    submit() {
      if (!this.isFormValid) return;
      const payload = {
        title: this.form.title,
        content: this.form.content,
        scheduled_at: this.scheduledAt,
      };

      if (this.selectedTemplate) {
        payload.template_params = {
          name: this.selectedTemplate.name,
          category: this.selectedTemplate.category,
          language: this.selectedTemplate.language,
          namespace: this.selectedTemplate.namespace || '',
          processed_params: {},
        };
      }

      this.$emit('submit', payload);
    },
  },
};
</script>

<style scoped>
.input {
  @apply rounded-md border border-n-weak bg-n-alpha-1 px-3 py-2 text-sm text-n-slate-12 outline-none transition-all placeholder:text-n-slate-10 hover:border-n-slate-8 focus:border-n-blue-11 focus:ring-1 focus:ring-n-blue-11;
}
</style>
