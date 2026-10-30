class Tetris {
  
  //POPULATION VARIABLES
  boolean dead = false;
  boolean is_best = false;
  
  NeuralNet brain;
  
  ArrayList<Integer> moves_to_make;
  int move_itterator = 0;
  
  int species_id = 0;  // 가문 ID = 시조 ID (1~200, 세대가 지나도 불변)
  int uniqueID = 0;  // 고유 개체 식별자

  //LINEAGE VARIABLES (CSV 기록용, 게임 동작에는 영향 없음)
  int birthGeneration = 1;          // 이 개체가 태어나 플레이한 세대
  String birthType = "FOUNDER";     // FOUNDER / CROSSOVER / ELITE_CLONE
  int parentAID = 0;                // CROSSOVER: 첫 번째 부모 (0 = 없음)
  int parentBID = 0;                // CROSSOVER: 두 번째 부모 (0 = 없음)
  int cloneSourceID = 0;            // ELITE_CLONE: 복제 원본 (0 = 없음)

  //GAME STATE VARIABLES    
    int[][] current_tet;
    int[][] next_tet;
    int rotation_idx;
    Matrix game_map;
    Matrix game_map_copy;
    int game_step;
    PVector tet_pos = new PVector(4,0);
    int lines = 0;
    int score = 0;
    int tetris = 0;
    int back_to_back_count = 0;  // 백투백 횟수
    int total_back_to_back = 0;  // 총 백투백 횟수
    int single_clears = 0;       // 1줄 클리어
    int double_clears = 0;       // 2줄 클리어  
    int triple_clears = 0;       // 3줄 클리어
    int pieces_placed = 0;       // 놓은 블록 수
    
    boolean last_clear_tetris = false;
    
    Tetris() {
        this(0);
    }
    
    Tetris(int spec) {
        this(spec, null);
    }

    // startBrain != null: 시조처럼 정해진 유전자로 시작 (첫 수 계산 전에 적용되므로 무작위 신경망을 거치지 않음)
    Tetris(int spec, NeuralNet startBrain) {
        init_game();
        uniqueID = nextUniqueID++;  // 고유 ID 할당
        if(!HUMAN_PLAY) {
            brain = (startBrain != null) ? startBrain : new NeuralNet(5,HIDDEN_NODES,1,HIDDEN_LAYERS);
            moves_to_make = find_best_move();
            species_id = spec;
        }
    }
    
    void update() { 
        if(!dead) {
            if(!HUMAN_PLAY) {
              if(move_itterator+1 < moves_to_make.size()) {
                 move(moves_to_make.get(move_itterator++));
              } else {
                move(1);
              }
            }
            game_step++;
            game_map_copy = game_map.copy();
            game_map_copy.insert_all_at(tet_pos.x, tet_pos.y, current_tet); 
            if(game_step >= 60) {
               game_step = 0; 
               tet_pos.y++;
               
               if(game_map.check_collision(tet_pos.x, tet_pos.y, current_tet)) {
                  game_map = game_map_copy.copy(); 
                  
                  int cleared = game_map.clear_lines();
                  pieces_placed++; // 블록이 놓일 때마다 카운트
                  
                  lines += cleared;
                  
                  if(cleared >= 4) {
                      tetris++;
                      if(last_clear_tetris) {
                          // 백투백 테트리스
                          back_to_back_count++;
                          total_back_to_back++;
                          score += 1200; // 백투백 보너스
                      } else {
                          back_to_back_count = 1; // 첫 테트리스
                          score += 800;
                      }
                      last_clear_tetris = true;
                      score += (cleared*200);
                  } else if(cleared > 0) {
                      // 라인 클리어별 통계 업데이트
                      if(cleared == 1) single_clears++;
                      else if(cleared == 2) double_clears++;
                      else if(cleared == 3) triple_clears++;
                      
                      score += (cleared*100);
                      last_clear_tetris = false;
                      back_to_back_count = 0; // 백투백 리셋
                  } else {
                      last_clear_tetris = false;
                      back_to_back_count = 0;
                  }
                  current_tet = copy_2d(next_tet);
                  next_tet = new_tet();
                  
                  tet_pos = new PVector(4,0);
                  
                  if(check_endgame()) {
                      dead = true;
                  }
                  if(!HUMAN_PLAY) {
                    moves_to_make = find_best_move();
                    move_itterator = 0;
                  }
               }
            }
        } 
    }
    
    void show_game() {
         show(game_map_copy, tet_pos, current_tet); 
    }
    
    void show_next() {
         stroke(0);
         fill(255);
         textSize(15);  // 30에서 15로 줄임
         textAlign(LEFT);
         text("Next: ", 100, 340);
         for(int y = 0; y < next_tet.length; y++) {
            for(int x = 0; x < next_tet[0].length; x++) {
               int val = next_tet[y][x];
               if(val != 0) {
                   fill(colors[val]);
                   rect(115+x*CELL_SIZE, 145+y*CELL_SIZE, CELL_SIZE, CELL_SIZE);  // 230에서 115, 290에서 145로 조정
               }
            }
         }
    }
    
    void show(Matrix game, PVector pos, int[][] tet) {
       //DRAW GUIDES
       if(GUIDE) {
           fill(255);
           ellipseMode(CENTER);
           for(int i = int(pos.y)+tet.length-1; i < ROWS; i++) {
              for(int j = 0; j < tet[0].length; j++) {
                ellipse(240+((int(pos.x)+j)*CELL_SIZE)+(CELL_SIZE/2), 20+i*CELL_SIZE+(CELL_SIZE/2),3,3);  // 480에서 240, 40에서 20, 점 크기도 5에서 3으로 조정
              }
           }
       }
       stroke(0);
       //DRAW TETROMINOS
       for(int i = 0; i < ROWS; i++) {
           for(int j = 0; j < COLS; j++) {
              int val = game.get_at(j, i);
              color c = colors[val];
              if(val != 0) {
                fill(c);
                rect(240+j*CELL_SIZE, 20+i*CELL_SIZE, CELL_SIZE, CELL_SIZE);  // 480에서 240, 40에서 20으로 조정
              }
           }
        }
    }
    
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
    
    void init_game() {
        current_tet = new_tet();
        next_tet = new_tet();
        rotation_idx = 0;
        game_map = new Matrix(ROWS,COLS);
        game_map_copy = game_map.copy();
        game_step = 0; 
        tet_pos = new PVector(4,0);
        show_game();
    }
    
    boolean check_endgame() {
       int[] top_line = game_map.get_row(0);
       for(int i = 0; i < top_line.length; i++) {
          if(top_line[i] != 0)
            return true;
       }
       return false;
    }
    
    int[][] rotate_tet(int[][] to_rotate) {
        int n =to_rotate.length;
        int m = to_rotate[0].length;
        int [][] output = new int [m][n];
        
        for (int i=0; i<n; i++) {
          for (int j=0;j<m; j++) {
              output [j][n-1-i] = to_rotate[i][j];
          }
        }
        rotation_idx++;
        if(rotation_idx >=4) {
           rotation_idx = 0; 
        }
        return output;
    }
    
    int[][] new_tet() {
        return copy_2d(tetrominos[(int)random(tetrominos.length)]);
    }
    
    int[] copy_1d(int[] array) {
       int[] copy = new int[array.length];
       for(int i = 0; i < array.length; i++) {
          copy[i] = array[i]; 
       }
       return copy;
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
    
    // 세대교체용 우수 개체 복제: 새 개체이므로 새 uniqueID를 소비한다.
    // 단순 기록 보존에는 사용하지 말 것 (TetrisRecord 사용)
    Tetris clone() {  //clone the Tetris
       Tetris clone = new Tetris(species_id);
       clone.brain = brain.clone();
       clone.birthGeneration = birthGeneration + 1;
       clone.birthType = "ELITE_CLONE";
       clone.cloneSourceID = uniqueID;
       return clone;
    }
    Tetris crossover(Tetris parent) {  //crossover the Tetris with another Tetris
       // 부모 중 더 높은 점수를 가진 쪽의 species_id 상속 (동점이면 parent 쪽)
       int inherited_species = (score > parent.score) ? species_id : parent.species_id;
       Tetris child = new Tetris(inherited_species);
       child.brain = brain.crossover(parent.brain);
       child.birthGeneration = birthGeneration + 1;
       child.birthType = "CROSSOVER";
       child.parentAID = uniqueID;         // 첫 번째 select_parent() 결과
       child.parentBID = parent.uniqueID;  // 두 번째 select_parent() 결과
       return child;
    }
    void mutate() {  //mutate the Tetris brain
         brain.mutate(mutation_rate);
    }
    
    float score_move(float terrain_height, float lines_cleared, float max_height, float min_height, float holes) {
       float[] input = {terrain_height, lines_cleared, max_height, min_height, holes};
       return brain.output(input)[0];
    }
    
    float fitness() {
       return float(score); 
    }
    
    ArrayList<Integer>find_best_move() {
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
                   if(x_add < 0)
                     move_list.add(2);
                   else
                     move_list.add(3);
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
                   
                   //CHECK NEXT TETROMINO
                   float max_next_score = 0;
                   if(CHECK_NEXT) {
                       ArrayList<Float> next_move_scores = new ArrayList<Float>();
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
                                    
                                   float next_m_score = score_move(next_terrain_height, next_lines_cleared, next_max_height, next_min_height, next_holes);
                                   next_move_scores.add(next_m_score);
                               }
                           }
                       }
                       for(float s : next_move_scores) {
                          if(s > max_next_score) {
                             max_next_score = s; 
                          }
                       }
                   }
                   move_scores.add(m_score+max_next_score);
               }
           }
        } 
        if(moves.size() > 0) {
          int max_index = 0;
          int min_index = 0;
          for(int i = 1; i < move_scores.size(); i++) {
              if(move_scores.get(i) == move_scores.get(max_index)) {
                 if(moves.get(i).size() < moves.get(max_index).size()) {
                     max_index = i;
                 }
              } else if(move_scores.get(i) > move_scores.get(max_index)) {
                 max_index = i; 
              } else if(move_scores.get(i) < move_scores.get(min_index)) {
                 min_index = i; 
              }
          }
          
          return moves.get(max_index);
        }
        ArrayList<Integer> m = new ArrayList<Integer>();
        m.add(1);
        return m;
    }
}
