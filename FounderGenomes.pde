import java.nio.file.Files;
import java.security.MessageDigest;

// 모든 팀원·모든 실행이 공유하는 200개 시조의 고정 유전자 (data/founder_genomes_v1.csv)
// 일반 실행은 이 파일을 읽기만 한다. 파일이 없거나 손상되면 새로 만들지 않고 시작을 중단한다.
final String FOUNDER_GENOME_HEADER = "founder_set_id,family_id,founder_name,gene_index,layer_index,row_index,col_index,weight";

class FounderGenomes {
  String setId;
  String sha256;        // 파일 바이트 전체의 SHA-256 (소문자 16진수)
  File file;
  int familyCount;
  int iNodes, hNodes, oNodes, hLayers;
  float[][][][] weights;  // [family_id-1][layer][row][col]

  FounderGenomes(String setId, int familyCount, int iNodes, int hNodes, int oNodes, int hLayers) {
    this.setId = setId;
    this.familyCount = familyCount;
    this.iNodes = iNodes; this.hNodes = hNodes; this.oNodes = oNodes; this.hLayers = hLayers;
    NeuralNet shape = emptyBrain();
    weights = new float[familyCount][shape.weights.length][][];
    for(int f = 0; f < familyCount; f++) {
      for(int l = 0; l < shape.weights.length; l++) {
        weights[f][l] = new float[shape.weights[l].rows][shape.weights[l].cols];
      }
    }
  }

  NeuralNet emptyBrain() {
    return new NeuralNet(iNodes, hNodes, oNodes, hLayers, false);
  }

  int genesPerFamily() {
    int n = 0;
    for(float[][] m : weights[0]) n += m.length * m[0].length;
    return n;
  }

  // 시조 #familyId의 고정 유전자로 채운 새 신경망 (개체마다 독립된 복사본)
  NeuralNet buildBrain(int familyId) {
    NeuralNet b = emptyBrain();
    float[][][] w = weights[familyId-1];
    for(int l = 0; l < w.length; l++) {
      for(int r = 0; r < w[l].length; r++) {
        for(int c = 0; c < w[l][r].length; c++) {
          b.weights[l].NetMatrix[r][c] = w[l][r][c];
        }
      }
    }
    return b;
  }

  // 신경망이 시조 #familyId의 고정 유전자와 비트 단위로 같은지
  boolean matches(int familyId, NeuralNet b) {
    float[][][] w = weights[familyId-1];
    if(b.weights.length != w.length) return false;
    for(int l = 0; l < w.length; l++) {
      if(b.weights[l].rows != w[l].length || b.weights[l].cols != w[l][0].length) return false;
      for(int r = 0; r < w[l].length; r++) {
        for(int c = 0; c < w[l][r].length; c++) {
          if(Float.floatToIntBits(b.weights[l].NetMatrix[r][c]) != Float.floatToIntBits(w[l][r][c])) return false;
        }
      }
    }
    return true;
  }
}

