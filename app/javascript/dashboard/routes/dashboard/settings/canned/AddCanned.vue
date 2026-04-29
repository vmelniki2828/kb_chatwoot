<script>
import { mapGetters } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';

import NextButton from 'dashboard/components-next/button/Button.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    Modal,
    TagMultiSelectComboBox,
    WootMessageEditor,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',
      selectedLabelIds: [],
      addCanned: {
        showLoading: false,
        message: '',
      },
      show: true,
    };
  },
  computed: {
    ...mapGetters({
      accountLabels: 'labels/getLabels',
    }),
    labelMultiSelectOptions() {
      return this.accountLabels.map(lab => ({
        value: lab.id,
        label: lab.title,
      }));
    },
  },
  mounted() {
    this.$store.dispatch('labels/get');
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {
      required,
    },
  },
  methods: {
    resetForm() {
      this.shortCode = '';
      this.content = '';
      this.selectedLabelIds = [];
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    addCannedResponse() {
      this.addCanned.showLoading = true;
      this.$store
        .dispatch('createCannedResponse', {
          short_code: this.shortCode,
          content: this.content,
          label_ids: this.selectedLabelIds,
        })
        .then(() => {
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col gap-0">
      <div class="px-8 pt-8 pb-6 border-b border-white/10">
        <p class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1">
          {{ $t('CANNED_MGMT.ADD.TITLE') }}
        </p>
        <h2 class="text-3xl font-black tracking-wide text-white uppercase">
          {{ $t('CANNED_MGMT.ADD.DESC') }}
        </h2>
      </div>

      <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="addCannedResponse()">
        <div class="flex flex-col gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-[#4ade80] tracking-widest">01</span>
            <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">
              {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            </span>
          </div>
          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.shortCode.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase">
              {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            </span>
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
              @blur="v$.shortCode.$touch"
            />
          </div>
        </div>

        <div class="border-t border-white/10" />

        <div class="flex flex-col gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-[#4ade80] tracking-widest">02</span>
            <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">
              {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
            </span>
          </div>
          <div
            class="rounded-xl border border-white/10 bg-white/5 px-4 py-3 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.content.$error }"
          >
            <span class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase block mb-2">
              {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
            </span>
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }"
              channel-type="Context::Default"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
            />
          </div>
        </div>

        <div class="border-t border-white/10" />

        <div class="flex flex-col gap-3">
          <div class="flex items-center gap-2">
            <span class="text-xs font-bold text-[#4ade80] tracking-widest">03</span>
            <span class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase">
              {{ $t('CANNED_MGMT.ADD.FORM.LABELS.LABEL') }}
            </span>
          </div>
          <p class="text-sm text-n-slate-11 -mt-1">
            {{ $t('CANNED_MGMT.ADD.FORM.LABELS.HINT') }}
          </p>
          <TagMultiSelectComboBox
            v-if="accountLabels.length"
            v-model="selectedLabelIds"
            class="max-w-xl rounded-xl border border-white/10 bg-white/5 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :options="labelMultiSelectOptions"
            :placeholder="$t('CANNED_MGMT.ADD.FORM.LABELS.PLACEHOLDER')"
            :search-placeholder="$t('CANNED_MGMT.ADD.FORM.LABELS.SEARCH_PLACEHOLDER')"
          />
          <p v-else class="text-sm text-n-slate-11">
            {{ $t('CANNED_MGMT.ADD.FORM.LABELS.EMPTY') }}
          </p>
        </div>

        <div class="border-t border-white/10" />

        <div class="flex items-center justify-between gap-3 py-2">
          <NextButton
            faded
            slate
            type="reset"
            variant="link"
            class="h-10 hover:!no-underline hover:text-n-brand"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            color="blue"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="v$.content.$invalid || v$.shortCode.$invalid || addCanned.showLoading"
            :is-loading="addCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .ProseMirror-woot-style {
    @apply min-h-[12.5rem];

    p {
      @apply text-base;
    }
  }
}
</style>
