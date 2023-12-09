import { s__ } from '~/locale';

export const ChildType = {
  // eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings
  Epic: 'Epic',
  // eslint-disable-next-line @gitlab/i18n/no-non-i18n-strings
  Issue: 'Issue',
};

export const ChildState = {
  Open: 'opened',
  Closed: 'closed',
};

export const idProp = {
  Epic: 'id',
  Issue: 'epicIssueId',
};

export const relativePositions = {
  Before: 'before',
  After: 'after',
};

export const RemoveItemModalProps = {
  Epic: {
    title: s__('Epics|Remove epic'),
    body: s__(
      'Epics|This will also remove any descendents of %{bStart}%{targetEpicTitle}%{bEnd} from %{bStart}%{parentEpicTitle}%{bEnd}. Are you sure?',
    ),
  },
  Issue: {
    title: s__('Epics|Remove issue'),
    body: s__(
      'Epics|Are you sure you want to remove %{bStart}%{targetIssueTitle}%{bEnd} from %{bStart}%{parentEpicTitle}%{bEnd}?',
    ),
  },
};

export const OVERFLOW_AFTER = 5;

export const SEARCH_DEBOUNCE = 500;

export const itemRemoveModalId = 'item-remove-confirmation';

export const treeItemChevronBtnClassName = 'btn-tree-item-chevron';
