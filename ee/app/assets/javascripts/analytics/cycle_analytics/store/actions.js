import dateFormat from 'dateformat';
import Api from 'ee/api';
import { getDayDifference, getDateInPast } from '~/lib/utils/datetime_utility';
import createFlash from '~/flash';
import { __, sprintf } from '~/locale';
import httpStatus from '~/lib/utils/http_status';
import * as types from './mutation_types';
import { dateFormats } from '../../shared/constants';
import { removeFlash } from '../utils';

const handleErrorOrRethrow = ({ action, error }) => {
  if (error?.response?.status === httpStatus.FORBIDDEN) {
    throw error;
  }
  action();
};

const isStageNameExistsError = ({ status, errors }) => {
  const ERROR_NAME_RESERVED = 'is reserved';
  if (status === httpStatus.UNPROCESSABLE_ENTITY) {
    if (errors?.name?.includes(ERROR_NAME_RESERVED)) return true;
  }
  return false;
};

export const setFeatureFlags = ({ commit }, featureFlags) =>
  commit(types.SET_FEATURE_FLAGS, featureFlags);

export const setSelectedGroup = ({ commit }, group) => commit(types.SET_SELECTED_GROUP, group);

export const setSelectedProjects = ({ commit }, projects) => {
  commit(types.SET_SELECTED_PROJECTS, projects);
};

export const setSelectedStage = ({ commit }, stage) => commit(types.SET_SELECTED_STAGE, stage);

export const setDateRange = ({ commit, dispatch }, { skipFetch = false, startDate, endDate }) => {
  commit(types.SET_DATE_RANGE, { startDate, endDate });

  if (skipFetch) return false;

  return dispatch('fetchCycleAnalyticsData');
};

export const requestStageData = ({ commit }) => commit(types.REQUEST_STAGE_DATA);
export const receiveStageDataSuccess = ({ commit }, data) => {
  commit(types.RECEIVE_STAGE_DATA_SUCCESS, data);
};

export const receiveStageDataError = ({ commit }) => {
  commit(types.RECEIVE_STAGE_DATA_ERROR);
  createFlash(__('There was an error fetching data for the selected stage'));
};

export const fetchStageData = ({ state, dispatch, getters }, slug) => {
  const { cycleAnalyticsRequestParams = {} } = getters;
  const {
    selectedGroup: { fullPath },
  } = state;

  dispatch('requestStageData');

  return Api.cycleAnalyticsStageEvents(fullPath, slug, cycleAnalyticsRequestParams)
    .then(({ data }) => dispatch('receiveStageDataSuccess', data))
    .catch(error => dispatch('receiveStageDataError', error));
};

export const requestStageMedianValues = ({ commit }) => commit(types.REQUEST_STAGE_MEDIANS);
export const receiveStageMedianValuesSuccess = ({ commit }, data) => {
  commit(types.RECEIVE_STAGE_MEDIANS_SUCCESS, data);
};

export const receiveStageMedianValuesError = ({ commit }) => {
  commit(types.RECEIVE_STAGE_MEDIANS_ERROR);
  createFlash(__('There was an error fetching median data for stages'));
};

const fetchStageMedian = (currentGroupPath, stageId, params) =>
  Api.cycleAnalyticsStageMedian(currentGroupPath, stageId, params).then(({ data }) => ({
    id: stageId,
    ...data,
  }));

export const fetchStageMedianValues = ({ state, dispatch, getters }) => {
  const {
    currentGroupPath,
    cycleAnalyticsRequestParams: { created_after, created_before },
  } = getters;

  const { stages } = state;
  const params = {
    group_id: currentGroupPath,
    created_after,
    created_before,
  };

  dispatch('requestStageMedianValues');
  const stageIds = stages.map(s => s.slug);

  return Promise.all(stageIds.map(stageId => fetchStageMedian(currentGroupPath, stageId, params)))
    .then(data => dispatch('receiveStageMedianValuesSuccess', data))
    .catch(error =>
      handleErrorOrRethrow({
        error,
        action: () => dispatch('receiveStageMedianValuesError', error),
      }),
    );
};

