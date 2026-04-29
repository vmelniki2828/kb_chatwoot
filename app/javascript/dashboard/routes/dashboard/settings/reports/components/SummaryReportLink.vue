<script setup>
import { computed } from 'vue';
import Avatar from 'next/avatar/Avatar.vue';
const props = defineProps({
  row: {
    type: Object,
    required: true,
  },
});

const routeName = computed(() => `${props.row.original.type}_reports_show`);
</script>

<template>
  <router-link
    :to="{ name: routeName, params: { id: row.original.id } }"
    :class="[
      row.original.type === 'agent'
        ? 'flex items-center gap-2 hover:no-underline'
        : 'text-n-slate-12 hover:underline',
    ]"
  >
    <Avatar
      v-if="row.original.type === 'agent'"
      :src="row.original.thumbnail"
      :name="row.original.name"
      :status="row.original.status"
      :size="28"
      hide-offline-status
      rounded-full
    />
    <span class="text-n-slate-12">
      {{ row.original.name }}
    </span>
  </router-link>
</template>
