# SAFEGRAM iOS — verified status (2026-10-31)

## Canonical sources
- Repository: https://github.com/mrirodovskiy97-hash/SAFEGRAM-iOS-CI
- Base branch: local/brandfix-v04; base commit: 01442957b7439be978b9ef7279b8e8ff7c68ceba
- Pinned upstream: https://github.com/maksakks/Ayugram-iOS at 2f746090b09b20695886fd52706a76d01b68ecaa
- Local isolated checkout: isolated development checkout

## Verified
- GitHub Actions run 32 (2026-10-15): Simulator and unsigned arm64 IPA jobs succeeded. This is **historical CI** evidence, not physical-device acceptance.
- Desktop SAFEGRAM.ipa and SAFEGRAM_NEW_BUILD_32/SAFEGRAM-UNSIGNED.ipa matched SHA256 34ff581dd83df6ed65b3c7e726e2689226a94f450d461771133a5c8f37251a5b on 2026-10-31.
- IPA build status: DEVICE_CREDENTIAL_MODE=TELEGRAM_TEST_ONLY; IPA_CODESIGNING=UNSIGNED; Telegram account login NOT verified.
- Windows 10: Apple Mobile Device Service running, physical iPhone NOT detected in latest USB probe.
- Local Python device-config suite: 6/6 PASS; compileall and git diff --check PASS on 2026-10-31.
- Fixed local Windows-incompatible POSIX mode assertion in ci/test_prepare_device_config.py.
- Added regression case to ci/privacy-smoke/main.swift: replayed message must still get warning scan when Leak Guard is enabled later; preserve opt-in message history deduplication. Minimal bridge fix in overlay/Swiftgram/SafeGramCore/Sources/SafeGramBridge.swift.
- Swift privacy smoke is **NOT executed** after this patch: macOS Xcode/Swift toolchain unavailable on Windows. Do not claim that native compilation passed for this patch.

## External blockers / release gate
1. Owner's Telegram app API ID/hash (from my.telegram.org) must be supplied directly to a trusted secret field; never write or paste credentials into logs, chat, Notion, or this repository.
2. Build with require_own_telegram_credentials=true; verify DEVICE_CREDENTIAL_MODE=OWN_TELEGRAM_APP. A test-mode IPA is NOT a usable release.
3. Connect the real iPhone and use local Apple signing. Apple ID/2FA must be entered by owner into legitimate signing UI only.
4. Perform actual device acceptance: install, launch, Telegram login, conversations, Security Center, local lock and unlock, history opt-in/deletion, and regression checks.
5. Visual design: owner rejected old UI on 2026-10-13 and chose the first of seven alternatives; the exact source file for 'first' is not recoverably identified. Do not silently ship rejected design.

## Safety and rollback
- Never overwrite existing Desktop IPA files or previous builds; this checkout is separate.
- Do not publish/push a release or change access without owner authorization.
- Revert local patch by checking the baseline commit in a **new isolated copy**; do not erase the previous checkpoint or other agents' work.
- Notion project checkpoint: private project status in Notion (not publicly linked)