export const requestCycleAnalyticsData = ({ commit }) => commit(types.REQUEST_CYCLE_ANALYTICS_DATA);
export const receiveCycleAnalyticsDataSuccess = ({ state, commit, dispatch }) => {
  commit(types.RECEIVE_CYCLE_ANALYTICS_DATA_SUCCESS);

  const { featureFlags: { hasDurationChart = false, hasTasksByTypeChart = false } = {} } = state;
  const promises = [];
  if (hasDurationChart) promises.push('fetchDurationData');
  if (hasTasksByTypeChart) promises.push('fetchTasksByTypeData');
  return Promise.all(promises.map(func => dispatch(func)));
};

export const receiveCycleAnalyticsDataError = ({ commit }, { response }) => {
  const { status } = response;
  commit(types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR, status);

  if (status !== httpStatus.FORBIDDEN)
    createFlash(__('There was an error while fetching value stream analytics data.'));
};

export const fetchCycleAnalyticsData = ({ dispatch }) => {
  removeFlash();

  dispatch('requestCycleAnalyticsData');
  return Promise.resolve()
    .then(() => dispatch('fetchGroupLabels'))
    .then(() => dispatch('fetchTopRankedGroupLabels'))
    .then(() => dispatch('fetchGroupStagesAndEvents'))
    .then(() => dispatch('fetchStageMedianValues'))
    .then(() => dispatch('fetchSummaryData'))
    .then(() => dispatch('receiveCycleAnalyticsDataSuccess'))
    .catch(error => dispatch('receiveCycleAnalyticsDataError', error));
};

export const hideCustomStageForm = ({ commit }) => {
  commit(types.HIDE_CUSTOM_STAGE_FORM);
  removeFlash();
};

export const showCustomStageForm = ({ commit }) => {
  commit(types.SHOW_CUSTOM_STAGE_FORM);
  removeFlash();
};

export const showEditCustomStageForm = ({ commit, dispatch }, selectedStage = {}) => {
  const {
    id = null,
    name = null,
    startEventIdentifier = null,
    startEventLabel: { id: startEventLabelId = null } = {},
    endEventIdentifier = null,
    endEventLabel: { id: endEventLabelId = null } = {},
  } = selectedStage;

  commit(types.SHOW_EDIT_CUSTOM_STAGE_FORM, {
    id,
    name,
    startEventIdentifier,
    startEventLabelId,
    endEventIdentifier,
    endEventLabelId,
  });
  dispatch('setSelectedStage', selectedStage);
  removeFlash();
};

export const requestSummaryData = ({ commit }) => commit(types.REQUEST_SUMMARY_DATA);

export const receiveSummaryDataError = ({ commit }, error) => {
  commit(types.RECEIVE_SUMMARY_DATA_ERROR, error);
  createFlash(__('There was an error while fetching value stream analytics summary data.'));
};

export const receiveSummaryDataSuccess = ({ commit }, data) =>
  commit(types.RECEIVE_SUMMARY_DATA_SUCCESS, data);

export const fetchSummaryData = ({ state, dispatch, getters }) => {
  const {
    cycleAnalyticsRequestParams: { created_after, created_before },
  } = getters;
  dispatch('requestSummaryData');

  const {
    selectedGroup: { fullPath },
  } = state;

  return Api.cycleAnalyticsSummaryData({ group_id: fullPath, created_after, created_before })
    .then(({ data }) => dispatch('receiveSummaryDataSuccess', data))
    .catch(error =>
      handleErrorOrRethrow({ error, action: () => dispatch('receiveSummaryDataError', error) }),
    );
};

export const requestGroupStagesAndEvents = ({ commit }) =>
  commit(types.REQUEST_GROUP_STAGES_AND_EVENTS);

export const receiveGroupLabelsSuccess = ({ commit }, data) =>
  commit(types.RECEIVE_GROUP_LABELS_SUCCESS, data);

export const receiveGroupLabelsError = ({ commit }, error) => {
  commit(types.RECEIVE_GROUP_LABELS_ERROR, error);
  createFlash(__('There was an error fetching label data for the selected group'));
};

export const requestGroupLabels = ({ commit }) => commit(types.REQUEST_GROUP_LABELS);

export const fetchGroupLabels = ({ dispatch, state }) => {
  dispatch('requestGroupLabels');
  const {
    selectedGroup: { fullPath },
  } = state;

  return Api.cycleAnalyticsGroupLabels(fullPath)
    .then(({ data }) => dispatch('receiveGroupLabelsSuccess', data))
    .catch(error =>
      handleErrorOrRethrow({ error, action: () => dispatch('receiveGroupLabelsError', error) }),
    );
};

