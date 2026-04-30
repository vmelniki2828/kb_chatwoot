<script setup>
import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { formatNumber } from '@chatwoot/utils';
import wootConstants from 'dashboard/constants/globals';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';

import ConversationBasicFilter from './widgets/conversation/ConversationBasicFilter.vue';
import SwitchLayout from 'dashboard/routes/dashboard/conversation/search/SwitchLayout.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import {
  DropdownContainer,
  DropdownBody,
  DropdownItem,
} from 'next/dropdown-menu/base';

const props = defineProps({
  pageTitle: { type: String, required: true },
  hasAppliedFilters: { type: Boolean, required: true },
  hasActiveFolders: { type: Boolean, required: true },
  activeStatus: { type: String, required: true },
  isOnExpandedLayout: { type: Boolean, required: true },
  conversationStats: { type: Object, required: true },
  isListLoading: { type: Boolean, required: true },
  assigneeTabItems: { type: Array, default: () => [] },
  activeAssigneeTab: { type: String, default: 'me' },
});

const emit = defineEmits([
  'addFolders',
  'deleteFolders',
  'resetFilters',
  'basicFilterChange',
  'filtersModal',
  'chatTabChange',
]);

const TAB_ICONS = {
  me: 'i-lucide-user',
  unassigned: 'i-lucide-user-x',
  all: 'i-lucide-users',
};

const activeTabIcon = computed(() => TAB_ICONS[props.activeAssigneeTab] || 'i-lucide-users');
const tabIcon = key => TAB_ICONS[key] || 'i-lucide-users';

const { uiSettings, updateUISettings } = useUISettings();
const router = useRouter();
const { accountScopedRoute } = useAccount();

const onBasicFilterChange = (value, type) => {
  emit('basicFilterChange', value, type);
};

const hasAppliedFiltersOrActiveFolders = computed(() => {
  return props.hasAppliedFilters || props.hasActiveFolders;
});

const allCount = computed(() => props.conversationStats?.allCount || 0);
const formattedAllCount = computed(() => formatNumber(allCount.value));

const activeTabItem = computed(() => {
  return props.assigneeTabItems.find(i => i.key === props.activeAssigneeTab);
});

const toggleConversationLayout = () => {
  const { LAYOUT_TYPES } = wootConstants;
  const {
    conversation_display_type: conversationDisplayType = LAYOUT_TYPES.CONDENSED,
  } = uiSettings.value;
  const newViewType =
    conversationDisplayType === LAYOUT_TYPES.CONDENSED
      ? LAYOUT_TYPES.EXPANDED
      : LAYOUT_TYPES.CONDENSED;
  updateUISettings({
    conversation_display_type: newViewType,
    previously_used_conversation_display_type: newViewType,
  });
};
</script>

<template>
  <div class="flex flex-col">
    <div class="flex items-center justify-between px-3 h-[3.25rem]">
      <h1
        class="text-base font-medium truncate text-n-slate-12"
        :title="pageTitle"
      >
        {{ pageTitle }}
      </h1>
      <RouterLink
        :to="{ name: 'search' }"
        class="flex items-center justify-center size-9 rounded-full outline outline-1 outline-n-weak bg-n-surface-1 dark:bg-n-surface-1 transition-all duration-100 ease-out hover:bg-n-surface-active dark:hover:bg-n-surface-active"
        :title="$t('COMBOBOX.SEARCH_PLACEHOLDER')"
      >
        <span class="i-lucide-search size-4 text-n-slate-11" />
      </RouterLink>
    </div>

    <div
      class="flex items-center justify-between gap-2 px-3 h-[3.25rem] border-t border-n-weak"
    >
      <div class="flex items-center justify-center min-w-0 gap-2">
        <span
          class="px-2 py-1 my-0.5 rounded-md capitalize bg-n-slate-3 text-xxs text-n-slate-12 shrink-0"
        >
          <template v-if="hasAppliedFiltersOrActiveFolders && !isListLoading && allCount > 0">
            {{ formattedAllCount }}
          </template>
          <template v-else-if="!hasAppliedFiltersOrActiveFolders">
            {{ $t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${activeStatus}.TEXT`) }}
          </template>
        </span>
      </div>

      <div class="flex items-center gap-1">
        <template v-if="hasAppliedFilters && !hasActiveFolders">
          <div class="relative">
            <NextButton
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.ADD.SAVE_BUTTON')"
              icon="i-lucide-save"
              slate
              xs
              faded
              @click="emit('addFolders')"
            />
            <div
              id="saveFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            v-tooltip.top-end="$t('FILTER.CLEAR_BUTTON_LABEL')"
            icon="i-lucide-circle-x"
            ruby
            faded
            xs
            @click="emit('resetFilters')"
          />
        </template>
        <template v-if="hasActiveFolders">
          <div class="relative">
            <NextButton
              id="toggleConversationFilterButton"
              v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.EDIT.EDIT_BUTTON')"
              icon="i-lucide-send-horizontal"
              slate
              xs
              faded
              @click="emit('filtersModal')"
            />
            <div
              id="conversationFilterTeleportTarget"
              class="absolute z-50 mt-2"
              :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
            />
          </div>
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.top-end="$t('FILTER.CUSTOM_VIEWS.DELETE.DELETE_BUTTON')"
            icon="i-lucide-trash-2"
            ruby
            xs
            faded
            @click="emit('deleteFolders')"
          />
        </template>
        <div v-else class="relative">
          <NextButton
            id="toggleConversationFilterButton"
            v-tooltip.right="$t('FILTER.TOOLTIP_LABEL')"
            icon="i-lucide-funnel"
            slate
            xs
            faded
            @click="emit('filtersModal')"
          />
          <div
            id="conversationFilterTeleportTarget"
            class="absolute z-50 mt-2"
            :class="{ 'ltr:right-0 rtl:left-0': isOnExpandedLayout }"
          />
        </div>
        <DropdownContainer v-if="!hasAppliedFiltersOrActiveFolders && assigneeTabItems.length">
          <template #trigger="{ toggle, isOpen }">
            <NextButton
              v-tooltip.top-end="activeTabItem?.name"
              :icon="activeTabIcon"
              slate
              xs
              faded
              :class="{ '!bg-n-surface-active': isOpen }"
              @click="toggle"
            />
          </template>
          <DropdownBody class="min-w-36 z-20 ltr:right-0 rtl:left-0">
            <DropdownItem
              v-for="item in assigneeTabItems"
              :key="item.key"
              preserve-open
              @click="emit('chatTabChange', item.key)"
            >
              <div class="flex items-center justify-between w-full gap-3">
                <div class="flex items-center gap-2">
                  <span class="size-4" :class="tabIcon(item.key)" />
                  <span :class="item.key === activeAssigneeTab ? 'text-n-brand font-medium' : ''">
                    {{ item.name }}
                  </span>
                </div>
                <span
                  class="rounded-full px-1.5 py-0 min-w-[18px] text-center text-xs"
                  :class="item.key === activeAssigneeTab
                    ? 'bg-n-green-5 text-n-green-9'
                    : 'bg-n-alpha-1 text-n-slate-10'"
                >
                  {{ item.count }}
                </span>
              </div>
            </DropdownItem>
          </DropdownBody>
        </DropdownContainer>
        <ConversationBasicFilter
          v-if="!hasAppliedFiltersOrActiveFolders"
          :is-on-expanded-layout="isOnExpandedLayout"
          @change-filter="onBasicFilterChange"
        />
        <SwitchLayout
          :is-on-expanded-layout="isOnExpandedLayout"
          @toggle="toggleConversationLayout"
        />
      </div>
    </div>
  </div>
</template>
