import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;
import java.util.TreeSet;
import java.util.LinkedHashMap;
import java.util.Collections;
import java.util.Comparator;

// ───────────── GA 실험 폴더(exports/<run_id>/) 읽기 ─────────────

// genes.csv 등 필요한 파일이 모두 있는 실험 폴더 목록 (최근 수정 순)
File[] listRuns(File exportsDir) {
  File[] dirs = exportsDir.listFiles();
  ArrayList<File> runs = new ArrayList<File>();
  if(dirs != null) {
    for(File d : dirs) {
      if(d.isDirectory() && new File(d, "experiments.csv").exists() && new File(d, "individuals.csv").exists()
         && new File(d, "genes.csv").exists() && new File(d, "game_results.csv").exists()) {
        runs.add(d);
      }
    }
  }
  Collections.sort(runs, new Comparator<File>() {
    public int compare(File a, File b) { return Long.compare(b.lastModified(), a.lastModified()); }
  });
  return runs.toArray(new File[0]);
}

// 헤더 이름 -> 컬럼 번호
HashMap<String, Integer> headerIndex(String header, File f, String... required) {
  HashMap<String, Integer> idx = new HashMap<String, Integer>();
  String[] h = header.split(",", -1);
  for(int i = 0; i < h.length; i++) idx.put(h[i].trim(), i);
  for(String r : required) {
    if(!idx.containsKey(r)) throw new RuntimeException(f.getName() + "에 '" + r + "' 컬럼이 없습니다: " + f.getAbsolutePath());
  }
  return idx;
}

BufferedReader openCsv(File f) throws IOException {
  return new BufferedReader(new InputStreamReader(new FileInputStream(f), StandardCharsets.UTF_8), 1 << 16);
}

// 실험 폴더에서 저장 완료된 세대 번호 목록
TreeSet<Integer> availableGenerations(File runDir) {
  TreeSet<Integer> gens = new TreeSet<Integer>();
  File f = new File(runDir, "game_results.csv");
  try {
    BufferedReader br = openCsv(f);
    try {
      String header = br.readLine();
      if(header == null) return gens;
      int g = headerIndex(header, f, "generation").get("generation");
      String line;
      while((line = br.readLine()) != null) {
        if(line.length() == 0) continue;
        gens.add(Integer.parseInt(line.split(",", -1)[g]));
      }
    } finally {
      br.close();
    }
  } catch(IOException e) {
    throw new RuntimeException("game_results.csv를 읽을 수 없습니다: " + e.getMessage());
  }
  return gens;
}

// "LAST"(또는 빈 칸) / 세대 번호 → 저장된 세대 하나
int parseGeneration(String spec, TreeSet<Integer> available) {
  if(available.isEmpty()) throw new RuntimeException("이 실험에는 아직 저장된 세대가 없습니다.");
  String s = spec.trim().toUpperCase(Locale.ROOT);
  if(s.length() == 0 || s.equals("LAST")) return available.last();
  int g;
  try {
    g = Integer.parseInt(s);
  } catch(NumberFormatException e) {
    throw new RuntimeException("세대는 LAST 또는 숫자로 입력하세요: " + spec);
  }
  if(!available.contains(g)) throw new RuntimeException(g + "세대는 저장되어 있지 않습니다 (저장된 세대: " + available.first() + "~" + available.last() + ").");
  return g;
}

