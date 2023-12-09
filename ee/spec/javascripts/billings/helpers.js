import subscriptionState from 'ee/billings/stores/modules/subscription/state';

// eslint-disable-next-line import/prefer-default-export
export const resetStore = store => {
  const newState = {
    subscription: subscriptionState(),
  };
  store.replaceState(newState);
};
