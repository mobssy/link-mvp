# 개발 노트

[English](ENGINEERING.md) · [한국어](ENGINEERING.ko.md) · [README](../README.ko.md)

## 고민하고 다듬은 것들

L!NK에는 서버가 없습니다. 모든 대화의 상대방은 시뮬레이션이고, 모든 AI 기능은 기기 안의 작은 온디바이스 모델에서 돌아갑니다. 그래서 작업 대부분은 이 모델의 출력을 여러 언어에서 믿을 만하게 만드는 일과, 하나의 코드로 iOS 26과 iOS 27을 모두 제대로 지원하는 일에 들어갔습니다. 아래의 변경은 모두 모델 출력을 찍어 보는 임시 프로브 테스트로 한국어·영어 샘플 대화에 먼저 돌려 본 뒤 반영했습니다. 자세한 과정은 각 커밋 메시지에 남아 있습니다.

### 작은 온디바이스 모델을 믿을 수 있게 만들기

- **없는 할 일을 지어내지 않는 회의 노트.** 처음에는 모델이 목록을 부풀렸습니다. "Should we invite Jordan?"이라는 질문이 질문한 사람의 할 일이 되고, 등산 이야기 같은 잡담이 할 일로 들어갔습니다. 이제 할 일마다 근거가 된 메시지를 인용하고 그 메시지가 무엇인지(약속, 요청, 질문)를 밝혀야 하며, 인용이 실제로 대화에 있을 때만 남깁니다. 담당자는 대화에 나온 이름으로만 정하고, 요청한 사람이 그 요청의 담당자가 되지 않게 했습니다. 인사말 속 "오늘"이 아무도 말하지 않은 정오로 고정되는 일이 있어서, 날짜는 모델이 아니라 `NSDataDetector`가 읽습니다. 그 뒤 영어·한국어·혼용 샘플 대화 6개에서 지어낸 할 일도, 잘못된 담당자도 나오지 않았습니다.
- **긴 대화의 요약.** 모델은 한 번에 약 4,000토큰만 읽기 때문에, 긴 대화는 여러 부분으로 나눠 부분마다 메모를 받고 그 메모로 요약을 쓰며 진행 상황을 화면에 보여 줍니다. 여기까지 세 번을 고쳤습니다. "글머리표 4개"로 메모를 요청하자 부분마다 첫 줄만 베꼈습니다. 메모 전체를 한 번에 요약하게 하자 대화 초반 이야기에만 머물렀습니다. 모델이 프롬프트의 "[2~3문장으로 쓰세요…]" 자리 표시까지 그대로 옮겨 적는 일도 있어서, 요약의 구성은 이제 앱이 직접 잡습니다(가이드 생성). 메시지 164개짜리 여행 계획 대화에서 처음에 정한 날짜와 마지막의 예약 내용이 모두 요약에 들어갑니다.
- **요약 하나, 두 언어.** 영어 요약에서 내 메시지에 붙인 "Me"를 모델이 이름으로 읽어 "Me will send the updated slides"라고 썼습니다. "You"로 바꾸자 해결됐습니다. 대신 2인칭으로 쓰라고 하면 한국어에서 딱딱한 "당신"이 나와서, 언어마다 각자의 표현을 씁니다. 요약 날짜는 기기 지역 설정을 따라 한국어 요약에 영어 날짜가 붙었는데, 이제 앱 언어를 따릅니다.
- **맞는 언어로 하는 답장.** 시뮬레이션 상대방은 원래 한국어 기본 문장 10개 중에서 골라 답했습니다("Dinner at 7?"에 "파일 잘 받았습니다 📄"). 이제는 기기 안의 모델이 실제로 한 말에 답합니다. 언어 감지에는 안전장치가 필요했습니다. "ok" 한 단어는 폴란드어로 인식돼 "Dobra."라는 답이 나왔고, "사용자의 언어로" 답하라고 하자 모델은 스페인어를 골랐습니다. 이제 감지 결과는 신뢰도 0.8 이상일 때만 쓰고, 짧은 메시지는 앞선 메시지와 함께 읽으며, 그래도 모르면 앱 언어를 씁니다.
- **대화의 맞은편에서 고르는 추천 답장.** 추천 답장이 누가 말하는지를 놓쳐서, "Congrats! When do you start?"에 "Congrats!"를 추천했습니다. 이제 대화록에 나와 상대를 표시합니다. 프롬프트에 예시 답을 넣어도 고쳐지긴 했지만, 그 예시가 상관없는 대화에 글자 그대로 나타나서 뺐습니다.
- **언어를 넘나드는 의미 검색.** "저녁 약속"으로 "dinner tonight"을 찾아야 합니다. 관련 표현을 달라고 하자 모델은 어떤 메시지에도 없는 표현을 지어내서, 이제 한 단어씩 받습니다. 유의어와 번역어를 함께 달라고 하자 검색어의 언어에만 머물러서, 번역어는 따로 받습니다. 검색어를 통째로 번역하는 문제("dinner appointment")도 있어서, 번역어는 단어 단위로 맞춰 봅니다. 무엇을 더해 찾았는지 화면에 보여 주므로 왜 그 메시지가 찾아졌는지 알 수 있습니다.
- **iOS 27의 사진 설명.** 영어로 쓴 요청에 한국어 설명을 달라고 하자 모델은 영어로 답한 뒤 스스로 번역했습니다. 그래서 요청 자체를 답해야 할 언어로 씁니다. iOS 26에서는 사진이 예전처럼 동작합니다.
- **지어낸 번역보다는 번역 없음.** Apple Intelligence와 Translation 프레임워크가 둘 다 번역하지 못하면, 예전에는 짧은 인사말 사전과 한국어·영어 단어를 하나씩 바꿔 끼운 결과를 번역처럼 보여 줬습니다. 이제는 메시지 아래에 번역할 수 없었다고 표시합니다.

