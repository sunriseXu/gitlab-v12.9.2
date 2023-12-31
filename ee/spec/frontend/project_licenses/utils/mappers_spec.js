import { toLicenseObject } from 'ee/project_licenses/utils/mappers';

const UNIQUE_ID = 'fakeUniqueId';
jest.mock('underscore', () => ({
  uniqueId: () => 'fakeUniqueId',
}));

describe('ee/project_licenses/utils/mappers', () => {
  describe('toLicenseObject', () => {
    describe.each`
      input                         | key
      ${{ id: 1, name: 'TEST' }}    | ${'id_1'}
      ${{ id: 2001, name: 'TEST' }} | ${'id_2001'}
      ${{ name: 'TEST' }}           | ${`client_${UNIQUE_ID}`}
    `('with object $input', ({ input, key }) => {
      it(`sets the key to ${key}`, () => {
        const result = toLicenseObject(input);

        expect(result).toEqual({
          ...input,
          key,
        });
      });
    });
  });
});
