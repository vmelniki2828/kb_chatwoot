<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Flag from 'dashboard/components-next/flag/Flag.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import countries from 'shared/constants/countries';

const props = defineProps({
  id: { type: Number, required: true },
  name: { type: String, default: '' },
  email: { type: String, default: '' },
  additionalAttributes: { type: Object, default: () => ({}) },
  phoneNumber: { type: String, default: '' },
  thumbnail: { type: String, default: '' },
  availabilityStatus: { type: String, default: null },
  isExpanded: { type: Boolean, default: false },
  isUpdating: { type: Boolean, default: false },
  selectable: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits([
  'toggle',
  'updateContact',
  'showContact',
  'select',
  'avatarHover',
]);

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const countriesMap = computed(() => {
  return countries.reduce((acc, country) => {
    acc[country.code] = country;
    acc[country.id] = country;
    return acc;
  }, {});
});

const countryDetails = computed(() => {
  const attributes = props.additionalAttributes || {};
  const { country, countryCode, city } = attributes;

  if (!country && !countryCode) return null;

  const activeCountry =
    countriesMap.value[country] || countriesMap.value[countryCode];

  if (!activeCountry) return null;

  return {
    countryCode: activeCountry.id,
    city: city ? `${city},` : null,
    name: activeCountry.name,
  };
});

const formattedLocation = computed(() => {
  if (!countryDetails.value) return '';
  return [countryDetails.value.city, countryDetails.value.name]
    .filter(Boolean)
    .join(' ');
});

const contactProfileLink = computed(() => {
  return `/app/accounts/${route.params.accountId}/contacts/${props.id}`;
});

const onClickExpand = () => {
  emit('toggle');
};

const onClickViewDetails = () => emit('showContact', props.id);

const toggleSelect = checked => {
  emit('select', checked);
};

const handleAvatarHover = isHovered => {
  emit('avatarHover', isHovered);
};
</script>

<template>
  <div class="relative">
    <CardLayout
      :key="id"
      layout="row"
      :class="{
        'outline-n-weak !bg-n-slate-3 dark:!bg-n-solid-3': isSelected,
      }"
    >
      <div class="flex items-center justify-start flex-1 gap-4">
        <div
          class="relative"
          @mouseenter="handleAvatarHover(true)"
          @mouseleave="handleAvatarHover(false)"
        >
          <Avatar
            :name="name"
            :src="thumbnail"
            :size="48"
            :status="availabilityStatus"
            hide-offline-status
            rounded-full
          >
            <template v-if="selectable" #overlay="{ size }">
              <label
                class="flex items-center justify-center rounded-full cursor-pointer absolute inset-0 z-10 backdrop-blur-[2px] border border-n-weak"
                :style="{ width: `${size}px`, height: `${size}px` }"
                @click.stop
              >
                <Checkbox
                  :model-value="isSelected"
                  @change="event => toggleSelect(event.target.checked)"
                />
              </label>
            </template>
          </Avatar>
        </div>

        <div class="flex flex-col gap-0.5 flex-1 min-w-0">
          <span class="text-base font-medium truncate text-n-slate-12">
            {{ name }}
            <a
              :href="contactProfileLink"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="leading-none flex-shrink-0"
            >
            </a>
            <a
              :href="contactProfileLink"
              target="_blank"
              rel="noopener nofollow noreferrer"
              class="leading-none flex-shrink-0"
            >
              <span class="i-lucide-external-link text-sm text-n-slate-10" />
            </a>
          </span>
          <div class="flex flex-wrap items-center gap-x-2 gap-y-0.5">
            <span
              v-if="email"
              class="text-sm truncate text-n-slate-11 max-w-[160px]"
              :title="email"
            >
              {{ email }}
            </span>
            <span
              v-if="email && phoneNumber"
              class="w-px h-3 bg-n-slate-6 flex-shrink-0"
            />
            <span v-if="phoneNumber" class="text-sm truncate text-n-slate-11">
              {{ phoneNumber }}
            </span>
          </div>
        </div>
      </div>

      <Button
        icon="i-lucide-chevron-down"
        variant="ghost"
        color="slate"
        size="xs"
        :class="{ 'rotate-180': isExpanded }"
        @click="onClickExpand"
      />

      <template #after>
        <div
          class="transition-all duration-300 ease-in-out grid overflow-hidden"
          :class="
            isExpanded
              ? 'grid-rows-[1fr] opacity-100'
              : 'grid-rows-[0fr] opacity-0'
          "
        >
          <div class="overflow-hidden">
            <div class="px-6 py-4 border-t border-n-strong">
              <table class="w-full border-collapse">
                <tbody>
                  <tr>
                    <td
                      class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
                      style="width: 40%"
                    >
                      {{ t('CONTACT_PANEL.NAME') }}
                    </td>
                    <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
                      <div class="flex items-center gap-1.5 min-w-0">
                        <span class="truncate font-medium">{{ name }}</span>
                      </div>
                    </td>
                  </tr>

                  <tr>
                    <td
                      class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
                      style="width: 40%"
                    >
                      {{ t('CONTACT_PANEL.EMAIL_ADDRESS') }}
                    </td>
                    <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
                      <a
                        v-if="email"
                        :href="`mailto:${email}`"
                        class="hover:underline truncate block max-w-full"
                        :title="email"
                      >
                        {{ email }}
                      </a>
                      <span v-else class="text-n-slate-10">—</span>
                    </td>
                  </tr>

                  <tr>
                    <td
                      class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
                      style="width: 40%"
                    >
                      {{ t('CONTACT_PANEL.PHONE_NUMBER') }}
                    </td>
                    <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
                      <a
                        v-if="phoneNumber"
                        :href="`tel:${phoneNumber}`"
                        class="hover:underline truncate block max-w-full"
                        :title="phoneNumber"
                      >
                        {{ phoneNumber }}
                      </a>
                      <span v-else class="text-n-slate-10">—</span>
                    </td>
                  </tr>

                  <tr>
                    <td
                      class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
                      style="width: 40%"
                    >
                      {{ t('CONTACT_PANEL.COMPANY') }}
                    </td>
                    <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
                      <span
                        v-if="additionalAttributes?.companyName"
                        class="truncate block max-w-full"
                        :title="additionalAttributes.companyName"
                      >
                        {{ additionalAttributes.companyName }}
                      </span>
                      <span v-else class="text-n-slate-10">—</span>
                    </td>
                  </tr>

                  <tr>
                    <td
                      class="py-1.5 pr-4 text-xs text-n-slate-10 whitespace-nowrap align-top"
                      style="width: 40%"
                    >
                      {{ t('CONTACT_PANEL.LOCATION') }}
                    </td>
                    <td class="py-1.5 text-xs text-n-slate-12 align-top min-w-0">
                      <span
                        v-if="countryDetails"
                        class="inline-flex items-center gap-1.5"
                      >
                        <Flag :country="countryDetails.countryCode" class="size-3.5 flex-shrink-0" />
                        <span class="truncate">{{ formattedLocation }}</span>
                      </span>
                      <span v-else class="text-n-slate-10">—</span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </template>
    </CardLayout>
  </div>
</template>
