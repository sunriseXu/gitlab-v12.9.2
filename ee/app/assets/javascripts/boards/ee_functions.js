export const setPromotionState = store => {
  store.addPromotionState();
};

export const setWeigthFetchingState = (issue, value) => {
  issue.setFetchingState('weight', value);
};
export const setEpicFetchingState = (issue, value) => {
  issue.setFetchingState('epic', value);
};

export const getMilestoneTitle = $boardApp => ({
  milestoneTitle: $boardApp.dataset.boardMilestoneTitle,
});

export const getBoardsModalData = $boardApp => ({
  isFullscreen: false,
  focusModeAvailable: $boardApp.hasAttribute('data-focus-mode-available'),
});
