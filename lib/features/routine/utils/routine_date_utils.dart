/// Ensures a local calendar date is stripped of any time components without shifting
/// it to UTC. This prevents off-by-one errors in regions where local midnight
/// is on a different calendar day than UTC.
DateTime routineDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
