import { shallowMount, createLocalVue } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { GlModal, GlButton } from '@gitlab/ui';
import Dashboard from 'ee/monitoring/components/dashboard.vue';
import {
  mockApiEndpoint,
  mockedQueryResultFixture,
  environmentData,
} from '../../../../../spec/frontend/monitoring/mock_data';
import { getJSONFixture } from '../../../../../spec/frontend/helpers/fixtures';
import { propsData } from '../../../../../spec/frontend/monitoring/init_utils';
import CustomMetricsFormFields from 'ee/custom_metrics/components/custom_metrics_form_fields.vue';
import Tracking from '~/tracking';
import { createStore } from '~/monitoring/stores';
import axios from '~/lib/utils/axios_utils';
import * as types from '~/monitoring/stores/mutation_types';

const localVue = createLocalVue();

const metricsDashboardFixture = getJSONFixture(
  'metrics_dashboard/environment_metrics_dashboard.json',
);
const metricsDashboardPayload = metricsDashboardFixture.dashboard;

describe('Dashboard', () => {
  let Component;
  let mock;
  let store;
  let wrapper;

  const findAddMetricButton = () => wrapper.vm.$refs.addMetricBtn;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(localVue.extend(Component), {
      propsData: { ...propsData, ...props },
      stubs: {
        GlButton,
      },
      store,
      localVue,
    });
  };

  beforeEach(() => {
    setFixtures(`
      <div class="prometheus-graphs"></div>
      <div class="layout-page"></div>
    `);
    window.gon = { ...window.gon, ee: true };
    store = createStore();
    mock = new MockAdapter(axios);
    mock.onGet(mockApiEndpoint).reply(200, metricsDashboardPayload);
    Component = localVue.extend(Dashboard);
  });
  afterEach(() => {
    mock.restore();
  });

  function setupComponentStore(component) {
    component.vm.$store.commit(
      `monitoringDashboard/${types.RECEIVE_METRICS_DATA_SUCCESS}`,
      metricsDashboardPayload,
    );

    component.vm.$store.commit(
      `monitoringDashboard/${types.RECEIVE_METRIC_RESULT_SUCCESS}`,
      mockedQueryResultFixture,
    );
    component.vm.$store.commit(
      `monitoringDashboard/${types.RECEIVE_ENVIRONMENTS_DATA_SUCCESS}`,
      environmentData,
    );
  }

  describe('add custom metrics', () => {
    describe('when not available', () => {
      beforeEach(() => {
        createComponent({
          hasMetrics: true,
          customMetricsPath: '/endpoint',
        });
      });
      it('does not render add button on the dashboard', () => {
        expect(findAddMetricButton()).toBeUndefined();
      });
    });
    describe('when available', () => {
      let origPage;
      beforeEach(done => {
        jest.spyOn(Tracking, 'event').mockReturnValue();
        createComponent({
          hasMetrics: true,
          customMetricsPath: '/endpoint',
          customMetricsAvailable: true,
        });
        setupComponentStore(wrapper);

        origPage = document.body.dataset.page;
        document.body.dataset.page = 'projects:environments:metrics';

        wrapper.vm.$nextTick(done);
      });
      afterEach(() => {
        document.body.dataset.page = origPage;
      });

      it('renders add button on the dashboard', () => {
        expect(findAddMetricButton()).toBeDefined();
      });

      it('uses modal for custom metrics form', () => {
        expect(wrapper.find(GlModal).exists()).toBe(true);
        expect(wrapper.find(GlModal).attributes().modalid).toBe('add-metric');
      });
      it('adding new metric is tracked', done => {
        const submitButton = wrapper.vm.$refs.submitCustomMetricsFormBtn;
        wrapper.setData({
          formIsValid: true,
        });
        wrapper.vm.$nextTick(() => {
          submitButton.$el.click();
          wrapper.vm.$nextTick(() => {
            expect(Tracking.event).toHaveBeenCalledWith(
              document.body.dataset.page,
              'click_button',
              {
                label: 'add_new_metric',
                property: 'modal',
                value: undefined,
              },
            );
            done();
          });
        });
      });
      it('renders custom metrics form fields', () => {
        expect(wrapper.find(CustomMetricsFormFields).exists()).toBe(true);
      });
    });
  });
});
