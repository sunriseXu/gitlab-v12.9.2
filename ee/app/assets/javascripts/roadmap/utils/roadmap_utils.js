import { newDate, getTimeframeWindowFrom, totalDaysInMonth } from '~/lib/utils/datetime_utility';

import {
  PRESET_TYPES,
  PRESET_DEFAULTS,
  EXTEND_AS,
  TIMELINE_CELL_MIN_WIDTH,
  DAYS_IN_WEEK,
  PAST_DATE,
  FUTURE_DATE,
} from '../constants';

const monthsForQuarters = {
  1: [0, 1, 2],
  2: [3, 4, 5],
  3: [6, 7, 8],
  4: [9, 10, 11],
};

/**
 * This method returns array of Objects representing Quarters based on provided initialDate
 *
 * For eg; If initialDate is 15th Jan 2018
 *         Then as per Roadmap specs, we need to show
 *         2 quarters before current quarters
 *         current quarter AND
 *         4 quarters after current quarter
 *         thus, total of 7 quarters (21 Months).
 *
 * So returned array from this method will be;
 *        [
 *          {
 *            quarterSequence: 4,
 *            year: 2017,
 *            range: [
 *              1 Oct 2017,
 *              1 Nov 2017,
 *              31 Dec 2017,
 *            ],
 *          },
 *          {
 *            quarterSequence: 1,
 *            year: 2018,
 *            range: [
 *              1 Jan 2018,
 *              1 Feb 2018,
 *              31 Mar 2018,
 *            ],
 *          },
 *          ....
 *          ....
 *          ....
 *          {
 *            quarterSequence: 1,
 *            year: 2019,
 *            range: [
 *              1 Jan 2019,
 *              1 Feb 2019,
 *              31 Mar 2019,
 *            ],
 *          },
 *        ]
 *
 * @param {Date} initialDate
 */
export const getTimeframeForQuartersView = (initialDate = new Date(), timeframe = []) => {
  const startDate = newDate(initialDate);
  startDate.setHours(0, 0, 0, 0);

  if (!timeframe.length) {
    // Get current quarter for current month
    const currentQuarter = Math.floor((startDate.getMonth() + 3) / 3);
    // Get index of current month in current quarter
    // It could be 0, 1, 2 (i.e. first, second or third)
    const currentMonthInCurrentQuarter = monthsForQuarters[currentQuarter].indexOf(
      startDate.getMonth(),
    );

    // To move start back to first month of 2 quarters prior by
    // adding quarter size (3 + 3) to month order will give us
    // exact number of months we need to go back in time
    const startMonth = currentMonthInCurrentQuarter + 6;
    // Move startDate to first month of previous quarter
    startDate.setMonth(startDate.getMonth() - startMonth);

    // Get timeframe for the length we determined for this preset
    // start from the startDate
    timeframe.push(...getTimeframeWindowFrom(startDate, PRESET_DEFAULTS.QUARTERS.TIMEFRAME_LENGTH));
  }

  const quartersTimeframe = [];
  // Iterate over the timeframe and break it down
  // in chunks of quarters
  for (let i = 0; i < timeframe.length; i += 3) {
    const range = timeframe.slice(i, i + 3);
    const lastMonthOfQuarter = range[range.length - 1];
    const quarterSequence = Math.floor((range[0].getMonth() + 3) / 3);
    const year = range[0].getFullYear();

    // Ensure that `range` spans across duration of
    // entire quarter
    lastMonthOfQuarter.setDate(totalDaysInMonth(lastMonthOfQuarter));

    quartersTimeframe.push({
      quarterSequence,
      range,
      year,
    });
  }

  return quartersTimeframe;
};

export const extendTimeframeForQuartersView = (initialDate = new Date(), length) => {
  const startDate = newDate(initialDate);
  startDate.setDate(1);

  startDate.setMonth(startDate.getMonth() + (length > 0 ? 1 : -1));
  const timeframe = getTimeframeWindowFrom(startDate, length);

  return getTimeframeForQuartersView(startDate, length > 0 ? timeframe : timeframe.reverse());
};

