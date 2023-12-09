import { createLocalVue, shallowMount } from '@vue/test-utils';
import Vuex from 'vuex';
import TerminalSession from 'ee/ide/components/terminal/session.vue';
import Terminal from 'ee/ide/components/terminal/terminal.vue';
import { STARTING, PENDING, RUNNING, STOPPING, STOPPED } from 'ee/ide/constants';

const TEST_TERMINAL_PATH = 'terminal/path';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('EE IDE TerminalSession', () => {
  let wrapper;
  let actions;
  let state;

  const factory = (options = {}) => {
    const store = new Vuex.Store({
      modules: {
        terminal: {
          namespaced: true,
          actions,
          state,
        },
      },
    });

    wrapper = shallowMount(TerminalSession, {
      localVue,
      store,
      ...options,
    });
  };

  beforeEach(() => {
    state = {
      session: { status: RUNNING, terminalPath: TEST_TERMINAL_PATH },
    };
    actions = {
      restartSession: jasmine.createSpy('restartSession'),
      stopSession: jasmine.createSpy('stopSession'),
    };
  });

  it('is empty if session is falsey', () => {
    state.session = null;
    factory();

    expect(wrapper.isEmpty()).toBe(true);
  });

  it('shows terminal', () => {
    factory();

    expect(wrapper.find(Terminal).props()).toEqual({
      terminalPath: TEST_TERMINAL_PATH,
      status: RUNNING,
    });
  });

  [STARTING, PENDING, RUNNING].forEach(status => {
    it(`show stop button when status is ${status}`, () => {
      state.session = { status };
      factory();

      const button = wrapper.find('button');
      button.trigger('click');

      return wrapper.vm.$nextTick().then(() => {
        expect(button.text()).toEqual('Stop Terminal');
        expect(actions.stopSession).toHaveBeenCalled();
      });
    });
  });

  [STOPPING, STOPPED].forEach(status => {
    it(`show stop button when status is ${status}`, () => {
      state.session = { status };
      factory();

      const button = wrapper.find('button');
      button.trigger('click');

      return wrapper.vm.$nextTick().then(() => {
        expect(button.text()).toEqual('Restart Terminal');
        expect(actions.restartSession).toHaveBeenCalled();
      });
    });
  });
});
