import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.math.BigDecimal;

// 실험 기록을 관계형 DB 적재용 CSV로 내보내는 클래스
// exports/<run_id>/ 아래 7개 파일. 완료된 세대만, 세대당 한 번만 기록한다.
class CsvExporter {

  final String H_EXPERIMENTS  = "run_id,founder_set_id,founder_genome_sha256,program_version,started_at,population_size,mutation_rate,input_nodes,hidden_nodes,output_nodes,hidden_layers";
  final String H_GENERATIONS  = "run_id,generation,population_size,highest_score,average_score,completed_at";
  final String H_FAMILIES     = "run_id,family_id,founder_individual_id,founder_name,family_name";
  final String H_INDIVIDUALS  = "run_id,individual_id,generation,family_id,birth_type";
  final String H_PARENTAGE    = "run_id,child_individual_id,parent_individual_id,parent_role";
  final String H_GENES        = "run_id,individual_id,gene_index,layer_index,row_index,col_index,weight";
  final String H_GAME_RESULTS = "run_id,individual_id,generation,score,lines,tetris_count,total_back_to_back,single_clears,double_clears,triple_clears,pieces_placed";
  final String H_SNAPSHOT     = "run_id,generation,individual_id,family_id,status,score,lines,tetris_count,total_back_to_back,single_clears,double_clears,triple_clears,pieces_placed,is_final,captured_at";

  final int RETRY_FRAMES = FPS * 2;  // 저장 실패 시 재시도 간격

  String runId;
  String startedAt;
  File runDir;

  // 실험 시작 시점의 설정·시조 정보 (이후 개체군이 바뀌어도 그대로 기록하기 위해 보관)
  int populationSize;
  float mutationRate;
  int iNodes, hNodes, oNodes, hLayers;
  int[] founderFamilyIds;
  int[] founderIndividualIds;

  boolean initialized = false;
  int lastExportedGen = 0;
  int maxExportedID = 0;
  HashMap<Integer, int[]> prevGen = new HashMap<Integer, int[]>();  // 직전 저장 세대: id -> {family_id, score}
  int nextRetryFrame = 0;

  long individualsWritten = 0;
  long geneRowsWritten = 0;

  String statusMessage = "";
  boolean statusError = false;

  FounderGenomes founders;  // 이 실행이 사용한 공통 시조 유전자 집합

  CsvExporter(Population p, FounderGenomes founders) {
    this.founders = founders;
    startedAt = timestamp("yyyy-MM-dd HH:mm:ss");

    populationSize = p.tetris_pop.length;
    mutationRate = mutation_rate;
    NeuralNet b = p.tetris_pop[0].brain;
    iNodes = b.iNodes; hNodes = b.hNodes; oNodes = b.oNodes; hLayers = b.hLayers;
    founderFamilyIds = new int[populationSize];
    founderIndividualIds = new int[populationSize];
    for(int i = 0; i < populationSize; i++) {
      founderFamilyIds[i] = p.tetris_pop[i].species_id;
      founderIndividualIds[i] = p.tetris_pop[i].uniqueID;
    }

    // 실행마다 고유한 run_id: <실행자>_<시작 시각>_<UUID 앞 8자리>
    // 여러 팀원이 같은 시각에 실행해도 UUID 부분으로 구분되고, 기존 폴더도 덮어쓰지 않는다
    String base = runOwnerTag() + "_" + timestamp("yyyyMMdd_HHmmss") + "_"
                  + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase(Locale.ROOT);
    runId = base;
    int suffix = 2;
    while(new File(sketchPath("exports/" + runId)).exists()) {
      runId = base + "_" + suffix++;
    }
    runDir = new File(sketchPath("exports/" + runId));

    initialize();
  }

  File file(String name) {
    return new File(runDir, name);
  }

