import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import Project from 'ee/storage_counter/components/project.vue';
import ProjectAvatar from '~/vue_shared/components/project_avatar/default.vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';

let wrapper;
const data = {
  id: '8',
  fullPath: 'h5bp/html5-boilerplate',
  nameWithNamespace: 'H5bp / Html5 Boilerplate',
  avatarUrl: null,
  webUrl: 'http://localhost:3001/h5bp/html5-boilerplate',
  name: 'Html5 Boilerplate',
  statistics: {
    commitCount: 0,
    storageSize: 1293346,
    repositorySize: 0,
    lfsObjectsSize: 0,
    buildArtifactsSize: 1272375,
    packagesSize: 0,
  },
};

function factory(project) {
  wrapper = shallowMount(Project, {
    propsData: {
      project,
    },
  });
}

describe('Storage Counter project component', () => {
  beforeEach(() => {
    factory(data);
  });

  it('renders project avatar', () => {
    expect(wrapper.contains(ProjectAvatar)).toBe(true);
  });

  it('renders project name', () => {
    expect(wrapper.text()).toContain(data.nameWithNamespace);
  });

  it('renders formatted storage size', () => {
    expect(wrapper.text()).toContain(numberToHumanSize(data.statistics.storageSize));
  });

  describe('toggle row', () => {
    describe('on click', () => {
      it('toggles isOpen', () => {
        expect(wrapper.vm.isOpen).toEqual(false);

        wrapper.find(GlButton).vm.$emit('click');

        expect(wrapper.vm.isOpen).toEqual(true);

        wrapper.find(GlButton).vm.$emit('click');

        expect(wrapper.vm.isOpen).toEqual(false);
      });
    });
  });
});
