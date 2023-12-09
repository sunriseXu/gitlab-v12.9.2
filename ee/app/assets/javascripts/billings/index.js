import Vue from 'vue';
import SubscriptionApp from './components/app.vue';
import store from './stores';

export default (containerId = 'js-billing-plans') => {
  const containerEl = document.getElementById(containerId);

  if (!containerEl) {
    return false;
  }

  return new Vue({
    el: containerEl,
    store,
    components: {
      SubscriptionApp,
    },
    data() {
      const { dataset } = this.$options.el;
      const { namespaceId, namespaceName, planUpgradeHref, customerPortalUrl } = dataset;

      return {
        namespaceId,
        namespaceName,
        planUpgradeHref,
        customerPortalUrl,
      };
    },
    render(createElement) {
      return createElement('subscription-app', {
        props: {
          namespaceId: this.namespaceId,
          namespaceName: this.namespaceName,
          planUpgradeHref: this.planUpgradeHref,
          customerPortalUrl: this.customerPortalUrl,
        },
      });
    },
  });
};