  // 폴더 생성 + experiments/families 기록 + 나머지 파일 헤더 기록
  boolean initialize() {
    try {
      if(!runDir.exists() && !runDir.mkdirs()) {
        throw new IOException("폴더를 만들 수 없습니다: " + runDir.getAbsolutePath());
      }
      String[] names = {"experiments.csv", "generations.csv", "families.csv", "individuals.csv", "parentage.csv", "genes.csv", "game_results.csv"};
      for(String n : names) {
        if(file(n).exists()) throw new IOException("이미 존재하는 파일을 덮어쓰지 않습니다: " + file(n).getAbsolutePath());
      }

      StringBuilder exp = new StringBuilder(H_EXPERIMENTS).append('\n');
      row(exp, csv(runId), csv(founders.setId), csv(founders.sha256), csv(PROGRAM_VERSION), csv(startedAt), str(populationSize), fmtFloat(mutationRate), str(iNodes), str(hNodes), str(oNodes), str(hLayers));

      StringBuilder fam = new StringBuilder(H_FAMILIES).append('\n');
      for(int i = 0; i < populationSize; i++) {
        int fid = founderFamilyIds[i];
        row(fam, csv(runId), str(fid), str(founderIndividualIds[i]), csv(founderName(fid)), csv(familyName(fid)));
      }

      String[] contents = {
        exp.toString(),
        H_GENERATIONS + "\n",
        fam.toString(),
        H_INDIVIDUALS + "\n",
        H_PARENTAGE + "\n",
        H_GENES + "\n",
        H_GAME_RESULTS + "\n"
      };
      try {
        for(int i = 0; i < names.length; i++) {
          writeFile(file(names[i]), contents[i], false);
        }
      } catch(IOException e) {
        for(String n : names) file(n).delete();  // 일부만 생성된 상태를 남기지 않음
        throw e;
      }
      initialized = true;
      setStatus("Run " + runId + " started", false);
      println("[CSV] 실험 폴더 생성: " + runDir.getAbsolutePath());
      return true;
    } catch(Exception e) {
      reportError("CSV 초기화 실패", e);
      return false;
    }
  }

  // 완료된 세대를 기록. 성공(또는 이미 기록됨)이면 true, 실패면 false (다음 세대로 진행하면 안 됨)
  boolean exportGeneration(Population p) {
    if(p.gen <= lastExportedGen) return true;  // 동일 세대 중복 기록 방지
    if(!p.is_done()) {
      setStatus("Gen " + p.gen + " in progress - not final", false);
      return false;
    }
    if(frameCount < nextRetryFrame) return false;
    if(!initialized && !initialize()) {
      nextRetryFrame = frameCount + RETRY_FRAMES;
      return false;
    }

    ArrayList<String> problems = validateGeneration(p);
    for(String s : problems) println("[CSV][검증 경고] Gen " + p.gen + ": " + s);

    String completedAt = timestamp("yyyy-MM-dd HH:mm:ss");
    int n = p.tetris_pop.length;
    long sum = 0;
    int highest = 0;
    for(Tetris t : p.tetris_pop) {
      sum += t.score;
      if(t.score > highest) highest = t.score;
    }

    StringBuilder gen = new StringBuilder();
    StringBuilder ind = new StringBuilder();
    StringBuilder par = new StringBuilder();
    StringBuilder genes = new StringBuilder();
    StringBuilder res = new StringBuilder();

    row(gen, csv(runId), str(p.gen), str(n), str(highest), String.format(Locale.ROOT, "%.4f", (double)sum / n), csv(completedAt));

    int geneRows = 0;
    for(Tetris t : p.tetris_pop) {
      row(ind, csv(runId), str(t.uniqueID), str(t.birthGeneration), str(t.species_id), csv(t.birthType));

      if(t.birthType.equals("CROSSOVER")) {
        row(par, csv(runId), str(t.uniqueID), str(t.parentAID), csv("PARENT_A"));
        row(par, csv(runId), str(t.uniqueID), str(t.parentBID), csv("PARENT_B"));
      } else if(t.birthType.equals("ELITE_CLONE")) {
        row(par, csv(runId), str(t.uniqueID), str(t.cloneSourceID), csv("CLONE_SOURCE"));
      }

      int geneIndex = 0;
      NetMatrix[] w = t.brain.weights;
      for(int l = 0; l < w.length; l++) {
        for(int r = 0; r < w[l].rows; r++) {
          for(int c = 0; c < w[l].cols; c++) {
            row(genes, csv(runId), str(t.uniqueID), str(geneIndex++), str(l), str(r), str(c), fmtFloat(w[l].NetMatrix[r][c]));
            geneRows++;
          }
        }
      }

      row(res, csv(runId), str(t.uniqueID), str(t.birthGeneration), str(t.score), str(t.lines), str(t.tetris),
          str(t.total_back_to_back), str(t.single_clears), str(t.double_clears), str(t.triple_clears), str(t.pieces_placed));
    }

    File[] files = { file("generations.csv"), file("individuals.csv"), file("parentage.csv"), file("genes.csv"), file("game_results.csv") };
    String[] contents = { gen.toString(), ind.toString(), par.toString(), genes.toString(), res.toString() };
    try {
      appendAll(files, contents);
    } catch(Exception e) {
      reportError("Gen " + p.gen + " CSV 저장 실패 (" + (RETRY_FRAMES / FPS) + "초 후 재시도, E 키로 즉시 재시도)", e);
      nextRetryFrame = frameCount + RETRY_FRAMES;
      return false;
    }

    // 저장이 끝난 뒤에만 완료 상태로 표시
    lastExportedGen = p.gen;
    prevGen.clear();
    for(Tetris t : p.tetris_pop) {
      prevGen.put(t.uniqueID, new int[] { t.species_id, t.score });
      if(t.uniqueID > maxExportedID) maxExportedID = t.uniqueID;
    }
    individualsWritten += n;
    geneRowsWritten += geneRows;

    String msg = "Gen " + p.gen + " saved: " + n + " individuals, " + geneRows + " genes"
                 + (problems.size() > 0 ? " (" + problems.size() + " validation warnings - see console)" : "");
    setStatus(msg, problems.size() > 0);
    println("[CSV] " + msg + " -> " + runDir.getName());
    return true;
  }

