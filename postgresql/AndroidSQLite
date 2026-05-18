# Reconstructing a “Personal Chronology” with Android's SQLite

## Context

My partner maintains a long-running music library on her phone where the order of acquisition and listening functions as a kind of personal timeline, relying on the file system's timestamps. After moving ~500 audio files from internal storage to an SD card, virtually every file now showed the same creation date, and any music player sorting by date added/modified became meaningless. One destructive step (bulk move) thus erased her personal history of musical discovery.

## The Problem

**Goal:** Recover (or reconstruct) the original personal order of music files, and make this ordering durable against future changes.

**Constraints:**
- File system timestamps flattened during the move.
- Android's media cataloguing is handled by MediaStore rather than through direct file browsing for many apps, with implementations varying by device.
- The raw SQLite MediaStore database is inaccessible without root.
- Output needs to be usable in a real music player via an external playlist (.m3u), preserving a stable and explicit order.

## Workflow

### 1. Querying MediaStore

I connected the phone via USB debugging and used ADB (Android Debug Bridge) in Windows cmd to query the audio catalogue through MediaStore content URIs.

```
adb version    # verifying ADB runs
adb devices
```
