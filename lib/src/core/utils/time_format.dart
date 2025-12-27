String formatDurationMmSs(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$minutes:$seconds';
}

