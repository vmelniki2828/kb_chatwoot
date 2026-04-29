<script setup>
import { computed, reactive, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { splitName } from '@chatwoot/utils';
import countries from 'shared/constants/countries.js';
import Input from 'dashboard/components-next/input/Input.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import PhoneNumberInput from 'dashboard/components-next/phonenumberinput/PhoneNumberInput.vue';

const props = defineProps({
  contactData: {
    type: Object,
    default: null,
  },
  isDetailsView: {
    type: Boolean,
    default: false,
  },
  isNewContact: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();

const FORM_CONFIG = {
  FIRST_NAME: { field: 'firstName' },
  LAST_NAME: { field: 'lastName' },
  EMAIL_ADDRESS: { field: 'email' },
  PHONE_NUMBER: { field: 'phoneNumber' },
  CITY: { field: 'additionalAttributes.city' },
  COUNTRY: { field: 'additionalAttributes.countryCode' },
  BIO: { field: 'additionalAttributes.description' },
  COMPANY_NAME: { field: 'additionalAttributes.companyName' },
};

const SOCIAL_CONFIG = {
  LINKEDIN: 'i-ri-linkedin-box-fill',
  FACEBOOK: 'i-ri-facebook-circle-fill',
  INSTAGRAM: 'i-ri-instagram-line',
  TELEGRAM: 'i-ri-telegram-fill',
  TIKTOK: 'i-ri-tiktok-fill',
  TWITTER: 'i-ri-twitter-x-fill',
  GITHUB: 'i-ri-github-fill',
};

const defaultState = {
  id: 0,
  name: '',
  email: '',
  firstName: '',
  lastName: '',
  phoneNumber: '',
  additionalAttributes: {
    description: '',
    companyName: '',
    countryCode: '',
    country: '',
    city: '',
    socialProfiles: {
      facebook: '',
      github: '',
      instagram: '',
      telegram: '',
      tiktok: '',
      linkedin: '',
      twitter: '',
    },
  },
};

const state = reactive({ ...defaultState });

const validationRules = {
  firstName: { required },
  email: { email },
};

const v$ = useVuelidate(validationRules, state);

const isFormInvalid = computed(() => v$.value.$invalid);

const prepareStateBasedOnProps = () => {
  if (props.isNewContact) {
    return; // Added to prevent state update for new contact form
  }

  const {
    id,
    name = '',
    email: emailAddress,
    phoneNumber,
    additionalAttributes = {},
  } = props.contactData || {};
  const { firstName, lastName } = splitName(name || '');
  const {
    description = '',
    companyName = '',
    countryCode = '',
    country = '',
    city = '',
    socialTelegramUserName = '',
    socialProfiles = {},
  } = additionalAttributes || {};

  const telegramUsername =
    socialProfiles?.telegram || socialTelegramUserName || '';

  Object.assign(state, {
    id,
    name,
    firstName,
    lastName,
    email: emailAddress,
    phoneNumber,
    additionalAttributes: {
      description,
      companyName,
      countryCode,
      country,
      city,
      socialProfiles: {
        ...socialProfiles,
        telegram: telegramUsername,
      },
    },
  });
};

const countryOptions = computed(() =>
  countries.map(({ name, id }) => ({ label: name, value: id }))
);

const editDetailsForm = computed(() =>
  Object.keys(FORM_CONFIG).map(key => ({
    key,
    placeholder: t(
      `CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.FORM.${key}.PLACEHOLDER`
    ),
  }))
);

const socialProfilesForm = computed(() =>
  Object.entries(SOCIAL_CONFIG).map(([key, icon]) => ({
    key,
    placeholder: t(`CONTACTS_LAYOUT.CARD.SOCIAL_MEDIA.FORM.${key}.PLACEHOLDER`),
    icon,
  }))
);

const isValidationField = key => {
  const field = FORM_CONFIG[key]?.field;
  return ['firstName', 'email'].includes(field);
};

const getValidationKey = key => {
  return FORM_CONFIG[key]?.field;
};

// Creates a computed property for two-way form field binding
const getFormBinding = key => {
  const field = FORM_CONFIG[key]?.field;
  if (!field) return null;

  return computed({
    get: () => {
      // Handle firstName/lastName fields
      if (field === 'firstName' || field === 'lastName') {
        return state[field]?.toString() || '';
      }

      // Handle nested vs non-nested fields
      const [base, nested] = field.split('.');
      // Example: 'email' → state.email
      // Example: 'additionalAttributes.city' → state.additionalAttributes.city
      return (nested ? state[base][nested] : state[base])?.toString() || '';
    },

    set: async value => {
      // Handle name fields specially to maintain the combined 'name' field
      if (field === 'firstName' || field === 'lastName') {
        state[field] = value;
        // Example: firstName="John", lastName="Doe" → name="John Doe"
        state.name = `${state.firstName} ${state.lastName}`.trim();
      } else {
        // Handle nested vs non-nested fields
        const [base, nested] = field.split('.');
        if (nested) {
          // Example: additionalAttributes.city = "New York"
          state[base][nested] = value;
        } else {
          // Example: email = "test@example.com"
          state[base] = value;
        }
      }

      const isFormValid = await v$.value.$validate();
      if (isFormValid) {
        const { firstName, lastName, ...stateWithoutNames } = state;
        emit('update', stateWithoutNames);
      }
    },
  });
};

const getMessageType = key => {
  return isValidationField(key) && v$.value[getValidationKey(key)]?.$error
    ? 'error'
    : 'info';
};

const handleCountrySelection = value => {
  const selectedCountry = countries.find(option => option.id === value);
  state.additionalAttributes.country = selectedCountry?.name || '';
  emit('update', state);
};

const resetValidation = () => {
  v$.value.$reset();
};

const resetForm = () => {
  Object.assign(state, defaultState);
};

watch(
  () => props.contactData?.id,
  id => {
    if (id) prepareStateBasedOnProps();
  },
  { immediate: true }
);

// Expose state to parent component for avatar upload
defineExpose({
  state,
  resetValidation,
  isFormInvalid,
  resetForm,
});
</script>

<template>
  <div class="flex flex-col gap-0">
    <div class="px-8 pt-8 pb-6 border-b border-white/10">
      <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">Contact</p>
      <h2 class="text-3xl font-black tracking-wide text-white uppercase">Edit Details</h2>
    </div>

    <div class="flex flex-col gap-6 px-8 py-6">
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Personal Info</span>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <template v-for="item in editDetailsForm" :key="item.key">
            <template v-if="['FIRST_NAME','LAST_NAME','EMAIL_ADDRESS','PHONE_NUMBER','CITY','COUNTRY'].includes(item.key)">
              <div class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]">
                <span class="text-[10px] font-semibold tracking-[0.15em] uppercase" :class="item.key === 'FIRST_NAME' ? 'text-[#4ade80]' : 'text-n-slate-10'">
                  {{ item.key.replace(/_/g, ' ') }}
                </span>
                <ComboBox
                  v-if="item.key === 'COUNTRY'"
                  v-model="state.additionalAttributes.countryCode"
                  :options="countryOptions"
                  :placeholder="item.placeholder"
                  class="[&>div>button]:h-7 [&>div>button]:bg-transparent [&>div>button]:border-0 [&>div>button]:p-0 [&>div>button]:text-n-slate-9 [&>div>button]:text-sm"
                  @update:model-value="handleCountrySelection"
                />
                <PhoneNumberInput
                  v-else-if="item.key === 'PHONE_NUMBER'"
                  v-model="getFormBinding(item.key).value"
                  :placeholder="item.placeholder"
                  :show-border="false"
                  class="[&_input]:bg-transparent [&_input]:border-0 [&_input]:p-0 [&_input]:text-sm [&_input]:text-n-slate-9 [&_input]:placeholder:text-n-slate-8"
                />
                <Input
                  v-else
                  v-model="getFormBinding(item.key).value"
                  :placeholder="item.placeholder"
                  :message-type="getMessageType(item.key)"
                  custom-input-class="h-6 !pt-0 !pb-0 !px-0 bg-transparent !border-0 !outline-none !shadow-none text-sm text-n-slate-9 placeholder:text-n-slate-8"
                  class="w-full [&_.input-wrap]:border-0 [&_.input-wrap]:bg-transparent [&_.input-wrap]:shadow-none [&_.input-wrap]:p-0 [&_.input-wrap]:min-h-0"
                  @input="isValidationField(item.key) && v$[getValidationKey(item.key)].$touch()"
                  @blur="isValidationField(item.key) && v$[getValidationKey(item.key)].$touch()"
                />
              </div>
            </template>
          </template>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Work</span>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <template v-for="item in editDetailsForm" :key="item.key">
            <template v-if="['COMPANY_NAME','BIO'].includes(item.key)">
              <div class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-2.5 pb-3 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]">
                <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
                  {{ item.key === 'COMPANY_NAME' ? 'COMPANY' : 'BIO' }}
                </span>
                <Input
                  v-model="getFormBinding(item.key).value"
                  :placeholder="item.placeholder"
                  custom-input-class="h-6 !pt-0 !pb-0 !px-0 bg-transparent !border-0 !outline-none !shadow-none text-sm text-n-slate-9 placeholder:text-n-slate-8"
                  class="w-full [&_.input-wrap]:border-0 [&_.input-wrap]:bg-transparent [&_.input-wrap]:shadow-none [&_.input-wrap]:p-0 [&_.input-wrap]:min-h-0"
                />
              </div>
            </template>
          </template>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">03</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Social Links</span>
        </div>
        <div class="flex flex-wrap gap-2">
          <div
            v-for="item in socialProfilesForm"
            :key="item.key"
            class="flex items-center h-9 gap-2 px-3 rounded-xl border border-white/10 bg-white/5 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_10px_rgba(74,222,128,0.18)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_14px_rgba(74,222,128,0.25)]"
          >
            <Icon :icon="item.icon" class="flex-shrink-0 text-n-slate-10 size-4" />
            <input
              v-model="state.additionalAttributes.socialProfiles[item.key.toLowerCase()]"
              class="w-auto min-w-[80px] text-sm bg-transparent outline-none text-n-slate-12 placeholder:text-n-slate-9"
              :placeholder="item.placeholder"
              :size="item.placeholder.length"
              @input="emit('update', state)"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
