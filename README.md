# TetrisAI

유전 알고리즘과 신경망을 이용하여 테트리스 플레이 전략을 학습하는 프로젝트입니다. AI는 블록을 배치할 수 있는 위치를 평가하고, 세대를 거치며 더 높은 게임 점수를 얻도록 진화합니다.

## 실행 환경 (Requirements)

이 프로젝트는 Processing(Java Mode) 으로 작성된 데스크톱 프로그램입니다. 테트리스 시뮬레이션과 CSV 생성에는 별도의 Python, MySQL 설치가 필요하지 않습니다. Python + MySQL은 추후 CSV 데이터를 취합·분석하는 DB 팀프로젝트에서 사용합니다.

| 항목 | 내용 |
|---|---|
| 실행 프로그램 | Processing IDE (Java Mode) |
| 최신 버전 | **동작 확인** (기존 문서에 기재된 테스트 버전: Processing 4.4.6) |
| 약 5년 전 사용한 버전 | **동작 확인** (정확한 버전 번호 미기록) |
| 그 밖의 Processing 버전 | **미검증** — 호환성을 보장하지 않음 |
| 운영체제 | 특정 운영체제의 호환성 전체를 검증한 것은 아님. 한글 글꼴은 OS별로 달라질 수 있음 |
| 필요한 프로젝트 파일 | 전체 `TetrisAI` 스케치 폴더 및 그 안의 `.pde`, `data/` 파일 |

> 동작 확인은 사용자가 실제 사용해 본 버전 기준입니다. 다른 Processing 버전에서의 실행 여부는 확인하지 않았습니다.

## 설치 및 실행 방법 (Getting Started)

**1. Processing 설치 및 Java Mode 확인**

Processing IDE를 설치하고 실행합니다. 상단 모드가 **Java**인지 확인하세요. 이 프로그램은 Python 스크립트가 아니라 Processing 스케치이므로, Python이나 VS Code의 일반적인 실행 버튼으로 `.pde` 파일을 실행하지 않습니다.

**2. 프로젝트 폴더 준비**

전달받은 압축파일을 해제한 후, 아래처럼 **`TetrisAI.pde`가 `TetrisAI` 폴더 바로 아래**에 있는지 확인합니다. `.pde` 파일 하나만 꺼내지 말고 프로젝트 폴더 전체를 유지하세요.

```text
TetrisAI/
├── TetrisAI.pde                 ← 실행할 메인 스케치
├── Population.pde
├── Tetris.pde
├── NeuraNet.pde
├── NetMatrix.pde
├── Founders.pde                 ← 시조 이름 관리 (CSV 확장 버전)
├── ...                         ← 기타 .pde 파일
└── data/
    └── founder_genomes_v1.csv  ← 공통 시조 유전자 (수정·삭제 금지)
```

**3. Processing에서 폴더 열기**

1. Processing IDE 메뉴에서 **File → Open... (파일 → 열기)** 를 선택합니다.
2. 압축 해제한 **`TetrisAI` 폴더**로 이동합니다.
3. 그 안의 **`TetrisAI.pde`를 선택하여 엽니다.** 이것이 프로젝트의 **메인 실행 파일**입니다.
4. 같은 폴더의 다른 `.pde` 파일은 스케치의 탭으로 함께 로드됩니다. `Population.pde`나 `Tetris.pde`를 따로 실행할 필요가 없습니다.
5. 좌측 상단의 **▶ Run (실행)** 버튼을 누릅니다.

**4. 팀원 이름 설정 (선택 사항)**

실행 전에 `TetrisAI.pde` 상단의 `RUN_OWNER`에 자신의 식별용 영문 이름을 입력할 수 있습니다.

```java
final String RUN_OWNER = "DONGHYUN";
```

이렇게 지정하면 `run_id`는 예를 들어 `DONGHYUN_20261030_141502_3F9A1C2B`와 같은 형식으로 생성됩니다. **팀원 간 데이터 비교를 위해 공통 시조 유전자 파일과 그 설정값은 변경하지 마세요.**

**5. 실행 상태 확인**

실행하면 게임 창이 열리고 Processing 콘솔에서 다음 메시지를 확인할 수 있습니다.

