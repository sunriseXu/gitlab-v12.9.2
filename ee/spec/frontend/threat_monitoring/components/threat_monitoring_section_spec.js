import { shallowMount } from '@vue/test-utils';
import createStore from 'ee/threat_monitoring/store';
import ThreatMonitoringSection from 'ee/threat_monitoring/components/threat_monitoring_section.vue';
import LoadingSkeleton from 'ee/threat_monitoring/components/loading_skeleton.vue';
import StatisticsHistory from 'ee/threat_monitoring/components/statistics_history.vue';
import StatisticsSummary from 'ee/threat_monitoring/components/statistics_summary.vue';

import { mockNominalHistory, mockAnomalousHistory } from '../mock_data';

describe('ThreatMonitoringSection component', () => {
  let store;
  let wrapper;

  const timeRange = {
    from: new Date(Date.UTC(2020, 2, 6)).toISOString(),
    to: new Date(Date.UTC(2020, 2, 13)).toISOString(),
  };

  const factory = ({ propsData, state } = {}) => {
    store = createStore();
    Object.assign(store.state.threatMonitoringWaf, {
      isLoadingStatistics: false,
      statistics: {
        total: 100,
        anomalous: 0.2,
        history: {
          nominal: mockNominalHistory,
          anomalous: mockAnomalousHistory,
        },
      },
      timeRange,
      ...state,
    });

    wrapper = shallowMount(ThreatMonitoringSection, {
      propsData: {
        storeNamespace: 'threatMonitoringWaf',
        title: 'Web Application Firewall',
        subtitle: 'Requests',
        nominalTitle: 'Total Requests',
        anomalousTitle: 'Anomalous Requests',
        yLegend: 'Requests',
        chartEmptyStateText: 'Empty Text',
        chartEmptyStateSvgPath: 'svg_path',
        documentationPath: 'documentation_path',
        ...propsData,
      },
      store,
    });
  };

  const findLoadingSkeleton = () => wrapper.find(LoadingSkeleton);
  const findStatisticsHistory = () => wrapper.find(StatisticsHistory);
  const findStatisticsSummary = () => wrapper.find(StatisticsSummary);
  const findChartEmptyState = () => wrapper.find({ ref: 'chartEmptyState' });

  beforeEach(() => {
    factory({});
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('does not show the loading skeleton', () => {
    expect(findLoadingSkeleton().exists()).toBe(false);
  });

  it('sets data to the summary', () => {
    const summary = findStatisticsSummary();
    expect(summary.exists()).toBe(true);

    expect(summary.props('data')).toStrictEqual({
      anomalous: {
        title: 'Anomalous Requests',
        value: 0.2,
      },
      nominal: {
        title: 'Total Requests',
        value: 100,
      },
    });
  });

  it('sets data to the chart', () => {
    const chart = findStatisticsHistory();
    expect(chart.exists()).toBe(true);

    expect(chart.props('data')).toStrictEqual({
      anomalous: { title: 'Anomalous Requests', values: mockAnomalousHistory },
      nominal: { title: 'Total Requests', values: mockNominalHistory },
      ...timeRange,
    });
    expect(chart.props('yLegend')).toEqual('Requests');
  });

  it('does not show the chart empty state', () => {
    expect(findChartEmptyState().exists()).toBe(false);
  });

  describe('given the statistics are loading', () => {
    beforeEach(() => {
      factory({
        state: { isLoadingStatistics: true },
      });
    });

    it('shows the loading skeleton', () => {
      expect(findLoadingSkeleton().element).toMatchSnapshot();
    });

    it('does not show the summary or history statistics', () => {
      expect(findStatisticsSummary().exists()).toBe(false);
      expect(findStatisticsHistory().exists()).toBe(false);
    });

    it('does not show the chart empty state', () => {
      expect(findChartEmptyState().exists()).toBe(false);
    });
  });

  describe('given there is a default environment with no data to display', () => {
    beforeEach(() => {
      factory({
        state: {
          statistics: {
            total: 100,
            anoumalous: 0.2,
            history: { nominal: [], anomalous: [] },
          },
        },
      });
    });

    it('does not show the loading skeleton', () => {
      expect(findLoadingSkeleton().exists()).toBe(false);
    });

    it('does not show the summary or history statistics', () => {
      expect(findStatisticsSummary().exists()).toBe(false);
      expect(findStatisticsHistory().exists()).toBe(false);
    });

    it('shows the chart empty state', () => {
      expect(findChartEmptyState().element).toMatchSnapshot();
    });
  });
});
