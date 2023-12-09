import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import testAction from 'helpers/vuex_action_helper';
import * as getters from 'ee/analytics/cycle_analytics/store/getters';
import * as actions from 'ee/analytics/cycle_analytics/store/actions';
import * as types from 'ee/analytics/cycle_analytics/store/mutation_types';
import {
  TASKS_BY_TYPE_FILTERS,
  TASKS_BY_TYPE_SUBJECT_ISSUE,
} from 'ee/analytics/cycle_analytics/constants';
import createFlash from '~/flash';
import httpStatusCodes from '~/lib/utils/http_status';
import {
  group,
  summaryData,
  allowedStages as stages,
  groupLabels,
  startDate,
  endDate,
  customizableStagesAndEvents,
  rawDurationData,
  rawDurationMedianData,
  transformedDurationData,
  transformedDurationMedianData,
  endpoints,
} from '../mock_data';
import { shouldFlashAMessage } from '../helpers';

const stageData = { events: [] };
const error = new Error(`Request failed with status code ${httpStatusCodes.NOT_FOUND}`);
const flashErrorMessage = 'There was an error while fetching value stream analytics data.';
const selectedGroup = { fullPath: group.path };
const [selectedStage] = stages;
const selectedStageSlug = selectedStage.slug;

const stageEndpoint = ({ stageId }) => `/-/analytics/value_stream_analytics/stages/${stageId}`;

