import { mount } from '@vue/test-utils';
import PackageTags from 'ee/packages/shared/components/package_tags.vue';
import { mockTags } from '../../mock_data';

describe('PackageTags', () => {
  let wrapper;

  function createComponent(tags = [], props = {}) {
    const propsData = {
      tags,
      ...props,
    };

    wrapper = mount(PackageTags, {
      propsData,
    });
  }

  const tagLabel = () => wrapper.find({ ref: 'tagLabel' });
  const tagBadges = () => wrapper.findAll({ ref: 'tagBadge' });
  const moreBadge = () => wrapper.find({ ref: 'moreBadge' });

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe('tag label', () => {
    it('shows the tag label by default', () => {
      createComponent();

      expect(tagLabel().exists()).toBe(true);
    });

    it('hides when hideLabel prop is set to true', () => {
      createComponent(mockTags, { hideLabel: true });

      expect(tagLabel().exists()).toBe(false);
    });
  });

  it('renders the correct number of tags', () => {
    createComponent(mockTags.slice(0, 2));

    expect(tagBadges()).toHaveLength(2);
    expect(moreBadge().exists()).toBe(false);
  });

  it('does not render more than the configured tagDisplayLimit', () => {
    createComponent(mockTags);

    expect(tagBadges()).toHaveLength(2);
  });

  it('renders the more tags badge if there are more than the configured limit', () => {
    createComponent(mockTags);

    expect(tagBadges()).toHaveLength(2);
    expect(moreBadge().exists()).toBe(true);
    expect(moreBadge().text()).toContain('2');
  });

  it('renders the configured tagDisplayLimit when set in props', () => {
    createComponent(mockTags, { tagDisplayLimit: 1 });

    expect(tagBadges()).toHaveLength(1);
    expect(moreBadge().exists()).toBe(true);
    expect(moreBadge().text()).toContain('3');
  });

  describe('tagBadgeStyle', () => {
    const defaultStyle = ['badge', 'badge-info', 'd-none'];

    it('shows tag badge when there is only one', () => {
      createComponent([mockTags[0]]);

      const expectedStyle = [...defaultStyle, 'd-block', 'prepend-left-8'];

      expect(
        tagBadges()
          .at(0)
          .classes(),
      ).toEqual(expectedStyle);
    });

    it('shows tag badge for medium or heigher resolutions', () => {
      createComponent(mockTags);

      const expectedStyle = [...defaultStyle, 'd-md-block'];

      expect(
        tagBadges()
          .at(1)
          .classes(),
      ).toEqual(expectedStyle);
    });

    it('correctly prepends left and appends right when there is more than one tag', () => {
      createComponent(mockTags, {
        tagDisplayLimit: 4,
      });

      const expectedStyleWithoutAppend = [...defaultStyle, 'd-md-block'];
      const expectedStyleWithAppend = [...expectedStyleWithoutAppend, 'append-right-4'];

      const allBadges = tagBadges();

      expect(allBadges.at(0).classes()).toEqual([...expectedStyleWithAppend, 'prepend-left-8']);
      expect(allBadges.at(1).classes()).toEqual(expectedStyleWithAppend);
      expect(allBadges.at(2).classes()).toEqual(expectedStyleWithAppend);
      expect(allBadges.at(3).classes()).toEqual(expectedStyleWithoutAppend);
    });
  });
});
