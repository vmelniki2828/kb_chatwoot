<script setup>
import EmojiOrIcon from 'shared/components/EmojiOrIcon.vue';

defineProps({
  title: { type: String, required: true },
  compact: { type: Boolean, default: false },
  icon: { type: String, default: '' },
  emoji: { type: String, default: '' },
  isOpen: { type: Boolean, default: true },
});

const emit = defineEmits(['toggle']);
const onToggle = () => emit('toggle');
</script>

<template>
  <div class="text-sm">
    <button
      class="flex items-center w-full px-3 py-2.5 gap-2.5 rounded-lg bg-transparent hover:bg-n-slate-2 transition-colors duration-150 m-0 border-0"
      :class="{ 'bg-n-slate-2 rounded-bl-none rounded-br-none': isOpen }"
      @click.stop="onToggle"
    >
      <div
        class="w-0.5 h-4 rounded-full flex-shrink-0 transition-colors duration-150"
        :style="isOpen ? 'background: #10A37F' : ''"
        :class="{ 'bg-n-slate-6': !isOpen }"
      />

      <div class="flex items-center gap-2 flex-1 min-w-0">
        <EmojiOrIcon
          v-if="icon || emoji"
          class="inline-block w-4 flex-shrink-0 text-n-slate-10"
          :icon="icon"
          :emoji="emoji"
        />
        <span
          class="text-sm font-medium text-n-slate-12 truncate transition-colors duration-150"
          :style="isOpen ? 'color: #10A37F' : ''"
        >
          {{ title }}
        </span>
      </div>

      <div class="flex items-center gap-1 flex-shrink-0">
        <slot name="button" />
        <span
          class="transition-transform duration-200 text-n-slate-9"
          :class="{ 'rotate-45': isOpen }"
          :style="isOpen ? 'color: #10A37F' : ''"
        >
          <fluent-icon size="14" icon="add" type="solid" />
        </span>
      </div>
    </button>

    <div
      v-if="isOpen"
      class="bg-n-slate-2 rounded-bl-lg rounded-br-lg border-t border-n-weak"
      :class="compact ? 'p-0' : 'px-3 py-3'"
    >
      <slot />
    </div>
  </div>
</template>
