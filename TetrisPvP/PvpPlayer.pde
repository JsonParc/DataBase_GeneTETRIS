// 배틀로얄 참가자 1명 = 저장된 GA 개체 1개의 신경망으로 플레이하는 테트리스 게임
// 블록 이동·낙하·AI 배치 판단(find_best_move)은 TetrisAI/Tetris.pde와 똑같이 유지해야 한다 (학습 때와 같은 실력으로 대결)
class PvpPlayer {
  // 출처 (GA 실험의 개체)
  String runId;
  int individualId;
  int generation;
  int familyId;
  String founderName = "?";  // 가문 시조 이름 (families.csv, 화면 표시용)
  int gaScore;          // GA에서 받은 점수 (참고용)
  NeuralNet brain;

  // 게임 상태
  java.util.Random pieceRng;
  int[][] current_tet;
  int[][] next_tet;
  Matrix game_map;
  Matrix game_map_copy;
  int game_step = 0;
  PVector tet_pos = new PVector(4, 0);
  ArrayList<Integer> moves_to_make;
  int move_itterator = 0;
  boolean dead = false;

  // 기록
  int score = 0;
  int lines = 0;              // 일반 줄 제거 수 (방해 줄 제외)
  int garbageCleared = 0;     // 지운 방해 줄 수 (점수 없음)
  int tetris = 0;
  int total_back_to_back = 0;
  boolean last_clear_tetris = false;
  int pieces_placed = 0;
  int linesSent = 0;          // 상대에게 보낸 방해 줄 수
  int linesReceived = 0;      // 실제로 받아서 판에 들어온 방해 줄 수
  int pendingGarbage = 0;     // 받았지만 아직 판에 들어오지 않은 방해 줄 (다음 블록이 놓일 때 들어옴)
  int lastAttacker = -1;      // 마지막으로 나를 공격한 참가자 번호
  int kills = 0;
  int deathStep = 0;          // 탈락한 경기 단계 (0 = 생존)
  int rank = 0;
  int target = -1;            // 마지막 공격 대상 (화면 표시용)
  String strategy = "RANDOM"; // 공격 대상 선택 방식 (경기 시작 시 무작위 배정): RANDOM / LEADER / WEAKEST

  PvpPlayer(String runId, int individualId, int generation, int familyId, int gaScore, NeuralNet brain) {
    this.runId = runId;
    this.individualId = individualId;
    this.generation = generation;
    this.familyId = familyId;
    this.gaScore = gaScore;
    this.brain = brain;
  }

  // 경기 시작: 모든 참가자가 같은 seed → 같은 블록 순서
  void reset(long pieceSeed) {
    pieceRng = new java.util.Random(pieceSeed);
    current_tet = new_tet();
    next_tet = new_tet();
    game_map = new Matrix(ROWS, COLS);
    game_map_copy = game_map.copy();
    game_step = 0;
    tet_pos = new PVector(4, 0);
    dead = false;
    score = lines = garbageCleared = tetris = total_back_to_back = pieces_placed = 0;
    last_clear_tetris = false;
    linesSent = linesReceived = pendingGarbage = kills = deathStep = rank = 0;
    lastAttacker = -1;
    target = -1;
    moves_to_make = find_best_move();
    move_itterator = 0;
  }

  // 한 단계 진행. 이번 단계에 블록을 놓으며 보낼 공격 줄 수를 돌려준다
  int step(java.util.Random matchRng) {
    if(dead) return 0;
    if(move_itterator+1 < moves_to_make.size()) {
      move(moves_to_make.get(move_itterator++));
    } else {
      move(1);
    }
    game_step++;
    game_map_copy = game_map.copy();
    game_map_copy.insert_all_at(tet_pos.x, tet_pos.y, current_tet);
    if(game_step < 60) return 0;

    game_step = 0;
    tet_pos.y++;
    if(!game_map.check_collision(tet_pos.x, tet_pos.y, current_tet)) return 0;

    // 블록 고정
    game_map = game_map_copy.copy();
    int normal = 0, garbage = 0;
    for(int r = 0; r < ROWS; r++) {
      if(!game_map.is_row_full(r)) continue;
      if(row_has_garbage(r)) garbage++; else normal++;
    }
    game_map.clear_lines();
    pieces_placed++;

    // 점수: TetrisAI와 같은 규칙, 단 방해 줄은 지워도 점수·공격 없음 (높이만 줄어듦)
    lines += normal;
    garbageCleared += garbage;
    if(normal >= 4) {
      tetris++;
      if(last_clear_tetris) {
        total_back_to_back++;
        score += 1200;
      } else {
        score += 800;
      }
      last_clear_tetris = true;
      score += normal * 200;
    } else if(normal > 0) {
      score += normal * 100;
      last_clear_tetris = false;
    } else {
      last_clear_tetris = false;
    }
    int attack = max(0, normal - 1);  // 지운 줄 - 1 만큼 공격

    current_tet = copy_2d(next_tet);
    next_tet = new_tet();
    tet_pos = new PVector(4, 0);

    // 쌓여 있던 방해 줄 반영 (블록이 놓인 직후, 다음 블록 계산 전)
    if(pendingGarbage > 0) {
      int n = pendingGarbage;
      pendingGarbage = 0;
      add_garbage(n, matchRng);
    }
    if(!dead && check_endgame()) dead = true;
    if(!dead) {
      moves_to_make = find_best_move();
      move_itterator = 0;
    }
    return attack;
  }

