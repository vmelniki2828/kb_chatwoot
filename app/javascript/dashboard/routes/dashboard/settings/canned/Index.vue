<script setup>
import { useAlert } from 'dashboard/composables';
import AddCanned from './AddCanned.vue';
import EditCanned from './EditCanned.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import { computed, onMounted, ref, defineOptions } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useStoreGetters,
  useStore,
  useMapGetter,
} from 'dashboard/composables/store';
import { picoSearch } from '@scmmishra/pico-search';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

defineOptions({
  name: 'CannedResponseSettings',
});

const getters = useStoreGetters();
const store = useStore();
const accountLabels = useMapGetter('labels/getLabels');
const { t } = useI18n();

const { getPlainText } = useMessageFormatter();

const fileInputRef = ref(null);
const showAddPopup = ref(false);
const loading = ref({});
const showEditPopup = ref(false);
const showDeleteConfirmationPopup = ref(false);
const activeResponse = ref({});
const cannedResponseAPI = ref({ message: '' });

const sortOrder = ref('asc');
const searchQuery = ref('');

const records = computed(() =>
  getters.getSortedCannedResponses.value(sortOrder.value)
);

const filteredRecords = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return records.value;
  return picoSearch(records.value, query, [
    { name: 'short_code', weight: 4 },
    'content',
  ]);
});
const uiFlags = computed(() => getters.getUIFlags.value);

const deleteConfirmText = computed(
  () =>
    `${t('CANNED_MGMT.DELETE.CONFIRM.YES')} ${activeResponse.value.short_code}`
);

const deleteRejectText = computed(
  () =>
    `${t('CANNED_MGMT.DELETE.CONFIRM.NO')} ${activeResponse.value.short_code}`
);

const deleteMessage = computed(() => {
  return ` ${activeResponse.value.short_code} ? `;
});

const toggleSort = () => {
  sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
};

const fetchCannedResponses = async () => {
  try {
    await store.dispatch('getCannedResponse');
  } catch (error) {
    // Ignore Error
  }
};

onMounted(() => {
  fetchCannedResponses();
  store.dispatch('labels/get');
});

const showAlertMessage = message => {
  loading[activeResponse.value.id] = false;
  activeResponse.value = {};
  cannedResponseAPI.value.message = message;
  useAlert(message);
};

const openImportPicker = () => {
  fileInputRef.value?.click();
};

const onImportFile = async event => {
  const input = event.target;
  const file = input.files?.[0];
  input.value = '';
  if (!file) return;

  try {
    const data = await store.dispatch('importCannedResponsesTable', file);
    const imported = data.imported ?? 0;
    const rowErrors = data.errors || [];
    let message = t('CANNED_MGMT.IMPORT.SUCCESS', { count: imported });
    if (rowErrors.length) {
      const details = rowErrors
        .map(e =>
          `${t('CANNED_MGMT.IMPORT.LINE_PREFIX', { line: e.line })} ${e.error}`
        )
        .join('; ');
      message = `${message} ${t('CANNED_MGMT.IMPORT.PARTIAL')} ${details}`;
    }
    useAlert(message);
  } catch (error) {
    useAlert(error?.message || t('CANNED_MGMT.IMPORT.ERROR'));
  }
};

const openAddPopup = () => {
  showAddPopup.value = true;
};
const hideAddPopup = () => {
  showAddPopup.value = false;
};

const openEditPopup = response => {
  showEditPopup.value = true;
  activeResponse.value = response;
};
const hideEditPopup = () => {
  showEditPopup.value = false;
};

const openDeletePopup = response => {
  showDeleteConfirmationPopup.value = true;
  activeResponse.value = response;
};

const closeDeletePopup = () => {
  showDeleteConfirmationPopup.value = false;
};