### 하나의 코드로 iOS 26과 iOS 27 지원하기

- **밀어서 답장.** `swipeActions`는 List에서만 동작하는데 메시지는 ScrollView 안에 있어서, iOS 26에서는 오른쪽으로 밀면 시스템의 뒤로 가기가 받아 채팅방을 나가 버렸습니다. 말풍선에 SwiftUI 드래그 제스처를 달자 밀기는 되었지만 스크롤이 막혔습니다. 결국 오른쪽으로, 주로 옆으로 움직일 때만 시작하는 UIKit 팬 제스처를 쓰고, iOS 26의 뒤로 가기가 이 제스처를 기다리게 했습니다. 말풍선에서 밀면 답장이 되고, 말풍선 옆에서 밀면 여전히 뒤로 갑니다. 두 경우 모두 iOS 26.5에서 원래 동작과 비교해 확인했습니다.
- **로드되지 않던 테스트 타깃.** AppIntentsTesting(iOS 27)은 iOS 26에 없는 라이브러리를 링크합니다. 프레임워크 자체는 있기 때문에 약한 링크로도 해결되지 않아, iOS 26에서 UI 테스트 번들 전체가 로드되지 않았습니다. Siri 테스트를 별도 타깃으로 옮겨 UI 테스트가 다시 두 버전에서 돌아갑니다.
- **기기 안에서만.** iOS 27의 Private Cloud Compute는 긴 대화를 한 번에 읽을 수 있지만 별도 승인이 필요한 권한이 있어야 하고, 권한 없이 첫 요청을 보내면 앱이 종료됩니다. 그래서 모든 AI 기능은 기기 안에서만 돌아갑니다.

### SwiftUI 상태와 동시성

- **지난 결과를 보여 주던 시트.** 회의 노트 시트가 노트를 쓰는 동안 몇 초씩 "정리할 내용이 아직 없어요"로 열려 있었습니다. 상태가 채팅 화면의 `@State`에 있었는데 시트만 그 값을 읽어서, 값이 바뀌어도 화면이 다시 그려지지 않았습니다. 시트가 직접 읽는 `@Observable` 모델로 옮겼고, 이를 위해 쓴 UI 테스트는 수정 전에는 실패하고 수정 후에는 통과합니다.
- **액터를 넘나드는 SwiftData.** 요약이 AI 서비스의 액터에서 SwiftData 메시지를 읽어서, 메인 스레드에서 자폭 메시지가 지워지는 순간과 경합했습니다. Swift 5 언어 모드에서는 경고가 나지 않았고, 이제 채팅 화면이 `Sendable` 복사본을 넘깁니다.
- **채팅을 멈추게 한 녹음.** 마이크를 누르고 있으면 채팅 전체가 멈췄습니다. 오디오 세션을 메인 스레드에서 켰고, 녹음기도 시작하면서 세션을 스스로 한 번 더 켰기 때문입니다. 시뮬레이터에서는 9초 누르기가 1분 넘게 걸렸습니다. 이제 둘 다 메인 스레드 밖(`@concurrent`)에서 돌고, 녹음이 시작되기 전에 손을 떼도 깔끔하게 취소됩니다.
- **아무도 보지 않던 작업.** 번역을 켜면 받은 메시지마다 번역이 두 번 돌았습니다. 한 번은 아무도 읽지 않는 딕셔너리를 채우는 용도였고, 보낸 메시지도 쓸데없이 한 번씩 번역됐습니다. 실제 온디바이스 추론이었고, 이제 없앴습니다.

### 시뮬레이터가 못 하는 것 확인하기

- 음성 인식은 iOS 시뮬레이터에서 돌지 않아서, 받아쓰기 과정은 같은 코드로 macOS에서 확인했습니다. 합성한 영어·한국어 문장이 글자 그대로 돌아왔고, 이때 테스트가 오디오 끝이 1,024프레임 경계에서 잘리는 문제를 잡아냈습니다.
- UI 테스트는 아이폰(iOS 26.5, 27)과 iPad에서 돌고, Siri 동작은 AppIntentsTesting으로 시스템을 거쳐 끝까지 실행합니다.

## 아이폰에서 실행하기

