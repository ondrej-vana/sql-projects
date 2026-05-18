# Reconstructing a “Personal Chronology” from Media Metadata

**Technology used:**

- Android's SQLite
- Windows cmd
- Power Query and the M language

## Context

My friend maintains a long-running music library on her phone where the order of acquisition and listening functions as a kind of personal timeline, relying on the file system's timestamps. After moving ~500 audio files from internal storage to an SD card, virtually every file now showed the same creation date, and any music player sorting by date added/modified became meaningless. One destructive step (bulk move) thus erased her personal history of musical discovery.

## The Problem

**Goal:** Recover (or reconstruct) the original personal order of music files, and make this ordering durable against future changes.

**Constraints:**
- File system timestamps flattened during the move.
- Android's media cataloguing is handled by MediaStore rather than through direct file browsing for many apps, with implementations varying by device.
- The raw SQLite MediaStore database is inaccessible without root.
- Output needs to be usable in a real music player via an external playlist (.m3u), preserving a stable and explicit order.

## Workflow

### 1. Querying MediaStore in Windows cmd

I connected the phone via USB debugging and used ADB (Android Debug Bridge) in **Windows cmd** to query the audio catalogue through MediaStore content URIs.

```cmd
adb version                              # verifying ADB runs
adb devices                              # checking the connection
adb shell content query ^
  --uri "content://media/external/audio/media" ^
  --projection "_data:title:artist:date_added:date_modified" ^
  --sort "date_added" ^
  > mediastore_audio_by_modified.txt     # extracting the timestamps into a .txt file
```

<details>
<summary>Sample output of the query.</summary>

>Row: 0 _data=/storage/emulated/0/Download/Bonnie Grace - The Goths (Epidemic Sound).mp3, title=Bonnie Grace - The Goths (Epidemic Sound), artist=&lt;unknown&gt;, date_added=1775681230, date_modified=1645089064
>
>Row: 1 _data=/storage/emulated/0/Download/Politik.mp3, title=Politik, artist=&lt;unknown&gt;, date_added=1775681230, date_modified=1649766663
>
>Row: 2 _data=/storage/emulated/0/Download/Kıraç - Siyah Gece (Official Audio).mp3, title=Kıraç - Siyah Gece (Official Audio), artist=&lt;unknown&gt;, date_added=1775681230, date_modified=1645010740
>
>Row: 3 _data=/storage/emulated/0/Download/Can Ozan - Toprak Yağmura.mp3, title=Toprak Yağmura, artist=Can Ozan , date_added=1775681230, date_modified=1679602729
>
>Row: 4 _data=/storage/emulated/0/Download/Istanbul Not Constantinople.mp3, title=Istanbul Not Constantinople, artist=&lt;unknown&gt;, date_added=1775681230, date_modified=1708718458
>
>Row: 5 _data=/storage/emulated/0/Download/Plastic Bertrand - Ça Plane Pour Moi.mp3, title=Plastic Bertrand - Ça Plane Pour Moi, artist=<&lt;unknown&gt;, date_added=1775681230, date_modified=1648583821

</details>

### 2. Parsing the Output in Power Query Editor

ADB content query output is not CSV. It uses comma separators between <code>key=value</code> pairs, but **values may contain commas** (e.g. titles), which breaks my original attempts at naive splitting. So I built a safer parser logic in **Power Query**, splitting on <code>", title="</code>, <code>", date_added="</code> etc.

### 3. Normalizing Timestamps in Power Query M

MediaStore timestamps are Unix epoch seconds (e.g. 1775681230), that is seconds elapsed since January 1st 1970. I converted these into a comparable datetime using a custom column specified in **Power Query M**:

```M
= Table.AddColumn(#"PreviousStep", "DateAdded", each #duration(0,0,0,[DateAddedUnix]) + #datetime(1970,1,1,0,0,0))
```

### 4. Preserving the Order in an .m3u Playlist

Finally, I encoded the order into a playlist file. I had to first validate that the phone's music player can handle relative paths when the playlist sits inside the same folder, making for a more portable solution. To avoid encoding issues with non-ASCII characters, I used the .m3u8 (UTF-8) standard.

<details><summary>Sample of the playlist content.</summary>

>#EXTM3U
>
>[MV] 포맨(4MEN) - 하루 __ 불가살(Bulgasal_ Immortal Souls) OST Part.1.mp3
>
>Rema x Mohamed  Ramadan x Patoranking - PLAYERS l Produced by RedOne.mp3
>
>Amr Diab...Illa Habebe  عمرو دياب...الا حبيبى.mp3
>
>Sherine - Nassay  شيرين - نساي.mp3
>
>Verdi La Traviata - III.Act - Gypsy and Picadors Chorus Noi siamo zingarelle.mp3

</details>

---

→ [Return to my SQL Portfolio.](/../../)