```text
[Font] 한글 표시 폰트: ...
[Founders] 고정 시조 유전자 로드: FOUNDERS_V1 (200 x 29), SHA-256 6fd10017…
[Founders] 검증 완료: 개체 200 / 시조 이름 200 / 가문 200 ...
[CSV] 실험 폴더 생성: .../exports/<run_id>
```

모든 개체가 한 세대의 플레이를 끝내면 다음과 같은 저장 메시지가 출력됩니다.

```text
[CSV] Gen N saved: 200 individuals, 5800 genes
```

CSV는 `TetrisAI/exports/<run_id>/`에서 확인할 수 있습니다. **각 팀원은 자신의 `<run_id>` 폴더 전체를 수집·전달**하면 됩니다. `in_progress/` 스냅샷은 최종 DB 적재 대상이 아닙니다.

**6. 실행 문제가 발생한다면**

- `TetrisAI.pde`가 아닌 다른 `.pde` 파일을 단독으로 열었는지 확인합니다.
- 프로젝트 폴더 이름이 `TetrisAI`인지, `TetrisAI.pde`와 다른 `.pde` 파일들이 같은 폴더에 있는지 확인합니다.
- `data/founder_genomes_v1.csv`가 존재하는지 확인합니다. 원본 파일을 엑셀 등으로 다시 저장하면 SHA-256 검증에 실패할 수 있습니다.
- Processing의 **Java Mode**로 실행 중인지 확인합니다.
- 오류가 발생하면 Processing 콘솔의 메시지를 확인합니다. 확인되지 않은 다른 버전에서는 호환성 문제가 생길 수 있습니다.

## 점수 계산 (Scoring)

| 플레이 결과 | 점수 |
|---|---:|
| 한 번에 1줄 제거 | 100점 |
| 한 번에 2줄 제거 | 200점 |
| 한 번에 3줄 제거 | 300점 |
| 한 번에 4줄 제거 (테트리스) | 800점 |
| 테트리스 연속 달성 (Back-to-back Tetris) | 1,200점 |

## 이동 위치 계산 (Calculating Moves)

새로운 블록이 등장하면 시스템은 해당 블록을 배치할 수 있는 모든 위치를 계산합니다. 각 위치에 블록을 배치했을 때의 게임 상태를 분석하고, 다음 특징값을 추출합니다.

### 신경망 입력 특징 (Features)

- **인접 열의 높이 차이 합계:** 서로 이웃한 열 사이의 높이 차이
- **구멍(Holes):** 블록으로 채울 수 없는 내부 빈 공간
- **최대 높이:** 쌓인 블록 구조의 최대 높이
- **최소 높이:** 쌓인 블록 구조의 최소 높이
- **제거한 줄 수:** 해당 배치로 제거되는 줄의 수

추출한 다섯 가지 특징값을 신경망에 입력하면 해당 배치의 평가 점수가 출력됩니다. 시스템은 가능한 모든 위치를 같은 방식으로 평가한 다음, 가장 높은 평가 점수를 받은 위치를 선택합니다. 이후 선택한 위치에 블록을 놓을 수 있도록 이동 및 회전 명령을 생성하여 실행합니다.

게임판은 10열이고 회전 상태는 최대 4가지이므로, 원본 프로그램 설명에서는 블록마다 **약 40가지 배치 후보**를 평가하는 것으로 설명합니다. 실제 유효한 배치 후보 수는 블록의 모양과 게임판 상태에 따라 달라질 수 있습니다.

## 학습 과정 (Training)

신경망의 가중치를 최적화하기 위해 **유전 알고리즘(Genetic Algorithm)** 을 사용합니다.

1. 각 세대마다 AI 개체 200개로 구성된 개체군을 생성합니다.
2. 모든 개체가 게임 오버가 될 때까지 테트리스를 플레이합니다.
3. 각 개체의 게임 점수를 바탕으로 우수한 개체를 선택합니다.
4. 선택한 두 부모 개체의 신경망 가중치 일부를 무작위로 조합하는 **교차(Crossover)** 를 수행합니다.
5. 교차로 생성한 신경망에 돌연변이율에 따른 **돌연변이(Mutation)** 를 적용합니다.
6. 새로운 개체군 200개를 구성하고 같은 과정을 반복합니다.

