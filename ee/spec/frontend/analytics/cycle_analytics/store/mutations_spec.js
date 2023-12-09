import mutations from 'ee/analytics/cycle_analytics/store/mutations';
import * as types from 'ee/analytics/cycle_analytics/store/mutation_types';
import { TASKS_BY_TYPE_FILTERS } from 'ee/analytics/cycle_analytics/constants';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';

import {
  summaryData,
  rawIssueEvents,
  issueEvents as transformedEvents,
  issueStage,
  planStage,
  codeStage,
  stagingStage,
  reviewStage,
  totalStage,
  groupLabels,
  startDate,
  endDate,
  customizableStagesAndEvents,
  tasksByTypeData,
  transformedDurationData,
  transformedTasksByTypeData,
  transformedDurationMedianData,
  selectedProjects,
} from '../mock_data';

let state = null;

describe('Cycle analytics mutations', () => {
  beforeEach(() => {
    state = {};
  });

  afterEach(() => {
    state = null;
  });

  it.each`
    mutation                                       | stateKey                              | value
    ${types.HIDE_CUSTOM_STAGE_FORM}                | ${'isCreatingCustomStage'}            | ${false}
    ${types.HIDE_CUSTOM_STAGE_FORM}                | ${'isEditingCustomStage'}             | ${false}
    ${types.HIDE_CUSTOM_STAGE_FORM}                | ${'customStageFormErrors'}            | ${null}
    ${types.HIDE_CUSTOM_STAGE_FORM}                | ${'customStageFormInitialData'}       | ${null}
    ${types.SHOW_CUSTOM_STAGE_FORM}                | ${'isCreatingCustomStage'}            | ${true}
    ${types.SHOW_CUSTOM_STAGE_FORM}                | ${'isEditingCustomStage'}             | ${false}
    ${types.SHOW_CUSTOM_STAGE_FORM}                | ${'customStageFormErrors'}            | ${null}
    ${types.SHOW_EDIT_CUSTOM_STAGE_FORM}           | ${'isEditingCustomStage'}             | ${true}
    ${types.SHOW_EDIT_CUSTOM_STAGE_FORM}           | ${'isCreatingCustomStage'}            | ${false}
    ${types.SHOW_EDIT_CUSTOM_STAGE_FORM}           | ${'customStageFormErrors'}            | ${null}
    ${types.REQUEST_STAGE_DATA}                    | ${'isLoadingStage'}                   | ${true}
    ${types.RECEIVE_STAGE_DATA_ERROR}              | ${'isEmptyStage'}                     | ${true}
    ${types.RECEIVE_STAGE_DATA_ERROR}              | ${'isLoadingStage'}                   | ${false}
    ${types.REQUEST_CYCLE_ANALYTICS_DATA}          | ${'isLoading'}                        | ${true}
    ${types.REQUEST_GROUP_LABELS}                  | ${'labels'}                           | ${[]}
    ${types.RECEIVE_GROUP_LABELS_ERROR}            | ${'labels'}                           | ${[]}
    ${types.REQUEST_TOP_RANKED_GROUP_LABELS}       | ${'topRankedLabels'}                  | ${[]}
    ${types.RECEIVE_TOP_RANKED_GROUP_LABELS_ERROR} | ${'topRankedLabels'}                  | ${[]}
    ${types.RECEIVE_SUMMARY_DATA_ERROR}            | ${'summary'}                          | ${[]}
    ${types.REQUEST_SUMMARY_DATA}                  | ${'summary'}                          | ${[]}
    ${types.RECEIVE_GROUP_STAGES_AND_EVENTS_ERROR} | ${'stages'}                           | ${[]}
    ${types.REQUEST_GROUP_STAGES_AND_EVENTS}       | ${'stages'}                           | ${[]}
    ${types.RECEIVE_GROUP_STAGES_AND_EVENTS_ERROR} | ${'customStageFormEvents'}            | ${[]}
    ${types.REQUEST_GROUP_STAGES_AND_EVENTS}       | ${'customStageFormEvents'}            | ${[]}
    ${types.REQUEST_CREATE_CUSTOM_STAGE}           | ${'isSavingCustomStage'}              | ${true}
    ${types.RECEIVE_CREATE_CUSTOM_STAGE_SUCCESS}   | ${'isSavingCustomStage'}              | ${false}
    ${types.RECEIVE_CREATE_CUSTOM_STAGE_ERROR}     | ${'isSavingCustomStage'}              | ${false}
    ${types.RECEIVE_CREATE_CUSTOM_STAGE_ERROR}     | ${'customStageFormErrors'}            | ${{}}
    ${types.REQUEST_TASKS_BY_TYPE_DATA}            | ${'isLoadingTasksByTypeChart'}        | ${true}
    ${types.RECEIVE_TASKS_BY_TYPE_DATA_ERROR}      | ${'isLoadingTasksByTypeChart'}        | ${false}
    ${types.REQUEST_UPDATE_STAGE}                  | ${'isLoading'}                        | ${true}
    ${types.REQUEST_UPDATE_STAGE}                  | ${'isSavingCustomStage'}              | ${true}
    ${types.REQUEST_UPDATE_STAGE}                  | ${'customStageFormErrors'}            | ${null}
    ${types.RECEIVE_UPDATE_STAGE_SUCCESS}          | ${'isLoading'}                        | ${false}
    ${types.RECEIVE_UPDATE_STAGE_SUCCESS}          | ${'isSavingCustomStage'}              | ${false}
    ${types.RECEIVE_UPDATE_STAGE_SUCCESS}          | ${'isEditingCustomStage'}             | ${false}
    ${types.RECEIVE_UPDATE_STAGE_SUCCESS}          | ${'customStageFormErrors'}            | ${null}
    ${types.RECEIVE_UPDATE_STAGE_ERROR}            | ${'isLoading'}                        | ${false}
    ${types.RECEIVE_UPDATE_STAGE_ERROR}            | ${'isSavingCustomStage'}              | ${false}
    ${types.REQUEST_REMOVE_STAGE}                  | ${'isLoading'}                        | ${true}
    ${types.RECEIVE_REMOVE_STAGE_RESPONSE}         | ${'isLoading'}                        | ${false}
    ${types.REQUEST_DURATION_DATA}                 | ${'isLoadingDurationChart'}           | ${true}
    ${types.RECEIVE_DURATION_DATA_ERROR}           | ${'isLoadingDurationChart'}           | ${false}
    ${types.REQUEST_STAGE_MEDIANS}                 | ${'medians'}                          | ${{}}
    ${types.RECEIVE_STAGE_MEDIANS_ERROR}           | ${'medians'}                          | ${{}}
    ${types.REQUEST_DURATION_MEDIAN_DATA}          | ${'isLoadingDurationChartMedianData'} | ${true}
    ${types.INITIALIZE_CYCLE_ANALYTICS_SUCCESS}    | ${'isLoading'}                        | ${false}
  `('$mutation will set $stateKey=$value', ({ mutation, stateKey, value }) => {
    mutations[mutation](state);

    expect(state[stateKey]).toEqual(value);
  });

  it.each`
    mutation                                       | payload                                                                                                                 | expectedState
    ${types.SET_FEATURE_FLAGS}                     | ${{ hasDurationChart: true }}                                                                                           | ${{ featureFlags: { hasDurationChart: true } }}
    ${types.SET_SELECTED_GROUP}                    | ${{ fullPath: 'cool-beans' }}                                                                                           | ${{ selectedGroup: { fullPath: 'cool-beans' }, selectedProjects: [] }}
    ${types.SET_SELECTED_PROJECTS}                 | ${selectedProjects}                                                                                                     | ${{ selectedProjects }}
    ${types.SET_DATE_RANGE}                        | ${{ startDate, endDate }}                                                                                               | ${{ startDate, endDate }}
    ${types.SET_SELECTED_STAGE}                    | ${{ id: 'first-stage' }}                                                                                                | ${{ selectedStage: { id: 'first-stage' } }}
    ${types.UPDATE_SELECTED_DURATION_CHART_STAGES} | ${{ updatedDurationStageData: transformedDurationData, updatedDurationStageMedianData: transformedDurationMedianData }} | ${{ durationData: transformedDurationData, durationMedianData: transformedDurationMedianData }}
  `(
    '$mutation with payload $payload will update state with $expectedState',
    ({ mutation, payload, expectedState }) => {
      state = {
        selectedGroup: { fullPath: 'rad-stage' },
      };
      mutations[mutation](state, payload);

      expect(state).toMatchObject(expectedState);
    },
  );

  describe(`${types.RECEIVE_STAGE_DATA_SUCCESS}`, () => {
    it('will set the currentStageEvents state item with the camelCased events', () => {
      mutations[types.RECEIVE_STAGE_DATA_SUCCESS](state, rawIssueEvents);

      expect(state.currentStageEvents).toEqual(transformedEvents);
    });

    it('will set isLoadingStage=false', () => {
      mutations[types.RECEIVE_STAGE_DATA_SUCCESS](state);

      expect(state.isLoadingStage).toEqual(false);
    });

    it('will set isEmptyStage=false if currentStageEvents.length > 0', () => {
      mutations[types.RECEIVE_STAGE_DATA_SUCCESS](state, rawIssueEvents);

      expect(state.isEmptyStage).toEqual(false);
    });

    it('will set isEmptyStage=true if currentStageEvents.length <= 0', () => {
      mutations[types.RECEIVE_STAGE_DATA_SUCCESS](state);

      expect(state.isEmptyStage).toEqual(true);
    });
  });

  describe(`types.RECEIVE_UPDATE_STAGE_ERROR`, () => {
    const mockFormError = { errors: { start_identifier: ['Cant be blank'] } };
    it('will set customStageFormErrors', () => {
      state = {};
      mutations[types.RECEIVE_UPDATE_STAGE_ERROR](state, mockFormError);

      expect(state.customStageFormErrors).toEqual(
        convertObjectPropsToCamelCase(mockFormError.errors),
      );
    });
  });

  describe(`${types.RECEIVE_GROUP_LABELS_SUCCESS}`, () => {
    it('will set the labels state item with the camelCased group labels', () => {
      mutations[types.RECEIVE_GROUP_LABELS_SUCCESS](state, groupLabels);

      expect(state.labels).toEqual(groupLabels.map(convertObjectPropsToCamelCase));
    });
  });

  describe(`${types.RECEIVE_TOP_RANKED_GROUP_LABELS_SUCCESS}`, () => {
    it('will set the labels state item with the camelCased group labels', () => {
      mutations[types.RECEIVE_GROUP_LABELS_SUCCESS](state, groupLabels);

      expect(state.labels).toEqual(groupLabels.map(convertObjectPropsToCamelCase));
    });
  });

  describe(`${types.RECEIVE_CYCLE_ANALYTICS_DATA_SUCCESS}`, () => {
    it('will set isLoading=false and errorCode=null', () => {
      mutations[types.RECEIVE_CYCLE_ANALYTICS_DATA_SUCCESS](state, {
        stats: [],
        summary: [],
        stages: [],
      });

      expect(state.errorCode).toBe(null);
      expect(state.isLoading).toBe(false);
    });
  });

  describe(`${types.RECEIVE_GROUP_STAGES_AND_EVENTS_SUCCESS}`, () => {
    describe('with data', () => {
      beforeEach(() => {
        mutations[types.RECEIVE_GROUP_STAGES_AND_EVENTS_SUCCESS](
          state,
          customizableStagesAndEvents,
        );
      });

      it('will convert the stats object to stages', () => {
        [issueStage, planStage, codeStage, stagingStage, reviewStage, totalStage].forEach(stage => {
          expect(state.stages).toContainEqual(stage);
        });
      });
    });
  });

  describe(`${types.RECEIVE_SUMMARY_DATA_SUCCESS}`, () => {
    beforeEach(() => {
      state = { stages: [{ slug: 'plan' }, { slug: 'issue' }, { slug: 'test' }] };
      mutations[types.RECEIVE_SUMMARY_DATA_SUCCESS](state, summaryData);
    });

    it('will set each summary item with a value of 0 to "-"', () => {
      expect(state.summary).toEqual([
        { value: 3, title: 'New Issues' },
        { value: '-', title: 'Deploys' },
      ]);
    });
  });

  describe(`${types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR}`, () => {
    it('sets errorCode correctly', () => {
      const errorCode = 403;

      mutations[types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR](state, errorCode);

      expect(state.isLoading).toBe(false);
      expect(state.errorCode).toBe(errorCode);
    });
  });

  describe(`${types.RECEIVE_TASKS_BY_TYPE_DATA_SUCCESS}`, () => {
    it('sets isLoadingTasksByTypeChart to false', () => {
      mutations[types.RECEIVE_TASKS_BY_TYPE_DATA_SUCCESS](state, {});

      expect(state.isLoadingTasksByTypeChart).toEqual(false);
    });

    it('sets tasksByType.data to the raw returned chart data', () => {
      state = { tasksByType: { data: null } };
      mutations[types.RECEIVE_TASKS_BY_TYPE_DATA_SUCCESS](state, tasksByTypeData);

      expect(state.tasksByType.data).toEqual(transformedTasksByTypeData);
    });
  });

  describe(`${types.RECEIVE_DURATION_DATA_SUCCESS}`, () => {
    it('sets the data correctly and falsifies isLoadingDurationChart', () => {
      const stateWithData = {
        isLoadingDurationChart: true,
        durationData: [['something', 'random']],
      };

      mutations[types.RECEIVE_DURATION_DATA_SUCCESS](stateWithData, transformedDurationData);

      expect(stateWithData.isLoadingDurationChart).toBe(false);
      expect(stateWithData.durationData).toBe(transformedDurationData);
    });
  });

  describe(`${types.RECEIVE_DURATION_MEDIAN_DATA_SUCCESS}`, () => {
    it('sets the data correctly and falsifies isLoadingDurationChartMedianData', () => {
      const stateWithData = {
        isLoadingDurationChartMedianData: true,
        durationMedianData: [['something', 'random']],
      };

      mutations[types.RECEIVE_DURATION_MEDIAN_DATA_SUCCESS](
        stateWithData,
        transformedDurationMedianData,
      );

      expect(stateWithData.isLoadingDurationChartMedianData).toBe(false);
      expect(stateWithData.durationMedianData).toBe(transformedDurationMedianData);
    });
  });

  describe(`${types.RECEIVE_DURATION_MEDIAN_DATA_ERROR}`, () => {
    it('falsifies isLoadingDurationChartMedianData and sets durationMedianData to an empty array', () => {
      const stateWithData = {
        isLoadingDurationChartMedianData: true,
        durationMedianData: [['something', 'random']],
      };

      mutations[types.RECEIVE_DURATION_MEDIAN_DATA_ERROR](stateWithData);

      expect(stateWithData.isLoadingDurationChartMedianData).toBe(false);
      expect(stateWithData.durationMedianData).toStrictEqual([]);
    });
  });

  describe(`${types.RECEIVE_STAGE_MEDIANS_SUCCESS}`, () => {
    it('sets each id as a key in the median object with the corresponding value', () => {
      const stateWithData = {
        medians: {},
      };

      mutations[types.RECEIVE_STAGE_MEDIANS_SUCCESS](stateWithData, [
        { id: 1, value: 20 },
        { id: 2, value: 10 },
      ]);

      expect(stateWithData.medians).toEqual({ '1': 20, '2': 10 });
    });
  });

  describe(`${types.SET_TASKS_BY_TYPE_FILTERS}`, () => {
    it('will update the tasksByType state key', () => {
      state = { tasksByType: {} };
      const subjectFilter = { filter: TASKS_BY_TYPE_FILTERS.SUBJECT, value: 'cool-subject' };
      mutations[types.SET_TASKS_BY_TYPE_FILTERS](state, subjectFilter);

      expect(state.tasksByType).toEqual({ subject: 'cool-subject' });
    });

    it('will toggle the specified label id in the tasksByType.selectedLabelIds state key', () => {
      state = {
        tasksByType: { selectedLabelIds: [10, 20, 30] },
      };
      const labelFilter = { filter: TASKS_BY_TYPE_FILTERS.LABEL, value: 20 };
      mutations[types.SET_TASKS_BY_TYPE_FILTERS](state, labelFilter);

      expect(state.tasksByType).toEqual({ selectedLabelIds: [10, 30] });

      mutations[types.SET_TASKS_BY_TYPE_FILTERS](state, labelFilter);
      expect(state.tasksByType).toEqual({ selectedLabelIds: [10, 30, 20] });
    });
  });

  describe(`${types.INITIALIZE_CYCLE_ANALYTICS}`, () => {
    const initialData = {
      group: { fullPath: 'cool-group' },
      selectedProjects,
      createdAfter: '2019-12-31',
      createdBefore: '2020-01-01',
    };

    it.each`
      stateKey              | expectedState
      ${'isLoading'}        | ${true}
      ${'selectedGroup'}    | ${initialData.group}
      ${'selectedProjects'} | ${initialData.selectedProjects}
      ${'startDate'}        | ${initialData.createdAfter}
      ${'endDate'}          | ${initialData.createdBefore}
    `(
      '$mutation with payload $payload will update state with $expectedState',
      ({ stateKey, expectedState }) => {
        state = {};
        mutations[types.INITIALIZE_CYCLE_ANALYTICS](state, initialData);

        expect(state[stateKey]).toEqual(expectedState);
      },
    );
  });
});
