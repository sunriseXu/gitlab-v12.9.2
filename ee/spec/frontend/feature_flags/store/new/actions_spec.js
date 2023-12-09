import MockAdapter from 'axios-mock-adapter';
import {
  setEndpoint,
  setPath,
  createFeatureFlag,
  requestCreateFeatureFlag,
  receiveCreateFeatureFlagSuccess,
  receiveCreateFeatureFlagError,
} from 'ee/feature_flags/store/modules/new/actions';
import state from 'ee/feature_flags/store/modules/new/state';
import * as types from 'ee/feature_flags/store/modules/new/mutation_types';
import testAction from 'helpers/vuex_action_helper';
import { TEST_HOST } from 'spec/test_constants';
import {
  ROLLOUT_STRATEGY_ALL_USERS,
  ROLLOUT_STRATEGY_PERCENT_ROLLOUT,
} from 'ee/feature_flags/constants';
import { mapFromScopesViewModel } from 'ee/feature_flags/store/modules/helpers';
import axios from '~/lib/utils/axios_utils';

jest.mock('~/lib/utils/url_utility');

describe('Feature flags New Module Actions', () => {
  let mockedState;

  beforeEach(() => {
    mockedState = state();
  });

  describe('setEndpoint', () => {
    it('should commit SET_ENDPOINT mutation', done => {
      testAction(
        setEndpoint,
        'feature_flags.json',
        mockedState,
        [{ type: types.SET_ENDPOINT, payload: 'feature_flags.json' }],
        [],
        done,
      );
    });
  });

  describe('setPath', () => {
    it('should commit SET_PATH mutation', done => {
      testAction(
        setPath,
        '/feature_flags',
        mockedState,
        [{ type: types.SET_PATH, payload: '/feature_flags' }],
        [],
        done,
      );
    });
  });

  describe('createFeatureFlag', () => {
    let mock;

    const actionParams = {
      name: 'name',
      description: 'description',
      active: true,
      scopes: [
        {
          id: 1,
          environmentScope: 'environmentScope',
          active: true,
          canUpdate: true,
          protected: true,
          shouldBeDestroyed: false,
          rolloutStrategy: ROLLOUT_STRATEGY_ALL_USERS,
          rolloutPercentage: ROLLOUT_STRATEGY_PERCENT_ROLLOUT,
        },
      ],
    };

    beforeEach(() => {
      mockedState.endpoint = `${TEST_HOST}/endpoint.json`;
      mock = new MockAdapter(axios);
    });

    afterEach(() => {
      mock.restore();
    });

    describe('success', () => {
      it('dispatches requestCreateFeatureFlag and receiveCreateFeatureFlagSuccess ', done => {
        const convertedActionParams = mapFromScopesViewModel(actionParams);

        mock.onPost(`${TEST_HOST}/endpoint.json`, convertedActionParams).replyOnce(200);

        testAction(
          createFeatureFlag,
          actionParams,
          mockedState,
          [],
          [
            {
              type: 'requestCreateFeatureFlag',
            },
            {
              type: 'receiveCreateFeatureFlagSuccess',
            },
          ],
          done,
        );
      });
    });

    describe('error', () => {
      it('dispatches requestCreateFeatureFlag and receiveCreateFeatureFlagError ', done => {
        const convertedActionParams = mapFromScopesViewModel(actionParams);

        mock
          .onPost(`${TEST_HOST}/endpoint.json`, convertedActionParams)
          .replyOnce(500, { message: [] });

        testAction(
          createFeatureFlag,
          actionParams,
          mockedState,
          [],
          [
            {
              type: 'requestCreateFeatureFlag',
            },
            {
              type: 'receiveCreateFeatureFlagError',
              payload: { message: [] },
            },
          ],
          done,
        );
      });
    });
  });

  describe('requestCreateFeatureFlag', () => {
    it('should commit REQUEST_CREATE_FEATURE_FLAG mutation', done => {
      testAction(
        requestCreateFeatureFlag,
        null,
        mockedState,
        [{ type: types.REQUEST_CREATE_FEATURE_FLAG }],
        [],
        done,
      );
    });
  });

  describe('receiveCreateFeatureFlagSuccess', () => {
    it('should commit RECEIVE_CREATE_FEATURE_FLAG_SUCCESS mutation', done => {
      testAction(
        receiveCreateFeatureFlagSuccess,
        null,
        mockedState,
        [
          {
            type: types.RECEIVE_CREATE_FEATURE_FLAG_SUCCESS,
          },
        ],
        [],
        done,
      );
    });
  });

  describe('receiveCreateFeatureFlagError', () => {
    it('should commit RECEIVE_CREATE_FEATURE_FLAG_ERROR mutation', done => {
      testAction(
        receiveCreateFeatureFlagError,
        'There was an error',
        mockedState,
        [{ type: types.RECEIVE_CREATE_FEATURE_FLAG_ERROR, payload: 'There was an error' }],
        [],
        done,
      );
    });
  });
});
