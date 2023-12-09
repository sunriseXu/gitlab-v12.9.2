import Vuex from 'vuex';
import { createLocalVue, mount } from '@vue/test-utils';
import { GlTabs, GlTab, GlFormInput, GlDropdown, GlDropdownItem } from '@gitlab/ui';
import GeoDesignsFilterBar from 'ee/geo_designs/components/geo_designs_filter_bar.vue';
import store from 'ee/geo_designs/store';
import { DEFAULT_SEARCH_DELAY } from 'ee/geo_designs/store/constants';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('GeoDesignsFilterBar', () => {
  let wrapper;

  const actionSpies = {
    setSearch: jest.fn(),
    setFilter: jest.fn(),
    fetchDesigns: jest.fn(),
    initiateAllDesignSyncs: jest.fn(),
  };

  const createComponent = () => {
    wrapper = mount(GeoDesignsFilterBar, {
      localVue,
      store,
      methods: {
        ...actionSpies,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  const findGlTabsContainer = () => wrapper.find(GlTabs);
  const findGlTab = () => findGlTabsContainer().findAll(GlTab);
  const findGlFormInput = () => findGlTabsContainer().find(GlFormInput);
  const findGlDropdown = () => findGlTabsContainer().find(GlDropdown);
  const findGlDropdownItem = () => findGlTabsContainer().find(GlDropdownItem);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('GlTab', () => {
      it('renders', () => {
        expect(findGlTabsContainer().exists()).toBe(true);
      });

      it('calls setFilter when input event is fired', () => {
        findGlTabsContainer().vm.$emit('input');
        expect(actionSpies.setFilter).toHaveBeenCalled();
      });
    });

    it('renders an instance of GlTab for each FilterOption', () => {
      expect(findGlTab().length).toBe(wrapper.vm.$store.state.filterOptions.length);
    });

    it('renders GlFormInput', () => {
      expect(findGlFormInput().exists()).toBe(true);
    });

    it('renders GlDropdown', () => {
      expect(findGlDropdown().exists()).toBe(true);
    });

    describe('GlDropDownItem', () => {
      it('renders', () => {
        expect(findGlDropdownItem().exists()).toBe(true);
      });

      it('calls initiateAllDesignSyncs when clicked', () => {
        const innerButton = findGlDropdownItem().find('button');
        innerButton.trigger('click');
        expect(actionSpies.initiateAllDesignSyncs).toHaveBeenCalled();
      });
    });
  });

  describe('when search changes', () => {
    beforeEach(() => {
      createComponent();
      actionSpies.fetchDesigns.mockClear(); // Will get called on init
      wrapper.vm.search = 'test search';
    });

    it(`should wait ${DEFAULT_SEARCH_DELAY}ms before calling setSearch`, () => {
      expect(actionSpies.setSearch).not.toHaveBeenCalledWith('test search');

      jest.runAllTimers(); // Debounce
      expect(actionSpies.setSearch).toHaveBeenCalledWith('test search');
    });

    it(`should wait ${DEFAULT_SEARCH_DELAY}ms before calling fetchDesigns`, () => {
      expect(actionSpies.fetchDesigns).not.toHaveBeenCalled();

      jest.runAllTimers(); // Debounce
      expect(actionSpies.fetchDesigns).toHaveBeenCalled();
    });
  });

  describe('filterChange', () => {
    const testValue = 2;

    beforeEach(() => {
      createComponent();
      wrapper.vm.filterChange(testValue);
    });

    it('should call setFilter with the filterIndex', () => {
      expect(actionSpies.setFilter).toHaveBeenCalledWith(testValue);
    });

    it('should call fetchDesigns', () => {
      expect(actionSpies.fetchDesigns).toHaveBeenCalled();
    });
  });
});
