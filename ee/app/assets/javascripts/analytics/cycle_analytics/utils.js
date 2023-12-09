import { isNumber } from 'underscore';
import dateFormat from 'dateformat';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import { hideFlash } from '~/flash';
import {
  newDate,
  dayAfter,
  secondsToDays,
  getDatesInRange,
  getDayDifference,
  getDateInPast,
  getDateInFuture,
} from '~/lib/utils/datetime_utility';
import { dateFormats } from '../shared/constants';
import { STAGE_NAME } from './constants';
import { toYmd } from '../shared/utils';

const EVENT_TYPE_LABEL = 'label';

export const removeFlash = (type = 'alert') => {
  const flashEl = document.querySelector(`.flash-${type}`);
  if (flashEl) {
    hideFlash(flashEl);
  }
};

export const toggleSelectedLabel = ({ selectedLabelIds = [], value = null }) => {
  if (!value) return selectedLabelIds;
  return selectedLabelIds.includes(value)
    ? selectedLabelIds.filter(v => v !== value)
    : [...selectedLabelIds, value];
};

export const isStartEvent = ev => Boolean(ev) && Boolean(ev.canBeStartEvent) && ev.canBeStartEvent;

export const eventToOption = (obj = null) => {
  if (!obj || (!obj.text && !obj.identifier)) return null;
  const { name: text = '', identifier: value = null } = obj;
  return { text, value };
};

export const getAllowedEndEvents = (events = [], targetIdentifier = null) => {
  if (!targetIdentifier || !events.length) return [];
  const st = events.find(({ identifier }) => identifier === targetIdentifier);
  return st && st.allowedEndEvents ? st.allowedEndEvents : [];
};

export const eventsByIdentifier = (events = [], targetIdentifier = []) => {
  if (!targetIdentifier || !targetIdentifier.length || !events.length) return [];
  return events.filter(({ identifier = '' }) => targetIdentifier.includes(identifier));
};

export const isLabelEvent = (labelEvents = [], ev = null) =>
  Boolean(ev) && labelEvents.length && labelEvents.includes(ev);

export const getLabelEventsIdentifiers = (events = []) =>
  events.filter(ev => ev.type && ev.type === EVENT_TYPE_LABEL).map(i => i.identifier);

/**
 * Checks if the specified stage is in memory or persisted to storage based on the id
 *
 * Default value stream analytics stages are initially stored in memory, when they are first
 * created the id for the stage is the name of the stage in lowercase. This string id
 * is used to fetch stage data (events, median calculation)
 *
 * When either a custom stage is created or an edit is made to a default stage then the
 * default stages get persisted to storage and will have a numeric id. The new numeric
 * id should then be used to access stage data
 *
 */
export const isPersistedStage = ({ custom, id }) => custom || isNumber(id);

/**
 * Returns the the correct slug to use for a stage
 * default stages use the snakecased title of the stage, while custom
 * stages will have a numeric id
 *
 * @param {Object} obj
 * @param {string} obj.title - title of the stage
 * @param {number} obj.id - numerical object id available for custom stages
 * @param {boolean} obj.custom - boolean flag indicating a custom stage
 * @returns {(number|string)} Returns a numerical id for customs stages and string for default stages
 */
const stageUrlSlug = ({ id, title, custom = false }) => {
  if (custom) return id;
  // We still use 'production' as the id to access this stage, even though the title is 'Total'
  return title.toLowerCase() === STAGE_NAME.TOTAL
    ? STAGE_NAME.PRODUCTION
    : convertToSnakeCase(title);
};

export const transformRawStages = (stages = []) =>
  stages.map(({ id, title, name = '', custom = false, ...rest }) => ({
    ...convertObjectPropsToCamelCase(rest, { deep: true }),
    id,
    title,
    custom,
    slug: isPersistedStage({ custom, id }) ? id : stageUrlSlug({ custom, id, title }),
    // the name field is used to create a stage, but the get request returns title
    name: name.length ? name : title,
  }));

export const transformRawTasksByTypeData = (data = []) => {
  if (!data.length) return [];
  return data.map(d => convertObjectPropsToCamelCase(d, { deep: true }));
};

/**
 * Takes the duration data for selected stages, transforms the date values and returns
 * the data in a flattened array
 *
 * The received data is expected to be the following format; One top level object in the array per stage,
 * each potentially having multiple data entries.
 * [
 *   {
 *    slug: 'issue',
 *    selected: true,
 *    data: [
 *      {
 *        'duration_in_seconds': 1234,
 *        'finished_at': '2019-09-02T18:25:43.511Z'
 *      },
 *      ...
 *    ]
 *   },
 *   ...
 * ]
 *
 * The data is then transformed and flattened into the following format;
 * [
 *  {
 *    'duration_in_seconds': 1234,
 *    'finished_at': '2019-09-02'
 *  },
 *  ...
 * ]
 *
 * @param {Array} data - The duration data for selected stages
 * @returns {Array} An array with each item being an object containing the duration_in_seconds and finished_at values for an event
 */
export const flattenDurationChartData = data =>
  data
    .map(stage =>
      stage.data.map(event => {
        const date = new Date(event.finished_at);
        return {
          ...event,
          finished_at: dateFormat(date, dateFormats.isoDate),
        };
      }),
    )
    .flat();

