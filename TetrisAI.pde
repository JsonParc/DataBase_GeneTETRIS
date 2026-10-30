final int CELL_SIZE = 20;  // 40에서 20으로 줄임 (블록 크기 절반)
final int ROWS = 20;
final int COLS = 10;
final int FPS = 300;

final int HIDDEN_LAYERS = 1;
final int HIDDEN_NODES = 4;

final int POPULATION_SIZE = 200;

final String PROGRAM_VERSION = "2.0.0";

// ── 공통 시조 유전자 (모든 팀원·모든 실행이 같은 값으로 시작) ──
// 일반 실행은 data/<FOUNDER_GENOME_FILE>을 읽기만 하며, 파일의 SHA-256이 아래 값과 다르면 시작하지 않는다.
final String FOUNDER_SET_ID = "FOUNDERS_V1";
final String FOUNDER_GENOME_FILE = "founder_genomes_v1.csv";
final String FOUNDER_GENOME_SHA256 = "6fd10017ed2731d85867685181e3925a4c48bd78c7426d4101c815958a4ff378";
// true: 시뮬레이션 대신 새 시조 유전자 파일을 한 번 생성하고 멈춘다 (새 시조 집합을 의도적으로 만들 때만)
final boolean GENERATE_FOUNDER_GENOMES = false;

// run_id 앞에 붙는 실행자 이름 (영문/숫자, 예: "DONGHYUN"). 비워 두면 "RUN"
final String RUN_OWNER = "";

// 전체 개체 화면 한 페이지의 최대 격자 크기 (최대 40개씩, 200개는 5페이지)
final int MULTI_MAX_COLS = 10;
final int MULTI_MAX_ROWS = 4;

final boolean HUMAN_PLAY = false;
final boolean CHECK_NEXT = true;
final boolean GUIDE = false;
boolean SHOW_ALL = false;  // final 제거하여 런타임에 변경 가능하게 함

// 고유 ID 관리를 위한 전역 변수
int nextUniqueID = 1;

// 전역 최고 기록 추적 (원본 개체의 불변 스냅샷으로 보관)
int allTimeHighScore = 0;
TetrisRecord allTimeRecord = null;
boolean hasUnsavedRecord = false; // 저장되지 않은 새 기록이 있는지

CsvExporter exporter;
PFont uiFont;
FounderGenomes founderGenomes;
String haltMessage = null;  // null이 아니면 시뮬레이션을 시작하지 않고 이 메시지를 표시

final int[][][] tetrominos = {
            {{1, 1, 1},
            {0, 1, 0}},
            
            {{0, 2, 2},
            {2, 2, 0}},
            
            {{3, 3, 0},
            {0, 3, 3}},
            
            {{4, 0, 0},
            {4, 4, 4}},
            
            {{0, 0, 5},
            {5, 5, 5}},
            
            {{6, 6, 6, 6}},
            
            {{7, 7},
            {7, 7}}
          };
          
final color[] colors = { color(0,0,0), color(255,0,0), color(0,255,0), color(0,0,255), color(255,255,0), color(255,0,255), color(0, 255,255), color(255,255,255) };

int highscore = 0;

float mutation_rate = 0.05;
float default_mutation_rate = mutation_rate;

Population pop;

Tetris player;

void settings() {
   size(1200,700);  // 세로 길이를 900에서 700으로 줄임
}

