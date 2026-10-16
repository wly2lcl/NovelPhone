# NovelPhone

[简体中文](README.md) | English

[![CI](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml/badge.svg)](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.44.3-02569B?logo=flutter&logoColor=white)

**A local-first AI novel-writing app for mobile.** Manuscripts, worldbuilding, characters and stats all live on your device. AI is an on-demand writing partner that talks directly to the model provider *you* configure — no middleman server involved.

Two design principles:

- **Your data stays yours** — SQLite storage on device, API keys in the OS secure store, backups to local files or your own object storage;
- **Curating the "AI flavor"** — a built-in rule engine plus optional LLM deep-check flags clichés and repetitive sentence patterns with locate-and-replace actions; AI continuation generates multiple candidates in parallel for you to compare.

Status: the MVP scope (78 / 78) is complete, followed by 18 enhancements (ENH-01~18, including a full Simplified-Chinese / English bilingual UI). Android release signing and GitHub Actions CI are in place; the iOS unsigned release build passes and 332 automated tests pass. Real-device acceptance records are in [docs/TODO.md](docs/TODO.md) (Chinese).

## Screenshots

| Works list | Volumes & chapters | Editor |
|:---:|:---:|:---:|
| ![Works list](docs/images/works-list.png) | ![Volumes & chapters](docs/images/chapters.png) | ![Editor](docs/images/editor.png) |

| AI-flavor check | AI continuation (3 candidates) |
|:---:|:---:|
| ![AI-flavor check](docs/images/ai-check.png) | ![AI continuation](docs/images/ai-continue.png) |

## Features

### Writing & work management

- Multiple works with cover colors, word counts and last-edited times; global search across works with highlighted hits and jump-to-editor
- Volumes and chapters: move volumes up / down, rename, delete; create chapters inside a volume; rename chapters, move them up / down or to another volume, and delete them
- Import txt / docx: encoding auto-detection (UTF-8 / GBK), chapter splitting on「第X章」headings with preview, merge-into-previous, 10 MB file cap
- Editor: autosave with a "saved" indicator, focus mode (toolbars hidden, caret line centered), writing appearance (night paper, font size, line height)
- Find, paragraph move, undo / redo (double cap: 100 steps and 2M characters)
- Chapter snapshots (version history): create / preview / restore / delete, with paragraph-level diff against the current text (change counts, colored lines, long unchanged runs collapsed), carried through backups
- Export: single chapter as txt / markdown; a whole work as Word (.docx) and EPUB 3

### Story assets

- Character cards with tags and descriptions, fed into AI context assembly
- Story bible: categorized worldbuilding / location / item entries
- Chapter outlines, expandable by AI
- Character relationship graph: ring layout with add / edit / delete

### AI writing partner

- **AI continuation**: 3 candidates generated in parallel by default (slightly varied temperature), length slider, custom direction, insert-at-caret; expandable "what the AI sees" panel showing estimated tokens vs. budget
- **AI inspiration**: streamed scene ideas, with previous-chapter summaries and the current outline injected
- **AI rewrite**: rewrite a selected paragraph as polish / expand / condense / tone-shift plus extra instructions; replacing the original goes through the undo stack
- **AI per-chapter summaries + volume recaps**: rolling summaries fight long-novel "amnesia"; summaries are viewable / editable and warn when stale
- **AI outline expansion**: turn a one-line premise into a scene-by-scene outline written back to the chapter
- **AI-flavor check**: two tiers — a rule engine (~200 phrase entries, sentence-pattern repetition, punctuation density) and an optional LLM deep check. The panel supports scope stats, type filters, in-place highlight & locate, one-tap replace, ignore / bulk-ignore, and handling-rate stats; runs without freezing the UI for both single chapters and entire works

### Models & extensibility