export const receiveTopRankedGroupLabelsSuccess = ({ commit }, data) =>
  commit(types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS, data);

export const receiveTopRankedGroupLabelsError = ({ commit }, error) => {
  commit(types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR, error);
  createFlash(__('There was an error fetching the top labels for the selected group'));
};

export const requestTopRankedGroupLabels = ({ commit }) =>
  commit(types.REQUEST_TOP_RANKED_GROUP_LABELS);

export const fetchTopRankedGroupLabels = ({
  dispatch,
  state,
  getters: {
    currentGroupPath,
    cycleAnalyticsRequestParams: { created_after, created_before },
  },
}) => {
  dispatch('requestTopRankedGroupLabels');
  const { subject } = state.tasksByType;

  return Api.cycleAnalyticsTopLabels({
    subject,
    created_after,
    created_before,
    group_id: currentGroupPath,
  })
    .then(({ data }) => dispatch('receiveTopRankedGroupLabelsSuccess', data))
    .catch(error =>
      handleErrorOrRethrow({
        error,
        action: () => dispatch('receiveTopRankedGroupLabelsError', error),
      }),
    );
};

export const receiveGroupStagesAndEventsError = ({ commit }, error) => {
  commit(types.RECEIVE_GROUP_STAGES_AND_EVENTS_ERROR, error);
  createFlash(__('There was an error fetching value stream analytics stages.'));
};

export const receiveGroupStagesAndEventsSuccess = ({ state, commit, dispatch }, data) => {
  commit(types.RECEIVE_GROUP_STAGES_AND_EVENTS_SUCCESS, data);
  const { stages = [] } = state;
  if (stages && stages.length) {
    const [firstStage] = stages;
    dispatch('setSelectedStage', firstStage);
    dispatch('fetchStageData', firstStage.slug);
  } else {
    createFlash(__('There was an error while fetching value stream analytics data.'));
  }
};

export const fetchGroupStagesAndEvents = ({ state, dispatch, getters }) => {
  const {
    selectedGroup: { fullPath },
  } = state;

  const {
    cycleAnalyticsRequestParams: { created_after, project_ids },
  } = getters;
  dispatch('requestGroupStagesAndEvents');

  return Api.cycleAnalyticsGroupStagesAndEvents(fullPath, {
    start_date: created_after,
    project_ids,
  })
    .then(({ data }) => dispatch('receiveGroupStagesAndEventsSuccess', data))
    .catch(error =>
      handleErrorOrRethrow({
        error,
        action: () => dispatch('receiveGroupStagesAndEventsError', error),
      }),
    );
};

export const clearCustomStageFormErrors = ({ commit }) => {
  commit(types.CLEAR_CUSTOM_STAGE_FORM_ERRORS);
  removeFlash();
};

export const requestCreateCustomStage = ({ commit }) => commit(types.REQUEST_CREATE_CUSTOM_STAGE);
export const receiveCreateCustomStageSuccess = ({ commit, dispatch }, { data: { title } }) => {
  commit(types.RECEIVE_CREATE_CUSTOM_STAGE_SUCCESS);
  createFlash(sprintf(__(`Your custom stage '%{title}' was created`), { title }), 'notice');

  return Promise.resolve()
    .then(() => dispatch('fetchGroupStagesAndEvents'))
    .then(() => dispatch('fetchSummaryData'))
    .catch(() => {
      createFlash(__('There was a problem refreshing the data, please try again'));
    });
};

export const receiveCreateCustomStageError = (
  { commit },
  { status = 400, errors = {}, data = {} } = {},
) => {
  commit(types.RECEIVE_CREATE_CUSTOM_STAGE_ERROR, { errors });
  const { name = null } = data;
  const flashMessage =
    name && isStageNameExistsError({ status, errors })
      ? sprintf(__(`'%{name}' stage already exists`), { name })
      : __('There was a problem saving your custom stage, please try again');

  createFlash(flashMessage);
};

export const createCustomStage = ({ dispatch, state }, data) => {
  const {
    selectedGroup: { fullPath },
  } = state;
  dispatch('requestCreateCustomStage');

  return Api.cycleAnalyticsCreateStage(fullPath, data)
    .then(response => {
      const { status, data: responseData } = response;
      return dispatch('receiveCreateCustomStageSuccess', { status, data: responseData });
    })
    .catch(({ response } = {}) => {
      const { data: { message, errors } = null, status = 400 } = response;

      dispatch('receiveCreateCustomStageError', { data, message, errors, status });
    });
};