이 과정에서 여러 세대에 걸쳐 높은 점수를 얻는 방향으로 신경망이 진화합니다.

## 다음 블록 예측 (Next Piece Knowledge)

AI가 다음에 등장할 블록을 미리 알고 있다면, 현재 블록의 배치를 결정할 때 다음 블록의 최적 배치까지 고려할 수 있습니다.

현재 블록을 배치할 수 있는 각 후보 위치에 대해, 다음 블록을 배치할 수 있는 모든 위치를 다시 계산합니다. 그리고 다음 블록의 후보 배치들을 신경망으로 평가하여 얻은 최고 점수를 현재 블록의 후보 배치 점수에 더합니다.

즉, 현재 블록을 단독으로 평가하는 대신 **현재 블록과 다음 블록을 함께 고려한 결과**로 배치 위치를 선택합니다.

블록 하나당 약 40개 배치 후보가 있다고 가정하면, 다음 블록까지 고려할 때 평가 대상은 대략 **40² = 1,600가지**로 늘어납니다. 이 수치는 개략적인 계산량이며 실제 후보 수는 달라질 수 있습니다.

---

## 데이터베이스 팀프로젝트용 CSV 출력 규격

이 프로젝트는 DB조별과제 시나리오의 데이터 생성 프로그램으로 확장되었습니다.

테트리스 AI 자체는 Processing(Java 기반) 프로그램이며, 생성된 CSV 파일을 향후 **Python + MySQL**로 개발하는 별도의 데이터베이스 관리 프로그램에서 가져와 분석할 예정입니다. 테트리스 프로그램 자체에는 MySQL 연결이나 DB 관리 화면이 없습니다.

### 공통 시조 유전자 (팀원 간 데이터 통합)

모든 팀원이 **똑같은 200개 시조 유전자**로 시작하고, 그 이후의 진화(블록 순서, 점수, 부모 선택, 교차, 돌연변이, 가문 멸종, 우승 가문)는 각자 독립적으로 진행됩니다. 따라서 "동현 가문"은 어느 팀원의 데이터에서든 같은 초기 유전자를 뜻합니다.

- 시조 유전자 파일: `data/founder_genomes_v1.csv` (시조 200 × 가중치 29 = 5,800행, 배포본에 포함)

```csv
  founder_set_id,family_id,founder_name,gene_index,layer_index,row_index,col_index,weight
  FOUNDERS_V1,1,동현,0,0,0,0,-0.1683898
```

- `founder_set_id` = `FOUNDERS_V1`, 파일 SHA-256 = `6fd10017ed2731d85867685181e3925a4c48bd78c7426d4101c815958a4ff378`
- 실행할 때마다 이 파일을 읽어 1세대 신경망을 만듭니다. 시조 개체는 처음부터 이 유전자로 생성되므로 무작위 신경망으로 첫 수를 두는 일이 없습니다.
- 다음 경우에는 **시뮬레이션을 시작하지 않고** 화면과 콘솔에 원인을 표시합니다. 새 유전자를 임의로 만들지 않습니다.

  - 파일이 없음 / 헤더·행 수·시조 이름·유전자 위치가 맞지 않음 / 값이 수정됨

  - SHA-256이 코드의 `FOUNDER_GENOME_SHA256`과 다름

  - UTF-8 BOM 또는 CRLF 줄바꿈으로 바뀜 (Excel에서 열어 저장하면 이렇게 됩니다 → **이 파일은 Excel로 저장하지 마세요**)

- git으로 배포할 때 줄바꿈이 바뀌지 않도록 `.gitattributes`에서 이 파일을 binary로 지정했습니다. zip으로 전달해도 됩니다.
- **새 시조 집합을 의도적으로 만들 때만**: `TetrisAI.pde`에서 `FOUNDER_SET_ID`/`FOUNDER_GENOME_FILE`을 새 버전(예: `FOUNDERS_V2`, `founder_genomes_v2.csv`)으로 바꾸고 `GENERATE_FOUNDER_GENOMES = true`로 실행합니다. 기존 무작위 초기화 방식으로 파일을 한 번 만들고 SHA-256을 표시한 뒤 멈춥니다(같은 이름의 파일이 있으면 거부). 표시된 값을 `FOUNDER_GENOME_SHA256`에 넣고 플래그를 `false`로 되돌린 뒤 팀 전체에 다시 배포합니다.

