# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AethrOps is a cross-platform (Android, Windows, Linux) AWS management app: a Flutter UI (`awsmgr_ui/`) talking over HTTP to a local Go backend that uses AWS SDK for Go v2. It is the successor to the CLI tool `awsmgr`, which is why the Flutter project and some identifiers are still named `awsmgr`.

Pinned toolchain versions (Flutter 3.41.3, Go 1.24.3, JDK 17, NDK r26d, etc.) are listed in `REQUIREMENTS.md`. Don't upgrade Flutter casually, because newer versions rewrite `android/gradle.properties`.

## Commands

```bash
# Linux dev run: builds backend/aethrops_core, starts `flutter run -d linux`,
# then copies the backend binary into build/linux/x64/debug/bundle/
./scripts/run_linux.sh

# Backend only (desktop HTTP server on 127.0.0.1:9480). It refuses to start without a token,
# and every request needs `Authorization: Bearer <token>`:
cd backend && go build -o aethrops_core main.go && AETHROPS_AUTH_TOKEN=dev ./aethrops_core
curl -H 'Authorization: Bearer dev' http://127.0.0.1:9480/api/version

# Android: cross-compile backend_ffi to libbackend.so for each ABI (needs ANDROID_NDK_HOME or auto-detects)
./scripts/build_backend_android.sh   # then: cd awsmgr_ui && flutter build apk
./scripts/build_android.sh           # full release APK build

./scripts/build_linux.sh             # Linux release; also build_appimage.sh, build_debian.sh
scripts\build_windows.bat            # Windows release; installer in scripts/installer/windows_setup.iss
```

Static checks (these mirror CI in `.github/workflows/test-backend.yml` and `test-frontend.yml`):

```bash
cd backend && go vet ./... && go fmt ./... && staticcheck ./...
cd awsmgr_ui && flutter analyze --no-fatal-infos && dart format lib/
```

The repo has no unit tests, either Go `_test.go` files or a Flutter `test/` directory. Run `go vet`, `flutter analyze` and the app itself to check changes.

## Architecture

### One backend, two hosts
- `backend/` (module `github.com/DragonEmperor9480/AethrOps`) holds all the logic. Its `main.go` runs a Gorilla Mux HTTP server on `127.0.0.1:9480` for desktop. The Flutter app spawns it as a child process named `aethrops_core`, which must sit next to the Flutter executable. The backend exits when its stdin closes, so it dies with the parent.
- `backend_ffi/` is a separate Go module that imports `backend` through `replace ... => ../backend` and is built with `-buildmode=c-shared` into `libbackend.so` for Android. It exports C functions (`SetDataDirectory`, `SetAuthToken`, `SetAWSCredentials`, `StartBackend`, `StopBackend`). `StartBackend` starts the **same HTTP server and routes** in-process on port 9480.
- **The local API is authenticated.** `backend/middleware/auth.go` (`middleware.Secure`) wraps the router in both hosts. It rejects any `Host` other than `127.0.0.1:9480` / `localhost:9480`, which blocks DNS rebinding, and any request without the per-launch bearer token, including `/health`. There is deliberately no CORS.
  - **Token flow:** Flutter generates the token in `BackendService` and passes it through the `AETHROPS_AUTH_TOKEN` env var on desktop, or the `SetAuthToken` FFI export (called before `StartBackend`) on Android.
  - **In Dart, every backend call must go through `BackendService.client` (package:http) or `S3Service._dio`,** which already carry the header. A bare `http.get` gets a 401. Never add the header to `S3Service._s3Dio`, which talks directly to S3.
- So the Flutter side always talks HTTP. `awsmgr_ui/lib/services/backend_service.dart` decides whether to spawn a process (desktop) or `dlopen` the library over FFI (mobile). Any new backend initialization step must be added to both `backend/main.go` and `backend_ffi/main.go`.

