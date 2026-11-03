# Arch Linux PKGBUILD for QuixiDesk — native Rust (tao/wry) AI desktop workspace.
# Upstream: https://github.com/QuixiAI/QuixiDesk  (MIT)
#
# Personal build. No maintainer contact is embedded here on purpose; send upstream
# issues to the QuixiDesk repository, packaging issues as comments.
#
# Upstream QuixiDesk is Eric Hartford's (QuixiAI, MIT). This package is NOT built on top of any
# other packaging repository — it patches the upstream release tarball directly, and the series is
# self-contained: 0001 is the Linux platform layer, the rest are this build's own additions.
#
# AI author: Nora, an AI.   Vibe coder: volkdude85 <volkdude85@users.noreply.github.com>
# Brokenly vibe coded — with sovereignty in mind. Every claim then measured.
#
# Builds from source. The upstream prebuilt Linux tarball is also usable, but a
# source build links against the distro's own webkit2gtk/gtk, which is what you
# want on Arch (rolling libs vs. a tarball pinned against Ubuntu 26.04).

pkgname=quixidesk-custom
pkgver=3.6556.12
pkgrel=55
pkgdesc="Native Rust desktop workspace for AI — pluggable cloud and local providers, MCP tools, projects, schedules"
arch=('x86_64')
# GCC LTO must be off. makepkg appends -flto=auto to CFLAGS/LDFLAGS by default;
# ring 0.17.14 compiles ~30 perlasm objects through the cc crate, and those
# become GCC LTO IR that rustc's link line never asks the linker plugin to
# reduce. The objects are present and nm lists every symbol, yet the link dies
# on undefined ring_core_0_17_14__* — the exact failure that cost this build
# several passes. options=('!lto') stops makepkg from adding the flag at all.
options=('!lto')
url="https://github.com/QuixiAI/QuixiDesk"
license=('MIT')
# Every entry here is a DT_NEEDED of the shipped binaries, mapped to its owner.
# pango / cairo / gdk-pixbuf2 / libsoup3 / glib2 are linked DIRECTLY by QuixiDesk;
# listing only gtk3 relied on them arriving transitively, which is wrong per Arch
# packaging policy and breaks on a system where gtk3's dependency set differs.
# Verified with `namcap` and by reading DT_NEEDED off the binary, not guessed.
depends=(
  'glibc'
  'gcc-libs'
  'gtk3'
  'webkit2gtk-4.1'
  'glib2'
  'pango'
  'cairo'
  'gdk-pixbuf2'
  'libsoup3'
  'openssl'
  'hicolor-icon-theme'
  'dbus'
  'libpulse'
  'bash'
)
makedepends=(
  'cargo'
  'rust'
  'pkgconf'
  'librsvg'
)
optdepends=(
  'git: git integration for workspace features (not linked; invoked by the app when present)'
  'spectacle: screen capture on KDE Plasma'
  'grim: screen capture on wlroots (Sway, Hyprland)'
  'gnome-screenshot: screen capture on GNOME'
  'imagemagick: capture fallback (import) where no desktop tool exists'
  'kscreen: display enumeration on KDE (kscreen-doctor)'
  'xorg-xrandr: display enumeration on X11'
  'wlr-randr: display enumeration on wlroots'
  'wl-clipboard: clipboard read/write on Wayland'
  'xclip: clipboard read/write on X11'
  'xsel: clipboard fallback on X11'
  'ydotool: ALL input synthesis - typing, key combos, mouse. Requires ydotoold running.'
  'kdialog: file and folder pickers on KDE'
  'zenity: file and folder pickers on GNOME and other desktops'
  'kio: application launching via kioclient6'
  'xdotool: cursor position, and X11 window operations'
  'ghidra: reverse-engineering skill — decompile a binary headless and read the C'
  'gnome-keyring: Secret Service backend on non-KDE desktops'
  'kwallet: Secret Service backend on KDE Plasma'
)
provides=('quixidesk')
conflicts=('quixidesk-bin' 'quixidesk-git')
source=(
  "0053-journal.patch"
  "${pkgname}-${pkgver}.tar.gz::https://github.com/QuixiAI/QuixiDesk/archive/refs/tags/v${pkgver}.tar.gz"
  "ydotoold.openrc"
  "0001-linux-support.patch"
  "0002-local-overrides.patch"
  "0003-condense-fallback.patch"
  "0004-skills.patch"
  "0005-headless.patch"
  "0009-linux-fixes-keybindings.patch"
  "0010-rustify-keybindings.patch"
  "0011-test-portability.patch"
  "0012-kde-scenario-pinning.patch"
  "0006-memory.patch"
  "0007-voice.patch"
  "0008-voice-local.patch"
  "0013-artix-love.patch"
  "0014-hyprland-omarchy.patch"
  "0015-browser-driving-skill.patch"
  "0016-test-portability-containers.patch"
  "0017-cli-usage.patch"
  "0018-themes-and-fonts.patch"
  "0019-reverse-engineering-skill.patch"
  "0020-voice-over-ipc.patch"
  "0021-dictation-referenceerror.patch"
  "0022-appearance-is-a-setting.patch"
  "0023-persona-file.patch"
  "0024-his-colours-and-his-words.patch"
  "0025-custom-colours-stay-in-custom.patch"
  "0026-retro-contrast.patch"
  "0027-resize-glass-boxes.patch"
  "0028-its-your-edition.patch"
  "0029-cron-jobs-explained.patch"
  "0030-plural-sections-open.patch"
  "0031-sidebar-tree.patch"
  "0032-branches-have-leaves.patch"
  "0033-less-white.patch"
  "0034-cursor-test-measures-the-move.patch"
  "0035-no-mac-tooling.patch"
  "0036-two-libraries-and-about.patch"
  "0037-privacy-is-paths.patch"
  "0038-transparency-and-background.patch"
  "0039-daemons.patch"
  "0040-sidebar-restyle.patch"
  "0041-links-open-in-brave.patch"
  "0042-rail-and-column.patch"
  "0043-automation-bridge.patch"
  "0044-shipped-persona.patch"
  "0045-browser-is-brave.patch"
  "0046-router-knows-daemons.patch"
  "0047-dot-and-label-agree.patch"
  "0048-socket-liveness.patch"
  "0049-mcp-platform-adapters.patch"
  "0050-context-button-earns-its-place.patch"
  "0051-with-skill.patch"
  "0052-tool-descriptions-know-the-platform.patch"
  "0056-home-headline.patch"
  0055-browser-choice.patch
  0056-engine-tests-carry-their-own-weight.patch
  0057-ollama-cloud-and-first-run.patch
  0058-first-contact.patch
  0059-newcomer-or-old-hand.patch
  0060-model-order-and-a-reachable-button.patch
  0061-memory-palace-setup.patch
  0062-memory-palace-explained.patch
  0063-encryption-choices.patch
  0064-pick-your-model.patch
  0065-visuals-audio-and-your-drives.patch
  0066-welcome-and-a-memory-folder-that-survives.patch
  0067-stt-tts-conversation.patch
  0068-ask-later.patch
  0069-lowercase.patch
  0070-doors.patch
  0071-aide.patch
  0072-desktop-pickers-and-documents.patch
  0073-cancel-is-not-a-choice.patch
  0074-opacity-voice-and-tasks.patch
  0075-provider-choice-and-the-task-widget.patch
  0076-approvals-voice-and-a-real-reset.patch
  0077-mic-and-speaker-are-switches.patch
  0078-a-key-where-the-question-is-asked.patch
  0079-the-microphone-is-actually-opened.patch
  0080-dictation-is-a-toggle-with-a-level-meter.patch
  0081-dictation-state-survives-a-repaint.patch
  0082-no-words-left-behind.patch
  0083-ctrl-f-and-no-second-conversation-mode.patch
  0084-personas-are-a-settings-section.patch
  0085-the-greeting-is-sup.patch
  0086-sup-by-default-sup-bitches-in-his-own-theme.patch
  0087-volkdude85-edition-and-a-plain-placeholder.patch
  0088-the-register-is-earned.patch
  0089-a-dev-key-and-a-door-that-means-zero.patch
  0090-nora-introduces-herself.patch
  0091-no-apple-shaped-capabilities-on-linux.patch
)
sha256sums=(
  'af4af51b2a4cc303627587e7c5f28739083ed09f339cd84a896045b4801a01f6'
  '0d447af0ebe5a9aa447e45cffe183c077647637994eb71ec22a29a179742484e'
  '6e777c4292128ea71db0234295c53cdd6fed235dc66ded68e53b906b26b6a61d'
  'a866886e26aea29b04e3c96483f07a9917e821559e416da03d6c630b85e71172'
  'fbe57cbee5e0cfd523a469382a227f55432a2494225f637098ce635eb06a0e91'
  'df6db5a447c0949ff3efb2a031a6f9814d4f4be6205d44acf829970c266078ea'
  '2b7811586ad063ad7e567b0b76c42f0b0e11ac5fec96af543b4e4d594b9c1119'
  '91a87092804d8209a67bf189d7a189439ec7fd3b6d6946a97d94288a2119a045'
  '780223f1c89e646688ac10a36c5c084bea727f46882aa8b9289dd83fd47de62a'
  '699cf11a5ac749a7563852f92c4b229da257b843dd3dcd1145be2d585896de91'
  'bc60f83eb492d1fcda4e5e26ef1998095586f088d9c8cc8ea4c34d01054d735b'
  'f2d9c341719739a046d922c5cdfd580e4eb14a8f9926caf5db7209dc6593a0ed'
  '07a3f17e7b4bc48a1796d59ce16cc03b7221bd74a19799a06dd1374f031628a2'
  'f01e250b689494cca9b42c3c4246e350738f4e1018ba70ecfdfddb5ef45c36a9'
  'e75ec05aaa360f41ce0e761c046594bda17a765f975fcad82448c1c0eda1bc32'
  '8f1460096977344bba9177d232ac3c43783dfc24763c978e84d80dc917a501bc'
  '48b49483972b25daaa046373c8f287107f0c736b2521136f1129a93a1c65cb43'
  'f36b89860957f43f6b6c9876b3467a4b4c5c7c8e04cb4b2807e24c16e2e03875'
  '1ac38960fc2cf1bce0bac6a6987edc7ec94bb1072ed18317320ea2d3a1e09426'
  'ab5ea50a1943e4068a3fbedbc6a7998cc99260a23c694ecb81867abea2e32fe9'
  '7901d532a6a287ae6ceccae92a28c4b7ed26e94242653da5b0c7d5e56ba0a5db'
  'cb543ffa08df3c1831b581c2c71ecb7bd731e7bde928e126edd91145552122df'
  '4e3339fa0544455a9a9e35bf1622cd7a24371ed34000e837dc5dc37dc3c0ef2d'
  'ac06b372232fe585738bc3458f44d77f207eaa89c490e80b5bf4240cccbda319'
  '7a9371be24fbdb3a16304a6926f003b57b20d6d702ba6356a2a8828e66253a40'
  '733f9cb38f4790f5ca6a979cb4601e1f3c1629c6bd3619520fce296c9abb1b1d'
  '0cf44f237b814af27b9cda8b2712bf66e615c9242847e0e86fda0a7225de2aa0'
  '497eb3976991f6867433e5b2d7211eeaa203afb9dd98877fcee350b5f02adc09'
  'bf45cb1ec062e66be385f28497ad5a9e93a2cb15ffad84d72e08f5c6857631a6'
  '01a39af1decf3dfde35ee60df329fcb641316188bd897eb783d78a8bd440455c'
  '88a139b0197a707c5c59e83554c7feff7a7958fe0dea37a4fc751a2ad5de766f'
  'd21931167a56aa7eb154d782143efa7ec8ef20f3385cf67fcc109252e52cc6ef'
  '77c84b4789675355f79eb053dccbcd47ace83ab916a80afe8d17e98279128e68'
  'e48623ad5db67ab7a1ee7246c78f23a8160c82552df76d840c63919604e341cb'
  '3c03b2caf9e586876bb8a3cd68cbb8e59cbb3ad145b6fb94a5cb9ed4a45bc74a'
  'cba6080a59f3e4f62402b45e7c37129d4ee173d5e29ea02e76e33c0da795bf80'
  '735ed0f2082a0bff1eee53132fbe31531cad8430673d10ab946bb419a3d893cc'
  'a6dab707446307af20d3d15a76056aeb2e9df67172f7c1613e3cd10a265538b4'
  '269b4a745d43a5c442ce546f90dde64458a5eef6481894cb0a73fa1884409b60'
  'c26c26680c56772e0984355b561336019bfb1b6f0870e57b682c9863bfc35b9a'
  '9028b862650fe6956a6900d625975ec90f3f4ac809563b86b7baa268e5309240'
  'f841131116b50752594dd098dec1d3fee6a42714f42249740a464915fe0a8591'
  'f55e3a6fc8a65ba73dc0999a266845b655f7301f31291c3311b480d241f3d779'
  '9eeb6ab5108c7c4f9d6808a23ef6d3f6883f9ebebe848f66441bf20e2705cd29'
  '9ed90b994c87c5e15227a0f880a343a286bc40ec3b44ee6b73d9935b14e9a6a1'
  'f475d5190c04c9b983c19722dbef03b3077ba02c1d5a8ca638bf7768cabeb653'
  '5797ae1fd38784245b5a0bd2d753af3f69f3480a1a36396fb8604afcd15b139a'
  'd1cd63f978a98028cd9bf5eba05fa32b71899a0c2e6a70ffe5e0c315a2663cce'
  '84d04591e7a9b53a1513c85f6c05784136cdebb3e17226177e8a95879d5b40a0'
  '3751e2225a979046fbffa2aeeded6cb3c807020a568e34f427da61e341141bd4'
  '18adfa1a5b4a0bf97643b050f9f4c43f5f15068321c813698e88c6837409b6a2'
  'b56b49fe0d9b364cb5deaf01110c432ca04a1e5c843437fddcc2ade42b3a9254'
  '5a01bbe389e129dd4ee40ae2d12782bddae9f6d0c750d7467a40120852abd1cc'
  '9cb8e388cd141788e6f8e6df3c974ed10d2a776ef6ed9c5b04524b4dd9a1270b'
  'd8c81e161561e55950779153e7b2d9f0752b7da0e0c7f56caa663649647d1a87'
  'b7dfe7875519de48e4ab55f72008d6c53ed35cf8cdeb385414ea0e802de37d97'
  'eaa1811e9b5cc3a2dad7b2e2a31f66bef47f79b73cda4ce4565189ca1820e58d'
  '506ca2739a04df26515b96f5e9b4a90d279f435ca83f316c984654726fd6f803'
  '92d88fa21948a6def843457b3e623a698feab43a8718ab76e49f702fcef204fb'
  'f1e8845381fbce034781c6953e0f4b40d809fa3b382462b315e1b9a14212c1d3'
  '6b3a83a502f8a551a03e017427509a02db069d7b5da37d2178d09ccd95f03417'
  '5724ed0b2a6bf8edc4d0776347050aac8a4f44e3c37553a0e1b2cb06712ccb0d'
  '9175793521febb93cf129483621debd74bb8f369bf3aefbe6ac65d9c6c8bfbb8'
  '60dde1b85f7737c29783b49b43d770e5609ef34f2d2598d3c39f099470f43a98'
  'cc53a583ac6a6af203075c210d080abb7f95fb8e0e03d34bc8cf5561fbab5389'
  '7dfbd143f3cd6df00c7168b06efb7502d254212c1014fc76973c7a9ff29e5d9e'
  '1e1694eff9d175d636cd92a725742e16ccb62a16a2d10e136384f1d45bf5667c'
  '1b46d0cfd5c5c02af273f3abbd289c0f6ad5765a4936feb5fcbb15055349bde8'
  '1d26534b0a5642e7aa4f3776a7a41be53904ea5772dde9f478615a76d13e9d37'
  '869711499fb97de268cc7c38d2960ef16295543ee0a6964dbad1010a83e9f88c'
  '226b80cb43a8049d3b8b731e7959dbabb71f661a058d784f4bc0b12fc24990af'
  '1d2e02a9dbd6e1edf61b0ac07f54967aa8018d021cd8830943d55e4433dd569d'
  '2a3b213bce9e1d30bbbbb6da84b175a5cb79c7f448fadcb76cf96b137345142c'
  'b013a82d1fc14e9e25577d9b80d2596baf112e5563cdb48105a03449d06c8c32'
  'e01534de901f57622d7e9463789315a5d3accfaab968a334ff04d388526ec2c6'
  '94a36daf1877e749f7dea37f88deb17b5c9f41c8830aedf699ebc019b62c6f2a'
  'daf57a2de473a23993031639c28b54168b2c77c17879060c0490c96874be7ff4'
  '86a7c612f60d4a538d2e90df1743c3b558ae0fd303ef2a4efa02badcbaa5fd8b'
  'a90f53ac3466de75c67a1be0b36bc0725d60ae78c2059e0e9d1a0cf248de8f17'
  'ac07c9dfabf0978e0317d54b89dc7f163ec0b1321d9920fc225e6e834257b2e2'
  '02d660759bf16ea5d25271f574460d4b93f9133f96d573e0fb9f825738df5e3b'
  'f1f3221f79c6a42f4f8310a0b8fe5c90e2e6a5accb20ba65dbe2580726393325'
  '56f0cf710be1412ad6a0d360ab7f5237a98f555ddae02627274796f2195efc74'
  '58f63448fe6fd0d0a8980e9693baeb683c13b547e0d757f3027a716ea5e2f4c8'
  '95c0db024cad4c7f241f0f250804ec7268c94d0231511f1a7aad5232d21667c1'
  'a230ed090394ac1c433fe4307c3fbdb0945f511b886e64d83ca77bc90790f1e9'
  'a94c706e583d162c9f37f61558e7222e4831ad1b91b73ffe553f8c45cdcd94c5'
  '804268b0e90400df7128b28f9bcd7a21da619bd0a4eafdab745d254d0bcebb35'
  '3340025cc1a6c1a0b720a077a9a49c1674695eb66b8c5ed313230b6b73a4a9b7'
  '3732f04cc3d01165955a1615da8ffcf18f4530445a7a8401bf582ff89b282e6a'
  '590e71894bdb74a5da2c6cb51cbdbdcc4dbb8d140bad48831b90a5d38dcc71f5'
  'c74e088f03930815bc9c23cc445b63760f4f7aebdb246bdb1855c72a14294ff0'
  '4a63477fe7c59e9eff8b176c586d6704735c7b9dad759f6f944c7f0fce506fae'
)