describe('Cycle analytics actions', () => {
  let state;
  let mock;

  beforeEach(() => {
    state = {
      startDate,
      endDate,
      stages: [],
      featureFlags: {
        hasDurationChart: true,
        hasTasksByTypeChart: true,
        hasDurationChartMedian: true,
      },
    };
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
    state = { ...state, selectedGroup: null };
  });

  it.each`
    action                   | type                       | stateKey                | payload
    ${'setFeatureFlags'}     | ${'SET_FEATURE_FLAGS'}     | ${'featureFlags'}       | ${{ hasDurationChart: true }}
    ${'setSelectedGroup'}    | ${'SET_SELECTED_GROUP'}    | ${'selectedGroup'}      | ${'someNewGroup'}
    ${'setSelectedProjects'} | ${'SET_SELECTED_PROJECTS'} | ${'selectedProjectIds'} | ${[10, 20, 30, 40]}
    ${'setSelectedStage'}    | ${'SET_SELECTED_STAGE'}    | ${'selectedStage'}      | ${{ id: 'someStageId' }}
  `('$action should set $stateKey with $payload and type $type', ({ action, type, payload }) => {
    testAction(
      actions[action],
      payload,
      state,
      [
        {
          type,
          payload,
        },
      ],
      [],
    );
  });

  describe('setDateRange', () => {
    const payload = { startDate, endDate };

    it('dispatches the fetchCycleAnalyticsData action', done => {
      testAction(
        actions.setDateRange,
        payload,
        state,
        [{ type: types.SET_DATE_RANGE, payload: { startDate, endDate } }],
        [{ type: 'fetchCycleAnalyticsData' }],
        done,
      );
    });
  });

  describe('fetchStageData', () => {
    beforeEach(() => {
      state = { ...state, selectedGroup };
      mock = new MockAdapter(axios);
      mock.onGet(endpoints.stageData).reply(200, { events: [] });
    });

    it('dispatches receiveStageDataSuccess with received data on success', done => {
      testAction(
        actions.fetchStageData,
        selectedStageSlug,
        state,
        [],
        [
          { type: 'requestStageData' },
          {
            type: 'receiveStageDataSuccess',
            payload: { events: [] },
          },
        ],
        done,
      );
    });

    describe('with a failing request', () => {
      beforeEach(() => {
        mock = new MockAdapter(axios);
        mock.onGet(endpoints.stageData).replyOnce(httpStatusCodes.NOT_FOUND, { error });
      });

      it('dispatches receiveStageDataError on error', done => {
        testAction(
          actions.fetchStageData,
          selectedStage,
          state,
          [],
          [
            {
              type: 'requestStageData',
            },
            {
              type: 'receiveStageDataError',
              payload: error,
            },
          ],
          done,
        );
      });
    });

    describe('receiveStageDataSuccess', () => {
      it(`commits the ${types.RECEIVE_STAGE_DATA_SUCCESS} mutation`, done => {
        testAction(
          actions.receiveStageDataSuccess,
          { ...stageData },
          state,
          [{ type: types.RECEIVE_STAGE_DATA_SUCCESS, payload: { events: [] } }],
          [],
          done,
        );
      });
    });
  });

  describe('receiveStageDataError', () => {
    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });
    it(`commits the ${types.RECEIVE_STAGE_DATA_ERROR} mutation`, () => {
      return testAction(
        actions.receiveStageDataError,
        null,
        state,
        [
          {
            type: types.RECEIVE_STAGE_DATA_ERROR,
          },
        ],
        [],
      );
    });

    it('will flash an error message', () => {
      actions.receiveStageDataError({
        commit: () => {},
      });

      shouldFlashAMessage('There was an error fetching data for the selected stage');
    });
  });

  describe('fetchGroupLabels', () => {
    describe('succeeds', () => {
      beforeEach(() => {
        gon.api_version = 'v4';
        state = { selectedGroup };
        mock.onGet(endpoints.groupLabels).replyOnce(200, groupLabels);
      });

      it('dispatches receiveGroupLabels if the request succeeds', () => {
        return testAction(
          actions.fetchGroupLabels,
          null,
          state,
          [],
          [
            { type: 'requestGroupLabels' },
            {
              type: 'receiveGroupLabelsSuccess',
              payload: groupLabels,
            },
          ],
        );
      });
    });

    describe('with an error', () => {
      beforeEach(() => {
        state = { selectedGroup };
        mock.onGet(endpoints.groupLabels).replyOnce(404);
      });

      it('dispatches receiveGroupLabelsError if the request fails', () => {
        return testAction(
          actions.fetchGroupLabels,
          null,
          state,
          [],
          [
            { type: 'requestGroupLabels' },
            {
              type: 'receiveGroupLabelsError',
              payload: error,
            },
          ],
        );
      });
    });

    describe('receiveGroupLabelsError', () => {
      beforeEach(() => {
        setFixtures('<div class="flash-container"></div>');
      });

      it('flashes an error message if the request fails', () => {
        actions.receiveGroupLabelsError({
          commit: () => {},
        });

        shouldFlashAMessage('There was an error fetching label data for the selected group');
      });
    });
  });

  describe('fetchTopRankedGroupLabels', () => {
    beforeEach(() => {
      gon.api_version = 'v4';
      state = { selectedGroup, tasksByType: { subject: TASKS_BY_TYPE_SUBJECT_ISSUE }, ...getters };
    });

    describe('succeeds', () => {
      beforeEach(() => {
        mock.onGet(endpoints.tasksByTypeTopLabelsData).replyOnce(200, groupLabels);
      });

      it('dispatches receiveTopRankedGroupLabelsSuccess if the request succeeds', () => {
        return testAction(
          actions.fetchTopRankedGroupLabels,
          null,
          state,
          [],
          [
            { type: 'requestTopRankedGroupLabels' },
            { type: 'receiveTopRankedGroupLabelsSuccess', payload: groupLabels },
          ],
        );
      });
    });

    describe('with an error', () => {
      beforeEach(() => {
        mock.onGet(endpoints.fetchTopRankedGroupLabels).replyOnce(404);
      });

      it('dispatches receiveTopRankedGroupLabelsError if the request fails', () => {
        return testAction(
          actions.fetchTopRankedGroupLabels,
          null,
          state,
          [],
          [
            { type: 'requestTopRankedGroupLabels' },
            { type: 'receiveTopRankedGroupLabelsError', payload: error },
          ],
        );
      });
    });

    describe('receiveTopRankedGroupLabelsError', () => {
      beforeEach(() => {
        setFixtures('<div class="flash-container"></div>');
      });

      it('flashes an error message if the request fails', () => {
        actions.receiveTopRankedGroupLabelsError({
          commit: () => {},
        });

        shouldFlashAMessage('There was an error fetching the top labels for the selected group');
      });
    });
  });

  describe('fetchCycleAnalyticsData', () => {
    function mockFetchCycleAnalyticsAction(overrides = {}) {
      const mocks = {
        requestCycleAnalyticsData:
          overrides.requestCycleAnalyticsData || jest.fn().mockResolvedValue(),
        fetchGroupLabels: overrides.fetchGroupLabels || jest.fn().mockResolvedValue(),
        fetchStageMedianValues: overrides.fetchStageMedianValues || jest.fn().mockResolvedValue(),
        fetchGroupStagesAndEvents:
          overrides.fetchGroupStagesAndEvents || jest.fn().mockResolvedValue(),
        fetchSummaryData: overrides.fetchSummaryData || jest.fn().mockResolvedValue(),
        receiveCycleAnalyticsDataSuccess:
          overrides.receiveCycleAnalyticsDataSuccess || jest.fn().mockResolvedValue(),
      };
      return {
        mocks,
        mockDispatchContext: jest
          .fn()
          .mockImplementationOnce(mocks.requestCycleAnalyticsData)
          .mockImplementationOnce(mocks.fetchGroupLabels)
          .mockImplementationOnce(mocks.fetchGroupStagesAndEvents)
          .mockImplementationOnce(mocks.fetchStageMedianValues)
          .mockImplementationOnce(mocks.fetchSummaryData)
          .mockImplementationOnce(mocks.receiveCycleAnalyticsDataSuccess),
      };
    }

    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
      mock.onGet(endpoints.summaryData).replyOnce(200, summaryData);
      state = { ...state, selectedGroup, startDate, endDate };
    });

    it(`dispatches actions for required value stream analytics analytics data`, done => {
      testAction(
        actions.fetchCycleAnalyticsData,
        state,
        null,
        [],
        [
          { type: 'requestCycleAnalyticsData' },
          { type: 'fetchGroupLabels' },
          { type: 'fetchTopRankedGroupLabels' },
          { type: 'fetchGroupStagesAndEvents' },
          { type: 'fetchStageMedianValues' },
          { type: 'fetchSummaryData' },
          { type: 'receiveCycleAnalyticsDataSuccess' },
        ],
        done,
      );
    });

    // TOOD: parameterize?
    it(`displays an error if fetchGroupLabels fails`, done => {
      const { mockDispatchContext } = mockFetchCycleAnalyticsAction({
        fetchGroupLabels: actions.fetchGroupLabels({
          dispatch: jest
            .fn()
            .mockResolvedValueOnce()
            .mockImplementation(actions.receiveGroupLabelsError({ commit: () => {} })),
          commit: () => {},
          state: { ...state },
          getters,
        }),
      });

      actions
        .fetchCycleAnalyticsData({
          dispatch: mockDispatchContext,
          state: {},
          commit: () => {},
        })

        .then(() => {
          shouldFlashAMessage('There was an error fetching label data for the selected group');
          done();
        })
        .catch(done.fail);
    });

    it(`displays an error if fetchStageMedianValues fails`, done => {
      const { mockDispatchContext } = mockFetchCycleAnalyticsAction({
        fetchStageMedianValues: actions.fetchStageMedianValues({
          dispatch: jest
            .fn()
            .mockResolvedValueOnce()
            .mockImplementation(actions.receiveStageMedianValuesError({ commit: () => {} })),
          commit: () => {},
          state: { ...state },
          getters,
        }),
      });

      actions
        .fetchCycleAnalyticsData({
          dispatch: mockDispatchContext,
          state: {},
          commit: () => {},
        })
        .then(() => {
          shouldFlashAMessage('There was an error fetching median data for stages');
          done();
        })
        .catch(done.fail);
    });

    it(`displays an error if fetchSummaryData fails`, done => {
      const { mockDispatchContext } = mockFetchCycleAnalyticsAction({
        fetchSummaryData: actions.fetchSummaryData({
          dispatch: jest
            .fn()
            .mockResolvedValueOnce()
            .mockImplementation(actions.receiveSummaryDataError({ commit: () => {} })),
          commit: () => {},
          state: { ...state },
          getters,
        }),
      });

      actions
        .fetchCycleAnalyticsData({
          dispatch: mockDispatchContext,
          state: {},
          commit: () => {},
        })
        .then(() => {
          shouldFlashAMessage(
            'There was an error while fetching value stream analytics summary data.',
          );
          done();
        })
        .catch(done.fail);
    });

    it(`displays an error if fetchGroupStagesAndEvents fails`, done => {
      const { mockDispatchContext } = mockFetchCycleAnalyticsAction({
        fetchGroupStagesAndEvents: actions.fetchGroupStagesAndEvents({
          dispatch: jest
            .fn()
            .mockResolvedValueOnce()
            .mockImplementation(actions.receiveGroupStagesAndEventsError({ commit: () => {} })),
          commit: () => {},
          state: { ...state },
          getters,
        }),
      });

      actions
        .fetchCycleAnalyticsData({
          dispatch: mockDispatchContext,
          state: {},
          commit: () => {},
        })
        .then(() => {
          shouldFlashAMessage('There was an error fetching value stream analytics stages.');
          done();
        })
        .catch(done.fail);
    });

    it(`displays an error if fetchDurationData fails`, () => {
      const { mockDispatchContext } = mockFetchCycleAnalyticsAction({
        fetchDurationData: actions.fetchDurationData(
          {
            dispatch: jest
              .fn()
              .mockResolvedValueOnce()
              .mockImplementation(actions.receiveDurationDataError({ commit: () => {} })),
            commit: () => {},
            state: { ...state, endpoints: { cycleAnalyticsStagesPath: '/this/is/fake' } },
            getters,
          },
          {},
        ),
      });

      actions.fetchDurationData(
        {
          dispatch: mockDispatchContext,
          state: { ...state, endpoints: { cycleAnalyticsStagesPath: '/this/is/fake' } },
          getters,
        },
        {},
      );

      shouldFlashAMessage(
        'There was an error while fetching value stream analytics duration data.',
      );
    });

    describe('with an existing error', () => {
      beforeEach(() => {
        setFixtures('<div class="flash-container"></div>');
      });

      it('removes an existing flash error if present', done => {
        const { mockDispatchContext } = mockFetchCycleAnalyticsAction();
        createFlash(flashErrorMessage);

        const flashAlert = document.querySelector('.flash-alert');

        expect(flashAlert).toBeVisible();

        actions
          .fetchCycleAnalyticsData({
            dispatch: mockDispatchContext,
            state: {},
            commit: () => {},
          })
          .then(() => {
            expect(flashAlert.style.opacity).toBe('0');
            done();
          })
          .catch(done.fail);
      });
    });

    it('will flash an error when there are no stages', () => {
      [[], null].forEach(emptyStages => {
        actions.receiveGroupStagesAndEventsSuccess(
          {
            commit: () => {},
            state: { stages: emptyStages },
            getters,
          },
          {},
        );

        shouldFlashAMessage(flashErrorMessage);
      });
    });
  });

  describe('receiveCycleAnalyticsDataError', () => {
    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });

    it(`commits the ${types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR} mutation on a 403 response`, done => {
      const response = { status: 403 };
      testAction(
        actions.receiveCycleAnalyticsDataError,
        { response },
        state,
        [
          {
            type: types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR,
            payload: response.status,
          },
        ],
        [],
        done,
      );
    });

    it(`commits the ${types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR} mutation on a non 403 error response`, done => {
      const response = { status: 500 };
      testAction(
        actions.receiveCycleAnalyticsDataError,
        { response },
        state,
        [
          {
            type: types.RECEIVE_CYCLE_ANALYTICS_DATA_ERROR,
            payload: response.status,
          },
        ],
        [],
        done,
      );
    });

    it('will flash an error when the response is not 403', () => {
      const response = { status: 500 };
      actions.receiveCycleAnalyticsDataError(
        {
          commit: () => {},
        },
        { response },
      );

      shouldFlashAMessage(flashErrorMessage);
    });
  });

  describe('receiveGroupStagesAndEventsSuccess', () => {
    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });

    it(`commits the ${types.RECEIVE_GROUP_STAGES_AND_EVENTS_SUCCESS} mutation`, done => {
      testAction(
        actions.receiveGroupStagesAndEventsSuccess,
        { ...customizableStagesAndEvents },
        state,
        [
          {
            type: types.RECEIVE_GROUP_STAGES_AND_EVENTS_SUCCESS,
            payload: { ...customizableStagesAndEvents },
          },
        ],
        [],
        done,
      );
    });

    it("dispatches the 'fetchStageData' action", done => {
      const stateWithStages = {
        ...state,
        stages,
      };

      testAction(
        actions.receiveGroupStagesAndEventsSuccess,
        { ...customizableStagesAndEvents },
        stateWithStages,
        [
          {
            type: types.RECEIVE_GROUP_STAGES_AND_EVENTS_SUCCESS,
            payload: { ...customizableStagesAndEvents },
          },
        ],
        [
          { type: 'setSelectedStage', payload: selectedStage },
          { type: 'fetchStageData', payload: selectedStageSlug },
        ],
        done,
      );
    });

    it('will flash an error when there are no stages', () => {
      [[], null].forEach(emptyStages => {
        actions.receiveGroupStagesAndEventsSuccess(
          {
            commit: () => {},
            state: { stages: emptyStages },
          },
          {},
        );
      });

      shouldFlashAMessage(flashErrorMessage);
    });
  });

  describe('updateStage', () => {
    const stageId = 'cool-stage';
    const payload = { hidden: true };

    beforeEach(() => {
      mock.onPut(stageEndpoint({ stageId }), payload).replyOnce(200, payload);
      state = { selectedGroup };
    });

    it('dispatches receiveUpdateStageSuccess with put request response data', done => {
      testAction(
        actions.updateStage,
        {
          id: stageId,
          ...payload,
        },
        state,
        [],
        [
          { type: 'requestUpdateStage' },
          {
            type: 'receiveUpdateStageSuccess',
            payload,
          },
        ],
        done,
      );
    });

    describe('with a failed request', () => {
      beforeEach(() => {
        setFixtures('<div class="flash-container"></div>');
        mock = new MockAdapter(axios);
        mock.onPut(stageEndpoint({ stageId })).replyOnce(httpStatusCodes.NOT_FOUND);
      });

      it('dispatches receiveUpdateStageError', done => {
        const data = {
          id: stageId,
          name: 'issue',
          ...payload,
        };
        testAction(
          actions.updateStage,
          data,
          state,
          [],
          [
            { type: 'requestUpdateStage' },
            {
              type: 'receiveUpdateStageError',
              payload: {
                status: httpStatusCodes.NOT_FOUND,
                data,
              },
            },
          ],
          done,
        );
      });

      it('flashes an error if the stage name already exists', done => {
        actions.receiveUpdateStageError(
          {
            commit: () => {},
            state,
          },
          {
            status: httpStatusCodes.UNPROCESSABLE_ENTITY,
            responseData: {
              errors: { name: ['is reserved'] },
            },
            data: {
              name: stageId,
            },
          },
        );

        shouldFlashAMessage(`'${stageId}' stage already exists`);
        done();
      });

      it('flashes an error message', done => {
        actions.receiveUpdateStageError(
          {
            commit: () => {},
            state,
          },
          { status: httpStatusCodes.BAD_REQUEST },
        );

        shouldFlashAMessage('There was a problem saving your custom stage, please try again');
        done();
      });
    });

    describe('receiveUpdateStageSuccess', () => {
      beforeEach(() => {
        setFixtures('<div class="flash-container"></div>');
      });

      const response = {
        title: 'NEW - COOL',
      };

      it('will dispatch fetchGroupStagesAndEvents and fetchSummaryData', () =>
        testAction(
          actions.receiveUpdateStageSuccess,
          response,
          state,
          [{ type: types.RECEIVE_UPDATE_STAGE_SUCCESS }],
          [{ type: 'fetchGroupStagesAndEvents' }, { type: 'setSelectedStage', payload: response }],
        ));

      it('will flash a success message', () =>
        actions
          .receiveUpdateStageSuccess(
            {
              dispatch: () => {},
              commit: () => {},
            },
            response,
          )
          .then(() => {
            shouldFlashAMessage('Stage data updated');
          }));

      describe('with an error', () => {
        it('will flash an error message', () =>
          actions
            .receiveUpdateStageSuccess(
              {
                dispatch: () => Promise.reject(),
                commit: () => {},
              },
              response,
            )
            .then(() => {
              shouldFlashAMessage('There was a problem refreshing the data, please try again');
            }));
      });
    });
  });

  describe('removeStage', () => {
    const stageId = 'cool-stage';

    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
      mock.onDelete(stageEndpoint({ stageId })).replyOnce(200);
      state = { selectedGroup };
    });

    it('dispatches receiveRemoveStageSuccess with put request response data', done => {
      testAction(
        actions.removeStage,
        stageId,
        state,
        [],
        [
          { type: 'requestRemoveStage' },
          {
            type: 'receiveRemoveStageSuccess',
          },
        ],
        done,
      );
    });

    describe('with a failed request', () => {
      beforeEach(() => {
        mock = new MockAdapter(axios);
        mock.onDelete(stageEndpoint({ stageId })).replyOnce(httpStatusCodes.NOT_FOUND);
      });

      it('dispatches receiveRemoveStageError', done => {
        testAction(
          actions.removeStage,
          stageId,
          state,
          [],
          [
            { type: 'requestRemoveStage' },
            {
              type: 'receiveRemoveStageError',
              payload: error,
            },
          ],
          done,
        );
      });

      it('flashes an error message', done => {
        actions.receiveRemoveStageError(
          {
            commit: () => {},
            state,
          },
          {},
        );

        shouldFlashAMessage('There was an error removing your custom stage, please try again');
        done();
      });
    });
  });

  describe('receiveRemoveStageSuccess', () => {
    const stageId = 'cool-stage';

    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
      mock.onDelete(stageEndpoint({ stageId })).replyOnce(200);
      state = { selectedGroup };
    });

    it('dispatches fetchCycleAnalyticsData', done => {
      testAction(
        actions.receiveRemoveStageSuccess,
        stageId,
        state,
        [{ type: 'RECEIVE_REMOVE_STAGE_RESPONSE' }],
        [{ type: 'fetchCycleAnalyticsData' }],
        done,
      );
    });

    it('flashes a success message', done => {
      actions.receiveRemoveStageSuccess(
        {
          dispatch: () => {},
          commit: () => {},
          state,
        },
        {},
      );

      shouldFlashAMessage('Stage removed');
      done();
    });
  });

  describe('fetchDurationData', () => {
    beforeEach(() => {
      mock.onGet(endpoints.durationData).reply(200, [...rawDurationData]);
    });

    it("dispatches the 'receiveDurationDataSuccess' action on success", done => {
      const stateWithStages = {
        ...state,
        stages: [stages[0], stages[1]],
        selectedGroup,
      };
      const dispatch = jest.fn();

      actions
        .fetchDurationData({
          dispatch,
          state: stateWithStages,
          getters,
        })
        .then(() => {
          expect(dispatch).toHaveBeenCalledWith(
            'receiveDurationDataSuccess',
            transformedDurationData,
          );
          done();
        })
        .catch(done.fail);
    });

    it("dispatches the 'requestDurationData' action", done => {
      const stateWithStages = {
        ...state,
        stages: [stages[0], stages[1]],
        selectedGroup,
      };
      const dispatch = jest.fn();

      actions
        .fetchDurationData({
          dispatch,
          state: stateWithStages,
          getters,
        })
        .then(() => {
          expect(dispatch).toHaveBeenNthCalledWith(1, 'requestDurationData');
          done();
        })
        .catch(done.fail);
    });

    it("dispatches the 'receiveDurationDataError' action when there is an error", done => {
      const brokenState = {
        ...state,
        stages: [
          {
            id: 'oops',
          },
        ],
        selectedGroup,
      };
      const dispatch = jest.fn();

      actions
        .fetchDurationData({
          dispatch,
          state: brokenState,
          getters,
        })
        .then(() => {
          expect(dispatch).toHaveBeenCalledWith('receiveDurationDataError');
          done();
        })
        .catch(done.fail);
    });
  });

  describe('receiveDurationDataSuccess', () => {
    describe('with hasDurationChartMedian feature flag enabled', () => {
      it('commits the transformed duration data and dispatches fetchDurationMedianData', () => {
        testAction(
          actions.receiveDurationDataSuccess,
          transformedDurationData,
          state,
          [
            {
              type: types.RECEIVE_DURATION_DATA_SUCCESS,
              payload: transformedDurationData,
            },
          ],
          [
            {
              type: 'fetchDurationMedianData',
            },
          ],
        );
      });
    });

    describe('with hasDurationChartMedian feature flag disabled', () => {
      const disabledState = {
        ...state,
        featureFlags: {
          hasDurationChartMedian: false,
        },
      };

      it('commits the transformed duration data', () => {
        testAction(
          actions.receiveDurationDataSuccess,
          transformedDurationData,
          disabledState,
          [
            {
              type: types.RECEIVE_DURATION_DATA_SUCCESS,
              payload: transformedDurationData,
            },
          ],
          [],
        );
      });
    });
  });

  describe('receiveDurationDataError', () => {
    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });

    it("commits the 'RECEIVE_DURATION_DATA_ERROR' mutation", () => {
      testAction(
        actions.receiveDurationDataError,
        {},
        state,
        [
          {
            type: types.RECEIVE_DURATION_DATA_ERROR,
          },
        ],
        [],
      );
    });

    it('will flash an error', () => {
      actions.receiveDurationDataError({
        commit: () => {},
      });

      shouldFlashAMessage(
        'There was an error while fetching value stream analytics duration data.',
      );
    });
  });

  describe('updateSelectedDurationChartStages', () => {
    it("commits the 'UPDATE_SELECTED_DURATION_CHART_STAGES' mutation with all the selected stages in the duration data", () => {
      const stateWithDurationData = {
        ...state,
        durationData: transformedDurationData,
        durationMedianData: transformedDurationMedianData,
      };

      testAction(
        actions.updateSelectedDurationChartStages,
        [...stages],
        stateWithDurationData,
        [
          {
            type: types.UPDATE_SELECTED_DURATION_CHART_STAGES,
            payload: {
              updatedDurationStageData: transformedDurationData,
              updatedDurationStageMedianData: transformedDurationMedianData,
            },
          },
        ],
        [],
      );
    });

    it("commits the 'UPDATE_SELECTED_DURATION_CHART_STAGES' mutation with all the selected and deselected stages in the duration data", () => {
      const stateWithDurationData = {
        ...state,
        durationData: transformedDurationData,
        durationMedianData: transformedDurationMedianData,
      };

      testAction(
        actions.updateSelectedDurationChartStages,
        [stages[0]],
        stateWithDurationData,
        [
          {
            type: types.UPDATE_SELECTED_DURATION_CHART_STAGES,
            payload: {
              updatedDurationStageData: [
                transformedDurationData[0],
                {
                  ...transformedDurationData[1],
                  selected: false,
                },
              ],
              updatedDurationStageMedianData: [
                transformedDurationMedianData[0],
                {
                  ...transformedDurationMedianData[1],
                  selected: false,
                },
              ],
            },
          },
        ],
        [],
      );
    });

    it("commits the 'UPDATE_SELECTED_DURATION_CHART_STAGES' mutation with all deselected stages in the duration data", () => {
      const stateWithDurationData = {
        ...state,
        durationData: transformedDurationData,
        durationMedianData: transformedDurationMedianData,
      };

      testAction(
        actions.updateSelectedDurationChartStages,
        [],
        stateWithDurationData,
        [
          {
            type: types.UPDATE_SELECTED_DURATION_CHART_STAGES,
            payload: {
              updatedDurationStageData: [
                {
                  ...transformedDurationData[0],
                  selected: false,
                },
                {
                  ...transformedDurationData[1],
                  selected: false,
                },
              ],
              updatedDurationStageMedianData: [
                {
                  ...transformedDurationMedianData[0],
                  selected: false,
                },
                {
                  ...transformedDurationMedianData[1],
                  selected: false,
                },
              ],
            },
          },
        ],
        [],
      );
    });
  });

  describe('fetchDurationMedianData', () => {
    beforeEach(() => {
      mock.onGet(endpoints.durationData).reply(200, [...rawDurationMedianData]);
    });

    it('dispatches requestDurationMedianData when called', done => {
      const stateWithStages = {
        ...state,
        stages: [stages[0], stages[1]],
        selectedGroup,
      };
      const dispatch = jest.fn();

      actions
        .fetchDurationMedianData({
          dispatch,
          state: stateWithStages,
        })
        .then(() => {
          expect(dispatch).toHaveBeenNthCalledWith(1, 'requestDurationMedianData');
          done();
        })
        .catch(done.fail);
    });

    it('dispatches the receiveDurationMedianDataSuccess action on success', done => {
      const stateWithStages = {
        ...state,
        stages: [stages[0], stages[1]],
        selectedGroup,
      };
      const dispatch = jest.fn();

      actions
        .fetchDurationMedianData({
          dispatch,
          state: stateWithStages,
        })
        .then(() => {
          expect(dispatch).toHaveBeenCalledWith(
            'receiveDurationMedianDataSuccess',
            transformedDurationMedianData,
          );
          done();
        })
        .catch(done.fail);
    });

    it('dispatches the receiveDurationMedianDataError action when there is an error', done => {
      const brokenState = {
        ...state,
        stages: [
          {
            id: 'oops',
          },
        ],
        selectedGroup,
      };
      const dispatch = jest.fn();

      actions
        .fetchDurationMedianData({
          dispatch,
          state: brokenState,
        })
        .then(() => {
          expect(dispatch).toHaveBeenCalledWith('receiveDurationMedianDataError');
          done();
        })
        .catch(done.fail);
    });
  });

  describe('receiveDurationMedianDataSuccess', () => {
    it('commits the transformed duration median data', done => {
      testAction(
        actions.receiveDurationMedianDataSuccess,
        transformedDurationMedianData,
        state,
        [
          {
            type: types.RECEIVE_DURATION_MEDIAN_DATA_SUCCESS,
            payload: transformedDurationMedianData,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveDurationMedianDataError', () => {
    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });

    it("commits the 'RECEIVE_DURATION_MEDIAN_DATA_ERROR' mutation", () => {
      testAction(
        actions.receiveDurationMedianDataError,
        {},
        state,
        [
          {
            type: types.RECEIVE_DURATION_MEDIAN_DATA_ERROR,
          },
        ],
        [],
      );
    });

    it('will flash an error', () => {
      actions.receiveDurationMedianDataError({
        commit: () => {},
      });

      shouldFlashAMessage(
        'There was an error while fetching value stream analytics duration median data.',
      );
    });
  });

  describe('fetchStageMedianValues', () => {
    let mockDispatch = jest.fn();
    beforeEach(() => {
      state = { ...state, stages: [{ slug: selectedStageSlug }], selectedGroup };
      mock = new MockAdapter(axios);
      mock.onGet(endpoints.stageMedian).reply(200, { events: [] });
      mockDispatch = jest.fn();
    });

    it('dispatches receiveStageMedianValuesSuccess with received data on success', done => {
      actions
        .fetchStageMedianValues({
          state,
          getters,
          commit: () => {},
          dispatch: mockDispatch,
        })
        .then(() => {
          expect(mockDispatch).toHaveBeenCalledWith('requestStageMedianValues');
          expect(mockDispatch).toHaveBeenCalledWith('receiveStageMedianValuesSuccess', [
            { events: [], id: selectedStageSlug },
          ]);
          done();
        })
        .catch(done.fail);
    });

    describe('with a failing request', () => {
      beforeEach(() => {
        mock.onGet(endpoints.stageMedian).reply(httpStatusCodes.NOT_FOUND, { error });
      });

      it('will dispatch receiveStageMedianValuesError', done => {
        actions
          .fetchStageMedianValues({
            state,
            getters,
            commit: () => {},
            dispatch: mockDispatch,
          })
          .then(() => {
            expect(mockDispatch).toHaveBeenCalledWith('requestStageMedianValues');
            expect(mockDispatch).toHaveBeenCalledWith('receiveStageMedianValuesError', error);
            done();
          })
          .catch(done.fail);
      });
    });
  });

  describe('receiveStageMedianValuesError', () => {
    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });

    it(`commits the ${types.RECEIVE_STAGE_MEDIANS_ERROR} mutation`, done => {
      testAction(
        actions.receiveStageMedianValuesError,
        null,
        state,
        [
          {
            type: types.RECEIVE_STAGE_MEDIANS_ERROR,
          },
        ],
        [],
        done,
      );
    });

    it('will flash an error message', () => {
      actions.receiveStageMedianValuesError({
        commit: () => {},
      });

      shouldFlashAMessage('There was an error fetching median data for stages');
    });
  });

  describe('receiveStageMedianValuesSuccess', () => {
    it(`commits the ${types.RECEIVE_STAGE_MEDIANS_SUCCESS} mutation`, done => {
      testAction(
        actions.receiveStageMedianValuesSuccess,
        { ...stageData },
        state,
        [{ type: types.RECEIVE_STAGE_MEDIANS_SUCCESS, payload: { events: [] } }],
        [],
        done,
      );
    });
  });

  describe('setTasksByTypeFilters', () => {
    const filter = TASKS_BY_TYPE_FILTERS.SUBJECT;
    const value = 'issue';

    it(`commits the ${types.SET_TASKS_BY_TYPE_FILTERS} mutation and dispatches 'fetchTasksByTypeData'`, done => {
      testAction(
        actions.setTasksByTypeFilters,
        { filter, value },
        {},
        [
          {
            type: types.SET_TASKS_BY_TYPE_FILTERS,
            payload: { filter, value },
          },
        ],
        [
          {
            type: 'fetchTasksByTypeData',
          },
        ],
        done,
      );
    });
  });

  describe('createCustomStage', () => {
    describe('with valid data', () => {
      const customStageData = {
        startEventIdentifier: 'start_event',
        endEventIdentifier: 'end_event',
        name: 'cool-new-stage',
      };

      beforeEach(() => {
        state = { ...state, selectedGroup };
        mock.onPost(endpoints.baseStagesEndpointstageData).reply(201, customStageData);
      });

      it(`dispatches the 'receiveCreateCustomStageSuccess' action`, () =>
        testAction(
          actions.createCustomStage,
          customStageData,
          state,
          [],
          [
            { type: 'requestCreateCustomStage' },
            {
              type: 'receiveCreateCustomStageSuccess',
              payload: { data: customStageData, status: 201 },
            },
          ],
        ));
    });

    describe('with errors', () => {
      const message = 'failed';
      const errors = {
        endEventIdentifier: ['Cant be blank'],
      };
      const customStageData = {
        startEventIdentifier: 'start_event',
        endEventIdentifier: '',
        name: 'cool-new-stage',
      };

      beforeEach(() => {
        state = { ...state, selectedGroup };
        mock
          .onPost(endpoints.baseStagesEndpointstageData)
          .reply(httpStatusCodes.UNPROCESSABLE_ENTITY, {
            message,
            errors,
          });
      });

      it(`dispatches the 'receiveCreateCustomStageError' action`, () =>
        testAction(
          actions.createCustomStage,
          customStageData,
          state,
          [],
          [
            { type: 'requestCreateCustomStage' },
            {
              type: 'receiveCreateCustomStageError',
              payload: {
                data: customStageData,
                errors,
                message,
                status: httpStatusCodes.UNPROCESSABLE_ENTITY,
              },
            },
          ],
        ));
    });
  });

  describe('receiveCreateCustomStageError', () => {
    const response = {
      data: { name: 'uh oh' },
    };

    beforeEach(() => {
      setFixtures('<div class="flash-container"></div>');
    });

    it('will commit the RECEIVE_CREATE_CUSTOM_STAGE_ERROR mutation', () =>
      testAction(actions.receiveCreateCustomStageError, response, state, [
        { type: types.RECEIVE_CREATE_CUSTOM_STAGE_ERROR, payload: { errors: {} } },
      ]));

    it('will flash an error message', done => {
      actions.receiveCreateCustomStageError(
        {
          commit: () => {},
        },
        response,
      );

      shouldFlashAMessage('There was a problem saving your custom stage, please try again');
      done();
    });

    describe('with a stage name error', () => {
      it('will flash an error message', done => {
        actions.receiveCreateCustomStageError(
          {
            commit: () => {},
          },
          {
            ...response,
            status: httpStatusCodes.UNPROCESSABLE_ENTITY,
            errors: { name: ['is reserved'] },
          },
        );

        shouldFlashAMessage("'uh oh' stage already exists");
        done();
      });
    });
  });

  describe('initializeCycleAnalytics', () => {
    let mockDispatch;
    let mockCommit;
    let store;

    const initialData = {
      group: selectedGroup,
      projectIds: [1, 2],
    };

    beforeEach(() => {
      mockDispatch = jest.fn(() => Promise.resolve());
      mockCommit = jest.fn();
      store = {
        state,
        getters,
        commit: mockCommit,
        dispatch: mockDispatch,
      };
    });

    describe('with no initialData', () => {
      it('commits "INITIALIZE_CYCLE_ANALYTICS"', () =>
        actions.initializeCycleAnalytics(store).then(() => {
          expect(mockCommit).toHaveBeenCalledWith('INITIALIZE_CYCLE_ANALYTICS', {});
        }));

      it('dispatches "initializeCycleAnalyticsSuccess"', () =>
        actions.initializeCycleAnalytics(store).then(() => {
          expect(mockDispatch).not.toHaveBeenCalledWith('fetchCycleAnalyticsData');
          expect(mockDispatch).toHaveBeenCalledWith('initializeCycleAnalyticsSuccess');
        }));
    });

    describe('with initialData', () => {
      it('dispatches "fetchCycleAnalyticsData" and "initializeCycleAnalyticsSuccess"', () =>
        actions.initializeCycleAnalytics(store, initialData).then(() => {
          expect(mockDispatch).toHaveBeenCalledWith('fetchCycleAnalyticsData');
          expect(mockDispatch).toHaveBeenCalledWith('initializeCycleAnalyticsSuccess');
        }));

      it('commits "INITIALIZE_CYCLE_ANALYTICS"', () =>
        actions.initializeCycleAnalytics(store, initialData).then(() => {
          expect(mockCommit).toHaveBeenCalledWith('INITIALIZE_CYCLE_ANALYTICS', initialData);
        }));
    });
  });

  describe('initializeCycleAnalyticsSuccess', () => {
    it(`commits the ${types.INITIALIZE_CYCLE_ANALYTICS_SUCCESS} mutation`, () =>
      testAction(
        actions.initializeCycleAnalyticsSuccess,
        null,
        state,
        [{ type: types.INITIALIZE_CYCLE_ANALYTICS_SUCCESS }],
        [],
      ));
  });

  describe('receiveCreateCustomStageSuccess', () => {
    const response = {
      data: {
        title: 'COOL',
      },
    };

    it('will dispatch fetchGroupStagesAndEvents and fetchSummaryData', () =>
      testAction(
        actions.receiveCreateCustomStageSuccess,
        response,
        state,
        [{ type: types.RECEIVE_CREATE_CUSTOM_STAGE_SUCCESS }],
        [{ type: 'fetchGroupStagesAndEvents' }, { type: 'fetchSummaryData' }],
      ));

    describe('with an error', () => {
      beforeEach(() => {
        setFixtures('<div class="flash-container"></div>');
      });

      it('will flash an error message', () =>
        actions
          .receiveCreateCustomStageSuccess(
            {
              dispatch: () => Promise.reject(),
              commit: () => {},
            },
            response,
          )
          .then(() => {
            shouldFlashAMessage('There was a problem refreshing the data, please try again');
          }));
    });
  });
});
