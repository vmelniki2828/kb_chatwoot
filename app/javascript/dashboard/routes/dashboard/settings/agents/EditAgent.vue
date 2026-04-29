<script setup>
import { ref, computed } from 'vue';
import { useRoute } from 'vue-router';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import Auth from '../../../../api/auth';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  name: {
    type: String,
    required: true,
  },
  email: {
    type: String,
    default: '',
  },
  type: {
    type: String,
    default: '',
  },
  availability: {
    type: String,
    default: '',
  },
  provider: {
    type: String,
    default: '',
  },
  customRoleId: {
    type: Number,
    default: null,
  },
  maxOpenConversations: {
    type: Number,
    default: null,
  },
});

const emit = defineEmits(['close']);

const { AVAILABILITY_STATUS_KEYS } = wootConstants;

const store = useStore();
const route = useRoute();
const { t } = useI18n();

const agentName = ref(props.name);
const agentAvailability = ref(props.availability);
const selectedRoleId = ref(props.customRoleId || props.type);
const agentCredentials = ref({ email: props.email });
const maxOpenConversationsInput = ref(
  props.maxOpenConversations != null ? String(props.maxOpenConversations) : ''
);

const showMaxOpenConversations = computed(() => {
  const accountId = Number(route.params.accountId);
  return store.getters['accounts/isFeatureEnabledonAccount'](
    accountId,
    'advanced_assignment'
  );
});

const rules = {
  agentName: { required, minLength: minLength(1) },
  selectedRoleId: { required },
  agentAvailability: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  selectedRoleId,
  agentAvailability,
});

const pageTitle = computed(
  () => `${t('AGENT_MGMT.EDIT.TITLE')} - ${props.name}`
);

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const statusList = computed(() => {
  return [
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
    t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
  ];
});

const availabilityStatuses = computed(() =>
  statusList.value.map((statusLabel, index) => ({
    label: statusLabel,
    value: AVAILABILITY_STATUS_KEYS[index],
    disabled: props.availability === AVAILABILITY_STATUS_KEYS[index],
  }))
);

const editAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      id: props.id,
      name: agentName.value,
      availability: agentAvailability.value,
    };

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
      payload.custom_role_id = null;
    }

    if (showMaxOpenConversations.value) {
      const raw = maxOpenConversationsInput.value;
      if (raw === '' || raw === null || raw === undefined) {
        payload.max_open_conversations = null;
      } else {
        const n = parseInt(raw, 10);
        payload.max_open_conversations = Number.isNaN(n) ? null : n;
      }
    }

    await store.dispatch('agents/update', payload);
    useAlert(t('AGENT_MGMT.EDIT.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.API.ERROR_MESSAGE'));
  }
};

const resetPassword = async () => {
  try {
    await Auth.resetPassword(agentCredentials.value);
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('AGENT_MGMT.EDIT.PASSWORD_RESET.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col gap-0">
    <div class="px-8 pt-8 pb-6 border-b border-white/10">
      <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">Agents</p>
      <h2 class="text-3xl font-black tracking-wide text-white uppercase">{{ $t('AGENT_MGMT.EDIT.TITLE') }}</h2>
    </div>

    <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="editAgent">
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Agent Info</span>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.agentName.$error }">
            <span class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase">{{ $t('AGENT_MGMT.EDIT.FORM.NAME.LABEL') }}</span>
            <input
              v-model="agentName"
              type="text"
              :placeholder="$t('AGENT_MGMT.EDIT.FORM.NAME.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
              @input="v$.agentName.$touch"
            />
          </div>

          <div class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.selectedRoleId.$error }">
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('AGENT_MGMT.EDIT.FORM.AGENT_TYPE.LABEL') }}</span>
            <select
              v-model="selectedRoleId"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 p-0 appearance-none cursor-pointer"
              @change="v$.selectedRoleId.$touch"
            >
              <option v-for="role in roles" :key="role.id" :value="role.id" class="bg-n-solid-3">
                {{ role.label }}
              </option>
            </select>
          </div>

          <div class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.agentAvailability.$error }">
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('PROFILE_SETTINGS.FORM.AVAILABILITY.LABEL') }}</span>
            <select
              v-model="agentAvailability"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 p-0 appearance-none cursor-pointer"
              @change="v$.agentAvailability.$touch"
            >
              <option v-for="status in availabilityStatuses" :key="status.value" :value="status.value" class="bg-n-solid-3">
                {{ status.label }}
              </option>
            </select>
          </div>

          <div v-if="showMaxOpenConversations" class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]">
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('AGENT_MGMT.EDIT.FORM.MAX_OPEN_CONVERSATIONS.LABEL') }}</span>
            <input
              v-model="maxOpenConversationsInput"
              type="number"
              min="1"
              step="1"
              :placeholder="$t('AGENT_MGMT.EDIT.FORM.MAX_OPEN_CONVERSATIONS.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
            />
          </div>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex items-center justify-between gap-3 py-2">
        <Button
          v-if="provider !== 'saml'"
          ghost
          type="button"
          icon="i-lucide-lock-keyhole"
          class="!px-2 text-n-slate-10 hover:text-n-brand"
          :label="$t('AGENT_MGMT.EDIT.PASSWORD_RESET.ADMIN_RESET_BUTTON')"
          @click.prevent="resetPassword"
        />
        <div v-else />
        <div class="flex items-center gap-3">
          <Button
            :label="$t('AGENT_MGMT.EDIT.CANCEL_BUTTON_TEXT')"
            variant="link"
            type="reset"
            class="h-10 hover:!no-underline hover:text-n-brand"
            @click.prevent="emit('close')"
          />
          <Button
            type="submit"
            :label="$t('AGENT_MGMT.EDIT.FORM.SUBMIT')"
            color="blue"
            :disabled="v$.$invalid || uiFlags.isUpdating"
            :is-loading="uiFlags.isUpdating"
          />
        </div>
      </div>
    </form>
  </div>
</template>