_libdir="/usr/lib/${pkgname}"

prepare() {
  cd "${srcdir}/QuixiDesk-${pkgver}"
  # Persistent cargo cache: a CARGO_HOME inside $srcdir is wiped by `makepkg -C`,
  # which forces a full ~300 MB registry re-download on every clean build.
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  # NOTE: `cargo fetch` deliberately does NOT run here. It used to, and that was a bug — the patches
  # below add `png = "0.17"` to Cargo.toml, so fetching before them downloads the dependency set of the
  # UNPATCHED tree. build() then runs with CARGO_NET_OFFLINE=true and fails with
  # `no matching package named png found`. It only ever worked on machines whose cargo cache already
  # had png from an earlier build; a clean machine — a new user, a CI runner, Eric — hits it immediately.
  # The fetch now runs at the END of prepare(), after every patch has been applied.
  # Clear every file the patches CREATE. A second build in the same tree otherwise
  # fails with "already exists! Skipping patch" and aborts prepare().
  rm -f crates/quixi-platform/src/linux.rs \
            crates/quixi-platform/examples/compat_matrix.rs \
            crates/quixi-platform/examples/platform_probe.rs \
        crates/quixi-platform/NOTES-linux.md \
        crates/quixi-platform/tests/linux_computer_use.rs \
        crates/quixi-platform/tests/capture_modes.rs \
        crates/quixi-platform/tests/bug_hunt.rs \
        crates/quixi-platform/tests/stress.rs \
        crates/quixi-platform/tests/input_synthesis.rs \
        crates/quixi-platform/tests/compat.rs \
        crates/quixi-platform/tests/compat_desktops.rs \
        crates/quixi-platform/tests/launch.rs \
        crates/quixi-platform/tests/common/mod.rs \
        crates/quixi-engine/tests/skills_stress.rs \
        crates/quixi-engine/src/bin/quixi.rs \
        crates/quixi-engine/src/palace.rs \
        crates/quixi-engine/src/voice.rs \
        resources/bundled-skills-extracted/reverse-engineering/SKILL.md \
        resources/bundled-skills-extracted/with/SKILL.md \
        resources/bundled-skills-extracted/reverse-engineering/ghidra_dump.py \
        resources/bundled-skills-extracted/reverse-engineering/DumpDecomp.java

  # 1) Linux platform layer: the ComputerUse surface upstream leaves as silent
  #    no-ops outside macOS, plus the KWin ScreenShot2 fast path.
  patch -Np1 -i "${srcdir}/0001-linux-support.patch"

  # 2) Local behaviour overrides - NOT for publication.
  patch -Np1 -i "${srcdir}/0002-local-overrides.patch"

  # 3) Context condensation degrades to a mechanical handoff instead of killing the run
  #    when the summariser returns nothing usable.
  patch -Np1 -i "${srcdir}/0003-condense-fallback.patch"

  # 4) Skills become something the model can actually use: an index it can search and a
  #    LoadSkill tool, over the bundled tree and any ~/.hermes profile skill trees.
  patch -Np1 -i "${srcdir}/0004-skills.patch"

  # 5) The headless `quixi` driver - same engine, no window.
  patch -Np1 -i "${srcdir}/0005-headless.patch"

  # 6) Fixes found by cross-desktop testing, plus keyboard-shortcut discovery:
  #    - is_wayland() treated an EMPTY WAYLAND_DISPLAY as Wayland, silently disabling
  #      cursor_position, active_output and window_under_cursor on a real X11 session
  #    - YDOTOOL_SOCKET was honoured even when the socket did not exist, so input died with an
  #      empty error on boxes using the distro ydotoold (/run/ydotoold.socket)
  #    - list_keybindings()/find_keybinding(): normalized shortcuts across KDE, GNOME and XFCE
  #    - input_path_check(): proves the input path with a zero-displacement injection
  patch -Np1 -i "${srcdir}/0009-linux-fixes-keybindings.patch"

  # 7) Less process spawning in the keybinding readers:
  #    - GNOME: one `gsettings list-recursively` instead of 25 `gsettings get` calls (539ms -> 14ms)
  #    - XFCE:  in-process org.xfce.Xfconf.GetAllProperties over D-Bus, no xfconf-query process
  patch -Np1 -i "${srcdir}/0010-rustify-keybindings.patch"

  # 8) Test portability: the suites asserted the author's machine rather than the contract —
  #    a hardcoded "wayland" session, a "> 50 KB means the screenshot worked" size heuristic, and a
  #    simulated desktop that inherited the runner's session type. They pass on any machine now.
  patch -Np1 -i "${srcdir}/0011-test-portability.patch"

  # 9) Pin the KDE fall-through scenario to X11: `import` is an X11 tool, so asserting it is KDE's
  #    next backend after a failing spectacle only holds for an X11 session.
  patch -Np1 -i "${srcdir}/0012-kde-scenario-pinning.patch"

  # 6) MemPalace-style memory: wings/rooms/drawers on disk, ranked recall, and a scope gate
  #    keyed on whether the active provider is local or remote.
  patch -Np1 -i "${srcdir}/0006-memory.patch"

  # 7) Voice without the webview: TTS and STT over HTTP or a command, with a silence lead-in so
  #    the first word is not clipped on Bluetooth sinks.
  patch -Np1 -i "${srcdir}/0007-voice.patch"

  # 8) Local voice defaults: this machine's Kokoro voice and its local Whisper service, plus the
  #    quixi --say / --transcript commands.
  patch -Np1 -i "${srcdir}/0008-voice-local.patch"

  # Fetch AFTER the patches, so the dependency set being fetched is the one the build will actually
  # use. This is the difference between a cold machine building successfully and failing on `png`.
  # Artix Love — "I don't want to run it, but I want to love it."
  # The suite could not pass in a container because a test asserted that a mouse move makes
  # the pointer position known without first checking this host can move a mouse at all.
  patch -Np1 -i "${srcdir}/0013-artix-love.patch"

  # Hyprland and Omarchy. Hyprland publishes the cursor position, which is the one thing
  # the Wayland path could not answer; Omarchy is Hyprland with Quickshell on top.
  patch -Np1 -i "${srcdir}/0014-hyprland-omarchy.patch"

  # Browser driving as a shipped skill: Brave over CDP, Firefox over BiDi, curl last. Without this
  # line the patch is downloaded and checksummed but never applied, so the skill silently does not
  # ship — which is exactly what happened here until the chain was inspected rather than assumed.
  patch -Np1 -i "${srcdir}/0015-browser-driving-skill.patch"

  # Two tests that were still asserting the host: "more than ten applications installed" (a
  # container ships none) and "the capture error names spectacle or grim" (a host with neither
  # names the backends it does have). Found by running the suite in an archlinux container.
  patch -Np1 -i "${srcdir}/0016-test-portability-containers.patch"

  # The usage text advertised five of the fourteen commands; the memory and voice commands were
  # accepted but invisible. Grouped by what they cost, with the real arity for each.
  patch -Np1 -i "${srcdir}/0017-cli-usage.patch"

  # matrix / amber / ice / custom themes, plus font family and text size. CSS and JS only:
  # upstream already had the variables and the data-theme switch, it only ever defined two looks.
  patch -Np1 -i "${srcdir}/0018-themes-and-fonts.patch"

  # Reverse-engineering skill: Ghidra headless driven by a wrapper that keeps the decompiled C and
  # drops the JVM/relocation noise. Ghidra is an optdepend, not a requirement.
  patch -Np1 -i "${srcdir}/0019-reverse-engineering-skill.patch"

  # Voice over the EIPC bridge: the UI called it over HTTP on a custom scheme, which WebKitGTK
  # blocks, so Dictate fell through to a macOS-only "use system dictation" dialog.
  patch -Np1 -i "${srcdir}/0020-voice-over-ipc.patch"

  # startEngineDictation referenced textarea/node from another scope: ReferenceError on every
  # Dictate click on Linux, swallowed by the event dispatcher.
  patch -Np1 -i "${srcdir}/0021-dictation-referenceerror.patch"

  # Appearance as backend state; sliders where the native colour dialog committed on first touch.
  patch -Np1 -i "${srcdir}/0022-appearance-is-a-setting.patch"

  # Persona as a file the user owns, named in the top bar.
  patch -Np1 -i "${srcdir}/0023-persona-file.patch"

  # His palette, read off his Hermes window, and his two strings.
  patch -Np1 -i "${srcdir}/0024-his-colours-and-his-words.patch"

  # A custom colour must not override every theme chosen after it.
  patch -Np1 -i "${srcdir}/0025-custom-colours-stay-in-custom.patch"

  # Retro: readable secondary text, visible borders, green heading.
  patch -Np1 -i "${srcdir}/0026-retro-contrast.patch"

  # Resizable sidebar, translucent panels, boxed surfaces.
  patch -Np1 -i "${srcdir}/0027-resize-glass-boxes.patch"

  # His words: New instance, VolkDude's QuixiDesk, Cron jobs, and one tools search.
  patch -Np1 -i "${srcdir}/0028-its-your-edition.patch"

  # Cron jobs: say what they are, show the expression, explain an empty list.
  patch -Np1 -i "${srcdir}/0029-cron-jobs-explained.patch"

  # Plural sidebar sections open; the composer says something human.
  patch -Np1 -i "${srcdir}/0030-plural-sections-open.patch"

  # Sidebar tree: caret gutter, whole-row targets, populated Tools & skills.
  patch -Np1 -i "${srcdir}/0031-sidebar-tree.patch"

  # An expansion must always resolve to a row.
  patch -Np1 -i "${srcdir}/0032-branches-have-leaves.patch"

  # Retro text tone: less white, greener, same contrast.
  patch -Np1 -i "${srcdir}/0033-less-white.patch"

  # The cursor test asserts the move result, not the machine it runs on.
  patch -Np1 -i "${srcdir}/0034-cursor-test-measures-the-move.patch"

  # No macOS-only MCP servers, and no office-document skills nobody here uses.
  patch -Np1 -i "${srcdir}/0035-no-mac-tooling.patch"

  # Two skill libraries with two searches; About says whose edition this is.
  patch -Np1 -i "${srcdir}/0036-two-libraries-and-about.patch"

  # Privacy & data: real paths, real counts, real files.
  patch -Np1 -i "${srcdir}/0037-privacy-is-paths.patch"

  # Panel opacity slider, and an optional drawn background.
  patch -Np1 -i "${srcdir}/0038-transparency-and-background.patch"

  # Daemons page: live systemd + port checks, horned icon.
  patch -Np1 -i "${srcdir}/0039-daemons.patch"

  # Sidebar rhythm: accent rail, active row, section labels.
  patch -Np1 -i "${srcdir}/0040-sidebar-restyle.patch"

  # External links resolve Brave first, honouring QUIXI_BROWSER.
  patch -Np1 -i "${srcdir}/0041-links-open-in-brave.patch"

  # Active-nav rail actually fires; Daemons joins the caret column.
  patch -Np1 -i "${srcdir}/0042-rail-and-column.patch"

  # window.__quixi_automation__: click/type/navigate without the system pointer.
  patch -Np1 -i "${srcdir}/0043-automation-bridge.patch"

  # Bundle the public Nora persona and seed it as a file the user owns.
  patch -Np1 -i "${srcdir}/0044-shipped-persona.patch"

  # Browser pane hands pages to Brave (--app window); no fake in-app rendering.
  patch -Np1 -i "${srcdir}/0045-browser-is-brave.patch"

  # navigate() allow-list: the Daemons page is reachable.
  patch -Np1 -i "${srcdir}/0046-router-knows-daemons.patch"

  # Daemons row: the light and the label come from one decision.
  patch -Np1 -i "${srcdir}/0047-dot-and-label-agree.patch"
  # A socket file is not a running daemon: probe by connecting, and gate the stale-socket case.
  patch -Np1 -i "${srcdir}/0048-socket-liveness.patch"

  # MCP is not macOS-only: sweep a leftover applescript adapter out of an existing config.
  patch -Np1 -i "${srcdir}/0049-mcp-platform-adapters.patch"

  # The context button only when an external server exists to browse.
  patch -Np1 -i "${srcdir}/0050-context-button-earns-its-place.patch"

  # With, shipped as a skill: the compiler's own language, taught to the agent.
  patch -Np1 -i "${srcdir}/0051-with-skill.patch"

  # The tool catalogue stops describing a Mac to a Linux agent.
  patch -Np1 -i "${srcdir}/0052-tool-descriptions-know-the-platform.patch"

  # Journal: one file per session, appended in place. Input at send, reply on completion.
  patch -Np1 -i "${srcdir}/0053-journal.patch"

  # The line under the greeting, said the way it actually gets said.
  patch -Np1 -i "${srcdir}/0056-home-headline.patch"

  patch -Np1 -i "${srcdir}/0055-browser-choice.patch"
  patch -Np1 -i "${srcdir}/0056-engine-tests-carry-their-own-weight.patch"
  patch -Np1 -i "${srcdir}/0057-ollama-cloud-and-first-run.patch"
  patch -Np1 -i "${srcdir}/0058-first-contact.patch"
  patch -Np1 -i "${srcdir}/0059-newcomer-or-old-hand.patch"
  patch -Np1 -i "${srcdir}/0060-model-order-and-a-reachable-button.patch"
  patch -Np1 -i "${srcdir}/0061-memory-palace-setup.patch"
  patch -Np1 -i "${srcdir}/0062-memory-palace-explained.patch"
  patch -Np1 -i "${srcdir}/0063-encryption-choices.patch"
  patch -Np1 -i "${srcdir}/0064-pick-your-model.patch"
  patch -Np1 -i "${srcdir}/0065-visuals-audio-and-your-drives.patch"
  patch -Np1 -i "${srcdir}/0066-welcome-and-a-memory-folder-that-survives.patch"
  patch -Np1 -i "${srcdir}/0067-stt-tts-conversation.patch"
  patch -Np1 -i "${srcdir}/0068-ask-later.patch"
  patch -Np1 -i "${srcdir}/0069-lowercase.patch"
  patch -Np1 -i "${srcdir}/0070-doors.patch"
  patch -Np1 -i "${srcdir}/0071-aide.patch"
  patch -Np1 -i "${srcdir}/0072-desktop-pickers-and-documents.patch"
  patch -Np1 -i "${srcdir}/0073-cancel-is-not-a-choice.patch"

  # One dial that tells the truth: the window is opaque at 100%, the compositor does the blending
  # below it, onboarding only appears on an install with no history, and there is a task list.
  patch -Np1 -i "${srcdir}/0074-opacity-voice-and-tasks.patch"

  # A clean install knows it is clean: nothing pre-selected, the cloud fields actually hidden, the
  # task list in the conversation, and an onboarding gate that needs an explicit yes to skip.
  patch -Np1 -i "${srcdir}/0075-provider-choice-and-the-task-widget.patch"

  # Approvals that explain themselves and can act on history, a microphone and a speaker with
  # device lists, a reading column you can widen, and a dev door that clears credentials.
  patch -Np1 -i "${srcdir}/0076-approvals-voice-and-a-real-reset.patch"

  # Device choice belongs in Settings, so the composer carries switches instead of two dropdowns.
  patch -Np1 -i "${srcdir}/0077-mic-and-speaker-are-switches.patch"

  # The model chip answers its own question: a key can be added without leaving the composer.
  patch -Np1 -i "${srcdir}/0078-a-key-where-the-question-is-asked.patch"

  # Dictation opens the microphone instead of reading a transcript somebody else produced.
  patch -Np1 -i "${srcdir}/0079-the-microphone-is-actually-opened.patch"

  # Dictation is press-to-start, press-to-stop, with a level meter while it is open.
  patch -Np1 -i "${srcdir}/0080-dictation-is-a-toggle-with-a-level-meter.patch"

  # The switch keeps its state across a repaint, and draws before it awaits.
  patch -Np1 -i "${srcdir}/0081-dictation-state-survives-a-repaint.patch"

  # Nothing said is left in an unclosed segment: flush on stop, and show the partial at once.
  patch -Np1 -i "${srcdir}/0082-no-words-left-behind.patch"

  # Ctrl+F searches, and conversation mode lives in the composer instead of being described twice.
  patch -Np1 -i "${srcdir}/0083-ctrl-f-and-no-second-conversation-mode.patch"

  # Personas live in settings, and the persona text can be read there.
  patch -Np1 -i "${srcdir}/0084-personas-are-a-settings-section.patch"

  # The greeting is "Sup" — the first word should set a register, not make a claim.
  patch -Np1 -i "${srcdir}/0085-the-greeting-is-sup.patch"

  # Sup by default; his own theme is the only place the other register appears.
  patch -Np1 -i "${srcdir}/0086-sup-by-default-sup-bitches-in-his-own-theme.patch"

  # The edition names itself in his handle's own case; the composer placeholder asks nothing.
  patch -Np1 -i "${srcdir}/0087-volkdude85-edition-and-a-plain-placeholder.patch"

  # The register follows the theme: earned by default, all on in his own.
  patch -Np1 -i "${srcdir}/0088-the-register-is-earned.patch"

  # A dev key box that configures in one paste, and a door that resets to zero.
  patch -Np1 -i "${srcdir}/0089-a-dev-key-and-a-door-that-means-zero.patch"

  # Nora introduces herself on an empty install, and the persona says the same in her voice.
  patch -Np1 -i "${srcdir}/0090-nora-introduces-herself.patch"

  # No macOS-shaped capability is advertised on Linux, and the prompt says so.
  patch -Np1 -i "${srcdir}/0091-no-apple-shaped-capabilities-on-linux.patch"
  cargo fetch --locked --target x86_64-unknown-linux-gnu
}

