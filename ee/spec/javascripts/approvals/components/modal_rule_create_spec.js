import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import RuleForm from 'ee/approvals/components/rule_form.vue';
import ModalRuleCreate from 'ee/approvals/components/modal_rule_create.vue';
import GlModalVuex from '~/vue_shared/components/gl_modal_vuex.vue';

const TEST_MODAL_ID = 'test-modal-create-id';
const TEST_RULE = { id: 7 };
const MODAL_MODULE = 'createModal';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('Approvals ModalRuleCreate', () => {
  let createModalState;
  let wrapper;

  const factory = (options = {}) => {
    const store = new Vuex.Store({
      modules: {
        [MODAL_MODULE]: {
          namespaced: true,
          state: createModalState,
        },
      },
    });

    const propsData = {
      modalId: TEST_MODAL_ID,
      ...options.propsData,
    };

    wrapper = shallowMount(localVue.extend(ModalRuleCreate), {
      ...options,
      localVue,
      store,
      propsData,
    });
  };

  beforeEach(() => {
    createModalState = {};
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('without data', () => {
    beforeEach(() => {
      createModalState.data = null;
    });

    it('renders modal', () => {
      factory();

      const modal = wrapper.find(GlModalVuex);

      expect(modal.exists()).toBe(true);

      expect(modal.props('modalModule')).toEqual(MODAL_MODULE);
      expect(modal.props('modalId')).toEqual(TEST_MODAL_ID);
      expect(modal.attributes('title')).toEqual('Add approval rule');
      expect(modal.attributes('ok-title')).toEqual('Add approval rule');
    });

    it('renders form', () => {
      factory();

      const modal = wrapper.find(GlModalVuex);
      const form = modal.find(RuleForm);

      expect(form.exists()).toBe(true);
      expect(form.props('initRule')).toEqual(null);
    });

    it('when modal emits ok, submits form', () => {
      factory();

      const form = wrapper.find(RuleForm);
      form.vm.submit = jasmine.createSpy('submit');

      const modal = wrapper.find(GlModalVuex);
      modal.vm.$emit('ok', new Event('ok'));

      expect(form.vm.submit).toHaveBeenCalled();
    });
  });

  describe('with data', () => {
    beforeEach(() => {
      createModalState.data = TEST_RULE;
    });

    it('renders modal', () => {
      factory();

      const modal = wrapper.find(GlModalVuex);

      expect(modal.exists()).toBe(true);

      expect(modal.attributes('title')).toEqual('Update approval rule');
      expect(modal.attributes('ok-title')).toEqual('Update approval rule');
    });

    it('renders form', () => {
      factory();

      const modal = wrapper.find(GlModalVuex);
      const form = modal.find(RuleForm);

      expect(form.exists()).toBe(true);
      expect(form.props('initRule')).toEqual(TEST_RULE);
    });
  });
});
