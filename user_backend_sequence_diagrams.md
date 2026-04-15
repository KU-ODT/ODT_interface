# ODT 시스템 시퀀스 & 동역학 아키텍처 (PPT 발표용 자료)

> **문서 활용 가이드**: 본 문서의 모든 다이어그램은 시스템이 다르게 보이지 않도록 **완벽히 동일한 5개의 구성요소(기둥)**를 사용해 통일성을 부여했습니다.
> 
> **[핵심 컴포넌트(기둥) 개념 설명]**
> *   💻 **Web Frontend**: 사용자가 누르는 Vue 화면 및 지도 Iframe.
> *   🌐 **API Gateway**: 웹 HTTP(POST/GET) 요청을 받아 검증하고 타겟 IP로 넘겨주는 통신 문지기 (프론트 통신용).
> *   ⚙️ **Backend Engine**: 실제 무거운 루프(While)나 자율비행 제어, VDT 수학 연산이 돌아가는 파이썬/C++ 핵심 워커(Worker).
> *   🚁 **AirSim (& Unreal)**: 3D 그래픽을 표출하고 기초 물리 판정을 내리는 시뮬레이터 렌더러.

---

## [Slide 1] Phase 2: Initial Configuration (초기 설정)
**발표 포인트**: 이 단계에서는 렌더링 부하나 엔진 통신이 전혀 없으며, 프론트엔드 환경에서 모든 Parameter를 세팅해 둡니다. 이는 이후의 "운명"을 결정하는 설계도가 됩니다.

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GUI as 💻 Web Frontend
    participant Gateway as 🌐 API Gateway
    participant Engine as ⚙️ Backend Engine
    participant AirSim as 🚁 AirSim & Unreal

    User->>GUI: 1. 시스템 설정 (도시, 기체, 미션 모드 등)
    User->>GUI: 2. "RUN ODT SYSTEM" 클릭
    
    Note over GUI: 설정값(State)들을 Local Store(odtStore)에 캐싱해 둠.<br/>- [City]: 향후 접속할 서버(VM IP) 라우팅에 활용<br/>- [Vehicle]: 제어할 특정 기체 식별자 Payload에 활용<br/>- [Mission Mode]: Simple/Customize UI 경로 분기<br/>- [AI Plugin]: 향후 카메라 분석 모델에 투입
    
    GUI-->>User: 3. 시스템 준비 완료 (메뉴 활성화)
```

---

## [Slide 2] Phase 3.1: Mission Execution (Simple Mode 흐름)
**발표 포인트**: 개발단계 및 관제 상황용 지정 경로 비행입니다. Phase 2에서 선택한 정보(VM IP, 기체명)가 Gateway와 Engine을 거쳐 시뮬레이터를 가동시킵니다.

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GUI as 💻 Web Frontend
    participant Gateway as 🌐 API Gateway
    participant Engine as ⚙️ Backend Engine
    participant AirSim as 🚁 AirSim & Unreal

    User->>GUI: "CONNECT" 및 "START" 클릭
    
    Note over GUI, Gateway: Phase 2의 [City] 매핑값을 통해 특정 서버(vmIp) 접속!<br/>호출: POST /{vmIp}/start (Payload: {vehicle_name="High-Fid"})
    GUI->>Gateway: REST API 전송 (라우팅 및 Payload 전달)
    
    Gateway->>Engine: 미션 실행 스레드(MissionRunner) 백그라운드 가동
    Engine->>AirSim: Client 통신 제어권 획득 (해당 기체 특정)
    
    Note over Engine, AirSim: [사전 정의된 고정 좌표 비행]<br/>지정된 Waypoint 배열을 향해 자율비행(moveOnPathAsync) 1회 발송
    
    loop 매 1초 마다 (Telemetry)
        Engine->>AirSim: 기체 상태 (배터리, 위치) 수집
        Engine-->>GUI: JSON 실시간 표출
    end
```

---