export const receiveTasksByTypeDataSuccess = ({ commit }, data) => {
  commit(types.RECEIVE_TASKS_BY_TYPE_DATA_SUCCESS, data);
};

export const receiveTasksByTypeDataError = ({ commit }, error) => {
  commit(types.RECEIVE_TASKS_BY_TYPE_DATA_ERROR, error);
  createFlash(__('There was an error fetching data for the tasks by type chart'));
};

export const requestTasksByTypeData = ({ commit }) => commit(types.REQUEST_TASKS_BY_TYPE_DATA);

export const fetchTasksByTypeData = ({ dispatch, state, getters }) => {
  const {
    currentGroupPath,
    cycleAnalyticsRequestParams: { created_after, created_before, project_ids },
  } = getters;

  const {
    tasksByType: { subject, selectedLabelIds },
  } = state;

  // dont request if we have no labels selected...for now
  if (selectedLabelIds.length) {
    const params = {
      group_id: currentGroupPath,
      created_after,
      created_before,
      project_ids,
      subject,
      label_ids: selectedLabelIds,
    };

    dispatch('requestTasksByTypeData');

    return Api.cycleAnalyticsTasksByType(params)
      .then(({ data }) => dispatch('receiveTasksByTypeDataSuccess', data))
      .catch(error => dispatch('receiveTasksByTypeDataError', error));
  }
  return Promise.resolve();
};

export const requestUpdateStage = ({ commit }) => commit(types.REQUEST_UPDATE_STAGE);
export const receiveUpdateStageSuccess = ({ commit, dispatch }, updatedData) => {
  commit(types.RECEIVE_UPDATE_STAGE_SUCCESS);
  createFlash(__('Stage data updated'), 'notice');

  return Promise.all([
    dispatch('fetchGroupStagesAndEvents'),
    dispatch('setSelectedStage', updatedData),
  ]).catch(() => {
    createFlash(__('There was a problem refreshing the data, please try again'));
  });
};

export const receiveUpdateStageError = (
  { commit },
  { status, responseData: { errors = null } = {}, data = {} },
) => {
  commit(types.RECEIVE_UPDATE_STAGE_ERROR, { errors, data });

  const { name = null } = data;
  const message =
    name && isStageNameExistsError({ status, errors })
      ? sprintf(__(`'%{name}' stage already exists`), { name })
      : __('There was a problem saving your custom stage, please try again');

  createFlash(__(message));
};

export const updateStage = ({ dispatch, state }, { id, ...rest }) => {
  const {
    selectedGroup: { fullPath },
  } = state;

  dispatch('requestUpdateStage');

  return Api.cycleAnalyticsUpdateStage(id, fullPath, { ...rest })
    .then(({ data }) => dispatch('receiveUpdateStageSuccess', data))
    .catch(({ response: { status = 400, data: responseData } = {} }) =>
      dispatch('receiveUpdateStageError', { status, responseData, data: { id, ...rest } }),
    );
};

export const requestRemoveStage = ({ commit }) => commit(types.REQUEST_REMOVE_STAGE);
export const receiveRemoveStageSuccess = ({ commit, dispatch }) => {
  commit(types.RECEIVE_REMOVE_STAGE_RESPONSE);
  createFlash(__('Stage removed'), 'notice');
  dispatch('fetchCycleAnalyticsData');
};

export const receiveRemoveStageError = ({ commit }) => {
  commit(types.RECEIVE_REMOVE_STAGE_RESPONSE);
  createFlash(__('There was an error removing your custom stage, please try again'));
};

export const removeStage = ({ dispatch, state }, stageId) => {
  const {
    selectedGroup: { fullPath },
  } = state;

  dispatch('requestRemoveStage');

  return Api.cycleAnalyticsRemoveStage(stageId, fullPath)
    .then(() => dispatch('receiveRemoveStageSuccess'))
    .catch(error => dispatch('receiveRemoveStageError', error));
};

export const requestDurationData = ({ commit }) => commit(types.REQUEST_DURATION_DATA);

