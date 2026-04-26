<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { messageStamp } from 'shared/helpers/timeHelper';

const props = defineProps({
  segments: { type: Array, default: () => [] },
  timelineStart: { type: Number, required: true },
  timelineEnd: { type: Number, required: true },
  timelineTicks: { type: Array, default: () => [] },
  userId: { type: [String, Number], required: true },
  canMovePrevious: Boolean,
  canMoveNext: Boolean,
  selectedScale: { type: String, default: 'daily' },
  availableScales: { type: Array, default: () => [] },
  displayTotals: {
    type: Object,
    default: () => ({ accepting: 0, not_accepting: 0, logged_out: 0 }),
  },
});

const emit = defineEmits(['previous', 'next', 'reset', 'scale-change']);

const { t } = useI18n();

const tooltip = ref(null);
const wrapperRef = ref(null);

function showTooltip(event, segment) {
  if (!wrapperRef.value) return;
  const rect = wrapperRef.value.getBoundingClientRect();
  tooltip.value = {
    x: event.clientX - rect.left,
    y: event.clientY - rect.top - 52,
    segment,
  };
}

function hideTooltip() {
  tooltip.value = null;
}

const availabilityMap = {
  online: 'ACCEPTING',
  busy: 'NOT_ACCEPTING',
  offline: 'LOGGED_OUT',
};

function availabilityLabel(apiKey) {
  const key = availabilityMap[String(apiKey || '').toLowerCase()];
  return key ? t(`AGENT_ACTIVITY_REPORT.STATUSES.${key}`) : '—';
}

function availabilityColor(status) {
  if (status === 'online') return '#22c55e';
  if (status === 'busy') return '#eab308';
  return '#64748b';
}

const formatDuration = totalSeconds => {
  const seconds = Number(totalSeconds || 0);
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  return `${String(h).padStart(2, '0')}h ${String(m).padStart(2, '0')}m`;
};

const timelineDuration = computed(() =>
  Math.max(1, props.timelineEnd - props.timelineStart)
);

const displaySegments = computed(() =>
  props.segments.map(segment => {
    const segStart = Number(segment.from || props.timelineStart);
    const segEnd = Number(segment.to || segStart);
    const left = ((segStart - props.timelineStart) / timelineDuration.value) * 100;
    const width = ((segEnd - segStart) / timelineDuration.value) * 100;
    return {
      ...segment,
      left: Math.max(0, Math.min(left, 100)),
      width: Math.max(0.1, Math.min(width, 100)),
      color: availabilityColor(segment.availability),
    };
  })
);

function tickLabelStyle(tick, index, total) {
  if (index === 0) return { left: '0%', transform: 'translateX(0)' };
  if (index === total - 1) return { left: '100%', transform: 'translateX(-100%)' };
  return { left: `${tick.x}%`, transform: 'translateX(-50%)' };
}

const tooltipData = computed(() => {
  if (!tooltip.value) return null;
  const s = tooltip.value.segment;
  return {
    status: availabilityLabel(s.availability),
    range: `${messageStamp(s.from, 'dd/MM/yy HH:mm')} – ${messageStamp(s.to, 'dd/MM/yy HH:mm')}`,
    duration: formatDuration(s.duration),
    color: availabilityColor(s.availability),
  };
});

const animKey = computed(() => `${props.userId}-${props.timelineStart}`);
</script>

