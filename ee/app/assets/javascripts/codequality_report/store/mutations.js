import * as types from './mutation_types';

export default {
  [types.SET_PAGE](state, page) {
    Object.assign(state, {
      pageInfo: Object.assign(state.pageInfo, {
        page,
      }),
    });
  },
  [types.REQUEST_REPORT](state) {
    Object.assign(state, { isLoadingCodequality: true });
  },
  [types.RECEIVE_REPORT_SUCCESS](state, allCodequalityIssues) {
    Object.assign(state, {
      isLoadingCodequality: false,
      allCodequalityIssues: Object.freeze(allCodequalityIssues),
      pageInfo: Object.assign(state.pageInfo, {
        total: allCodequalityIssues.length,
      }),
    });
  },
  [types.RECEIVE_REPORT_ERROR](state, codeQualityError) {
    Object.assign(state, {
      isLoadingCodequality: false,
      allCodequalityIssues: [],
      loadingCodequalityFailed: true,
      codeQualityError,
      pageInfo: Object.assign(state.pageInfo, {
        total: 0,
      }),
    });
  },
};