build() {
  cd "${srcdir}/QuixiDesk-${pkgver}"
  # Which edition this is, compiled in and shown in the title bar. The published build is the one
  # that must never be mistaken for a machine's local copy: it ships with no persona, no memory
  # entries and no keys, and its name says which one it is.
  export QUIXI_EDITION_LABEL="(volkdude85 github) "
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export CARGO_NET_OFFLINE=true
  # Keep the toolchain deterministic: gcc/bfd as the driver, and the same
  # debuginfo level makepkg uses so ring's Rust CGUs and its C objects are
  # built under matching settings. (The undefined ring_core_*_ link failure is
  # fixed by options=('!lto') above, not by these flags.)
  # Remap the build path out of the binary. Without this, panic locations and debug info
# embed the builder's home directory -- 975 strings of /home/<user>/... in QuixiDesk
# alone -- which ships their username to everyone who downloads the package.
export RUSTFLAGS="-C force-frame-pointers=yes -C debuginfo=2 -C linker=cc -C link-arg=-fuse-ld=bfd --remap-path-prefix=$HOME=/build"
  cargo build --release --workspace --locked --lib
  cargo build --release --workspace --locked --bins
  local b
  for b in QuixiDesk quixi-chrome-native-host quixi-disclaimer quixi-guest-daemon \
           quixi-mcp-builtin quixi-mcp-worker quixi-ssh-askpass; do
    [ -x "target/release/${b}" ] || { echo "quixidesk: missing binary ${b}" >&2; return 1; }
  done
}

