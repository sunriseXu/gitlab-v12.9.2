import MockAdapter from 'axios-mock-adapter';
import * as actions from 'ee/vue_shared/license_management/store/actions';
import * as mutationTypes from 'ee/vue_shared/license_management/store/mutation_types';
import createState from 'ee/vue_shared/license_management/store/state';
import { LICENSE_APPROVAL_STATUS } from 'ee/vue_shared/license_management/constants';
import { TEST_HOST } from 'spec/test_constants';
import testAction from 'helpers/vuex_action_helper';
import { approvedLicense, blacklistedLicense } from '../mock_data';
import axios from '~/lib/utils/axios_utils';

describe('License store actions', () => {
  const apiUrlManageLicenses = `${TEST_HOST}/licenses/management`;
  const licensesApiPath = `${TEST_HOST}/licensesApiPath`;

  let axiosMock;
  let licenseId;
  let state;
  let mockDispatch;
  let mockCommit;
  let store;

  const expectDispatched = (...args) => expect(mockDispatch).toHaveBeenCalledWith(...args);

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    state = {
      ...createState(),
      apiUrlManageLicenses,
      currentLicenseInModal: approvedLicense,
    };
    licenseId = approvedLicense.id;
    mockDispatch = jest.fn(() => Promise.resolve());
    mockCommit = jest.fn();
    store = {
      state,
      commit: mockCommit,
      dispatch: mockDispatch,
    };
  });

  afterEach(() => {
    axiosMock.restore();
  });

  describe('setAPISettings', () => {
    it('commits SET_API_SETTINGS', done => {
      const payload = { apiUrlManageLicenses };
      testAction(
        actions.setAPISettings,
        payload,
        state,
        [{ type: mutationTypes.SET_API_SETTINGS, payload }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('setLicenseInModal', () => {
    it('commits SET_LICENSE_IN_MODAL with license', done => {
      testAction(
        actions.setLicenseInModal,
        approvedLicense,
        state,
        [{ type: mutationTypes.SET_LICENSE_IN_MODAL, payload: approvedLicense }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('setIsAdmin', () => {
    it('commits SET_IS_ADMIN', done => {
      testAction(
        actions.setIsAdmin,
        false,
        state,
        [{ type: mutationTypes.SET_IS_ADMIN, payload: false }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('resetLicenseInModal', () => {
    it('commits RESET_LICENSE_IN_MODAL', done => {
      testAction(
        actions.resetLicenseInModal,
        null,
        state,
        [{ type: mutationTypes.RESET_LICENSE_IN_MODAL }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('requestDeleteLicense', () => {
    it('commits REQUEST_DELETE_LICENSE', done => {
      testAction(
        actions.requestDeleteLicense,
        null,
        state,
        [{ type: mutationTypes.REQUEST_DELETE_LICENSE }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('receiveDeleteLicense', () => {
    it('commits RECEIVE_DELETE_LICENSE and dispatches fetchManagedLicenses and removePendingLicense', () => {
      return actions.receiveDeleteLicense(store, licenseId).then(() => {
        expect(mockCommit).toHaveBeenCalledWith(mutationTypes.RECEIVE_DELETE_LICENSE);
        expectDispatched('fetchManagedLicenses');
        expectDispatched('removePendingLicense', licenseId);
      });
    });
  });

  describe('receiveDeleteLicenseError', () => {
    it('commits RECEIVE_DELETE_LICENSE_ERROR', done => {
      const error = new Error('Test');
      testAction(
        actions.receiveDeleteLicenseError,
        error,
        state,
        [{ type: mutationTypes.RECEIVE_DELETE_LICENSE_ERROR, payload: error }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('deleteLicense', () => {
    let endpointMock;
    let deleteUrl;

    beforeEach(() => {
      deleteUrl = `${apiUrlManageLicenses}/${licenseId}`;
      endpointMock = axiosMock.onDelete(deleteUrl);
    });

    it('dispatches requestDeleteLicense, addPendingLicense and receiveDeleteLicense for successful response', () => {
      endpointMock.replyOnce(req => {
        expect(req.url).toBe(deleteUrl);
        return [200, ''];
      });

      return actions.deleteLicense(store).then(() => {
        expectDispatched('requestDeleteLicense');
        expectDispatched('addPendingLicense', licenseId);
        expectDispatched('receiveDeleteLicense', licenseId);
      });
    });

    it('dispatches requestDeleteLicense, addPendingLicense, receiveDeleteLicenseError and removePendingLicense for error response', () => {
      endpointMock.replyOnce(req => {
        expect(req.url).toBe(deleteUrl);
        return [500, ''];
      });

      return actions.deleteLicense(store).then(() => {
        expectDispatched('requestDeleteLicense');
        expectDispatched('addPendingLicense', licenseId);
        expectDispatched('receiveDeleteLicenseError', expect.any(Error));
        expectDispatched('removePendingLicense', licenseId);
      });
    });
  });

  describe('requestSetLicenseApproval', () => {
    it('commits REQUEST_SET_LICENSE_APPROVAL', done => {
      testAction(
        actions.requestSetLicenseApproval,
        null,
        state,
        [{ type: mutationTypes.REQUEST_SET_LICENSE_APPROVAL }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('receiveSetLicenseApproval', () => {
    describe('given the licensesApiPath is provided', () => {
      it('commits RECEIVE_SET_LICENSE_APPROVAL and dispatches fetchParsedLicenseReport', done => {
        testAction(
          actions.receiveSetLicenseApproval,
          null,
          { ...state, licensesApiPath },
          [{ type: mutationTypes.RECEIVE_SET_LICENSE_APPROVAL }],
          [{ type: 'fetchParsedLicenseReport' }],
        )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('given the licensesApiPath is not provided', () => {
      it('commits RECEIVE_SET_LICENSE_APPROVAL and dispatches fetchManagedLicenses and removePendingLicense', () => {
        return actions.receiveSetLicenseApproval(store, licenseId).then(() => {
          expect(mockCommit).toHaveBeenCalledWith(mutationTypes.RECEIVE_SET_LICENSE_APPROVAL);
          expectDispatched('fetchManagedLicenses');
          expectDispatched('removePendingLicense', licenseId);
        });
      });
    });
  });

  describe('receiveSetLicenseApprovalError', () => {
    it('commits RECEIVE_SET_LICENSE_APPROVAL_ERROR', done => {
      const error = new Error('Test');
      testAction(
        actions.receiveSetLicenseApprovalError,
        error,
        state,
        [{ type: mutationTypes.RECEIVE_SET_LICENSE_APPROVAL_ERROR, payload: error }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('setLicenseApproval', () => {
    const newStatus = 'FAKE_STATUS';

    describe('uses POST endpoint for existing licenses;', () => {
      let putEndpointMock;
      let newLicense;

      beforeEach(() => {
        newLicense = { name: 'FOO LICENSE' };
        putEndpointMock = axiosMock.onPost(apiUrlManageLicenses);
      });

      it('dispatches requestSetLicenseApproval, addPendingLicense and receiveSetLicenseApproval for successful response', () => {
        putEndpointMock.replyOnce(req => {
          const { approval_status, name } = JSON.parse(req.data);

          expect(req.url).toBe(apiUrlManageLicenses);
          expect(approval_status).toBe(newStatus);
          expect(name).toBe(name);
          return [200, ''];
        });

        return actions.setLicenseApproval(store, { license: newLicense, newStatus }).then(() => {
          expectDispatched('requestSetLicenseApproval');
          expectDispatched('addPendingLicense', undefined);
          expectDispatched('receiveSetLicenseApproval', undefined);
        });
      });

      it('dispatches requestSetLicenseApproval, addPendingLicense, receiveSetLicenseApprovalError and removePendingLicense for error response', () => {
        putEndpointMock.replyOnce(req => {
          expect(req.url).toBe(apiUrlManageLicenses);
          return [500, ''];
        });

        return actions.setLicenseApproval(store, { license: newLicense, newStatus }).then(() => {
          expectDispatched('requestSetLicenseApproval');
          expectDispatched('addPendingLicense', undefined);
          expectDispatched('receiveSetLicenseApprovalError', expect.any(Error));
          expectDispatched('removePendingLicense', undefined);
        });
      });
    });

    describe('uses PATCH endpoint for existing licenses;', () => {
      let patchEndpointMock;
      let licenseUrl;

      beforeEach(() => {
        licenseUrl = `${apiUrlManageLicenses}/${licenseId}`;
        patchEndpointMock = axiosMock.onPatch(licenseUrl);
      });

      it('dispatches requestSetLicenseApproval, addPendingLicense and receiveSetLicenseApproval for successful response', () => {
        patchEndpointMock.replyOnce(req => {
          expect(req.url).toBe(licenseUrl);
          const { approval_status, name } = JSON.parse(req.data);

          expect(approval_status).toBe(newStatus);
          expect(name).toBeUndefined();
          return [200, ''];
        });

        return actions
          .setLicenseApproval(store, { license: approvedLicense, newStatus })
          .then(() => {
            expectDispatched('requestSetLicenseApproval');
            expectDispatched('addPendingLicense', approvedLicense.id);
            expectDispatched('receiveSetLicenseApproval', approvedLicense.id);
          });
      });

      it('dispatches requestSetLicenseApproval, addPendingLicense, receiveSetLicenseApprovalError and removePendingLicense for error response', () => {
        patchEndpointMock.replyOnce(req => {
          expect(req.url).toBe(licenseUrl);
          return [500, ''];
        });

        return actions
          .setLicenseApproval(store, { license: approvedLicense, newStatus })
          .then(() => {
            expectDispatched('requestSetLicenseApproval');
            expectDispatched('addPendingLicense', approvedLicense.id);
            expectDispatched('receiveSetLicenseApprovalError', expect.any(Error));
            expectDispatched('removePendingLicense', approvedLicense.id);
          });
      });
    });
  });

  describe('allowLicense', () => {
    const newStatus = LICENSE_APPROVAL_STATUS.ALLOWED;

    it('dispatches setLicenseApproval for un-approved licenses', done => {
      const license = { name: 'FOO' };

      testAction(
        actions.allowLicense,
        license,
        state,
        [],
        [{ type: 'setLicenseApproval', payload: { license, newStatus } }],
      )
        .then(done)
        .catch(done.fail);
    });

    it('dispatches setLicenseApproval for blacklisted licenses', done => {
      const license = blacklistedLicense;

      testAction(
        actions.allowLicense,
        license,
        state,
        [],
        [{ type: 'setLicenseApproval', payload: { license, newStatus } }],
      )
        .then(done)
        .catch(done.fail);
    });

    it('does not dispatch setLicenseApproval for approved licenses', done => {
      testAction(actions.allowLicense, approvedLicense, state, [], [])
        .then(done)
        .catch(done.fail);
    });
  });

  describe('denyLicense', () => {
    const newStatus = LICENSE_APPROVAL_STATUS.DENIED;

    it('dispatches setLicenseApproval for un-approved licenses', done => {
      const license = { name: 'FOO' };

      testAction(
        actions.denyLicense,
        license,
        state,
        [],
        [{ type: 'setLicenseApproval', payload: { license, newStatus } }],
      )
        .then(done)
        .catch(done.fail);
    });

    it('dispatches setLicenseApproval for approved licenses', done => {
      const license = approvedLicense;

      testAction(
        actions.denyLicense,
        license,
        state,
        [],
        [{ type: 'setLicenseApproval', payload: { license, newStatus } }],
      )
        .then(done)
        .catch(done.fail);
    });

    it('does not dispatch setLicenseApproval for blacklisted licenses', done => {
      testAction(actions.denyLicense, blacklistedLicense, state, [], [])
        .then(done)
        .catch(done.fail);
    });
  });

  describe('requestManagedLicenses', () => {
    it('commits REQUEST_MANAGED_LICENSES', done => {
      testAction(
        actions.requestManagedLicenses,
        null,
        state,
        [{ type: mutationTypes.REQUEST_MANAGED_LICENSES }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('receiveManagedLicensesSuccess', () => {
    it('commits RECEIVE_MANAGED_LICENSES_SUCCESS', done => {
      const payload = [approvedLicense];
      testAction(
        actions.receiveManagedLicensesSuccess,
        payload,
        state,
        [{ type: mutationTypes.RECEIVE_MANAGED_LICENSES_SUCCESS, payload }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('receiveManagedLicensesError', () => {
    it('commits RECEIVE_MANAGED_LICENSES_ERROR', done => {
      const error = new Error('Test');
      testAction(
        actions.receiveManagedLicensesError,
        error,
        state,
        [{ type: mutationTypes.RECEIVE_MANAGED_LICENSES_ERROR, payload: error }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('fetchManagedLicenses', () => {
    let endpointMock;

    beforeEach(() => {
      endpointMock = axiosMock.onGet(apiUrlManageLicenses, { params: { per_page: 100 } });
    });

    it('dispatches requestManagedLicenses and receiveManagedLicensesSuccess for successful response', done => {
      const payload = [{ name: 'foo', approval_status: LICENSE_APPROVAL_STATUS.DENIED }];
      endpointMock.replyOnce(() => [200, payload]);

      testAction(
        actions.fetchManagedLicenses,
        null,
        state,
        [],
        [{ type: 'requestManagedLicenses' }, { type: 'receiveManagedLicensesSuccess', payload }],
      )
        .then(done)
        .catch(done.fail);
    });

    it('dispatches requestManagedLicenses and receiveManagedLicensesError for error response', done => {
      endpointMock.replyOnce(() => [500, '']);

      testAction(
        actions.fetchManagedLicenses,
        null,
        state,
        [],
        [
          { type: 'requestManagedLicenses' },
          { type: 'receiveManagedLicensesError', payload: expect.any(Error) },
        ],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('requestParsedLicenseReport', () => {
    it(`should commit ${mutationTypes.REQUEST_PARSED_LICENSE_REPORT}`, done => {
      testAction(
        actions.requestParsedLicenseReport,
        null,
        state,
        [{ type: mutationTypes.REQUEST_PARSED_LICENSE_REPORT }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('receiveParsedLicenseReportSuccess', () => {
    it(`should commit ${mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS} with the correct payload`, done => {
      const payload = { newLicenses: [{ name: 'foo' }] };

      testAction(
        actions.receiveParsedLicenseReportSuccess,
        payload,
        state,
        [{ type: mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_SUCCESS, payload }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('receiveParsedLicenseReportError', () => {
    it(`should commit ${mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_ERROR}`, done => {
      const payload = new Error('Test');

      testAction(
        actions.receiveParsedLicenseReportError,
        payload,
        state,
        [{ type: mutationTypes.RECEIVE_PARSED_LICENSE_REPORT_ERROR, payload }],
        [],
      )
        .then(done)
        .catch(done.fail);
    });
  });

  describe('fetchParsedLicenseReport', () => {
    let licensesApiMock;
    let rawLicenseReport;

    beforeEach(() => {
      licensesApiMock = axiosMock.onGet(licensesApiPath);
      state = {
        ...createState(),
        licensesApiPath,
      };
    });

    describe('pipeline reports', () => {
      beforeEach(() => {
        rawLicenseReport = [
          {
            name: 'MIT',
            classification: { id: 2, approval_status: 'blacklisted', name: 'MIT' },
            dependencies: [{ name: 'vue' }],
            count: 1,
            url: 'http://opensource.org/licenses/mit-license',
          },
        ];
      });

      it('should fetch, parse, and dispatch the new licenses on a successful request', done => {
        licensesApiMock.replyOnce(() => [200, rawLicenseReport]);

        const parsedLicenses = {
          existingLicenses: [],
          newLicenses: [
            {
              ...rawLicenseReport[0],
              id: 2,
              approvalStatus: 'blacklisted',
              packages: [{ name: 'vue' }],
              status: 'failed',
            },
          ],
        };

        testAction(
          actions.fetchParsedLicenseReport,
          null,
          state,
          [],
          [
            { type: 'requestParsedLicenseReport' },
            { type: 'receiveParsedLicenseReportSuccess', payload: parsedLicenses },
          ],
        )
          .then(done)
          .catch(done.fail);
      });

      it('should send an error on an unsuccesful request', done => {
        licensesApiMock.replyOnce(400);

        testAction(
          actions.fetchParsedLicenseReport,
          null,
          state,
          [],
          [
            { type: 'requestParsedLicenseReport' },
            { type: 'receiveParsedLicenseReportError', payload: expect.any(Error) },
          ],
        )
          .then(done)
          .catch(done.fail);
      });
    });

    describe('MR widget reports', () => {
      beforeEach(() => {
        rawLicenseReport = {
          new_licenses: [
            {
              name: 'Apache 2.0',
              classification: { id: 1, approval_status: 'approved', name: 'Apache 2.0' },
              dependencies: [{ name: 'echarts' }],
              count: 1,
              url: 'http://www.apache.org/licenses/LICENSE-2.0.txt',
            },
            {
              name: 'New BSD',
              classification: { id: 3, approval_status: 'unclassified', name: 'New BSD' },
              dependencies: [{ name: 'zrender' }],
              count: 1,
              url: 'http://opensource.org/licenses/BSD-3-Clause',
            },
          ],
          existing_licenses: [
            {
              name: 'MIT',
              classification: { id: 2, approval_status: 'blacklisted', name: 'MIT' },
              dependencies: [{ name: 'vue' }],
              count: 1,
              url: 'http://opensource.org/licenses/mit-license',
            },
          ],
          removed_licenses: [],
        };
      });

      it('should fetch, parse, and dispatch the new licenses on a successful request', done => {
        licensesApiMock.replyOnce(() => [200, rawLicenseReport]);

        const parsedLicenses = {
          existingLicenses: [
            {
              ...rawLicenseReport.existing_licenses[0],
              id: 2,
              approvalStatus: 'blacklisted',
              packages: [{ name: 'vue' }],
              status: 'failed',
            },
          ],
          newLicenses: [
            {
              ...rawLicenseReport.new_licenses[0],
              id: 1,
              approvalStatus: 'approved',
              packages: [{ name: 'echarts' }],
              status: 'success',
            },
            {
              ...rawLicenseReport.new_licenses[1],
              id: 3,
              approvalStatus: 'unclassified',
              packages: [{ name: 'zrender' }],
              status: 'neutral',
            },
          ],
        };

        testAction(
          actions.fetchParsedLicenseReport,
          null,
          state,
          [],
          [
            { type: 'requestParsedLicenseReport' },
            { type: 'receiveParsedLicenseReportSuccess', payload: parsedLicenses },
          ],
        )
          .then(done)
          .catch(done.fail);
      });
    });
  });
});
