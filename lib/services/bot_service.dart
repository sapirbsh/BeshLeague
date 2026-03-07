import 'dart:math';
import 'dart:convert'; // חובה בשביל ה-JSON

enum BotSkill { starter, good, advanced }

class BotPlayer {
  final String name;
  final int trophies;
  final BotSkill skill;

  const BotPlayer({required this.name, required this.trophies, required this.skill});
}

class BotMove {
  final int source; 
  final int dest;   

  const BotMove(this.source, this.dest);
}

class BotService {
  static final Random _random = Random();

  // הרשימה כבר לא "const", כי אנחנו נאפשר לשרת לעדכן אותה בלייב!
  // אבל נשאיר כאן את הבוטים כגיבוי התחלתי למקרה שהאינטרנט איטי.
  static List<BotPlayer> _allBots = const [
    BotPlayer(name: "Kobi88",    trophies: 50, skill: BotSkill.starter),
    BotPlayer(name: "Moshiko",   trophies: 60, skill: BotSkill.starter),
    BotPlayer(name: "Barak_G",   trophies: 300, skill: BotSkill.good),
    BotPlayer(name: "Omri_Pro",  trophies: 1200, skill: BotSkill.advanced),
    BotPlayer(name: "Saar77",    trophies: 1400, skill: BotSkill.advanced),
  ];

  // ==============================================================
  // הפונקציה החדשה והחשובה - מעדכנת את הבוטים מהשרת בזמן אמת!
  // ==============================================================
  static void updateBotsFromServer(String jsonString) {
    try {
      final List<dynamic> data = json.decode(jsonString);
      final List<BotPlayer> loadedBots = [];
      
      for (var b in data) {
        BotSkill parsedSkill = BotSkill.starter;
        if (b['skill'] == 'good') parsedSkill = BotSkill.good;
        if (b['skill'] == 'advanced') parsedSkill = BotSkill.advanced;

        loadedBots.add(BotPlayer(
          name: b['name'] ?? 'Bot',
          trophies: b['trophies'] ?? 0,
          skill: parsedSkill,
        ));
      }
      
      // מחליף את רשימת הגיבוי ברשימה המלאה שהגיעה מממשק הניהול
      if (loadedBots.isNotEmpty) {
        _allBots = loadedBots;
      }
    } catch (e) {
      print("Error loading bots from server: $e");
    }
  }

  static BotPlayer getRandomBot() {
    return _allBots[_random.nextInt(_allBots.length)];
  }

  static Duration getReadyDelay(BotSkill skill) {
    switch (skill) {
      case BotSkill.starter:
        return Duration(milliseconds: 3000 + _random.nextInt(3000));
      case BotSkill.good:
        return Duration(milliseconds: 2000 + _random.nextInt(2000));
      case BotSkill.advanced:
        return Duration(milliseconds: 1000 + _random.nextInt(1500));
    }
  }

  static Duration getThinkDelay(BotSkill skill) {
    switch (skill) {
      case BotSkill.starter:
        return Duration(milliseconds: 1500 + _random.nextInt(1500));
      case BotSkill.good:
        return Duration(milliseconds: 1000 + _random.nextInt(1500));
      case BotSkill.advanced:
        return Duration(milliseconds: 500 + _random.nextInt(1300)); 
    }
  }

  static List<BotMove> getValidBotMoves(List<int> board, List<int> availableMoves, int oppBar) {
    List<BotMove> moves = [];
    if (availableMoves.isEmpty) return moves;

    bool canBearOff = _canBotBearOff(board, oppBar);
    Set<int> uniqueMoves = availableMoves.toSet();

    if (oppBar > 0) {
      for (int mv in uniqueMoves) {
        int dest = mv - 1;
        if (dest >= 0 && dest <= 23 && board[dest] <= 1) {
          moves.add(BotMove(25, dest));
        }
      }
      return moves;
    }

    for (int src = 0; src < 24; src++) {
      if (board[src] >= 0) continue; 
      for (int mv in uniqueMoves) {
        int dest = src + mv;
        if (dest <= 23) {
          if (board[dest] <= 1) moves.add(BotMove(src, dest));
        } else if (canBearOff) {
          if (dest == 24) {
            moves.add(BotMove(src, 24));
          } else {
            bool pieceOnLower = false;
            for (int i = 18; i < src; i++) {
              if (board[i] < 0) { pieceOnLower = true; break; }
            }
            if (!pieceOnLower) moves.add(BotMove(src, 24));
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

  static BotMove? selectBotMove(List<int> board, List<int> availableMoves, int oppBar, BotSkill skill) {
    final validMoves = getValidBotMoves(board, availableMoves, oppBar);
    if (validMoves.isEmpty) return null;

    switch (skill) {
      case BotSkill.starter:
        return validMoves[_random.nextInt(validMoves.length)];
      case BotSkill.good:
        final hittingMoves = validMoves.where((m) => m.dest < 24 && board[m.dest] == 1).toList();
        if (hittingMoves.isNotEmpty) return hittingMoves[_random.nextInt(hittingMoves.length)];
        return validMoves[_random.nextInt(validMoves.length)];
      case BotSkill.advanced:
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
    if (move.dest == 24) return 15; 
    int score = 0;
    final dest = move.dest;
    if (board[dest] == 1) score += 10;      
    if (board[dest] < 0) score += 3;         
    score += dest ~/ 6;
    return score;
  }
}