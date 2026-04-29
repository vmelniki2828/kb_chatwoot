<script setup>
import { ref, computed, reactive, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { required, helpers, url } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { useToggle } from '@vueuse/core';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import AccessToken from 'dashboard/routes/dashboard/settings/profile/AccessToken.vue';

const props = defineProps({
  type: {
    type: String,
    default: 'create',
    validator: value => ['create', 'edit'].includes(value),
  },
  selectedBot: {
    type: Object,
    default: () => ({}),
  },
});

const MODAL_TYPES = {
  CREATE: 'create',
  EDIT: 'edit',
};

const store = useStore();
const { t } = useI18n();
const dialogRef = ref(null);
const uiFlags = useMapGetter('agentBots/getUIFlags');

const formState = reactive({
  botName: '',
  botDescription: '',
  botUrl: '',
  botAvatar: null,
  botAvatarUrl: '',
});

const [showAccessToken, toggleAccessToken] = useToggle();
const accessToken = ref('');

const v$ = useVuelidate(
  {
    botName: {
      required: helpers.withMessage(
        () => t('AGENT_BOTS.FORM.ERRORS.NAME'),
        required
      ),
    },
    botUrl: {
      required: helpers.withMessage(
        () => t('AGENT_BOTS.FORM.ERRORS.URL'),
        required
      ),
      url: helpers.withMessage(
        () => t('AGENT_BOTS.FORM.ERRORS.VALID_URL'),
        url
      ),
    },
  },
  formState
);

const isLoading = computed(() =>
  props.type === MODAL_TYPES.CREATE
    ? uiFlags.value.isCreating
    : uiFlags.value.isUpdating
);

const dialogTitle = computed(() => {
  if (showAccessToken.value) {
    return t('AGENT_BOTS.ACCESS_TOKEN.TITLE');
  }

  return props.type === MODAL_TYPES.CREATE
    ? t('AGENT_BOTS.ADD.TITLE')
    : t('AGENT_BOTS.EDIT.TITLE');
});

const dialogDescription = computed(() => {
  if (showAccessToken.value) {
    return t('AGENT_BOTS.ACCESS_TOKEN.DESCRIPTION');
  }
  return '';
});

const confirmButtonLabel = computed(() =>
  props.type === MODAL_TYPES.CREATE
    ? t('AGENT_BOTS.FORM.CREATE')
    : t('AGENT_BOTS.FORM.UPDATE')
);

const botNameError = computed(() =>
  v$.value.botName.$error ? v$.value.botName.$errors[0]?.$message : ''
);

const botUrlError = computed(() =>
  v$.value.botUrl.$error ? v$.value.botUrl.$errors[0]?.$message : ''
);

const showAccessTokenInput = computed(
  () =>
    showAccessToken.value ||
    props.type === MODAL_TYPES.EDIT ||
    accessToken.value
);

const resetForm = () => {
  Object.assign(formState, {
    botName: '',
    botDescription: '',
    botUrl: '',
    botAvatar: null,
    botAvatarUrl: '',
  });
  v$.value.$reset();
};

const handleImageUpload = ({ file, url: avatarUrl }) => {
  formState.botAvatar = file;
  formState.botAvatarUrl = avatarUrl;
};

const handleAvatarDelete = async () => {
  if (props.selectedBot?.id) {
    try {
      await store.dispatch(
        'agentBots/deleteAgentBotAvatar',
        props.selectedBot.id
      );
      formState.botAvatar = null;
      formState.botAvatarUrl = '';
      useAlert(t('AGENT_BOTS.AVATAR.SUCCESS_DELETE'));
    } catch (error) {
      useAlert(t('AGENT_BOTS.AVATAR.ERROR_DELETE'));
    }
  } else {
    formState.botAvatar = null;
    formState.botAvatarUrl = '';
  }
};

const handleSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;
  if (showAccessToken.value) return;

  const botData = {
    name: formState.botName,
    description: formState.botDescription,
    outgoing_url: formState.botUrl,
    bot_type: 'webhook',
    avatar: formState.botAvatar,
  };

  const isCreate = props.type === MODAL_TYPES.CREATE;

  try {
    const actionPayload = isCreate
      ? botData
      : { id: props.selectedBot.id, data: botData };

    const response = await store.dispatch(
      `agentBots/${isCreate ? 'create' : 'update'}`,
      actionPayload
    );

    const alertKey = isCreate
      ? t('AGENT_BOTS.ADD.API.SUCCESS_MESSAGE')
      : t('AGENT_BOTS.EDIT.API.SUCCESS_MESSAGE');
    useAlert(alertKey);

    // Show access token after creation
    if (isCreate) {
      const { access_token: responseAccessToken, id } = response || {};

      if (id && responseAccessToken) {
        accessToken.value = responseAccessToken;
        toggleAccessToken(true);
      } else {
        accessToken.value = '';
        dialogRef.value.close();
      }
    } else {
      dialogRef.value.close();
    }

    resetForm();
  } catch (error) {
    const errorKey = isCreate
      ? t('AGENT_BOTS.ADD.API.ERROR_MESSAGE')
      : t('AGENT_BOTS.EDIT.API.ERROR_MESSAGE');
    useAlert(errorKey);
  }
};

