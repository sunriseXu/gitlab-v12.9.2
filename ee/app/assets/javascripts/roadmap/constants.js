import { s__ } from '~/locale';

export const EPIC_DETAILS_CELL_WIDTH = 320;

export const EPIC_ITEM_HEIGHT = 50;

export const TIMELINE_CELL_MIN_WIDTH = 180;

export const SCROLL_BAR_SIZE = 16;

export const EPIC_HIGHLIGHT_REMOVE_AFTER = 3000;

export const DAYS_IN_WEEK = 7;

export const PERCENTAGE = 100;

export const SMALL_TIMELINE_BAR = 100;

export const VERY_SMALL_TIMELINE_BAR = 27;

export const BUFFER_OVERLAP_SIZE = 20;

export const PRESET_TYPES = {
  QUARTERS: 'QUARTERS',
  MONTHS: 'MONTHS',
  WEEKS: 'WEEKS',
};

export const EXTEND_AS = {
  PREPEND: 'prepend',
  APPEND: 'append',
};

export const emptyStateDefault = s__(
  'GroupRoadmap|To view the roadmap, add a start or due date to one of your epics in this group or its subgroups; from %{startDate} to %{endDate}.',
);

export const emptyStateWithFilters = s__(
  'GroupRoadmap|To widen your search, change or remove filters; from %{startDate} to %{endDate}.',
);

export const PRESET_DEFAULTS = {
  QUARTERS: {
    TIMEFRAME_LENGTH: 21,
  },
  MONTHS: {
    TIMEFRAME_LENGTH: 8,
  },
  WEEKS: {
    TIMEFRAME_LENGTH: 7,
  },
};

export const PAST_DATE = new Date(new Date().getFullYear() - 100, 0, 1);

export const FUTURE_DATE = new Date(new Date().getFullYear() + 100, 0, 1);
