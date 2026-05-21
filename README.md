# FREEZE! — 청각장애인을 위한 안전 알림 웨어러블 앱

> 중앙대학교 다학제 융합 IoT 가전분야 캡스톤 디자인 경진대회 출품작 (No. 10)

청각장애인이 일상에서 놓치기 쉬운 위험 신호(사이렌·화재경보·차량 경적)와
주변 음성·후방 접근 차량을 **진동·시각·텍스트**로 동시에 전달하는
웨어러블 시스템의 **Flutter 모바일/웹 앱** 입니다.

---

## 프로젝트 배경

국내 청각장애인은 약 44만 명으로 전체 등록 장애 유형 중 두 번째로 많고,
신규 등록 비율은 가장 높습니다. 그러나 기존 보청기는 소리를 단순 증폭할 뿐
위험음을 구분하지 못해 화재·교통사고 상황에서 인명 피해로 이어지는 사례가 반복됩니다.

본 프로젝트는 마이크 어레이·카메라·AI 모델로 위험을 능동적으로 분류하고
진동(방향성)과 앱 알림으로 즉시 대응할 수 있는 보조 장치를 목표로 합니다.

---

## 시스템 구성

```
[Respeaker Mic + RPi Cam] ──▶ [Raspberry Pi] ──▶ [AWS EC2 (FastAPI)]
                                     │                  │
                                     │     WebSocket    │
                                     │                  ▼
                                     │            [Flutter App]  ◀── 본 저장소
                                     ▼
                              [ESP32 ─ 진동 모터]
```

| 구성 | 역할 |
| --- | --- |
| Respeaker Mic | 주변 소리 수집, 방향 추정 |
| Raspberry Pi Camera V3 | 후방 영상 촬영 |
| Raspberry Pi | AI 추론(YAMNet / Whisper / YOLOv8) 및 서버 전송 |
| AWS EC2 (FastAPI) | WebSocket 허브, 이벤트 브로커, 영상 저장 |
| ESP32 | 무선 통신으로 진동 모터 제어 |
| **Flutter App** | **실시간 위험 알림 UI, 음성 인식 결과 표시, 후방 영상 갤러리** |

---

## 사용 AI 모델

- **YAMNet (Google)** — 521 종 환경음 분류. 사이렌·화재경보·차량 경적 등 위험음을 식별하고 강도(dB)·방향성을 함께 산출
- **Whisper (OpenAI)** — 대화·이름 호출 등 음성을 텍스트로 변환
- **YOLOv8** — 후방 카메라 영상에서 사람·차량·사물을 탐지, 위험 판정 시 자동 녹화 및 블랙박스 기록

---

## 앱 주요 기능

- **실시간 위험음 알림** — YAMNet 결과를 받아 위험/안전 상태를 카드로 표시, 위험 시 펄스 애니메이션 + 로컬 알림
- **방향 표시** — 컴파스 위젯이 소리가 발생한 방향을 가리킴
- **음성 인식 자막** — Whisper 결과를 실시간 자막처럼 표시
- **블랙박스 갤러리** — YOLOv8가 캡처한 후방 영상/이미지를 날짜별로 정리, 외부 다운로드 가능
- **정확한 연결 인디케이터** — WebSocket 핸드셰이크 완료 시점 기준의 LIVE / CONNECTING 핍
- **크로스플랫폼** — Android / iOS / Web 빌드 지원 (웹은 로컬 알림 제외)

---

## 빠르게 실행하기

```bash
flutter pub get

# 웹 데모 (Chrome)
flutter run -d chrome

# Android 디바이스/에뮬레이터
flutter run -d android

# 릴리즈 빌드
flutter build apk            # Android
flutter build web            # 웹 정적 산출물 → build/web
```

서버 엔드포인트는 [`lib/main.dart`](lib/main.dart)의 `EventViewerPage(endpoint: ...)` 에서 변경합니다.

요구 사항: Flutter SDK `^3.8.1`, Dart 3 이상.

---

## 폴더 구조

```
lib/
├── main.dart                       # 앱 진입점, 테마 구성
├── theme/
│   └── tokens.dart                 # 디자인 토큰 (색상·반경·그라데이션)
├── models/
│   └── events.dart                 # Yamnet/Clova/Yolo 이벤트 모델 + JSON 파서
├── services/
│   ├── ws_client.dart              # WebSocket 클라이언트, 자동 재연결
│   ├── ws_connector_io.dart        # 모바일/데스크톱 커넥터
│   ├── ws_connector_web.dart       # 웹 커넥터 (conditional import)
│   └── notification_service.dart   # 로컬 알림 (kIsWeb 시 스킵)
├── pages/
│   ├── event_viewer_page.dart      # 메인 화면: 위험음 + 음성 자막
│   └── yolo_page.dart              # 블랙박스 갤러리
├── widgets/
│   ├── yamnet_card.dart            # 위험/안전 상태 카드 (펄스 + 컴파스)
│   ├── clova_panel.dart            # 음성 인식 패널
│   ├── yolo_card.dart              # YOLO 이미지 카드
│   └── empty_state.dart            # 빈 상태 placeholder
└── utils/
    └── yolo_utils.dart             # 시간 → 파일명/날짜 키 변환
```

레이어 책임 분리:

- **models/** — 서버에서 오는 JSON을 타입 안전한 Dart 객체로 변환. UI/네트워크와 분리
- **services/** — WebSocket 연결·재연결, 로컬 알림 등 외부 통신 / 부수 효과
- **widgets/** — 재사용 가능한 작은 UI 컴포넌트
- **pages/** — 위젯을 조합한 한 화면 단위
- **theme/** — 색상·반경·그라데이션 토큰 한 곳 관리
- **utils/** — 순수 함수 헬퍼

---

## 팀

윤수현 · 김광민 · 김두형 · 이진묵 · 차다민
