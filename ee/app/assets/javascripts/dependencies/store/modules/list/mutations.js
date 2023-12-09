import * as types from './mutation_types';
import { REPORT_STATUS, SORT_ORDER } from './constants';

export default {
  [types.SET_DEPENDENCIES_ENDPOINT](state, payload) {
    state.endpoint = payload;
  },
  [types.SET_INITIAL_STATE](state, payload) {
    Object.assign(state, payload);
  },
  [types.REQUEST_DEPENDENCIES](state) {
    state.isLoading = true;
    state.errorLoading = false;
  },
  [types.RECEIVE_DEPENDENCIES_SUCCESS](state, { dependencies, reportInfo, pageInfo }) {
    state.dependencies = dependencies;
    state.pageInfo = pageInfo;
    state.isLoading = false;
    state.errorLoading = false;
    state.reportInfo.status = reportInfo.status;
    state.reportInfo.jobPath = reportInfo.job_path;
    state.reportInfo.generatedAt = reportInfo.generated_at;
    state.initialized = true;
  },
  [types.RECEIVE_DEPENDENCIES_ERROR](state) {
    state.isLoading = false;
    state.errorLoading = true;
    state.dependencies = [];
    state.pageInfo = {};
    state.reportInfo = {
      status: REPORT_STATUS.ok,
      jobPath: '',
      generatedAt: '',
    };
    state.initialized = true;
  },
  [types.SET_SORT_FIELD](state, payload) {
    state.sortField = payload;
  },
  [types.TOGGLE_SORT_ORDER](state) {
    state.sortOrder =
      state.sortOrder === SORT_ORDER.ascending ? SORT_ORDER.descending : SORT_ORDER.ascending;
  },
};
