class WeekRange {
  WeekRange.from(DateTime anchor)
    : start = DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
      ).subtract(Duration(days: anchor.weekday - DateTime.monday)),
      endExclusive = DateTime(anchor.year, anchor.month, anchor.day)
          .subtract(Duration(days: anchor.weekday - DateTime.monday))
          .add(const Duration(days: 7));

  final DateTime start;
  final DateTime endExclusive;

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(endExclusive);
}
