# Offline-first Dungeon Companion — Android model inference prototype

Status: experimental `feature/offline-ondevice-ai` branch. Neither
`release/fixed-tablet-ui-v2` nor the working `feature/conversational-companion`
branch is modified. The Android NDK build and Tab A8 memory/speed need testing.

## Purpose

**No AI account, cloud provider, per-question fee, server subscription, or PC
required to answer offline questions.** The AI model and inference execute
on the player's own Android device (CPU). Every public-release user should
be able to run the same local feature without access to the developer's
Vercel account. Offline inference does not contact the internet.

The earlier Vercel prototype is separate and has been paused. This
branch contains no paid AI backend source, API pairing client or cloud
credentials. The original conversational/cloud branch remains preserved
as an independent experiment.

## What's implemented

- A pinned llama.cpp submodule for Android JNI native inference:
  `ggml-org/llama.cpp` at
  `8e23278c7c36f4429fb237467d50e2935a91e655`.
- Android Gradle / CMake ARM64 CPU-only bridge, limiting the context
  to 2048 tokens, maximum input 1700 tokens, maximum answer 160 tokens,
  and 3 CPU threads to limit memory/heat on the Samsung Galaxy Tab A8.
- One-time manual GGUF import from Android's document picker. The app
  copies the model to private application storage. Imports reject
  non-GGUF magic, files under 150 MB, and files over 800 MB. No model
  weights are checked into GitHub or bundled with the APK.
- Wide results pop-out, in-world class personality or factual mode,
  with a local, read-only HP/level snapshot (no upload).
- A **small first-pack** of attributed NetHackWiki reference notes
  for subjects including healing, rations, monks and Elbereth.
  These notes are NOT a full offline copy of NetHackWiki. Missing
  sources are labelled insufficient instead of letting the model
  invent mechanics. Human-authored fact strings are attributed in
  the pop-out under NetHackWiki CC BY-SA 3.0.
- The original NetHackWiki live search remains separate and optional:
  the `Ask NetHackWiki (online)` action uses internet, while
  `Ask offline AI` requires no network.

## Suggested free model for the first tablet benchmark

- SmolLM2-360M-Instruct Q4_K_M GGUF from
  https://huggingface.co/QuantFactory/SmolLM2-360M-Instruct-GGUF
- Approx. 249 MB. Model has Apache-2.0 licence in the original
  model repository. Verify the model file and licence again before
  final public distribution.
- Download the specific `SmolLM2-360M-Instruct-Q4_K_M.gguf`
  file once, transfer it to the tablet, open the companion and choose
  `Import downloaded GGUF`. Alternatively use the model
  repository button in the companion. The model is private to the app
  after import; it does not require Wi-Fi for later questions.
- Larger Qwen models are NOT the first benchmark on the 3–4 GB Tab A8.

## Tablet build

Start with NetHack Save & Quit. On Windows PowerShell:

    $Script = "$env:TEMP\Build-OfflineCompanion.ps1"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/starez74/Amphitere/feature/offline-ondevice-ai/scripts/Build-OfflineCompanion.ps1" -OutFile $Script
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -Install

The script verifies repo origins and exact main↔frontend commit, initializes
the pinned llama.cpp source, backs up the existing APK, builds the app,
and only uses adb install -r. It never uninstalls, resets saves or
pushes to GitHub. It refuses a wrong origin or wrong native source SHA.
CMake / NDK downloads and native compile may be substantially larger
than the prior Java-only build.

If this first Android compile fails, keep the original app installed and
send the build output. Do NOT manually change the stable branches.

## Acceptance tests before any public release

1. Build completes; the APK contains libnethack_llama.so for arm64-v8a.
2. No model imported: Ask offline AI shows sourced local notes without
   pretending it generated a conversational answer.
3. Import GGUF through Android picker: display says model ready; no crash.
4. Airplane mode ON: Ask offline AI works without server or API token;
   test Monk persona and Factual mode with the same healing question.
5. Repeat 10 questions and measure latency, sustained RAM and device
   heat. Capture native crashes via adb logcat if they occur.
6. Verify NetHack game input, saved character, inventory, D-pad, fixed
   keyboard, menus, and Save & Quit/restore are unchanged.
7. Try unknown questions: model must not pretend to know exact mechanics
   absent from the reference pack. Review citations for accuracy.
8. Determine whether 3 GB devices remain stable; if not, expose a
   reference-only fallback rather than requiring model inference.
9. Before public distribution: model redistribution rules, NetHackWiki
   attribution/share-alike, open-source library licences, update integrity
   verification, memory safety and accessibility must all pass review.

This is a **prototype**, not a claim that a 360M-parameter model can
reliably reason about NetHack. The offline factual reference pack may
prove more accurate than generative output on weaker tablets.

Sources:
- https://github.com/ggml-org/llama.cpp/blob/master/docs/android.md
- https://huggingface.co/QuantFactory/SmolLM2-360M-Instruct-GGUF
- https://nethackwiki.com/wiki/NetHackWiki:Copyrights