// 선택한 세대의 개체 전원을 불러와 참가자로 만든다
ArrayList<PvpPlayer> loadPlayers(File runDir, int gen) {
  String runId = runDir.getName();
  try {
    // 1) 신경망 구조 (experiments.csv)
    File ef = new File(runDir, "experiments.csv");
    BufferedReader br = openCsv(ef);
    String eh = br.readLine();
    String er = br.readLine();
    br.close();
    if(eh == null || er == null) throw new RuntimeException("experiments.csv가 비어 있습니다.");
    HashMap<String, Integer> ei = headerIndex(eh, ef, "run_id", "input_nodes", "hidden_nodes", "output_nodes", "hidden_layers");
    String[] ev = er.split(",", -1);
    int iN = Integer.parseInt(ev[ei.get("input_nodes")]);
    int hN = Integer.parseInt(ev[ei.get("hidden_nodes")]);
    int oN = Integer.parseInt(ev[ei.get("output_nodes")]);
    int hL = Integer.parseInt(ev[ei.get("hidden_layers")]);
    runId = ev[ei.get("run_id")];

    // 세대별 폴더(v2.1.0 by_generation/gen_NNNN)가 있으면 그 세대 파일만 읽고, 없으면 전체 CSV에서 골라 읽는다
    File genDir = new File(runDir, "by_generation/gen_" + nf(gen, 4));
    File src = new File(genDir, "genes.csv").exists() ? genDir : runDir;
    println("[PvP] " + gen + "세대 데이터: " + src.getAbsolutePath());

    // 2) 해당 세대의 개체 전원 (파일 순서 = GA 개체 순서)
    File gf = new File(src, "game_results.csv");
    LinkedHashMap<Integer, int[]> chosen = new LinkedHashMap<Integer, int[]>();  // id -> {generation, GA score, family}
    br = openCsv(gf);
    try {
      HashMap<String, Integer> gi = headerIndex(br.readLine(), gf, "individual_id", "generation", "score");
      String line;
      while((line = br.readLine()) != null) {
        if(line.length() == 0) continue;
        String[] v = line.split(",", -1);
        if(Integer.parseInt(v[gi.get("generation")]) != gen) continue;
        chosen.put(Integer.parseInt(v[gi.get("individual_id")]), new int[] { gen, Integer.parseInt(v[gi.get("score")]), 0 });
      }
    } finally {
      br.close();
    }
    if(chosen.size() < 2) throw new RuntimeException(gen + "세대 개체가 " + chosen.size() + "명입니다. 배틀로얄은 2명 이상 필요합니다.");

    // 3) 가문 ID (individuals.csv)
    File inf = new File(src, "individuals.csv");
    br = openCsv(inf);
    try {
      HashMap<String, Integer> ii = headerIndex(br.readLine(), inf, "individual_id", "family_id");
      String line;
      while((line = br.readLine()) != null) {
        if(line.length() == 0) continue;
        String[] v = line.split(",", -1);
        int[] c = chosen.get(Integer.parseInt(v[ii.get("individual_id")]));
        if(c != null) c[2] = Integer.parseInt(v[ii.get("family_id")]);
      }
    } finally {
      br.close();
    }

    // 4) 유전자 (genes.csv는 클 수 있으므로 한 줄씩 읽으며 선택된 개체만 사용)
    HashMap<Integer, NeuralNet> brains = new HashMap<Integer, NeuralNet>();
    HashMap<Integer, Integer> geneCount = new HashMap<Integer, Integer>();
    for(int id : chosen.keySet()) {
      brains.put(id, new NeuralNet(iN, hN, oN, hL, false));
      geneCount.put(id, 0);
    }
    File genf = new File(src, "genes.csv");
    br = openCsv(genf);
    try {
      HashMap<String, Integer> gx = headerIndex(br.readLine(), genf, "individual_id", "layer_index", "row_index", "col_index", "weight");
      int cId = gx.get("individual_id"), cL = gx.get("layer_index"), cR = gx.get("row_index"), cC = gx.get("col_index"), cW = gx.get("weight");
      String line;
      while((line = br.readLine()) != null) {
        if(line.length() == 0) continue;
        String[] v = line.split(",", -1);
        int id = Integer.parseInt(v[cId]);
        NeuralNet b = brains.get(id);
        if(b == null) continue;
        b.weights[Integer.parseInt(v[cL])].NetMatrix[Integer.parseInt(v[cR])][Integer.parseInt(v[cC])] = Float.parseFloat(v[cW]);
        geneCount.put(id, geneCount.get(id) + 1);
      }
    } finally {
      br.close();
    }
    int expected = 0;
    for(NetMatrix m : new NeuralNet(iN, hN, oN, hL, false).weights) expected += m.rows * m.cols;

    // 5) 가문 시조 이름 (families.csv, 없으면 번호만 표시)
    HashMap<Integer, String> names = new HashMap<Integer, String>();
    File ff = new File(runDir, "families.csv");
    if(ff.exists()) {
      br = openCsv(ff);
      try {
        HashMap<String, Integer> fi = headerIndex(br.readLine(), ff, "family_id", "founder_name");
        String line;
        while((line = br.readLine()) != null) {
          if(line.length() == 0) continue;
          String[] v = line.split(",", -1);
          names.put(Integer.parseInt(v[fi.get("family_id")]), v[fi.get("founder_name")]);
        }
      } finally {
        br.close();
      }
    }

    ArrayList<PvpPlayer> players = new ArrayList<PvpPlayer>();
    for(int id : chosen.keySet()) {
      if(geneCount.get(id) != expected) {
        throw new RuntimeException("개체 #" + id + "의 유전자 " + geneCount.get(id) + "개 (기대 " + expected + "개) - genes.csv가 불완전합니다.");
      }
      int[] c = chosen.get(id);
      PvpPlayer p = new PvpPlayer(runId, id, c[0], c[2], c[1], brains.get(id));
      if(names.containsKey(c[2])) p.founderName = names.get(c[2]);
      players.add(p);
    }
    return players;
  } catch(IOException e) {
    throw new RuntimeException("실험 데이터를 읽을 수 없습니다 (" + runDir.getAbsolutePath() + "): " + e.getMessage());
  } catch(NumberFormatException e) {
    throw new RuntimeException("실험 CSV의 숫자 형식 오류: " + e.getMessage());
  }
}

