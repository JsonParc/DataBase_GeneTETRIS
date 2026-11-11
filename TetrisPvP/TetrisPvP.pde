// TetrisAI 배틀로얄 (PvP)
// TetrisAI가 저장한 exports/<run_id>/ 에서 한 세대의 개체 전원을 불러와, 서로 방해 줄을 보내며 한 경기를 치른다.
// 유전 알고리즘 실행과는 별도로, 원하는 때 원하는 컴퓨터에서 실행한다.
// Matrix.pde / NetMatrix.pde / NeuraNet.pde 는 TetrisAI 폴더의 같은 파일을 그대로 복사한 것 (수정 시 함께 맞출 것)

import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JLabel;
import javax.swing.JTextField;
import javax.swing.JComboBox;

final String PVP_VERSION = "1.1.0";

// ── 설정 기본값 (시작 설정 창에서 변경 가능) ──
// exports 폴더 위치. 비우면 이 스케치 폴더의 상위(TetrisAI)/exports
final String EXPORTS_DIR = "";
final String DEFAULT_GENERATION = "LAST";   // LAST 또는 세대 번호
final String DEFAULT_SEED = "";             // 비우면 무작위 (기록됨)
final int DEFAULT_MAX_STEPS = 200000;       // 경기 최대 단계 (넘으면 생존자 중 점수 1위 우승)

// ── 게임 상수 (TetrisAI와 동일) ──
final int ROWS = 20;
final int COLS = 10;
final boolean CHECK_NEXT = true;
final int GARBAGE = 8;  // 방해 줄 칸 값
final int[][][] tetrominos = {
  {{1, 1, 1}, {0, 1, 0}},
  {{0, 2, 2}, {2, 2, 0}},
  {{3, 3, 0}, {0, 3, 3}},
  {{4, 0, 0}, {4, 4, 4}},
  {{0, 0, 5}, {5, 5, 5}},
  {{6, 6, 6, 6}},
  {{7, 7}, {7, 7}}
};
final color[] colors = { color(0,0,0), color(255,0,0), color(0,255,0), color(0,0,255), color(255,255,0), color(255,0,255), color(0,255,255), color(255,255,255), color(110,110,110) };

// ── 경기 상태 ──
File runDir;
ArrayList<PvpPlayer> roster;
int generation, maxSteps;
long seed;
PvpWriter writer;
PvpMatch match;
boolean saved = false;
String haltMessage = null;

int speed = 4;          // 프레임당 진행 단계 (+/- 키, 기본 x4)
boolean paused = false;
int page = 0;
boolean aliveOnly = false;
final int MAX_SPEED = 256;

void settings() {
  size(1200, 700);
}

void setup() {
  frameRate(300);
  setupKoreanFont();
  try {
    File exportsDir = EXPORTS_DIR.length() > 0 ? new File(EXPORTS_DIR) : new File(sketchPath(".."), "exports");
    File[] runs = listRuns(exportsDir);
    if(runs.length == 0) throw new RuntimeException("불러올 실험이 없습니다: " + exportsDir.getAbsolutePath()
                                                    + "\nTetrisAI를 1세대 이상 실행해 exports/<run_id>/ 를 만든 뒤 다시 실행하세요.");
    if(!askSettings(runs)) { exit(); return; }
    writer = new PvpWriter(runDir);
    match = new PvpMatch(writer.newMatchId(), generation, seed, maxSteps, roster);
    println("[PvP] " + match.matchId + " 시작: " + runDir.getName() + " " + generation + "세대 " + roster.size() + "명, 블록 시드 " + seed);
  } catch(RuntimeException e) {
    haltMessage = "[시작 중단] " + e.getMessage();
    println(haltMessage);
  }
}