1. `TalkMVP.xcodeproj`를 열고 **TalkMVP** 타깃 → **Signing & Capabilities**에서 팀을 선택합니다. 무료 Apple ID라면 번들 ID도 고유한 값으로 바꿔 주세요.
2. 아이폰을 연결하고 실행 대상으로 선택한 뒤 **Run**을 누릅니다.
3. 무료(개인) 팀은 첫 실행 전에 기기에서 개발자를 신뢰해야 합니다: **설정 → 일반 → VPN 및 기기 관리 → 내 Apple ID → 신뢰**. 무료 프로비저닝 프로파일은 7일 후 만료되며, Xcode에서 다시 실행하면 갱신됩니다.
4. 로그인 화면의 **테스트 모드로 체험하기**를 누르면 계정 없이 샘플 친구·채팅과 함께 앱을 둘러볼 수 있습니다.

## 프로젝트 구조

앱 타깃은 역할별로 나뉩니다. 화면은 흐름마다 `Features/` 아래 폴더 하나에, 화면이 없는 로직은 `Services/`, `Repositories/`, `Models/`에 있습니다. `TalkMVP/`는 Xcode가 타깃에 자동 동기화하는 폴더라, 디스크의 폴더가 그대로 Xcode의 그룹입니다.

```
link-mvp/
├── TalkMVP.xcodeproj/
├── TalkMVP/
│   ├── App/                     # 앱 진입점과 탭 구성
│   ├── Features/                # 화면, 흐름별 폴더 하나씩
│   │   ├── Auth/                # AuthView, SSOSignInView, AppLockView, OnboardingContactsView
│   │   ├── Chats/               # ChatListView
│   │   ├── Conversation/        # ChatView (+Friends/Helpers/Input/Media/Messages/Sheets), ChatViewModel,
│   │   │                        # MessageBubbleView, MeetingNotesView, ChatRoomBackgroundSettings, …
│   │   ├── Friends/             # FriendsView, FriendProfileView, FriendRowViews, AddFriendView, FriendManagementViews
│   │   └── Settings/            # SettingsView, SettingsCardComponents, ProfileEditView, *SettingsView 페이지들,
│   │                            # HelpView, AppInfoView, TermsPoliciesView
│   ├── Services/                # 화면 없는 로직
│   │   ├── AI/                  # AIService, MeetingNotes (+Extractor/Grounding), ReplySuggestions, ReplyWriter,
│   │   │                        # MessageTranslation, MessageSearch, PhotoDescriber, VoiceTranscriber, …
│   │   ├── Auth/                # AuthManager, GoogleOAuthService, AppLockManager
│   │   ├── Chat/                # ChatService (+Protocol), AutoResponseService, OpenChatRooms, NotificationManager,
│   │   │                        # LocalNotificationDelegate
│   │   ├── Contacts/            # ContactsSyncService, FriendSearchService
│   │   ├── Location/            # LocationManager
│   │   └── Media/               # VoiceMessageService, AttachmentHandler, AttachmentPreviewer
│   ├── Intents/                 # ChatIntents, ChatIntentActions (Siri·단축어)
│   ├── Models/                  # ChatRoom, Message, User (SwiftData)
│   ├── Repositories/            # 프로토콜 뒤의 SwiftData 접근, 첨부 파일, 정리 작업, 테스트 계정
│   ├── Localization/            # L10n, LanguageManager (+Extensions), LocalizationService
│   ├── DesignSystem/            # 브랜드 색상, 글자 크기·손쉬운 사용 설정, 터치 영역
│   ├── AppShortcuts.xcstrings   # Siri 문구 (앱이 지원하는 5개 언어)
│   ├── Localizable.xcstrings    # Siri·단축어 문구 (같은 5개 언어, UI 문구는 코드에서 번역)
│   └── Assets.xcassets/         # 앱 아이콘, 색상, 이미지 에셋
├── TalkMVPTests/
│   └── TalkMVPTests.swift       # Swift Testing 스위트
├── TalkMVPUITests/
│   ├── TalkMVPUITests.swift     # 아이폰·iPad UI 흐름 테스트
│   └── TalkMVPUITestsLaunchTests.swift
├── TalkMVPSiriUITests/
│   └── SiriActionsUITests.swift # AppIntentsTesting으로 Siri 동작을 끝까지 실행 (iOS 27 전용)
└── docs/
    ├── ENGINEERING.ko.md        # 이 문서
    └── screenshots/             # README에 쓰인 이미지 (앱 번들에는 포함되지 않음)
```

## 테스트


```bash
# 단위 테스트 (Swift Testing)
xcodebuild test -project TalkMVP.xcodeproj -scheme TalkMVP \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TalkMVPTests

# UI 테스트 — iPad에서도 돌려 주세요: 목록·대화 나란히 보기 테스트는 넓은 창에서만 실행됩니다
xcodebuild test -project TalkMVP.xcodeproj -scheme TalkMVP \
  -destination 'platform=iOS Simulator,name=iPad mini (A17 Pro)' -only-testing:TalkMVPUITests

# Siri·단축어 — AppIntentsTesting으로 끝까지 실행하며 iOS 27 시뮬레이터가 필요합니다
xcodebuild test -project TalkMVP.xcodeproj -scheme TalkMVP \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TalkMVPSiriUITests
```
