import Vue from 'vue';

import geoNodeDetailItemComponent from 'ee/geo_nodes/components/geo_node_detail_item.vue';
import { VALUE_TYPE, CUSTOM_TYPE } from 'ee/geo_nodes/constants';
import mountComponent from 'helpers/vue_mount_component_helper';
import { rawMockNodeDetails } from '../mock_data';

const createComponent = config => {
  const Component = Vue.extend(geoNodeDetailItemComponent);
  const defaultConfig = Object.assign(
    {
      itemTitle: 'GitLab version',
      cssClass: 'node-version',
      itemValue: '10.4.0-pre',
      successLabel: 'Synced',
      failureLabel: 'Failed',
      neutralLabel: 'Out of sync',
      itemValueType: VALUE_TYPE.PLAIN,
    },
    config,
  );

  return mountComponent(Component, defaultConfig);
};

describe('GeoNodeDetailItemComponent', () => {
  describe('template', () => {
    it('renders container elements correctly', () => {
      const vm = createComponent();

      expect(vm.$el.classList.contains('node-detail-item')).toBeTruthy();
      expect(vm.$el.querySelectorAll('.node-detail-title').length).not.toBe(0);
      expect(vm.$el.querySelector('.node-detail-title').innerText.trim()).toBe('GitLab version');
      vm.$destroy();
    });

    it('renders plain item value', () => {
      const vm = createComponent();

      expect(vm.$el.querySelectorAll('.node-detail-value').length).not.toBe(0);
      expect(vm.$el.querySelector('.node-detail-value').innerText.trim()).toBe('10.4.0-pre');
      vm.$destroy();
    });

    it('renders item title help info icon and popover with help info', () => {
      const helpInfo = {
        title: 'Foo title tooltip',
        url: 'https://docs.gitlab.com',
        urlText: 'Help',
      };
      const vm = createComponent({ helpInfo });
      const helpTextIconEl = vm.$el.querySelector('.node-detail-help-text');

      expect(helpTextIconEl).not.toBeNull();
      expect(helpTextIconEl.querySelector('use').getAttribute('xlink:href')).toContain('question');
      vm.$destroy();
    });

    it('renders graph item value', () => {
      const vm = createComponent({
        itemValueType: VALUE_TYPE.GRAPH,
        itemValue: { successCount: 5, failureCount: 3, totalCount: 10 },
      });

      expect(vm.$el.querySelectorAll('.stacked-progress-bar').length).not.toBe(0);
      vm.$destroy();
    });

    it('renders stale information status icon when `itemValueStale` prop is true', () => {
      const itemValueStaleTooltip = 'Data is out of date from 8 hours ago';
      const vm = createComponent({
        itemValueType: VALUE_TYPE.GRAPH,
        itemValue: { successCount: 5, failureCount: 3, totalCount: 10 },
        itemValueStale: true,
        itemValueStaleTooltip,
      });

      const iconEl = vm.$el.querySelector('.text-warning-500');

      expect(iconEl).not.toBeNull();
      expect(iconEl.dataset.originalTitle).toBe(itemValueStaleTooltip);
      expect(iconEl.querySelector('use').getAttribute('xlink:href')).toContain('time-out');
      vm.$destroy();
    });

    it('renders sync settings item value', () => {
      const vm = createComponent({
        itemValueType: VALUE_TYPE.CUSTOM,
        customType: CUSTOM_TYPE.SYNC,
        itemValue: {
          namespaces: rawMockNodeDetails.namespaces,
          lastEvent: {
            id: rawMockNodeDetails.last_event_id,
            timeStamp: rawMockNodeDetails.last_event_timestamp,
          },
          cursorLastEvent: {
            id: rawMockNodeDetails.cursor_last_event_id,
            timeStamp: rawMockNodeDetails.cursor_last_event_timestamp,
          },
        },
      });

      expect(vm.$el.querySelectorAll('.node-sync-settings').length).not.toBe(0);
      vm.$destroy();
    });

    it('renders event status item value', () => {
      const vm = createComponent({
        itemValueType: VALUE_TYPE.CUSTOM,
        customType: CUSTOM_TYPE.EVENT,
        itemValue: {
          eventId: rawMockNodeDetails.last_event_id,
          eventTimeStamp: rawMockNodeDetails.last_event_timestamp,
        },
      });

      expect(vm.$el.querySelectorAll('.event-status-timestamp').length).not.toBe(0);
      vm.$destroy();
    });

    it('does not render if featureDisabled is true', () => {
      const vm = createComponent({
        featureDisabled: true,
      });

      expect(vm.$el.innerHTML).toBeUndefined();
      vm.$destroy();
    });
  });
});