void setup() {
    frameRate(FPS);
    setupKoreanFont();
    if(HUMAN_PLAY)
      player = new Tetris();
    else {
      try {
        validateFounderNames(POPULATION_SIZE);
        File genomeFile = new File(dataPath(FOUNDER_GENOME_FILE));
        if(GENERATE_FOUNDER_GENOMES) {
          FounderGenomes g = generateFounderGenomes(genomeFile, FOUNDER_SET_ID, POPULATION_SIZE, 5, HIDDEN_NODES, 1, HIDDEN_LAYERS);
          haltMessage = "새 시조 유전자 파일을 생성했습니다 (시뮬레이션은 시작하지 않음)\n\n"
                      + g.file.getAbsolutePath() + "\n" + FOUNDER_SET_ID + ": 시조 " + g.familyCount + " x 유전자 " + g.genesPerFamily() + "\n"
                      + "SHA-256: " + g.sha256 + "\n\n"
                      + "TetrisAI.pde에서 FOUNDER_GENOME_SHA256에 위 값을 넣고 GENERATE_FOUNDER_GENOMES = false 로 바꾼 뒤 다시 실행하세요.";
          println(haltMessage);
          return;
        }
        founderGenomes = loadFounderGenomes(genomeFile, FOUNDER_SET_ID, POPULATION_SIZE, 5, HIDDEN_NODES, 1, HIDDEN_LAYERS);
        if(!founderGenomes.sha256.equals(FOUNDER_GENOME_SHA256)) {
          throw new RuntimeException("시조 유전자 파일이 배포본과 다릅니다 (SHA-256 불일치).\n파일: " + founderGenomes.sha256
                                     + "\n기대: " + FOUNDER_GENOME_SHA256 + "\n배포받은 원본 " + FOUNDER_GENOME_FILE + " 파일로 교체하세요.");
        }
        println("[Founders] 고정 시조 유전자 로드: " + FOUNDER_SET_ID + " (" + founderGenomes.familyCount + " x " + founderGenomes.genesPerFamily()
                + "), SHA-256 " + founderGenomes.sha256);
        pop = new Population(founderGenomes);
        validateFounderPopulation(pop);
        exporter = new CsvExporter(pop, founderGenomes);
      } catch(RuntimeException e) {
        pop = null;
        haltMessage = "[시작 중단] " + e.getMessage();
        println(haltMessage);
      }
    }
}

// 시조 이름(한글)이 깨지지 않도록 한글 글리프가 있는 시스템 폰트를 사용
void setupKoreanFont() {
    String sample = "동현 지훈 규리 가문";
    String[] candidates = {"Malgun Gothic", "맑은 고딕", "Apple SD Gothic Neo", "AppleSDGothicNeo-Regular",
                           "NanumGothic", "나눔고딕", "Noto Sans CJK KR", "Noto Sans KR", "Gulim", "굴림", "Dialog", "SansSerif"};
    for(String name : candidates) {
        PFont f = createFont(name, 18, true);
        Object nativeFont = f.getNative();
        if(nativeFont instanceof java.awt.Font && ((java.awt.Font)nativeFont).canDisplayUpTo(sample) == -1) {
            uiFont = f;
            println("[Font] 한글 표시 폰트: " + ((java.awt.Font)nativeFont).getFontName() + " (요청: " + name + ")");
            break;
        }
    }
    if(uiFont == null) {
        println("[Font][경고] 한글을 표시할 수 있는 폰트를 찾지 못했습니다. 시조 이름이 깨질 수 있습니다.");
        return;
    }
    textFont(uiFont);
}

void draw() {
    background(0);
    if(haltMessage != null) {  // 시조 유전자 문제 등으로 시뮬레이션을 시작하지 않은 상태
        fill(255, 120, 120);
        textAlign(LEFT, TOP);
        textSize(18);
        text(haltMessage, 30, 30, width - 60, height - 60);
        return;
    }
    if(HUMAN_PLAY) {
        player.update();
        player.show_game();
        player.show_next();
        if(player.dead) {
           highscore = player.score;
           player = new Tetris(); 
        }
    } else {
      if(pop.is_done()) {
          // 세대 종료: 최종 점수로 역대 기록 확정 → CSV 저장 → 저장 성공 시에만 세대교체
          checkAndSaveNewRecord();
          if(exporter.exportGeneration(pop)) {
              int new_highscore = pop.find_best_tetris().score;
              if(new_highscore > highscore)
                  highscore = new_highscore;
              pop.natural_selection();
          } else {
              pop.show();  // 저장 실패: 다음 세대로 넘어가지 않고 재시도 대기
          }
      } else{
          pop.update();
          pop.show();
      }
    }
    show();
}

