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
  'custom_attribute_updated',
];

const ALL_CUSTOM_ATTRIBUTES = 'all';

// Derives the { mode, keys } local UI state from a saved key list (['all'] or specific keys).
const modeAndKeysFromSaved = savedKeys => {
  if (!Array.isArray(savedKeys) || savedKeys.includes(ALL_CUSTOM_ATTRIBUTES)) {
    return { mode: ALL_CUSTOM_ATTRIBUTES, keys: [] };
  }
  return { mode: 'specific', keys: savedKeys };
};

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
      conversationCustomAttributeMode: ALL_CUSTOM_ATTRIBUTES,
      conversationCustomAttributeKeys: [],
      contactCustomAttributeMode: ALL_CUSTOM_ATTRIBUTES,
      contactCustomAttributeKeys: [],
    };
  },
  computed: {
    ...mapGetters({
      agentBots: 'agentBots/getBots',
      uiFlags: 'agentBots/getUIFlags',
      conversationAttributes: 'attributes/getConversationAttributes',
      contactAttributes: 'attributes/getContactAttributes',
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

        const conversationState = modeAndKeysFromSaved(
          config.conversationCustomAttributeKeys
        );
        this.conversationCustomAttributeMode = conversationState.mode;
        this.conversationCustomAttributeKeys = conversationState.keys;

        const contactState = modeAndKeysFromSaved(
          config.contactCustomAttributeKeys
        );
        this.contactCustomAttributeMode = contactState.mode;
        this.contactCustomAttributeKeys = contactState.keys;
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
      this.$store.dispatch('attributes/get');
    },
    isEventSelected(eventName) {
      return this.selectedEventNames.includes(eventName);
    },
    toggleEvent(eventName) {
      this.selectedEventNames = this.isEventSelected(eventName)
        ? this.selectedEventNames.filter(name => name !== eventName)
        : [...this.selectedEventNames, eventName];
    },
    isCustomAttributeFieldSelected(model, key) {
      const keys =
        model === 'conversation'
          ? this.conversationCustomAttributeKeys
          : this.contactCustomAttributeKeys;
      return keys.includes(key);
    },
    toggleCustomAttributeField(model, key) {
      const property =
        model === 'conversation'
          ? 'conversationCustomAttributeKeys'
          : 'contactCustomAttributeKeys';
      this[property] = this.isCustomAttributeFieldSelected(model, key)
        ? this[property].filter(name => name !== key)
        : [...this[property], key];
    },
    async updateActiveAgentBot() {
      try {
        await this.$store.dispatch('agentBots/setAgentBotInbox', {
          inboxId: this.inbox.id,
          // Added this to make sure that empty values are not sent to the API
          botId: this.selectedAgentBotId ? this.selectedAgentBotId : undefined,
          initialConversationStatus: this.initialConversationStatus,
          eventNames: this.selectedEventNames,
          conversationCustomAttributeKeys:
            this.conversationCustomAttributeMode === ALL_CUSTOM_ATTRIBUTES
              ? [ALL_CUSTOM_ATTRIBUTES]
              : this.conversationCustomAttributeKeys,
          contactCustomAttributeKeys:
            this.contactCustomAttributeMode === ALL_CUSTOM_ATTRIBUTES
              ? [ALL_CUSTOM_ATTRIBUTES]
              : this.contactCustomAttributeKeys,
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

        <div
          v-if="isEventSelected('custom_attribute_updated')"
          class="flex flex-col gap-4 mt-4 ml-6 pl-4 border-l-2 border-n-weak"
        >
          <div class="flex flex-col gap-2">
            <span class="text-n-slate-12 text-sm font-medium">
              {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.CONVERSATION_FIELDS') }}
            </span>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="conversationCustomAttributeMode"
                type="radio"
                value="all"
                name="conversation-custom-attribute-mode"
              />
              <span class="text-n-slate-11 text-sm">
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.ALL_FIELDS') }}
              </span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="conversationCustomAttributeMode"
                type="radio"
                value="specific"
                name="conversation-custom-attribute-mode"
              />
              <span class="text-n-slate-11 text-sm">
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.SPECIFIC_FIELDS') }}
              </span>
            </label>
            <div
              v-if="conversationCustomAttributeMode === 'specific'"
              class="flex flex-col gap-2 ml-6"
            >
              <label
                v-for="attribute in conversationAttributes"
                :key="attribute.attributeKey"
                class="flex items-center gap-2 cursor-pointer"
              >
                <Checkbox
                  :model-value="
                    isCustomAttributeFieldSelected(
                      'conversation',
                      attribute.attributeKey
                    )
                  "
                  @update:model-value="
                    toggleCustomAttributeField(
                      'conversation',
                      attribute.attributeKey
                    )
                  "
                />
                <span class="text-n-slate-12 text-sm">{{
                  attribute.attributeDisplayName
                }}</span>
              </label>
              <p
                v-if="!conversationAttributes.length"
                class="text-n-slate-11 text-sm"
              >
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.NO_FIELDS') }}
              </p>
            </div>
          </div>

          <div class="flex flex-col gap-2">
            <span class="text-n-slate-12 text-sm font-medium">
              {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.CONTACT_FIELDS') }}
            </span>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="contactCustomAttributeMode"
                type="radio"
                value="all"
                name="contact-custom-attribute-mode"
              />
              <span class="text-n-slate-11 text-sm">
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.ALL_FIELDS') }}
              </span>
            </label>
            <label class="flex items-center gap-2 cursor-pointer">
              <input
                v-model="contactCustomAttributeMode"
                type="radio"
                value="specific"
                name="contact-custom-attribute-mode"
              />
              <span class="text-n-slate-11 text-sm">
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.SPECIFIC_FIELDS') }}
              </span>
            </label>
            <div
              v-if="contactCustomAttributeMode === 'specific'"
              class="flex flex-col gap-2 ml-6"
            >
              <label
                v-for="attribute in contactAttributes"
                :key="attribute.attributeKey"
                class="flex items-center gap-2 cursor-pointer"
              >
                <Checkbox
                  :model-value="
                    isCustomAttributeFieldSelected(
                      'contact',
                      attribute.attributeKey
                    )
                  "
                  @update:model-value="
                    toggleCustomAttributeField(
                      'contact',
                      attribute.attributeKey
                    )
                  "
                />
                <span class="text-n-slate-12 text-sm">{{
                  attribute.attributeDisplayName
                }}</span>
              </label>
              <p
                v-if="!contactAttributes.length"
                class="text-n-slate-11 text-sm"
              >
                {{ $t('AGENT_BOTS.BOT_CONFIGURATION.EVENTS.CUSTOM_ATTRIBUTES.NO_FIELDS') }}
              </p>
            </div>
          </div>
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