- Model groups: OpenAI-compatible / Anthropic / Responses endpoint protocols, multiple groups with enable toggles, baseUrl and model list, per-task generation parameters
- Task-to-model mapping: continuation / inspiration / rewrite / check / summary / outline / volume-recap each bind to their own group; unconfigured states guide you to Settings
- Network resilience: exponential backoff retry on 429 / 5xx before the first text delta; classified, readable errors for content-filtering and other failures
- MCP tool service: connect a remote Streamable HTTP server and let AI call its tools
- Custom skills: extra instruction text plus a tool allowlist, injected into continuation and inspiration orchestration

### UI & experience

- Bilingual UI: Simplified Chinese / English, following the system locale by default and switchable in Settings → Writing → Language (effective immediately, persisted). AI prompts and Chinese domain data stay in Chinese
- App-wide dark mode: follow-system / light / dark, with light and dark variants of the warm paper palette

### Data, stats & privacy

- Backup to file: whole-database zip (`data.json` + per-work markdown), restored either as "merge as new works" or "overwrite local data"
- Cloud backup: bring your own S3-compatible storage (AWS S3 / Alibaba Cloud OSS / Qiniu Kodo / Tencent COS / Huawei OBS), SigV4 signed directly, off by default, manual and interval-based automatic backups
- Writing stats: daily word-count goal progress, writing streak, pomodoro, and a 7 / 30-day word-count trend chart
- Token & adoption stats: grouped by task · model, tracking generations, token usage, adoption and ignore rates
- Privacy: API keys live in the OS secure store (keychain / keystore), never in the database and never in backups; a first-network-use notice gates every AI feature. See [docs/COMPLIANCE.md](docs/COMPLIANCE.md) (Chinese)

## Tech stack

| Layer | Choice |
|---|---|
| UI / state | Flutter 3.44 · Riverpod · go_router |
| Data | Drift (SQLite, schema v10 with a full migration chain) |
| Secure storage | flutter_secure_storage (keychain / keystore) |
| Network | http (SSE stream parsing), crypto (cloud-backup SigV4 signing) |
| AI interop | three endpoint-protocol adapters, mcp_dart (remote MCP), custom-skill orchestration |
| Platform | Single codebase for iOS / Android; Android is currently the primary delivery and acceptance target (iOS has passed an unsigned release build check) |

No server-side components: the app works offline; network is used only when you actively call AI or cloud backup, connecting straight to the provider you configured.

## Getting started

Requirements:

- Flutter 3.44.x (CI baseline 3.44.3) / Dart ^3.12.2
- Android SDK (to build the Android package)
- Xcode 27+ (to build the iOS package, optional; no CocoaPods needed)

```bash
flutter pub get
flutter run     # on a connected Android device or emulator
```

Release APK (configure signing first: point `android/key.properties` at your keystore; neither file is committed — keep offline backups):

```bash
flutter build apk --release
```

iOS build (requires Xcode 27+; Flutter 3.44 uses Swift Package Manager, no CocoaPods needed; use `--no-codesign` to verify compilation without a signing certificate):

```bash
flutter build ios --no-codesign --release
```

Regenerate Drift code after changing table schemas:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tests & CI

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test    # 332 cases: data layer / editor controller / AI client & orchestration / check engine / widgets
```

GitHub Actions ([ci.yml](.github/workflows/ci.yml)) runs the three checks on pushes and pull requests.

Dev helper: [tool/fake_llm_server.dart](tool/fake_llm_server.dart) simulates Chat Completions / Messages success streams plus 429 / 5xx / content-filtering scenarios on loopback (`GET /stats` reports request counts). With `adb reverse` it lets you exercise AI error and retry paths on a real device without a real API key.

## Documentation

| Document | Contents |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Product positioning, scope and acceptance criteria |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Tech choices, layering, data model and AI-layer design |
| [docs/TODO.md](docs/TODO.md) | Task list, progress tracking and real-device acceptance records (M1-M4 + ENH-01~18) |
| [docs/COMPLIANCE.md](docs/COMPLIANCE.md) | Privacy policy, data-security notes and store-listing points |

(The docs above are written in Chinese.)

## License

[Apache License 2.0](LICENSE)
