<script>
import { messageStamp } from 'shared/helpers/timeHelper';

export default {
  name: 'SystemActivityMessage',
  props: {
    message: {
      type: Object,
      required: true,
    },
  },
  computed: {
    readableTime() {
      const { created_at: createdAt = '' } = this.message;
      return messageStamp(createdAt, 'LLL d yyyy, h:mm a');
    },
  },
};
</script>

<template>
  <div
    class="flex justify-center w-full px-4 py-2"
    :id="`cwmsg-${message.id}`"
  >
    <div
      class="inline-block max-w-[92%] rounded-lg bg-n-alpha-1 px-3 py-2 text-center text-xs leading-snug text-n-slate-11"
    >
      <p v-dompurify-html="message.content" class="text-n-slate-11" />
      <p v-if="readableTime" class="mt-1 text-[10px] text-n-slate-10">
        {{ readableTime }}
      </p>
    </div>
  </div>
</template>
