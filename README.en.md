# NovelPhone

[简体中文](README.md) | English

[![CI](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml/badge.svg)](https://github.com/wly2lcl/NovelPhone/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Flutter](https://img.shields.io/badge/Flutter-3.44.3-02569B?logo=flutter&logoColor=white)

**A local-first AI novel-writing app for mobile.** Manuscripts, worldbuilding, characters and stats all live on your device. AI is an on-demand writing partner that talks directly to the model provider *you* configure — no middleman server involved.

Two design principles:

- **Your data stays yours** — SQLite storage on device, API keys in the OS secure store, backups to local files or your own object storage;
- **Curating the "AI flavor"** — a built-in rule engine plus optional LLM deep-check flags clichés and repetitive sentence patterns with locate-and-replace actions; AI continuation generates multiple candidates in parallel for you to compare.

Status: the MVP scope (78 / 78) is complete, followed by 24 enhancements (ENH-01~24, including a full Simplified-Chinese / English bilingual UI, MCP OAuth 2.1 PKCE and skill front-matter import, accessibility semantics, a branded app icon / launch splash, release-artifact delivery, plus the recycle bin, MCP call audit, backup checksum preview, skill export, style profile, AI setting completion, plot brainstorming, work Q&A, whole-work consistency scan and stability hardening; ENH-24 adds Markdown / EPUB import, plot-to-outline transfer, relation extraction, batch summaries, a monthly AI budget and release closure). Android release signing, AAB / split-ABI APKs and GitHub Actions CI (including an iOS unsigned-build job and release-artifact archiving) are in place; the iOS unsigned release build passes and 450 automated tests pass. Real-device acceptance records are in [docs/TODO.md](docs/TODO.md) (Chinese). On 2026-10-18 the ENH-23 style profile, AI setting completion and plot brainstorming were re-verified against two real model channels — `deepseek-v4-flash` and `agnes-3.0-flash` (portrait comparison screenshots below).

## Screenshots

| Works list | Volumes & chapters | Editor |
|:---:|:---:|:---:|
| ![Works list](docs/images/works-list.png) | ![Volumes & chapters](docs/images/chapters.png) | ![Editor](docs/images/editor.png) |

| AI-flavor check | AI continuation (3 candidates) |
|:---:|:---:|
| ![AI-flavor check](docs/images/ai-check.png) | ![AI continuation](docs/images/ai-continue.png) |

**ENH-23 real-model acceptance (portrait comparison, left: before / right: AI result)**

| Style profile (DeepSeek V4) | AI setting completion (Agnes 3.0) |
|:---:|:---:|
| ![Style profile](docs/images/enh23-style-compare.png) | ![AI setting completion](docs/images/enh23-extract-compare.png) |

| Plot brainstorming (DeepSeek V4) |
|:---:|
| ![Plot brainstorming](docs/images/enh23-plan-compare.png) |

## Features

### Writing & work management

- Multiple works with cover colors, word counts and last-edited times; global search across works with highlighted hits and jump-to-editor
- Volumes and chapters: move volumes up / down, rename, delete; create chapters inside a volume; rename chapters, move them up / down or to another volume, and delete them
- Recycle bin: deleting a work or chapter only marks it as deleted; restore it or purge it permanently within 30 days from Settings → Recycle Bin. Expired entries are cleaned automatically at startup and when the bin is opened
- Import txt / docx / Markdown / EPUB: encoding auto-detection (UTF-8 / GBK), chapter splitting on「第X章」headings with preview, merge-into-previous, 10 MB file cap; EPUB chapters follow the OPF spine (nav pages skipped) and Markdown splits on headings
- Editor: autosave with a "saved" indicator, focus mode (toolbars hidden, caret line centered), writing appearance (night paper, font size, line height)
- Find, paragraph move, undo / redo (double cap: 100 steps and 2M characters)
- Find & replace across a whole work: preview every matching chapter and snippet, then replace all at once; affected chapters get automatic snapshots you can roll back from version history
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
- **AI setting-consistency check**: combines the current chapter, character cards, story bible and outline into a one-shot report of character / setting / timeline conflicts with fix suggestions; results are read-only and never modify the manuscript
- **Whole-work consistency scan**: scans every chapter and expands per-chapter conflict details; generation streams live and can be stopped at any time while keeping the partial report
- **Style profile**: extracts narrative perspective, tone, sentence-length and wording preferences from sample chapters into the work, then injects them into writing and Q&A context automatically
- **AI setting completion**: extracts characters, story-bible entries and character relations from chapter text, previews the merged result with automatic deduplication, and applies it to character cards / the story bible / the relation graph in one step; relations whose endpoints cannot be resolved report why they were skipped
- **Plot brainstorming**: proposes multiple directions and per-chapter suggestions from existing settings, outlines and the latest progress, saveable to the inspiration box or transferable to chapter outlines
- **Batch summaries**: generates summaries for chapters that lack one or whose text changed, sequentially, with a stop control
- **Work Q&A**: multi-turn conversation about a whole work, answering after retrieving chapters, characters, settings and outlines locally; history persists per work (latest 40 turns), with a context preview for the current turn and a clear action
- **AI-flavor check**: two tiers — a rule engine (~200 phrase entries, sentence-pattern repetition, punctuation density) and an optional LLM deep check. The panel supports scope stats, type filters, in-place highlight & locate, one-tap replace, ignore / bulk-ignore, and handling-rate stats; runs without freezing the UI for both single chapters and entire works

### Models & extensibility

- Model groups: OpenAI-compatible / Anthropic / Responses endpoint protocols, multiple groups with enable toggles, baseUrl and model list, per-task generation parameters
- Task-to-model mapping: continuation / inspiration / rewrite / check / summary / outline / volume-recap / setting-consistency check each bind to their own group; unconfigured states guide you to Settings. The consistency check falls back to the AI-flavor check group and then the continuation group
- Network resilience: exponential backoff retry on 429 / 5xx before the first text delta; classified, readable errors for content-filtering and other failures; 30-second connect timeout and 90-second stream-idle timeout so requests cannot hang forever
- MCP tool service: connect a remote Streamable HTTP server and let AI call its tools; authentication supports custom headers and **OAuth 2.1 PKCE** (authorization in the system browser, loopback callback, dynamic client registration, automatic refresh_token renewal; tokens stay in the on-device secure store). The **MCP call audit** keeps the latest 100 remote tool calls on device (tool name, argument / result summaries, duration, success flag), expandable and clearable, with no network access and no credentials
- Custom skills: extra instruction text plus a tool allowlist, injected into continuation and inspiration orchestration; **front matter** import from a file or pasted text following the Anthropic SKILL.md convention (name / description / allowed-tools / parameters / enabled, previewed before saving), plus Markdown export shared through the system share sheet

### UI & experience

- Bilingual UI: Simplified Chinese / English, following the system locale by default and switchable in Settings → Writing → Language (effective immediately, persisted). AI prompts and Chinese domain data stay in Chinese
- App-wide dark mode: follow-system / light / dark, with light and dark variants of the warm paper palette
- Branded look: a fountain-pen-nib app icon and a warm launch splash; an About page with the version number, privacy highlights and the open-source license list
- Accessibility: labeled switches / color swatches / overflow menus, long-press-only actions exposed as custom screen-reader actions (work cards, chapter rows), summary descriptions for charts, and sliders merged with their labels

### Data, stats & privacy

- Backup to file: whole-database zip (`data.json` + `manifest.json` + per-work markdown). Before restoring, a preview shows the export time, data version and work / chapter / character counts and verifies the **SHA-256** checksum (legacy backups without a manifest are clearly labeled); restore either as "merge as new works" or "overwrite local data"
- Cloud backup: bring your own S3-compatible storage (AWS S3 / Alibaba Cloud OSS / Qiniu Kodo / Tencent COS / Huawei OBS), SigV4 signed directly, off by default, manual and interval-based automatic backups
- Writing stats: daily word-count goal progress, writing streak, pomodoro, a 7 / 30-day word-count trend chart and a year-long writing heatmap
- Token & adoption stats: grouped by task · model, tracking generations, token usage, adoption and ignore rates; model groups accept per-million input / output token prices, and the stats page estimates cost in CNY; an optional **monthly AI budget** warns at 80% and turns red at 100% (it does not block calls)
- Release materials: a standalone bilingual [privacy policy](docs/PRIVACY.md) and [release guide](docs/RELEASE.md) (build commands, Google Play listing, Data safety answers, iOS blockers); the About page opens the privacy policy externally
- Privacy: API keys live in the OS secure store (keychain / keystore), never in the database and never in backups; a first-network-use notice gates every AI feature. See [docs/COMPLIANCE.md](docs/COMPLIANCE.md) (Chinese)

## Tech stack

| Layer | Choice |
|---|---|
| UI / state | Flutter 3.44 · Riverpod · go_router |
| Data | Drift (SQLite, schema v12 with a full migration chain) |
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

Release artifacts (configure signing first: point `android/key.properties` at your keystore; neither file is committed — keep offline backups):

```bash
# AAB: the Google Play upload format (required for the first submission)
flutter build appbundle --release

# Split-ABI APKs: recommended for sideloading / direct distribution (one per ABI)
flutter build apk --release --split-per-abi

# Universal APK: one package for all devices, larger size
flutter build apk --release
```

Artifact paths: APKs under `build/app/outputs/flutter-apk/`, AAB under `build/app/outputs/bundle/release/`.

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
flutter test    # 450 cases: data layer / editor controller / AI client & orchestration / style profiles and structured output / work Q&A and retrieval / import parsing (txt / Markdown / EPUB) / MCP OAuth, audit and skill import-export / check engine / widgets
```

GitHub Actions ([ci.yml](.github/workflows/ci.yml)) runs the three checks on pushes and pull requests and additionally runs an unsigned iOS release build (`flutter build ios --release --no-codesign`) on `macos-latest` to catch iOS project / plugin integration issues early. On `main` pushes or manual dispatch it also builds an AAB and split-ABI APKs with an ephemeral keystore and archives them for 14 days (build verification only; rebuild with the offline release certificate before uploading, see [docs/RELEASE.md](docs/RELEASE.md)).

Dev helpers: [tool/fake_llm_server.dart](tool/fake_llm_server.dart) simulates Chat Completions / Messages success streams plus 429 / 5xx / content-filtering scenarios, and provides JSON scenarios for style / entity extraction / plot planning (`/openai-style`, `/openai-extract`, `/openai-plan`); stream chunks are flushed immediately so incremental output and stop-with-partial-result can be observed (`GET /stats` reports request counts; the `/openai-tool` scenario issues a tool call first and answers once the tool result arrives, exercising the MCP call and audit path). With `adb reverse` it lets you exercise AI error and retry paths on a real device without a real API key. [tool/fake_mcp_oauth_server.dart](tool/fake_mcp_oauth_server.dart) simulates an MCP server with an OAuth 2.1 PKCE authorization server (dynamic registration, S256 verification, refresh_token) and an echo tool for exercising the full authorization chain.

## Documentation

| Document | Contents |
|---|---|
| [docs/PRD.md](docs/PRD.md) | Product positioning, scope and acceptance criteria |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Tech choices, layering, data model and AI-layer design |
| [docs/TODO.md](docs/TODO.md) | Task list, progress tracking and real-device acceptance records (M1-M4 + ENH-01~24) |
| [docs/COMPLIANCE.md](docs/COMPLIANCE.md) | Privacy policy, data-security notes and store-listing points |
| [docs/RELEASE.md](docs/RELEASE.md) | Build commands, store listing, Data safety answers and known limitations |
| [docs/PRIVACY.md](docs/PRIVACY.md) | Public privacy policy (bilingual, shared by the store listing and the in-app About page) |

(The docs above are written in Chinese.)

## License

[Apache License 2.0](LICENSE)
