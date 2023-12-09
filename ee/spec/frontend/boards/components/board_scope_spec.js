import { mount } from '@vue/test-utils';
import BoardScope from 'ee/boards/components/board_scope.vue';
import { TEST_HOST } from 'helpers/test_constants';

describe('BoardScope', () => {
  let wrapper;
  let vm;

  beforeEach(() => {
    const propsData = {
      collapseScope: false,
      canAdminBoard: false,
      board: {
        labels: [],
        assignee: {},
      },
      milestonePath: `${TEST_HOST}/milestones`,
      labelsPath: `${TEST_HOST}/labels`,
    };

    wrapper = mount(BoardScope, {
      propsData,
    });

    ({ vm } = wrapper);
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('methods', () => {
    describe('handleLabelClick', () => {
      const label = {
        id: 1,
        title: 'Foo',
        color: ['#BADA55'],
        text_color: '#FFFFFF',
      };

      it('initializes `board.labels` as empty array when `label.isAny` is `true`', () => {
        const labelIsAny = { isAny: true };
        vm.handleLabelClick(labelIsAny);

        expect(Array.isArray(vm.board.labels)).toBe(true);
        expect(vm.board.labels.length).toBe(0);
      });

      it('adds provided `label` to board.labels', () => {
        vm.handleLabelClick(label);

        expect(vm.board.labels.length).toBe(1);
        expect(vm.board.labels[0].id).toBe(label.id);
        vm.handleLabelClick(label);
      });
    });
  });
});