export const receiveDurationDataSuccess = ({ commit, state, dispatch }, data) => {
  commit(types.RECEIVE_DURATION_DATA_SUCCESS, data);

  const { featureFlags: { hasDurationChartMedian = false } = {} } = state;
  if (hasDurationChartMedian) dispatch('fetchDurationMedianData');
};

export const receiveDurationDataError = ({ commit }) => {
  commit(types.RECEIVE_DURATION_DATA_ERROR);
  createFlash(__('There was an error while fetching value stream analytics duration data.'));
};

export const fetchDurationData = ({ state, dispatch, getters }) => {
  dispatch('requestDurationData');

  const {
    stages,
    selectedGroup: { fullPath },
  } = state;

  const {
    cycleAnalyticsRequestParams: { created_after, created_before, project_ids },
  } = getters;

  return Promise.all(
    stages.map(stage => {
      const { slug } = stage;

      return Api.cycleAnalyticsDurationChart(slug, {
        group_id: fullPath,
        created_after,
        created_before,
        project_ids,
      }).then(({ data }) => ({
        slug,
        selected: true,
        data,
      }));
    }),
  )
    .then(data => {
      dispatch('receiveDurationDataSuccess', data);
    })
    .catch(() => dispatch('receiveDurationDataError'));
};

export const requestDurationMedianData = ({ commit }) => commit(types.REQUEST_DURATION_MEDIAN_DATA);

export const receiveDurationMedianDataSuccess = ({ commit }, data) =>
  commit(types.RECEIVE_DURATION_MEDIAN_DATA_SUCCESS, data);

export const receiveDurationMedianDataError = ({ commit }) => {
  commit(types.RECEIVE_DURATION_MEDIAN_DATA_ERROR);
  createFlash(__('There was an error while fetching value stream analytics duration median data.'));
};

export const fetchDurationMedianData = ({ state, dispatch }) => {
  dispatch('requestDurationMedianData');

  const {
    stages,
    selectedGroup: { fullPath },
    startDate,
    endDate,
    selectedProjectIds,
  } = state;

  const offsetValue = getDayDifference(new Date(startDate), new Date(endDate));
  const offsetCreatedAfter = getDateInPast(new Date(startDate), offsetValue);
  const offsetCreatedBefore = getDateInPast(new Date(endDate), offsetValue);

  return Promise.all(
    stages.map(stage => {
      const { slug } = stage;

      return Api.cycleAnalyticsDurationChart(slug, {
        group_id: fullPath,
        created_after: dateFormat(offsetCreatedAfter, dateFormats.isoDate),
        created_before: dateFormat(offsetCreatedBefore, dateFormats.isoDate),
        project_ids: selectedProjectIds,
      }).then(({ data }) => ({
        slug,
        selected: true,
        data,
      }));
    }),
  )
    .then(data => {
      dispatch('receiveDurationMedianDataSuccess', data);
    })
    .catch(() => dispatch('receiveDurationMedianDataError'));
};

export const updateSelectedDurationChartStages = ({ state, commit }, stages) => {
  const setSelectedPropertyOnStages = data =>
    data.map(stage => {
      const selected = stages.reduce((result, object) => {
        if (object.slug === stage.slug) return true;
        return result;
      }, false);

      return {
        ...stage,
        selected,
      };
    });

  const { durationData, durationMedianData } = state;
  const updatedDurationStageData = setSelectedPropertyOnStages(durationData);
  const updatedDurationStageMedianData = setSelectedPropertyOnStages(durationMedianData);

  commit(types.UPDATE_SELECTED_DURATION_CHART_STAGES, {
    updatedDurationStageData,
    updatedDurationStageMedianData,
  });
};

export const setTasksByTypeFilters = ({ dispatch, commit }, data) => {
  commit(types.SET_TASKS_BY_TYPE_FILTERS, data);
  dispatch('fetchTasksByTypeData');
};

export const initializeCycleAnalyticsSuccess = ({ commit }) =>
  commit(types.INITIALIZE_CYCLE_ANALYTICS_SUCCESS);

export const initializeCycleAnalytics = ({ dispatch, commit }, initialData = {}) => {
  commit(types.INITIALIZE_CYCLE_ANALYTICS, initialData);
  if (initialData?.group?.fullPath) {
    return dispatch('fetchCycleAnalyticsData').then(() =>
      dispatch('initializeCycleAnalyticsSuccess'),
    );
  }

  return dispatch('initializeCycleAnalyticsSuccess');
};
