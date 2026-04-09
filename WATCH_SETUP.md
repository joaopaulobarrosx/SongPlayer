# Apple Watch companion — Xcode setup

All the source code for the watchOS app and the shared `SongPlayerCore`
Swift Package is already on disk. Xcode needs two one-time steps to wire
them into the project.

## 1. Add the local Swift package

1. Open `SongPlayer.xcodeproj`.
2. `File ▸ Add Package Dependencies…`
3. Click **Add Local…** in the bottom-left.
4. Pick the folder `SongPlayerCore/` (the one containing `Package.swift`).
5. In the "Add to Target" dropdown, pick **SongPlayer** (the iOS app).
   You can leave the iOS app using its existing local copies for now — the
   package is consumed only by the watchOS target in the next step.

> The package already builds clean (`cd SongPlayerCore && swift build`).

## 2. Add the watchOS target

1. `File ▸ New ▸ Target…`
2. Select **watchOS ▸ App**.
3. Fill in:
   - Product Name: **SongPlayerWatch**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Bundle Identifier: `<your iOS bundle id>.watchkitapp` (Xcode prefills this)
   - Include Notification Scene: **off**
   - Include Tests: optional
4. When Xcode asks "Activate `SongPlayerWatch` scheme?", click **Activate**.
5. Xcode creates an empty folder `SongPlayerWatch Watch App/`. **Delete** the
   two boilerplate files it generated (`ContentView.swift` and the `…App.swift`
   file) — the real files are already on disk in that same folder and will
   be picked up automatically by the file-system-synchronized group.
6. In the watchOS target's **General ▸ Frameworks, Libraries, and Embedded
   Content**, click **+** and add the **SongPlayerCore** library.
7. Background audio — Xcode creates an auto-generated Info.plist at
   `SongPlayerWatch-Watch-App-Info.plist` (project root, not inside the
   target folder). That file is already populated in the repo with
   `UIBackgroundModes = [audio]`, so no manual step is required. If Xcode
   regenerates it empty, open the target's **Signing & Capabilities** tab,
   click **+ Capability**, add **Background Modes**, and check **Audio,
   AirPlay, and Picture in Picture**.

> ⚠️ When deleting the boilerplate files Xcode created, only delete
> `ContentView.swift` and any duplicate `*App.swift`. The real entry point
> `SongPlayerWatchApp.swift` is already in the repo inside
> `SongPlayerWatch Watch App/`. If you accidentally delete it, the linker
> will fail with `Undefined symbols: "_main"` — restore it from git.

## 3. Build & run

1. Select the **SongPlayerWatch** scheme.
2. Pick a "Apple Watch Series X (…mm)" simulator.
3. Run. You should see Splash → Home (search + recently played) → Album /
   Player, all driven by the iTunes Search API.

## How it works

- Shared code (`Song`, `SongsViewModel`, `AlbumViewModel`,
  `NetworkService`, `MediaCacheService`, `CachedSong`) lives in the
  `SongPlayerCore` Swift package. Both targets can consume it.
- The watchOS app has its **own** playback service
  (`WatchAudioPlayerService`) because `MPRemoteCommandCenter` /
  `MPNowPlayingInfoCenter` are not available on watchOS. It uses plain
  `AVPlayer` and the same offline cache as the iPhone — so a preview
  played once is available offline on subsequent launches.
- The Watch fetches from the iTunes API directly via `NetworkService`,
  independent of the iPhone. No `WatchConnectivity` is required for a
  functional MVP. If you later want recently-played sync from iPhone →
  Watch, a `WCSession.updateApplicationContext` push is the lightest
  option.

## Future cleanup (optional)

The iOS target still has its own copies of the files that are now also
in `SongPlayerCore`. After you verify the package works for the watch
target, you can:

1. In the iOS target, delete the local files under:
   - `SongPlayer/Models/Song.swift`
   - `SongPlayer/Models/CachedSong.swift`
   - `SongPlayer/Services/Networking/*.swift`
   - `SongPlayer/Services/Cache/MediaCacheService.swift`
   - `SongPlayer/ViewModels/*.swift`
2. Add `import SongPlayerCore` at the top of the iOS views that reference
   those types.
3. Make sure `SongPlayerCore` is linked in the iOS target (step 1 above).

Running the full test suite after each step keeps the refactor safe.
