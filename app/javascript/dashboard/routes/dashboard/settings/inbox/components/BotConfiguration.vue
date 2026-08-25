<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import LoadingState from 'dashboard/components/widgets/LoadingState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const EVENT_CATEGORIES = [
  'conversation_opened',
  'message_created',
  'conversation_status_changed',
  'webwidget_triggered',
];

export default {
  components: {
    LoadingState,
    SettingsFieldSection,
    NextButton,
    SelectInput,
    Checkbox,
  },
  props: {
    inbox: {
      type: Object,
      default: () => ({}),
    },
  },
  data() {
    return {
      selectedAgentBotId: null,
      initialConversationStatus: 'pending',
      selectedEventNames: [...EVENT_CATEGORIES],
    };
  },
  computed: {
    ...mapGetters({
      agentBots: 'agentBots/getBots',
      uiFlags: 'agentBots/getUIFlags',
    }),
    currentInboxId() {
      return this.inbox?.id || this.$route.params.inboxId;
    },
    activeAgentBot() {
      return this.$store.getters['agentBots/getActiveAgentBot'](
        this.currentInboxId
      );
    },
    agentBotInboxConfig() {
      return this.$store.getters['agentBots/getAgentBotInboxConfig'](
        this.currentInboxId
      );
    },
    statusOptions() {
      return [
        {
          value: 'pending',
          label: this.$t(
            'AGENT_BOTS.BOT_CONFIGURATION.INITIAL_STATUS.PENDING'
          ),
        },
        {
          value: 'open',
          label: this.$t('AGENT_BOTS.BOT_CONFIGURATION.INITIAL_STATUS.OPEN'),
        },
      ];
    },
    eventOptions() {
      return EVENT_CATEGORIES.map(value => ({
        value,
        label: this.$t(`AGENT_BOTS.BOT_CONFIGURATION.EVENTS.${value.toUpperCase()}`),
      }));
    },
  },
  watch: {
    activeAgentBot() {
      this.selectedAgentBotId = this.activeAgentBot.id;
    },
    agentBotInboxConfig: {
      immediate: true,
      handler(config) {
        this.initialConversationStatus =
          config.initialConversationStatus || 'pending';
        // Array.isArray (not `.length`): an explicitly saved empty array means
        // "all events disabled" and must be preserved, not treated as unset.
        this.selectedEventNames = Array.isArray(config.eventNames)
          ? config.eventNames
          : [...EVENT_CATEGORIES];
      },
    },
  },
  mounted() {
    this.fetchBotData();
  },

  methods: {
    fetchBotData() {
      this.$store.dispatch('agentBots/get');
      this.$store.dispatch('agentBots/fetchAgentBotInbox', this.currentInboxId);
    },
    isEventSelected(eventName) {
      return this.selectedEventNames.includes(eventName);
    },
    toggleEvent(eventName) {
      this.selectedEventNames = this.isEventSelected(eventName)
        ? this.selectedEventNames.filter(name => name !== eventName)
        : [...this.selectedEventNames, eventName];
    },
    async updateActiveAgentBot() {
      try {
        await this.$store.dispatch('agentBots/setAgentBotInbox', {
          inboxId: this.inbox.id,
          // Added this to make sure that empty values are not sent to the API
          botId: this.selectedAgentBotId ? this.selectedAgentBotId : undefined,
          initialConversationStatus: this.initialConversationStatus,
          eventNames: this.selectedEventNames,
        });
        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.SUCCESS_MESSAGE'));
      } catch (error) {
        useAlert(this.$t('AGENT_BOTS.BOT_CONFIGURATION.ERROR_MESSAGE'));
      }
    },
    async disconnectBot() {
      try {
        await this.$store.dispatch('agentBots/disconnectBot', {
          inboxId: this.inbox.id,
        });
        useAlert(
          this.$t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECTED_SUCCESS_MESSAGE')
        );
      } catch (error) {
        useAlert(
          error?.message ||
            this.$t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECTED_ERROR_MESSAGE')
        );
      }
    },
  },
};
</script>

<template>
  <div class="mx-6 max-w-4xl">
    <LoadingState v-if="uiFlags.isFetching || uiFlags.isFetchingAgentBot" />
    <form v-else @submit.prevent="updateActiveAgentBot">
      <SettingsFieldSection
        :label="$t('AGENT_BOTS.BOT_CONFIGURATION.TITLE')"
        :help-text="$t('AGENT_BOTS.BOT_CONFIGURATION.DESC')"
        class="[&>div]:!items-start"
      >
        <SelectInput
          v-model="selectedAgentBotId"
          :placeholder="$t('AGENT_BOTS.BOT_CONFIGURATION.SELECT_PLACEHOLDER')"
          :options="agentBots.map(bot => ({ value: bot.id, label: bot.name }))"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        v-if="selectedAgentBotId"
        :label="$t('AGENT_BOTS.BOT_CONFIGURATION.INITIAL_STATUS.TITLE')"
        :help-text="$t('AGENT_BOTS.BOT_CONFIGURATION.INITIAL_STATUS.DESC')"
        class="[&>div]:!items-start"
      >
        <SelectInput
          v-model="initialConversationStatus"
          :options="statusOptions"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        v-if="selectedAgentBotId"
        :label="$t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.TITLE')"
        :help-text="$t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.DESC')"
        class="[&>div]:!items-start"
      >
        <div class="flex flex-col gap-2">
          <label
            v-for="option in eventOptions"
            :key="option.value"
            class="flex items-center gap-2 cursor-pointer"
          >
            <Checkbox
              :model-value="isEventSelected(option.value)"
              @update:model-value="toggleEvent(option.value)"
            />
            <span class="text-n-slate-12 text-sm">{{ option.label }}</span>
          </label>
        </div>
      </SettingsFieldSection>

      <div class="grid grid-cols-1 lg:grid-cols-8 mt-3">
        <div class="col-span-1 lg:col-span-2 invisible" />
        <div class="col-span-1 lg:col-span-6 flex gap-2 mx-1">
          <NextButton
            type="submit"
            :label="$t('AGENT_BOTS.BOT_CONFIGURATION.SUBMIT')"
            :is-loading="uiFlags.isSettingAgentBot"
          />
          <NextButton
            type="button"
            :disabled="!selectedAgentBotId"
            :is-loading="uiFlags.isDisconnecting"
            faded
            ruby
            @click="disconnectBot"
          >
            {{ $t('AGENT_BOTS.BOT_CONFIGURATION.DISCONNECT') }}
          </NextButton>
        </div>
      </div>
    </form>
  </div>
</template>
