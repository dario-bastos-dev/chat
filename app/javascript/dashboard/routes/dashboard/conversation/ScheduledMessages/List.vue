<template>
  <div class="scheduled-messages-wrap">
    <div class="p-4 border-b border-n-weak flex justify-end items-center">
      <button
        @click="showForm = true"
        class="p-1 border bg-n-blue-2 border-n-blue-5 rounded text-n-blue-11 hover:bg-n-blue-3 text-sm"
      >
        + {{ $t('SCHEDULED_MESSAGES.ADD_NEW') }}
      </button>
    </div>

    <div v-if="showForm" class="p-4 border-b border-n-weak">
      <ScheduledMessageForm
        :initial-data="editingMessage"
        @submit="save"
        @cancel="cancelForm"
      />
    </div>

    <div class="p-4 flex flex-col gap-3">
      <div v-if="uiFlags.isFetching" class="text-sm text-n-slate-10">
        {{ $t('SCHEDULED_MESSAGES.LOADING') }}
      </div>
      <div v-else-if="!records.length" class="text-sm text-n-slate-10">
        {{ $t('SCHEDULED_MESSAGES.EMPTY') }}
      </div>
      <template v-else>
        <ScheduledMessageItem
          v-for="msg in records"
          :key="msg.id"
          :message="msg"
          @edit="openEdit"
          @delete="deleteMessage"
        />
      </template>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import ScheduledMessageItem from './ScheduledMessageItem.vue';
import ScheduledMessageForm from './ScheduledMessageForm.vue';

export default {
  components: {
    ScheduledMessageItem,
    ScheduledMessageForm,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  data() {
    return {
      showForm: false,
      editingMessage: {},
    };
  },
  computed: {
    ...mapGetters({
      records: 'scheduledMessages/getScheduledMessages',
      uiFlags: 'scheduledMessages/getUIFlags',
    }),
  },
  mounted() {
    this.fetchData();
  },
  watch: {
    conversationId() {
      this.fetchData();
    },
  },
  methods: {
    fetchData() {
      this.$store.dispatch('scheduledMessages/get', this.conversationId);
    },
    openEdit(msg) {
      this.editingMessage = msg;
      this.showForm = true;
    },
    cancelForm() {
      this.showForm = false;
      this.editingMessage = {};
    },
    async save(data) {
      const payload = {
        conversationId: this.conversationId,
        macrosObj: data,
      };

      if (this.editingMessage.id) {
        payload.id = this.editingMessage.id;
        await this.$store.dispatch('scheduledMessages/update', payload);
      } else {
        await this.$store.dispatch('scheduledMessages/create', payload);
      }

      this.cancelForm();
    },
    async deleteMessage(id) {
      await this.$store.dispatch('scheduledMessages/delete', {
        conversationId: this.conversationId,
        id,
      });
    },
  },
};
</script>
