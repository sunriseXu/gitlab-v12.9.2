import API from 'ee/api';
import * as types from './mutation_types';
import { __ } from '~/locale';
import createFlash from '~/flash';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';

export const setProjectId = ({ commit }, projectId) => commit(types.SET_PROJECT_ID, projectId);

export const setFilters = ({ commit, dispatch }, { label_name, milestone_title }) => {
  commit(types.SET_FILTERS, { labelName: label_name, milestoneTitle: milestone_title });

  dispatch('fetchMergeRequests');
};

export const fetchMergeRequests = ({ dispatch, state }) => {
  dispatch('requestMergeRequests');

  const { projectId, filters, pageInfo } = state;
  const params = {
    project_id: projectId,
    milestone_title: filters.milestoneTitle,
    label_name: filters.labelName,
    page: pageInfo.page,
  };

  return API.codeReviewAnalytics(params)
    .then(response => {
      const { headers, data } = response;
      dispatch('receiveMergeRequestsSuccess', { headers, data });
    })
    .catch(err => dispatch('receiveMergeRequestsError', err));
};

export const requestMergeRequests = ({ commit }) => commit(types.REQUEST_MERGE_REQUESTS);

export const receiveMergeRequestsSuccess = ({ commit }, { headers, data: mergeRequests }) => {
  const normalizedHeaders = normalizeHeaders(headers);
  const pageInfo = parseIntPagination(normalizedHeaders);

  commit(types.RECEIVE_MERGE_REQUESTS_SUCCESS, { pageInfo, mergeRequests });
};

export const receiveMergeRequestsError = ({ commit }, { response }) => {
  const { status } = response;
  commit(types.RECEIVE_MERGE_REQUESTS_ERROR, status);
  createFlash(__('An error occurred while loading merge requests.'));
};

export const setPage = ({ commit }, page) => commit(types.SET_PAGE, page);
