# Simulation Data Interface API

이 프로젝트는 시뮬레이션 제어 및 설정을 위한 **API 인터페이스 정의서**입니다.
효율적인 협업과 관리를 위해 **개별 파일별로 완전히 분리된 구조**를 가지고 있습니다.

This project defines the API interface for simulation control and configuration.
It uses a **fully decoupled structure** where each file acts as a standalone unit for efficient collaboration.

---

## 🇰🇷 [Korean] 실행 가이드

### 1. 사전 요구사항
*   **Python**: 로컬 서버 실행을 위해 Python이 설치되어 있어야 합니다.
    *   터미널에서 `python --version` 명령어로 설치 여부를 확인할 수 있습니다.

### 2. 실행 방법
1.  이 폴더에 있는 **`start_server.bat`** 파일을 더블 클릭하여 실행합니다.
2.  명령 프롬프트(까만 창)가 열리고 로컬 웹 서버가 시작됩니다.
3.  자동으로 웹 브라우저가 실행되며 **Swagger UI** 화면이 표시됩니다.
    *   만약 브라우저가 열리지 않는다면 주소창에 `http://localhost:8000/interface.html` 을 입력하세요.

### 3. 파일 구조 및 수정 방법 (중요)
*   **`simulation_api.yaml`**: 메인 진입점. 단순히 하위 파일들을 나열하는 역할만 합니다.
*   **`paths/`**: 실제 작업 공간입니다.
    *   `1.1.1.yaml`, `2.0.1.yaml` 등 **ID 번호**에 맞는 파일을 찾아서 수정하시면 됩니다.
    *   각 파일 안에 Request/Response 데이터 모델(Schema)이 **모두 포함(Inline)**되어 있습니다.
    *   따라서 다른 파일을 열어볼 필요 없이, **해당 파일 하나만 작업**하면 됩니다.

---

## 🇺🇸 [English] Project Guide

### 1. Prerequisites
*   **Python**: Creating a local server requires Python installed.
    *   You can check the installation with `python --version` in your terminal.

### 2. How to Run
1.  Double-click the **`start_server.bat`** file in this folder.
2.  A command prompt window will open, and the local web server will start.
3.  Your default web browser will automatically open the **Swagger UI** page.
    *   If the browser doesn't open automatically, type `http://localhost:8000/interface.html` in the address bar.

### 3. File Structure & Modification (Important)
*   **`simulation_api.yaml`**: Main entry point. Primarily lists the sub-files.
*   **`paths/`**: This is your workspace.
    *   Locate the file matching your **ID Number** (e.g., `1.1.1.yaml`, `2.0.1.yaml`).
    *   All data models (Schemas) are **Inlined** directly within each file.
    *   You can work on **that single file** without needing to check other external files.