  // 저장 직전 참조 무결성 검사. 문제 목록을 돌려준다 (비어 있으면 정상)
  ArrayList<String> validateGeneration(Population p) {
    ArrayList<String> problems = new ArrayList<String>();
    if(p.tetris_pop.length != populationSize) {
      problems.add("개체 수 " + p.tetris_pop.length + " != " + populationSize);
    }
    int expectedGenes = 0;
    for(NetMatrix m : p.tetris_pop[0].brain.weights) expectedGenes += m.rows * m.cols;

    HashSet<Integer> ids = new HashSet<Integer>();
    HashSet<Integer> families = new HashSet<Integer>();
    for(int fid : founderFamilyIds) families.add(fid);

    for(Tetris t : p.tetris_pop) {
      String who = "개체 #" + t.uniqueID;
      if(!ids.add(t.uniqueID)) problems.add(who + " ID 중복");
      if(t.uniqueID <= maxExportedID) problems.add(who + " ID가 이전 세대 ID와 겹침");
      if(t.birthGeneration != p.gen) problems.add(who + " 세대 " + t.birthGeneration + " != " + p.gen);
      if(!t.dead) problems.add(who + " 아직 생존 중 (미완료 점수)");
      if(!families.contains(t.species_id)) problems.add(who + " 가문 " + t.species_id + "이 families에 없음");
      int genes = 0;
      for(NetMatrix m : t.brain.weights) genes += m.rows * m.cols;
      if(genes != expectedGenes) problems.add(who + " 유전자 수 " + genes + " != " + expectedGenes);

      if(p.gen == 1) {
        if(!t.birthType.equals("FOUNDER")) problems.add(who + " 1세대인데 " + t.birthType);
        if(!founders.matches(t.species_id, t.brain)) problems.add(who + " 유전자가 고정 시조 유전자(" + founders.setId + ")와 다름");
      } else if(t.birthType.equals("CROSSOVER")) {
        int[] a = prevGen.get(t.parentAID);
        int[] b = prevGen.get(t.parentBID);
        if(a == null) problems.add(who + " PARENT_A #" + t.parentAID + "가 직전 세대에 없음");
        if(b == null) problems.add(who + " PARENT_B #" + t.parentBID + "가 직전 세대에 없음");
        if(a != null && b != null) {
          int expectedFamily = (a[1] > b[1]) ? a[0] : b[0];
          if(t.species_id != expectedFamily) problems.add(who + " 가문 승계 불일치 " + t.species_id + " != " + expectedFamily);
        }
      } else if(t.birthType.equals("ELITE_CLONE")) {
        int[] src = prevGen.get(t.cloneSourceID);
        if(src == null) problems.add(who + " CLONE_SOURCE #" + t.cloneSourceID + "가 직전 세대에 없음");
        else if(src[0] != t.species_id) problems.add(who + " 복제 원본과 가문이 다름");
        if(t.cloneSourceID == t.uniqueID) problems.add(who + " 복제 원본과 ID가 같음");
      } else {
        problems.add(who + " " + p.gen + "세대인데 " + t.birthType);
      }
    }
    return problems;
  }