void show() {
    
    if(!SHOW_ALL) {  // 단일 뷰일 때만 벽과 UI 표시
        //WALL
        stroke(0);
        for(int i = 0; i < ROWS+2; i++) {
           fill(100);
           rect(0,i*CELL_SIZE, CELL_SIZE, CELL_SIZE);
           rect(220,i*CELL_SIZE, CELL_SIZE, CELL_SIZE);  // 440에서 220으로 조정
           rect(440,i*CELL_SIZE, CELL_SIZE, CELL_SIZE);  // 880에서 440으로 조정
        }
        for(int i = 0; i < 23; i++) {  // width/CELL_SIZE 대신 고정값 사용
           fill(100);
           rect(20+i*CELL_SIZE,0, CELL_SIZE, CELL_SIZE);  // 40에서 20으로 조정
           rect(20+i*CELL_SIZE,420, CELL_SIZE, CELL_SIZE);  // 840에서 420으로 조정
        }
        
        // 오른쪽 빈 공간에 정보 표시 (x: 500부터 시작)
        fill(255);
        textAlign(LEFT);
        textSize(18);
        if(HUMAN_PLAY) {
          text("Score: "+player.score, 500,60);
          text("Lines: "+player.lines, 500,85);
          text("Tetris: "+player.tetris, 500,110);
          text("Highscore : "+highscore, 500,135);
        } else {
          show_single_view_info();
        }
    } else {
        // 멀티 뷰일 때는 간단한 정보만 표시 (더 컴팩트하게)
        Tetris gen_best = pop.find_best_tetris();
        fill(255);
        textAlign(LEFT, BASELINE);
        textSize(16);  // 좀 더 작게
        text("Gen: "+pop.gen, 20, 25);
        text("Gen Best: "+gen_best.score+" (#"+gen_best.uniqueID+" "+founderName(gen_best.species_id)+")", 110, 25);
        text("All-Time: "+allTimeHighScore, 420, 25);
        text("Alive: " + countAlive() + "/" + pop.tetris_pop.length, 570, 25);
        text("On screen ID: " + pop.best_tetris.uniqueID + " (" + founderName(pop.best_tetris.species_id) + ")", 720, 25);
    }
}

// 단일 화면 정보: 화면의 대표 개체 / 세대 최고 개체(사망 포함) / 역대 최고 개체를 구분해서 표시
void show_single_view_info() {
    Tetris rep = pop.best_tetris;             // 현재 화면에서 플레이 중인 대표 개체
    Tetris gen_best = pop.find_best_tetris(); // 현재 세대 최고 점수 개체 (사망 개체 포함)
    int x = 500;
    int y = 40;
    int lh = 25;

    textAlign(LEFT, BASELINE);
    textSize(18);
    fill(255);
    text("Generation: " + pop.gen, x, y);
    text("Individual ID: " + rep.uniqueID, x, y += lh);
    text("Founder ID: " + rep.species_id, x, y += lh);
    text("Founder: " + founderName(rep.species_id), x, y += lh);
    text("Family: " + familyName(rep.species_id), x, y += lh);
    text("Current Score: " + rep.score, x, y += lh);
    text("Lines: " + rep.lines + "   Tetris: " + rep.tetris, x, y += lh);
    text("Generation Best Score: " + gen_best.score, x, y += lh);
    text("All-Time High Score: " + allTimeHighScore, x, y += lh);
    text("Mutation Rate : " + mutation_rate*100 + "%", x, y += lh);
    // (뉴럴 네트워크는 Population.show()에서 500,300 위치에 그려짐)

    // 오른쪽 열: 세대 최고 / 역대 최고 / CSV 상태
    x = 800;
    y = 40;
    lh = 22;
    textSize(16);
    fill(255, 255, 0);
    text("GENERATION BEST (incl. dead)", x, y);
    fill(255);
    text("Individual ID: " + gen_best.uniqueID, x, y += lh);
    text("Founder: " + founderName(gen_best.species_id) + " (#" + gen_best.species_id + ")", x, y += lh);
    text("Score: " + gen_best.score + (gen_best.dead ? "  [DEAD]" : "  [ALIVE]"), x, y += lh);

    y += 34;
    fill(255, 255, 0); // 노란색으로 강조
    text("ALL-TIME RECORD", x, y);
    fill(255);
    text("High Score: " + allTimeHighScore, x, y += lh);
    if(allTimeRecord != null) {
        text("Record Gen: " + allTimeRecord.generation, x, y += lh);
        text("Record ID: " + allTimeRecord.individualId, x, y += lh);
        text("Founder: " + founderName(allTimeRecord.familyId) + " (#" + allTimeRecord.familyId + ")", x, y += lh);
        text("Status: " + (allTimeRecord.isFinal ? "FINAL" : "IN PROGRESS"), x, y += lh);
    }
    // 미저장 기록 알림
    if(hasUnsavedRecord) {
        fill(255, 100, 100); // 빨간색으로 강조
        text("NEW RECORD NOT SAVED!", x, y += lh);
    }

    y += 34;
    fill(255, 255, 0);
    text("CSV EXPORT", x, y);
    fill(255);
    textSize(13);
    text("Folder: exports/" + exporter.runId, x, y += 20);
    text("Last saved generation: " + (exporter.lastExportedGen == 0 ? "-" : str(exporter.lastExportedGen))
         + "   (gen " + pop.gen + (pop.is_done() ? " complete)" : " in progress)"), x, y += 20);
    if(exporter.statusError) fill(255, 100, 100); else fill(120, 255, 120);
    text(exporter.statusMessage, x, y + 6, width - x - 10, 160);  // 오류 원인(긴 경로 포함)이 잘리지 않도록

    fill(150); // 회색으로 안내 메시지
    textSize(14);
    text("SPACE: multi-view   S: save record   ESC: save & exit", 500, 540);
    text("E: CSV status / retry   P: in-progress snapshot (not final)", 500, 560);
}