<template>
  <div class="rounded-xl border border-n-weak bg-n-alpha-2 p-4">
    <div class="mb-3 flex flex-wrap items-center justify-between gap-2">
      <span class="text-xs font-semibold uppercase tracking-wide text-n-slate-11">
        {{ $t('AGENT_ACTIVITY_REPORT.TIMELINE.TITLE') }}
      </span>
      <div class="flex items-center gap-1.5">
        <select
        :value="selectedScale"
        style="height: 28px !important; margin: 0 !important; padding: 0 8px !important; font-size: 12px !important; line-height: 28px !important; box-sizing: border-box !important; vertical-align: middle !important;"
        class="min-w-max rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 outline-none focus:border-n-brand dark:bg-n-solid-2 appearance-none"
        @change="emit('scale-change', $event.target.value)"
        >
        <option v-for="scale in availableScales" :key="scale.key" :value="scale.key">
            {{ scale.label }}
        </option>
        </select>
        <button
          class="flex h-7 w-7 items-center justify-center rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 transition-colors hover:bg-n-alpha-3 disabled:cursor-not-allowed disabled:opacity-30 dark:bg-n-solid-2"
          :disabled="!canMovePrevious"
          @click="emit('previous')"
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="15 18 9 12 15 6"/></svg>
        </button>
        <button
          class="flex h-7 items-center justify-center rounded-lg border border-n-weak bg-n-solid-1 px-2.5 text-xs text-n-slate-12 transition-colors hover:bg-n-alpha-3 dark:bg-n-solid-2"
          @click="emit('reset')"
        >
          {{ $t('AGENT_ACTIVITY_REPORT.NAV.LATEST') }}
        </button>
        <button
          class="flex h-7 w-7 items-center justify-center rounded-lg border border-n-weak bg-n-solid-1 text-n-slate-12 transition-colors hover:bg-n-alpha-3 disabled:cursor-not-allowed disabled:opacity-30 dark:bg-n-solid-2"
          :disabled="!canMoveNext"
          @click="emit('next')"
        >
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"/></svg>
        </button>
      </div>
    </div>

    <div
      ref="wrapperRef"
      class="relative select-none rounded-lg border border-n-weak bg-n-solid-1 px-3 pb-2 pt-4 dark:bg-n-solid-3"
    >
      <svg
        :key="animKey"
        viewBox="0 0 100 10"
        class="block h-6 w-full overflow-visible"
        preserveAspectRatio="none"
        aria-hidden="true"
      >
        <rect x="0" y="3" width="100" height="4" fill="#cbd5e1" class="dark:fill-slate-700" />
        <line
          v-for="tick in timelineTicks"
          :key="`${userId}-t-${tick.value}`"
          :x1="tick.x" y1="1" :x2="tick.x" y2="9"
          stroke="#94a3b8" stroke-width="0.25"
        />
        <g
          v-for="segment in displaySegments"
          :key="`${userId}-s-${segment.from}-${segment.to}`"
          class="cursor-pointer"
          @mouseenter="showTooltip($event, segment)"
          @mouseleave="hideTooltip"
        >
          <rect :x="segment.left" y="3" :width="segment.width" height="4" :fill="segment.color" />
        </g>
      </svg>

      <div class="relative mt-2 h-4">
        <span
          v-for="(tick, index) in timelineTicks"
          :key="`${userId}-l-${tick.value}`"
          class="absolute top-0 whitespace-nowrap text-[10px] leading-tight text-n-slate-10"
          :style="tickLabelStyle(tick, index, timelineTicks.length)"
        >
          {{ tick.label }}
        </span>
      </div>

      <Transition
        enter-active-class="transition duration-100 ease-out"
        enter-from-class="opacity-0 translate-y-1"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition duration-75 ease-in"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 translate-y-1"
      >
        <div
          v-if="tooltip && tooltipData"
          class="pointer-events-none absolute z-50 -translate-x-1/2 whitespace-nowrap rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 shadow-lg"
          :style="{ left: `${tooltip.x}px`, top: `${tooltip.y}px` }"
        >
          <div class="mb-0.5 flex items-center gap-1.5">
            <span class="h-1.5 w-1.5 shrink-0 rounded-full" :style="{ backgroundColor: tooltipData.color }" />
            <span class="text-[11px] font-semibold" :style="{ color: tooltipData.color }">
              {{ tooltipData.status }}
            </span>
          </div>
          <div class="text-[11px] text-n-slate-11">{{ tooltipData.range }}</div>
          <div class="mt-0.5 text-[11px] font-medium text-n-slate-12">{{ tooltipData.duration }}</div>
        </div>
      </Transition>
    </div>

    <div class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-n-slate-11">
      <span class="flex items-center gap-1.5">
        <span class="h-2 w-2 shrink-0 rounded-full" :style="{ backgroundColor: '#22c55e' }" />
        {{ $t('AGENT_ACTIVITY_REPORT.TOTALS.ACCEPTING') }}
        <span class="font-semibold text-emerald-600 dark:text-emerald-400">{{ formatDuration(displayTotals.accepting) }}</span>
      </span>
      <span class="flex items-center gap-1.5">
        <span class="h-2 w-2 shrink-0 rounded-full" :style="{ backgroundColor: '#eab308' }" />
        {{ $t('AGENT_ACTIVITY_REPORT.TOTALS.NOT_ACCEPTING') }}
        <span class="font-semibold text-amber-600 dark:text-amber-400">{{ formatDuration(displayTotals.not_accepting) }}</span>
      </span>
      <span class="flex items-center gap-1.5">
        <span class="h-2 w-2 shrink-0 rounded-full" :style="{ backgroundColor: '#64748b' }" />
        {{ $t('AGENT_ACTIVITY_REPORT.TOTALS.LOGGED_OUT') }}
        <span class="font-semibold text-slate-500 dark:text-slate-400">{{ formatDuration(displayTotals.logged_out) }}</span>
      </span>
    </div>
  </div>
</template>
