import * as types from './mutation_types';
import { ALL } from './constants';
import { isBaseFilterOption } from './utils';

export default {
  [types.SET_ALL_FILTERS](state, payload = {}) {
    state.filters = state.filters.map(filter => {
      // If the payload is empty, we fall back to an empty selection
      const selectedOptions = (payload && payload[filter.id]) || [];

      const selection = Array.isArray(selectedOptions)
        ? new Set(selectedOptions)
        : new Set([selectedOptions]);

      // This prevents us from selecting nothing at all
      if (selection.size === 0) {
        selection.add(ALL);
      }

      return { ...filter, selection };
    });
    state.hideDismissed = payload.scope !== 'all';
  },
  [types.SET_FILTER](state, payload) {
    const { filterId, optionId } = payload;
    const activeFilter = state.filters.find(filter => filter.id === filterId);

    if (activeFilter) {
      let selection = new Set(activeFilter.selection);

      if (isBaseFilterOption(optionId)) {
        selection = new Set([ALL]);
      } else {
        selection.delete(ALL);
        if (selection.has(optionId)) {
          selection.delete(optionId);
        } else {
          selection.add(optionId);
        }
      }

      // This prevents us from selecting nothing at all
      if (selection.size === 0) {
        selection.add(ALL);
      }
      activeFilter.selection = selection;
    }
  },
  [types.SET_FILTER_OPTIONS](state, payload) {
    const { filterId, options } = payload;
    state.filters.find(filter => filter.id === filterId).options = options;
  },
  [types.HIDE_FILTER](state, { filterId }) {
    const hiddenFilter = state.filters.find(({ id }) => id === filterId);
    if (hiddenFilter) {
      hiddenFilter.hidden = true;
    }
  },
  [types.SET_TOGGLE_VALUE](state, { key, value }) {
    state[key] = value;
  },
};