int countAlive() {
    if(HUMAN_PLAY || pop == null) return 0;
    int count = 0;
    for(int i = 0; i < pop.tetris_pop.length; i++) {
        if(!pop.tetris_pop[i].dead) count++;
    }
    return count;
}

void checkAndSaveNewRecord() {
    if(pop == null) return;
    
    // 기록 보유 개체가 이번 세대에서 아직 플레이 중이었다면 최신 상태로 스냅샷 갱신
    if(allTimeRecord != null && allTimeRecord.generation == pop.gen) {
        Tetris holder = pop.find_by_id(allTimeRecord.individualId);
        if(holder != null && (holder.score != allTimeRecord.score || holder.dead != allTimeRecord.isFinal)) {
            if(holder.score != allTimeRecord.score) hasUnsavedRecord = true;
            allTimeRecord = new TetrisRecord(holder);
            allTimeHighScore = holder.score;
        }
    }

    // 현재 세대에서 가장 점수가 높은 AI 찾기 (사망 개체 포함)
    Tetris currentBest = pop.find_best_tetris();
    if(currentBest == null) return;

    // 새로운 최고 기록인지 확인
    if(currentBest.score > allTimeHighScore) {
        boolean newHolder = (allTimeRecord == null || allTimeRecord.individualId != currentBest.uniqueID);
        allTimeHighScore = currentBest.score;
        allTimeRecord = new TetrisRecord(currentBest); // 원본 정보 스냅샷 (새 ID를 소비하지 않음)
        hasUnsavedRecord = true; // 새 기록 플래그 설정
        if(!newHolder) return;  // 같은 개체의 점수 상승은 콘솔에 반복 출력하지 않음

        println("🏆 NEW ALL-TIME HIGH SCORE! 🏆");
        println("Score: " + allTimeHighScore + " (Generation " + allTimeRecord.generation + ", ID " + allTimeRecord.individualId
                + ", " + familyName(allTimeRecord.familyId) + ")");
        println("Press S to save this record!");
        
        // 자동 저장하지 않음 - 수동으로만 저장
    }
}

String getNextFilename() {
    // data 폴더에서 기존 파일들을 확인하여 다음 버전 번호 결정
    String baseName = "best_ai";
    String extension = ".json";
    
    // 기본 파일이 있는지 확인
    File baseFile = new File(dataPath(baseName + extension));
    if (!baseFile.exists()) {
        return baseName + extension;
    }
    
    // 버전 파일들 확인
    int version = 1;
    File versionFile;
    do {
        versionFile = new File(dataPath(baseName + version + extension));
        version++;
    } while (versionFile.exists());
    
    return baseName + (version - 1) + extension;
}