  // 진행 중인 세대의 현재 상태를 별도 폴더(in_progress/)에 기록. 최종 CSV에는 섞지 않는다
  void writeInProgressSnapshot(Population p) {
    String capturedAt = timestamp("yyyy-MM-dd HH:mm:ss");
    boolean done = p.is_done();
    StringBuilder sb = new StringBuilder(H_SNAPSHOT).append('\n');
    for(Tetris t : p.tetris_pop) {
      row(sb, csv(runId), str(p.gen), str(t.uniqueID), str(t.species_id), csv(t.dead ? "DEAD" : "ALIVE"),
          str(t.score), str(t.lines), str(t.tetris), str(t.total_back_to_back), str(t.single_clears),
          str(t.double_clears), str(t.triple_clears), str(t.pieces_placed), done ? "1" : "0", csv(capturedAt));
    }
    File dir = new File(runDir, "in_progress");
    File f = new File(dir, "gen_" + p.gen + "_snapshot_" + timestamp("HHmmss_SSS") + ".csv");
    try {
      if(!dir.exists() && !dir.mkdirs()) throw new IOException("폴더를 만들 수 없습니다: " + dir.getAbsolutePath());
      writeFile(f, sb.toString(), false);
      setStatus("Snapshot (not final): in_progress/" + f.getName(), false);
      println("[CSV] 진행 중 스냅샷 저장 (최종 기록 아님): " + f.getAbsolutePath());
    } catch(Exception e) {
      reportError("스냅샷 저장 실패", e);
    }
  }

  // E 키: 저장 상태 출력 + 실패한 세대 즉시 재시도 예약
  void manualExport(Population p) {
    println("========== CSV EXPORT STATUS ==========");
    println("Run ID          : " + runId);
    println("Folder          : " + runDir.getAbsolutePath());
    println("Initialized     : " + initialized);
    println("Last saved gen  : " + (lastExportedGen == 0 ? "none" : str(lastExportedGen)));
    println("Rows written    : individuals " + individualsWritten + ", genes " + geneRowsWritten);
    println("Current gen     : " + p.gen + (p.is_done() ? " (complete)" : " (in progress - will be saved automatically when complete)"));
    println("Last status     : " + statusMessage);
    println("=======================================");
    if(!initialized || (p.is_done() && p.gen > lastExportedGen)) {
      nextRetryFrame = 0;  // 다음 프레임에 즉시 재시도
      println("[CSV] 저장 재시도를 요청했습니다.");
    }
  }

  // 모든 파일에 이어쓰기. 하나라도 실패하면 모든 파일을 원래 길이로 되돌린다
  void appendAll(File[] files, String[] contents) throws IOException {
    long[] sizes = new long[files.length];
    for(int i = 0; i < files.length; i++) {
      if(!files[i].exists()) throw new IOException("파일이 없습니다 (헤더 누락 방지를 위해 중단): " + files[i].getAbsolutePath());
      sizes[i] = files[i].length();
    }
    try {
      for(int i = 0; i < files.length; i++) {
        writeFile(files[i], contents[i], true);
      }
    } catch(IOException e) {
      for(int i = 0; i < files.length; i++) {
        if(files[i].length() == sizes[i]) continue;  // 변경되지 않은 파일은 그대로 둠
        try {
          RandomAccessFile raf = new RandomAccessFile(files[i], "rw");
          raf.setLength(sizes[i]);
          raf.close();
        } catch(IOException re) {
          println("[CSV][오류] 롤백 실패: " + files[i].getAbsolutePath() + " - " + re);
        }
      }
      throw e;
    }
  }

  void writeFile(File f, String content, boolean append) throws IOException {
    Writer w = new OutputStreamWriter(new FileOutputStream(f, append), StandardCharsets.UTF_8);
    try {
      w.write(content);
    } finally {
      w.close();
    }
  }

  void row(StringBuilder sb, String... fields) {
    for(int i = 0; i < fields.length; i++) {
      if(i > 0) sb.append(',');
      sb.append(fields[i]);
    }
    sb.append('\n');
  }

  // RFC 4180 방식: 쉼표·따옴표·개행이 있으면 따옴표로 감싸고 내부 따옴표는 두 번 쓴다
  String csv(String s) {
    if(s.indexOf(',') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0 || s.indexOf('\r') >= 0) {
      return "\"" + s.replace("\"", "\"\"") + "\"";
    }
    return s;
  }

  // float를 지수 표기 없이, 원래 float 값으로 정확히 되돌릴 수 있는 10진수로 출력
  String fmtFloat(float v) {
    return plainFloat(v);
  }

  // run_id 앞부분: RUN_OWNER(영문·숫자·_·-만 사용), 비어 있으면 RUN
  String runOwnerTag() {
    String tag = RUN_OWNER.trim().toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9_-]", "");
    return tag.length() == 0 ? "RUN" : tag;
  }

  String timestamp(String pattern) {
    return new SimpleDateFormat(pattern, Locale.ROOT).format(new Date());
  }

  void setStatus(String msg, boolean error) {
    statusMessage = msg;
    statusError = error;
  }

  void reportError(String what, Exception e) {
    setStatus(what + ": " + e.getMessage(), true);
    println("[CSV][오류] " + what);
    e.printStackTrace();
  }
}