/**
 * This method returns array of Dates respresenting Months based on provided initialDate
 *
 * For eg; If initialDate is 15th Jan 2018
 *         Then as per Roadmap specs, we need to show
 *         2 months before current month,
 *         current month AND
 *         5 months after current month
 *         thus, total of 8 months.
 *
 * So returned array from this method will be;
 *        [
 *          1 Nov 2017, 1 Dec 2017, 1 Jan 2018, 1 Feb 2018,
 *          1 Mar 2018, 1 Apr 2018, 1 May 2018, 30 Jun 2018
 *        ]
 *
 * @param {Date} initialDate
 */
export const getTimeframeForMonthsView = (initialDate = new Date()) => {
  const startDate = newDate(initialDate);

  // Move startDate to a month prior to current month
  startDate.setMonth(startDate.getMonth() - 2);

  return getTimeframeWindowFrom(startDate, PRESET_DEFAULTS.MONTHS.TIMEFRAME_LENGTH);
};

export const extendTimeframeForMonthsView = (initialDate = new Date(), length) => {
  const startDate = newDate(initialDate);

  // When length is positive (which means extension is of type APPEND)
  // Set initial date as first day of the month.
  if (length > 0) {
    startDate.setDate(1);
  }

  const timeframe = getTimeframeWindowFrom(startDate, length - 1).slice(1);

  return length > 0 ? timeframe : timeframe.reverse();
};

/**
 * This method returns array of Dates respresenting Months based on provided initialDate
 *
 * For eg; If initialDate is 15th Jan 2018
 *         Then as per Roadmap specs, we need to show
 *         2 weeks before current week,
 *         current week AND
 *         4 weeks after current week
 *         thus, total of 7 weeks.
 *         Note that week starts on Sunday
 *
 * So returned array from this method will be;
 *        [
 *          31 Dec 2017, 7 Jan 2018, 14 Jan 2018, 21 Jan 2018,
 *          28 Jan 2018, 4 Mar 2018, 11 Mar 2018
 *        ]
 *
 * @param {Date} initialDate
 */
export const getTimeframeForWeeksView = (initialDate = new Date(), length) => {
  const timeframe = [];
  const startDate = newDate(initialDate);
  startDate.setHours(0, 0, 0, 0);

  // When length is not provided
  // We need to provide standard
  // timeframe as per feature specs (see block comment above)
  if (!length) {
    const dayOfWeek = startDate.getDay();
    const daysToFirstDayOfPrevWeek = dayOfWeek + DAYS_IN_WEEK * 2;

    // Move startDate to first day (Sunday) of 2 weeks prior
    startDate.setDate(startDate.getDate() - daysToFirstDayOfPrevWeek);
  }

  const rangeLength = length || PRESET_DEFAULTS.WEEKS.TIMEFRAME_LENGTH;

  // Iterate for the length of this preset
  for (let i = 0; i < rangeLength; i += 1) {
    // Push date to timeframe only when day is
    // first day (Sunday) of the week
    timeframe.push(newDate(startDate));

    // Move date next Sunday
    startDate.setDate(startDate.getDate() + DAYS_IN_WEEK);
  }

  return timeframe;
};

export const extendTimeframeForWeeksView = (initialDate = new Date(), length) => {
  const startDate = newDate(initialDate);

  if (length < 0) {
    // When length is negative, we need to go
    // back as many weeks in time as value of length
    startDate.setDate(startDate.getDate() + length * DAYS_IN_WEEK);
  }

  return getTimeframeForWeeksView(startDate, Math.abs(length));
};

export const extendTimeframeForPreset = ({
  presetType = PRESET_TYPES.MONTHS,
  extendAs = EXTEND_AS.PREPEND,
  extendByLength = 0,
  initialDate,
}) => {
  if (presetType === PRESET_TYPES.QUARTERS) {
    const length = extendByLength || PRESET_DEFAULTS.QUARTERS.TIMEFRAME_LENGTH;

    return extendTimeframeForQuartersView(
      initialDate,
      extendAs === EXTEND_AS.PREPEND ? -length : length,
    );
  } else if (presetType === PRESET_TYPES.MONTHS) {
    const length = extendByLength || PRESET_DEFAULTS.MONTHS.TIMEFRAME_LENGTH;

    return extendTimeframeForMonthsView(
      initialDate,
      extendAs === EXTEND_AS.PREPEND ? -length : length,
    );
  }

  const length = extendByLength || PRESET_DEFAULTS.WEEKS.TIMEFRAME_LENGTH;

  return extendTimeframeForWeeksView(
    initialDate,
    extendAs === EXTEND_AS.PREPEND ? -length : length,
  );
};