## [Slide 3] Phase 3.2: Mission Execution (Customize Mode 흐름)
**발표 포인트**: 동적 라우팅 역학입니다. 사용자가 맵 프레임(Iframe)에서 찍은 경로 위치를 1차원 데이터가 아닌, 엔진이 연산 가능한 좌표로 변환합니다.

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GUI as 💻 Web Frontend
    participant Gateway as 🌐 API Gateway
    participant Engine as ⚙️ Backend Engine
    participant AirSim as 🚁 AirSim & Unreal

    User->>GUI: 맵 위에 출발-도착 마커 직접 클릭
    
    Note over GUI, Gateway: [Vehicle] 값과 마커 위치 묶어 전송<br/>Payload: { route: [위도/경도 배열], vehicle_name }
    GUI->>Gateway: WGS84 위경도 데이터 POST 전송
    
    Gateway->>Engine: 동적 비행 스레드 가동 요청
    
    Note over Engine, AirSim: [동적 좌표계 변환(Dynamic Transform)]<br/>Engine이 드론 주위의 환경에 맞게 <br/>위경도 => 로컬 미터(m) 단위(NED 좌표)로 실시간 통역
    
    loop 변환된 웨이포인트 갯수 만큼 반복
        Engine->>AirSim: 통역된 위치로 쪼개어서 비행 지시 (moveToPosition)
        AirSim-->>Engine: 목표점마다 도착 확인 대기
    end
```

---

## [Slide 4] Phase 3.3: Mission Dynamics (Simple 연산과정)
**발표 포인트**: Phase 3.1 & 3.2에서 비행 지시가 들어갔을 때, 시뮬레이터 자체에 내장된 기초 물리 연산이 기동하는 시퀀스입니다. 

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GUI as 💻 Web Frontend
    participant Gateway as 🌐 API Gateway
    participant Engine as ⚙️ Backend Engine
    participant AirSim as 🚁 AirSim & Unreal

    Engine->>AirSim: 1. "계산된 목표 지점으로 초속 10m로 가라" (1회 지시)
    
    loop 시뮬레이터 자체 프레임 단위
        Note over AirSim: 2. AirSim(FastPhysics) 자체 강체 동역학 연산 수행<br/>(바람, 저항 무시 / 단순 관성/중력 이동)
        AirSim->>AirSim: 3. 연산 완료된 3D 그래픽 좌표 갱신 (스스로)
    end
    
    AirSim-->>User: 4. 최종 렌더링 화면 표출
```

---

## [Slide 5] Phase 3.4: Mission Dynamics (High-Fidelity 연산과정)
**발표 포인트**: 정밀 해석입니다. AirSim 내부 물리 엔진을 완전 차단하고, 무거운 수학 연산을 전담하는 CADE/SITL(Backend Engine)이 통제권을 100% 장악합니다.

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GUI as 💻 Web Frontend
    participant Gateway as 🌐 API Gateway
    participant Engine as ⚙️ Backend Engine
    participant AirSim as 🚁 AirSim & Unreal

    Note over Engine: 1. 외부 VDT 모듈(MDADE/SITL)이 고정밀 공력/추력 연산
    
    loop 고속 통신 루프 (초당 50~100 프레임)
        Note over Engine, AirSim: 2. "지금 즉시 이 X,Y,Z 위치와 회전각태로 존재하라"
        Engine->>AirSim: 3. 신규 파라미터 강제 주입 (simSetVehiclePose)
        
        Note over AirSim: 4. AirSim 자체 물리엔진은 기능 정지(완전 무시 Bypass됨)
        
        AirSim->>AirSim: 5. 전달받은 무조건적 좌표에 아바타를 강제 렌더링
    end
    
    AirSim-->>User: 6. 고정밀로 움직이는 드론 영상 표출
```

---

## [Slide 6] Phase 4: Operation Environment (시각화 연동 흐름)
**발표 포인트**: 비행 중인 언리얼 3D 렌더링 화면을 무거운 연산 없이, 마치 유튜브 영상 보듯 UI로 실시간 스트리밍해 주는 VNC 시퀀스입니다.

```mermaid
sequenceDiagram
    actor User as 👤 User
    participant GUI as 💻 Web Frontend
    participant Gateway as 🌐 API Gateway
    participant Engine as ⚙️ Backend Engine
    participant AirSim as 🚁 AirSim & Unreal

    User->>GUI: "Operation Environment" 메뉴 (화면) 진입
    GUI->>Gateway: 스트리밍 컴포넌트 접속 URL 리턴 요청
    Gateway-->>GUI: VNC 고유 웹 스트리밍 소스 발급 (vnc.html?...)
    
    Note over GUI, AirSim: Phase 2의 [City] 값으로 매핑된 해당 서버에<br/>웹소켓 레이어를 직접 열고 비디오 프레임을 캡처 전송
    
    AirSim-->>GUI: 실시간 3D 화면을 비디오 스트림으로 송출
    GUI-->>User: 무거운 웹GL 다운로드 없이 영상 즉각 시청
```
