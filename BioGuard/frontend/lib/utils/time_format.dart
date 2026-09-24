/// BioGuard — Time formatting helpers for display.
///
/// The backend stores UTC in naive DateTime columns, so timestamps usually
/// arrive without an offset and DateTime.parse reads them as local time.
/// These helpers treat any non-UTC value as UTC wall-clock time.
DateTime _asUtc(DateTime t) => t.isUtc
    ? t
    : DateTime.utc(
        t.year,
        t.month,
        t.day,
        t.hour,
        t.minute,
        t.second,
        t.millisecond,
        t.microsecond,
      );

/// "just now", "42s ago", "5m ago", "3h ago", "2d ago".
String timeAgo(DateTime t) {
  final diff = DateTime.now().toUtc().difference(_asUtc(t));
  if (diff.inSeconds < 5) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// "24 Sep, 14:05:09" in the device's local time zone.
String dateTimeLabel(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final l = _asUtc(t).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.day} ${months[l.month - 1]}, '
      '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}