check() {
  cd "${srcdir}/QuixiDesk-${pkgver}"
  export CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
  export CARGO_NET_OFFLINE=true
  export RUSTFLAGS="-C force-frame-pointers=yes -C debuginfo=2 -C linker=cc -C link-arg=-fuse-ld=bfd"
  # Unit tests for the Linux platform layer: keycode table, character map,
  # desktop-entry parsing, capability consistency. The input-synthesis tests are
  # deliberately NOT run here - they inject real keystrokes and clicks into
  # whatever window has focus, so they need a human-supervised throwaway terminal
  # (QUIXI_INPUT_TEST=1) and must never fire during a package build.
  cargo test --release --locked -p quixi-platform --lib
}

package() {
  # Ship the OpenRC service. NOT under /usr/share/doc: many images — including the Artix base
  # image — carry `NoExtract = usr/share/doc/*` in pacman.conf, so pacman records the file in its
  # database and then never writes it to disk. A functional file in a documentation path is
  # invisible exactly where it is most needed. Measured: the package installed with 116 files and
  # no service file, and `pacman -Qkk` reported `/usr/share/doc (No such file or directory)`.
  install -Dm644 "${srcdir}/ydotoold.openrc" \
    "${pkgdir}/usr/share/${pkgname}/ydotoold.openrc"

  cd "${srcdir}/QuixiDesk-${pkgver}"

  # --- private tree: every helper binary plus the resources dir -------------
  # Upstream resolves helpers via current_exe()'s directory and the web UI via
  # $QUIXI_RESOURCES_DIR (or ./resources beside the binary). Both are satisfied
  # by keeping the whole portable layout together under /usr/lib/quixidesk.
  install -d "${pkgdir}${_libdir}"

  local bins=(
    QuixiDesk
    quixi
    quixi-chrome-native-host
    quixi-disclaimer
    quixi-guest-daemon
    quixi-mcp-builtin
    quixi-mcp-worker
    quixi-ssh-askpass
  )
  local b
  for b in "${bins[@]}"; do
    install -Dm755 "target/release/${b}" "${pkgdir}${_libdir}/${b}"
  done

  cp -a resources "${pkgdir}${_libdir}/resources"
  install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"

  # Attribution for the memory design. The wings/rooms/drawers model is MemPalace's idea.
  install -d "${pkgdir}/usr/share/doc/${pkgname}"
  cat > "${pkgdir}/usr/share/doc/${pkgname}/CREDITS" <<'EOF'
QuixiDesk is by QuixiAI (Eric Hartford) - MIT.
See /usr/share/licenses/quixidesk-custom/LICENSE for the upstream notice.

Memory subsystem (wings / rooms / drawers, "MemPalace")
  Design and name: MemPalace, by Milla Jovovich and the MemPalace project.
  https://github.com/MemPalace/mempalace   (MIT)

  The implementation here is independent - no MemPalace source was copied - but the
  model is hers and the credit is hers. If you like it, go and look at the original.

Linux platform layer, skills integration, headless driver, memory:
  written for this fork.
EOF

  # --- launcher ------------------------------------------------------------
  install -d "${pkgdir}/usr/bin"
  cat > "${pkgdir}/usr/bin/${pkgname}" <<'EOF'
#!/bin/sh
_libdir=/usr/lib/quixidesk
export QUIXI_RESOURCES_DIR="${QUIXI_RESOURCES_DIR:-${_libdir}/resources}"
export QUIXI_MCP_WORKER="${QUIXI_MCP_WORKER:-${_libdir}/quixi-mcp-worker}"
case ":${PATH}:" in
  *":${_libdir}:"*) ;;
  *) PATH="${_libdir}:${PATH}"; export PATH ;;
