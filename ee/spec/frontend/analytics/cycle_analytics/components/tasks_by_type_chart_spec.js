import { mount, shallowMount } from '@vue/test-utils';
import TasksByTypeChart from 'ee/analytics/cycle_analytics/components/tasks_by_type_chart.vue';
import { TASKS_BY_TYPE_SUBJECT_ISSUE } from 'ee/analytics/cycle_analytics/constants';
import { groupLabels } from '../mock_data';

const seriesNames = ['Cool label', 'Normal label'];
const data = [[0, 1, 2], [5, 2, 3], [2, 4, 1]];
const groupBy = ['Group 1', 'Group 2', 'Group 3'];
const filters = {
  selectedGroup: {
    id: 22,
    name: 'Gitlab Org',
    fullName: 'Gitlab Org',
    fullPath: 'gitlab-org',
  },
  selectedProjectIds: [],
  startDate: new Date('2019-12-11'),
  endDate: new Date('2020-01-10'),
  subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
  selectedLabelIds: [1, 2, 3],
};

function createComponent({ props = {}, shallow = true, stubs = {} }) {
  const fn = shallow ? shallowMount : mount;
  return fn(TasksByTypeChart, {
    propsData: {
      filters,
      chartData: {
        groupBy,
        data,
        seriesNames,
      },
      labels: groupLabels,
      ...props,
    },
    stubs: {
      'gl-stacked-column-chart': true,
      'tasks-by-type-filters': true,
      ...stubs,
    },
  });
}

describe('TasksByTypeChart', () => {
  let wrapper = null;

  afterEach(() => {
    wrapper.destroy();
  });

  describe('with data available', () => {
    beforeEach(() => {
      wrapper = createComponent({});
    });

    it('should render the loading chart', () => {
      expect(wrapper.html()).toMatchSnapshot();
    });
  });

  describe('no data available', () => {
    beforeEach(() => {
      wrapper = createComponent({
        props: {
          chartData: {
            groupBy: [],
            data: [],
            seriesNames: [],
          },
        },
      });
    });

    it('should render the no data available message', () => {
      expect(wrapper.html()).toMatchSnapshot();
    });
  });
});
