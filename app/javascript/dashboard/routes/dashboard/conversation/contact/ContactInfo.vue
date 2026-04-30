<script>
import { mapGetters } from 'vuex';
import { dynamicTime } from 'shared/helpers/timeHelper';

export default {
  props: {
    contact: {
      type: Object,
      default: () => ({}),
    },
    channelType: {
      type: String,
      default: '',
    },
  },
  computed: {
    contactProfileLink() {
      return `/app/accounts/${this.$route.params.accountId}/contacts/${this.contact.id}`;
    },
    additionalAttributes() {
      return this.contact.additional_attributes || {};
    },
    location() {
      const {
        country = '',
        city = '',
        country_code: countryCode,
      } = this.additionalAttributes;
      const cityAndCountry = [city, country].filter(item => !!item).join(', ');
      if (!cityAndCountry) return '';
      return this.findCountryFlag(countryCode, cityAndCountry);
    },
  },
  methods: {
    dynamicTime,
    findCountryFlag(countryCode, cityAndCountry) {
      try {
        if (!countryCode) return `${cityAndCountry} 🌎`;
        const code = countryCode?.toLowerCase();
        return `${cityAndCountry} <span class="fi fi-${code} size-3.5"></span>`;
      } catch (error) {
        return '';
      }
    },
  },
};
</script>

<template>
  <div class="w-full px-1 pb-2">
    <table class="w-full border-collapse">
      <tbody>
        <!-- Name row -->
        <tr class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.NAME') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <div class="flex items-center gap-1.5 min-w-0">
              <span class="truncate font-medium">{{ contact.name }}</span>
              <span
                v-if="contact.created_at"
                v-tooltip.left="
                  `${$t('CONTACT_PANEL.CREATED_AT_LABEL')} ${dynamicTime(
                    contact.created_at
                  )}`
                "
                class="i-lucide-info text-sm text-n-slate-10 flex-shrink-0"
              />
              <a
                :href="contactProfileLink"
                target="_blank"
                rel="noopener nofollow noreferrer"
                class="leading-none flex-shrink-0"
              >
                <span class="i-lucide-external-link text-sm text-n-slate-10" />
              </a>
            </div>
          </td>
        </tr>

        <!-- Email row -->
        <tr class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.EMAIL_ADDRESS') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <a
              v-if="contact.email"
              :href="`mailto:${contact.email}`"
              class="hover:underline truncate block max-w-full"
              :title="contact.email"
            >
              {{ contact.email }}
            </a>
            <span v-else class="text-n-slate-10">—</span>
          </td>
        </tr>

        <!-- Phone row -->
        <tr class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.PHONE_NUMBER') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <a
              v-if="contact.phone_number"
              :href="`tel:${contact.phone_number}`"
              class="hover:underline truncate block max-w-full"
              :title="contact.phone_number"
            >
              {{ contact.phone_number }}
            </a>
            <span v-else class="text-n-slate-10">—</span>
          </td>
        </tr>

        <!-- Identifier row -->
        <tr v-if="contact.identifier" class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.IDENTIFIER') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <span
              class="truncate block max-w-full"
              :title="contact.identifier"
            >
              {{ contact.identifier }}
            </span>
          </td>
        </tr>

        <!-- Company row -->
        <tr class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.COMPANY') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <span
              v-if="additionalAttributes.company_name"
              class="truncate block max-w-full"
              :title="additionalAttributes.company_name"
            >
              {{ additionalAttributes.company_name }}
            </span>
            <span v-else class="text-n-slate-10">—</span>
          </td>
        </tr>

        <!-- Location row -->
        <tr class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.LOCATION') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <span
              v-if="location || additionalAttributes.location"
              v-dompurify-html="location || additionalAttributes.location"
              class="truncate block max-w-full"
            />
            <span v-else class="text-n-slate-10">—</span>
          </td>
        </tr>

        <!-- Description row -->
        <tr v-if="additionalAttributes.description" class="group">
          <td
            class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
            style="width: 38%"
          >
            {{ $t('CONTACT_PANEL.DESCRIPTION') }}
          </td>
          <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
            <span class="break-words">
              {{ additionalAttributes.description }}
            </span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>