export const extendTimeframeForAvailableWidth = ({
  timeframe,
  timeframeStart,
  timeframeEnd,
  availableTimeframeWidth,
  presetType,
}) => {
  let timeframeLength = timeframe.length;

  // Estimate how many more timeframe columns are needed
  // to fill in extra screen space so that timeline becomes
  // horizontally scrollable.
  while (availableTimeframeWidth / timeframeLength > TIMELINE_CELL_MIN_WIDTH) {
    timeframeLength += 1;
  }
  // We double the increaseLengthBy to make sure there's enough room
  // to perform horizontal scroll without triggering timeframe extension
  // on initial page load.
  let increaseLengthBy = timeframeLength - timeframe.length;

  // Handle a case where window size is leading to
  // increaseLength between 1 & 3 which is not big
  // enough for extendTimeframeFor*****View methods
  if (increaseLengthBy > 0 && increaseLengthBy <= 3) {
    increaseLengthBy += 4; // Equalize by adding 2 columns on each end
  }

  // If there are timeframe items to be added
  // to make timeline scrollable, do as follows.
  if (increaseLengthBy > 0) {
    // Split length in 2 parts and get
    // count for both prepend and append.
    const prependBy = Math.floor(increaseLengthBy / 2);
    const appendBy = Math.ceil(increaseLengthBy / 2);

    if (prependBy) {
      // Prepend the timeline with
      // the count as given by prependBy
      timeframe.unshift(
        ...extendTimeframeForPreset({
          extendAs: EXTEND_AS.PREPEND,
          initialDate: timeframeStart,
          // In case of presetType `quarters`, length would represent
          // number of months for total quarters, hence we do `* 3`.
          extendByLength: presetType === PRESET_TYPES.QUARTERS ? prependBy * 3 : prependBy,
          presetType,
        }),
      );
    }

    if (appendBy) {
      // Append the timeline with
      // the count as given by appendBy
      timeframe.push(
        ...extendTimeframeForPreset({
          extendAs: EXTEND_AS.APPEND,
          initialDate: timeframeEnd,
          // In case of presetType `quarters`, length would represent
          // number of months for total quarters, hence we do `* 3`.
          //
          // For other preset types, we add `2` to appendBy to compensate for
          // last item of original timeframe (month or week)
          extendByLength: presetType === PRESET_TYPES.QUARTERS ? appendBy * 3 : appendBy + 2,
          presetType,
        }),
      );
    }
  }
};

export const getTimeframeForPreset = (
  presetType = PRESET_TYPES.MONTHS,
  availableTimeframeWidth = 0,
) => {
  let timeframe;
  let timeframeStart;
  let timeframeEnd;

  // Get timeframe based on presetType and
  // extract timeframeStart and timeframeEnd
  // date objects
  if (presetType === PRESET_TYPES.QUARTERS) {
    timeframe = getTimeframeForQuartersView();
    [timeframeStart] = timeframe[0].range;
    // eslint-disable-next-line prefer-destructuring
    timeframeEnd = timeframe[timeframe.length - 1].range[2];
  } else if (presetType === PRESET_TYPES.MONTHS) {
    timeframe = getTimeframeForMonthsView();
    [timeframeStart] = timeframe;
    timeframeEnd = timeframe[timeframe.length - 1];
  } else {
    timeframe = getTimeframeForWeeksView();
    timeframeStart = newDate(timeframe[0]);
    timeframeEnd = newDate(timeframe[timeframe.length - 1]);
    timeframeStart.setDate(timeframeStart.getDate());
    timeframeEnd.setDate(timeframeEnd.getDate() + DAYS_IN_WEEK); // Move date ahead by a week
  }

  // Extend timeframe on initial load to ensure
  // timeline is horizontally scrollable in all
  // screen sizes.
  extendTimeframeForAvailableWidth({
    timeframe,
    timeframeStart,
    timeframeEnd,
    availableTimeframeWidth,
    presetType,
  });

  return timeframe;
};

