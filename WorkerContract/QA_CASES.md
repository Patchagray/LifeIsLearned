# Mandatory integration checks for Codex

- Catalog returns 50 planned titles when allowlists empty, no Download controls; unknown ID 404.
- `approved-covers` alone enables cover preview for planned title but never package download.
- Invalid/unapproved/missing cover -> placeholder, no body transfer.
- Package exists in private GitHub but has no allowlist approval -> 404 from Worker.
- All-but-one-idea valid audio -> publication blocked (not an optional fallback path for distributed books).
- `audio-gate` PASS but owner has not approved the exact hash -> blocked.
- Owner approval present but `audio-gate` FAIL -> blocked.
- Tampered size/SHA/ID/revision -> blocked before import, no learner-state changes.
- Direct anonymous GitHub private release URL denies access; Worker route with valid GitHub App secret can read.
- Worker never sends GitHub auth to signed redirect, leaks private release location, or serves arbitrary file paths.
- Cancellation/resume: correct 206/Content-Range or safe clean restart; 401/403/404/429/5xx recover gracefully.
- App Explore appears even with empty installed library; toggling remains in-place and keeps active narration.
- Plus menu only Scan Book, Import File and Cancel; scanner and remote restore focus Explore book ID.
- Offline reading from installed package uses studio MP3; offload removes package/audio while retaining cards/progress/History; redownload restores.
- App Attest not present; document public Worker endpoint access honestly.