// ───────────── PvP 결과 CSV 쓰기: exports/<run_id>/pvp/ (경기를 할 때마다 같은 파일에 이어 씀) ─────────────

class PvpWriter {
  final String H_MATCHES      = "match_id,run_id,generation,program_version,block_seed,player_count,max_steps,started_at,ended_at,duration_steps,duration_ms,"
                              + "highest_score,highest_score_individual_id,winner_individual_id,end_reason";
  final String H_PARTICIPANTS = "match_id,run_id,individual_id,generation,family_id,target_strategy,final_rank,score,lines,garbage_lines_cleared,"
                              + "lines_sent,lines_received,pieces_placed,tetris_count,kills,eliminated_step";

  File dir;
  String error = null;

  PvpWriter(File runDir) {
    dir = new File(runDir, "pvp");
  }

  // 전역 고유 경기 ID: PVP_<시각>_<UUID 앞 8자리>
  String newMatchId() {
    return "PVP_" + now("yyyyMMdd_HHmmss") + "_" + java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase(Locale.ROOT);
  }

  void writeMatch(PvpMatch m) {
    StringBuilder mr = new StringBuilder();
    PvpPlayer w = m.players[m.order[0]];
    PvpPlayer top = m.topScorer();
    mr.append(join(m.matchId, w.runId, str(m.generation), PVP_VERSION, Long.toString(m.seed), str(m.players.length), str(m.maxSteps),
                   m.startedAt, m.endedAt, str(m.steps), Long.toString(m.durationMs),
                   str(top.score), str(top.individualId), str(w.individualId), m.endReason)).append('\n');
    StringBuilder pr = new StringBuilder();
    for(PvpPlayer p : m.players) {
      pr.append(join(m.matchId, p.runId, str(p.individualId), str(p.generation), str(p.familyId), p.strategy, str(p.rank), str(p.score), str(p.lines),
                     str(p.garbageCleared), str(p.linesSent), str(p.linesReceived), str(p.pieces_placed), str(p.tetris), str(p.kills),
                     p.deathStep == 0 ? "" : str(p.deathStep))).append('\n');
    }
    try {
      if(!dir.exists() && !dir.mkdirs()) throw new IOException("폴더를 만들 수 없습니다: " + dir.getAbsolutePath());
      ensureHeader("pvp_participants.csv", H_PARTICIPANTS);
      ensureHeader("pvp_matches.csv", H_MATCHES);
      write("pvp_participants.csv", pr.toString(), true);  // 참가자 먼저 → 경기 행이 있으면 참가자 행도 반드시 있음
      write("pvp_matches.csv", mr.toString(), true);
      println("[PvP] " + m.matchId + " 저장: 우승 #" + w.individualId + ", 최고 점수 " + top.score + " (" + m.endReason + ")");
    } catch(IOException e) {
      error = m.matchId + " 저장 실패: " + e.getMessage();
      println("[PvP][오류] " + error);
    }
  }

  // 파일이 없으면 헤더로 새로 만들고, 있으면 헤더가 현재 형식과 같은지 확인 (다른 형식에 섞어 쓰지 않음)
  void ensureHeader(String name, String header) throws IOException {
    File f = new File(dir, name);
    if(!f.exists() || f.length() == 0) {
      write(name, header + "\n", false);
      return;
    }
    BufferedReader br = openCsv(f);
    String first;
    try { first = br.readLine(); } finally { br.close(); }
    if(!header.equals(first)) throw new IOException(f.getAbsolutePath() + "의 헤더가 현재 형식과 다릅니다 (이전 버전 파일). 파일 이름을 바꾸거나 옮긴 뒤 다시 실행하세요.");
  }

  void write(String name, String content, boolean append) throws IOException {
    Writer w = new OutputStreamWriter(new FileOutputStream(new File(dir, name), append), StandardCharsets.UTF_8);
    try {
      w.write(content);
    } finally {
      w.close();
    }
  }

  String join(String... f) {
    StringBuilder sb = new StringBuilder();
    for(int i = 0; i < f.length; i++) {
      if(i > 0) sb.append(',');
      sb.append(f[i]);
    }
    return sb.toString();
  }

  String csv(String s) {
    if(s.indexOf(',') >= 0 || s.indexOf('"') >= 0 || s.indexOf('\n') >= 0) return "\"" + s.replace("\"", "\"\"") + "\"";
    return s;
  }
}

String now(String pattern) {
  return new SimpleDateFormat(pattern, Locale.ROOT).format(new Date());
}
