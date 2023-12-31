import { mount } from '@vue/test-utils';
import WeightSelect from 'ee/boards/components/weight_select.vue';
import { GlButton, GlDropdown } from '@gitlab/ui';

describe('WeightSelect', () => {
  let wrapper;

  const editButton = () => wrapper.find(GlButton);
  const valueContainer = () => wrapper.find('.value');
  const weightDropdown = () => wrapper.find(GlDropdown);
  const weightSelect = () => wrapper.find({ ref: 'weight-select' });

  const defaultProps = {
    weights: ['Any Weight', 'No Weight', 1, 2, 3],
    board: {
      weight: null,
    },
    canEdit: true,
  };

  const createComponent = (props = {}) => {
    wrapper = mount(WeightSelect, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when no weight has been selected', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays "Any Weight"', () => {
      expect(valueContainer().text()).toEqual('Any Weight');
    });

    it('hides the weight dropdown', () => {
      expect(weightDropdown().isVisible()).toBeFalsy();
    });
  });

  describe('when the weight cannot be edited', () => {
    beforeEach(() => {
      createComponent({ canEdit: false });
    });

    it('does not render the edit button', () => {
      expect(editButton().exists()).toBeFalsy();
    });
  });

  describe('when the weight can be edited', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows the edit button', () => {
      expect(editButton().isVisible()).toBeTruthy();
    });

    describe('and the edit button is clicked', () => {
      beforeEach(() => {
        editButton().trigger('click');
      });

      describe('and no weight has been selected yet', () => {
        it('hides the value text', () => {
          expect(valueContainer().isVisible()).toBeFalsy();
        });

        it('shows the weight dropdown', () => {
          expect(weightDropdown().isVisible()).toBeTruthy();
        });
      });

      describe('and a weight has been selected', () => {
        beforeEach(() => {
          weightSelect().trigger('click');
        });

        it('shows the value text', () => {
          expect(valueContainer().isVisible()).toBeTruthy();
        });

        it('hides the weight dropdown', () => {
          expect(weightDropdown().isVisible()).toBeFalsy();
        });
      });
    });
  });

  describe('when a new weight value is selected', () => {
    it.each`
      weight          | text
      ${'Any Weight'} | ${'Any Weight'}
      ${'No Weight'}  | ${'No Weight'}
      ${0}            | ${'No Weight'}
      ${-1}           | ${'Any Weight'}
      ${1}            | ${'1'}
    `('$weight displays as "$text"', ({ weight, text }) => {
      createComponent({ board: { weight } });
      expect(valueContainer().text()).toEqual(text);
    });
  });
});
