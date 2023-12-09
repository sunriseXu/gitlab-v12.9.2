import { shallowMount } from '@vue/test-utils';
import TerminalControls from 'ee/ide/components/terminal/terminal_controls.vue';
import ScrollButton from '~/ide/components/jobs/detail/scroll_button.vue';

describe('EE IDE TerminalControls', () => {
  let wrapper;
  let buttons;

  const factory = (options = {}) => {
    wrapper = shallowMount(TerminalControls, {
      ...options,
    });

    buttons = wrapper.findAll(ScrollButton);
  };

  it('shows an up and down scroll button', () => {
    factory();

    expect(buttons.wrappers.map(x => x.props())).toEqual([
      jasmine.objectContaining({ direction: 'up', disabled: true }),
      jasmine.objectContaining({ direction: 'down', disabled: true }),
    ]);
  });

  it('enables up button with prop', () => {
    factory({ propsData: { canScrollUp: true } });

    expect(buttons.at(0).props()).toEqual(
      jasmine.objectContaining({ direction: 'up', disabled: false }),
    );
  });

  it('enables down button with prop', () => {
    factory({ propsData: { canScrollDown: true } });

    expect(buttons.at(1).props()).toEqual(
      jasmine.objectContaining({ direction: 'down', disabled: false }),
    );
  });

  it('emits "scroll-up" when click up button', () => {
    factory({ propsData: { canScrollUp: true } });

    expect(wrapper.emittedByOrder()).toEqual([]);

    buttons.at(0).vm.$emit('click');

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.emittedByOrder()).toEqual([{ name: 'scroll-up', args: [] }]);
    });
  });

  it('emits "scroll-down" when click down button', () => {
    factory({ propsData: { canScrollDown: true } });

    expect(wrapper.emittedByOrder()).toEqual([]);

    buttons.at(1).vm.$emit('click');

    return wrapper.vm.$nextTick().then(() => {
      expect(wrapper.emittedByOrder()).toEqual([{ name: 'scroll-down', args: [] }]);
    });
  });
});
