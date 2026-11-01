<div align="center">

<img src="assets/app-icon.png" width="100" height="100" alt="Pixel Pin icon" />

# Pixel Pin

**화면의 색을 고르고, 고정하고, 복사하세요.**

Windows를 위한 작고 깔끔한 픽셀 컬러 피커. Made by [TeamHJD](https://teamhjd.com/).

[![Release](https://img.shields.io/github/v/release/Team-HJD-21/Pixel-Pin?style=flat-square&color=547CF0)](https://github.com/Team-HJD-21/Pixel-Pin/releases/latest)
![Platform](https://img.shields.io/badge/Windows-10%20%2F%2011-202B40?style=flat-square)
![Architecture](https://img.shields.io/badge/x64-Desktop-202B40?style=flat-square)
![Built with](https://img.shields.io/badge/.NET-10%20%7C%20WPF-7856C8?style=flat-square)

[**다운로드**](https://github.com/Team-HJD-21/Pixel-Pin/releases/latest) · [사용 방법](#사용-방법) · [개발 및 빌드](#개발-및-빌드) · [문제 제보](https://github.com/Team-HJD-21/Pixel-Pin/issues)

<br />

<img src="assets/preview.png" width="440" alt="Pixel Pin: 픽셀 확대경, HEX 복사 버튼, RGB 값, 최근 색상 기록" />

<sub>화면 구성 예시 · 샘플 색상 #547CF0</sub>

</div>

## 딱 필요한 만큼

| 기능 | 설명 |
| :--- | :--- |
| **실시간 픽셀 측정** | 커서 아래의 색을 HEX와 RGB로 표시합니다. |
| **클릭으로 고정 / 재개** | 한 번 클릭해서 고정하고, 다시 클릭해서 측정을 이어갑니다. |
| **픽셀 확대경** | 주변 17 × 17 픽셀을 확대하고 측정하는 픽셀을 중앙에 표시합니다. |
| **색상이 보이는 복사 버튼** | 배경은 측정한 색으로, 글자는 대비가 높은 검정 또는 흰색으로 바뀝니다. |
| **최근 색상 8개** | 복사한 색을 저장하고, 클릭해서 다시 복사합니다. |
| **항상 위에** | 다른 창을 보면서도 측정값을 확인할 수 있습니다. |

계정도, 설치 과정도 없습니다. 앱 자체는 네트워크에 연결하지 않습니다. 하단 제작자 링크를 누를 때만 기본 브라우저에서 TeamHJD 사이트가 열립니다.

## 다운로드 및 실행

1. [최신 릴리스](https://github.com/Team-HJD-21/Pixel-Pin/releases/latest)에서 **`Pixel-Pin-v1.0.0-win-x64.zip`**을 받습니다.
2. 원하는 폴더에 압축을 풉니다.
3. **`PixelPin.exe`**를 실행합니다.

**지원 환경:** Windows 10 / 11, x64. 공식 배포본에는 .NET 런타임이 포함되어 있어 별도 설치가 필요하지 않습니다.

## 사용 방법

**① 고르기** → 앱 바깥으로 커서를 옮겨 원하는 픽셀을 찾습니다.

**② 고정하기** → 화면을 왼쪽 클릭합니다. 색상과 확대경이 고정됩니다.

**③ 복사하기** → `HEX 복사`를 누릅니다. `#RRGGBB` 형식으로 클립보드에 복사됩니다.

**④ 다시 고르기** → 화면을 다시 클릭하거나 `실시간 측정 재개`를 누릅니다.

앱 안의 복사 버튼이나 최근 색상을 누르면 고정 / 재개가 전환되지 않습니다. 실시간 측정 중 앱 안으로 커서를 옮기면 마지막 측정값이 유지됩니다.

| 단축키 | 동작 |
| :--- | :--- |
| `Ctrl` + `Shift` + `C` | 현재 색상의 HEX 코드 복사 |
| `Ctrl` + `Shift` + `Space` | 색상 고정 / 실시간 측정 재개 |

단축키는 다른 앱을 사용하는 동안에도 동작합니다. 다른 프로그램과 충돌하면 Pixel Pin 안의 버튼을 사용할 수 있습니다.

> 화면 클릭은 원래 프로그램에도 전달됩니다. 버튼이나 링크를 누르지 않고 색만 고정하려면 `Ctrl + Shift + Space`를 사용하세요.

## 색상과 기록

- **측정 기준:** 커서가 있는 물리적 픽셀 1개. 값은 Windows 화면 캡처에서 읽은 8비트 RGB입니다.
- **모니터:** 여러 모니터, 음수 화면 좌표, 모니터별 배율을 처리하도록 구성되어 있습니다.
- **색상 관리:** 원본 파일의 색상 프로필을 분석하지 않습니다. HDR이나 화면 색상 처리에 따라 원본 파일의 RGB 값과 다를 수 있습니다.
- **캡처 제한:** 보안 화면 또는 캡처가 차단된 콘텐츠는 측정할 수 없습니다.
- **저장 위치:** 최근 복사한 색상은 `%LOCALAPPDATA%\PixelPin\history.json`에 저장됩니다. 이전 Digital Color Meter 버전의 기록은 첫 실행 때 이어받습니다.

## 개발 및 빌드

**.NET SDK 10**이 설치된 Windows에서 빌드합니다. WPF와 Windows API를 사용하며 외부 NuGet 패키지에 의존하지 않습니다.

```powershell
git clone https://github.com/Team-HJD-21/Pixel-Pin.git
cd Pixel-Pin
dotnet run --project PixelPin.csproj
```

로컬 실행용 빌드:

```powershell
dotnet publish PixelPin.csproj -c Release --self-contained false -o dist
```

위 빌드는 .NET Desktop Runtime 10이 필요합니다. 배포할 때 실행 파일 옆의 DLL과 JSON 파일도 함께 보관하세요.

런타임을 포함한 단일 실행 파일:

```powershell
dotnet publish PixelPin.csproj -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:EnableCompressionInSingleFile=true -p:DebugType=None -o artifacts/win-x64
```

아이콘은 `assets/app-icon.svg`를 원본으로 관리합니다. `assets/generate-icon.ps1`로 16–256px의 여러 크기를 담은 Windows ICO를 다시 만들 수 있습니다.

## 프로젝트

버그나 사용 중 불편한 점은 [Issues](https://github.com/Team-HJD-21/Pixel-Pin/issues)에 남겨주세요.

<div align="center">

<br />

**[Made by TeamHJD](https://teamhjd.com/)**

<sub>© 2026 TeamHJD. All rights reserved.</sub>

</div>