### 여러 팀원의 데이터 합치기

- `run_id`는 실행마다 고유합니다: `<RUN_OWNER>_<시작 시각>_<UUID 앞 8자리>`. 여러 명이 같은 초에 실행해도 겹치지 않습니다.
- `individual_id`는 **실행마다 1부터** 다시 시작합니다. 개체는 반드시 `(run_id, individual_id)` 조합으로 식별하세요. 부모 관계(`parentage.csv`)도 같은 `run_id` 안에서만 연결됩니다.
- 서로 다른 실행의 세대를 하나의 계보로 이어 붙이지 마세요. 각 실행은 독립된 진화 실험입니다.
- 가문은 `experiments.founder_set_id`가 같은 실행끼리 `family_id`로 비교할 수 있습니다. 합치기 전에 모든 실행의 `founder_set_id`와 `founder_genome_sha256`이 같은지 확인하세요.
- 권장 키: `experiments(run_id)`, `families(run_id, family_id)` 또는 공통 `founder_families(founder_set_id, family_id)`, `individuals(run_id, individual_id)`, `parentage(run_id, child_individual_id, parent_role)`, `genes(run_id, individual_id, gene_index)`, `game_results(run_id, individual_id)`, `generations(run_id, generation)`

### 화면

- **단일 화면** (기본)

  - 왼쪽 열: 대표 개체 = **현재 살아 있는 개체 중 점수가 가장 높은 개체** (매 프레임 갱신, 동점이면 보던 개체 유지) — `Generation`, `Individual ID`, `Founder ID`, `Founder`, `Family`, `Current Score`, `Lines / Tetris`, 그리고 `Generation Best Score`, `All-Time High Score`, `Mutation Rate`

  - 오른쪽 열 `GENERATION BEST (incl. dead)`: 현재 세대에서 점수가 가장 높은 개체(사망 개체 포함)의 ID·시조·점수·생존 여부

  - 오른쪽 열 `ALL-TIME RECORD`: 모든 세대를 통틀어 최고 점수를 기록한 개체의 점수·세대·ID·시조, 그리고 `FINAL`(게임 종료 후 확정) / `IN PROGRESS`(아직 플레이 중) 상태

  - 오른쪽 열 `CSV EXPORT`: 출력 폴더, 마지막으로 저장된 세대, 저장 성공/오류 메시지

  - 세 개체(대표 / 세대 최고 / 역대 최고)는 서로 다른 개체일 수 있습니다.

- **전체 개체 화면** (SPACE)

  - 칸마다 `ID: <개체 고유 ID>`, `Founder: <시조 이름> (#<시조 ID>)`, `Score: <점수> ALIVE|DEAD` 를 표시합니다. 대표 개체(살아 있는 개체 중 최고 점수)는 노란색 + `BEST`, 사망 개체는 빨간색입니다.

  - 한 페이지에 최대 10×4 = 40개를 표시하고, 넘치면 ←/→ 키로 페이지를 넘깁니다. (200개 = 5페이지)

  - 기본은 기존처럼 살아 있는 개체만 표시하고(모두 사망하면 전체 표시), **A 키**로 사망 개체를 포함한 200개 전체 표시로 전환합니다.

### 단축키

| 키 | 동작 |
|---|---|
| `SPACE` | 단일 화면 ↔ 전체 개체 화면 전환 |
| `←` / `→` | (전체 개체 화면) 페이지 이동 |
| `A` | (전체 개체 화면) 살아 있는 개체만 ↔ 사망 포함 전체 |
| `S` | 역대 최고 기록을 JSON으로 저장 (`data/best_ai*.json`) |
| `E` | CSV 저장 상태를 콘솔에 출력하고, 저장에 실패한 완료 세대가 있으면 즉시 재시도 |
| `P` | 진행 중인 세대의 현재 상태를 **별도 스냅샷**으로 저장 (`exports/<run_id>/in_progress/`, 최종 기록 아님) |
| `ESC` | 완료됐지만 미저장인 세대가 있으면 저장 → 역대 최고 기록 JSON 저장 → 종료 |

### 시조와 가문

