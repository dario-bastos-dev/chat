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

    <div v-if="!isTemplateRequired && !selectedTemplate">
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

      <div v-if="selectedTemplate" class="mt-2 flex items-center justify-between mb-2">
        <span class="text-sm font-medium text-n-slate-12">
          {{ $t('SCHEDULED_MESSAGES.FORM.TEMPLATE_SELECTED', { name: selectedTemplate.name }) }}
        </span>
        <button @click="clearTemplate" class="text-xs text-n-ruby-9 hover:underline">
          Remover Template
        </button>
      </div>

      <WhatsAppTemplateParser
        v-if="selectedTemplate"
        ref="templateParser"
        :template="selectedTemplate"
        @send-message="onParserSubmit"
      >
        <template #actions>
          <div class="hidden"></div>
        </template>
      </WhatsAppTemplateParser>

      <div v-if="showTemplatePicker && !selectedTemplate" class="mt-2">
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
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

export default {
  components: {
    TemplatesPicker,
    WhatsAppTemplateParser,
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
        !['evolution', 'evolution_go'].includes(this.inbox?.provider)
      );
    },
    scheduledAt() {
      if (!this.form.date || !this.form.time) return null;
      const date = new Date(`${this.form.date}T${this.form.time}`);
      return isNaN(date.getTime()) ? null : date.toISOString();
    },
    lastIncomingMessageAt() {
      const messages = this.currentChat?.messages || [];
      if (!messages.length) return null;
      const incoming = messages.filter(m => m.message_type === 0);
      if (!incoming.length) return null;
      
      const ts = incoming[incoming.length - 1].created_at;
      // Garante que se for timestamp em segundos (10 digitos), seja convertido para ms
      return String(ts).length === 10 ? ts * 1000 : ts;
    },
    isMoreThan24Hours() {
      let windowExpiresAt;

      if (this.lastIncomingMessageAt) {
        windowExpiresAt = this.lastIncomingMessageAt + (24 * 60 * 60 * 1000);
      } else {
        windowExpiresAt = 0; // Assume window is closed se não houver mensagem recebida
      }

      // Se não temos agendamento completo ainda, validamos em relação ao "agora".
      // Isso bloqueia o campo de texto imediatamente se a janela já estiver fechada.
      if (!this.scheduledAt) {
        return Date.now() > windowExpiresAt;
      }

      const scheduledDate = new Date(this.scheduledAt).getTime();
      return scheduledDate > windowExpiresAt;
    },
    isTemplateRequired() {
      return this.isWhatsAppBusinessCloud && this.isMoreThan24Hours;
    },
    isFormValid() {
      const baseValid = this.form.date && this.form.time && this.form.title;
      if (this.selectedTemplate) {
        return baseValid; // Validação do template ocorre no parser ao submeter
      }
      return baseValid && this.form.content;
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
    onParserSubmit(parserPayload) {
      const payload = {
        title: this.form.title,
        content: parserPayload.message || '-',
        scheduled_at: this.scheduledAt,
        template_params: parserPayload.templateParams,
      };
      this.$emit('submit', payload);
    },
    submit() {
      if (!this.isFormValid) return;

      if (this.selectedTemplate) {
        this.$refs.templateParser.sendMessage();
        return;
      }

      const payload = {
        title: this.form.title,
        content: this.form.content,
        scheduled_at: this.scheduledAt,
      };

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
