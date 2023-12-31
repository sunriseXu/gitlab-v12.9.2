<script>
import { mapActions } from 'vuex';
import { GlAlert, GlEmptyState, GlIcon, GlLink, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ThreatMonitoringFilters from './threat_monitoring_filters.vue';
import ThreatMonitoringSection from './threat_monitoring_section.vue';

export default {
  name: 'ThreatMonitoring',
  components: {
    GlAlert,
    GlEmptyState,
    GlIcon,
    GlLink,
    GlPopover,
    ThreatMonitoringFilters,
    ThreatMonitoringSection,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    defaultEnvironmentId: {
      type: Number,
      required: true,
    },
    chartEmptyStateSvgPath: {
      type: String,
      required: true,
    },
    emptyStateSvgPath: {
      type: String,
      required: true,
    },
    documentationPath: {
      type: String,
      required: true,
    },
    showUserCallout: {
      type: Boolean,
      required: true,
    },
    userCalloutId: {
      type: String,
      required: true,
    },
    userCalloutsPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      showAlert: this.showUserCallout,

      // We require the project to have at least one available environment.
      // An invalid default environment id means there there are no available
      // environments, therefore infrastructure cannot be set up. A valid default
      // environment id only means that infrastructure *might* be set up.
      isSetUpMaybe: this.isValidEnvironmentId(this.defaultEnvironmentId),
    };
  },
  created() {
    if (this.isSetUpMaybe) {
      this.setCurrentEnvironmentId(this.defaultEnvironmentId);
      this.fetchEnvironments();
    }
  },
  methods: {
    ...mapActions('threatMonitoring', ['fetchEnvironments', 'setCurrentEnvironmentId']),
    isValidEnvironmentId(id) {
      return Number.isInteger(id) && id >= 0;
    },
    dismissAlert() {
      this.showAlert = false;

      axios.post(this.userCalloutsPath, {
        feature_name: this.userCalloutId,
      });
    },
  },
  chartEmptyStateDescription: s__(
    `ThreatMonitoring|While it's rare to have no traffic coming to your
    application, it can happen. In any event, we ask that you double check your
    settings to make sure you've set up the WAF correctly.`,
  ),
  wafChartEmptyStateDescription: s__(
    `ThreatMonitoring|While it's rare to have no traffic coming to your
    application, it can happen. In any event, we ask that you double check your
    settings to make sure you've set up the WAF correctly.`,
  ),
  networkPolicyChartEmptyStateDescription: s__(
    `ThreatMonitoring|While it's rare to have no traffic coming to your
    application, it can happen. In any event, we ask that you double check your
    settings to make sure you've set up the Network Policies correctly.`,
  ),
  emptyStateDescription: s__(
    `ThreatMonitoring|Threat monitoring provides security monitoring and rules
    to protect production applications.`,
  ),
  alertText: s__(
    `ThreatMonitoring|The graph below is an overview of traffic coming to your
    application as tracked by the Web Application Firewall (WAF). View the docs
    for instructions on how to access the WAF logs to see what type of
    malicious traffic is trying to access your app. The docs link is also
    accessible by clicking the "?" icon next to the title below.`,
  ),
  helpPopoverText: s__('ThreatMonitoring|At this time, threat monitoring only supports WAF data.'),
};
</script>

<template>
  <gl-empty-state
    v-if="!isSetUpMaybe"
    ref="emptyState"
    :title="s__('ThreatMonitoring|Threat monitoring is not enabled')"
    :description="$options.emptyStateDescription"
    :svg-path="emptyStateSvgPath"
    :primary-button-link="documentationPath"
    :primary-button-text="__('Learn More')"
  />

  <section v-else>
    <gl-alert
      v-if="showAlert"
      class="my-3"
      variant="info"
      :secondary-button-link="documentationPath"
      :secondary-button-text="__('View documentation')"
      @dismiss="dismissAlert"
    >
      {{ $options.alertText }}
    </gl-alert>
    <header class="my-3">
      <h2 class="h3 mb-1">
        {{ s__('ThreatMonitoring|Threat Monitoring') }}
        <gl-link
          ref="helpLink"
          target="_blank"
          :href="documentationPath"
          :aria-label="s__('ThreatMonitoring|Threat Monitoring help page link')"
        >
          <gl-icon name="question" />
        </gl-link>
        <gl-popover :target="() => $refs.helpLink" triggers="hover focus">
          {{ $options.helpPopoverText }}
        </gl-popover>
      </h2>
    </header>

    <threat-monitoring-filters />

    <threat-monitoring-section
      ref="wafSection"
      store-namespace="threatMonitoringWaf"
      :title="s__('ThreatMonitoring|Web Application Firewall')"
      :subtitle="s__('ThreatMonitoring|Requests')"
      :anomalous-title="s__('ThreatMonitoring|Anomalous Requests')"
      :nominal-title="s__('ThreatMonitoring|Total Requests')"
      :y-legend="s__('ThreatMonitoring|Requests')"
      :chart-empty-state-text="$options.wafChartEmptyStateDescription"
      :chart-empty-state-svg-path="chartEmptyStateSvgPath"
      :documentation-path="documentationPath"
    />

    <template v-if="glFeatures.networkPolicyUi">
      <hr />

      <threat-monitoring-section
        ref="networkPolicySection"
        store-namespace="threatMonitoringNetworkPolicy"
        :title="s__('ThreatMonitoring|Container Network Policy')"
        :subtitle="s__('ThreatMonitoring|Packet Activity')"
        :anomalous-title="s__('ThreatMonitoring|Dropped Packets')"
        :nominal-title="s__('ThreatMonitoring|Total Packets')"
        :y-legend="s__('ThreatMonitoring|Operations Per Second')"
        :chart-empty-state-text="$options.networkPolicyChartEmptyStateDescription"
        :chart-empty-state-svg-path="chartEmptyStateSvgPath"
        :documentation-path="documentationPath"
      />
    </template>
  </section>
</template>
