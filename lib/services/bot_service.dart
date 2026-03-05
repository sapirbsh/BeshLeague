import 'dart:math';

enum BotSkill { starter, good, advanced }

class BotPlayer {
  final String name;
  final int trophies;
  final BotSkill skill;

  const BotPlayer({required this.name, required this.trophies, required this.skill});
}

class BotMove {
  final int source; // 0-23 for board, 25 = bar (opponent's bar)
  final int dest;   // 0-23 for board, 24 = bear off

  const BotMove(this.source, this.dest);
}

class BotService {
  static final Random _random = Random();

  static const List<BotPlayer> _allBots = [
    // --- Starter tier (50–150 trophies) ---
    BotPlayer(name: "Kobi88",    trophies: 55,  skill: BotSkill.starter),
    BotPlayer(name: "Moshiko",   trophies: 72,  skill: BotSkill.starter),
    BotPlayer(name: "Shlomit_T", trophies: 88,  skill: BotSkill.starter),
    BotPlayer(name: "Dganit",    trophies: 95,  skill: BotSkill.starter),
    BotPlayer(name: "Eli_Paz",   trophies: 63,  skill: BotSkill.starter),
    BotPlayer(name: "Yossi_K",   trophies: 110, skill: BotSkill.starter),
    BotPlayer(name: "Batya22",   trophies: 130, skill: BotSkill.starter),
    BotPlayer(name: "Roni_B",    trophies: 78,  skill: BotSkill.starter),
    BotPlayer(name: "Nurit_L",   trophies: 145, skill: BotSkill.starter),
    BotPlayer(name: "Avi_S",     trophies: 50,  skill: BotSkill.starter),

    // --- Good tier (200–400 trophies) ---
    BotPlayer(name: "Barak_G",   trophies: 215, skill: BotSkill.good),
    BotPlayer(name: "Tamar_H",   trophies: 260, skill: BotSkill.good),
    BotPlayer(name: "Dvir99",    trophies: 310, skill: BotSkill.good),
    BotPlayer(name: "ShirK",     trophies: 285, skill: BotSkill.good),
    BotPlayer(name: "Itamar_Z",  trophies: 340, skill: BotSkill.good),
    BotPlayer(name: "Noa_Ben",   trophies: 390, skill: BotSkill.good),
    BotPlayer(name: "Gal_Or",    trophies: 220, skill: BotSkill.good),
    BotPlayer(name: "Reef_A",    trophies: 375, skill: BotSkill.good),
    BotPlayer(name: "Yam_Levi",  trophies: 295, skill: BotSkill.good),
    BotPlayer(name: "Dana_R",    trophies: 250, skill: BotSkill.good),

    // --- Advanced tier (500–900 trophies) ---
    BotPlayer(name: "Omri_Pro",  trophies: 620, skill: BotSkill.advanced),
    BotPlayer(name: "Hila_X",    trophies: 750, skill: BotSkill.advanced),
    BotPlayer(name: "Saar77",    trophies: 540, skill: BotSkill.advanced),
    BotPlayer(name: "Lior_Ace",  trophies: 880, skill: BotSkill.advanced),
    BotPlayer(name: "Ori_King",  trophies: 710, skill: BotSkill.advanced),
    BotPlayer(name: "Rotem_Z",   trophies: 590, skill: BotSkill.advanced),
    BotPlayer(name: "Niv_G",     trophies: 650, skill: BotSkill.advanced),
    BotPlayer(name: "Shaked_A",  trophies: 820, skill: BotSkill.advanced),
    BotPlayer(name: "Tom_Elite", trophies: 900, skill: BotSkill.advanced),
    BotPlayer(name: "Bar_M",     trophies: 560, skill: BotSkill.advanced),
  ];

  static BotPlayer getRandomBot() {
    return _allBots[_random.nextInt(_allBots.length)];
  }

  /// Delay before the bot clicks "ready" on the pre-game screen
  static Duration getReadyDelay(BotSkill skill) {
    switch (skill) {
      case BotSkill.starter:
        return Duration(milliseconds: 3000 + _random.nextInt(3000)); // 3–6s
      case BotSkill.good:
        return Duration(milliseconds: 2000 + _random.nextInt(2000)); // 2–4s
      case BotSkill.advanced:
        return Duration(milliseconds: 1000 + _random.nextInt(1500)); // 1–2.5s
    }
  }

