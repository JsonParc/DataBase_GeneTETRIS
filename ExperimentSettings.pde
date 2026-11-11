import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JLabel;
import javax.swing.JTextField;
import javax.swing.JCheckBox;

// ── 실행 시 정해지는 실험 설정 (시작 설정 창 또는 TetrisAI.pde의 기본값) ──
String runOwner = RUN_OWNER;      // run_id 앞부분
long blockSeed = 0;               // 실험 시드: 블록 순서 + 유전 연산(부모 선택·교차·돌연변이) 난수의 출발점
int maxGenerations = 0;           // 이 세대까지 저장하면 실험 종료 (0 = 무제한)
boolean sharedPieces = false;     // true: 같은 세대의 모든 개체가 같은 블록 순서로 플레이

String pieceSeedMode() {
  return sharedPieces ? "SHARED_PER_GENERATION" : "PER_INDIVIDUAL";
}

// 시작 설정 창. 확인을 누르면 true, 취소하면 false
boolean askExperimentSettings() {
  String seedDefault = DEFAULT_BLOCK_SEED.trim();
  JTextField ownerField = new JTextField(RUN_OWNER, 18);
  JTextField seedField = new JTextField(seedDefault, 18);
  JTextField maxGenField = new JTextField(str(DEFAULT_MAX_GENERATIONS), 18);
  JCheckBox sharedBox = new JCheckBox("같은 세대의 200개체가 모두 같은 블록 순서로 플레이", DEFAULT_SHARED_PIECES);

  JPanel panel = new JPanel(new java.awt.GridLayout(0, 1, 2, 2));
  panel.add(new JLabel("실행자 이름 (영문/숫자, run_id 앞부분 · 비우면 RUN)"));
  panel.add(ownerField);
  panel.add(new JLabel("블록 난수 시드 (정수 · 비우면 무작위로 정하고 기록)"));
  panel.add(seedField);
  panel.add(new JLabel("최대 세대 수 (이 세대까지 저장하고 종료 · 0 = 무제한)"));
  panel.add(maxGenField);
  panel.add(sharedBox);
  panel.add(new JLabel("같은 시드 + 같은 설정이면 블록 순서와 진화 과정 전체가 똑같이 재현됩니다."));

  while(true) {
    int r = JOptionPane.showConfirmDialog(null, panel, "TetrisAI 실험 설정", JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
    if(r != JOptionPane.OK_OPTION) return false;
    String err = applySettings(ownerField.getText(), seedField.getText(), maxGenField.getText(), sharedBox.isSelected());
    if(err == null) return true;
    JOptionPane.showMessageDialog(null, err, "입력 오류", JOptionPane.ERROR_MESSAGE);
  }
}

// 설정 창을 쓰지 않을 때: TetrisAI.pde의 기본값 적용
void applyDefaultSettings() {
  String err = applySettings(RUN_OWNER, DEFAULT_BLOCK_SEED, str(DEFAULT_MAX_GENERATIONS), DEFAULT_SHARED_PIECES);
  if(err != null) throw new RuntimeException("TetrisAI.pde 기본 설정 오류: " + err);
}

// 입력값 검증 후 적용. 오류가 있으면 메시지, 정상이면 null
String applySettings(String owner, String seedText, String maxGenText, boolean shared) {
  long seed;
  String s = seedText.trim().replace(",", "").replace("_", "");
  if(s.length() == 0) {
    seed = (long)(Math.random() * 1000000000L);  // 다시 입력하기 쉬운 9자리 이하 무작위 시드
  } else {
    try {
      seed = Long.parseLong(s);
    } catch(NumberFormatException e) {
      return "블록 난수 시드는 정수여야 합니다: " + seedText;
    }
  }
  int maxGen;
  try {
    maxGen = Integer.parseInt(maxGenText.trim());
  } catch(NumberFormatException e) {
    return "최대 세대 수는 0 이상의 정수여야 합니다: " + maxGenText;
  }
  if(maxGen < 0) return "최대 세대 수는 0 이상이어야 합니다: " + maxGen;

  runOwner = owner.trim();
  blockSeed = seed;
  maxGenerations = maxGen;
  sharedPieces = shared;
  return null;
}

// 세대 generation의 slot번째 개체가 사용할 블록 순서 시드 (실험 시드에서 결정적으로 유도)
// sharedPieces이면 slot과 무관하게 세대마다 하나의 시드
long pieceSeedFor(int generation, int slot) {
  long x = mix64(blockSeed ^ (0x9E3779B97F4A7C15L * generation));
  if(!sharedPieces) x = mix64(x ^ (0xD1B54A32D192ED03L * (slot + 1)));
  return x >>> 1;  // 음수가 아닌 값 (DB BIGINT에 그대로 저장)
}

// SplitMix64 마무리 함수: 비슷한 입력(세대 1, 2, 3…)에서도 서로 무관한 시드를 만든다
long mix64(long z) {
  z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
  z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
  return z ^ (z >>> 31);
}
