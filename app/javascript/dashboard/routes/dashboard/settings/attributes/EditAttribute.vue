<script>
import { useVuelidate } from '@vuelidate/core';
import { useAlert } from 'dashboard/composables';
import { required, minLength } from '@vuelidate/validators';
import { getRegexp } from 'shared/helpers/Validators';
import { ATTRIBUTE_TYPES } from './constants';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';

export default {
  components: {
    NextButton,
    TagInput,
  },
  props: {
    selectedAttribute: {
      type: Object,
      default: () => {},
    },
    isUpdating: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['onClose'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      displayName: '',
      description: '',
      attributeType: 0,
      regexPattern: null,
      regexCue: null,
      regexEnabled: false,
      show: true,
      attributeKey: '',
      values: [],
      tagInputTouched: false,
    };
  },
  validations: {
    displayName: {
      required,
    },
    attributeType: {
      required,
    },
    description: {
      required,
      minLength: minLength(1),
    },
    attributeKey: {
      required,
      isKey(value) {
        return !(value.indexOf(' ') >= 0);
      },
    },
  },
  computed: {
    types() {
      return ATTRIBUTE_TYPES.map(item => ({
        ...item,
        option: this.$t(`ATTRIBUTES_MGMT.ATTRIBUTE_TYPES.${item.key}`),
      }));
    },
    setAttributeListValue() {
      return this.selectedAttribute.attribute_values || [];
    },
    updatedAttributeListValues() {
      return this.values;
    },
    isButtonDisabled() {
      return this.v$.description.$invalid || this.isTagInputEmpty;
    },
    isTagInputEmpty() {
      return this.isAttributeTypeList && this.values.length === 0;
    },
    isTagInputInvalid() {
      return this.tagInputTouched && this.isTagInputEmpty;
    },

    pageTitle() {
      return `${this.$t('ATTRIBUTES_MGMT.EDIT.TITLE')} - ${
        this.selectedAttribute.attribute_display_name
      }`;
    },
    selectedAttributeType() {
      return this.types.find(
        item =>
          item.key.toLowerCase() ===
          this.selectedAttribute.attribute_display_type
      )?.id;
    },
    keyErrorMessage() {
      if (!this.v$.attributeKey.isKey) {
        return this.$t('ATTRIBUTES_MGMT.ADD.FORM.KEY.IN_VALID');
      }
      return this.$t('ATTRIBUTES_MGMT.ADD.FORM.KEY.ERROR');
    },
    isAttributeTypeList() {
      return this.attributeType === 6;
    },
    isAttributeTypeText() {
      return this.attributeType === 0;
    },
    isRegexEnabled() {
      return this.regexEnabled;
    },
  },
  mounted() {
    this.setFormValues();
  },
  methods: {
    onClose() {
      this.$emit('onClose');
    },
    setFormValues() {
      const regexPattern = this.selectedAttribute.regex_pattern
        ? getRegexp(this.selectedAttribute.regex_pattern).source
        : null;
      this.displayName = this.selectedAttribute.attribute_display_name;
      this.description = this.selectedAttribute.attribute_description;
      this.attributeType = this.selectedAttributeType;
      this.attributeKey = this.selectedAttribute.attribute_key;
      this.regexPattern = regexPattern;
      this.regexCue = this.selectedAttribute.regex_cue;
      this.regexEnabled = regexPattern != null;
      this.values = this.setAttributeListValue;
    },
    async editAttributes() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        return;
      }
      if (!this.regexEnabled) {
        this.regexPattern = null;
        this.regexCue = null;
      }
      try {
        await this.$store.dispatch('attributes/update', {
          id: this.selectedAttribute.id,
          attribute_description: this.description,
          attribute_display_name: this.displayName,
          attribute_values: this.updatedAttributeListValues,
          regex_pattern: this.regexPattern
            ? new RegExp(this.regexPattern).toString()
            : null,
          regex_cue: this.regexCue,
        });
        this.alertMessage = this.$t('ATTRIBUTES_MGMT.EDIT.API.SUCCESS_MESSAGE');
        this.onClose();
      } catch (error) {
        const errorMessage = error?.message;
        this.alertMessage =
          errorMessage || this.$t('ATTRIBUTES_MGMT.EDIT.API.ERROR_MESSAGE');
      } finally {
        useAlert(this.alertMessage);
      }
    },
    toggleRegexEnabled() {
      this.regexEnabled = !this.regexEnabled;
    },
  },
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">

    <div class="px-8 pt-8 pb-6 border-b border-white/10">
      <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">
        {{ $t('ATTRIBUTES_MGMT.ADD.FORM.MODEL.LABEL') }}
      </p>
      <h2 class="text-3xl font-black tracking-wide text-white uppercase">
        {{ pageTitle }}
      </h2>
    </div>

    <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="editAttributes">

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
          <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Attribute Info</span>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.displayName.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase">
              {{ $t('ATTRIBUTES_MGMT.ADD.FORM.NAME.LABEL') }}
            </span>
            <input
              v-model="displayName"
              type="text"
              :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
              @blur="v$.displayName.$touch"
            />
          </div>

          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 opacity-60 cursor-not-allowed"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
              {{ $t('ATTRIBUTES_MGMT.ADD.FORM.KEY.LABEL') }}
            </span>
            <input
              v-model="attributeKey"
              type="text"
              :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.KEY.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 cursor-not-allowed"
              readonly
            />
          </div>

          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 opacity-60 cursor-not-allowed col-span-2"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
              {{ $t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LABEL') }}
            </span>
            <select
              v-model="attributeType"
              disabled
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 p-0 appearance-none cursor-not-allowed"
            >
              <option v-for="type in types" :key="type.id" :value="type.id" class="bg-n-solid-3">
                {{ type.option }}
              </option>
            </select>
          </div>
        </div>

        <div
          class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-2 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
          :class="{ 'border-red-500/50': v$.description.$error }"
        >
          <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.DESC.LABEL') }}
          </span>
          <textarea
            v-model="description"
            rows="4"
            :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.DESC.PLACEHOLDER')"
            class="bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 resize-none"
            @blur="v$.description.$touch"
          />
        </div>
      </div>

      <template v-if="isAttributeTypeList">
        <div class="border-t border-white/10" />
        <div class="flex flex-col gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
            <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">
              {{ $t('ATTRIBUTES_MGMT.EDIT.TYPE.LIST.LABEL') }}
            </span>
          </div>
          <div
            class="rounded-xl border px-3 py-2 transition-all duration-200"
            :class="isTagInputInvalid ? 'border-red-500/50' : 'border-white/10 bg-white/5 hover:border-[rgba(74,222,128,0.4)]'"
          >
            <TagInput
              v-model="values"
              :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.PLACEHOLDER')"
              allow-create
              @blur="tagInputTouched = true"
            />
          </div>
          <span v-show="isTagInputInvalid" class="text-red-400 text-sm font-normal">
            {{ $t('ATTRIBUTES_MGMT.ADD.FORM.TYPE.LIST.ERROR') }}
          </span>
        </div>
      </template>

      <template v-if="isAttributeTypeText">
        <div class="border-t border-white/10" />
        <div class="flex flex-col gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
            <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">Validation</span>
          </div>

          <label
            class="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 px-4 py-3 cursor-pointer transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)]"
          >
            <input
              v-model="regexEnabled"
              type="checkbox"
              class="w-4 h-4 accent-[#4ade80] cursor-pointer"
              @input="toggleRegexEnabled"
            />
            <span class="text-sm text-n-slate-9">
              {{ $t('ATTRIBUTES_MGMT.ADD.FORM.ENABLE_REGEX.LABEL') }}
            </span>
          </label>

          <template v-if="isRegexEnabled">
            <div class="grid grid-cols-2 gap-3">
              <div
                class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
              >
                <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
                  {{ $t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_PATTERN.LABEL') }}
                </span>
                <input
                  v-model="regexPattern"
                  type="text"
                  :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_PATTERN.PLACEHOLDER')"
                  class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 font-mono"
                />
              </div>

              <div
                class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
              >
                <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase">
                  {{ $t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_CUE.LABEL') }}
                </span>
                <input
                  v-model="regexCue"
                  type="text"
                  :placeholder="$t('ATTRIBUTES_MGMT.ADD.FORM.REGEX_CUE.PLACEHOLDER')"
                  class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
                />
              </div>
            </div>
          </template>
        </div>
      </template>

      <div class="border-t border-white/10" />

      <div class="flex items-center justify-between gap-3 py-2">
        <NextButton
          faded
          slate
          type="reset"
          :label="$t('ATTRIBUTES_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          :label="$t('ATTRIBUTES_MGMT.EDIT.UPDATE_BUTTON_TEXT')"
          color="blue"
          :is-loading="isUpdating"
          :disabled="isButtonDisabled"
        />
      </div>
    </form>
  </div>
</template>

<style lang="scss" scoped>
.key-value {
  padding: 0 0.5rem 0.5rem 0;
  font-family: monospace;
}
</style>