boolean askSettings(File[] runs) {
  String[] runNames = new String[runs.length];
  for(int i = 0; i < runs.length; i++) runNames[i] = runs[i].getName();
  JComboBox<String> runBox = new JComboBox<String>(runNames);
  JTextField genField = new JTextField(DEFAULT_GENERATION, 18);
  JTextField seedField = new JTextField(DEFAULT_SEED, 18);
  JTextField stepField = new JTextField(str(DEFAULT_MAX_STEPS), 18);

  JPanel panel = new JPanel(new java.awt.GridLayout(0, 1, 2, 2));
  panel.add(new JLabel("실험 (exports/<run_id>, 최근 순)")); panel.add(runBox);
  panel.add(new JLabel("세대 (LAST = 마지막 저장 세대, 또는 번호) · 그 세대 개체 전원 참가")); panel.add(genField);
  panel.add(new JLabel("블록 난수 시드 (정수, 비우면 무작위)")); panel.add(seedField);
  panel.add(new JLabel("최대 단계 (도달 시 생존자 중 점수 1위 우승)")); panel.add(stepField);
  panel.add(new JLabel("공격 방식(RANDOM/LEADER/WEAKEST)은 개체마다 무작위로 배정됩니다."));

  while(true) {
    int r = JOptionPane.showConfirmDialog(null, panel, "TetrisAI 배틀로얄 설정", JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
    if(r != JOptionPane.OK_OPTION) return false;
    try {
      runDir = runs[runBox.getSelectedIndex()];
      maxSteps = parseIntField(stepField.getText(), "최대 단계", 1000);
      String s = seedField.getText().trim().replace(",", "").replace("_", "");
      if(s.length() == 0) seed = (long)(Math.random() * 1000000000L);
      else {
        try { seed = Long.parseLong(s); }
        catch(NumberFormatException e) { throw new RuntimeException("블록 난수 시드는 정수여야 합니다: " + s); }
      }
      generation = parseGeneration(genField.getText(), availableGenerations(runDir));
      roster = loadPlayers(runDir, generation);
      return true;
    } catch(RuntimeException e) {
      JOptionPane.showMessageDialog(null, e.getMessage(), "입력 오류", JOptionPane.ERROR_MESSAGE);
    }
  }
}

int parseIntField(String text, String what, int minValue) {
  try {
    int v = Integer.parseInt(text.trim());
    if(v < minValue) throw new RuntimeException(what + "는 " + minValue + " 이상이어야 합니다: " + v);
    return v;
  } catch(NumberFormatException e) {
    throw new RuntimeException(what + "는 정수여야 합니다: " + text);
  }
}

void draw() {
  background(0);
  if(haltMessage != null) {
    fill(255, 120, 120);
    textAlign(LEFT, TOP);
    textSize(18);
    text(haltMessage, 30, 30, width - 60, height - 60);
    return;
  }
  if(match == null) return;

  if(!paused && !match.over) {
    for(int s = 0; s < speed && !match.over; s++) match.step();
  }
  if(match.over && !saved) {
    saved = true;
    writer.writeMatch(match);
  }
  drawMatch();
}

void drawMatch() {
  // 표시 대상: 진행 중이면 참가 순서(A 키로 생존자만), 끝나면 순위 순
  ArrayList<Integer> shown = new ArrayList<Integer>();
  if(match.over) {
    for(int r = 0; r < match.order.length; r++) shown.add(match.order[r]);
  } else {
    for(int i = 0; i < match.players.length; i++) {
      if(!aliveOnly || !match.players[i].dead) shown.add(i);
    }
  }
  int n = shown.size();
  int cols = constrain((int)ceil(sqrt(n * 2.0)), 1, 12);
  int rows = constrain((int)ceil((float)n / cols), 1, 3);
  int perPage = cols * rows;
  int pages = max(1, (n + perPage - 1) / perPage);
  page = constrain(page, 0, pages - 1);

  int top = 50, bottom = 40, margin = 10, textH = 40;
  float tileW = (width - margin * (cols + 1)) / (float)cols;
  float tileH = (height - top - bottom - margin * (rows + 1)) / (float)rows;
  float cell = min((tileW - 6) / COLS, (tileH - textH) / ROWS);

  for(int k = page * perPage; k < min(n, (page + 1) * perPage); k++) {
    int i = shown.get(k);
    PvpPlayer p = match.players[i];
    int slot = k - page * perPage;
    float x = margin + (slot % cols) * (tileW + margin);
    float y = top + margin + (slot / cols) * (tileH + margin);

    boolean winner = match.over && p.rank == 1;
    fill(winner ? color(255, 230, 0) : (p.dead ? color(255, 110, 110) : color(255)));
    textAlign(LEFT, BASELINE);
    textSize(11);
    text(p.founderName + "가문 #" + p.individualId + " " + p.strategy.charAt(0) + (p.dead && !match.over ? " OUT" : ""), x + 4, y + 11);
    text("S " + p.score + "  L " + p.lines, x + 4, y + 24);
    String atk = "→" + (p.target >= 0 ? "#" + match.players[p.target].individualId : "-") + " " + p.linesSent + "/" + p.linesReceived;
    if(match.over) atk = "rank " + p.rank + (p.kills > 0 ? "  KO " + p.kills : "");
    text(atk, x + 4, y + 37);
    p.draw_board(x + 4, y + textH, cell);
  }

  // 상단 정보
  fill(255);
  textAlign(LEFT, BASELINE);
  textSize(15);
  text("Gen " + generation + "   seed " + seed + "   alive " + match.aliveCount() + "/" + match.players.length
       + "   step " + match.steps + "/" + maxSteps + "   speed x" + speed + (paused ? "   [PAUSED]" : ""), 12, 22);
  textSize(12);
  fill(170);
  text("run " + runDir.getName() + "   match " + match.matchId, 12, 40);
  if(match.over) {
    PvpPlayer w = match.players[match.order[0]];
    PvpPlayer t = match.topScorer();
    fill(255, 230, 0);
    textSize(15);
    textAlign(RIGHT, BASELINE);
    text("WINNER " + w.founderName + "가문 #" + w.individualId + " (" + w.strategy + ", " + match.endReason + ")   top score " + t.score
         + " (" + t.founderName + "가문 #" + t.individualId + ")", width - 12, 22);
  }

  // 하단 안내
  fill(150);
  textSize(12);
  textAlign(LEFT, BASELINE);
  text("Page " + (page + 1) + "/" + pages + (aliveOnly && !match.over ? " (alive only)" : "")
       + "     LEFT/RIGHT page | A alive/all | +/- speed | SPACE pause | ESC exit   "
       + "R/L/W = RANDOM/LEADER/WEAKEST   S=score L=lines →target sent/received", 12, height - 14);
  if(match.over) {
    fill(writer.error == null ? color(120, 255, 120) : color(255, 100, 100));
    text(writer.error == null ? "Saved: " + writer.dir.getAbsolutePath() + "   (ESC: exit)" : writer.error, 12, height - 30);
  }
}

void keyPressed() {
  if(key == ESC) {
    key = 0;
    if(match != null && !match.over) println("[PvP] 진행 중이던 경기 " + match.matchId + "는 저장되지 않았습니다.");
    exit();
    return;
  }
  if(match == null) return;
  if(key == '+' || key == '=') speed = min(speed * 2, MAX_SPEED);
  if(key == '-' || key == '_') speed = max(speed / 2, 1);
  if(key == ' ') paused = !paused;
  if(key == 'a' || key == 'A') { aliveOnly = !aliveOnly; page = 0; }
  if(key == CODED && keyCode == LEFT) page--;
  if(key == CODED && keyCode == RIGHT) page++;
}

void setupKoreanFont() {
  String sample = "가문 경기";
  String[] candidates = {"Malgun Gothic", "맑은 고딕", "Apple SD Gothic Neo", "NanumGothic", "Noto Sans CJK KR", "Noto Sans KR", "Gulim", "Dialog", "SansSerif"};
  for(String name : candidates) {
    PFont f = createFont(name, 18, true);
    Object nativeFont = f.getNative();
    if(nativeFont instanceof java.awt.Font && ((java.awt.Font)nativeFont).canDisplayUpTo(sample) == -1) {
      textFont(f);
      return;
    }
  }
}
