<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDetectKeyboardLayout } from 'dashboard/composables/useDetectKeyboardLayout';
import { SHORTCUT_KEYS, KEYS } from '../../../../components/widgets/modal/constants';
import {
  LAYOUT_QWERTZ,
  keysToModifyInQWERTZ,
} from 'shared/helpers/KeyboardHelpers';
import Hotkey from 'dashboard/components/base/Hotkey.vue';

const { t } = useI18n();
const currentLayout = ref(null);

const title = computed(
  () => item => t(`KEYBOARD_SHORTCUTS.TITLE.${item.label}`)
);

const needsShiftKey = computed(
  () => keySet =>
    currentLayout.value === LAYOUT_QWERTZ &&
    keySet.some(key => keysToModifyInQWERTZ.has(key))
);

onMounted(async () => {
  currentLayout.value = await useDetectKeyboardLayout();
});
</script>

<template>
  <div class="flex flex-col gap-6 p-6">
    <h1 class="text-lg font-medium text-n-slate-12">
      {{ $t('SIDEBAR_ITEMS.KEYBOARD_SHORTCUTS') }}
    </h1>

    <div class="grid grid-cols-2 gap-x-5 gap-y-3">
      <!-- Toggle modal shortcut -->
      <div class="flex justify-between items-center min-w-[25rem]">
        <h5 class="text-sm text-n-slate-12">
          {{ $t('KEYBOARD_SHORTCUTS.TOGGLE_MODAL') }}
        </h5>
        <div class="flex items-center gap-2 mb-1 ml-2">
          <Hotkey custom-class="min-h-[28px] min-w-[60px] normal-case key">
            {{ KEYS.WIN }}
          </Hotkey>
          <Hotkey custom-class="min-h-[28px] min-w-[36px] key">
            {{ KEYS.SLASH }}
          </Hotkey>
        </div>
      </div>

      <!-- All other shortcuts -->
      <div
        v-for="shortcut in SHORTCUT_KEYS"
        :key="shortcut.id"
        class="flex justify-between items-center min-w-[25rem]"
      >
        <h5 class="text-sm text-n-slate-12 min-w-[36px]">
          {{ title(shortcut) }}
        </h5>
        <div class="flex items-center gap-2 mb-1 ml-2">
          <template v-if="needsShiftKey(shortcut.keySet)">
            <Hotkey custom-class="min-h-[28px] min-w-[36px] key">
              {{ KEYS.SHIFT }}
            </Hotkey>
          </template>
          <template v-for="(key, index) in shortcut.displayKeys" :key="index">
            <template v-if="key !== KEYS.SLASH">
              <Hotkey custom-class="min-h-[28px] min-w-[36px] key normal-case">
                {{ key }}
              </Hotkey>
            </template>
            <span
              v-else
              class="flex items-center text-sm font-semibold text-n-slate-12"
            >
              {{ key }}
            </span>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.key {
  @apply py-2 px-2.5 font-semibold text-xs text-n-slate-12 bg-n-slate-4 dark:bg-n-slate-2 shadow border-b-2 rtl:border-l-2 ltr:border-r-2 border-n-strong;
}
</style>
