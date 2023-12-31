<script>
import { GlColumnChart, GlLineChart, GlStackedColumnChart } from '@gitlab/ui/dist/charts';

import { getSvgIconPathContent } from '~/lib/utils/icon_utils';
import ResizableChartContainer from '~/vue_shared/components/resizable_chart/resizable_chart_container.vue';

import InsightsChartError from './insights_chart_error.vue';
import { CHART_TYPES } from '../constants';

const CHART_HEIGHT = 300;

export default {
  components: {
    GlColumnChart,
    GlLineChart,
    GlStackedColumnChart,
    ResizableChartContainer,
    InsightsChartError,
  },
  props: {
    loaded: {
      type: Boolean,
      required: true,
    },
    type: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    data: {
      type: Object,
      required: true,
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      svgs: {},
    };
  },
  computed: {
    dataZoomConfig() {
      const handleIcon = this.svgs['scroll-handle'];

      return handleIcon ? { handleIcon } : {};
    },
    chartOptions() {
      let options = {
        yAxis: {
          minInterval: 1,
        },
      };

      if (this.type === this.$options.chartTypes.LINE) {
        options = {
          ...options,
          xAxis: {
            ...options.xAxis,
            name: this.data.xAxisTitle,
            type: 'category',
          },
          yAxis: {
            ...options.yAxis,
            name: this.data.yAxisTitle,
            type: 'value',
          },
        };
      }

      return { dataZoom: [this.dataZoomConfig], ...options };
    },
    isColumnChart() {
      return [this.$options.chartTypes.BAR, this.$options.chartTypes.PIE].includes(this.type);
    },
    isStackedColumnChart() {
      return this.type === this.$options.chartTypes.STACKED_BAR;
    },
    isLineChart() {
      return this.type === this.$options.chartTypes.LINE;
    },
  },
  methods: {
    setSvg(name) {
      return getSvgIconPathContent(name)
        .then(path => {
          if (path) {
            this.$set(this.svgs, name, `path://${path}`);
          }
        })
        .catch(e => {
          // eslint-disable-next-line no-console, @gitlab/i18n/no-non-i18n-strings
          console.error('SVG could not be rendered correctly: ', e);
        });
    },
    onChartCreated() {
      this.setSvg('scroll-handle');
    },
  },
  height: CHART_HEIGHT,
  chartTypes: CHART_TYPES,
};
</script>
<template>
  <resizable-chart-container v-if="loaded" class="insights-chart">
    <h5 class="text-center">{{ title }}</h5>
    <p v-if="description" class="text-center">{{ description }}</p>
    <gl-column-chart
      v-if="isColumnChart"
      v-bind="$attrs"
      :height="$options.height"
      :data="data.datasets"
      x-axis-type="category"
      :x-axis-title="data.xAxisTitle"
      :y-axis-title="data.yAxisTitle"
      :option="chartOptions"
      @created="onChartCreated"
    />
    <gl-stacked-column-chart
      v-else-if="isStackedColumnChart"
      v-bind="$attrs"
      :height="$options.height"
      :data="data.datasets"
      :group-by="data.labels"
      :series-names="data.seriesNames"
      x-axis-type="category"
      :x-axis-title="data.xAxisTitle"
      :y-axis-title="data.yAxisTitle"
      :option="chartOptions"
      @created="onChartCreated"
    />
    <gl-line-chart
      v-else-if="isLineChart"
      v-bind="$attrs"
      :height="$options.height"
      :data="data.datasets"
      :option="chartOptions"
      @created="onChartCreated"
    />
  </resizable-chart-container>
  <div v-else class="insights-chart">
    <insights-chart-error
      :chart-name="title"
      :title="__('This chart could not be displayed')"
      :summary="__('Please check the configuration file for this chart')"
      :error="error"
    />
  </div>
</template>
