<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { email, maxLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import Avatar from 'next/avatar/Avatar.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'next/textarea/TextArea.vue';
import SelectInput from 'dashboard/components-next/select/Select.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
});

const { t } = useI18n();

// Meta's documented limits for the business profile fields.
const LIMITS = { about: 139, description: 512, address: 256, email: 128 };
const MAX_WEBSITES = 2;

const profile = reactive({
  about: '',
  description: '',
  address: '',
  email: '',
  vertical: '',
  websites: ['', ''],
});

const verticals = ref([]);
const profilePictureUrl = ref('');
const profilePictureFile = ref(null);
// Meta offers no way to clear a profile picture, so discarding a pick
// restores the saved one.
const savedPictureUrl = ref('');
const isFetching = ref(false);
const isUpdating = ref(false);
const fetchError = ref('');

const rules = {
  about: { maxLength: maxLength(LIMITS.about) },
  description: { maxLength: maxLength(LIMITS.description) },
  address: { maxLength: maxLength(LIMITS.address) },
  email: { email, maxLength: maxLength(LIMITS.email) },
};

const v$ = useVuelidate(rules, profile);

const verticalOptions = computed(() =>
  verticals.value.map(value => ({
    value,
    label: t(`INBOX_MGMT.WHATSAPP_PROFILE.VERTICALS.${value}`),
  }))
);

const websiteErrors = computed(() =>
  profile.websites.map(website =>
    website && !/^https?:\/\/\S+$/.test(website)
      ? t('INBOX_MGMT.WHATSAPP_PROFILE.WEBSITES.ERROR')
      : ''
  )
);

const hasErrors = computed(
  () => v$.value.$invalid || websiteErrors.value.some(Boolean)
);

const applyProfile = payload => {
  profile.about = payload.about || '';
  profile.description = payload.description || '';
  profile.address = payload.address || '';
  profile.email = payload.email || '';
  profile.vertical = payload.vertical || '';
  profile.websites = Array.from(
    { length: MAX_WEBSITES },
    (_, index) => payload.websites?.[index] || ''
  );
  savedPictureUrl.value = payload.profile_picture_url || '';
  profilePictureUrl.value = savedPictureUrl.value;
  profilePictureFile.value = null;
};

const fetchProfile = async () => {
  isFetching.value = true;
  fetchError.value = '';
  try {
    const { data } = await InboxesAPI.getWhatsappProfile(props.inbox.id);
    verticals.value = data.verticals || [];
    applyProfile(data.payload || {});
  } catch (error) {
    fetchError.value =
      error?.response?.data?.error ||
      t('INBOX_MGMT.WHATSAPP_PROFILE.FETCH_ERROR');
  } finally {
    isFetching.value = false;
  }
};

// The shared avatar input accepts gif and webp, which Meta rejects, so the
// file is checked here instead of letting the user find out only on save.
const PICTURE_TYPES = ['image/jpeg', 'image/jpg', 'image/png'];
const PICTURE_MAX_SIZE = 5 * 1024 * 1024;

const handlePictureUpload = ({ file, url: previewUrl }) => {
  if (!PICTURE_TYPES.includes(file.type)) {
    useAlert(t('INBOX_MGMT.WHATSAPP_PROFILE.PICTURE.FORMAT_ERROR'));
    return;
  }
  if (file.size > PICTURE_MAX_SIZE) {
    useAlert(t('INBOX_MGMT.WHATSAPP_PROFILE.PICTURE.SIZE_ERROR'));
    return;
  }
  profilePictureFile.value = file;
  profilePictureUrl.value = previewUrl;
};

const handlePictureDelete = () => {
  profilePictureFile.value = null;
  profilePictureUrl.value = savedPictureUrl.value;
};