/**
 * Takes the duration data for selected stages, groups the data by day and calculates the total duration
 * per day.
 *
 * The received data is expected to be the following format; One top level object in the array per stage,
 * each potentially having multiple data entries.
 * [
 *   {
 *    slug: 'issue',
 *    selected: true,
 *    data: [
 *      {
 *        'duration_in_seconds': 1234,
 *        'finished_at': '2019-09-02T18:25:43.511Z'
 *      },
 *      ...
 *    ]
 *   },
 *   ...
 * ]
 *
 * The data is then computed and transformed into a format that can be passed to the chart:
 * [
 *  ['2019-09-02', 7, '2019-09-02'],
 *  ['2019-09-03', 10, '2019-09-03'],
 *  ['2019-09-04', 8, '2019-09-04'],
 *  ...
 * ]
 *
 * In the data above, each array i represents a point in the scatterplot with the following data:
 * i[0] = date, displayed on x axis
 * i[1] = metric, displayed on y axis
 * i[2] = date, used in the tooltip
 *
 * @param {Array} data - The duration data for selected stages
 * @param {Date} startDate - The globally selected cycle analytics start date
 * @param {Date} endDate - The globally selected cycle analytics end date
 * @returns {Array} An array with each item being another arry of three items (plottable date, computed total, tooltip display date)
 */
export const getDurationChartData = (data, startDate, endDate) => {
  const flattenedData = flattenDurationChartData(data);
  const eventData = [];

  for (
    let currentDate = newDate(startDate);
    currentDate <= endDate;
    currentDate = dayAfter(currentDate)
  ) {
    const currentISODate = dateFormat(newDate(currentDate), dateFormats.isoDate);
    const valuesForDay = flattenedData.filter(object => object.finished_at === currentISODate);
    const summedData = valuesForDay.reduce((total, value) => total + value.duration_in_seconds, 0);
    const summedDataInDays = secondsToDays(summedData);

    if (summedDataInDays) eventData.push([currentISODate, summedDataInDays, currentISODate]);
  }

  return eventData;
};

/**
 * Takes the offset duration data for selected stages and calls getDurationChartData to compute the totals.
 * The data is then transformed into a format expected by the scatterplot;
 *
 * [
 *   ['2019-09-02', 7],
 *   ...
 * ]
 *
 * The transformation works by calling getDateInPast on the provided startDate and endDate in order to match
 * the startDate and endDate fetched when making the API call to fetch the data.
 *
 * In order to map the offset data to plottable points within the chart's range, getDateInFuture is called
 * on the data series with the same offest used for getDateInPast. This creates plottable data that matches up
 * with the data being displayed on the chart.
 *
 * @param {Array} data - The computed, plottable duration chart data
 * @param {Date} startDate - The globally selected cycle analytics start date
 * @param {Date} endDate - The globally selected cycle analytics end date
 * @returns {Array} An array with each item being another arry of two items (date, computed total)
 */
export const getDurationChartMedianData = (data, startDate, endDate) => {
  const offsetValue = getDayDifference(startDate, endDate);
  const offsetEndDate = getDateInPast(endDate, offsetValue);
  const offsetStartDate = getDateInPast(startDate, offsetValue);

  const offsetDurationData = getDurationChartData(data, offsetStartDate, offsetEndDate);

  const result = offsetDurationData.map(event => [
    dateFormat(getDateInFuture(new Date(event[0]), offsetValue), dateFormats.isoDate),
    event[1],
  ]);

  return result;
};

export const orderByDate = (a, b, dateFmt = datetime => new Date(datetime).getTime()) =>
  dateFmt(a) - dateFmt(b);

/**
 * Takes a dictionary of dates and the associated value, sorts them and returns just the value
 *
 * @param {Object.<Date, number>} series - Key value pair of dates and the value for that date
 * @returns {number[]} The values of each key value pair
 */
export const flattenTaskByTypeSeries = (series = {}) =>
  Object.entries(series)
    .sort((a, b) => orderByDate(a[0], b[0]))
    .map(dataSet => dataSet[1]);

/**
 * @typedef {Object} RawTasksByTypeData
 * @property {Object} label - Raw data for a group label
 * @property {Array} series - Array of arrays with date and associated value ie [ ['2020-01-01', 10],['2020-01-02', 10] ]

 * @typedef {Object} TransformedTasksByTypeData
 * @property {Array} groupBy - The list of dates for the range of data in each data series
 * @property {Array} data - An array of the data values for each series
 * @property {Array} seriesNames - Names of the series to be charted ie label names
 */

/**
 * Takes the raw tasks by type data and generates an array of data points,
 * an array of data series and an array of data labels for the given time period.
 *
 * Currently the data is transformed to support use in a stacked column chart:
 * https://gitlab-org.gitlab.io/gitlab-ui/?path=/story/charts-stacked-column-chart--stacked
 *
 * @param {Object} obj
 * @param {RawTasksByTypeData[]} obj.data - array of raw data, each element contains a label and series
 * @param {Date} obj.startDate - start date in ISO date format
 * @param {Date} obj.endDate - end date in ISO date format
 *
 * @returns {TransformedTasksByTypeData} The transformed data ready for use in charts
 */
export const getTasksByTypeData = ({ data = [], startDate = null, endDate = null }) => {
  if (!startDate || !endDate || !data.length) {
    return {
      groupBy: [],
      data: [],
      seriesNames: [],
    };
  }

  const groupBy = getDatesInRange(startDate, endDate, toYmd).sort(orderByDate);
  const zeroValuesForEachDataPoint = groupBy.reduce(
    (acc, date) => ({
      ...acc,
      [date]: 0,
    }),
    {},
  );

  const transformed = data.reduce(
    (acc, curr) => {
      const {
        label: { title },
        series,
      } = curr;
      acc.seriesNames = [...acc.seriesNames, title];
      acc.data = [
        ...acc.data,
        // adds 0 values for each data point and overrides with data from the series
        flattenTaskByTypeSeries({ ...zeroValuesForEachDataPoint, ...Object.fromEntries(series) }),
      ];
      return acc;
    },
    {
      data: [],
      seriesNames: [],
    },
  );

  return {
    ...transformed,
    groupBy,
  };
};
