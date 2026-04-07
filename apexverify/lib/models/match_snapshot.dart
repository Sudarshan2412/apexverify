class MatchSnapshot {
  final String homeTeam;
  final String awayTeam;
  final String score;
  final String clock;
  final bool hasOverlay;

  MatchSnapshot({
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
    required this.clock,
    required this.hasOverlay,
  });
}