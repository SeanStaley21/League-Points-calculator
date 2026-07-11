const int defaultWeekCount = 8;

/// Matches the league's current "Points calculator" table (1st..13th score).
const int defaultScoredPositions = 13;

const List<String> defaultDivisionNames = [
  'Pro 1',
  'Pro 2',
  'Pro 3',
  'Juniors',
];

const String seasonFileExtension = 'lpts';

/// Extension for a standalone kart roster file -- just kart numbers/classes,
/// saved separately from a season so the pool can be reused across seasons.
const String kartRosterFileExtension = 'lktr';

const int currentFormatVersion = 1;
