# 리눅스용 CodexBar

사용량 및 지출 창과 설정 창을 따로 제공하는 Qt 6 데스크톱 앱으로, 선택적인 시스템
트레이 아이콘과 런처 항목을 함께 설치합니다. 공급자 조회와 인증은 Swift로 작성된
`codexbar` CLI가 담당하고, 데스크톱 앱은 폴링·설정·알림과 데스크톱 어댑터용 전용
로컬 소켓을 담당합니다. HTTP 서버는 필요하지 않습니다.

## 릴리스 아카이브 설치

데스크톱 아카이브는 별도의 CodexBarCLI 아카이브와 함께 x86_64 및 ARM64용으로
배포되며, 각각 `.sha256` 파일이 따라옵니다. 데스크톱은 시스템 Qt를 사용하고,
릴리스 바이너리는 glibc 2.39 이상과 Qt 6.4 이상을 요구합니다. Ubuntu 24.04와
Debian 13은 이 기준을 충족합니다. 그보다 오래된 배포판은 소스 빌드가 필요합니다.
Enterprise Linux 9(Rocky, AlmaLinux, RHEL 9.x)는 glibc 2.34를 제공하므로 배포된
데스크톱 아카이브가 실행되지 않습니다. [빌드 및 설치](#빌드-및-설치)에 따라 소스에서
빌드하십시오. EPEL의 Qt 6.6은 Qt 기준을 충족합니다. 배포된 glibc CLI 아카이브도
같은 2.39 기준으로 빌드되므로, EL9에서는 정적 링크된 musl CLI 아카이브를 쓰거나
CLI를 소스에서 빌드하십시오. 데스크톱은 CLI를 하위 프로세스로 실행하므로 musl CLI와
glibc 데스크톱을 함께 써도 문제없습니다. musl CLI 아카이브는 Alpine 같은 배포판에서
CLI만 사용할 때를 위한 것이며, 이를 쓴다고 glibc 데스크톱 아카이브가 musl에서
동작하게 되지는 않습니다.

### 런타임 패키지

아카이브를 내려받기 전에 배포판에 맞는 패키지를 설치하십시오. 아래 목록에는 내려받기
도구와 Python 설치 스크립트 실행에 필요한 것이 포함되어 있습니다. 개발 패키지는 소스
빌드에만 필요합니다.

Arch 계열(Omarchy 포함):

```sh
sudo pacman -S --needed curl python qt6-base qt6-declarative qt6-svg qt6-wayland
```

Fedora:

```sh
sudo dnf install curl python3 qt6-qtbase qt6-qtdeclarative qt6-qtsvg qt6-qtwayland
```

Enterprise Linux 9(Rocky, AlmaLinux, RHEL 9.x). Qt 6는 기본 저장소에 없으므로 EPEL을
먼저 활성화하십시오:

```sh
sudo dnf install curl python3 epel-release
sudo dnf install qt6-qtbase qt6-qtdeclarative qt6-qtsvg qt6-qtwayland
```

Qt Quick Controls와 Fusion 스타일은 Arch에서는 `qt6-declarative`, Fedora와 Enterprise
Linux 9에서는 `qt6-qtdeclarative`에 들어 있습니다. Debian과 Ubuntu는 QML 모듈을
WorkerScript를 포함해 별도 패키지로 나눠 제공합니다.

Ubuntu 24.04(Noble):

```sh
sudo apt update
sudo apt install curl python3 qml6-module-qtquick qml6-module-qtquick-controls \
  qml6-module-qtquick-layouts qml6-module-qtquick-templates qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript libqt6widgets6t64 libqt6svg6 qt6-wayland
```

Debian 13(Trixie):

```sh
sudo apt update
sudo apt install curl python3 qml6-module-qtquick qml6-module-qtquick-controls \
  qml6-module-qtquick-layouts qml6-module-qtquick-templates qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript libqt6widgets6 libqt6svg6 qt6-wayland
```

### 내려받기, 검증, 설치

아래 블록을 `sh` 또는 `bash`에서 실행하십시오(fish를 쓴다면 먼저 `bash`로 진입).
최신 정식 GitHub 릴리스를 골라 두 아카이브를 내려받고, 내려받기나 체크섬이 하나라도
실패하면 중단합니다. 서브셸에서 실행되므로 현재 디렉터리와 셸 옵션은 그대로 유지되고,
매번 새 임시 디렉터리를 사용합니다. CLI와 그 리소스 번들은 `~/.local/lib/codexbar-cli`
아래에 함께 보관됩니다.

```sh
(
set -eu
arch=$(uname -m)
case "$arch" in x86_64|aarch64) ;; *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; esac
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"
api=https://api.github.com/repos/steipete/CodexBar/releases/latest
curl -fsSL "$api" -o release.json
version=$(python3 -c 'import json; print(json.load(open("release.json"))["tag_name"])')
base="https://github.com/steipete/CodexBar/releases/download/$version"
cli="CodexBarCLI-$version-linux-$arch.tar.gz"
desktop="CodexBarDesktop-$version-linux-$arch.tar.gz"
for archive in "$cli" "$desktop"; do
  curl -fSL "$base/$archive" -o "$archive"
  curl -fSL "$base/$archive.sha256" -o "$archive.sha256"
  sha256sum -c "$archive.sha256"
done
# Neither archive is extracted until both checksums have passed.
cli_dir="$HOME/.local/lib/codexbar-cli"
mkdir -p "$cli_dir" "$HOME/.local/bin"
tar -xzf "$cli" -C "$cli_dir"
ln -sfn "$cli_dir/codexbar" "$HOME/.local/bin/codexbar"
"$HOME/.local/bin/codexbar" --version
tar -xzf "$desktop"
cd "${desktop%.tar.gz}"
python3 Integrations/Linux/install.py --cli "$HOME/.local/bin/codexbar"
)
```

Omarchy에서만 설치 명령에 `--omarchy`를 추가하고, 로그인 시 자동 시작을 끄려면
`--no-autostart`를 추가하십시오. 그런 다음 설치된 앱을 엽니다:

```sh
~/.local/bin/codexbar-linux --settings
```

전체 경로 없이 `codexbar`를 실행하려면 `~/.local/bin`을 PATH에 추가하십시오. 이
심링크는 CLI 설치 디렉터리를 가리키므로, 업그레이드할 때 `VERSION`과
`CodexBar_CodexBarCore.bundle`을 그 위치에 함께 유지해야 합니다. Homebrew와 AUR의
`codexbar-cli` 패키지도 CLI 설치 방법이며, 이미 CLI가 있다면 그 절대 경로를 데스크톱
설치 스크립트에 넘기십시오.

인증 없는 GitHub API가 요청 제한에 걸리면
[GitHub Releases](https://github.com/steipete/CodexBar/releases/latest)에서 해당하는
네 개 파일을 직접 내려받거나
`gh release download --repo steipete/CodexBar --pattern 'CodexBar*-linux-x86_64.tar.gz*'`
를 사용하십시오(ARM64는 `aarch64`로 대체). 빈 디렉터리에서 두 `.sha256` 검증을 모두
통과시킨 뒤에 아카이브를 풀고, 위 설치 명령을 내려받은 파일 이름으로 실행하십시오.

업그레이드하려면 CodexBar를 종료하고 설치 블록을 다시 실행한 뒤 앱을 다시 여십시오.
기존 설정과 "자동 시작 해제" 상태는 유지됩니다. 아직 데스크톱 자동 업데이터나 배포판
저장소 패키지는 없습니다. 일반 CI 아티팩트는 미리보기이며 릴리스가 아닙니다. 제거
방법은 [검증 및 제거](#검증-및-제거)를 참고하십시오.

## 빌드 및 설치

리눅스, C++17, make, qmake6, 그리고 Qt 6.4 이상이 필요합니다(Base, Declarative/Quick,
Quick Controls, Network, D-Bus, SVG 아이콘 지원). 빌드 과정에서 Qt Linguist 도구의
`lrelease`를 실행해 번역 카탈로그를 컴파일합니다. Wayland 세션에서는 Qt의 Wayland
플러그인을 설치하십시오. Arch/Omarchy에서는 `base-devel qt6-base qt6-declarative
qt6-svg qt6-wayland qt6-tools`입니다. Enterprise Linux 9(Rocky, AlmaLinux, RHEL 9.x)
에서는 EPEL을 활성화하고 `gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel
qt6-qtsvg-devel qt6-qtwayland-devel qt6-qttools-devel`을 설치하십시오. EL9의 시스템
GCC 11이면 C++17 요구사항을 충족합니다. `PATH`에 리눅스용 Homebrew 툴체인이 있으면
그쪽 링커와 `libgomp`가 EL9보다 높은 glibc를 요구해 링크가 실패하므로,
`PATH=/usr/local/bin:/usr/bin:/bin`으로 시스템 툴체인을 쓰도록 빌드하십시오.

저장소 검사는 EL9에서 `./Scripts/lint.sh lint-linux`로 실행합니다. 기본 `lint` 대상은
macOS 전용 단계를 추가로 실행합니다. 한 가지 제약은 SwiftLint입니다. 배포되는 리눅스
바이너리가 glibc 2.38 이상을 요구하므로 EL9에서는 실행되지 않으며, 다른 환경에서
돌리거나 소스에서 빌드해야 합니다. SwiftFormat, oxlint, 이식 가능한 검사들은 모두
정상 실행됩니다.

체크아웃한 저장소에서는 `make install` 한 번으로 전체 과정이 끝납니다. CLI와 Qt
데스크톱을 빌드하고 둘 다 현재 사용자 계정에 설치한 뒤 런처 항목까지 작성합니다.

```sh
make install
~/.local/bin/codexbar-linux --settings
```

CLI는 리소스 번들과 함께 `~/.local/lib/codexbar`에 설치되고 `~/.local/bin/codexbar`로
연결되며, 데스크톱은 `~/.local/bin/codexbar-linux`에 설치됩니다. 설치 스크립트는 경로를
설정에 기록하기 전에 두 이름 모두를 통해 번들이 로드되는지 검증합니다. 다른 위치에
설치하려면 `PREFIX`를 지정하고, 설치 스크립트 옵션은 `INSTALL_ARGS`로 전달하십시오:

```sh
make install PREFIX=/opt/codexbar INSTALL_ARGS=--no-autostart
```

Swift 툴체인은 `PATH`에 있으면 그대로 사용하고, 없으면 `/opt/swift`와 swiftly의 기본
위치를 자동으로 찾습니다. 다른 곳에 두었다면 `SWIFT_TOOLCHAIN`에 `usr/bin/swift`를
품은 디렉터리를 지정하십시오. EL9에는 Swift 패키지가 없으므로 공식 UBI 9 빌드를
설치하면 됩니다:

```sh
curl -fL https://download.swift.org/swift-6.2-release/ubi9/swift-6.2-RELEASE/swift-6.2-RELEASE-ubi9.tar.gz \
  | sudo tar xz -C /opt --one-top-level=swift --strip-components=1
```

이미 보유한 CLI를 그대로 쓰거나 CLI를 빌드하지 않고 설치하려면 설치 스크립트를 직접
실행하십시오. CLI의 리소스 번들을 실행 파일 옆에 유지하고, 먼저 공급자 CLI로 인증을
마쳐야 합니다. 저장소 루트에서:

```sh
mkdir -p .local/linux-build
cd .local/linux-build
qmake6 ../../Integrations/Linux/codexbar-linux.pro
make -j4
cd ../..
python3 Integrations/Linux/install.py --cli /absolute/path/to/codexbar
~/.local/bin/codexbar-linux --settings
```

간결한 Omarchy 어댑터까지 설치하려면 `--omarchy`를, 로그인 시 자동 시작을 끄려면
`--no-autostart`를 추가하십시오. 설치는 사용자 단위로 이뤄지고 기존 설정을 보존하며,
변경 전에 기존 환경설정을 백업합니다. 재설치해도 "자동 시작 해제" 상태는 유지됩니다.
체크아웃 없이 릴리스 아카이브만으로도 설치할 수 있습니다:

```sh
# Inside an extracted CodexBarDesktop archive:
python3 Integrations/Linux/install.py --cli /absolute/path/to/codexbar --omarchy
```

로컬 빌드로 아카이브를 만들려면
`python3 Integrations/Linux/package.py --version 0.1.0`을 실행하십시오. 아카이브에는
앱, 설치 스크립트, 아이콘, 어댑터, 라이선스, 설명서만 들어갑니다. 호환되는 시스템
Qt/glibc 라이브러리와 별도로 설치한 CodexBar CLI가 필요하며, AppImage나 배포판 고유
패키지가 아닙니다. 지원하려는 배포판 중 가장 오래된 것에서 빌드하십시오.

Qt는 Wayland와 X11을 모두 지원합니다. 트레이는 Qt의 데스크톱 통합(StatusNotifier 또는
X11 트레이 호스트)을 사용합니다. 트레이가 없어도 런처와 창은 정상 동작합니다. Omarchy
설치 시에는 중복 트레이를 기본적으로 숨깁니다.

GNOME은 3.26 이후 자체 트레이 호스트를 제공하지 않으므로, GNOME 세션에서는
`org.kde.StatusNotifierWatcher`를 제공하는 확장이 필요합니다.
[AppIndicator and KStatusNotifierItem Support](https://extensions.gnome.org/extension/615/appindicator-support/)
를 설치하고 활성화하십시오. Enterprise Linux 9에서는 EPEL의
`gnome-shell-extension-appindicator` 패키지로 제공됩니다. 이 확장이 없으면 Qt가 트레이
항목을 등록하지 못해 아이콘이 나타나지 않습니다. 이때 앱은 stderr에 한 번 알리고 계속
실행되므로, 런처 항목이나 `codexbar-linux --usage`로 창을 열거나 설정에서 트레이를
끄십시오.

트레이 메뉴에는 현재 할당량이 함께 표시됩니다. GNOME의 트레이 호스트는 좌클릭 한 번에
메뉴만 열고 `Activate`는 더블클릭에서만 호출하므로, 한 번의 클릭으로 사용량을 바로 읽을
수 있도록 공급자·구간·남은 비율·재설정 시각을 메뉴 위쪽에 넣었습니다. 창을 열려면 메뉴의
"사용량 및 지출…"을 고르거나 트레이 아이콘을 더블클릭하십시오. `ItemIsMenu`가 거짓일 때
셸이 더블클릭 여부를 기다리므로 메뉴가 약 0.4초 뒤에 열리는데, 이 속성은 Qt의
`QDBusTrayIcon`에 고정되어 있어 앱에서 바꿀 수 없습니다.

### 패널에 한 줄로 표시

`--status-line`은 실행 중인 앱에서 현재 사용량을 한 줄로 출력합니다. IPC로 값을 읽어오기만
하므로 공급자를 새로 조회하지 않아 짧은 주기로 호출해도 부담이 없습니다.

```sh
codexbar-linux --status-line
# Codex: 11% (1W:6D 3H)  Claude: 55% (5H:3H 20M)/10% (1W:4D 21H)
```

퍼센트는 설정의 할당량 표시(남은 양/사용한 양)를 그대로 따릅니다. 앱이 실행 중이 아니면
표준 출력은 비고 종료 코드 1을 반환하므로, 패널 위젯에는 빈 칸으로 나타납니다.

GNOME 상단 바에 이 줄을 직접 띄우려면 명령 출력을 패널에 그려주는 확장이 필요합니다.
[Executor](https://extensions.gnome.org/extension/2932/executor/)가 GNOME 40을 지원합니다.
설치한 뒤 Executor 설정에서 명령을 `codexbar-linux --status-line`, 주기를 30초 정도로
지정하면 됩니다.

트레이 아이콘 자체에 텍스트를 넣는 방법은 쓸 수 없습니다. StatusNotifierItem에는
`XAyatanaLabel` 확장 속성이 있지만, AppIndicator 확장의
`interfaces-xml/StatusNotifierItem.xml`에서 해당 속성과 `XAyatanaNewLabel` 시그널이 주석
처리되어 있어 GDBusProxy가 노출하지 않습니다. 앱이 속성을 내보내도 읽히지 않습니다.
아이콘 픽스맵에 글자를 그리는 우회로도 막혀 있는데, 확장이 아이콘 폭과 높이를 같은 값으로
강제해 가로로 긴 이미지가 찌그러집니다.

같은 줄을 waybar, polybar, tmux 상태줄 등에서도 그대로 쓸 수 있습니다.

Rocky Linux 9.8(GNOME Shell 40.10, X11 세션, EPEL의 Qt 6.6.2)에서 확인한 결과, 소스
빌드가 정상 실행되고 창이 렌더링되며 AppIndicator 확장을 활성화하면 앱이 셸에
StatusNotifierItem을 등록합니다. GNOME Wayland 세션, KDE, 그 밖의 컴포지터는 아직 직접
호환성 시험이 필요합니다.

## 언어

데스크톱은 세션 로케일을 따르며 한국어 카탈로그(`i18n/codexbar_ko.ts`)를 포함합니다.
그 외 로케일에서는 영어 원본 문자열을 그대로 사용합니다. 따라서 한국어 세션
(`LANG=ko_KR.UTF-8`)에서는 별도 설정 없이 한국어로 시작하고,
`LANG=C ./codexbar-linux --usage`로 영어를 강제할 수 있습니다. 카탈로그는 빌드 시
`lrelease`가 컴파일해 바이너리에 포함하므로, 패키징된 아카이브도 별도 설치 단계 없이
번역을 함께 가져갑니다.

창·메뉴·설정 문자열은 QML과 C++ 소스에서 옵니다. `Shared/`의 공용 모델이 만들어내는
문자열(할당량 구간 레이블, 재설정 카운트다운, 비용 출처, 알림 문구)은 `Usage`와
`Notifications` 컨텍스트 아래 같은 카탈로그로 해석되므로, UI의 양쪽이 함께 번역됩니다.
오프라인 Node 테스트처럼 순수 JS로 쓰는 쪽은 번역기를 설치하지 않고 영어 기본값을
유지합니다.

언어를 추가하려면 한국어 카탈로그를 `i18n/codexbar_<code>.ts`로 복사하고
`codexbar-linux.pro`의 `TRANSLATIONS`에 추가한 뒤, 항목을 번역하고 다시 빌드하십시오.
추출 가능한 항목은 다음 명령으로 갱신합니다:
`lupdate main.cpp DesktopController.cpp DesktopController.h qml -ts i18n/codexbar_<code>.ts`.
`Usage`와 `Notifications` 컨텍스트는 모델이 런타임 조회로 번역하여 `lupdate`가 인식하지
못하므로 수작업으로 관리합니다.

## 창과 동작

설정은 일반, 공급자, 고급으로 나뉘어 있습니다. 공급자/소스 선택, 계정 인덱스, 전체 계정
표시, 신원 표시 여부, 새로 고침 주기, 상태, 로컬 지출, 알림, 트레이 표시를 제어합니다.
계정 선택기는 표시할 사용량을 고르는 것이며 공급자 CLI의 로그인을 바꾸지 않습니다.
`custom`을 선택하면 설치된 CLI의 카탈로그에서 공급자를 골라 순서를 위아래로 조정할 수
있습니다. 그 정렬된 목록만 순차적으로 조회하며, 실패한 공급자는 이전 결과를 유지하고
정상인 공급자만 갱신됩니다. 계정 선택기는 단일 공급자 조회에 적용되고, custom 목록은 각
공급자의 기본 계정을 사용합니다.

로그인과 로그아웃은 `xdg-terminal-exec`(선택적 의존성)으로 기본 터미널에서 Codex 또는
Claude CLI를 엽니다. 로그아웃은 확인을 거칩니다. 앱은 터미널 출력을 읽지 않으며 자격
증명을 저장하지 않습니다. 흐름을 마친 뒤 사용량을 새로 고치십시오. 이 기능은 활성 CLI
세션을 관리하는 것이며, 브라우저 가져오기·토큰 계정 편집·Mac 관리 프로필은 여기에
구현되어 있지 않습니다.

사용량 화면에는 사용했거나 남은 할당량, 재설정 시각, 사용 속도, 크레딧, 상태, 공급자
공통 세부 정보, 차트가 표시됩니다. 알 수 없는 값은 알 수 없음으로 남습니다. 신원은
기본적으로 숨겨집니다. 표시 환경설정으로 재설정 카운트다운, 절대 시각, 사용 속도 표시
여부, 할당량 부족 색상을 조정합니다. 트레이에는 첫 번째 표시 공급자의 할당량 미터 두
개를 보여주거나 고정 아이콘을 쓸 수 있습니다. 알 수 없는 미터는 빈 트랙으로 남습니다.
툴팁은 표시 중인 공급자와 데이터가 오래되었는지를 알려줍니다. Omarchy 팝업도 할당량과
재설정 환경설정을 공유합니다.

로그인 시 시작 설정은 설정 창에서 즉시 적용됩니다. 그 밖의 환경설정은 저장을 눌러야
적용됩니다. Omarchy로 설치하면 테마 따라가기가 기본 활성화되며,
`$XDG_STATE_HOME/omarchy/current/theme/colors.toml`(보통 `~/.local/state`)에서 색상을
읽어 10초마다 확인합니다. 테마가 없거나 불완전하면 Qt 시스템 팔레트로 되돌아갑니다. 이
설정은 어떤 데스크톱에서도 끌 수 있습니다. 로컬 지출은 이 컴퓨터의 계정 전반에 걸친
Codex/Claude 기록을 달력일 기준과 30일 추정치, 토큰 구성, 출처, 커버리지와 함께
보여줍니다. 추정치는 청구서가 아닙니다. 지출 화면을 열면 할당량 폴링과 별개로 스캔하며
5분 캐시를 사용합니다. 새로 고침을 누르면 새로 스캔합니다.

할당량 폴링은 기본 5분입니다. 창을 열 때 새로 고침 옵션을 켜면 해당 창이 열릴 때
사용량을 갱신합니다. 새로 고침과 Ctrl+R은 선택한 탭만 독립적으로 갱신합니다. Ctrl+,는
설정을 열고 Ctrl+Q는 종료합니다. 각 스트림 내에서 조회가 겹치지 않고, 60초가 지나면
중단하며, 출력은 8 MiB로 제한합니다. 새로 고침이 실패하면 이전 결과를 유지하고 오래됨
표시를 붙입니다. 선택을 바꾸면 진행 중이던 이전 결과는 버립니다. 선택적 알림은
데스크톱의 D-Bus 알림 서비스를 통해 남은 할당량 임계값 통과, 관측된 재설정, 서비스 상태
전환을 알립니다. 시작 시점, 공급자 오류, 계정이 모호한 다중 계정 결과에서는 알리지
않습니다.

창을 닫아도 백엔드는 계속 실행됩니다. 사용량 창이나 트레이에서 종료하거나
`codexbar-linux --quit`을 사용하십시오. 다시 실행하면 기존 프로세스의 창이 열립니다.
환경설정은 `$XDG_CONFIG_HOME/codexbar/linux.json`(보통 `~/.config`)에 사용자 전용 권한으로
원자적으로 기록됩니다. 잘못된 파일은 절대 덮어쓰지 않으므로, 파일을 고치거나 삭제한 뒤
다시 시작하십시오. 인증 정보는 CLI의 저장소에 그대로 남습니다.

## 어댑터 인터페이스

```sh
codexbar-linux --background
codexbar-linux --usage
codexbar-linux --settings
codexbar-linux --spending
codexbar-linux --refresh
codexbar-linux --snapshot
codexbar-linux --configure '{"provider":"both","refreshSeconds":300}'
codexbar-linux --autostart status # also enable or disable
codexbar-linux --quit
```

snapshot, refresh, configure, autostart, quit은 실행 중인 프로세스가 있어야 합니다. UI
명령은 필요하면 프로세스를 시작합니다. IPC 클라이언트는 GUI 플러그인을 로드하지
않습니다. `--cli PATH`와 `--no-tray`는 새 인스턴스를 시작할 때 적용됩니다. 같은 사용자
전용 로컬 소켓은 `$XDG_RUNTIME_DIR/codexbar-linux/desktop.sock`에 있으며, 요청과 응답은
줄바꿈으로 끝나는 JSON입니다. 스냅샷 스키마 버전 1에는 간결한 공급자 구간, 요약, 갱신
시각, 진행/오래됨/오류 상태, 지출 사용 가능 여부가 들어갑니다. 계정 신원, CLI 경로,
자격 증명 설정은 포함하지 않습니다. 어댑터를 위한 표시 값과 재설정 문구는 포함합니다.
어댑터는 `schemaVersion`을 확인하고, 모르는 필드를 허용하며, 백엔드가 없으면 사용 불가로
처리해야 합니다.

## 검증 및 제거

```sh
node --test Integrations/Omarchy/test.mjs Integrations/Omarchy/notifications.test.mjs
python3 Integrations/Omarchy/test_install.py
python3 Integrations/Linux/tests/test_desktop.py
python3 Integrations/Linux/tests/test_package.py
# Account-action test: qmake6 Integrations/Linux/tests/accounts.pro in a build directory,
# then make and run ./tst_accounts. Uses a fake terminal and fake provider CLIs.
```

런타임 테스트는 HOME/XDG 경로를 격리하고 가짜 CLI와 오프스크린 Qt를 사용합니다.
DISPLAY에 접근할 수 있는 세션에서 X11을 검증하려면 `CODEXBAR_TEST_PLATFORM=xcb`를
설정하십시오.

제거하려면 CodexBar를 종료한 뒤 `~/.local/bin/codexbar-linux`,
`$XDG_DATA_HOME/applications/com.steipete.CodexBar.desktop`,
`$XDG_DATA_HOME/icons/hicolor/scalable/apps/codexbar.svg`,
`$XDG_CONFIG_HOME/autostart/com.steipete.CodexBar.desktop`을 삭제하십시오.
기본 데이터/설정 디렉터리는 `~/.local/share`와 `~/.config`입니다. 나중에 다시 설치할
것을 대비해 환경설정과 백업은 남겨 두어도 됩니다. `make install`로 설치했다면
`~/.local/lib/codexbar`(`PREFIX`를 지정했다면 해당 경로 아래)와
`~/.local/bin/codexbar` 심링크도 함께 삭제하십시오.
