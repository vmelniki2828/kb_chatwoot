<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
  />
  <svg
    v-else
    v-once
    v-bind="attrs"
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <circle cx="8" cy="8" r="8" fill="#20BDB0"/>
    <path
      d="M11.5 4.5H4.5C3.95 4.5 3.5 4.95 3.5 5.5V10C3.5 10.55 3.95 11 4.5 11H5V12.5L7 11H11.5C12.05 11 12.5 10.55 12.5 10V5.5C12.5 4.95 12.05 4.5 11.5 4.5Z"
      fill="white"
    />
    <circle cx="6" cy="7.75" r="0.75" fill="#20BDB0"/>
    <circle cx="8" cy="7.75" r="0.75" fill="#20BDB0"/>
    <circle cx="10" cy="7.75" r="0.75" fill="#20BDB0"/>
  </svg>
</template>
