# ODT (Operational Digital Twin) — Execution Flow Analysis

> **Legend**
> - 🖥️ `[GUI]` — Screens the user sees and interacts with
> - ⚙️ `[Logic]` — Internal code running behind the scenes (Store, Service, API modules, etc.)
> - 🌐 `[Backend]` — External servers / simulators

## Table of Contents
1. [End-to-End Execution Overview](#1-overview)
2. [Phase 1: Login → Home → Service Bootstrap](#2-phase-1)
3. [Phase 2: Initial Configuration](#3-phase-2)
4. [Phase 3: Mission Execution (Simple Mode)](#4-phase-3)
5. [Phase 4: Operation Environment (Visualization)](#5-phase-4)
6. [Phase 5: Vertiport Customize](#6-phase-5)
7. [State Machine & Guard System](#7-state-machine)
8. [Real-time Data Polling](#8-polling)
9. [Runtime Architecture — How Tabs Run in Parallel](#9-parallel)

---

## 1. End-to-End Execution Overview {#1-overview}

```mermaid
graph TD
    LOGIN["🖥️ Login GUI"] --> HOME["🖥️ Home GUI + Bootstrap"]
    HOME --> CONFIG["🖥️ Configuration GUI<br/>Environment / Vehicle / Mission / AI"]
    CONFIG -->|RUN ODT SYSTEM| READY{Configuration<br/>Ready?}
    READY -->|Yes + Simple mode| MISSION["🖥️ Use Case GUI<br/>Mission Execution & Monitoring"]
    READY -->|Yes + Customize mode| VERTIPORT["🖥️ Customize GUI<br/>Vertiport Setup"]
    READY -->|Yes| VIS["🖥️ Operation Environment GUI<br/>VNC / UE iframe"]
    READY -->|Yes| SIT["🖥️ Situation Monitoring GUI<br/>Monitoring iframe"]
    
    MISSION --> CONNECT[Connect to AirSim]
    CONNECT --> START[Start Mission]
    START --> POLLING["1-second polling<br/>Status + Sensors + Logs"]
    POLLING --> CONTROL{Control Commands}
    CONTROL -->|Pause| PAUSE[Pause / Hover]
    CONTROL -->|Resume| RESUME[Resume]
    CONTROL -->|Reset| RESET[Reset World]
    
    style LOGIN fill:#1e3a5f
    style CONFIG fill:#2d4a2d
    style MISSION fill:#4a2d2d
    style VERTIPORT fill:#4a3d2d
    style VIS fill:#2d2d4a
```

> [!NOTE]
> There is **no dedicated Mission Planning step** in the current codebase. The system goes directly from Configuration → Mission Execution. Missions are pre-defined scenarios executed by AirSim.

---

## 2. Phase 1: Login → Home → Service Bootstrap {#2-phase-1}

### 2.1 Login Sequence

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant LoginGUI as 🖥️ Login GUI
        participant HomeGUI as 🖥️ Home GUI
    end

    box rgb(50, 50, 50) Internal Logic
        participant AuthSvc as ⚙️ authService
        participant AuthStore as ⚙️ authStore
    end

    box rgb(80, 40, 40) Backend
        participant Backend as 🌐 Platform API
    end

    User->>LoginGUI: { username: "researcher", password: "****" }

    LoginGUI->>AuthSvc: loginAndInit({ username, password })

    AuthSvc->>Backend: POST /api/auth/login<br/>Content-Type: application/x-www-form-urlencoded<br/>Body: username=researcher&password=****

    Backend-->>AuthSvc: {<br/>  status: 0,<br/>  msg: "success",<br/>  data: {<br/>    access_token: "eyJhbGci...",<br/>    refresh_token: "dGhpcyBp...",<br/>    user: { uid: 42, nick_name: "Dr. Kim" },<br/>    productIdList: [1, 3]<br/>  }<br/>}

    AuthSvc->>AuthStore: login({<br/>  access_token: "eyJhbGci...",<br/>  refresh_token: "dGhpcyBp...",<br/>  uid: 42,<br/>  nick_name: "Dr. Kim",<br/>  productIdList: [1, 3]<br/>})

    Note over AuthStore: sessionStorage.setItem("access_token", "eyJhbGci...")<br/>sessionStorage.setItem("refresh_token", "dGhpcyBp...")<br/>sessionStorage.setItem("uid", 42)<br/>sessionStorage.setItem("nick_name", "Dr. Kim")<br/>sessionStorage.setItem("productIdList", "[1,3]")

    LoginGUI->>HomeGUI: router.push("/home")
```

### 2.2 Home Bootstrap Sequence

```mermaid
sequenceDiagram
    box rgb(30, 60, 90) GUI
        participant HomeGUI as 🖥️ Home GUI
    end

    box rgb(50, 50, 50) Internal Logic
        participant CompSvc as ⚙️ componentService
        participant CompStore as ⚙️ compConfigStore
        participant MissionStore as ⚙️ missionStore
        participant VertiStore as ⚙️ vertiportStore
        participant WebSvc as ⚙️ websiteService
        participant WebStore as ⚙️ websiteUrlStore
    end

    box rgb(80, 40, 40) Backend
        participant Backend as 🌐 Platform API
    end

    Note over HomeGUI: onMounted() → Promise.all([ ... ])

    par Parallel: Load component configs
        HomeGUI->>CompSvc: loadCompConfigs()
        CompSvc->>Backend: GET /api/component/configs<br/>Authorization: Bearer eyJhbGci...

        Backend-->>CompSvc: {<br/>  status: 0,<br/>  data: [<br/>    {<br/>      serviceKey: "visualization",<br/>      componentType: "VM_VNC",<br/>      vmIp: "192.168.0.101",<br/>      productId: 1,<br/>      componentId: 201,<br/>      available: true<br/>    },<br/>    {<br/>      serviceKey: "mission",<br/>      componentType: "MISSION",<br/>      vmIp: "192.168.0.102",<br/>      productId: 1,<br/>      componentId: 202<br/>    },<br/>    {<br/>      serviceKey: "situation",<br/>      componentType: "VM_VNC",<br/>      vmIp: "192.168.0.103",<br/>      productId: 1,<br/>      componentId: 203,<br/>      available: true<br/>    },<br/>    {<br/>      serviceKey: "vertiport",<br/>      vmIp: "192.168.0.104",<br/>      productId: 1,<br/>      componentId: 204<br/>    }<br/>  ]<br/>}

        CompSvc->>CompStore: setFromList(data)<br/>→ filter: componentType in ["VM_VNC", "UE_WEB"]<br/>→ serviceMap: {<br/>    "visualization": { vmIp: "192.168.0.101", componentType: "VM_VNC", ... },<br/>    "situation": { vmIp: "192.168.0.103", componentType: "VM_VNC", ... }<br/>  }

        CompSvc->>MissionStore: setFromList(data)<br/>→ filter: serviceKey === "mission"<br/>→ vmIp = "192.168.0.102"

        CompSvc->>VertiStore: setFromList(data)<br/>→ filter: serviceKey === "vertiport"<br/>→ vmIp = "192.168.0.104"

    and Parallel: Load website URLs
        HomeGUI->>WebSvc: loadWebsiteUrls()
        WebSvc->>Backend: GET /api/websites?affiliation=kada<br/>Authorization: Bearer eyJhbGci...

        Backend-->>WebSvc: {<br/>  status: 0,<br/>  data: [<br/>    { key: "kadainstitutehomepage", url: "https://sites.google.com/..." },<br/>    { key: "kadaproducthomepage", url: "https://kada.konkuk.ac.kr/..." },<br/>    { key: "dtamtutorial", url: "https://docs.google.com/..." }<br/>  ]<br/>}

        WebSvc->>WebStore: setFromList(data)<br/>→ websiteMap: {<br/>    "kadainstitutehomepage": "https://sites.google.com/...",<br/>    "kadaproducthomepage": "https://kada.konkuk.ac.kr/...",<br/>    "dtamtutorial": "https://docs.google.com/..."<br/>  }
    end

    Note over HomeGUI: ✅ Bootstrap complete
```

> [!IMPORTANT]
> **`productIdList: [1, 3]`** means this user has access to both ODT (`1`) and CADE (`3`). The sidebar dynamically shows/hides DTAM and CADE menu groups based on `productIdList.includes(COMPONENT_IDS.ODT)`.

---

## 3. Phase 2: Initial Configuration {#3-phase-2}

### 3.1 Configuration GUI Layout

```
🖥️ Configuration GUI
┌──────────────────────────────────────────────────┐
│           OPERATIONAL DIGITAL TWIN                │
│             INITIAL CONFIGURATION                 │
│  ┌──────────────────┬──────────────────────────┐  │
│  │ OPERATION ENV    │ VEHICLE CONFIGURATION     │  │
│  │ [Seoul ▾]        │ [Low] [Mid] [✅ High]     │  │
│  ├──────────────────┼──────────────────────────┤  │
│  │ MISSION SCENARIO │ AI PLUGINS               │  │
│  │ [✅ Simple]      │ [YOLO] [✅ R-YOLO]       │  │
│  │ [Customize]      │                           │  │
│  └──────────────────┴──────────────────────────┘  │
│  Status: Env: Seoul | Vehicle: High-Fidelity ...  │
│  [Save Configuration] [🟢 RUN ODT SYSTEM] [Load] │
└──────────────────────────────────────────────────┘
```

### 3.2 RUN ODT SYSTEM Sequence

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant ConfigGUI as 🖥️ Configuration GUI
        participant SidebarGUI as 🖥️ Sidebar GUI
        participant ToastGUI as 🖥️ Toast Notification
    end

    box rgb(50, 50, 50) Internal Logic
        participant ODTStore as ⚙️ odtStore
        participant MsgStore as ⚙️ messageStore
        participant MenuLogic as ⚙️ useSidebarMenus
    end

    User->>ConfigGUI: Select city dropdown → "Seoul"
    Note over ConfigGUI: confParams.city = "Seoul"

    User->>ConfigGUI: Click vehicle card → "High-Fidelity"
    Note over ConfigGUI: confParams.vehicle = "High-Fidelity"

    User->>ConfigGUI: Click mission card → "Simple"
    Note over ConfigGUI: confParams.mission = "Simple"

    User->>ConfigGUI: Click AI card → "R-YOLO"
    Note over ConfigGUI: confParams.ai = "R-YOLO"

    User->>ConfigGUI: Click 🟢 "RUN ODT SYSTEM"

    alt Any parameter is empty
        ConfigGUI->>MsgStore: show({<br/>  type: "warning",<br/>  text: "Please complete all initial configuration items before running ODT.",<br/>  duration: 2500<br/>})
        MsgStore->>ToastGUI: ⚠️ Warning toast shown for 2.5s
    else All parameters filled
        ConfigGUI->>ODTStore: setInitialConfiguration({<br/>  vehicle: "High-Fidelity",<br/>  city: "Seoul",<br/>  mission: "simple",     ← toLowerCase()!<br/>  ai: "R-YOLO"<br/>})
        Note over ODTStore: this.initialConfig = { vehicle, city, mission, ai }<br/>this.config.parametersCompleted = true

        ConfigGUI->>ODTStore: markRunClicked()
        Note over ODTStore: this.config.runClicked = true<br/>✅ isConfigurationReady =<br/>  parametersCompleted && runClicked = true

        ConfigGUI->>MsgStore: show({<br/>  type: "success",<br/>  text: "ODT system initialized successfully. You can proceed to the next stage.",<br/>  duration: 2500<br/>})
        MsgStore->>ToastGUI: ✅ Success toast shown
    end

    Note over MenuLogic: computed sidebarMenus re-evaluates:<br/>odtStore.isConfigurationReady === true<br/>odtStore.initialConfig.mission === "simple"

    MenuLogic->>SidebarGUI: Updated menu data:<br/>[<br/>  { title: "Configuration", disabled: false },<br/>  { title: "Mission Plan", children: [<br/>      { title: "Use Case", disabled: false, missionMode: "simple" },<br/>      { title: "Customize", disabled: true, missionMode: "customize" }<br/>  ]},<br/>  { title: "Operation Environment", disabled: false },<br/>  { title: "Situation Monitoring", disabled: false }<br/>]
```

---

## 4. Phase 3: Mission Execution (Simple Mode) {#4-phase-3}

### 4.1 Use Case GUI Layout

```
🖥️ Use Case GUI
┌────────────────────────────────────────────────────────────────────┐
│  KADA ODT PROJECTS - MISSION PROFILE RUNNER    ● SYSTEM CONNECTED │
├──────────────┬──────────────────────┬──────────────────────────────┤
│ LINK SETTINGS│   TELEMETRY FEED     │   SYSTEM CONSOLE             │
│ IP:  10.0.0.5│   UAM1/altitude: 150 │   [UAM1] Taking off          │
│ PORT: 41451  │   UAM1/speed: 24.7   │   [UAM1] Ascending to 150m   │
│ Vehicles:    │   UAM1/battery: 87   │   [UAM1] Waypoint 1 reached  │
│   UAM1       │   UAM1/lat: 37.54    │   [UAM1] Cruising at 150m    │
│              │   UAM1/lon: 127.00   │                              │
│ [DISCONNECT] │   UAM1/heading: 45.2 │                              │
│              │                      │                              │
│ COMMANDS     │                      │                              │
│ [START (S0)] │   Auto-refresh 1s    │      Auto-refresh 1s         │
│ [RESUME]     │                      │                              │
│ [PAUSE]      │                      │                              │
│ [RESET]      │                      │                              │
├──────────────┴──────────────────────┴──────────────────────────────┤
│  2026-03-31 15:30:00                                               │
└────────────────────────────────────────────────────────────────────┘
```

### 4.2 CONNECT Sequence

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant MissionGUI as 🖥️ Use Case GUI
    end

    box rgb(50, 50, 50) Internal Logic
        participant MissionAPI as ⚙️ api/mission.js
        participant MissionStore as ⚙️ missionStore
        participant Axios as ⚙️ missionhttp (axios)
    end

    box rgb(80, 40, 40) Backend
        participant Gateway as 🌐 Mission Gateway
        participant AirSim as 🌐 AirSim VM
    end

    User->>MissionGUI: Click "CONNECT"

    MissionGUI->>MissionAPI: connect()

    MissionAPI->>MissionStore: useMissionStore().vmIp
    MissionStore-->>MissionAPI: vmIp = "192.168.0.102"

    MissionAPI->>MissionAPI: buildMissionUrl("connect")<br/>→ "/192.168.0.102/connect"

    MissionAPI->>Axios: missionpost("/192.168.0.102/connect", {})

    Note over Axios: Request Interceptor adds:<br/>Authorization: Bearer eyJhbGci...

    Axios->>Gateway: POST /kada/odt/mission/192.168.0.102/connect<br/>Headers: {<br/>  Authorization: "Bearer eyJhbGci...",<br/>  Content-Type: "application/json"<br/>}<br/>Body: {}

    Gateway->>AirSim: Initialize connection + vehicles
    AirSim-->>Gateway: Connection established

    Gateway-->>Axios: {<br/>  status: "ok",<br/>  connected: true,<br/>  airsim_ip: "10.0.0.5",<br/>  airsim_port: 41451,<br/>  vehicles: { "UAM1": {} }<br/>}

    Axios-->>MissionAPI: response.data (auto-unwrapped by .then(res => res.data))
    MissionAPI-->>MissionGUI: { connected: true, airsim_ip: "10.0.0.5", ... }

    Note over MissionGUI: status.value.connected = true<br/>🖥️ Header: "○ DISCONNECTED" → "● SYSTEM CONNECTED"<br/>🖥️ Button: green CONNECT → red DISCONNECT

    Note over MissionGUI: ── Immediate refresh ──

    MissionGUI->>Gateway: GET /kada/odt/mission/192.168.0.102/status<br/>Authorization: Bearer eyJhbGci...
    Gateway-->>MissionGUI: {<br/>  connected: true,<br/>  airsim_ip: "10.0.0.5",<br/>  airsim_port: 41451,<br/>  vehicles: { "UAM1": { stage: 0, status: "idle" } }<br/>}
    Note over MissionGUI: 🖥️ LINK SETTINGS: IP=10.0.0.5, PORT=41451

    MissionGUI->>Gateway: GET /kada/odt/mission/192.168.0.102/sensors<br/>Authorization: Bearer eyJhbGci...
    Gateway-->>MissionGUI: {<br/>  "UAM1": {<br/>    altitude: 0, speed: 0, battery: 100,<br/>    latitude: 37.5407, longitude: 127.0016, heading: 0<br/>  }<br/>}
    Note over MissionGUI: 🖥️ TELEMETRY: UAM1/altitude=0, UAM1/speed=0, ...

    MissionGUI->>Gateway: GET /kada/odt/mission/192.168.0.102/logs<br/>Authorization: Bearer eyJhbGci...
    Gateway-->>MissionGUI: [<br/>  { i: 0, vehicle: "UAM1", message: "Connected to AirSim" }<br/>]
    Note over MissionGUI: 🖥️ CONSOLE: [UAM1] Connected to AirSim

    Note over MissionGUI: ── Start polling: setInterval(refresh, 1000) ──
```

### 4.3 START Mission Sequence

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant MissionGUI as 🖥️ Use Case GUI
    end

    box rgb(80, 40, 40) Backend
        participant Gateway as 🌐 Mission Gateway
        participant AirSim as 🌐 AirSim VM
    end

    User->>MissionGUI: Click "START (S0)"

    MissionGUI->>Gateway: POST /kada/odt/mission/192.168.0.102/start<br/>Authorization: Bearer eyJhbGci...<br/>Body: {}
    Gateway->>AirSim: Begin mission from Stage 0
    AirSim-->>Gateway: { status: "ok", mission_started: true }
    Gateway-->>MissionGUI: { status: "ok" }

    Note over MissionGUI: logPollingEnabled = true

    loop Every 1 second (setInterval)
        MissionGUI->>Gateway: GET .../192.168.0.102/status
        Gateway-->>MissionGUI: {<br/>  connected: true,<br/>  airsim_ip: "10.0.0.5",<br/>  airsim_port: 41451,<br/>  vehicles: {<br/>    "UAM1": { stage: 2, status: "cruising" }<br/>  }<br/>}
        Note over MissionGUI: 🖥️ LINK SETTINGS updated

        MissionGUI->>Gateway: GET .../192.168.0.102/sensors
        Gateway-->>MissionGUI: {<br/>  "UAM1": {<br/>    altitude: 150.3,<br/>    speed: 24.7,<br/>    battery: 87,<br/>    latitude: 37.5412,<br/>    longitude: 127.0023,<br/>    heading: 45.2<br/>  }<br/>}
        Note over MissionGUI: 🖥️ TELEMETRY table:<br/>UAM1/altitude → 150.3<br/>UAM1/speed → 24.7<br/>UAM1/battery → 87<br/>UAM1/latitude → 37.5412<br/>UAM1/longitude → 127.0023<br/>UAM1/heading → 45.2

        MissionGUI->>Gateway: GET .../192.168.0.102/logs
        Gateway-->>MissionGUI: [<br/>  { i: 0, vehicle: "UAM1", message: "Connected to AirSim" },<br/>  { i: 1, vehicle: "UAM1", message: "Taking off" },<br/>  { i: 2, vehicle: "UAM1", message: "Ascending to 150m" },<br/>  { i: 3, vehicle: "UAM1", message: "Waypoint 1 reached" },<br/>  { i: 4, vehicle: "UAM1", message: "Cruising at 150m" }<br/>]
        Note over MissionGUI: 🖥️ CONSOLE:<br/>[UAM1] Connected to AirSim<br/>[UAM1] Taking off<br/>[UAM1] Ascending to 150m<br/>[UAM1] Waypoint 1 reached<br/>[UAM1] Cruising at 150m
    end
```

### 4.4 Control Commands (PAUSE / RESUME / RESET)

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant MissionGUI as 🖥️ Use Case GUI
    end

    box rgb(80, 40, 40) Backend
        participant Gateway as 🌐 Mission Gateway
        participant AirSim as 🌐 AirSim
    end

    rect rgb(40, 60, 40)
        Note over User,AirSim: PAUSE
        User->>MissionGUI: Click "PAUSE / HOVER"
        MissionGUI->>Gateway: POST .../192.168.0.102/pause<br/>Authorization: Bearer eyJhbGci...<br/>Body: {}
        Gateway->>AirSim: Pause mission (hover in place)
        AirSim-->>Gateway: { status: "ok", paused: true }
        Gateway-->>MissionGUI: { status: "ok" }
        Note over MissionGUI: logPollingEnabled = true
    end

    rect rgb(40, 40, 60)
        Note over User,AirSim: RESUME
        User->>MissionGUI: Click "RESUME"
        MissionGUI->>Gateway: POST .../192.168.0.102/resume<br/>Authorization: Bearer eyJhbGci...<br/>Body: {}
        Gateway->>AirSim: Resume mission
        AirSim-->>Gateway: { status: "ok", resumed: true }
        Gateway-->>MissionGUI: { status: "ok" }
        Note over MissionGUI: logPollingEnabled = true
    end

    rect rgb(60, 40, 40)
        Note over User,AirSim: RESET
        User->>MissionGUI: Click "RESET UAMSIM"
        Note over MissionGUI: 🖥️ confirm("Reset AirSim?")
        
        alt User clicks Cancel
            Note over MissionGUI: No action
        else User clicks OK
            MissionGUI->>Gateway: POST .../192.168.0.102/reset<br/>Authorization: Bearer eyJhbGci...<br/>Body: {}
            Gateway->>AirSim: Reset world & mission state
            AirSim-->>Gateway: { status: "ok", reset: true }
            Gateway-->>MissionGUI: { status: "ok" }
            Note over MissionGUI: logPollingEnabled = false<br/>logs.value = []<br/>lastLogTs = 0<br/>🖥️ CONSOLE: cleared
        end
    end
```

### 4.5 DISCONNECT Sequence

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant MissionGUI as 🖥️ Use Case GUI
    end

    box rgb(80, 40, 40) Backend
        participant Gateway as 🌐 Mission Gateway
    end

    User->>MissionGUI: Click "DISCONNECT" (red)

    MissionGUI->>Gateway: POST .../192.168.0.102/disconnect<br/>Authorization: Bearer eyJhbGci...<br/>Body: {}
    Gateway-->>MissionGUI: { status: "ok", disconnected: true }

    Note over MissionGUI: clearInterval(timer) → polling stopped<br/><br/>status.value.connected = false<br/>sensors.value = {}<br/>logs.value = []<br/>lastLogId.value = -1

    Note over MissionGUI: 🖥️ GUI reset:<br/>• Header: "● CONNECTED" → "○ DISCONNECTED"<br/>• Button: red DISCONNECT → green CONNECT<br/>• TELEMETRY: "No sensor data"<br/>• CONSOLE: empty<br/>• COMMANDS: all buttons disabled
```

---

## 5. Phase 4: Operation Environment (Visualization) {#5-phase-4}

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant SidebarGUI as 🖥️ Sidebar GUI
        participant VisuGUI as 🖥️ Operation Environment GUI
    end

    box rgb(50, 50, 50) Internal Logic
        participant CfgStore as ⚙️ compConfigStore
        participant CompSvc as ⚙️ componentService
        participant AuthStore as ⚙️ authStore
        participant UrlStore as ⚙️ serviceUrlStore
    end

    box rgb(80, 40, 40) Backend
        participant Backend as 🌐 Platform API
    end

    User->>SidebarGUI: Click "Operation Environment"
    SidebarGUI->>SidebarGUI: router.push("/home/odt/visualization")
    Note over SidebarGUI: 🖥️ New tab created: "Environment"

    SidebarGUI->>VisuGUI: Component mounted

    Note over VisuGUI: serviceKey = route.meta.serviceKey = "visualization"<br/>🖥️ Show: "Connecting to Service..."

    VisuGUI->>CfgStore: getServiceConfig("visualization")
    CfgStore-->>VisuGUI: {<br/>  serviceKey: "visualization",<br/>  componentType: "VM_VNC",<br/>  productId: 1,<br/>  componentId: 201,<br/>  available: true,<br/>  vmIp: "192.168.0.101"<br/>}

    alt available === false
        Note over VisuGUI: 🖥️ Show "Coming Soon to DTAM." text
    else available === true
        VisuGUI->>CompSvc: openCompConn("visualization", 1, 201)

        CompSvc->>Backend: POST /api/comp/conn<br/>Authorization: Bearer eyJhbGci...<br/>Body: {<br/>  product_id: 1,<br/>  product_component_id: 201<br/>}

        Backend-->>CompSvc: {<br/>  status: 0,<br/>  data: {<br/>    serviceUrl: "http://192.168.0.101:6080/vnc.html?resize=remote",<br/>    component_type: "VM_VNC"<br/>  }<br/>}

        CompSvc->>AuthStore: authStore.access_token
        AuthStore-->>CompSvc: "eyJhbGci..."

        Note over CompSvc: Build final URL:<br/>baseUrl = "http://192.168.0.101:6080/vnc.html?resize=remote"<br/>finalUrl = baseUrl<br/>  + "&token=eyJhbGci..."<br/>  + "&_t=1711871234567"<br/>  + "&autoconnect=true"<br/>  + "&reconnect=true"

        CompSvc->>UrlStore: setService("visualization", {<br/>  type: "VM_VNC",<br/>  url: "http://192.168.0.101:6080/vnc.html?resize=remote&token=eyJhbGci...&_t=1711871234567&autoconnect=true&reconnect=true"<br/>})

        Note over VisuGUI: loading = false<br/>computed service = urlStore.getService("visualization")<br/>service.type === "VM_VNC"

        Note over VisuGUI: 🖥️ Render:<br/><iframe<br/>  src="http://192.168.0.101:6080/vnc.html?...&autoconnect=true"<br/>  class="vnc-iframe"<br/>/><br/><br/>→ noVNC client connects to AirSim VM<br/>→ Live simulator screen displayed
    end
```

### 5.1 Service Type → Rendering

| `component_type` | GUI renders | Purpose |
|------------------|-----------|---------|
| `VM_VNC` | `<iframe src="http://{vmIp}:6080/vnc.html?...">` | noVNC → AirSim remote screen |
| `UE_WEB` | `<iframe src="{ueStreamUrl}">` | Unreal Engine Pixel Streaming |
| Other / null | `<p>Coming Soon to DTAM.</p>` | Placeholder |

### 5.2 Situation Monitoring (Same Code, Different serviceKey)

```
Route: /home/odt/visualization → serviceKey = "visualization" → compConfigStore["visualization"] → VM at 192.168.0.101
Route: /home/odt/situation     → serviceKey = "situation"      → compConfigStore["situation"]      → VM at 192.168.0.103
```

---

## 6. Phase 5: Vertiport Customize {#6-phase-5}

```mermaid
sequenceDiagram
    actor User as 👤 User

    box rgb(30, 60, 90) GUI
        participant SidebarGUI as 🖥️ Sidebar GUI
        participant ToastGUI as 🖥️ Toast
        participant VertiGUI as 🖥️ Customize GUI
    end

    box rgb(50, 50, 50) Internal Logic
        participant Guard as ⚙️ odtMissionGuard
        participant VStore as ⚙️ vertiportStore
    end

    User->>SidebarGUI: Click "Customize"

    alt odtStore.initialConfig.mission === "simple"
        SidebarGUI->>ToastGUI: show({<br/>  type: "warning",<br/>  text: 'Current mission mode is SIMPLE. "Customize" is not available.'<br/>})
        Note over SidebarGUI: ❌ Navigation blocked
    else mission === "customize"
        SidebarGUI->>Guard: router.push("/home/odt/vertiport")
        Guard->>Guard: Check: odtStore.initialConfig.mission
        
        alt mission === "simple" (safety net)
            Guard->>SidebarGUI: next("/home/odt/configuration")
        else mission === "customize" ✅
            Guard->>VertiGUI: Allow → mount component
        end

        VertiGUI->>VStore: vertiportStore.vmIp
        VStore-->>VertiGUI: "192.168.0.104"

        alt vmIp exists
            Note over VertiGUI: vertiportUrl = computed:<br/>"http://kadaproduct.konkuk.ac.kr:2025/kada/odt/vertiport/192.168.0.104/"

            Note over VertiGUI: 🖥️ Render:<br/><iframe<br/>  src="http://kadaproduct.konkuk.ac.kr:2025/kada/odt/vertiport/192.168.0.104/"<br/>  class="vertiport-iframe"<br/>/>
        else vmIp is null
            Note over VertiGUI: 🖥️ Empty (v-if="vmIp" → false → no iframe)
        end
    end
```

> [!IMPORTANT]
> Unlike Operation Environment, the Customize GUI does **NOT** call `openCompConn()`. It builds the iframe URL directly using a **hardcoded host** (`kadaproduct.konkuk.ac.kr:2025`) + `vertiportStore.vmIp`.

---

## 7. State Machine & Guard System {#7-state-machine}

### 7.1 State Transitions

```mermaid
stateDiagram-v2
    [*] --> Unconfigured: App start

    Unconfigured --> ParametersSet: setInitialConfiguration({<br/>vehicle, city, mission, ai})
    note right of Unconfigured
        parametersCompleted: false
        runClicked: false
        isConfigurationReady: false
        All menus disabled except Configuration
    end note

    ParametersSet --> Ready: markRunClicked()
    note right of ParametersSet
        parametersCompleted: true
        runClicked: false
        isConfigurationReady: false
        Menus still disabled
    end note

    Ready --> Ready: Navigate / Execute
    note right of Ready
        parametersCompleted: true
        runClicked: true
        isConfigurationReady: true
        Menus enabled per mission mode
    end note

    Ready --> Unconfigured: odtStore.reset()
```

### 7.2 Triple Guard System

| Layer | Type | Trigger | Action |
|-------|------|---------|--------|
| **1** | 🖥️ Sidebar GUI | `!isConfigurationReady` or mission mode mismatch | Menu greyed out + warning toast on click |
| **2** | ⚙️ Route Guard | URL navigates to `/home/odt/vertiport` while `mission==="simple"` (or vice versa) | `next("/home/odt/configuration")` redirect |
| **3** | ⚙️ Component Watch | `odtStore.initialConfig.mission` changes while user is on incompatible page | `router.replace("/home/odt/configuration")` |

---

## 8. Real-time Data Polling {#8-polling}

```mermaid
graph TD
    subgraph "🖥️ Use Case GUI — Polling Cycle"
        CONNECT["CONNECT clicked"] --> START_POLL["startPolling()"]
        START_POLL --> INTERVAL["⏱️ setInterval(refresh, 1000)"]
        
        INTERVAL --> REFRESH["refresh()"]
        REFRESH --> STATUS["🌐 GET /{vmIp}/status"]
        STATUS --> CHECK{response.connected?}
        CHECK -->|false| SKIP[Skip sensors & logs]
        CHECK -->|true| SENSORS["🌐 GET /{vmIp}/sensors"]
        SENSORS --> LOGS["🌐 GET /{vmIp}/logs"]
        LOGS --> RENDER["🖥️ Update 3 GUI panels"]
        RENDER --> TIME["currentTime = new Date()"]
        TIME --> INTERVAL
        
        DISCONNECT["DISCONNECT clicked"] --> STOP["stopPolling()<br/>clearInterval(timer)"]
    end
```

---

## 9. Runtime Architecture — Parallel Tabs {#9-parallel}

```mermaid
graph LR
    subgraph "🌐 AirSim VM (Server-side)"
        SIM["Simulation Engine<br/>Mission continues running<br/>regardless of frontend tabs"]
    end

    subgraph "🖥️ Frontend (all tabs alive via v-show)"
        TAB1["🖥️ Use Case Tab<br/>1s polling: GET status/sensors/logs"]
        TAB2["🖥️ Operation Env Tab<br/>iframe: VNC to 192.168.0.101:6080"]
        TAB3["🖥️ Situation Tab<br/>iframe: VNC to 192.168.0.103:6080"]
    end

    SIM ---|"{ altitude: 150, speed: 25, ... }"| TAB1
    SIM ---|"VNC pixel stream"| TAB2
    SIM ---|"monitoring data stream"| TAB3
```

> [!NOTE]
> The mission **only stops** when the user clicks **PAUSE**, **RESET**, or **DISCONNECT**. Tab switching has zero effect on the running simulation.

---

## 10. GUI ↔ Source File Mapping

### 🖥️ GUI Screens

| GUI Screen | Source File | Role |
|------------|-----------|------|
| **Login GUI** | [LoginView.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/views/LoginView.vue) | Login form |
| **Home GUI** | [HomeView.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/views/HomeView.vue) | Layout shell |
| **Sidebar GUI** | [Sidebar.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/layout/Sidebar.vue) | Navigation |
| **Configuration GUI** | [InitialConfiguration.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/dtam/InitialConfiguration.vue) | 4 params + RUN |
| **Use Case GUI** | [MissionUpload.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/dtam/MissionUpload.vue) | AirSim control |
| **Operation Env GUI** | [OperationDigital.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/dtam/OperationDigital.vue) | VNC/UE iframe |
| **Situation GUI** | [OperationDigital.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/dtam/OperationDigital.vue) | Monitoring iframe |
| **Customize GUI** | [VertiportWrapper.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/dtam/VertiportWrapper.vue) | Vertiport iframe |
| **Toast** | [AppMessage.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/common/AppMessage.vue) | Alert messages |
| **Tab Bar** | [TabView.vue](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/components/TabView.vue) | Tab management |

### ⚙️ Internal Logic

| Module | Source File | Role |
|--------|-----------|------|
| **ODT State** | [odtStore.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/stores/odtStore.js) | Ready flags |
| **Mission VM** | [missionStore.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/stores/missionStore.js) | vmIp state |
| **Mission API** | [mission.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/api/mission.js) | 9 API functions |
| **Service Connector** | [componentService.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/services/componentService.js) | iframe URL builder |
| **Route Guard** | [odtMissionGuard.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/router/guards/odtMissionGuard.js) | Route protection |
| **Menu Logic** | [useSidebarMenus.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/composables/useSidebarMenus.js) | Dynamic disabled |
| **Menu Data** | [menuConfig.js](file:///c:/Users/HJW/Documents/Dev/ODT/DTAMPlatform/kada-platform-web-frontend-main/src/data/menuConfig.js) | Menu tree |
