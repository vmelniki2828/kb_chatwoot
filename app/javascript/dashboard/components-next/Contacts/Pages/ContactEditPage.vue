<script setup>
import { computed, ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useRoute, useRouter } from 'vue-router';

import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ContactsForm from 'dashboard/components-next/Contacts/ContactsForm/ContactsForm.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const contact = useMapGetter('contacts/getContactById');
const uiFlags = useMapGetter('contacts/getUIFlags');

const contactsFormRef = ref(null);
const avatarFile = ref(null);
const avatarUrl = ref('');
const contactData = ref({});

const selectedContact = computed(() => contact.value(route.params.contactId));
const isUpdating = computed(() => uiFlags.value.isUpdating);
const isFetchingItem = computed(() => uiFlags.value.isFetchingItem);
const isFormInvalid = computed(() => contactsFormRef.value?.isFormInvalid);

const avatarSrc = computed(() =>
  avatarUrl.value ? avatarUrl.value : contactData.value?.thumbnail
);

const goToContactsList = () => {
  router.push({ name: 'contacts_dashboard_index', params: { accountId: route.params.accountId } });
};

const goToContactView = () => {
  router.push({ name: 'contacts_show', params: { accountId: route.params.accountId, contactId: route.params.contactId } });
};

const breadcrumbItems = computed(() => [
  { label: t('CONTACTS_LAYOUT.HEADER.BREADCRUMB.CONTACTS') },
  { label: selectedContact.value?.name || '...' },
  { label: t('CONTACTS_LAYOUT.DETAILS.EDIT_CONTACT') },
]);

const onBreadcrumbClick = (item, index) => {
  if (index === 0) goToContactsList();
  if (index === 1) goToContactView();
};

onMounted(async () => {
  if (route.params.contactId) {
    await store.dispatch('contacts/show', { id: route.params.contactId });
  }
  if (selectedContact.value) {
    Object.assign(contactData.value, { ...selectedContact.value });
  }
});

const handleFormUpdate = updatedData => {
  Object.assign(contactData.value, updatedData);
};

const updateContact = async () => {
  try {
    const { customAttributes, ...basicContactData } = contactData.value;
    await store.dispatch('contacts/update', basicContactData);
    await store.dispatch('contacts/fetchContactableInbox', selectedContact.value.id);
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.SUCCESS_MESSAGE'));
    goToContactView();
  } catch {
    useAlert(t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.ERROR_MESSAGE'));
  }
};

const handleAvatarUpload = async ({ file, url }) => {
  avatarFile.value = file;
  avatarUrl.value = url;
  try {
    await store.dispatch('contacts/update', {
      ...contactsFormRef.value?.state,
      avatar: file,
      isFormData: true,
    });
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.UPLOAD.ERROR_MESSAGE'));
  }
};

const handleAvatarDelete = async () => {
  try {
    if (selectedContact.value?.id) {
      await store.dispatch('contacts/deleteAvatar', selectedContact.value.id);
      useAlert(t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.SUCCESS_MESSAGE'));
    }
    avatarFile.value = null;
    avatarUrl.value = '';
    contactData.value.thumbnail = null;
  } catch (error) {
    useAlert(error.message || t('CONTACTS_LAYOUT.DETAILS.AVATAR.DELETE.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col flex-1 h-full overflow-auto bg-n-surface-1">
    <header class="sticky top-0 z-10 px-6 py-4 border-b border-n-weak bg-n-surface-1">
      <div class="flex items-center justify-between w-full max-w-2xl mx-auto">
        <Breadcrumb :items="breadcrumbItems" @click="onBreadcrumbClick" />
            <div class="flex items-center gap-2">
          <Button
            :label="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')"
            size="sm"
            :is-loading="isUpdating"
            :disabled="isUpdating || isFormInvalid"
            @click="updateContact"
          />
        </div>
      </div>
    </header>

    <main class="flex-1 overflow-y-auto">
      <div class="w-full max-w-2xl mx-auto px-6 py-8">
        <div
          v-if="isFetchingItem"
          class="flex items-center justify-center py-20 text-n-slate-11"
        >
          <Spinner />
        </div>

        <template v-else-if="selectedContact">
          <div class="flex flex-col items-start gap-4 pb-8 mb-8 border-b border-n-weak">
            <Avatar
              :src="avatarSrc || ''"
              :name="selectedContact?.name || ''"
              :size="80"
              allow-upload
              @upload="handleAvatarUpload"
              @delete="handleAvatarDelete"
            />
            <div class="flex flex-col gap-0.5">
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ selectedContact?.name }}
              </h2>
              <span class="text-sm text-n-slate-11">
                {{ t('CONTACTS_LAYOUT.DETAILS.EDIT_CONTACT') }}
              </span>
            </div>
          </div>

          <ContactsForm
            ref="contactsFormRef"
            :contact-data="contactData"
            is-details-view
            @update="handleFormUpdate"
          />

          <div class="flex items-center gap-3 mt-8 pt-6 border-t border-n-weak">
            <Button
              :label="t('CONTACTS_LAYOUT.CARD.EDIT_DETAILS_FORM.UPDATE_BUTTON')"
              size="sm"
              :is-loading="isUpdating"
              :disabled="isUpdating || isFormInvalid"
              @click="updateContact"
            />
          </div>
        </template>
      </div>
    </main>
  </div>
</template>
