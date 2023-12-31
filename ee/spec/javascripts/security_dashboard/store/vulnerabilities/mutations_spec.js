import createState from 'ee/security_dashboard/store/modules/vulnerabilities/state';
import * as types from 'ee/security_dashboard/store/modules/vulnerabilities/mutation_types';
import mutations from 'ee/security_dashboard/store/modules/vulnerabilities/mutations';
import { DAYS } from 'ee/security_dashboard/store/modules/vulnerabilities/constants';
import mockData from './data/mock_data_vulnerabilities';

describe('vulnerabilities module mutations', () => {
  let state;

  beforeEach(() => {
    state = createState();
  });

  describe('SET_PIPELINE_ID', () => {
    const pipelineId = 123;

    it(`should set the pipelineId to ${pipelineId}`, () => {
      mutations[types.SET_PIPELINE_ID](state, pipelineId);

      expect(state.pipelineId).toBe(pipelineId);
    });
  });

  describe('SET_SOURCE_BRANCH', () => {
    const sourceBranch = 'feature-branch-1';

    it(`should set the sourceBranch to ${sourceBranch}`, () => {
      mutations[types.SET_SOURCE_BRANCH](state, sourceBranch);

      expect(state.sourceBranch).toBe(sourceBranch);
    });
  });

  describe('SET_VULNERABILITIES_ENDPOINT', () => {
    it('should set `vulnerabilitiesEndpoint` to `fakepath.json`', () => {
      const endpoint = 'fakepath.json';

      mutations[types.SET_VULNERABILITIES_ENDPOINT](state, endpoint);

      expect(state.vulnerabilitiesEndpoint).toBe(endpoint);
    });
  });

  describe('SET_VULNERABILITIES_PAGE', () => {
    const page = 3;
    it(`should set pageInfo.page to ${page}`, () => {
      mutations[types.SET_VULNERABILITIES_PAGE](state, page);

      expect(state.pageInfo.page).toBe(page);
    });
  });

  describe('REQUEST_VULNERABILITIES', () => {
    beforeEach(() => {
      state.errorLoadingVulnerabilities = true;
      state.loadingVulnerabilitiesErrorCode = 403;
      mutations[types.REQUEST_VULNERABILITIES](state);
    });

    it('should set `isLoadingVulnerabilities` to `true`', () => {
      expect(state.isLoadingVulnerabilities).toBeTruthy();
    });

    it('should set `errorLoadingVulnerabilities` to `false`', () => {
      expect(state.errorLoadingVulnerabilities).toBeFalsy();
    });

    it('should reset `loadingVulnerabilitiesErrorCode`', () => {
      expect(state.loadingVulnerabilitiesErrorCode).toBe(null);
    });
  });

  describe('RECEIVE_VULNERABILITIES_SUCCESS', () => {
    let payload;

    beforeEach(() => {
      payload = {
        vulnerabilities: mockData,
        pageInfo: { a: 1, b: 2, c: 3 },
      };
      mutations[types.RECEIVE_VULNERABILITIES_SUCCESS](state, payload);
    });

    it('should set `isLoadingVulnerabilities` to `false`', () => {
      expect(state.isLoadingVulnerabilities).toBeFalsy();
    });

    it('should set `pageInfo`', () => {
      expect(state.pageInfo).toBe(payload.pageInfo);
    });

    it('should set `vulnerabilities`', () => {
      expect(state.vulnerabilities).toBe(payload.vulnerabilities);
    });
  });

  describe('RECEIVE_VULNERABILITIES_ERROR', () => {
    const errorCode = 403;

    beforeEach(() => {
      mutations[types.RECEIVE_VULNERABILITIES_ERROR](state, errorCode);
    });

    it('should set `isLoadingVulnerabilities` to `false`', () => {
      expect(state.isLoadingVulnerabilities).toBeFalsy();
    });

    it('should set `loadingVulnerabilitiesErrorCode`', () => {
      expect(state.loadingVulnerabilitiesErrorCode).toBe(errorCode);
    });
  });

  describe('SET_VULNERABILITIES_COUNT_ENDPOINT', () => {
    it('should set `vulnerabilitiesCountEndpoint` to `fakepath.json`', () => {
      const endpoint = 'fakepath.json';

      mutations[types.SET_VULNERABILITIES_COUNT_ENDPOINT](state, endpoint);

      expect(state.vulnerabilitiesCountEndpoint).toBe(endpoint);
    });
  });

  describe('REQUEST_VULNERABILITIES_COUNT', () => {
    beforeEach(() => {
      state.errorLoadingVulnerabilitiesCount = true;
      mutations[types.REQUEST_VULNERABILITIES_COUNT](state);
    });

    it('should set `isLoadingVulnerabilitiesCount` to `true`', () => {
      expect(state.isLoadingVulnerabilitiesCount).toBeTruthy();
    });

    it('should set `errorLoadingVulnerabilitiesCount` to `false`', () => {
      expect(state.errorLoadingVulnerabilitiesCount).toBeFalsy();
    });
  });

  describe('RECEIVE_VULNERABILITIES_COUNT_SUCCESS', () => {
    let payload;

    beforeEach(() => {
      payload = mockData;
      mutations[types.RECEIVE_VULNERABILITIES_COUNT_SUCCESS](state, payload);
    });

    it('should set `isLoadingVulnerabilitiesCount` to `false`', () => {
      expect(state.isLoadingVulnerabilitiesCount).toBeFalsy();
    });

    it('should set `vulnerabilitiesCount`', () => {
      expect(state.vulnerabilitiesCount).toBe(payload);
    });
  });

  describe('RECEIVE_VULNERABILITIES_COUNT_ERROR', () => {
    it('should set `isLoadingVulnerabilitiesCount` to `false`', () => {
      mutations[types.RECEIVE_VULNERABILITIES_COUNT_ERROR](state);

      expect(state.isLoadingVulnerabilitiesCount).toBeFalsy();
    });
  });

  describe('SET_VULNERABILITIES_HISTORY_ENDPOINT', () => {
    it('should set `vulnerabilitiesHistoryEndpoint` to `fakepath.json`', () => {
      const endpoint = 'fakepath.json';

      mutations[types.SET_VULNERABILITIES_HISTORY_ENDPOINT](state, endpoint);

      expect(state.vulnerabilitiesHistoryEndpoint).toBe(endpoint);
    });
  });

  describe('REQUEST_VULNERABILITIES_HISTORY', () => {
    beforeEach(() => {
      state.errorLoadingVulnerabilitiesHistory = true;
      mutations[types.REQUEST_VULNERABILITIES_HISTORY](state);
    });

    it('should set `isLoadingVulnerabilitiesHistory` to `true`', () => {
      expect(state.isLoadingVulnerabilitiesHistory).toBeTruthy();
    });

    it('should set `errorLoadingVulnerabilitiesHistory` to `false`', () => {
      expect(state.errorLoadingVulnerabilitiesHistory).toBeFalsy();
    });
  });

  describe('RECEIVE_VULNERABILITIES_HISTORY_SUCCESS', () => {
    let payload;

    beforeEach(() => {
      payload = mockData;
      mutations[types.RECEIVE_VULNERABILITIES_HISTORY_SUCCESS](state, payload);
    });

    it('should set `isLoadingVulnerabilitiesHistory` to `false`', () => {
      expect(state.isLoadingVulnerabilitiesHistory).toBeFalsy();
    });

    it('should set `vulnerabilitiesHistory`', () => {
      expect(state.vulnerabilitiesHistory).toBe(payload);
    });
  });

  describe('RECEIVE_VULNERABILITIES_HISTORY_ERROR', () => {
    it('should set `isLoadingVulnerabilitiesHistory` to `false`', () => {
      mutations[types.RECEIVE_VULNERABILITIES_HISTORY_ERROR](state);

      expect(state.isLoadingVulnerabilitiesHistory).toBeFalsy();
    });
  });

  describe('SET_VULNERABILITIES_HISTORY_DAY_RANGE', () => {
    it('should set the vulnerabilitiesHistoryDayRange to number of days', () => {
      mutations[types.SET_VULNERABILITIES_HISTORY_DAY_RANGE](state, DAYS.THIRTY);

      expect(state.vulnerabilitiesHistoryDayRange).toBe(DAYS.THIRTY);
    });

    it('should set the vulnerabilitiesHistoryMaxDayInterval to 7 if days are 60 and under', () => {
      mutations[types.SET_VULNERABILITIES_HISTORY_DAY_RANGE](state, DAYS.THIRTY);

      expect(state.vulnerabilitiesHistoryMaxDayInterval).toBe(7);
    });

    it('should set the vulnerabilitiesHistoryMaxDayInterval to 14 if over 60', () => {
      mutations[types.SET_VULNERABILITIES_HISTORY_DAY_RANGE](state, DAYS.NINETY);

      expect(state.vulnerabilitiesHistoryMaxDayInterval).toBe(14);
    });
  });

  describe('SET_MODAL_DATA', () => {
    describe('with all the data', () => {
      const vulnerability = mockData[0];
      let payload;

      beforeEach(() => {
        payload = { vulnerability };
        mutations[types.SET_MODAL_DATA](state, payload);
      });

      it('should set the modal title', () => {
        expect(state.modal.title).toBe(vulnerability.name);
      });

      it('should set the modal project', () => {
        expect(state.modal.project.value).toBe(vulnerability.project.full_name);
        expect(state.modal.project.url).toBe(vulnerability.project.full_path);
      });

      it('should set the modal vulnerability', () => {
        expect(state.modal.vulnerability).toEqual(vulnerability);
      });
    });

    describe('with irregular data', () => {
      const vulnerability = mockData[0];
      it('should set isDismissed when the vulnerabilitiy is dismissed', () => {
        const payload = {
          vulnerability: { ...vulnerability, dismissal_feedback: 'I am dismissed' },
        };
        mutations[types.SET_MODAL_DATA](state, payload);

        expect(state.modal.vulnerability.isDismissed).toBe(true);
      });

      it('should set hasIssue when the vulnerabilitiy has a related issue', () => {
        const payload = {
          vulnerability: {
            ...vulnerability,
            issue_feedback: {
              issue_iid: 123,
            },
          },
        };
        mutations[types.SET_MODAL_DATA](state, payload);

        expect(state.modal.vulnerability.hasIssue).toBe(true);
      });

      it('should not set hasIssue when the issue_iid in null', () => {
        const payload = {
          vulnerability: {
            ...vulnerability,
            issue_feedback: {
              issue_iid: null,
            },
          },
        };
        mutations[types.SET_MODAL_DATA](state, payload);

        expect(state.modal.vulnerability.hasIssue).toBe(false);
      });
    });
  });

  describe('REQUEST_CREATE_ISSUE', () => {
    beforeEach(() => {
      mutations[types.REQUEST_CREATE_ISSUE](state);
    });

    it('should set isCreatingIssue to true', () => {
      expect(state.isCreatingIssue).toBe(true);
    });

    it('should nullify the error state on the modal', () => {
      expect(state.modal.error).toBeNull();
    });
  });

  describe('RECEIVE_CREATE_ISSUE_SUCCESS', () => {
    it('should fire the visitUrl function on the issue URL', () => {
      const payload = { issue_url: 'fakepath.html' };
      const visitUrl = spyOnDependency(mutations, 'visitUrl');
      mutations[types.RECEIVE_CREATE_ISSUE_SUCCESS](state, payload);

      expect(visitUrl).toHaveBeenCalledWith(payload.issue_url);
    });
  });

  describe('RECEIVE_CREATE_ISSUE_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_CREATE_ISSUE_ERROR](state);
    });

    it('should set isCreatingIssue to false', () => {
      expect(state.isCreatingIssue).toBe(false);
    });

    it('should set the error state on the modal', () => {
      expect(state.modal.error).toBe('There was an error creating the issue');
    });
  });

  describe('REQUEST_CREATE_MERGE_REQUEST', () => {
    beforeEach(() => {
      mutations[types.REQUEST_CREATE_MERGE_REQUEST](state);
    });

    it('should set isCreatingMergeRequest to true', () => {
      expect(state.isCreatingMergeRequest).toBe(true);
    });

    it('should nullify the error state on the modal', () => {
      expect(state.modal.error).toBeNull();
    });
  });

  describe('RECEIVE_CREATE_MERGE_REQUEST_SUCCESS', () => {
    it('should fire the visitUrl function on the merge request URL', () => {
      const payload = { merge_request_path: 'fakepath.html' };
      const visitUrl = spyOnDependency(mutations, 'visitUrl');
      mutations[types.RECEIVE_CREATE_MERGE_REQUEST_SUCCESS](state, payload);

      expect(visitUrl).toHaveBeenCalledWith(payload.merge_request_path);
    });
  });

  describe('RECEIVE_CREATE_MERGE_REQUEST_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_CREATE_MERGE_REQUEST_ERROR](state);
    });

    it('should set isCreatingMergeRequest to false', () => {
      expect(state.isCreatingMergeRequest).toBe(false);
    });

    it('should set the error state on the modal', () => {
      expect(state.modal.error).toBe('There was an error creating the merge request');
    });
  });

  describe('REQUEST_DISMISS_VULNERABILITY', () => {
    beforeEach(() => {
      mutations[types.REQUEST_DISMISS_VULNERABILITY](state);
    });

    it('should set isDismissingVulnerability to true', () => {
      expect(state.isDismissingVulnerability).toBe(true);
    });

    it('should nullify the error state on the modal', () => {
      expect(state.modal.error).toBeNull();
    });
  });

  describe('RECEIVE_DISMISS_VULNERABILITY_SUCCESS', () => {
    let payload;
    let vulnerability;
    let data;

    beforeEach(() => {
      state.vulnerabilities = mockData;
      [vulnerability] = mockData;
      data = { name: 'dismissal feedback' };
      payload = { vulnerability, data };
      mutations[types.RECEIVE_DISMISS_VULNERABILITY_SUCCESS](state, payload);
    });

    it('should set the dismissal feedback on the passed vulnerability', () => {
      expect(vulnerability.dismissal_feedback).toEqual(data);
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set isDismissed on the modal vulnerability to be true', () => {
      expect(state.modal.vulnerability.isDismissed).toBe(true);
    });
  });

  describe('RECEIVE_DISMISS_VULNERABILITY_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_DISMISS_VULNERABILITY_ERROR](state);
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set the error state on the modal', () => {
      expect(state.modal.error).toBe('There was an error dismissing the vulnerability.');
    });
  });

  describe('REQUEST_DISMISS_SELECTED_VULNERABILITIES', () => {
    beforeEach(() => {
      mutations[types.REQUEST_DISMISS_SELECTED_VULNERABILITIES](state);
    });

    it('should set isDismissingVulnerabilities to true', () => {
      expect(state.isDismissingVulnerabilities).toBe(true);
    });
  });

  describe('RECEIVE_DISMISS_SELECTED_VULNERABILITIES_SUCCESS', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_DISMISS_SELECTED_VULNERABILITIES_SUCCESS](state);
    });

    it('should set isDismissingVulnerabilities to false', () => {
      expect(state.isDismissingVulnerabilities).toBe(false);
    });

    it('should remove all selected vulnerabilities', () => {
      expect(Object.keys(state.selectedVulnerabilities)).toHaveLength(0);
    });
  });

  describe('RECEIVE_DISMISS_SELECTED_VULNERABILITIES_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_DISMISS_SELECTED_VULNERABILITIES_ERROR](state);
    });

    it('should set isDismissingVulnerabilties to false', () => {
      expect(state.isDismissingVulnerabilities).toBe(false);
    });
  });

  describe('SELECT_VULNERABILITY', () => {
    const id = 1234;

    beforeEach(() => {
      mutations[types.SELECT_VULNERABILITY](state, id);
    });

    it('should add the vulnerability to selected vulnerabilities', () => {
      expect(state.selectedVulnerabilities[id]).toBeTruthy();
    });

    it('should not add a duplicate id to the selected vulnerabilities', () => {
      expect(state.selectedVulnerabilities).toHaveLength(1);
      mutations[types.SELECT_VULNERABILITY](state, id);

      expect(state.selectedVulnerabilities).toHaveLength(1);
    });
  });

  describe('DESELECT_VULNERABILITY', () => {
    beforeEach(() => {
      state.selectedVulnerabilities = { 12: true, 34: true, 56: true };
    });

    it('should remove the vulnerability from selected vulnerabilities', () => {
      const vulnerabilityId = 12;

      expect(state.selectedVulnerabilities[vulnerabilityId]).toBeTruthy();
      mutations[types.DESELECT_VULNERABILITY](state, vulnerabilityId);

      expect(state.selectedVulnerabilities[vulnerabilityId]).toBeFalsy();
    });
  });

  describe('SELECT_ALL_VULNERABILITIES', () => {
    beforeEach(() => {
      state.vulnerabilities = [{ id: 12 }, { id: 34 }, { id: 56 }];
      state.selectedVulnerabilites = {};
    });

    it('should add all the vulnerabilities when none are selected', () => {
      mutations[types.SELECT_ALL_VULNERABILITIES](state);

      expect(Object.keys(state.selectedVulnerabilities)).toHaveLength(state.vulnerabilities.length);
    });

    it('should add all the vulnerabilities when some are already selected', () => {
      state.selectedVulnerabilites = { 12: true, 13: true };
      mutations[types.SELECT_ALL_VULNERABILITIES](state);

      expect(Object.keys(state.selectedVulnerabilities)).toHaveLength(state.vulnerabilities.length);
    });
  });

  describe('DESELECT_ALL_VULNERABILITIES', () => {
    beforeEach(() => {
      state.selectedVulnerabilities = { 12: true, 34: true, 56: true };
      mutations[types.DESELECT_ALL_VULNERABILITIES](state);
    });

    it('should remove all selected vulnerabilities', () => {
      expect(Object.keys(state.selectedVulnerabilities)).toHaveLength(0);
    });
  });

  describe('REQUEST_DELETE_DISMISSAL_COMMENT', () => {
    beforeEach(() => {
      mutations[types.REQUEST_DELETE_DISMISSAL_COMMENT](state);
    });

    it('should set isDismissingVulnerability to true', () => {
      expect(state.isDismissingVulnerability).toBe(true);
    });

    it('should nullify the error state on the modal', () => {
      expect(state.modal.error).toBeNull();
    });
  });

  describe('RECEIVE_DELETE_DISMISSAL_COMMENT_SUCCESS', () => {
    let payload;
    let vulnerability;
    let data;

    beforeEach(() => {
      state.vulnerabilities = mockData;
      [vulnerability] = mockData;
      data = { name: '' };
      payload = { id: vulnerability.id, data };
      mutations[types.RECEIVE_DELETE_DISMISSAL_COMMENT_SUCCESS](state, payload);
    });

    it('should set the dismissal feedback on the passed vulnerability to an empty string', () => {
      expect(state.vulnerabilities[0].dismissal_feedback).toEqual({ name: '' });
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set isDissmissed on the modal vulnerability to be true', () => {
      expect(state.modal.vulnerability.isDismissed).toBe(true);
    });
  });

  describe('RECEIVE_DELETE_DISMISSAL_COMMENT_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_DELETE_DISMISSAL_COMMENT_ERROR](state);
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set the error state on the modal', () => {
      expect(state.modal.error).toBe('There was an error deleting the comment.');
    });
  });

  describe(types.SHOW_DISMISSAL_DELETE_BUTTONS, () => {
    beforeEach(() => {
      mutations[types.SHOW_DISMISSAL_DELETE_BUTTONS](state);
    });

    it('should set isShowingDeleteButtonsto to true', () => {
      expect(state.modal.isShowingDeleteButtons).toBe(true);
    });
  });

  describe(types.HIDE_DISMISSAL_DELETE_BUTTONS, () => {
    beforeEach(() => {
      mutations[types.HIDE_DISMISSAL_DELETE_BUTTONS](state);
    });

    it('should set isShowingDeleteButtons to false', () => {
      expect(state.modal.isShowingDeleteButtons).toBe(false);
    });
  });

  describe('REQUEST_ADD_DISMISSAL_COMMENT', () => {
    beforeEach(() => {
      mutations[types.REQUEST_ADD_DISMISSAL_COMMENT](state);
    });

    it('should set isDismissingVulnerability to true', () => {
      expect(state.isDismissingVulnerability).toBe(true);
    });

    it('should nullify the error state on the modal', () => {
      expect(state.modal.error).toBeNull();
    });
  });

  describe('RECEIVE_ADD_DISMISSAL_COMMENT_SUCCESS', () => {
    let payload;
    let vulnerability;
    let data;

    beforeEach(() => {
      state.vulnerabilities = mockData;
      [vulnerability] = mockData;
      data = { name: 'dismissal feedback' };
      payload = { vulnerability, data };
      mutations[types.RECEIVE_ADD_DISMISSAL_COMMENT_SUCCESS](state, payload);
    });

    it('should set the dismissal feedback on the passed vulnerability', () => {
      expect(state.vulnerabilities[0].dismissal_feedback).toEqual(data);
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set isDissmissed on the modal vulnerability to be true', () => {
      expect(state.modal.vulnerability.isDismissed).toBe(true);
    });
  });

  describe('RECEIVE_ADD_DISMISSAL_COMMENT_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_ADD_DISMISSAL_COMMENT_ERROR](state);
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set the error state on the modal', () => {
      expect(state.modal.error).toBe('There was an error adding the comment.');
    });
  });

  describe('REQUEST_REVERT_DISMISSAL', () => {
    beforeEach(() => {
      mutations[types.REQUEST_REVERT_DISMISSAL](state);
    });

    it('should set isDismissingVulnerability to true', () => {
      expect(state.isDismissingVulnerability).toBe(true);
    });

    it('should nullify the error state on the modal', () => {
      expect(state.modal.error).toBeNull();
    });
  });

  describe('RECEIVE_REVERT_DISMISSAL_SUCCESS', () => {
    let payload;
    let vulnerability;

    beforeEach(() => {
      state.vulnerabilities = mockData;
      [vulnerability] = mockData;
      payload = { vulnerability };
      mutations[types.RECEIVE_REVERT_DISMISSAL_SUCCESS](state, payload);
    });

    it('should set the dismissal feedback on the passed vulnerability', () => {
      expect(vulnerability.dismissal_feedback).toBeNull();
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set isDissmissed on the modal vulnerability to be false', () => {
      expect(state.modal.vulnerability.isDismissed).toBe(false);
    });
  });

  describe('RECEIVE_REVERT_DISMISSAL_ERROR', () => {
    beforeEach(() => {
      mutations[types.RECEIVE_REVERT_DISMISSAL_ERROR](state);
    });

    it('should set isDismissingVulnerability to false', () => {
      expect(state.isDismissingVulnerability).toBe(false);
    });

    it('should set the error state on the modal', () => {
      expect(state.modal.error).toBe('There was an error reverting the dismissal.');
    });
  });

  describe('OPEN_DISMISSAL_COMMENT_BOX', () => {
    beforeEach(() => {
      mutations[types.OPEN_DISMISSAL_COMMENT_BOX](state);
    });

    it('should set isCommentingOnDismissal to true', () => {
      expect(state.modal.isCommentingOnDismissal).toBe(true);
    });
  });

  describe('CLOSE_DISMISSAL_COMMENT_BOX', () => {
    beforeEach(() => {
      mutations[types.CLOSE_DISMISSAL_COMMENT_BOX](state);
    });

    it('should set isCommentingOnDismissal to false', () => {
      expect(state.modal.isCommentingOnDismissal).toBe(false);
    });

    it('should set isShowingDeleteButtons to false', () => {
      expect(state.modal.isShowingDeleteButtons).toBe(false);
    });
  });
});