// 고정 시조 유전자 파일 읽기. 문제가 있으면 원인을 담은 RuntimeException (새 유전자를 만들지 않음)
FounderGenomes loadFounderGenomes(File f, String setId, int familyCount, int iNodes, int hNodes, int oNodes, int hLayers) {
  String where = f.getAbsolutePath();
  if(!f.exists()) {
    throw new RuntimeException("시조 유전자 파일이 없습니다: " + where
      + "\n배포받은 data/" + f.getName() + " 파일을 data 폴더에 넣으세요. (새 시조 유전자는 자동으로 만들지 않습니다)");
  }
  byte[] bytes;
  try {
    bytes = Files.readAllBytes(f.toPath());
  } catch(IOException e) {
    throw new RuntimeException("시조 유전자 파일을 읽을 수 없습니다: " + where + " - " + e.getMessage());
  }

  FounderGenomes g = new FounderGenomes(setId, familyCount, iNodes, hNodes, oNodes, hLayers);
  g.file = f;
  g.sha256 = sha256Hex(bytes);

  String text = new String(bytes, StandardCharsets.UTF_8);
  if(text.startsWith("﻿")) throw new RuntimeException("시조 유전자 파일이 손상되었습니다 (UTF-8 BOM 추가됨 - Excel 등에서 다시 저장한 것으로 보임): " + where);
  if(text.indexOf('\r') >= 0) throw new RuntimeException("시조 유전자 파일이 손상되었습니다 (줄바꿈이 CRLF로 변환됨 - Excel 저장 또는 git 자동 변환): " + where);
  String[] lines = text.split("\n", -1);
  if(lines.length < 1 || !lines[0].equals(FOUNDER_GENOME_HEADER)) {
    throw new RuntimeException("시조 유전자 파일의 헤더가 올바르지 않습니다: " + where + "\n기대값: " + FOUNDER_GENOME_HEADER);
  }

  // 신경망 구조로부터 (layer,row,col) -> gene_index 계산
  NeuralNet shape = g.emptyBrain();
  int[] layerOffset = new int[shape.weights.length];
  for(int l = 1; l < layerOffset.length; l++) layerOffset[l] = layerOffset[l-1] + shape.weights[l-1].rows * shape.weights[l-1].cols;
  int perFamily = g.genesPerFamily();
  boolean[][] seen = new boolean[familyCount][perFamily];
  int rows = 0;

  for(int i = 1; i < lines.length; i++) {
    String line = lines[i];
    if(line.length() == 0) {
      if(i == lines.length - 1) break;  // 마지막 개행
      throw new RuntimeException("시조 유전자 파일 " + (i+1) + "번째 줄이 비어 있습니다.");
    }
    String err = "시조 유전자 파일 " + (i+1) + "번째 줄 오류: ";
    String[] v = line.split(",", -1);
    if(v.length != 8) throw new RuntimeException(err + "컬럼 수 " + v.length + " (8이어야 함)");
    try {
      if(!v[0].equals(setId)) throw new RuntimeException(err + "founder_set_id " + v[0] + " != " + setId);
      int fid = Integer.parseInt(v[1]);
      if(fid < 1 || fid > familyCount) throw new RuntimeException(err + "family_id 범위 밖 " + fid);
      if(!v[2].equals(founderName(fid))) throw new RuntimeException(err + "시조 #" + fid + " 이름 " + v[2] + " != " + founderName(fid));
      int gi = Integer.parseInt(v[3]), l = Integer.parseInt(v[4]), r = Integer.parseInt(v[5]), c = Integer.parseInt(v[6]);
      if(l < 0 || l >= shape.weights.length || r < 0 || r >= shape.weights[l].rows || c < 0 || c >= shape.weights[l].cols) {
        throw new RuntimeException(err + "신경망 구조(" + iNodes + "-" + hNodes + "-" + oNodes + ", 은닉층 " + hLayers + ")에 없는 위치 " + l + "/" + r + "/" + c);
      }
      if(gi != layerOffset[l] + r * shape.weights[l].cols + c) throw new RuntimeException(err + "gene_index " + gi + "가 위치와 맞지 않음");
      if(seen[fid-1][gi]) throw new RuntimeException(err + "시조 #" + fid + " 유전자 " + gi + " 중복");
      float w = Float.parseFloat(v[7]);
      if(Float.isNaN(w) || w < -1 || w > 1) throw new RuntimeException(err + "가중치 범위 밖 " + v[7]);
      if(!plainFloat(w).equals(v[7])) throw new RuntimeException(err + "가중치 표기가 원본 형식과 다름 " + v[7] + " (수정된 파일로 보임)");
      seen[fid-1][gi] = true;
      g.weights[fid-1][l][r][c] = w;
      rows++;
    } catch(NumberFormatException e) {
      throw new RuntimeException(err + "숫자 형식 오류 (" + e.getMessage() + ")");
    }
  }
  if(rows != familyCount * perFamily) {
    throw new RuntimeException("시조 유전자 파일 행 수 " + rows + " != " + familyCount + " x " + perFamily + " = " + (familyCount * perFamily) + " (일부 시조 유전자 누락)");
  }
  return g;
}

// 새 시조 집합을 의도적으로 만들 때만 사용 (GENERATE_FOUNDER_GENOMES = true). 기존 파일은 절대 덮어쓰지 않음
FounderGenomes generateFounderGenomes(File f, String setId, int familyCount, int iNodes, int hNodes, int oNodes, int hLayers) {
  if(f.exists()) {
    throw new RuntimeException("시조 유전자 파일이 이미 있습니다: " + f.getAbsolutePath()
      + "\n기존 시조 집합은 덮어쓰지 않습니다. 새 집합이 필요하면 FOUNDER_SET_ID와 FOUNDER_GENOME_FILE을 새 버전(예: FOUNDERS_V2 / founder_genomes_v2.csv)으로 바꾸세요.");
  }
  StringBuilder sb = new StringBuilder(FOUNDER_GENOME_HEADER).append('\n');
  for(int fid = 1; fid <= familyCount; fid++) {
    NeuralNet b = new NeuralNet(iNodes, hNodes, oNodes, hLayers);  // 기존 무작위 초기화 방식 그대로
    int gi = 0;
    for(int l = 0; l < b.weights.length; l++) {
      for(int r = 0; r < b.weights[l].rows; r++) {
        for(int c = 0; c < b.weights[l].cols; c++) {
          sb.append(setId).append(',').append(fid).append(',').append(founderName(fid)).append(',')
            .append(gi++).append(',').append(l).append(',').append(r).append(',').append(c).append(',')
            .append(plainFloat(b.weights[l].NetMatrix[r][c])).append('\n');
        }
      }
    }
  }
  try {
    File dir = f.getParentFile();
    if(dir != null && !dir.exists() && !dir.mkdirs()) throw new IOException("폴더를 만들 수 없습니다: " + dir);
    Writer w = new OutputStreamWriter(new FileOutputStream(f, false), StandardCharsets.UTF_8);
    try {
      w.write(sb.toString());
    } finally {
      w.close();
    }
  } catch(IOException e) {
    throw new RuntimeException("시조 유전자 파일 저장 실패: " + f.getAbsolutePath() + " - " + e.getMessage());
  }
  // 저장한 파일을 다시 읽어 그대로 복원되는지 확인
  return loadFounderGenomes(f, setId, familyCount, iNodes, hNodes, oNodes, hLayers);
}

// float를 지수 표기 없이, 다시 읽으면 원래 float 값과 정확히 같아지는 10진수로 표기
String plainFloat(float v) {
  return new BigDecimal(Float.toString(v)).toPlainString();
}

String sha256Hex(byte[] bytes) {
  try {
    byte[] d = MessageDigest.getInstance("SHA-256").digest(bytes);
    StringBuilder sb = new StringBuilder();
    for(byte b : d) sb.append(String.format("%02x", b & 0xff));
    return sb.toString();
  } catch(Exception e) {
    throw new RuntimeException("SHA-256 계산 실패: " + e);
  }
}
