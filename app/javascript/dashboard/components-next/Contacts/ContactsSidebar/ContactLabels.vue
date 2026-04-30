<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({
  contactId: {
    type: [String, Number],
    default: null,
  },
});

const store = useStore();
const route = useRoute();
const { t } = useI18n();

const allLabels = useMapGetter('labels/getLabels');
const contactLabels = useMapGetter('contactLabels/getContactLabels');

const savedLabels = computed(() => {
  const availableContactLabels = contactLabels.value(props.contactId);
  return allLabels.value.filter(({ title }) =>
    availableContactLabels.includes(title)
  );
});

const labelList = computed(() =>
  allLabels.value.map(label => ({
    value: label.id,
    label: label.title,
    thumbnail: { name: label.title, color: label.color },
  }))
);

const fetchLabels = async contactId => {
  if (!contactId) return;
  store.dispatch('contactLabels/get', contactId);
};

const handleLabelAction = async value => {
  if (!value) return;
  try {
    const currentLabels = savedLabels.value.map(label => label.title);
    const selectedLabel = allLabels.value.find(label => label.id === value);
    if (!selectedLabel) return;

    const updatedLabels = currentLabels.includes(selectedLabel.title)
      ? currentLabels.filter(title => title !== selectedLabel.title)
      : [...currentLabels, selectedLabel.title];

    await store.dispatch('contactLabels/update', {
      contactId: props.contactId,
      labels: updatedLabels,
    });
  } catch (error) {
    // error
  }
};

const handleRemoveLabel = async label => {
  try {
    const updatedLabels = savedLabels.value
      .filter(l => l.id !== label.id)
      .map(l => l.title);
    await store.dispatch('contactLabels/update', {
      contactId: props.contactId,
      labels: updatedLabels,
    });
  } catch (error) {
    // error
  }
};

watch(
  () => props.contactId,
  (newVal, oldVal) => {
    if (newVal !== oldVal) fetchLabels(newVal);
  }
);

onMounted(() => {
  if (route.params.contactId) fetchLabels(route.params.contactId);
});
</script>

<template>
  <div class="flex flex-col gap-6 px-6 py-6">
    <div class="flex flex-col gap-2">
      <h4 class="text-base text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.SIDEBAR.LABELS.TITLE') }}
      </h4>
      <p class="text-sm text-n-slate-11">
        {{ t('CONTACTS_LAYOUT.SIDEBAR.LABELS.DESCRIPTION') }}
      </p>
    </div>

    <div v-if="savedLabels.length > 0" class="flex flex-wrap gap-2">
      <span
        v-for="label in savedLabels"
        :key="label.id"
        class="flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium text-white"
        :style="{ backgroundColor: label.color }"
      >
        <span class="size-1.5 rounded-full bg-white/40 shrink-0" />
        {{ label.title }}
        <button
          class="ml-1 opacity-70 hover:opacity-100 transition-opacity"
          @click="handleRemoveLabel(label)"
        >
          <span class="i-ph-x size-3" />
        </button>
      </span>
    </div>

    <div class="flex flex-col gap-2">
      <label class="text-sm text-n-slate-12">
        {{ t('CONTACTS_LAYOUT.SIDEBAR.LABELS.SELECT_LABEL') }}
      </label>
      <ComboBox
        id="labels"
        :model-value="null"
        :options="labelList"
        :empty-state="t('CONTACTS_LAYOUT.SIDEBAR.LABELS.EMPTY_STATE')"
        :search-placeholder="t('CONTACTS_LAYOUT.SIDEBAR.LABELS.SEARCH_PLACEHOLDER')"
        :placeholder="t('CONTACTS_LAYOUT.SIDEBAR.LABELS.PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2"
        @update:model-value="handleLabelAction"
      />
    </div>
  </div>
</template>
