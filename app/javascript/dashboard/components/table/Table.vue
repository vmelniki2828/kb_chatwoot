<script setup>
import { FlexRender } from '@tanstack/vue-table';
import SortButton from './SortButton.vue';
import { computed } from 'vue';

const props = defineProps({
  table: {
    type: Object,
    required: true,
  },
  fixed: {
    type: Boolean,
    default: false,
  },
  type: {
    type: String,
    default: 'relaxed',
  },
});

const isRelaxed = computed(() => props.type === 'relaxed');
const rows = computed(() => props.table.getRowModel().rows);
const headers = computed(() => props.table.getHeaderGroups()[0].headers);
</script>

<template>
  <table class="w-full border-collapse table-fixed rounded-xl overflow-hidden">
    <thead>
      <tr>
        <th
          v-for="header in headers"
          :key="header.id"
          class="text-left py-2.5 px-4 text-xs font-medium text-n-slate-11 uppercase tracking-wider bg-n-slate-3 border-b border-n-weak first:rounded-tl-xl last:rounded-tr-xl cursor-pointer select-none"
          @click="header.column.getCanSort() && header.column.toggleSorting()"
        >
          <div v-if="!header.isPlaceholder" class="flex items-center gap-1">
            <FlexRender
              :render="header.column.columnDef.header"
              :props="header.getContext()"
            />
            <SortButton v-if="header.column.getCanSort()" :header="header" />
          </div>
        </th>
      </tr>
    </thead>

    <tbody>
      <tr
        v-for="(row, rowIndex) in rows"
        :key="row.id"
        class="hover:bg-n-alpha-1 transition-colors duration-100"
      >
        <td
          v-for="cell in row.getVisibleCells()"
          :key="cell.id"
          class="text-sm text-n-slate-12 truncate border-b border-n-weak"
          :class="[
            isRelaxed ? 'py-3.5 px-4' : 'py-2 px-4',
            rowIndex === rows.length - 1 ? 'border-b-0' : '',
          ]"
        >
          <FlexRender
            :render="cell.column.columnDef.cell"
            :props="cell.getContext()"
          />
        </td>
      </tr>
    </tbody>
  </table>
</template>