  /// Delay before the bot starts selecting its move during a turn
  static Duration getThinkDelay(BotSkill skill) {
    switch (skill) {
      case BotSkill.starter:
        return Duration(milliseconds: 1500 + _random.nextInt(1500)); // 1.5–3s
      case BotSkill.good:
        return Duration(milliseconds: 1000 + _random.nextInt(1500)); // 1–2.5s
      case BotSkill.advanced:
        return Duration(milliseconds: 500 + _random.nextInt(1300));  // 0.5–1.8s
    }
  }

  /// Returns all valid (source, dest) moves for the bot (opponent, negative pieces).
  /// Bot pieces are negative on the board and move from low index → high index.
  /// source == 25 means the bot's bar.
  /// dest == 24 means bear off.
  static List<BotMove> getValidBotMoves(List<int> board, List<int> availableMoves, int oppBar) {
    List<BotMove> moves = [];
    if (availableMoves.isEmpty) return moves;

    bool canBearOff = _canBotBearOff(board, oppBar);

    Set<int> uniqueMoves = availableMoves.toSet();

    if (oppBar > 0) {
      // Must enter from bar — entry point is 0+move-1 (0-indexed from point 0)
      for (int mv in uniqueMoves) {
        int dest = mv - 1; // entering from bar into index (mv-1) since bar is at "point 25" in backgammon notation → 0-indexed board dest = mv - 1
        if (dest >= 0 && dest <= 23 && board[dest] >= -1) {
          moves.add(BotMove(25, dest));
        }
      }
      return moves;
    }

    for (int src = 0; src < 24; src++) {
      if (board[src] >= 0) continue; // no bot piece here
      for (int mv in uniqueMoves) {
        int dest = src + mv;
        if (dest <= 23) {
          if (board[dest] >= -1) { // empty, bot's own single, or human blot (==1) → wait, bot piece is negative so own = negative
            // board[dest] <= 1 means: could be negative (bot's own), 0 (empty), or 1 (single human blot)
            // board[dest] >= 2 means 2+ human pieces = blocked
            if (board[dest] <= 1) {
              moves.add(BotMove(src, dest));
            }
          }
        } else if (canBearOff) {
          if (dest == 24) {
            moves.add(BotMove(src, 24));
          } else {
            // Overshoot: only valid if no bot pieces at higher indices
            bool pieceBehind = false;
            for (int i = src - 1; i >= 18; i--) {
              if (board[i] < 0) { pieceBehind = true; break; }
            }
            if (!pieceBehind) moves.add(BotMove(src, 24));
          }
        }
      }
    }
    return moves;
  }

  static bool _canBotBearOff(List<int> board, int oppBar) {
    if (oppBar > 0) return false;
    for (int i = 0; i < 18; i++) {
      if (board[i] < 0) return false;
    }
    return true;
  }

  /// Select the best move for the bot given its skill level.
  /// Returns null if no valid moves exist.
  static BotMove? selectBotMove(List<int> board, List<int> availableMoves, int oppBar, BotSkill skill) {
    final validMoves = getValidBotMoves(board, availableMoves, oppBar);
    if (validMoves.isEmpty) return null;

    switch (skill) {
      case BotSkill.starter:
        return validMoves[_random.nextInt(validMoves.length)];

      case BotSkill.good:
        // Prefer hitting human blots, else pick random
        final hittingMoves = validMoves.where((m) => m.dest < 24 && board[m.dest] == 1).toList();
        if (hittingMoves.isNotEmpty) return hittingMoves[_random.nextInt(hittingMoves.length)];
        return validMoves[_random.nextInt(validMoves.length)];

      case BotSkill.advanced:
        // Score each move and pick the best
        BotMove best = validMoves.first;
        int bestScore = -999;
        for (final move in validMoves) {
          int score = _scoreBotMove(board, move);
          if (score > bestScore) { bestScore = score; best = move; }
        }
        return best;
    }
  }

  static int _scoreBotMove(List<int> board, BotMove move) {
    if (move.dest == 24) return 15; // bearing off is great
    int score = 0;
    final dest = move.dest;
    if (board[dest] == 1) score += 10;      // hitting a human blot
    if (board[dest] < 0) score += 3;         // landing on own point (building prime)
    // prefer moving forward (higher dest = better progress for bot)
    score += dest ~/ 6;
    return score;
  }
}
