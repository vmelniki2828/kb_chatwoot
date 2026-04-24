<script>
import AgentMessage from 'widget/components/AgentMessage.vue';
import UserMessage from 'widget/components/UserMessage.vue';
import SystemActivityMessage from 'widget/components/SystemActivityMessage.vue';
import { mapGetters } from 'vuex';
import { MESSAGE_TYPE } from 'widget/helpers/constants';

export default {
  components: {
    AgentMessage,
    UserMessage,
    SystemActivityMessage,
  },
  props: {
    message: {
      type: Object,
      default: () => {},
    },
  },
  computed: {
    ...mapGetters({
      allMessages: 'conversation/getConversation',
    }),
    isUserMessage() {
      return this.message.message_type === MESSAGE_TYPE.INCOMING;
    },
    isActivityMessage() {
      return this.message.message_type === MESSAGE_TYPE.ACTIVITY;
    },
    /** Не показываем в виджете служебные сообщения о смене лейблов (для посетителя бессмысленно). */
    isWidgetHiddenActivity() {
      if (!this.isActivityMessage) return false;
      const attrs = this.message.content_attributes || {};
      return attrs.activity_type === 'labels_change';
    },
    replyTo() {
      const replyTo = this.message?.content_attributes?.in_reply_to;
      return replyTo ? this.allMessages[replyTo] : null;
    },
  },
};
</script>

<template>
  <UserMessage
    v-if="isUserMessage"
    :id="`cwmsg-${message.id}`"
    :message="message"
    :reply-to="replyTo"
  />
  <template v-else-if="isActivityMessage">
    <SystemActivityMessage
      v-if="!isWidgetHiddenActivity"
      :message="message"
    />
  </template>
  <AgentMessage
    v-else
    :id="`cwmsg-${message.id}`"
    :message="message"
    :reply-to="replyTo"
  />
</template>

<style scoped lang="scss">
.message-wrap {
  display: flex;
  flex-direction: row;
  align-items: flex-end;
  max-width: 90%;
}
</style>
