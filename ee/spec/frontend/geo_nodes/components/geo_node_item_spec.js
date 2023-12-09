import Vue from 'vue';

import geoNodeItemComponent from 'ee/geo_nodes/components/geo_node_item.vue';
import eventHub from 'ee/geo_nodes/event_hub';
import mountComponent from 'helpers/vue_mount_component_helper';
import { mockNode, mockNodeDetails } from '../mock_data';

jest.mock('ee/geo_nodes/event_hub');

const createComponent = (node = mockNode) => {
  const Component = Vue.extend(geoNodeItemComponent);

  return mountComponent(Component, {
    node,
    primaryNode: true,
    nodeActionsAllowed: true,
    nodeEditAllowed: true,
    geoTroubleshootingHelpPath: '/foo/bar',
  });
};

describe('GeoNodeItemComponent', () => {
  let vm;

  beforeEach(() => {
    vm = createComponent();
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('data', () => {
    it('returns default data props', () => {
      expect(vm.isNodeDetailsLoading).toBe(true);
      expect(vm.isNodeDetailsFailed).toBe(false);
      expect(vm.nodeHealthStatus).toBe('');
      expect(vm.errorMessage).toBe('');
      expect(typeof vm.nodeDetails).toBe('object');
    });
  });

  describe('computed', () => {
    let vmHttps;
    let httpsNode;

    beforeEach(() => {
      // Altered mock data for secure URL
      httpsNode = Object.assign({}, mockNode, {
        id: mockNodeDetails.id,
        url: 'https://127.0.0.1:3001/',
      });
      vmHttps = createComponent(httpsNode);
    });

    afterEach(() => {
      vmHttps.$destroy();
    });

    describe('showNodeDetails', () => {
      it('returns `false` if Node details are still loading', () => {
        vmHttps.isNodeDetailsLoading = true;

        expect(vmHttps.showNodeDetails).toBeFalsy();
      });

      it('returns `false` if Node details failed to load', () => {
        vmHttps.isNodeDetailsLoading = false;
        vmHttps.isNodeDetailsFailed = true;

        expect(vmHttps.showNodeDetails).toBeFalsy();
      });

      it('returns `true` if Node details loaded', () => {
        vmHttps.handleNodeDetails(mockNodeDetails);
        vmHttps.isNodeDetailsLoading = false;
        vmHttps.isNodeDetailsFailed = false;

        expect(vmHttps.showNodeDetails).toBeTruthy();
      });
    });
  });

  describe('methods', () => {
    describe('handleNodeDetails', () => {
      it('intializes props based on provided `nodeDetails`', () => {
        // With altered mock data with matching ID
        const mockNodeSecondary = Object.assign({}, mockNode, {
          id: mockNodeDetails.id,
          primary: false,
        });
        const vmNodePrimary = createComponent(mockNodeSecondary);

        vmNodePrimary.handleNodeDetails(mockNodeDetails);

        expect(vmNodePrimary.isNodeDetailsLoading).toBeFalsy();
        expect(vmNodePrimary.isNodeDetailsFailed).toBeFalsy();
        expect(vmNodePrimary.errorMessage).toBe('');
        expect(vmNodePrimary.nodeDetails).toBe(mockNodeDetails);
        expect(vmNodePrimary.nodeHealthStatus).toBe(mockNodeDetails.health);
        vmNodePrimary.$destroy();

        // With default mock data without matching ID
        vm.handleNodeDetails(mockNodeDetails);

        expect(vm.isNodeDetailsLoading).toBeTruthy();
        expect(vm.nodeDetails).not.toBe(mockNodeDetails);
        expect(vm.nodeHealthStatus).not.toBe(mockNodeDetails.health);
      });
    });

    describe('handleMounted', () => {
      it('emits `pollNodeDetails` event and passes node ID', () => {
        vm.handleMounted();

        expect(eventHub.$emit).toHaveBeenCalledWith('pollNodeDetails', vm.node);
      });
    });
  });

  describe('created', () => {
    it('binds `nodeDetailsLoaded` event handler', () => {
      const vmX = createComponent();

      expect(eventHub.$on).toHaveBeenCalledWith('nodeDetailsLoaded', jasmine.any(Function));
      vmX.$destroy();
    });
  });

  describe('beforeDestroy', () => {
    it('unbinds `nodeDetailsLoaded` event handler', () => {
      const vmX = createComponent();
      vmX.$destroy();

      expect(eventHub.$off).toHaveBeenCalledWith('nodeDetailsLoaded', jasmine.any(Function));
    });
  });

  describe('template', () => {
    it('renders container element', () => {
      expect(vm.$el.classList.contains('card', 'geo-node-item')).toBe(true);
    });

    it('renders node error message', done => {
      const err = 'Something error message';
      vm.isNodeDetailsFailed = true;
      vm.errorMessage = err;
      Vue.nextTick(() => {
        expect(vm.$el.querySelectorAll('p.bg-danger-100').length).not.toBe(0);
        expect(vm.$el.querySelector('p.bg-danger-100').innerText.trim()).toContain(err);
        expect(vm.$el.querySelector('p.bg-danger-100 a').getAttribute('href')).toBe('/foo/bar');
        done();
      });
    });
  });
});
