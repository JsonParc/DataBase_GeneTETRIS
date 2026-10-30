// 기록 보존용 불변 스냅샷
// Tetris.clone()과 달리 새 Tetris 객체를 만들지 않으므로 uniqueID를 소비하지 않으며,
// 원본 개체의 ID·가문·점수·통계·가중치를 스냅샷 시점 그대로 보존한다.
class TetrisRecord {
  final int individualId;
  final int familyId;
  final int generation;
  final int score;
  final int lines;
  final int tetris;
  final int backToBackCount;
  final int totalBackToBack;
  final int singleClears;
  final int doubleClears;
  final int tripleClears;
  final int piecesPlaced;
  final boolean isFinal;  // 개체 사망 후(게임 종료 후) 찍힌 스냅샷인지

  final int iNodes, hNodes, oNodes, hLayers;
  final float[][][] weights;  // [layer][row][col]

  TetrisRecord(Tetris t) {
    individualId = t.uniqueID;
    familyId = t.species_id;
    generation = t.birthGeneration;
    score = t.score;
    lines = t.lines;
    tetris = t.tetris;
    backToBackCount = t.back_to_back_count;
    totalBackToBack = t.total_back_to_back;
    singleClears = t.single_clears;
    doubleClears = t.double_clears;
    tripleClears = t.triple_clears;
    piecesPlaced = t.pieces_placed;
    isFinal = t.dead;

    iNodes = t.brain.iNodes;
    hNodes = t.brain.hNodes;
    oNodes = t.brain.oNodes;
    hLayers = t.brain.hLayers;
    weights = new float[t.brain.weights.length][][];
    for(int w = 0; w < weights.length; w++) {
      NetMatrix m = t.brain.weights[w];
      weights[w] = new float[m.rows][m.cols];
      for(int i = 0; i < m.rows; i++) {
        for(int j = 0; j < m.cols; j++) {
          weights[w][i][j] = m.NetMatrix[i][j];
        }
      }
    }
  }
}