최초 세대의 200개 AI 개체를 각각 **시조(Founder)** 로 취급하고, 사전에 정한 고유 이름을 부여합니다. 각 시조는 하나의 가문을 형성합니다.

- 시조 ID 1: 동현 → **동현 가문**
- 시조 ID 2: 지훈 → **지훈 가문**
- 시조 ID 3: 현우 → **현우 가문**
- …
- 시조 ID 200: 규리 → **규리 가문**

후손은 기존 프로그램의 가문 승계 규칙에 따라 대표 부모의 가문 ID(`species_id`)를 계승합니다. 그러나 실제 유전적 관계는 두 부모의 ID를 각각 저장하여 **가문 소속과 부모·자식 관계를 구별**합니다. 시조의 후손이 더 이상 남지 않더라도 가문 기록은 삭제하지 않습니다.

- 시조 이름 목록은 `Founders.pde`의 `FOUNDER_NAMES` 배열입니다. 순서가 가문 ID를 결정하므로 정렬하거나 바꾸지 마세요.
- 가문 ID = 시조 ID = `species_id` (1~200). 1세대 개체 ID도 1~200이므로 시조의 `individual_id`와 `family_id`는 같은 값입니다.
- **교차(CROSSOVER)**: 두 부모 중 점수가 높은 쪽의 가문을 계승하고, 동점이면 `PARENT_B`(두 번째로 선택된 부모)의 가문을 계승합니다. (원본 규칙 그대로)
- **우수 개체 복제(ELITE_CLONE)**: 매 세대 0번 자리에 이전 세대 최고 점수 개체가 복제됩니다. 복제 개체는 새 개체 ID를 받고, 원본의 가문을 계승하며, 원본 ID가 `CLONE_SOURCE`로 기록됩니다. 돌연변이는 적용되지 않습니다(원본 동작).

### CSV 출력 경로

각 독립적인 실험은 `run_id`(예: `DONGHYUN_20261030_141502_3F9A1C2B`)로 구분하고, 다음 경로에 7개 CSV 파일을 저장합니다. 같은 이름의 폴더가 이미 있으면 `_2`, `_3`… 을 붙여 기존 결과를 절대 덮어쓰지 않습니다.

```text
exports/
└── <run_id>/
    ├── experiments.csv
    ├── generations.csv
    ├── families.csv
    ├── individuals.csv
    ├── parentage.csv
    ├── genes.csv
    ├── game_results.csv
    └── in_progress/            (P 키를 눌렀을 때만 생성, DB 적재 대상 아님)
        └── gen_<N>_snapshot_<시각>.csv
```

### CSV 파일별 내용

#### 1. `experiments.csv` — 실험 설정

```csv
run_id,founder_set_id,founder_genome_sha256,program_version,started_at,population_size,mutation_rate,input_nodes,hidden_nodes,output_nodes,hidden_layers
```

실험 ID, 사용한 공통 시조 집합(`FOUNDERS_V1`)과 그 파일의 SHA-256, 프로그램 버전(`2.0.0`), 시작 시각, 개체군 크기, 돌연변이율 및 신경망 구조를 기록합니다. 실험마다 1행을 사용합니다.

#### 2. `generations.csv` — 세대별 통계

```csv
run_id,generation,population_size,highest_score,average_score,completed_at
```

각 세대의 개체 수, 최고 점수, 평균 점수, 세대 종료 시각을 기록합니다. **완료된 세대마다 1행**을 사용하며, 최고·평균 점수는 해당 세대 개체들의 실제 최종 점수에서 계산합니다.

#### 3. `families.csv` — 시조 및 가문

```csv
run_id,family_id,founder_individual_id,founder_name,family_name
```

가문 ID, 시조 개체 ID, 시조 이름 및 가문 이름을 기록합니다. 기본 개체군 200개를 기준으로 실험마다 **200행**을 생성합니다. 가문 ID는 `species_id`에 대응합니다.

#### 4. `individuals.csv` — AI 개체

```csv
run_id,individual_id,generation,family_id,birth_type
```

개체의 고유 ID, 소속 세대, 가문 ID 및 탄생 방식을 저장합니다. `birth_type`은 다음 값 중 하나입니다.