esac
exec "${_libdir}/QuixiDesk" "$@"
EOF
  chmod 755 "${pkgdir}/usr/bin/${pkgname}"

  # Headless driver. A symlink is enough: current_exe() resolves it to the real path, and the
  # binary already falls back to /usr/lib/quixidesk/resources when the sibling dir is absent.
  ln -s "${_libdir}/quixi" "${pkgdir}/usr/bin/quixi"

  # --- desktop entry + icons ----------------------------------------------
  install -d "${pkgdir}/usr/share/applications"
  cat > "${pkgdir}/usr/share/applications/${pkgname}.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=QuixiDesk
GenericName=AI Desktop Workspace
Comment=Native desktop workspace for AI with cloud and local providers
Exec=quixidesk %U
Icon=quixidesk
Terminal=false
Categories=Development;Utility;
Keywords=AI;LLM;Chat;Assistant;Agent;MCP;Ollama;llama.cpp;
StartupNotify=true
StartupWMClass=QuixiDesk
EOF

  install -Dm644 resources/quixi-logo.svg \
    "${pkgdir}/usr/share/icons/hicolor/scalable/apps/${pkgname}.svg"

  local s
  for s in 16 24 32 48 64 128 256 512; do
    install -d "${pkgdir}/usr/share/icons/hicolor/${s}x${s}/apps"
    rsvg-convert -w "${s}" -h "${s}" resources/quixi-logo.svg \
      -o "${pkgdir}/usr/share/icons/hicolor/${s}x${s}/apps/${pkgname}.png"
  done

  # --- runtime docs --------------------------------------------------------
  install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
  install -Dm644 ARCHITECTURE.md "${pkgdir}/usr/share/doc/${pkgname}/ARCHITECTURE.md" 2>/dev/null || true
  # Platform documentation: the macOS->Linux mapping, the decisions and the
  # measurements behind them, and the dependency table. Ships inside the
  # package so it is readable without the source tree.
  install -Dm644 crates/quixi-platform/NOTES-linux.md \
    "${pkgdir}/usr/share/doc/${pkgname}/NOTES-linux.md"
}
