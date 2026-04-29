<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import {
  AVAILABLE_CUSTOM_ROLE_PERMISSIONS,
  MANAGE_ALL_CONVERSATION_PERMISSIONS,
  CONVERSATION_UNASSIGNED_PERMISSIONS,
  CONVERSATION_PARTICIPATING_PERMISSIONS,
} from 'dashboard/constants/permissions.js';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  mode: {
    type: String,
    default: 'add',
    validator: value => ['add', 'edit'].includes(value),
  },
  selectedRole: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const name = ref('');
const description = ref('');
const selectedPermissions = ref([]);

const nameInput = ref(null);

const addCustomRole = reactive({
  showLoading: false,
  message: '',
});

const rules = computed(() => ({
  name: { required, minLength: minLength(2) },
  description: { required },
  selectedPermissions: { required, minLength: minLength(1) },
}));

const v$ = useVuelidate(rules, { name, description, selectedPermissions });

const resetForm = () => {
  name.value = '';
  description.value = '';
  selectedPermissions.value = [];
  v$.value.$reset();
};

const populateEditForm = () => {
  name.value = props.selectedRole.name || '';
  description.value = props.selectedRole.description || '';
  selectedPermissions.value = props.selectedRole.permissions || [];
};

watch(
  selectedPermissions,
  (newValue, oldValue) => {
    // Check if manage all conversation permission is added or removed
    const hasAddedManageAllConversation =
      newValue.includes(MANAGE_ALL_CONVERSATION_PERMISSIONS) &&
      !oldValue.includes(MANAGE_ALL_CONVERSATION_PERMISSIONS);
    const hasRemovedManageAllConversation =
      oldValue.includes(MANAGE_ALL_CONVERSATION_PERMISSIONS) &&
      !newValue.includes(MANAGE_ALL_CONVERSATION_PERMISSIONS);

    if (hasAddedManageAllConversation) {
      // If manage all conversation permission is added,
      // then add unassigned and participating permissions automatically
      selectedPermissions.value = [
        ...new Set([
          ...selectedPermissions.value,
          CONVERSATION_UNASSIGNED_PERMISSIONS,
          CONVERSATION_PARTICIPATING_PERMISSIONS,
        ]),
      ];
    } else if (hasRemovedManageAllConversation) {
      // If manage all conversation permission is removed,
      // then only remove manage all conversation permission
      selectedPermissions.value = selectedPermissions.value.filter(
        p => p !== MANAGE_ALL_CONVERSATION_PERMISSIONS
      );
    }
  },
  { deep: true }
);

onMounted(() => {
  if (props.mode === 'edit') {
    populateEditForm();
  }
  // Focus the name input when mounted
  nameInput.value?.focus();
});

const getTranslationKey = base => {
  return props.mode === 'edit'
    ? `CUSTOM_ROLE.EDIT.${base}`
    : `CUSTOM_ROLE.ADD.${base}`;
};

const modalTitle = computed(() => t(getTranslationKey('TITLE')));
const modalDescription = computed(() => t(getTranslationKey('DESC')));
const submitButtonText = computed(() => t(getTranslationKey('SUBMIT')));

const handleCustomRole = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  addCustomRole.showLoading = true;
  try {
    const roleData = {
      name: name.value,
      description: description.value,
      permissions: selectedPermissions.value,
    };

    if (props.mode === 'edit') {
      await store.dispatch('customRole/updateCustomRole', {
        id: props.selectedRole.id,
        ...roleData,
      });
      useAlert(t('CUSTOM_ROLE.EDIT.API.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('customRole/createCustomRole', roleData);
      useAlert(t('CUSTOM_ROLE.ADD.API.SUCCESS_MESSAGE'));
    }

    resetForm();
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.message || t(`CUSTOM_ROLE.FORM.API.ERROR_MESSAGE`);
    useAlert(errorMessage);
  } finally {
    addCustomRole.showLoading = false;
  }
};

const isSubmitDisabled = computed(
  () => v$.value.$invalid || addCustomRole.showLoading
);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">

    <div class="px-8 pt-8 pb-6 border-b border-white/10">
      <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">
        {{ $t('CUSTOM_ROLE.FORM.PERMISSIONS.LABEL') }}
      </p>
      <h2 class="text-3xl font-black tracking-wide text-white uppercase">
        {{ modalTitle }}
      </h2>
    </div>

    <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="handleCustomRole">

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Role Info</span>
        </div>

        <div class="grid grid-cols-1">
          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.name.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase">
              {{ $t('CUSTOM_ROLE.FORM.NAME.LABEL') }}
            </span>
            <input
              ref="nameInput"
              v-model.trim="name"
              type="text"
              :placeholder="$t('CUSTOM_ROLE.FORM.NAME.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
              @blur="v$.name.$touch"
            />
          </div>

          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-2 pb-2 col-span-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.description.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
              {{ $t('CUSTOM_ROLE.FORM.DESCRIPTION.LABEL') }}
            </span>
            <textarea
              v-model="description"
              :rows="3"
              :placeholder="$t('CUSTOM_ROLE.FORM.DESCRIPTION.PLACEHOLDER')"
              class="bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 resize-none"
              @blur="v$.description.$touch"
            />
          </div>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
          <span
            class="text-xs font-semibold tracking-[0.18em] uppercase"
            :class="v$.selectedPermissions.$error ? 'text-red-400' : 'text-n-slate-10'"
          >
            {{ $t('CUSTOM_ROLE.FORM.PERMISSIONS.LABEL') }}
          </span>
        </div>

        <div class="flex flex-col gap-2">
          <label
            v-for="permission in AVAILABLE_CUSTOM_ROLE_PERMISSIONS"
            :key="permission"
            :for="permission"
            class="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3 cursor-pointer transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)]"
            :class="{ 'border-[rgba(74,222,128,0.5)] bg-[rgba(74,222,128,0.05)]': selectedPermissions.includes(permission) }"
          >
            <input
              :id="permission"
              v-model="selectedPermissions"
              type="checkbox"
              :value="permission"
              name="permissions"
              class="w-4 h-4 accent-[#4ade80] cursor-pointer"
            />
            <span class="text-sm text-n-slate-9">
              {{ $t(`CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`) }}
            </span>
          </label>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex items-center justify-between gap-3 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('CUSTOM_ROLE.FORM.CANCEL_BUTTON_TEXT')"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="submitButtonText"
          color="blue"
          :disabled="isSubmitDisabled"
          :is-loading="addCustomRole.showLoading"
        />
      </div>
    </form>
  </div>
</template>
