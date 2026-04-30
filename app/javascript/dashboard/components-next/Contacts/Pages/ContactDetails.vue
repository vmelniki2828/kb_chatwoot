<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import Button from 'dashboard/components-next/button/Button.vue';
import ConfirmContactDeleteDialog from 'dashboard/components-next/Contacts/ContactsForm/ConfirmContactDeleteDialog.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  selectedContact: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['goToContactsList']);
const { t } = useI18n();
const router = useRouter();
const route = useRoute();
const confirmDeleteContactDialogRef = ref(null);

const contactFields = computed(() => {
  const c = props.selectedContact;
  if (!c) return [];

  const attr = c.additionalAttributes || {};
  const city = attr.city;
  const country = attr.country;
  const location = [city, country].filter(Boolean).join(', ');
  const phone = c.phoneNumber;
  const email = c.email;
  const companyName = attr.companyName || c.company?.name;
  const description = attr.description;
  const status = c.availabilityStatus;

  return [
    { icon: 'i-ph-envelope',            label: t('CONTACT_PANEL.EMAIL_ADDRESS'), value: email },
    { icon: 'i-ph-phone',               label: t('CONTACT_PANEL.PHONE_NUMBER'),  value: phone },
    { icon: 'i-ph-map-pin',             label: t('CONTACT_PANEL.LOCATION'),      value: location },
    { icon: 'i-ph-building',            label: t('CONTACT_PANEL.COMPANY'),       value: companyName },
    { icon: 'i-ph-info',                label: t('CONTACT_PANEL.DESCRIPTION'),   value: description },
  ].filter(f => f.value);
});

const socialFields = computed(() => {
  const profiles = props.selectedContact?.additionalAttributes?.socialProfiles || {};
  const icons = {
    github:    'i-ph-github-logo',
    twitter:   'i-ph-twitter-logo',
    facebook:  'i-ph-facebook-logo',
    linkedin:  'i-ph-linkedin-logo',
    instagram: 'i-ph-instagram-logo',
    telegram:  'i-ph-telegram-logo',
    tiktok:    'i-ph-tiktok-logo',
  };
  return Object.entries(profiles)
    .filter(([, val]) => val)
    .map(([key, val]) => ({
      icon: icons[key] || 'i-ph-link',
      label: key.charAt(0).toUpperCase() + key.slice(1),
      value: val,
    }));
});

const goToEditContact = () => {
  router.push({ name: 'contacts_contact_edit', params: { accountId: route.params.accountId, contactId: route.params.contactId } });
};

const openConfirmDeleteContactDialog = () => {
  confirmDeleteContactDialogRef.value?.open();
};
</script>

<template>
  <div class="flex flex-col items-start gap-6 pb-6">
    <div class="w-full flex flex-col gap-1 rounded-xl border border-n-weak bg-n-solid-2 p-4">
      <div
        v-for="field in contactFields"
        :key="field.label"
        class="flex items-center gap-3 py-2 border-b border-n-weak last:border-0"
      >
        <span :class="[field.icon, 'size-4 text-n-slate-10 shrink-0']" />
        <span class="text-sm text-n-slate-11 w-28 shrink-0">{{ field.label }}</span>
        <span class="text-sm text-n-slate-12 truncate">{{ field.value }}</span>
      </div>
      <button
        class="mt-2 text-sm text-n-blue-9 hover:text-n-blue-10 transition-colors self-start"
        @click="goToEditContact"
      >
        {{ t('CONTACTS_LAYOUT.DETAILS.EDIT_CONTACT') }}
      </button>
    </div>

    <div v-if="socialFields.length > 0" class="w-full flex flex-col gap-1 rounded-xl border border-n-weak bg-n-solid-2 p-4">
      <h6 class="text-xs font-medium text-n-slate-10 uppercase tracking-wide mb-2">
        {{ t('CONTACT_PANEL.SOCIAL_PROFILES') }}
      </h6>
      <div
        v-for="field in socialFields"
        :key="field.label"
        class="flex items-center gap-3 py-2 border-b border-n-weak last:border-0"
      >
        <span :class="[field.icon, 'size-4 text-n-slate-10 shrink-0']" />
        <span class="text-sm text-n-slate-11 w-28 shrink-0">{{ field.label }}</span>
        <span class="text-sm text-n-slate-12 truncate">{{ field.value }}</span>
      </div>
    </div>

    <Policy :permissions="['administrator']">
      <div class="flex flex-col items-start w-full gap-4 pt-4 border-t border-n-strong">
        <div class="flex flex-col gap-1">
          <h6 class="text-sm font-medium text-n-slate-12">
            {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT') }}
          </h6>
          <span class="text-xs text-n-slate-11">
            {{ t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT_DESCRIPTION') }}
          </span>
        </div>
        <Button
          :label="t('CONTACTS_LAYOUT.DETAILS.DELETE_CONTACT')"
          color="ruby"
          size="sm"
          @click="openConfirmDeleteContactDialog"
        />
      </div>
      <ConfirmContactDeleteDialog
        ref="confirmDeleteContactDialogRef"
        :selected-contact="selectedContact"
        @go-to-contacts-list="emit('goToContactsList')"
      />
    </Policy>
  </div>
</template>
