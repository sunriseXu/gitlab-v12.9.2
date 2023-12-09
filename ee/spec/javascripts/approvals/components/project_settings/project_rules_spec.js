import Vuex from 'vuex';
import { mount, createLocalVue } from '@vue/test-utils';
import { createStoreOptions } from 'ee/approvals/stores';
import projectSettingsModule from 'ee/approvals/stores/modules/project_settings';
import ProjectRules from 'ee/approvals/components/project_settings/project_rules.vue';
import RuleInput from 'ee/approvals/components/mr_edit/rule_input.vue';
import UserAvatarList from '~/vue_shared/components/user_avatar/user_avatar_list.vue';
import { createProjectRules } from '../../mocks';

const TEST_RULES = createProjectRules();

const localVue = createLocalVue();
localVue.use(Vuex);

const findCell = (tr, name) => tr.find(`td.js-${name}`);

const getRowData = tr => {
  const name = findCell(tr, 'name');
  const members = findCell(tr, 'members');
  const approvalsRequired = findCell(tr, 'approvals-required');
  return {
    name: name.text(),
    approvers: members.find(UserAvatarList).props('items'),
    approvalsRequired: approvalsRequired.find(RuleInput).props('rule').approvalsRequired,
  };
};

describe('Approvals ProjectRules', () => {
  let wrapper;
  let store;

  const factory = (props = {}) => {
    wrapper = mount(localVue.extend(ProjectRules), {
      propsData: props,
      store: new Vuex.Store(store),
      localVue,
    });
  };

  beforeEach(() => {
    store = createStoreOptions(projectSettingsModule());
    store.modules.approvals.state.rules = TEST_RULES;
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when allow multiple rules', () => {
    beforeEach(() => {
      store.state.settings.allowMultiRule = true;
    });

    it('renders row for each rule', () => {
      factory();

      const rows = wrapper.findAll('tbody tr').filter((tr, index) => index !== 0);
      const data = rows.wrappers.map(getRowData);

      expect(data).toEqual(
        TEST_RULES.filter((rule, index) => index !== 0).map(rule => ({
          name: rule.name,
          approvers: rule.approvers,
          approvalsRequired: rule.approvalsRequired,
        })),
      );
    });

    it('should always have any_approver rule', () => {
      factory();
      const hasAnyApproverRule = store.modules.approvals.state.rules.some(
        rule => rule.ruleType === 'any_approver',
      );

      expect(hasAnyApproverRule).toBe(true);
    });
  });

  describe('when only allow single rule', () => {
    let rule;
    let row;

    beforeEach(() => {
      [rule] = TEST_RULES;
      store.modules.approvals.state.rules = [rule];

      factory();

      row = wrapper.find('tbody tr');
    });

    it('does not render name', () => {
      expect(findCell(row, 'name').exists()).toBe(false);
    });

    it('should only display 1 rule', () => {
      factory();

      expect(store.modules.approvals.state.rules.length).toBe(1);
    });
  });

  describe('when the Vulnerability-Check group is used', () => {
    let rows;

    beforeEach(() => {
      const rules = createProjectRules();
      rules[0].name = 'Vulnerability-Check';
      store.modules.approvals.state.rules = rules;
      store.state.settings.allowMultiRule = true;
    });

    beforeEach(() => {
      factory();
      rows = wrapper.findAll('tbody tr');
    });

    it('should not render the popover for a standard approval group', () => {
      const secondRow = rows.at(1);
      const nameCell = findCell(secondRow, 'name');

      expect(nameCell.find('.js-help').exists()).toBeFalsy();
    });
  });
});