### Backend layering (`backend/`)
- `routes/routes.go`: the single registry of every `/api/...` endpoint. New endpoints go here. Gorilla Mux matches routes in registration order, so register literal paths (e.g. `/api/ec2/instances/all-regions`) before `{param}` routes. Object keys and ARNs use `{name:.*}` patterns.
- `controllers/`: HTTP handlers that parse requests, call into the service/model layer, and write JSON. EC2 handlers take an optional `?region=` and use `utils.GetEC2ClientForRegion` for it.
- **Two response formats exist side by side, and the codebase is migrating between them (since PR #15):**
  - **New:** `utils.Success(w, status, msg, data)` / `utils.Error(w, status, msg)` (`utils/json.go`) wrap every response in `models.Response` → `{"status": bool, "message": string, "data": ...}`. Messages are constants in `constants/` (`constants.go` for success messages and the int status codes, `error_constants.go` for error messages). Currently only part of `controllers/iam.go` and `/health` use it.
  - **Old:** `respondJSON` / `respondError` (bottom of `controllers/iam.go`) return the raw payload, and errors as `{"error": "..."}`. Every other controller still uses these.
  - Moving an endpoint to the new envelope changes its JSON shape, so the matching Dart method in `awsmgr_ui/lib/services/` must be updated in the same change. It needs to read `body['data'][...]` instead of `body[...]`, and `message` instead of `error`.
- **Where AWS calls live:**
  - **IAM (refactored):** the logic is in `service/iam_user_service.go`, `iam_group_service.go` and `iam_policy_service.go`. Request/result types are flat files in `models/` (`iamUser.go`, `iamGroup.go`, `iamPolicy.go`). Simple list calls may call `utils.IAMClient` directly from the controller. The old `models/iam/{user,group,policy}/` packages are gone.
  - **S3, EC2 and CloudWatch:** still use the older layout of one file per operation under `models/<service>/` (e.g. `models/s3/CreateS3FolderModel.go`), with mixed snake_case/PascalCase file names.
  - Several IAM routes in `routes.go` are commented out or marked `NEED TO IMPLEMENT IT LATER` while the refactor is in progress.
- `utils/aws_client.go`: global SDK clients (`utils.EC2Client`, `IAMClient`, `S3Client`, …) plus a per-region EC2 client cache. `InitAWSClients()` loads the **active account from SQLite** and falls back to file/env config. Switching accounts or credentials re-runs this (`controllers/aws_reload.go`).
- `db_service/`: GORM + SQLite (`aethrops.db`; v1.1 started a fresh database, and the old `aethrops_data.db` is ignored). Desktop stores it under `~/.aethrops/`, and mobile uses the directory passed to `SetDataDirectory`. Secret keys are encrypted at rest through `db_service.Encrypt/Decrypt`.
- `service/`: IAM business logic (see above), plus longer-running and cross-cutting features such as CloudWatch log streaming and sessions, SMTP mail for sending IAM credentials, and MFA.

### AWS accounts and credentials
- Accounts are stored in the `AWSAccount` table (`db_service/models.go`), with exactly one `IsActive`. `controllers/aws_accounts.go` handles creating, listing, activating and deleting accounts, and `GET /api/aws/auth-status` returns `authenticated` | `select_account` | `no_accounts`. Activating an account must re-run `utils.InitAWSClients()`, because the global SDK clients are swapped in place.
- `/api/aws/config` (`controllers/aws_config.go`) and the FFI `SetAWSCredentials` export are the **older** credential paths, based on `~/.aethrops/credentials` files and env vars. The DB-backed account system is the primary path.
- **Secrets at rest** use AES-GCM with a random per-install key, `secret.key` (mode 0600) in the config directory, created on first use (`db_service/encryption.go`). Deleting it makes every stored secret unreadable. There is deliberately no migration of data from older builds.
  - The SMTP password is stored encrypted (`sender_pass_enc`) and is never returned by `GET /api/email/config`, which only reports `has_password`.
- SMTP config (`service/mail_service.go`) and the MFA device (`service/mfa_service.go`) are stored as files under `db_service.GetConfigDirectory()`, not in SQLite.

### Data-heavy flows
- **S3 transfers never go through the backend.** `POST /s3/buckets/{b}/upload` and `GET /s3/buckets/{b}/objects/{key}` only return 15-minute **presigned URLs**. For uploads, `S3Service` PUTs directly to S3 with a separate `Dio` client and throttles its progress callbacks. Viewing and downloading open the presigned URL in the system browser (`launchUrl` in `s3_browser_screen.dart`).
- **CloudWatch live logs** use Server-Sent Events. `GET /api/cloudwatch/lambda/{fn}/logs` streams `data: {json}` events with event IDs. `service/cloudwatch_service.go` tries the native StartLiveTail API first and falls back to a shared polling loop with a dedup cache. Each stream also writes to a log session file (`service/log_session_service.go`), which can be downloaded from `/api/cloudwatch/logs/download/{sessionId}`. On the Flutter side, `CloudWatchService.streamLambdaLogs` parses the SSE by hand.

### Flutter (`awsmgr_ui/lib/`)
- **Startup flow:** `main.dart` → `SplashScreen` starts the backend (`BackendService.start()`, which polls `/health` for up to 15 s), then routes based on `auth-status`. `authenticated` goes to `SecurityWrapper(child: HomeScreen())`, `select_account` to `AccountSelectorScreen`, and `no_accounts` to `CredentialsSetupScreen`.
- **PIN and biometric lock:** `services/security_service.dart` stores a hashed PIN in `flutter_secure_storage` and uses `local_auth`. `widgets/security_wrapper.dart` locks the app again after 5 minutes in the background.
- **Desktop window close:** `main.dart` sets `windowManager.setPreventClose(true)`. `onWindowClose` → `utils/exit_handler.dart` shows a confirmation, then POSTs `/api/shutdown` (the backend calls `os.Exit`).
- **`services/`** holds thin, static backend clients. Most use `package:http` with a 30 s timeout (`api_service.dart` covers IAM, accounts, email and version). S3 uses `dio` for its long timeouts and progress reporting. Add a new endpoint to the matching service, not inside a screen.
- **State:** `provider` with only two `ChangeNotifier`s, `ThemeProvider` and `AwsConfigProvider` (current/available region, cached in `shared_preferences`). Everything else is local `StatefulWidget` state in the screens, which are large (1–1.5k lines).
- **UI:** `screens/` holds one screen per AWS area plus its detail and profile screens. Shared widgets are in `widgets/`, including the Samsung-style `oneui_widgets.dart`, and IAM dialogs are in `widgets/iam/`. Theme lives in `theme/app_theme.dart`. Use `utils/toast_utils.dart` for notifications.
- **Platform checks:** code that differs by platform branches on `Platform.isAndroid` / desktop (window manager, FFI vs. process, `download_service.dart` storage permissions and media scan on Android).

### Versioning and releases
- `version.json` at the repo root is the per-platform source of truth (`version` + `build_number`). Build scripts read it and inject it into the backend with `-ldflags -X github.com/DragonEmperor9480/AethrOps/models.Version=... -X ...models.BuildNumberStr=...`.
- The in-app update check (`models/awsmgr_version.go`) fetches `version.json` from the `master` branch on GitHub and compares **build numbers**, not version strings. Bump `build_number` when releasing.
- CI and release automation ("AethrBuild") lives in `.github/workflows/` (`AethrBuild.yml` orchestrates the platform builds, the GitHub release, the website update and announcements).

## Other docs
- `docs/AI_ASSISTANT_ARCHITECTURE.md` and `docs/AI_ASSISTANT_IMPLEMENTATION_PLAN.md`: a planned on-device LLM assistant (llama.cpp through CGo, `/api/ai/chat`) that maps natural language to existing backend operations.
- `ToDo.txt`: known bugs and the backlog.
