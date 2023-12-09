export default () => ({
  // API Calls
  basePath: '',
  epicsState: '',
  filterQueryString: '',
  initialEpicsPath: '',
  filterParams: null,

  // Data
  epicIid: '',
  epics: [],
  visibleEpics: [],
  epicIds: [],
  currentGroupId: -1,
  fullPath: '',
  timeframe: [],
  extendedTimeframe: [],
  presetType: '',
  sortedBy: '',
  milestoneIds: [],
  milestones: [],
  bufferSize: 0,

  // UI Flags
  defaultInnerHeight: 0,
  isChildEpics: false,
  windowResizeInProgress: false,
  epicsFetchInProgress: false,
  epicsFetchForTimeframeInProgress: false,
  epicsFetchFailure: false,
  epicsFetchResultEmpty: false,
  milestonesFetchInProgress: false,
  milestonesFetchFailure: false,
  milestonesFetchResultEmpty: false,
});
