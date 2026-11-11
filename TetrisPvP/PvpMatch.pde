// 배틀로얄 한 경기
// - 모든 참가자가 같은 블록 순서(seed)로 동시에 플레이
// - 한 번에 k줄(방해 줄 제외)을 지우면 k-1줄을 대상 1명에게 방해 줄로 보냄
// - 받은 방해 줄은 받은 쪽의 다음 블록이 놓일 때 아래에서 밀려 올라옴 (줄마다 무작위 한 칸이 비어 있음)
// - 공격 대상은 참가자마다 경기 시작 시 무작위로 배정된 방식(RANDOM / LEADER / WEAKEST)으로 고른다
// - 마지막 1명이 남거나, 단계 제한(maxSteps)에 도달하면 종료
final String[] STRATEGIES = {"RANDOM", "LEADER", "WEAKEST"};

class PvpMatch {
  String matchId;
  int generation;
  long seed;
  int maxSteps;
  PvpPlayer[] players;
  java.util.Random rng;   // 공격 대상 선택 + 방해 줄 빈칸 위치 (seed에서 유도 → 재현 가능)

  int steps = 0;
  boolean over = false;
  String endReason = "";
  int[] order;            // 최종 순위 순서의 참가자 번호 (order[0] = 우승)
  String startedAt, endedAt;
  long startMillis, durationMs;

  PvpMatch(String matchId, int generation, long seed, int maxSteps, ArrayList<PvpPlayer> list) {
    this.matchId = matchId;
    this.generation = generation;
    this.seed = seed;
    this.maxSteps = maxSteps;
    players = list.toArray(new PvpPlayer[0]);
    rng = new java.util.Random(seed ^ 0x5DEECE66DL ^ 0x9E3779B97F4A7C15L);
    for(PvpPlayer p : players) {
      p.reset(seed);
      p.strategy = STRATEGIES[rng.nextInt(STRATEGIES.length)];  // 시드에서 결정 → 재현 가능
    }
    startedAt = now("yyyy-MM-dd HH:mm:ss");
    startMillis = millis();
  }

  void step() {
    if(over) return;
    steps++;
    for(int i = 0; i < players.length; i++) {
      PvpPlayer p = players[i];
      if(p.dead) continue;
      int attack = p.step(rng);
      if(p.dead) {
        p.deathStep = steps;
        if(p.lastAttacker >= 0) players[p.lastAttacker].kills++;
      }
      if(attack > 0) {
        int t = chooseTarget(i);
        if(t >= 0) {
          players[t].pendingGarbage += attack;
          players[t].lastAttacker = i;
          p.linesSent += attack;
          p.target = t;
        }
      }
    }
    int alive = aliveCount();
    if(alive <= 1) finish(alive == 1 ? "LAST_SURVIVOR" : "SIMULTANEOUS_KO");
    else if(steps >= maxSteps) finish("TIME_LIMIT");
  }

  // 공격 대상 (공격자의 strategy): RANDOM(살아 있는 상대 중 무작위) / LEADER(점수 1위) / WEAKEST(가장 높이 쌓인 상대)
  int chooseTarget(int self) {
    ArrayList<Integer> cand = new ArrayList<Integer>();
    for(int j = 0; j < players.length; j++) {
      if(j != self && !players[j].dead) cand.add(j);
    }
    if(cand.isEmpty()) return -1;
    String mode = players[self].strategy;
    if(mode.equals("LEADER")) {
      int best = cand.get(0);
      for(int j : cand) if(players[j].score > players[best].score) best = j;
      return best;
    }
    if(mode.equals("WEAKEST")) {
      int best = cand.get(0);
      int bestH = players[best].stack_height() + players[best].pendingGarbage;
      for(int j : cand) {
        int h = players[j].stack_height() + players[j].pendingGarbage;
        if(h > bestH) { best = j; bestH = h; }
      }
      return best;
    }
    return cand.get(rng.nextInt(cand.size()));
  }

  int aliveCount() {
    int n = 0;
    for(PvpPlayer p : players) if(!p.dead) n++;
    return n;
  }

  // 순위: 생존자(점수순) → 늦게 탈락한 순 → 같은 단계 탈락이면 점수순 → 개체 ID순
  void finish(String reason) {
    over = true;
    endReason = reason;
    endedAt = now("yyyy-MM-dd HH:mm:ss");
    durationMs = millis() - startMillis;
    Integer[] idx = new Integer[players.length];
    for(int i = 0; i < idx.length; i++) idx[i] = i;
    java.util.Arrays.sort(idx, new Comparator<Integer>() {
      public int compare(Integer a, Integer b) {
        PvpPlayer x = players[a], y = players[b];
        if(x.dead != y.dead) return x.dead ? 1 : -1;
        if(x.deathStep != y.deathStep) return Integer.compare(y.deathStep, x.deathStep);
        if(x.score != y.score) return Integer.compare(y.score, x.score);
        return Integer.compare(x.individualId, y.individualId);
      }
    });
    order = new int[idx.length];
    for(int r = 0; r < idx.length; r++) {
      order[r] = idx[r];
      players[idx[r]].rank = r + 1;
    }
  }

  PvpPlayer topScorer() {
    PvpPlayer best = players[0];
    for(PvpPlayer p : players) {
      if(p.score > best.score || (p.score == best.score && p.individualId < best.individualId)) best = p;
    }
    return best;
  }
}