const initializeForm = () => {
  if (props.selectedBot && Object.keys(props.selectedBot).length) {
    const {
      name,
      description,
      outgoing_url: botUrl,
      thumbnail,
      bot_config: botConfig,
      access_token: botAccessToken,
    } = props.selectedBot;
    formState.botName = name || '';
    formState.botDescription = description || '';
    formState.botUrl = botUrl || botConfig?.webhook_url || '';
    formState.botAvatarUrl = thumbnail || '';

    if (botAccessToken && props.type === MODAL_TYPES.EDIT) {
      accessToken.value = botAccessToken;
    }
  } else {
    resetForm();
  }
};

const onCopyToken = async value => {
  await copyTextToClipboard(value);
  useAlert(t('AGENT_BOTS.ACCESS_TOKEN.COPY_SUCCESSFUL'));
};

const onResetToken = async () => {
  const response = await store.dispatch(
    'agentBots/resetAccessToken',
    props.selectedBot.id
  );
  if (response) {
    accessToken.value = response.access_token;
    useAlert(t('AGENT_BOTS.ACCESS_TOKEN.RESET_SUCCESS'));
  } else {
    useAlert(t('AGENT_BOTS.ACCESS_TOKEN.RESET_ERROR'));
  }
};

const closeModal = () => {
  if (!showAccessToken.value) v$.value?.$reset();
  accessToken.value = '';
  toggleAccessToken(false);
};

const onClickClose = () => {
  closeModal();
  dialogRef.value.close();
};

watch(() => props.selectedBot, initializeForm, { immediate: true, deep: true });

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="closeModal"
  >
    <div class="flex flex-col gap-0">
      <div class="px-8 pt-8 pb-6 border-b border-white/10">
        <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">Bots</p>
        <h2 class="text-3xl font-black tracking-wide text-white uppercase">{{ dialogTitle }}</h2>
        <p v-if="dialogDescription" class="text-sm text-n-slate-10 mt-1">{{ dialogDescription }}</p>
      </div>

      <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="handleSubmit">

        <template v-if="!showAccessToken || type === 'edit'">
          <div class="flex flex-col gap-3">
            <div class="flex items-center gap-2">
              <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
              <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Identity</span>
            </div>
            <div class="flex items-center gap-4">
              <Avatar
                :src="formState.botAvatarUrl"
                :name="formState.botName"
                :size="68"
                allow-upload
                icon-name="i-lucide-bot-message-square-message-square"
                @upload="handleImageUpload"
                @delete="handleAvatarDelete"
              />
              <div
                class="flex-1 flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
                :class="{ 'border-red-500/50': v$.botName.$error }"
              >
                <span class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase">{{ $t('AGENT_BOTS.FORM.NAME.LABEL') }}</span>
                <input
                  v-model="formState.botName"
                  type="text"
                  :placeholder="$t('AGENT_BOTS.FORM.NAME.PLACEHOLDER')"
                  class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
                  @blur="v$.botName.$touch()"
                />
              </div>
            </div>
          </div>

          <div class="border-t border-white/10" />

          <div class="flex flex-col gap-3">
            <div class="flex items-center gap-2">
              <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
              <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Configuration</span>
            </div>
            <div class="flex flex-col gap-3">
              <div
                class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
                :class="{ 'border-red-500/50': v$.botUrl.$error }"
              >
                <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('AGENT_BOTS.FORM.WEBHOOK_URL.LABEL') }}</span>
                <input
                  v-model="formState.botUrl"
                  type="text"
                  :placeholder="$t('AGENT_BOTS.FORM.WEBHOOK_URL.PLACEHOLDER')"
                  class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
                  @blur="v$.botUrl.$touch()"
                />
              </div>

              <div class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-2 pb-3 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]">
                <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('AGENT_BOTS.FORM.DESCRIPTION.LABEL') }}</span>
                <textarea
                  v-model="formState.botDescription"
                  :placeholder="$t('AGENT_BOTS.FORM.DESCRIPTION.PLACEHOLDER')"
                  rows="3"
                  class="bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 resize-none"
                />
              </div>
            </div>
          </div>
        </template>

        <div v-if="showAccessTokenInput" class="flex flex-col gap-3">
          <div class="border-t border-white/10" />
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-[#4ade80] tracking-widest">03</span>
            <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">{{ $t('AGENT_BOTS.ACCESS_TOKEN.TITLE') }}</span>
          </div>
          <AccessToken
            v-if="type === 'edit'"
            :value="accessToken"
            @on-copy="onCopyToken"
            @on-reset="onResetToken"
          />
          <AccessToken
            v-else
            :value="accessToken"
            :show-reset-button="false"
            @on-copy="onCopyToken"
          />
        </div>

        <div class="border-t border-white/10" />

        <div class="flex items-center justify-between gap-3 py-2">
          <NextButton
            variant="link"
            type="reset"
            :label="$t('AGENT_BOTS.FORM.CANCEL')"
            class="h-10 hover:!no-underline hover:text-n-brand"
            @click="onClickClose()"
          />
          <NextButton
            v-if="!showAccessToken"
            type="submit"
            color="blue"
            :label="confirmButtonLabel"
            :is-loading="isLoading"
            :disabled="v$.$invalid"
          />
        </div>
      </form>
    </div>
  </Dialog>
</template>
