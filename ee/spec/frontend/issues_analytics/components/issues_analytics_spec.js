import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import Vuex from 'vuex';
import { TEST_HOST } from 'helpers/test_constants';
import IssuesAnalytics from 'ee/issues_analytics/components/issues_analytics.vue';
import { createLocalVue, shallowMount } from '@vue/test-utils';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { createStore } from 'ee/issues_analytics/stores';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('Issues Analytics component', () => {
  let wrapper;
  let store;
  let mountComponent;
  let axiosMock;
  const mockChartData = { '2017-11': 0, '2017-12': 2 };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    mountComponent = data => {
      setFixtures('<div id="mock-filter"></div>');
      const propsData = data || {
        endpoint: TEST_HOST,
        filterBlockEl: document.querySelector('#mock-filter'),
        noDataEmptyStateSvgPath: 'svg',
        filtersEmptyStateSvgPath: 'svg',
      };

      return shallowMount(IssuesAnalytics, {
        localVue,
        propsData,
        stubs: {
          GlColumnChart: true,
        },
        store,
      });
    };

    wrapper = mountComponent();
  });

  afterEach(() => {
    wrapper.destroy();
    axiosMock.restore();
  });

  const findLoadingIcon = () => wrapper.find(GlLoadingIcon);
  const findChartContainer = () => wrapper.find('.issues-analytics-chart');
  const findEmptyState = () => wrapper.find(GlEmptyState);

  it('fetches chart data when mounted', () => {
    expect(store.dispatch).toHaveBeenCalledWith('issueAnalytics/fetchChartData', TEST_HOST);
  });

  it('renders loading state when loading', () => {
    wrapper.vm.$store.state.issueAnalytics.loading = true;

    return wrapper.vm.$nextTick(() => {
      expect(findLoadingIcon().exists()).toBe(true);
      expect(findChartContainer().exists()).toBe(false);
    });
  });

  it('renders chart when data is present', () => {
    wrapper.vm.$store.state.issueAnalytics.chartData = mockChartData;

    return wrapper.vm.$nextTick(() => {
      expect(findChartContainer().exists()).toBe(true);
    });
  });

  it('fetches data when filters are applied', () => {
    wrapper.vm.$store.state.issueAnalytics.filters = '?hello=world';

    return wrapper.vm.$nextTick(() => {
      expect(store.dispatch).toHaveBeenCalledTimes(2);
      expect(store.dispatch.mock.calls[1]).toEqual(['issueAnalytics/fetchChartData', TEST_HOST]);
    });
  });

  it('renders empty state when chart data is empty', () => {
    wrapper.vm.$store.state.issueAnalytics.chartData = {};

    return wrapper.vm.$nextTick(() => {
      expect(findEmptyState().exists()).toBe(true);
      expect(wrapper.vm.showNoDataEmptyState).toBe(true);
    });
  });

  it('renders filters empty state when filters are applied and chart data is empty', () => {
    wrapper.vm.$store.state.issueAnalytics.chartData = {};
    wrapper.vm.$store.state.issueAnalytics.filters = '?hello=world';

    return wrapper.vm.$nextTick(() => {
      expect(findEmptyState().exists()).toBe(true);
      expect(wrapper.vm.showFiltersEmptyState).toBe(true);
    });
  });
});
