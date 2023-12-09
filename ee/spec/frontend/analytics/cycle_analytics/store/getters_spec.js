import * as getters from 'ee/analytics/cycle_analytics/store/getters';
import {
  startDate,
  endDate,
  transformedDurationData,
  transformedDurationMedianData,
  durationChartPlottableData,
  durationChartPlottableMedianData,
  allowedStages,
  selectedProjects,
} from '../mock_data';

let state = null;

describe('Cycle analytics getters', () => {
  describe('hasNoAccessError', () => {
    beforeEach(() => {
      state = {
        errorCode: null,
      };
    });

    it('returns true if "hasError" is set to 403', () => {
      state.errorCode = 403;
      expect(getters.hasNoAccessError(state)).toEqual(true);
    });

    it('returns false if "hasError" is not set to 403', () => {
      expect(getters.hasNoAccessError(state)).toEqual(false);
    });
  });

  describe('selectedProjectIds', () => {
    describe('with selectedProjects set', () => {
      it('returns the ids of each project', () => {
        state = {
          selectedProjects,
        };

        expect(getters.selectedProjectIds(state)).toEqual([1, 2]);
      });
    });

    describe('without selectedProjects set', () => {
      it('will return an empty array', () => {
        state = { selectedProjects: [] };
        expect(getters.selectedProjectIds(state)).toEqual([]);
      });
    });
  });

  describe('currentGroupPath', () => {
    describe('with selectedGroup set', () => {
      it('returns the `fullPath` value of the group', () => {
        const fullPath = 'cool-beans';
        state = {
          selectedGroup: {
            fullPath,
          },
        };

        expect(getters.currentGroupPath(state)).toEqual(fullPath);
      });
    });

    describe('without a selectedGroup set', () => {
      it.each([[''], [{}], [null]])('given %s will return null', value => {
        state = { selectedGroup: value };
        expect(getters.currentGroupPath(state)).toEqual(null);
      });
    });
  });

  describe('cycleAnalyticsRequestParams', () => {
    beforeEach(() => {
      const fullPath = 'cool-beans';
      state = {
        selectedGroup: {
          fullPath,
        },
        startDate,
        endDate,
        selectedProjects,
      };
    });

    it.each`
      param               | value
      ${'created_after'}  | ${'2018-12-15'}
      ${'created_before'} | ${'2019-01-14'}
      ${'project_ids'}    | ${[1, 2]}
    `('should return the $param with value $value', ({ param, value }) => {
      expect(
        getters.cycleAnalyticsRequestParams(state, { selectedProjectIds: [1, 2] }),
      ).toMatchObject({
        [param]: value,
      });
    });
  });

  describe('durationChartPlottableData', () => {
    it('returns plottable data for selected stages', () => {
      const stateWithDurationData = {
        startDate,
        endDate,
        durationData: transformedDurationData,
      };

      expect(getters.durationChartPlottableData(stateWithDurationData)).toEqual(
        durationChartPlottableData,
      );
    });

    it('returns null if there is no plottable data for the selected stages', () => {
      const stateWithDurationData = {
        startDate,
        endDate,
        durationData: [],
      };

      expect(getters.durationChartPlottableData(stateWithDurationData)).toBeNull();
    });
  });

  describe('durationChartPlottableMedianData', () => {
    it('returns plottable median data for selected stages', () => {
      const stateWithDurationMedianData = {
        startDate,
        endDate,
        durationMedianData: transformedDurationMedianData,
      };

      expect(getters.durationChartMedianData(stateWithDurationMedianData)).toEqual(
        durationChartPlottableMedianData,
      );
    });

    it('returns an empty array if there is no plottable median data for the selected stages', () => {
      const stateWithDurationMedianData = {
        startDate,
        endDate,
        durationMedianData: [],
      };

      expect(getters.durationChartMedianData(stateWithDurationMedianData)).toEqual([]);
    });
  });

  const hiddenStage = { ...allowedStages[2], hidden: true };
  const givenStages = [allowedStages[0], allowedStages[1], hiddenStage];
  describe.each`
    func              | givenStages    | expectedStages
    ${'hiddenStages'} | ${givenStages} | ${[hiddenStage]}
    ${'activeStages'} | ${givenStages} | ${[allowedStages[0], allowedStages[1]]}
  `('hiddenStages', ({ func, expectedStages, givenStages: stages }) => {
    it(`'${func}' returns ${expectedStages.length} stages`, () => {
      expect(getters[func]({ stages })).toEqual(expectedStages);
    });

    it(`'${func}' returns an empty array if there are no stages`, () => {
      expect(getters[func]({ stages: [] })).toEqual([]);
    });
  });
});
