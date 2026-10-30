import java.util.HashSet;

// 최초 1세대 개체 200마리에게 순서대로 부여되는 시조 이름
// 시조 #n (= 가문 ID n = species_id n) 의 이름은 FOUNDER_NAMES[n-1]
// 순서가 가문 ID를 결정하므로 정렬하거나 변경하지 말 것
final String[] FOUNDER_NAMES = {
  "동현", "지훈", "현우", "준호", "민수", "정민", "재현", "성민", "승현", "진우", "상현", "민호", "태현", "민재", "재호", "종현", "현준", "민석", "영민", "진호",
  "병헌", "성현", "성진", "정훈", "재민", "동욱", "준혁", "승민", "우진", "동하", "승우", "정우", "상민", "영준", "현수", "창민", "명훈", "경민", "현진", "영우",
  "성재", "형준", "정현", "재원", "정호", "성호", "지호", "태우", "재웅", "태민", "광현", "민규", "상우", "승재", "재윤", "진현", "철우", "태경", "현승", "호준",
  "민성", "동주", "재경", "민혁", "승찬", "진형", "민우", "진수", "재혁", "준영", "찬우", "원우", "인우", "건호", "태호", "범준", "우영", "찬희", "우성", "동윤",
  "준형", "재훈", "석민", "선호", "승원", "영재", "용우", "정환", "지환", "진혁", "태영", "태환", "현석", "형민", "혜성", "효준", "희재", "강민", "건우", "규민",
  "민지", "은지", "지현", "수진", "혜원", "은서", "현지", "지영", "소희", "유나", "지수", "유정", "다솜", "보미", "소영", "미선", "다혜", "선영", "진아", "아름",
  "하나", "슬기", "보라", "슬아", "아라", "혜수", "현주", "지은", "서연", "서현", "지민", "민경", "서윤", "하은", "수빈", "예은", "다은", "유진", "채원", "수민",
  "지원", "나은", "예린", "지아", "소윤", "윤서", "지윤", "채윤", "서진", "민아", "세린", "가을", "가현", "세인", "한나", "은하", "서원", "미소", "수지", "혜린",
  "재인", "서린", "주연", "채희", "소원", "여름", "아연", "수연", "예원", "희원", "가영", "나연", "다윤", "서하", "선재", "성희", "수아", "승연", "시현", "신영",
  "유빈", "윤아", "은비", "은채", "인아", "정원", "정윤", "주은", "지우", "채은", "태희", "하윤", "하율", "해인", "현아", "혜진", "효주", "희진", "가민", "규리"
};

String founderName(int familyId) {
    if(familyId < 1 || familyId > FOUNDER_NAMES.length) return "?";
    return FOUNDER_NAMES[familyId-1];
}

String familyName(int familyId) {
    return founderName(familyId) + " 가문";
}

// 시조 이름 목록 자체 검증 (개수, 빈 값, 중복)
void validateFounderNames(int populationSize) {
    if(FOUNDER_NAMES.length != populationSize) {
        throw new RuntimeException("시조 이름 개수(" + FOUNDER_NAMES.length + ")가 초기 개체 수(" + populationSize + ")와 다릅니다.");
    }
    HashSet<String> seen = new HashSet<String>();
    for(int i = 0; i < FOUNDER_NAMES.length; i++) {
        String name = FOUNDER_NAMES[i];
        if(name == null || name.trim().length() == 0 || !name.equals(name.trim())) {
            throw new RuntimeException("시조 #" + (i+1) + "의 이름이 비어 있거나 공백을 포함합니다.");
        }
        if(!seen.add(name)) {
            throw new RuntimeException("중복된 시조 이름: " + name + " (시조 #" + (i+1) + ")");
        }
    }
}

// 1세대 개체군과 시조 이름의 일대일 대응 검증
void validateFounderPopulation(Population p) {
    Tetris[] founders = p.tetris_pop;
    if(founders.length != FOUNDER_NAMES.length) {
        throw new RuntimeException("1세대 개체 수(" + founders.length + ")와 시조 이름 수(" + FOUNDER_NAMES.length + ")가 다릅니다.");
    }
    HashSet<Integer> ids = new HashSet<Integer>();
    HashSet<Integer> families = new HashSet<Integer>();
    HashSet<String> names = new HashSet<String>();
    for(int i = 0; i < founders.length; i++) {
        Tetris t = founders[i];
        if(t.species_id != i+1)
            throw new RuntimeException("개체 #" + t.uniqueID + "의 가문 ID(" + t.species_id + ")가 시조 순번(" + (i+1) + ")과 다릅니다.");
        if(!t.birthType.equals("FOUNDER") || t.birthGeneration != 1 || t.parentAID != 0 || t.parentBID != 0 || t.cloneSourceID != 0)
            throw new RuntimeException("개체 #" + t.uniqueID + "가 부모 관계가 없는 1세대 시조로 생성되지 않았습니다.");
        if(!ids.add(t.uniqueID))
            throw new RuntimeException("1세대 개체 ID 중복: " + t.uniqueID);
        families.add(t.species_id);
        names.add(founderName(t.species_id));
    }
    if(families.size() != FOUNDER_NAMES.length || names.size() != FOUNDER_NAMES.length) {
        throw new RuntimeException("가문 수(" + families.size() + ") 또는 시조 이름 수(" + names.size() + ")가 " + FOUNDER_NAMES.length + "가 아닙니다.");
    }
    println("[Founders] 검증 완료: 개체 " + founders.length + " / 시조 이름 " + names.size() + " / 가문 " + families.size()
            + " (중복 없음, 부모 관계 없음) — #1 " + founderName(1) + ", #" + FOUNDER_NAMES.length + " " + founderName(FOUNDER_NAMES.length));
}
