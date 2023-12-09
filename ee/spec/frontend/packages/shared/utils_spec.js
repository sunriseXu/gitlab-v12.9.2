import { packageTypeToTrackCategory, beautifyPath } from 'ee/packages/shared/utils';
import { PackageType, TrackingCategories } from 'ee/packages/shared/constants';

describe('Packages shared utils', () => {
  describe('packageTypeToTrackCategory', () => {
    it('prepend UI to package category', () => {
      expect(packageTypeToTrackCategory()).toMatchInlineSnapshot(`"UI::undefined"`);
    });

    it.each(Object.keys(PackageType))('returns a correct category string for %s', packageKey => {
      const packageName = PackageType[packageKey];
      expect(packageTypeToTrackCategory(packageName)).toBe(
        `UI::${TrackingCategories[packageName]}`,
      );
    });
  });
  describe('beautifyPath', () => {
    it('returns a string with spaces around /', () => {
      expect(beautifyPath('foo/bar')).toBe('foo / bar');
    });
    it('does not fail for empty string', () => {
      expect(beautifyPath()).toBe('');
    });
  });
});