  boolean row_has_garbage(int r) {
    for(int c = 0; c < COLS; c++) {
      if(game_map.matrix[r][c] == GARBAGE) return true;
    }
    return false;
  }

  // 아래에서 방해 줄 n개를 밀어 올림. 각 줄은 무작위 한 칸이 비어 있음. 맨 윗줄이 밀려나면 탈락
  void add_garbage(int n, java.util.Random matchRng) {
    for(int k = 0; k < n; k++) {
      for(int c = 0; c < COLS; c++) {
        if(game_map.matrix[0][c] != 0) {  // 블록이 판 위로 밀려남
          dead = true;
          return;
        }
      }
      for(int r = 0; r < ROWS - 1; r++) {
        game_map.matrix[r] = game_map.matrix[r+1];
      }
      int[] row = new int[COLS];
      for(int c = 0; c < COLS; c++) row[c] = GARBAGE;
      row[matchRng.nextInt(COLS)] = 0;
      game_map.matrix[ROWS-1] = row;
      linesReceived++;
    }
    game_map_copy = game_map.copy();
  }

  int stack_height() {
    return game_map.get_max_height();
  }

  // ───── 아래는 TetrisAI/Tetris.pde와 동일한 로직 ─────

  void move(int dir) {
    PVector new_pos = tet_pos.copy();
    int[][] test_tet = copy_2d(current_tet);
    switch(dir) {
      case 0:
        test_tet = rotate_tet(current_tet);
        break;
      case 1:
        game_step = 60;
        break;
      case 2:
        new_pos.x--;
        break;
      case 3:
        new_pos.x++;
        break;
    }
    if(!game_map.check_collision(new_pos.x, new_pos.y, test_tet)) {
      tet_pos = new_pos.copy();
      current_tet = copy_2d(test_tet);
    }
  }

  boolean check_endgame() {
    int[] top_line = game_map.get_row(0);
    for(int i = 0; i < top_line.length; i++) {
      if(top_line[i] != 0) return true;
    }
    return false;
  }

  int[][] rotate_tet(int[][] to_rotate) {
    int n = to_rotate.length;
    int m = to_rotate[0].length;
    int[][] output = new int[m][n];
    for(int i = 0; i < n; i++) {
      for(int j = 0; j < m; j++) {
        output[j][n-1-i] = to_rotate[i][j];
      }
    }
    return output;
  }

  int[][] new_tet() {
    return copy_2d(tetrominos[pieceRng.nextInt(tetrominos.length)]);
  }

  int[][] copy_2d(int[][] array) {
    int[][] copy = new int[array.length][array[0].length];
    for(int i = 0; i < array.length; i++) {
      for(int j = 0; j < array[0].length; j++) {
        copy[i][j] = array[i][j];
      }
    }
    return copy;
  }

  float score_move(float terrain_height, float lines_cleared, float max_height, float min_height, float holes) {
    float[] input = {terrain_height, lines_cleared, max_height, min_height, holes};
    return brain.output(input)[0];
  }