const deleteCannedResponse = async id => {
  try {
    await store.dispatch('deleteCannedResponse', id);
    showAlertMessage(t('CANNED_MGMT.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    const errorMessage =
      error?.message || t('CANNED_MGMT.DELETE.API.ERROR_MESSAGE');
    showAlertMessage(errorMessage);
  }
};

const confirmDeletion = () => {
  loading[activeResponse.value.id] = true;
  closeDeletePopup();
  deleteCannedResponse(activeResponse.value.id);
};

const tableHeaders = computed(() => {
  return [
    t('CANNED_MGMT.LIST.TABLE_HEADER.SHORT_CODE'),
    t('CANNED_MGMT.LIST.TABLE_HEADER.LABELS'),
    t('CANNED_MGMT.LIST.TABLE_HEADER.ACTIONS'),
  ];
});

const labelsForCanned = item => {
  const ids = item.label_ids || [];
  if (!ids.length) return [];
  const byId = Object.fromEntries(
    (accountLabels.value || []).map(l => [Number(l.id), l])
  );
  return ids.map(id => byId[Number(id)]).filter(Boolean);
};
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.fetchingList"
    :loading-message="$t('CANNED_MGMT.LOADING')"
    :no-records-found="!records.length"
    :no-records-message="$t('CANNED_MGMT.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('CANNED_MGMT.HEADER')"
        :description="$t('CANNED_MGMT.DESCRIPTION')"
        :link-text="$t('CANNED_MGMT.LEARN_MORE')"
        :search-placeholder="$t('CANNED_MGMT.SEARCH_PLACEHOLDER')"
        feature-name="canned_responses"
      >
        <template v-if="records?.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('CANNED_MGMT.COUNT', { n: records.length }) }}
          </span>
        </template>
        <template #actions>
          <input
            ref="fileInputRef"
            type="file"
            accept=".xlsx,.tsv,.csv,.txt,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/plain,text/csv,text/tab-separated-values"
            class="hidden"
            @change="onImportFile"
          />
          <Button
            v-tooltip.top="$t('CANNED_MGMT.IMPORT.HELP')"
            :label="$t('CANNED_MGMT.IMPORT.BUTTON')"
            faded
            slate
            size="sm"
            :is-loading="uiFlags.importingTable"
            :disabled="uiFlags.importingTable"
            @click="openImportPicker"
          />
          <Button
            :label="$t('CANNED_MGMT.HEADER_BTN_TXT')"
            size="sm"
            @click="openAddPopup"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredRecords"
        :no-data-message="
          !records.length
            ? $t('CANNED_MGMT.LIST.404')
            : searchQuery
              ? $t('CANNED_MGMT.NO_RESULTS')
              : ''
        "
      >
        <template #header-0>
          <button
            class="flex items-center gap-2 p-0 cursor-pointer"
            @click="toggleSort"
          >
            <span class="mb-0">
              {{ tableHeaders[0] }}
            </span>
            <Icon
              class="size-5 text-n-slate-11 flex-shrink-0"
              :icon="
                sortOrder === 'desc'
                  ? 'i-woot-sort-descending'
                  : 'i-woot-sort-ascending'
              "
            />
          </button>
        </template>
        <template #header-1>
          {{ tableHeaders[1] }}
        </template>
        <template #header-2>
          {{ tableHeaders[2] }}
        </template>

        <template #row="{ items }">
          <BaseTableRow
            v-for="cannedItem in items"
            :key="cannedItem.short_code"
            :item="cannedItem"
          >
            <template #default>
              <BaseTableCell class="max-w-0">
                <div class="flex flex-col gap-2 min-w-0">
                  <span class="text-heading-3 text-n-slate-12 truncate block">
                    {{ cannedItem.short_code }}
                  </span>
                  <p class="text-body-main text-n-slate-11 line-clamp-5">
                    {{ getPlainText(cannedItem.content) }}
                  </p>
                </div>
              </BaseTableCell>

              <BaseTableCell class="max-w-xs align-top">
                <div class="flex flex-wrap gap-1">
                  <span
                    v-for="lab in labelsForCanned(cannedItem)"
                    :key="lab.id"
                    class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-n-alpha-2 text-n-slate-12 border border-n-weak"
                  >
                    {{ lab.title }}
                  </span>
                  <span
                    v-if="!labelsForCanned(cannedItem).length"
                    class="text-body-main text-n-slate-11"
                  >
                    —
                  </span>
                </div>
              </BaseTableCell>

              <BaseTableCell align="end" class="w-24">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('CANNED_MGMT.EDIT.BUTTON_TEXT')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="openEditPopup(cannedItem)"
                  />
                  <Button
                    v-tooltip.top="$t('CANNED_MGMT.DELETE.BUTTON_TEXT')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="loading[cannedItem.id]"
                    @click="openDeletePopup(cannedItem)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
    <woot-modal v-model:show="showAddPopup" :on-close="hideAddPopup">
      <AddCanned :on-close="hideAddPopup" />
    </woot-modal>

    <woot-modal v-model:show="showEditPopup" :on-close="hideEditPopup">
      <EditCanned
        v-if="showEditPopup"
        :key="activeResponse.id"
        :id="activeResponse.id"
        :edshort-code="activeResponse.short_code"
        :edcontent="activeResponse.content"
        :ed-label-ids="activeResponse.label_ids || []"
        :on-close="hideEditPopup"
      />
    </woot-modal>

    <woot-delete-modal
      v-model:show="showDeleteConfirmationPopup"
      :on-close="closeDeletePopup"
      :on-confirm="confirmDeletion"
      :title="$t('CANNED_MGMT.DELETE.CONFIRM.TITLE')"
      :message="$t('CANNED_MGMT.DELETE.CONFIRM.MESSAGE')"
      :message-value="deleteMessage"
      :confirm-text="deleteConfirmText"
      :reject-text="deleteRejectText"
    />
  </SettingsLayout>
</template>