const updateProfile = async () => {
  v$.value.$touch();
  if (hasErrors.value) return;

  isUpdating.value = true;
  try {
    const { data } = await InboxesAPI.updateWhatsappProfile(props.inbox.id, {
      about: profile.about,
      description: profile.description,
      address: profile.address,
      email: profile.email,
      vertical: profile.vertical,
      websites: profile.websites.filter(Boolean),
      profilePicture: profilePictureFile.value,
    });
    // The save succeeded even when the server could not read the profile back,
    // so an empty payload must leave the form as typed instead of blanking it.
    if (Object.keys(data.payload || {}).length) applyProfile(data.payload);
    useAlert(t('INBOX_MGMT.WHATSAPP_PROFILE.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('INBOX_MGMT.WHATSAPP_PROFILE.UPDATE_ERROR')
    );
  } finally {
    isUpdating.value = false;
  }
};

onMounted(fetchProfile);
</script>

<template>
  <div class="flex flex-col gap-6">
    <div v-if="isFetching" class="flex justify-center py-10">
      <Spinner class="size-6 text-n-slate-11" />
    </div>

    <Banner
      v-else-if="fetchError"
      color="ruby"
      :action-label="$t('INBOX_MGMT.WHATSAPP_PROFILE.RETRY')"
      @action="fetchProfile"
    >
      {{ fetchError }}
    </Banner>

    <template v-else>
      <p class="text-sm text-n-slate-11">
        {{ $t('INBOX_MGMT.WHATSAPP_PROFILE.DESCRIPTION') }}
      </p>

      <div class="flex flex-col items-start gap-1">
        <label class="text-heading-3 text-n-slate-12">
          {{ $t('INBOX_MGMT.WHATSAPP_PROFILE.PICTURE.LABEL') }}
        </label>
        <Avatar
          :src="profilePictureUrl"
          :size="72"
          icon-name="i-ri-whatsapp-fill"
          name=""
          allow-upload
          rounded-full
          @upload="handlePictureUpload"
          @delete="handlePictureDelete"
        />
        <p class="text-label-small text-n-slate-11">
          {{ $t('INBOX_MGMT.WHATSAPP_PROFILE.PICTURE.HELP_TEXT') }}
        </p>
      </div>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WHATSAPP_PROFILE.ABOUT.LABEL')"
        :help-text="$t('INBOX_MGMT.WHATSAPP_PROFILE.ABOUT.HELP_TEXT')"
      >
        <TextArea
          v-model="profile.about"
          :max-length="LIMITS.about"
          :placeholder="$t('INBOX_MGMT.WHATSAPP_PROFILE.ABOUT.PLACEHOLDER')"
          show-character-count
          auto-height
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WHATSAPP_PROFILE.BUSINESS_DESCRIPTION.LABEL')"
        :help-text="
          $t('INBOX_MGMT.WHATSAPP_PROFILE.BUSINESS_DESCRIPTION.HELP_TEXT')
        "
      >
        <TextArea
          v-model="profile.description"
          :max-length="LIMITS.description"
          :placeholder="
            $t('INBOX_MGMT.WHATSAPP_PROFILE.BUSINESS_DESCRIPTION.PLACEHOLDER')
          "
          show-character-count
          auto-height
          resize
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WHATSAPP_PROFILE.VERTICAL.LABEL')"
        :help-text="$t('INBOX_MGMT.WHATSAPP_PROFILE.VERTICAL.HELP_TEXT')"
      >
        <SelectInput
          v-model="profile.vertical"
          :options="verticalOptions"
          :placeholder="$t('INBOX_MGMT.WHATSAPP_PROFILE.VERTICAL.PLACEHOLDER')"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WHATSAPP_PROFILE.ADDRESS.LABEL')"
      >
        <Input
          v-model="profile.address"
          :maxlength="LIMITS.address"
          :placeholder="$t('INBOX_MGMT.WHATSAPP_PROFILE.ADDRESS.PLACEHOLDER')"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WHATSAPP_PROFILE.EMAIL.LABEL')"
      >
        <Input
          v-model="profile.email"
          type="email"
          :maxlength="LIMITS.email"
          :placeholder="$t('INBOX_MGMT.WHATSAPP_PROFILE.EMAIL.PLACEHOLDER')"
          :message="
            v$.email.$error ? $t('INBOX_MGMT.WHATSAPP_PROFILE.EMAIL.ERROR') : ''
          "
          :message-type="v$.email.$error ? 'error' : 'info'"
          @blur="v$.email.$touch()"
        />
      </SettingsFieldSection>

      <SettingsFieldSection
        :label="$t('INBOX_MGMT.WHATSAPP_PROFILE.WEBSITES.LABEL')"
        :help-text="$t('INBOX_MGMT.WHATSAPP_PROFILE.WEBSITES.HELP_TEXT')"
      >
        <div class="flex flex-col gap-3">
          <Input
            v-for="(_website, index) in profile.websites"
            :key="index"
            v-model="profile.websites[index]"
            :placeholder="
              $t('INBOX_MGMT.WHATSAPP_PROFILE.WEBSITES.PLACEHOLDER')
            "
            :message="websiteErrors[index]"
            :message-type="websiteErrors[index] ? 'error' : 'info'"
          />
        </div>
      </SettingsFieldSection>

      <div>
        <NextButton
          :is-loading="isUpdating"
          :disabled="hasErrors"
          :label="$t('INBOX_MGMT.SETTINGS_POPUP.UPDATE')"
          @click="updateProfile"
        />
      </div>
    </template>
  </div>
</template>