- `FOUNDER`: 최초 세대 시조
- `CROSSOVER`: 부모 개체 두 개의 유전자를 교차해 생성된 자손
- `ELITE_CLONE`: 우수 개체를 복제하여 생성된 자손

개체 ID는 **같은 실험 안에서 중복되지 않도록** 관리하며, 복제된 자손에게도 새로운 개체 ID를 부여합니다.

#### 5. `parentage.csv` — 부모·자식 관계

```csv
run_id,child_individual_id,parent_individual_id,parent_role
```

자식 개체와 부모 개체의 관계를 기록합니다. `parent_role`은 `PARENT_A`, `PARENT_B`, `CLONE_SOURCE` 중 하나입니다.

- 교차로 탄생한 자손: 부모 관계 2행
- 우수 개체 복제로 탄생한 자손: 복제 출처 관계 1행
- 최초 세대 시조: 부모 관계 없음

두 부모가 우연히 같은 개체여도 부모 역할을 구별해 기록합니다. 이 파일을 이용해 특정 개체의 부모, 조상, 후손을 조회할 수 있습니다.

#### 6. `genes.csv` — 신경망 유전자 가중치

```csv
run_id,individual_id,gene_index,layer_index,row_index,col_index,weight
```

개체별 신경망 가중치를 기록합니다. 가중치가 속한 레이어·행·열 위치와 실제 가중치 값을 저장합니다.

원본 `NeuraNet.pde`의 기본 구조는 입력 5개, 은닉 4개, 출력 1개, 은닉층 1개이며, **편향(Bias)을 포함한 가중치는 총 29개**입니다. 입력→은닉층 가중치가 4 × (5 + 1) = 24개, 은닉층→출력 가중치가 1 × (4 + 1) = 5개입니다. 따라서 기본 설정에서는 개체별 **29행**을 출력합니다. 신경망 구조를 변경하면 그에 따라 행 수도 달라져야 합니다.

`gene_index`, `layer_index`, `row_index`, `col_index`는 0부터 시작하는 것으로 통일합니다.

#### 7. `game_results.csv` — 게임 플레이 결과

```csv
run_id,individual_id,generation,score,lines,tetris_count,total_back_to_back,single_clears,double_clears,triple_clears,pieces_placed
```

개체별 최종 점수, 제거한 줄 수, 테트리스 횟수, 연속 테트리스 횟수, 1·2·3줄 제거 횟수, 사용한 블록 수를 기록합니다.

**개체당 게임 1회**이며, 게임이 끝난 개체의 최종 결과를 1행으로 저장합니다. 모든 값은 `Tetris.pde`가 게임 중 실제로 집계한 값입니다. (`tetris_count` = `tetris` 필드, `total_back_to_back` = 연속 테트리스 누적 횟수)

### 파일 간 관계

| 연결 키 | 용도 |
|---|---|
| `run_id` | 같은 실험에 속한 데이터 식별 (개체는 `(run_id, individual_id)`로 식별) |
| `family_id` | 개체가 속한 시조 가문 연결 |
| `individual_id` | 개체 정보·유전자·게임 결과 연결 |
| `child_individual_id`, `parent_individual_id` | 개체 간 부모·자식 관계 연결 |
| `generation` | 세대별 통계 및 개체 그룹 구분 |

실제 DB에서는 실험별 ID 중복을 방지하기 위해 필요에 따라 `run_id`를 포함한 **복합키**를 사용할 수 있습니다.

### 출력 시점 및 형식

- 최초 시조와 실험 설정(`experiments.csv`, `families.csv`)과 나머지 5개 파일의 헤더는 실험 시작 시 기록합니다.
- **세대교체 직전**(200개체가 모두 게임 오버된 프레임), 사망 개체를 포함한 200개체의 최종 점수와 유전자를 확정하여 5개 파일에 이어 씁니다. 파일 쓰기는 세대당 1회이며 매 프레임 쓰지 않습니다.
- **저장에 성공한 뒤에만** 다음 세대로 넘어갑니다. 저장 중 오류가 나면

  - 이번 세대에 이어 쓴 내용을 모든 파일에서 원래 길이로 되돌리고(부분 기록 방지),

  - 화면 `CSV EXPORT` 영역과 콘솔에 오류 원인을 표시하고,

  - 세대교체를 멈춘 채 2초마다(또는 `E` 키로 즉시) 재시도합니다.

