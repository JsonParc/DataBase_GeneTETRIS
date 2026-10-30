class Population {
   
   Tetris[] tetris_pop;
   Tetris best_tetris;
   
   int gen = 1;
   int same_best = 0;
   
   float best_score = 0;
   float fitness_sum = 0;

   // 전체 개체 화면 상태
   int view_page = 0;
   boolean view_all = false;  // false: 살아있는 개체만, true: 사망 개체 포함 전체

   Population(FounderGenomes founders) {  // 1세대: 고정된 시조 유전자로 시작
      tetris_pop = new Tetris[founders.familyCount];
      for(int i = 0; i < tetris_pop.length; i++) {
         tetris_pop[i] = new Tetris(i+1, founders.buildBrain(i+1));
      }
      best_tetris = tetris_pop[0];
      best_tetris.is_best = true;
   }
   
   boolean is_done() {  //check if all the tetris_pop in the population are dead
      for(int i = 0; i < tetris_pop.length; i++) {
         if(!tetris_pop[i].dead)
           return false;
      }
      return true;
   }
   
   void update() {  //update all the tetris_pop in the generation
      for(int i = 0; i < tetris_pop.length; i++) {
        if(!tetris_pop[i].dead) {
           tetris_pop[i].update();
        }
      }

      // 화면 대표 개체 = 현재 살아있는 개체 중 최고 점수 (화면 표시용, 학습에는 영향 없음)
      // 동점이면 지금 보던 개체를 유지해서 화면이 깜빡이지 않게 함
      Tetris top = find_best_tetris_alive();
      if(top != null && top != best_tetris && (best_tetris.dead || top.score > best_tetris.score)) {
         best_tetris.is_best = false;
         best_tetris = top;
         best_tetris.is_best = true;
      }

      // 새로운 최고 기록 체크 (200개 점수 비교뿐이라 매 프레임 수행해도 부담이 적고,
      // 화면의 세대 최고 점수와 역대 최고 점수가 어긋나 보이지 않음)
      checkAndSaveNewRecord();
   }
   
   void show() {  //show either the best Tetris or all the tetris_pop
      if(SHOW_ALL) {
        show_all_games();
      } else {
        best_tetris.show_game();
        best_tetris.show_next();
        // 뉴럴 네트워크를 오른쪽 공간에 표시
        best_tetris.brain.show(500, 300, 250, 200, new float[5], new float[1]);
      }
   }
   
   void show_all_games() {
      // 기본: 살아있는 AI만 수집. A 키를 누르면 사망 개체 포함 전체 표시
      ArrayList<Tetris> shown_tetris = new ArrayList<Tetris>();
      for(int i = 0; i < tetris_pop.length; i++) {
        if(view_all || !tetris_pop[i].dead) {
          shown_tetris.add(tetris_pop[i]);
        }
      }

      // 살아있는 AI가 없으면 모든 AI 표시
      if(shown_tetris.size() == 0) {
        for(int i = 0; i < tetris_pop.length; i++) {
          shown_tetris.add(tetris_pop[i]);
        }
      }

      // 동적 그리드 계산 (표시 대상 수에 따라), 한 화면에 다 들어가지 않으면 페이지로 나눔
      int total_shown = shown_tetris.size();
      int cols = (int)ceil(sqrt(total_shown));  // 정사각형에 가깝게
      if(cols > MULTI_MAX_COLS) cols = MULTI_MAX_COLS;
      int rows = (int)ceil((float)total_shown / cols);
      if(rows > MULTI_MAX_ROWS) rows = MULTI_MAX_ROWS;
      int per_page = cols * rows;
      int pages = (total_shown + per_page - 1) / per_page;
      view_page = constrain(view_page, 0, pages - 1);

      // 게임 크기 계산 (텍스트 공간 확보)
      int margin = 8;  // 게임 간 간격
      int text_height = 42;  // 텍스트 3줄을 위한 상단 공간
      int top = 40;
      int game_width = (width - margin * (cols + 1)) / cols;
      int game_height = (height - top - 40 - margin * (rows + 1) - text_height * rows) / rows;  // 텍스트 공간 제외

      // 게임 크기에 맞게 스케일 조정 (보드는 200x400)
      float scale_factor = min((float)game_width / 200, (float)game_height / 400);
      if(scale_factor > 0.35) scale_factor = 0.35;  // 최대 크기 제한

      int start = view_page * per_page;
      int end = min(start + per_page, total_shown);
      for(int i = start; i < end; i++) {
        int row = (i - start) / cols;
        int col = (i - start) % cols;
        Tetris current_tetris = shown_tetris.get(i);

        int x = margin + col * (game_width + margin);
        int y = top + margin + row * (game_height + margin + text_height);

        // 텍스트를 게임 위쪽에 표시 (겹치지 않도록)
        if(current_tetris.dead) {
          fill(255, 100, 100);  // 죽은 AI는 빨간색
        } else if(current_tetris.is_best) {
          fill(255, 255, 0);    // 최고 성능 AI는 노란색
        } else {
          fill(255);            // 일반 살아있는 AI는 흰색
        }

        textSize(11);
        textAlign(LEFT, BASELINE);
        text("ID: " + current_tetris.uniqueID + (current_tetris.is_best ? "  BEST" : ""), x + 2, y + 11);
        text("Founder: " + founderName(current_tetris.species_id) + " (#" + current_tetris.species_id + ")", x + 2, y + 24);
        text("Score: " + current_tetris.score + (current_tetris.dead ? "  DEAD" : "  ALIVE"), x + 2, y + 37);

        // 게임 화면은 텍스트 아래에 표시 (보드 좌상단이 칸 좌상단에 오도록 이동)
        pushMatrix();
        translate(x, y + text_height);
        scale(scale_factor);
        noFill();
        stroke(80);
        rect(0, 0, COLS*CELL_SIZE, ROWS*CELL_SIZE);
        translate(-240, -20);
        current_tetris.show_game();
        popMatrix();
      }

      // 하단에 통계 및 페이지 정보 표시
      fill(255);
      textSize(14);
      textAlign(LEFT, BASELINE);
      text("Alive: " + countAlive() + "/" + tetris_pop.length, 20, height - 15);
      text("Showing: " + (view_all ? "ALL" : "ALIVE ONLY") + " (" + total_shown + ")", 150, height - 15);
      text("Page " + (view_page + 1) + "/" + pages + "   Grid: " + cols + "x" + rows, 360, height - 15);
      fill(150);
      textSize(12);
      text("LEFT/RIGHT page | A alive/all | SPACE view | S save | E CSV | P snap | ESC exit", 640, height - 15);
   }

   Tetris find_by_id(int id) {
       for(int i = 0; i < tetris_pop.length; i++) {
          if(tetris_pop[i].uniqueID == id) return tetris_pop[i];
       }
       return null;
   }
   
   Tetris find_best_tetris_alive() {  //살아있는 개체 중 최고 점수 (없으면 null)
       float max = -1;
       int max_index = -1;
       for(int i = 0; i < tetris_pop.length; i++) {
          if(!tetris_pop[i].dead && tetris_pop[i].fitness() > max) {
             max = tetris_pop[i].fitness();
             max_index = i;
          }
       }
       return max_index < 0 ? null : tetris_pop[max_index];
   }
   
   Tetris find_best_tetris() {  //set the best Tetris of the generation
       float max = 0;
       int max_index = 0;
       for(int i = 0; i < tetris_pop.length; i++) {
          if(tetris_pop[i].fitness() > max) {
             max = tetris_pop[i].fitness();
             max_index = i;
          }
       }
       return tetris_pop[max_index];
   }
   
   Tetris select_parent() {  //selects a random number in range of the fitnesssum and if a Tetris falls in that range then select it
      float rand = random(fitness_sum);
      float summation = 0;
      for(int i = 0; i < tetris_pop.length; i++) {
         summation += tetris_pop[i].fitness();
         if(summation > rand) {
           return tetris_pop[i];
         }
      }
      return tetris_pop[0];
   }
   
   void natural_selection() {
      Tetris[] newtetris_pop = new Tetris[tetris_pop.length];
      
      best_tetris = find_best_tetris();
      best_tetris.is_best = true;
      calculate_fitness_sum();
      
      newtetris_pop[0] = best_tetris.clone();  //add the best Tetris of the prior generation into the new generation
      for(int i = 1; i < tetris_pop.length; i++) {
         Tetris child = select_parent().crossover(select_parent());
         child.mutate();
         newtetris_pop[i] = child;
      }
      tetris_pop = newtetris_pop.clone();
      gen+=1;
   }
   
   void mutate() {
       for(int i = 1; i < tetris_pop.length; i++) {  //start from 1 as to not override the best Tetris placed in index 0
          tetris_pop[i].mutate(); 
       }
   }
   
   void calculate_fitness_sum() {  //calculate the sum of all the tetris_pop fitnesses
       fitness_sum = 0;
       for(int i = 0; i < tetris_pop.length; i++) {
         fitness_sum += tetris_pop[i].fitness(); 
      }
   }
}
