import { IFrameHelper, RNHelper } from './utils';

/**
 * Закрывает панель виджета: сообщение родителю (iframe SDK), RN WebView
 * или возврат на главный экран при открытом виджете в отдельной вкладке.
 */
export function closeWidgetSurface(vm) {
  if (IFrameHelper.isIFrame()) {
    IFrameHelper.sendMessage({ event: 'closeWindow' });
    return;
  }
  if (RNHelper.isRNWebView()) {
    RNHelper.sendMessage({ type: 'close-widget' });
    return;
  }
  vm.$store.dispatch('appConfig/toggleWidgetOpen', false);
  if (vm.$route?.name && vm.$route.name !== 'home') {
    vm.$router.replace({ name: 'home' }).catch(() => {});
  }
}