- 완료되지 않은 세대의 중간 결과는 7개 파일에 기록하지 않습니다. `P` 키 스냅샷은 `in_progress/` 폴더에 `status`(ALIVE/DEAD)와 `is_final` 컬럼을 포함해 따로 저장됩니다.
- 이미 저장된 세대 번호는 다시 기록하지 않습니다.
- 프로그램을 종료해도 이미 저장된 세대는 그대로 남습니다. 종료 시점에 진행 중이던 세대는 기록되지 않습니다.
- 새로운 실행은 별도 `run_id` 디렉터리에 저장해 이전 결과를 덮어쓰지 않습니다.
- 형식

  - **UTF-8 (BOM 없음)**, **쉼표 구분**, **첫 줄 헤더**, 줄바꿈 **LF(`\n`)**

  - 쉼표·따옴표·개행이 들어간 문자열은 RFC 4180 방식으로 따옴표 처리 (현재 데이터에는 해당 값이 없음)

  - 정수는 정수 그대로, `average_score`는 소수점 4자리, `weight`와 `mutation_rate`는 지수 표기 없는 10진수(원래 float 값으로 정확히 복원 가능)

  - 시각은 `yyyy-MM-dd HH:mm:ss` (MySQL `DATETIME` 형식, 실행 PC의 로컬 시각)

- 저장 직전 참조 무결성을 검사합니다(개체 ID 중복, 세대 번호, 부모가 직전 세대의 실제 개체인지, 가문 승계 규칙, 유전자 개수 등). 문제가 있으면 콘솔에 `[CSV][검증 경고]`로 출력합니다.
- 용량 참고: 세대당 약 290KB(대부분 `genes.csv`)가 늘어납니다. 1,000세대면 약 290MB입니다.

### 데이터 읽기 예시

```python
import pandas as pd
genes = pd.read_csv("exports/DONGHYUN_20261030_141502_3F9A1C2B/genes.csv", encoding="utf-8")
```

```sql
LOAD DATA LOCAL INFILE 'exports/DONGHYUN_20261030_141502_3F9A1C2B/individuals.csv'
INTO TABLE individuals
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;
```

> Excel에서 열면 BOM이 없어 한글이 깨져 보일 수 있습니다. Excel에서는 **데이터 → 텍스트/CSV 가져오기**에서 UTF-8을 선택하세요. (파일 자체는 정상입니다)

### 역대 최고 기록 JSON (`S` / `ESC`)

기존 `data/best_ai.json`, `data/best_aiN.json` 저장 기능과 키 구조는 그대로 유지합니다(BestAI, NeuralAnalyzer 호환).

- 이전에는 기록 개체를 `clone()`으로 보관해서 **새 개체 ID가 소비되고 점수·통계가 0으로 저장**되는 문제가 있었습니다. (기존 `best_ai.json`의 `"score": 0`, 1세대에 존재하지 않는 `"unique_id": 234` 가 이 문제의 결과입니다)
- 이제는 원본 개체의 값을 복사한 불변 스냅샷(`TetrisRecord.pde`)으로 보관하므로 개체 ID를 소비하지 않고, 원본 ID·시조·세대·점수·게임 통계·가중치가 그대로 저장됩니다.
- 추가된 키: `founder_id`, `founder_name`, `family_name`, `is_final`(게임 종료 후 확정된 값인지), `run_id`
- 역대 기록은 매 프레임 전체 200개체(사망 포함) 중 최고 점수로 갱신하고(기존: 1초마다, 화면에 표시된 대표 개체만 확인), 세대가 끝날 때 최종 점수로 다시 확정합니다.

### CSV 활용 예시

저장된 데이터를 Python 프로그램에서 MySQL로 가져오면 다음 분석을 수행할 수 있습니다.

- 역대 최고 점수를 기록한 개체와 소속 가문 조회
- 세대별 최고 점수 및 평균 점수 변화 분석
- 특정 개체의 부모·조상·후손 추적
- 가문별 생존 후손 수 및 멸문 여부 확인
- 우수 개체의 유전자 가중치 비교
- 실험 조건별 학습 성과 비교
