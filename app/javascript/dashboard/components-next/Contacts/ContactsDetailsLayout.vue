<script setup>
import { computed, ref, useSlots } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { vOnClickOutside } from '@vueuse/components';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

import Button from 'dashboard/components-next/button/Button.vue';
import Breadcrumb from 'dashboard/components-next/breadcrumb/Breadcrumb.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import VoiceCallButton from 'dashboard/components-next/Contacts/VoiceCallButton.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  selectedContact: { type: Object, default: () => ({}) },
  isUpdating: { type: Boolean, default: false },
  isDetailView: { type: Boolean, default: false },
  showPaginationFooter: { type: Boolean, default: true },
});

const emit = defineEmits(['goToContactsList', 'blockContact', 'unblockContact']);

const { t } = useI18n();
const slots = useSlots();
const route = useRoute();
const router = useRouter();
const showBlockMenu = ref(false);

const contactId = computed(() => route.params.contactId);

const uiFlags = useMapGetter('contacts/getUIFlags');
const isUpdating = computed(() => uiFlags.value.isUpdating);

const createdAt = computed(() =>
  props.selectedContact?.createdAt
    ? dynamicTime(props.selectedContact.createdAt)
    : ''
);

const lastActivityAt = computed(() =>
  props.selectedContact?.lastActivityAt
    ? dynamicTime(props.selectedContact.lastActivityAt)
    : ''
);

const breadcrumbItems = computed(() => {
  const items = [{ label: t('CONTACTS_LAYOUT.HEADER.BREADCRUMB.CONTACTS') }];
  if (props.selectedContact?.name) items.push({ label: props.selectedContact.name });
  return items;
});

const goToContactsList = () => {
  router.push({ name: 'contacts_dashboard_index', params: { accountId: route.params.accountId } });
};

const onBreadcrumbClick = (item, index) => {
  if (index === 0) goToContactsList();
};

const isContactBlocked = computed(() => {
  const c = props.selectedContact;
  if (!c) return false;
  return c.messaging_block_active ?? c.messagingBlockActive ?? c.blocked ?? false;
});

const blockDurationMenuItems = computed(() => [
  { action: 'block', value: 1,  label: t('CONTACTS_LAYOUT.HEADER.BLOCK_1_DAY') },
  { action: 'block', value: 3,  label: t('CONTACTS_LAYOUT.HEADER.BLOCK_3_DAYS') },
  { action: 'block', value: 7,  label: t('CONTACTS_LAYOUT.HEADER.BLOCK_7_DAYS') },
  { action: 'block', value: 30, label: t('CONTACTS_LAYOUT.HEADER.BLOCK_30_DAYS') },
  { action: 'block', value: 0,  label: t('CONTACTS_LAYOUT.HEADER.BLOCK_PERMANENT') },
]);

const onBlockDuration = ({ value }) => {
  showBlockMenu.value = false;
  emit('blockContact', { blockForDays: value });
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">

    <div class="shrink-0 bg-n-solid-3 border-b border-n-weak px-5 py-3 flex flex-col gap-2">
      <Breadcrumb :items="breadcrumbItems" @click="onBreadcrumbClick" />

      <div class="flex items-center justify-between gap-4 flex-wrap">
        <div class="flex items-center gap-3 min-w-0">
          <slot name="avatar">
            <Avatar
              :src="selectedContact?.thumbnail || ''"
              :name="selectedContact?.name || ''"
              :size="64"
            />
          </slot>
          <div class="min-w-0">
            <h2 class="text-sm font-semibold text-n-slate-12 truncate leading-snug">
              {{ selectedContact?.name }}
            </h2>
            <div class="flex flex-col gap-0.5 mt-0.5">
              <span class="text-sm text-n-slate-11">
                {{ $t('CONTACTS_LAYOUT.DETAILS.CREATED_AT', { date: createdAt }) }}
                •
                {{ $t('CONTACTS_LAYOUT.DETAILS.LAST_ACTIVITY', { date: lastActivityAt }) }}
              </span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2 shrink-0">
          <Button
            v-if="isContactBlocked"
            :label="$t('CONTACTS_LAYOUT.HEADER.UNBLOCK_CONTACT')"
            size="sm"
            slate
            :is-loading="isUpdating"
            :disabled="isUpdating"
            @click="emit('unblockContact')"
          />
          <div v-else v-on-click-outside="() => (showBlockMenu = false)" class="relative">
            <Button
              :label="$t('CONTACTS_LAYOUT.HEADER.BLOCK_CONTACT_MENU')"
              size="sm"
              slate
              trailing-icon
              icon="i-lucide-chevron-down"
              :is-loading="isUpdating"
              :disabled="isUpdating"
              @click="showBlockMenu = !showBlockMenu"
            />
            <DropdownMenu
              v-if="showBlockMenu"
              :menu-items="blockDurationMenuItems"
              class="z-[100] w-48 mt-1 ltr:right-0 rtl:left-0 top-full"
              @action="onBlockDuration"
            />
          </div>
          <VoiceCallButton
            :phone="selectedContact?.phoneNumber"
            :contact-id="contactId"
            :label="$t('CONTACT_PANEL.CALL')"
            size="sm"
          />
          <ComposeConversation :contact-id="contactId">
            <template #trigger="{ toggle }">
              <Button
                :label="$t('CONTACTS_LAYOUT.HEADER.SEND_MESSAGE')"
                size="sm"
                @click="toggle"
              />
            </template>
          </ComposeConversation>
        </div>
      </div>
    </div>

    <div class="hidden md:flex flex-1 overflow-hidden">
      <div class="flex flex-col flex-1 shrink-0 overflow-y-auto border-r border-n-weak bg-n-solid-1 items-center">
        <div class="w-full max-w-xl px-6 py-4">
          <slot name="default" />
        </div>
      </div>

      <div v-if="slots.center" class="hidden lg:flex flex-1 overflow-y-auto">
        <slot name="center" />
      </div>

      <div
        v-if="slots.sidebar"
        class="flex flex-col flex-1 overflow-hidden border-l border-n-weak bg-n-solid-2"
      >
        <slot name="sidebar" />
      </div>
    </div>

    <div class="md:hidden flex flex-col flex-1 overflow-y-auto">
      <div v-if="slots.sidebar" class="border-b border-n-weak">
        <slot name="sidebar" />
      </div>
      <div>
        <slot name="default" />
      </div>
      <div v-if="slots.center" class="border-t border-n-weak">
        <slot name="center" />
      </div>
    </div>

  </section>
</template>
