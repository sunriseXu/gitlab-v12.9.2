import { isNumber } from 'underscore';
import { getDatesInRange } from '~/lib/utils/datetime_utility';
import {
  isStartEvent,
  isLabelEvent,
  getAllowedEndEvents,
  eventToOption,
  eventsByIdentifier,
  getLabelEventsIdentifiers,
  flattenDurationChartData,
  getDurationChartData,
  getDurationChartMedianData,
  transformRawStages,
  isPersistedStage,
  getTasksByTypeData,
  flattenTaskByTypeSeries,
  orderByDate,
  toggleSelectedLabel,
} from 'ee/analytics/cycle_analytics/utils';
import { toYmd } from 'ee/analytics/shared/utils';
import {
  customStageEvents as events,
  customStageLabelEvents as labelEvents,
  labelStartEvent,
  customStageStartEvents as startEvents,
  transformedDurationData,
  transformedDurationMedianData,
  flattenedDurationData,
  durationChartPlottableData,
  durationChartPlottableMedianData,
  startDate,
  endDate,
  issueStage,
  rawCustomStage,
  transformedTasksByTypeData,
} from './mock_data';

const labelEventIds = labelEvents.map(ev => ev.identifier);

describe('Cycle analytics utils', () => {
  describe('isStartEvent', () => {
    it('will return true for a valid start event', () => {
      expect(isStartEvent(startEvents[0])).toEqual(true);
    });

    it('will return false for input that is not a start event', () => {
      [{ identifier: 'fake-event', canBeStartEvent: false }, {}, [], null, undefined].forEach(
        ev => {
          expect(isStartEvent(ev)).toEqual(false);
        },
      );
    });
  });

  describe('isLabelEvent', () => {
    it('will return true if the given event identifier is in the labelEvents array', () => {
      expect(isLabelEvent(labelEventIds, labelStartEvent.identifier)).toEqual(true);
    });

    it('will return false if the given event identifier is not in the labelEvents array', () => {
      [startEvents[1].identifier, null, undefined, ''].forEach(ev => {
        expect(isLabelEvent(labelEventIds, ev)).toEqual(false);
      });
      expect(isLabelEvent(labelEventIds)).toEqual(false);
    });
  });

  describe('eventToOption', () => {
    it('will return null if no valid object is passed in', () => {
      [{}, [], null, undefined].forEach(i => {
        expect(eventToOption(i)).toEqual(null);
      });
    });

    it('will set the "value" property to the events identifier', () => {
      events.forEach(ev => {
        const res = eventToOption(ev);
        expect(res.value).toEqual(ev.identifier);
      });
    });

    it('will set the "text" property to the events name', () => {
      events.forEach(ev => {
        const res = eventToOption(ev);
        expect(res.text).toEqual(ev.name);
      });
    });
  });

  describe('getLabelEventsIdentifiers', () => {
    it('will return an array of identifiers for the label events', () => {
      const res = getLabelEventsIdentifiers(events);
      expect(res).toEqual(labelEventIds);
    });

    it('will return an empty array when there are no matches', () => {
      const ev = [{ _type: 'simple' }, { type: 'simple' }, { t: 'simple' }];
      expect(getLabelEventsIdentifiers(ev)).toEqual([]);
      expect(getLabelEventsIdentifiers([])).toEqual([]);
    });
  });

  describe('getAllowedEndEvents', () => {
    it('will return the relevant end events for a given start event identifier', () => {
      const se = events[0];
      expect(getAllowedEndEvents(events, se.identifier)).toEqual(se.allowedEndEvents);
    });

    it('will return an empty array if there are no end events available', () => {
      ['cool_issue_label_added', [], {}, null, undefined].forEach(ev => {
        expect(getAllowedEndEvents(events, ev)).toEqual([]);
      });
    });
  });

  describe('eventsByIdentifier', () => {
    it('will return the events with an identifier in the provided array', () => {
      expect(eventsByIdentifier(events, labelEventIds)).toEqual(labelEvents);
    });

    it('will return an empty array if there are no matching events', () => {
      [['lol', 'bad'], [], {}, null, undefined].forEach(items => {
        expect(eventsByIdentifier(events, items)).toEqual([]);
      });
      expect(eventsByIdentifier([], labelEvents)).toEqual([]);
    });
  });

  describe('flattenDurationChartData', () => {
    it('flattens the data as expected', () => {
      const flattenedData = flattenDurationChartData(transformedDurationData);

      expect(flattenedData).toStrictEqual(flattenedDurationData);
    });
  });

  describe('cycleAnalyticsDurationChart', () => {
    it('computes the plottable data as expected', () => {
      const plottableData = getDurationChartData(transformedDurationData, startDate, endDate);

      expect(plottableData).toStrictEqual(durationChartPlottableData);
    });
  });

  describe('getDurationChartMedianData', () => {
    it('computes the plottable data as expected', () => {
      const plottableData = getDurationChartMedianData(
        transformedDurationMedianData,
        startDate,
        endDate,
      );

      expect(plottableData).toStrictEqual(durationChartPlottableMedianData);
    });
  });

  describe('transformRawStages', () => {
    it('retains all the stage properties', () => {
      const transformed = transformRawStages([issueStage, rawCustomStage]);
      expect(transformed).toMatchSnapshot();
    });

    it('converts object properties from snake_case to camelCase', () => {
      const [transformedCustomStage] = transformRawStages([rawCustomStage]);
      expect(transformedCustomStage).toMatchObject({
        endEventIdentifier: 'issue_first_added_to_board',
        startEventIdentifier: 'issue_first_mentioned_in_commit',
      });
    });

    it('sets the slug to the value of the stage id', () => {
      const transformed = transformRawStages([issueStage, rawCustomStage]);
      transformed.forEach(t => {
        expect(t.slug).toEqual(t.id);
      });
    });

    it('sets the name to the value of the stage title if its not set', () => {
      const transformed = transformRawStages([issueStage, rawCustomStage]);
      transformed.forEach(t => {
        expect(t.name.length > 0).toBe(true);
        expect(t.name).toEqual(t.title);
      });
    });
  });

  describe('isPersistedStage', () => {
    it.each`
      custom   | id                    | expected
      ${true}  | ${'this-is-a-string'} | ${true}
      ${true}  | ${42}                 | ${true}
      ${false} | ${42}                 | ${true}
      ${false} | ${'this-is-a-string'} | ${false}
    `('with custom=$custom and id=$id', ({ custom, id, expected }) => {
      expect(isPersistedStage({ custom, id })).toEqual(expected);
    });
  });

  describe('flattenTaskByTypeSeries', () => {
    const dummySeries = Object.fromEntries([
      ['2019-01-16', 40],
      ['2019-01-14', 20],
      ['2019-01-12', 10],
      ['2019-01-15', 30],
    ]);

    let transformedDummySeries = [];

    beforeEach(() => {
      transformedDummySeries = flattenTaskByTypeSeries(dummySeries);
    });

    it('extracts the value from an array of datetime / value pairs', () => {
      expect(transformedDummySeries.every(isNumber)).toEqual(true);
      Object.values(dummySeries).forEach(v => {
        expect(transformedDummySeries.includes(v)).toBeTruthy();
      });
    });

    it('sorts the items by the datetime parameter', () => {
      expect(transformedDummySeries).toEqual([10, 20, 30, 40]);
    });
  });

  describe('orderByDate', () => {
    it('sorts dates from the earliest to latest', () => {
      expect(['2019-01-14', '2019-01-12', '2019-01-16', '2019-01-15'].sort(orderByDate)).toEqual([
        '2019-01-12',
        '2019-01-14',
        '2019-01-15',
        '2019-01-16',
      ]);
    });
  });

  describe('getTasksByTypeData', () => {
    let transformed = {};

    const groupBy = getDatesInRange(startDate, endDate, toYmd);
    // only return the values, drop the date which is the first paramater
    const extractSeriesValues = ({ series }) => series.map(kv => kv[1]);
    const data = transformedTasksByTypeData.map(extractSeriesValues);

    const labels = transformedTasksByTypeData.map(d => {
      const { label } = d;
      return label.title;
    });

    it('will return blank arrays if given no data', () => {
      [{ data: [], startDate, endDate }, [], {}].forEach(chartData => {
        transformed = getTasksByTypeData(chartData);
        ['seriesNames', 'data', 'groupBy'].forEach(key => {
          expect(transformed[key]).toEqual([]);
        });
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        transformed = getTasksByTypeData({ data: transformedTasksByTypeData, startDate, endDate });
      });

      it('will return an object with the properties needed for the chart', () => {
        ['seriesNames', 'data', 'groupBy'].forEach(key => {
          expect(transformed).toHaveProperty(key);
        });
      });

      describe('seriesNames', () => {
        it('returns the names of all the labels in the dataset', () => {
          expect(transformed.seriesNames).toEqual(labels);
        });
      });

      describe('groupBy', () => {
        it('returns the date groupBy as an array', () => {
          expect(transformed.groupBy).toEqual(groupBy);
        });

        it('the start date is the first element', () => {
          expect(transformed.groupBy[0]).toEqual(toYmd(startDate));
        });

        it('the end date is the last element', () => {
          expect(transformed.groupBy[transformed.groupBy.length - 1]).toEqual(toYmd(endDate));
        });
      });

      describe('data', () => {
        it('returns an array of data points', () => {
          expect(transformed.data).toEqual(data);
        });

        it('contains an array of data for each label', () => {
          expect(transformed.data.length).toEqual(labels.length);
        });

        it('contains a value for each day in the groupBy', () => {
          transformed.data.forEach(d => {
            expect(d.length).toEqual(transformed.groupBy.length);
          });
        });
      });
    });
  });

  describe('toggleSelectedLabel', () => {
    const selectedLabelIds = [1, 2, 3];

    it('will return the array if theres no value given', () => {
      expect(toggleSelectedLabel({ selectedLabelIds })).toEqual([1, 2, 3]);
    });

    it('will remove an id that exists', () => {
      expect(toggleSelectedLabel({ selectedLabelIds, value: 2 })).toEqual([1, 3]);
    });
    it('will add an id that does not exist', () => {
      expect(toggleSelectedLabel({ selectedLabelIds, value: 4 })).toEqual([1, 2, 3, 4]);
    });
  });
});
