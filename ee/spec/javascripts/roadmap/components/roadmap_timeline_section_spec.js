import Vue from 'vue';

import roadmapTimelineSectionComponent from 'ee/roadmap/components/roadmap_timeline_section.vue';
import eventHub from 'ee/roadmap/event_hub';
import { getTimeframeForMonthsView } from 'ee/roadmap/utils/roadmap_utils';

import { PRESET_TYPES } from 'ee/roadmap/constants';

import mountComponent from 'spec/helpers/vue_mount_component_helper';
import { mockEpic, mockTimeframeInitialDate } from '../mock_data';

const mockTimeframeMonths = getTimeframeForMonthsView(mockTimeframeInitialDate);

const createComponent = ({
  presetType = PRESET_TYPES.MONTHS,
  epics = [mockEpic],
  timeframe = mockTimeframeMonths,
} = {}) => {
  const Component = Vue.extend(roadmapTimelineSectionComponent);

  return mountComponent(Component, {
    presetType,
    epics,
    timeframe,
  });
};

describe('RoadmapTimelineSectionComponent', () => {
  let vm;

  beforeEach(() => {
    vm = createComponent();
  });

  afterEach(() => {
    vm.$destroy();
  });

  describe('data', () => {
    it('returns default data props', () => {
      expect(vm.scrolledHeaderClass).toBe('');
    });
  });

  describe('computed', () => {
    describe('sectionContainerStyles', () => {
      it('returns object containing `width` with value based on epic details cell width, timeline cell width and timeframe length', () => {
        expect(vm.sectionContainerStyles).toEqual(
          jasmine.objectContaining({
            width: '1760px',
          }),
        );
      });
    });
  });

  describe('methods', () => {
    describe('handleEpicsListScroll', () => {
      it('sets `scrolled-ahead` class on thead element based on provided scrollTop value', () => {
        // vm.$el.clientHeight is 0 during tests
        // hence any value greater than 0 should
        // update scrolledHeaderClass prop
        vm.handleEpicsListScroll({ scrollTop: 1 });

        expect(vm.scrolledHeaderClass).toBe('scroll-top-shadow');

        vm.handleEpicsListScroll({ scrollTop: 0 });

        expect(vm.scrolledHeaderClass).toBe('');
      });
    });
  });

  describe('mounted', () => {
    it('binds `epicsListScrolled` event listener via eventHub', () => {
      spyOn(eventHub, '$on');
      const vmX = createComponent({});

      expect(eventHub.$on).toHaveBeenCalledWith('epicsListScrolled', jasmine.any(Function));
      vmX.$destroy();
    });
  });

  describe('beforeDestroy', () => {
    it('unbinds `epicsListScrolled` event listener via eventHub', () => {
      spyOn(eventHub, '$off');
      const vmX = createComponent({});
      vmX.$destroy();

      expect(eventHub.$off).toHaveBeenCalledWith('epicsListScrolled', jasmine.any(Function));
    });
  });

  describe('template', () => {
    it('renders component container element with class `roadmap-timeline-section`', () => {
      expect(vm.$el.classList.contains('roadmap-timeline-section')).toBe(true);
    });

    it('renders empty header cell element with class `timeline-header-blank`', () => {
      expect(vm.$el.querySelector('.timeline-header-blank')).not.toBeNull();
    });
  });
});