void saveBestAI() {
    if(allTimeRecord == null) {
        println("No all-time best AI to save yet.");
        return;
    }

    TetrisRecord best = allTimeRecord;
    JSONObject aiData = new JSONObject();

    // 기본 정보 저장 (역대 최고 기록, 원본 개체 기준)
    aiData.setInt("generation", best.generation);
    aiData.setInt("score", best.score);
    aiData.setInt("lines", best.lines);
    aiData.setInt("tetris", best.tetris);
    aiData.setInt("back_to_back_count", best.backToBackCount);
    aiData.setInt("total_back_to_back", best.totalBackToBack);
    aiData.setInt("single_clears", best.singleClears);
    aiData.setInt("double_clears", best.doubleClears);
    aiData.setInt("triple_clears", best.tripleClears);
    aiData.setInt("pieces_placed", best.piecesPlaced);
    aiData.setInt("species_id", best.familyId);
    aiData.setInt("unique_id", best.individualId);
    aiData.setInt("founder_id", best.familyId);
    aiData.setString("founder_name", founderName(best.familyId));
    aiData.setString("family_name", familyName(best.familyId));
    aiData.setBoolean("is_final", best.isFinal);
    if(exporter != null) aiData.setString("run_id", exporter.runId);
    aiData.setString("timestamp", year() + "-" + month() + "-" + day() + "_" + hour() + "-" + minute() + "-" + second());
    aiData.setString("record_type", "ALL_TIME_HIGH_SCORE");
    
    // 뉴럴 네트워크 가중치 저장
    // Neural Network 가중치 저장 (NetMatrix 배열 구조 사용)
    JSONObject brainData = new JSONObject();
    
    JSONArray weightsArray = new JSONArray();
    for(int w = 0; w < best.weights.length; w++) {
        JSONObject weightData = new JSONObject();
        weightData.setInt("rows", best.weights[w].length);
        weightData.setInt("cols", best.weights[w][0].length);

        JSONArray matrixData = new JSONArray();
        for(int i = 0; i < best.weights[w].length; i++) {
            JSONArray rowData = new JSONArray();
            for(int j = 0; j < best.weights[w][i].length; j++) {
                rowData.setFloat(j, best.weights[w][i][j]);
            }
            matrixData.setJSONArray(i, rowData);
        }
        weightData.setJSONArray("matrix", matrixData);
        weightsArray.setJSONObject(w, weightData);
    }
    brainData.setJSONArray("weights", weightsArray);
    
    // 네트워크 구조 정보
    brainData.setInt("input_nodes", best.iNodes);
    brainData.setInt("hidden_nodes", best.hNodes);
    brainData.setInt("output_nodes", best.oNodes);
    brainData.setInt("hidden_layers", best.hLayers);
    
    aiData.setJSONObject("brain", brainData);
    
    // 버전 관리로 파일 저장
    String filename = getNextFilename();
    saveJSONObject(aiData, "data/" + filename);
    
    // 기본 파일도 업데이트 (BestAI 호환성을 위해)
    saveJSONObject(aiData, "data/best_ai.json");
    
    hasUnsavedRecord = false; // 저장 완료 플래그
    
    println("Best AI saved to " + filename);
    println("Score: " + best.score + ", Generation: " + best.generation + ", ID: " + best.individualId + ", " + familyName(best.familyId));
}

void keyPressed() {
  if(haltMessage != null) {  // 시작 중단 상태: ESC로 종료만 가능
    if(key == ESC) { key = 0; exit(); }
    return;
  }
  if(key == CODED && HUMAN_PLAY) {
     switch(keyCode) {
        case UP:
          player.move(0);
          break;
        case DOWN:
          player.move(1);
          break;
        case LEFT:
          player.move(2);
          break;
        case RIGHT:
          player.move(3);
          break;
     }
  }
  
  // 전체 개체 화면: 좌우 방향키로 페이지 이동
  if(key == CODED && !HUMAN_PLAY && SHOW_ALL) {
    if(keyCode == LEFT) pop.view_page--;
    if(keyCode == RIGHT) pop.view_page++;  // 범위는 그릴 때 보정
  }

  // 스페이스바로 단일/멀티 뷰 전환
  if(key == ' ' && !HUMAN_PLAY) {
    SHOW_ALL = !SHOW_ALL;
  }

  // A 키: 전체 개체 화면에서 살아있는 개체만 / 사망 포함 전체 전환
  if((key == 'a' || key == 'A') && !HUMAN_PLAY) {
    pop.view_all = !pop.view_all;
    pop.view_page = 0;
  }

  // E 키: CSV 저장 상태 확인 + 실패한 완료 세대 즉시 재시도
  if((key == 'e' || key == 'E') && !HUMAN_PLAY) {
    exporter.manualExport(pop);
  }

  // P 키: 진행 중인 세대의 현재 상태를 별도 스냅샷으로 저장 (최종 기록 아님)
  if((key == 'p' || key == 'P') && !HUMAN_PLAY) {
    exporter.writeInProgressSnapshot(pop);
  }

  // ESC 키로 역대 최고 AI 저장하고 종료
  if(key == ESC && !HUMAN_PLAY) {
    key = 0; // ESC 기본 동작 방지
    // 이미 완료됐지만 아직 저장되지 않은 세대가 있으면 마지막으로 저장 시도
    if(pop.is_done() && pop.gen > exporter.lastExportedGen) {
      checkAndSaveNewRecord();
      exporter.nextRetryFrame = 0;
      exporter.exportGeneration(pop);
    }
    saveBestAI();
    println("All-time best AI saved! Exiting...");
    exit();
  }
  
  // S 키로 역대 최고 AI 저장 (종료하지 않음)
  if(key == 's' || key == 'S') {
    if(!HUMAN_PLAY) {
      saveBestAI();
      println("All-time best AI saved!");
    }
  }
}
