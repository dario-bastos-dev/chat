<template>
  <div class="px-1">
    <div
      v-if="uiFlags.isFetching"
      class="py-2 text-center text-sm text-n-slate-10"
    >
      {{ $t('CONVERSATION_SEQUENCES.LOADING') }}
    </div>
    <div
      v-else-if="!sequences.length"
      class="py-2 text-center text-sm text-n-slate-10"
    >
      {{ $t('CONVERSATION_SEQUENCES.EMPTY') }}
    </div>
    <div v-else class="flex flex-col gap-1">
      <div
        v-for="sequence in sequences"
        :key="sequence.id"
        class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-md hover:bg-n-alpha-1 transition-colors"
      >
        <div class="flex items-center gap-2 flex-1 min-w-0">
          <span
            class="flex-shrink-0 size-2 rounded-full"
            :class="sequence.active ? 'bg-n-green-9' : 'bg-n-slate-7'"
          />
          <span class="text-sm text-n-slate-12 truncate">{{
            sequence.name
          }}</span>
        </div>
        <button
          v-if="sequence.attached"
          class="flex-shrink-0 px-2 py-0.5 text-xs font-medium rounded border transition-colors"
          :class="
            sequence.conversation_active
              ? 'text-n-red-11 border-n-red-7 hover:bg-n-red-3'
              : 'text-n-green-11 border-n-green-7 hover:bg-n-green-3'
          "
          :disabled="uiFlags.isUpdating"
          @click="
            sequence.conversation_active
              ? detachSequence(sequence)
              : attachSequence(sequence)
          "
        >
          {{
            sequence.conversation_active
              ? $t('CONVERSATION_SEQUENCES.DEACTIVATE')
              : $t('CONVERSATION_SEQUENCES.ACTIVATE')
          }}
        </button>
        <button
          v-else
          class="flex-shrink-0 px-2 py-0.5 text-xs font-medium rounded border text-n-blue-11 border-n-blue-7 hover:bg-n-blue-3 transition-colors"
          :disabled="uiFlags.isUpdating"
          @click="attachSequence(sequence)"
        >
          {{ $t('CONVERSATION_SEQUENCES.ACTIVATE') }}
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

export default {
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  computed: {
    ...mapGetters({
      sequences: 'conversationSequences/getSequences',
      uiFlags: 'conversationSequences/getUIFlags',
    }),
  },
  watch: {
    conversationId: {
      handler(newVal) {
        if (newVal) {
          this.fetchSequences();
        }
      },
      immediate: true,
    },
  },
  methods: {
    async fetchSequences() {
      await this.$store.dispatch(
        'conversationSequences/get',
        this.conversationId
      );
    },
    async attachSequence(sequence) {
      try {
        await this.$store.dispatch('conversationSequences/attach', {
          conversationId: this.conversationId,
          messageSequenceId: sequence.id,
        });
        useAlert(this.$t('CONVERSATION_SEQUENCES.ACTIVATED_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('CONVERSATION_SEQUENCES.ERROR'));
      }
    },
    async detachSequence(sequence) {
      try {
        await this.$store.dispatch('conversationSequences/detach', {
          conversationId: this.conversationId,
          conversationSequenceId: sequence.conversation_sequence_id,
        });
        useAlert(this.$t('CONVERSATION_SEQUENCES.DEACTIVATED_SUCCESS'));
      } catch (error) {
        useAlert(this.$t('CONVERSATION_SEQUENCES.ERROR'));
      }
    },
  },
};
</script>
