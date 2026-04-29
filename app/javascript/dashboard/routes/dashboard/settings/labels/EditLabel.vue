<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import validations, { getLabelTitleErrorMessage } from './validations';
import { useVuelidate } from '@vuelidate/core';

import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    NextButton,
  },
  props: {
    selectedResponse: {
      type: Object,
      default: () => {},
    },
  },
  emits: ['close'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      title: '',
      description: '',
      showOnSidebar: true,
      color: '',
    };
  },
  validations,
  computed: {
    ...mapGetters({
      uiFlags: 'labels/getUIFlags',
    }),
    pageTitle() {
      return `${this.$t('LABEL_MGMT.EDIT.TITLE')} - ${
        this.selectedResponse.title
      }`;
    },
    labelTitleErrorMessage() {
      const errorMessage = getLabelTitleErrorMessage(this.v$);
      return this.$t(errorMessage);
    },
  },
  mounted() {
    this.setFormValues();
  },
  methods: {
    onClose() {
      this.$emit('close');
    },
    setFormValues() {
      this.title = this.selectedResponse.title;
      this.description = this.selectedResponse.description;
      this.showOnSidebar = this.selectedResponse.show_on_sidebar;
      this.color = this.selectedResponse.color;
    },
    editLabel() {
      this.$store
        .dispatch('labels/update', {
          id: this.selectedResponse.id,
          color: this.color,
          description: this.description,
          title: this.title.toLowerCase(),
          show_on_sidebar: this.showOnSidebar,
        })
        .then(() => {
          useAlert(this.$t('LABEL_MGMT.EDIT.API.SUCCESS_MESSAGE'));
          setTimeout(() => this.onClose(), 10);
        })
        .catch(() => {
          useAlert(this.$t('LABEL_MGMT.EDIT.API.ERROR_MESSAGE'));
        });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-0">
    <div class="px-8 pt-8 pb-6 border-b border-white/10">
      <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">Labels</p>
      <h2 class="text-3xl font-black tracking-wide text-white uppercase">{{ $t('LABEL_MGMT.EDIT.TITLE') }}</h2>
    </div>

    <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="editLabel">
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Label Info</span>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.title.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase">{{ $t('LABEL_MGMT.FORM.NAME.LABEL') }}</span>
            <input
              v-model="title"
              type="text"
              :placeholder="$t('LABEL_MGMT.FORM.NAME.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 lowercase"
              @input="v$.title.$touch"
              @blur="v$.title.$touch"
            />
          </div>

          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.description.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('LABEL_MGMT.FORM.DESCRIPTION.LABEL') }}</span>
            <input
              v-model="description"
              type="text"
              :placeholder="$t('LABEL_MGMT.FORM.DESCRIPTION.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
              @input="v$.description.$touch"
              @blur="v$.description.$touch"
            />
          </div>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Appearance</span>
        </div>
        <div class="flex items-center gap-6">
          <div class="flex flex-col gap-1">
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">{{ $t('LABEL_MGMT.FORM.COLOR.LABEL') }}</span>
            <woot-color-picker v-model="color" />
          </div>
          <label class="flex items-center gap-2 cursor-pointer select-none">
            <input v-model="showOnSidebar" type="checkbox" :value="true" class="accent-[#4ade80]" />
            <span class="text-sm text-n-slate-10">{{ $t('LABEL_MGMT.FORM.SHOW_ON_SIDEBAR.LABEL') }}</span>
          </label>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex items-center justify-between gap-3 py-2">
        <NextButton
          variant="link"
          type="reset"
          :label="$t('LABEL_MGMT.FORM.CANCEL')"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          color="blue"
          :label="$t('LABEL_MGMT.FORM.EDIT')"
          :disabled="v$.title.$invalid || uiFlags.isUpdating"
          :is-loading="uiFlags.isUpdating"
        />
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
// Label API supports only lowercase letters
.label-name--input {
  ::v-deep {
    input {
      @apply lowercase;
    }
  }
}
</style>