  ArrayList<Integer> find_best_move() {
    ArrayList<ArrayList<Integer>> moves = new ArrayList<ArrayList<Integer>>();
    ArrayList<Float> move_scores = new ArrayList<Float>();
    for(int x_add = 5; x_add >= -5; x_add--) {
      for(int rotate = 0; rotate <= 3; rotate++) {
        int[][] test_tet = copy_2d(current_tet);
        ArrayList<Integer> move_list = new ArrayList<Integer>();
        for(int r = 0; r < rotate; r++) {
          test_tet = rotate_tet(test_tet);
          move_list.add(0);
        }
        for(int x = 0; x < abs(x_add); x++) {
          if(x_add < 0) move_list.add(2);
          else move_list.add(3);
        }
        PVector testing_pos = tet_pos.copy();
        testing_pos.x += x_add;

        if(!game_map.check_collision(testing_pos.x, testing_pos.y, test_tet)) {
          while(!game_map.check_collision(testing_pos.x, testing_pos.y+1, test_tet)) {
            testing_pos.y++;
            move_list.add(1);
          }
          Matrix testing_map = game_map.copy();
          testing_map.insert_all_at(testing_pos.x, testing_pos.y, test_tet);
          float max_height = float(testing_map.get_max_height());
          float min_height = float(testing_map.get_min_height());
          float lines_cleared = float(testing_map.clear_lines());
          float terrain_height = float(testing_map.calculate_terrain());
          float holes = float(testing_map.count_holes());

          moves.add(move_list);
          float m_score = score_move(terrain_height, lines_cleared, max_height, min_height, holes);

          float max_next_score = 0;
          if(CHECK_NEXT) {
            for(int x = 5; x >= -5; x--) {
              for(int rot = 0; rot <= 3; rot++) {
                int[][] next_test_tet = copy_2d(next_tet);
                PVector next_testing_pos = tet_pos.copy();
                next_testing_pos.x += x;
                for(int r = 0; r < rot; r++) {
                  next_test_tet = rotate_tet(next_test_tet);
                }
                if(!testing_map.check_collision(next_testing_pos.x, next_testing_pos.y, next_test_tet)) {
                  while(!testing_map.check_collision(next_testing_pos.x, next_testing_pos.y+1, next_test_tet)) {
                    next_testing_pos.y++;
                  }
                  Matrix next_testing_map = testing_map.copy();
                  next_testing_map.insert_all_at(next_testing_pos.x, next_testing_pos.y, next_test_tet);
                  float next_max_height = float(next_testing_map.get_max_height());
                  float next_min_height = float(next_testing_map.get_min_height());
                  float next_lines_cleared = float(next_testing_map.clear_lines());
                  float next_terrain_height = float(next_testing_map.calculate_terrain());
                  float next_holes = float(next_testing_map.count_holes());
                  float s = score_move(next_terrain_height, next_lines_cleared, next_max_height, next_min_height, next_holes);
                  if(s > max_next_score) max_next_score = s;
                }
              }
            }
          }
          move_scores.add(m_score + max_next_score);
        }
      }
    }
    if(moves.size() > 0) {
      // Tetris.pde는 동점 비교를 Float 객체 ==(참조 비교)로 하므로 동점 처리 분기가 실제로는 실행되지 않는다.
      // 같은 결정을 내리도록 "더 큰 값일 때만 교체(동점이면 먼저 나온 후보 유지)"로 동일하게 구현
      int max_index = 0;
      for(int i = 1; i < move_scores.size(); i++) {
        if(move_scores.get(i) > move_scores.get(max_index)) max_index = i;
      }
      return moves.get(max_index);
    }
    ArrayList<Integer> m = new ArrayList<Integer>();
    m.add(1);
    return m;
  }

  // 보드 그리기 (x, y = 보드 좌상단, cell = 칸 크기)
  void draw_board(float x, float y, float cell) {
    noStroke();
    fill(25);
    rect(x, y, COLS * cell, ROWS * cell);
    for(int i = 0; i < ROWS; i++) {
      for(int j = 0; j < COLS; j++) {
        int val = game_map_copy.matrix[i][j];
        if(val != 0) {
          fill(dead ? lerpColor(colors[val], color(0), 0.6) : colors[val]);
          rect(x + j * cell, y + i * cell, cell - 0.5, cell - 0.5);
        }
      }
    }
    // 대기 중인 방해 줄 표시 (보드 왼쪽 빨간 막대)
    if(pendingGarbage > 0 && !dead) {
      fill(255, 60, 60);
      float h = min(pendingGarbage, ROWS) * cell;
      rect(x - 3, y + ROWS * cell - h, 3, h);
    }
    noFill();
    stroke(dead ? 90 : 160);
    rect(x, y, COLS * cell, ROWS * cell);
  }
}