/**
 * Returns timeframe range in string based on provided config.
 *
 * @param {object} config
 * @param {string} config.presetType String representing preset type
 * @param {array} config.timeframe Array of dates representing timeframe
 *
 * @returns {object} Returns an object containing `startDate` & `dueDate` strings
 *                   Computed using presetType and timeframe.
 */
export const getEpicsTimeframeRange = ({ presetType = '', timeframe = [] }) => {
  let start;
  let due;

  const firstTimeframe = timeframe[0];
  const lastTimeframe = timeframe[timeframe.length - 1];

  // Compute start and end dates from timeframe
  // based on provided presetType.
  if (presetType === PRESET_TYPES.QUARTERS) {
    [start] = firstTimeframe.range;
    due = lastTimeframe.range[lastTimeframe.range.length - 1];
  } else if (presetType === PRESET_TYPES.MONTHS) {
    start = firstTimeframe;
    due = lastTimeframe;
  } else if (presetType === PRESET_TYPES.WEEKS) {
    start = firstTimeframe;
    due = newDate(lastTimeframe);
    due.setDate(due.getDate() + 6);
  }

  const startDate = `${start.getFullYear()}-${start.getMonth() + 1}-${start.getDate()}`;
  const dueDate = `${due.getFullYear()}-${due.getMonth() + 1}-${due.getDate()}`;

  return {
    startDate,
    dueDate,
  };
};

export const getEpicsPathForPreset = ({
  basePath = '',
  filterQueryString = '',
  presetType = '',
  timeframe = [],
  epicsState = 'all',
}) => {
  let epicsPath = basePath;

  if (!basePath || !timeframe.length) {
    return null;
  }

  const range = getEpicsTimeframeRange({
    presetType,
    timeframe,
  });

  epicsPath += epicsPath.indexOf('?') === -1 ? '?' : '&';
  epicsPath += `state=${epicsState}&start_date=${range.startDate}&end_date=${range.dueDate}`;

  if (filterQueryString) {
    epicsPath += `&${filterQueryString}`;
  }

  return epicsPath;
};

/**
 * This function takes two epics and return sortable dates depending on the '
 * type of sorting order -- startDate or endDate.
 */
export function assignDates(a, b, { dateUndefined, outOfRange, originalDate, date, proxyDate }) {
  let aDate;
  let bDate;

  if (a[dateUndefined]) {
    // Set proxy date to be either far in the past or
    // far in the future to ensure sort order is
    // correct.
    aDate = proxyDate;
  } else {
    aDate = a[outOfRange] ? a[originalDate] : a[date];
  }

  if (b[dateUndefined]) {
    bDate = proxyDate;
  } else {
    bDate = b[outOfRange] ? b[originalDate] : b[date];
  }

  return [aDate, bDate];
}

export const sortEpics = (epics, sortedBy) => {
  const sortByStartDate = sortedBy.indexOf('start_date') > -1;
  const sortOrderAsc = sortedBy.indexOf('asc') > -1;

  epics.sort((a, b) => {
    const [aDate, bDate] = assignDates(a, b, {
      dateUndefined: sortByStartDate ? 'startDateUndefined' : 'endDateUndefined',
      outOfRange: sortByStartDate ? 'startDateOutOfRange' : 'endDateOutOfRange',
      originalDate: sortByStartDate ? 'originalStartDate' : 'originalEndDate',
      date: sortByStartDate ? 'startDate' : 'endDate',
      proxyDate: sortByStartDate ? PAST_DATE : FUTURE_DATE,
    });

    // Sort in ascending or descending order
    if (aDate.getTime() < bDate.getTime()) {
      return sortOrderAsc ? -1 : 1;
    } else if (aDate.getTime() > bDate.getTime()) {
      return sortOrderAsc ? 1 : -1;
    }
    return 0;
  });
};
