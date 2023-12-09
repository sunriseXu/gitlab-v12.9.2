import { shallowMount, createLocalVue } from '@vue/test-utils';
import { trimText } from 'spec/helpers/text_helper';
import MRWidgetAutoMergeEnabled from '~/vue_merge_request_widget/components/states/mr_widget_auto_merge_enabled.vue';
import {
  MWPS_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
  MTWPS_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

describe('MRWidgetAutoMergeEnabled', () => {
  const localVue = createLocalVue();
  let wrapper;
  let vm;

  const service = {
    merge: () => {},
    poll: () => {},
  };

  const mr = {
    shouldRemoveSourceBranch: false,
    canRemoveSourceBranch: true,
    canCancelAutomaticMerge: true,
    mergeUserId: 1,
    currentUserId: 1,
    setToAutoMergeBy: {},
    sha: '1EA2EZ34',
    targetBranchPath: '/foo/bar',
    targetBranch: 'foo',
    autoMergeStrategy: MTWPS_MERGE_STRATEGY,
  };

  const factory = (mrUpdates = {}) => {
    wrapper = shallowMount(localVue.extend(MRWidgetAutoMergeEnabled), {
      propsData: {
        mr: { ...mr, ...mrUpdates },
        service,
      },
      localVue,
    });

    ({ vm } = wrapper);
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('computed', () => {
    describe('statusTextBeforeAuthor', () => {
      it('should return "Added to the merge train by" if the pipeline has been added to the merge train', () => {
        factory({ autoMergeStrategy: MT_MERGE_STRATEGY });

        expect(vm.statusTextBeforeAuthor).toBe('Added to the merge train by');
      });

      it('should return "Set by" if the MTWPS is selected', () => {
        factory({ autoMergeStrategy: MTWPS_MERGE_STRATEGY });

        expect(vm.statusTextBeforeAuthor).toBe('Set by');
      });

      it('should return "Set by" if the MWPS is selected', () => {
        factory({ autoMergeStrategy: MWPS_MERGE_STRATEGY });

        expect(vm.statusTextBeforeAuthor).toBe('Set by');
      });
    });

    describe('statusTextAfterAuthor', () => {
      it('should return "to start a merge train..." if MTWPS is selected and there is no existing merge train', () => {
        factory({
          autoMergeStrategy: MTWPS_MERGE_STRATEGY,
          mergeTrainsCount: 0,
        });

        expect(vm.statusTextAfterAuthor).toBe('to start a merge train when the pipeline succeeds');
      });

      it('should return "to be added to the merge train..." if MTWPS is selected and there is an existing merge train', () => {
        factory({
          autoMergeStrategy: MTWPS_MERGE_STRATEGY,
          mergeTrainsCount: 1,
        });

        expect(vm.statusTextAfterAuthor).toBe(
          'to be added to the merge train when the pipeline succeeds',
        );
      });

      it('should return "to be merged automatically..." if MWPS is selected', () => {
        factory({ autoMergeStrategy: MWPS_MERGE_STRATEGY });

        expect(vm.statusTextAfterAuthor).toBe(
          'to be merged automatically when the pipeline succeeds',
        );
      });
    });

    describe('cancelButtonText', () => {
      it('should return "Cancel start merge train" if MTWPS is selected', () => {
        factory({ autoMergeStrategy: MTWPS_MERGE_STRATEGY });

        expect(vm.cancelButtonText).toBe('Cancel automatic merge');
      });

      it('should return "Remove from merge train" if the pipeline has been added to the merge train', () => {
        factory({ autoMergeStrategy: MT_MERGE_STRATEGY });

        expect(vm.cancelButtonText).toBe('Remove from merge train');
      });

      it('should return "Cancel automatic merge" if MWPS is selected', () => {
        factory({ autoMergeStrategy: MWPS_MERGE_STRATEGY });

        expect(vm.cancelButtonText).toBe('Cancel automatic merge');
      });
    });
  });

  describe('template', () => {
    it('should render the status text as "...to start a merge train" if MTWPS is selected and there is no existing merge train', () => {
      factory({
        autoMergeStrategy: MTWPS_MERGE_STRATEGY,
        mergeTrainsCount: 0,
      });

      const statusText = trimText(vm.$el.querySelector('.js-status-text-after-author').innerText);

      expect(statusText).toBe('to start a merge train when the pipeline succeeds');
    });

    it('should render the status text as "...to be added to the merge train" MTWPS is selected and there is an existing merge train', () => {
      factory({
        autoMergeStrategy: MTWPS_MERGE_STRATEGY,
        mergeTrainsCount: 1,
      });

      const statusText = trimText(vm.$el.querySelector('.js-status-text-after-author').innerText);

      expect(statusText).toBe('to be added to the merge train when the pipeline succeeds');
    });

    it('should render the cancel button as "Cancel automatic merge" if MTWPS is selected', () => {
      factory({ autoMergeStrategy: MTWPS_MERGE_STRATEGY });

      const cancelButtonText = trimText(vm.$el.querySelector('.js-cancel-auto-merge').innerText);

      expect(cancelButtonText).toBe('Cancel automatic merge');
    });
  });

  it('should render the cancel button as "Remove from merge train" if the pipeline has been added to the merge train', () => {
    factory({ autoMergeStrategy: MT_MERGE_STRATEGY });

    const cancelButtonText = trimText(vm.$el.querySelector('.js-cancel-auto-merge').innerText);

    expect(cancelButtonText).toBe('Remove from merge train');
  });
});
