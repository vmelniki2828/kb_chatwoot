<script setup>
import { onMounted, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useRoute, useRouter } from 'vue-router';

import ContactsDetailsLayout from 'dashboard/components-next/Contacts/ContactsDetailsLayout.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactDetails from 'dashboard/components-next/Contacts/Pages/ContactDetails.vue';
import ContactHistory from 'dashboard/components-next/Contacts/ContactsSidebar/ContactHistory.vue';
import ContactMerge from 'dashboard/components-next/Contacts/ContactsSidebar/ContactMerge.vue';
import ContactCustomAttributes from 'dashboard/components-next/Contacts/ContactsSidebar/ContactCustomAttributes.vue';
import ContactLabels from 'dashboard/components-next/Contacts/ContactsSidebar/ContactLabels.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const contact = useMapGetter('contacts/getContactById');
const uiFlags = useMapGetter('contacts/getUIFlags');

const activeTab = ref('attributes');
const contactMergeRef = ref(null);

const isFetchingItem = computed(() => uiFlags.value.isFetchingItem);
const isMergingContact = computed(() => uiFlags.value.isMerging);
const isUpdatingContact = computed(() => uiFlags.value.isUpdating);
const selectedContact = computed(() => contact.value(route.params.contactId));
const showSpinner = computed(() => isFetchingItem.value || isMergingContact.value);

const TABS = [
  { key: 'attributes', icon: 'i-ph-list-bullets',            labelKey: 'CONTACTS_LAYOUT.SIDEBAR.TABS.ATTRIBUTES' },
  { key: 'history',    icon: 'i-ph-clock-counter-clockwise',  labelKey: 'CONTACTS_LAYOUT.SIDEBAR.TABS.HISTORY' },
  { key: 'labels',     icon: 'i-ph-tag',                      labelKey: 'CONTACTS_LAYOUT.SIDEBAR.TABS.LABELS' },
  { key: 'merge',      icon: 'i-ph-git-merge',                labelKey: 'CONTACTS_LAYOUT.SIDEBAR.TABS.MERGE' },
];

const goToContactsList = () => {
  if (window.history.state?.back || window.history.length > 1) {
    router.back();
  } else {
    router.push(`/app/accounts/${route.params.accountId}/contacts?page=1`);
  }
};

const fetchActiveContact = async () => {
  if (route.params.contactId) {
    await store.dispatch('contacts/show', { id: route.params.contactId });
    await store.dispatch('contacts/fetchContactableInbox', route.params.contactId);
  }
};

const blockContactWithDuration = async ({ blockForDays }) => {
  try {
    await store.dispatch('contacts/update', { ...selectedContact.value, blocked: true, blockForDays });
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_ERROR_MESSAGE'));
  }
};

const unblockContact = async () => {
  try {
    await store.dispatch('contacts/update', { ...selectedContact.value, blocked: false });
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_SUCCESS_MESSAGE'));
  } catch {
    useAlert(t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_ERROR_MESSAGE'));
  }
};

onMounted(() => {
  fetchActiveContact();
  store.dispatch('contactConversations/get', route.params.contactId);
  store.dispatch('attributes/get');
  store.dispatch('labels/get');
});
</script>

<template>
  <div class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1">
    <ContactsDetailsLayout
      :selected-contact="selectedContact"
      is-detail-view
      :show-pagination-footer="false"
      :is-updating="isUpdatingContact"
      @go-to-contacts-list="goToContactsList"
      @block-contact="blockContactWithDuration"
      @unblock-contact="unblockContact"
    >
      <template #default>
        <div
          v-if="showSpinner"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <ContactDetails
          v-else-if="selectedContact"
          :selected-contact="selectedContact"
          @go-to-contacts-list="goToContactsList"
        />
      </template>

      <template #sidebar>
        <div class="flex flex-col h-full">
          <div class="flex shrink-0 border-b border-n-weak bg-n-solid-3">
            <button
              v-for="tab in TABS"
              :key="tab.key"
              class="flex-1 flex flex-col items-center gap-1 px-2 py-3 text-xs font-medium transition-colors border-b-2 -mb-px hover:text-n-slate-12 hover:bg-n-alpha-black1"
              :class="activeTab === tab.key
                ? 'border-n-brand text-n-brand'
                : 'border-transparent text-n-slate-10'"
              @click="activeTab = tab.key"
            >
              <span :class="[tab.icon, 'size-4 shrink-0']" />
              <span class="truncate w-full text-center leading-tight">
                {{ $t(tab.labelKey) }}
              </span>
            </button>
          </div>

          <div class="flex-1 overflow-y-auto">
            <div v-if="isFetchingItem" class="flex items-center justify-center py-10 text-n-slate-11">
              <Spinner />
            </div>
            <template v-else>
              <ContactCustomAttributes
                v-if="activeTab === 'attributes'"
                :selected-contact="selectedContact"
              />
              <ContactHistory v-else-if="activeTab === 'history'" />
              <ContactLabels
                v-else-if="activeTab === 'labels'"
                :contact-id="route.params.contactId"
              />
              <ContactMerge
                v-else-if="activeTab === 'merge'"
                ref="contactMergeRef"
                :selected-contact="selectedContact"
                @go-to-contacts-list="goToContactsList"
                @reset-tab="activeTab = 'attributes'"
              />
            </template>
          </div>
        </div>
      </template>
    </ContactsDetailsLayout>
  </div>
</template>
