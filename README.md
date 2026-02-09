# Simulation Data Interface API

이 프로젝트는 시뮬레이션 제어 및 설정을 위한 **API 인터페이스 정의서**입니다.
효율적인 협업과 관리를 위해 여러개의 YAML 파일로 모듈화되어 있습니다.

This project defines the API interface for simulation control and configuration.
It is modularized into multiple YAML files for efficient collaboration and management.

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

### 3. 파일 구조 및 수정 방법
*   **`simulation_api.yaml`**: 메인 진입점 파일입니다. 전체 구조를 정의하고 하위 파일들을 참조(`$ref`)합니다.
*   **`paths/`**: API 경로(Path)별 정의가 모여 있습니다.
    *   `1_initial_setting.yaml`: 초기 설정 관련 API
    *   `2_execution.yaml`: 실행 제어 관련 API
    *   `3_event_propagation.yaml`: 이벤트 및 전파 관련 API
*   **`components/schemas/`**: 데이터 모델(Schema) 정의가 모여 있습니다.
    *   `vehicle.yaml`, `environment.yaml` 등 객체별로 분리되어 있습니다.

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

### 3. File Structure & Modification
*   **`simulation_api.yaml`**: The main entry point file. It defines the overall structure and references sub-files using `$ref`.
*   **`paths/`**: Contains definitions for API paths.
    *   `1_initial_setting.yaml`: APIs related to initialization.
    *   `2_execution.yaml`: APIs for execution control.
    *   `3_event_propagation.yaml`: APIs for event handling.
*   **`components/schemas/`**: Contains definitions for Data Schemas.
    *   Files are split by object type (e.g., `vehicle.yaml`, `environment.yaml`).
