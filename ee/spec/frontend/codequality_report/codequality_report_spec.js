import Vuex from 'vuex';
import CodequalityReportApp from 'ee/codequality_report/codequality_report.vue';
import { parsedIssues } from './mock_data';
import { mount, createLocalVue } from '@vue/test-utils';

jest.mock('~/flash');

const localVue = createLocalVue();
localVue.use(Vuex);

describe('Codequality report app', () => {
  let wrapper;
  let store;

  const createComponent = (state = {}, issues = []) => {
    store = new Vuex.Store({
      state: {
        pageInfo: {},
        ...state,
      },
      getters: {
        codequalityIssues: () => issues,
        codequalityIssueTotal: () => issues.length,
      },
    });

    wrapper = mount(CodequalityReportApp, {
      localVue,
      store,
    });
  };

  const findStatus = () => wrapper.find('.js-code-text');
  const findSuccessIcon = () => wrapper.find('.js-ci-status-icon-success');
  const findWarningIcon = () => wrapper.find('.js-ci-status-icon-warning');

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoadingCodequality: true });
    });

    it('shows a loading state', () => {
      expect(findStatus().text()).toBe('Loading codeclimate report');
    });
  });

  describe('on error', () => {
    beforeEach(() => {
      createComponent({ loadingCodequalityFailed: true });
    });

    it('shows a warning icon and error message', () => {
      expect(findWarningIcon().exists()).toBe(true);
      expect(findStatus().text()).toBe('Failed to load codeclimate report');
    });
  });

  describe('when there are codequality issues', () => {
    beforeEach(() => {
      createComponent({}, parsedIssues);
    });

    it('renders the codequality issues', () => {
      const expectedIssueTotal = parsedIssues.length;

      expect(findWarningIcon().exists()).toBe(true);
      expect(findStatus().text()).toBe(`Found ${expectedIssueTotal} code quality issues`);
      expect(wrapper.findAll('.report-block-list-issue').length).toBe(expectedIssueTotal);
    });
  });

  describe('when there are no codequality issues', () => {
    beforeEach(() => {
      createComponent({}, []);
    });

    it('shows a message that no codequality issues were found', () => {
      expect(findSuccessIcon().exists()).toBe(true);
      expect(findStatus().text()).toBe('No code quality issues found');
      expect(wrapper.findAll('.report-block-list-issue').length).toBe(0);
    });
  });
});
