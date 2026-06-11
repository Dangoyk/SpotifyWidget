# Spotify Quick Add (A+)

An iPhone app with **configurable Home Screen widgets**. Each widget is assigned to one Spotify playlist when you add it from the widget gallery.

**Example:**
- Widget 1 → Favorites
- Widget 2 → Gym
- Widget 3 → Road Trip

Tap a widget's **Add Current Song** button to add whatever is currently playing in Spotify to **that widget's playlist** — no playlist picker each time.

## What you need

- A Mac with **Xcode 15+**
- An iPhone running **iOS 17+**
- A free **Apple ID** (for signing the app to your device)
- A **Spotify account**
- A **Spotify Developer** app Client ID

---

## Part 1: Spotify Developer Setup

### 1. Open the Spotify Developer Dashboard

Go to [https://developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) and sign in with your Spotify account.

If this is your first time, accept the developer terms when prompted.

### 2. Create a new app

1. Click **Create app**
2. **App name:** `Spotify Quick Add`
3. **App description:** anything descriptive (e.g. "Adds currently playing songs to a playlist")
4. **Redirect URI:** `spotifyquickadd://callback`
5. Accept the terms and click **Save**

### 3. Copy your Client ID

On your app's page, copy the **Client ID** (not the Client Secret).

### 4. Paste the Client ID into the project

Open:

`SpotifyQuickAdd/SpotifyQuickAdd/Config/SpotifyConfig.swift`

Replace:

```swift
static let clientID = "YOUR_SPOTIFY_CLIENT_ID"
```

with your real Client ID:

```swift
static let clientID = "abc123yourclientid"
```

### 5. Why you should NOT put the Client Secret on iPhone

Spotify gives you a **Client Secret** for server-side apps. Anything embedded in an iPhone app can be extracted from the app binary. This project uses **PKCE**, which is designed for mobile apps **without** a client secret.

Never store the Client Secret in this app.

### 6. What is PKCE?

**PKCE** (Proof Key for Code Exchange) replaces the client secret for mobile apps:

1. The app generates a random **code verifier**
2. It sends a hashed **code challenge** to Spotify when starting login
3. Spotify returns an authorization **code**
4. The app exchanges that code for tokens, proving it has the original verifier

This prevents stolen authorization codes from being used by someone else.

---

## Part 2: Open and Configure the Xcode Project

### 1. Get the project on your Mac

Clone or copy this repository to your Mac, then open:

`SpotifyQuickAdd/SpotifyQuickAdd.xcodeproj`

### 2. Set your development team

1. Select the **SpotifyQuickAdd** project in the navigator
2. Select the **SpotifyQuickAdd** target
3. Open **Signing & Capabilities**
4. Check **Automatically manage signing**
5. Choose your **Team** (your Apple ID)

Repeat for the **SpotifyQuickAddWidgetExtension** target.

### 3. Update bundle identifiers (recommended)

Replace `com.yourname` with something unique to you, e.g. `com.janedoe`:

- App: `com.janedoe.spotifyquickadd`
- Widget: `com.janedoe.spotifyquickadd.widget`

Also update the **App Group** in both entitlements files and in `SpotifyConfig.swift`:

- `group.com.janedoe.spotifyquickadd`

Enable **App Groups** capability on both targets in Xcode if it is not already enabled.

### 4. Verify URL Types (redirect URI)

The project's `Info.plist` already includes the URL scheme. To verify in Xcode:

1. Select the **SpotifyQuickAdd** app target
2. Open the **Info** tab
3. Expand **URL Types**
4. Confirm **URL Schemes** contains: `spotifyquickadd`

This matches the redirect URI registered in Spotify:

`spotifyquickadd://callback`

---

## Part 3: Build to Your iPhone

### 1. Connect your iPhone

Plug in your iPhone and unlock it. Trust the computer if prompted.

### 2. Select your device

In Xcode's toolbar, choose your **iPhone** as the run destination (not a simulator — Spotify playback testing works best on a real device with the Spotify app).

### 3. Build and run

Press **Run** (▶) or `Cmd+R`.

The first time, iOS may block the app because it is signed with your personal Apple ID:

1. On iPhone: **Settings → General → VPN & Device Management**
2. Tap your Apple ID
3. Tap **Trust**

Run the app again from Xcode.

---

## Part 4: Manual Xcode Checklist (A+)

Do these steps yourself in Xcode before building:

### 1. Widget Extension target

The project already includes **SpotifyQuickAddWidgetExtension**. Confirm it appears under **TARGETS** in the project navigator.

### 2. App Groups (both targets)

For **SpotifyQuickAdd** and **SpotifyQuickAddWidgetExtension**:

1. Select the target → **Signing & Capabilities**
2. Confirm **App Groups** is enabled
3. Confirm this group is checked:
   ```
   group.com.yourname.spotifyquickadd
   ```
4. Use the **same** App Group ID in:
   - `SpotifyQuickAdd/SpotifyQuickAdd.entitlements`
   - `SpotifyQuickAddWidget/SpotifyQuickAddWidget.entitlements`
   - `SpotifyQuickAdd/Config/SpotifyConfig.swift` → `appGroupIdentifier`

Replace `com.yourname` with your own identifier everywhere.

### 3. Keychain sharing (both targets)

Both entitlements files include **Keychain Sharing** via `keychain-access-groups`. This lets the widget read Spotify tokens saved by the main app. No extra step needed if entitlements match.

If the widget says login is required even after signing in, set your Apple Team ID in `SpotifyConfig.swift`:

```swift
static let appleTeamID: String? = "YOUR10CHARTEAMID"
```

Find it in Xcode under **Signing & Capabilities** → **Team**, or at [developer.apple.com/account](https://developer.apple.com/account).

### 4. URL scheme (main app only)

Confirm **SpotifyQuickAdd** target → **Info** → **URL Types** → URL Schemes:

```
spotifyquickadd
```

### 5. Spotify redirect URI

In Spotify Developer Dashboard, confirm:

```
spotifyquickadd://callback
```

### 6. Build to physical iPhone

Select your iPhone as run destination → **Run** (`Cmd+R`).

---

## Part 5: First-Time App Setup

1. Open **Spotify Quick Add** on your iPhone
2. Tap **Sign In with Spotify** and approve permissions
3. Tap **Fetch Playlists** (required — caches playlists for widget configuration)
4. Optionally select a playlist and tap **Test Add Current Song** to verify in the app

---

## Part 6: Add and Configure Widgets (A+)

You can add **multiple widgets**, each with a **different playlist** — on the Home Screen or Lock Screen.

### Home Screen widgets

1. Long-press the Home Screen → tap **+**
2. Search **Spotify Quick Add**
3. Pick **Small** or **Medium** → **Add Widget**
4. When prompted, **choose a playlist** (e.g. Favorites)
5. Tap **Done**
6. Repeat to add more widgets with different playlists (Gym, Road Trip, etc.)

### Lock Screen widgets

1. Wake your iPhone and **touch and hold** the Lock Screen
2. Tap **Customize** → tap the **widget area** above or below the time
3. Tap **+** and search **Spotify Quick Add**
4. Pick a style:
   - **Inline** — one line: “Add to [Playlist]”
   - **Circular** — tap the **+** button
   - **Rectangular** — playlist name + “Tap to add current song”
5. **Choose a playlist** when prompted
6. Tap **Done** twice to save

Lock Screen widgets use the same playlist configuration as Home Screen widgets. You still need to **Sign in** and **Fetch Playlists** in the app first.

### Using a widget

1. Play a song in the **Spotify** app
2. Tap **Add Current Song** on the widget
3. The widget shows the result with **album art**, **song name**, and **artist** (wrapped text), for example:
   - Album cover + **Song Name** / Artist
   - ❌ Nothing is currently playing.
   - ❌ Spotify login required. Open the app to sign in.
   - ❌ Please configure this widget with a playlist.
   - ❌ This song is already in that playlist.

### Reconfigure a widget

Long-press the widget → **Edit Widget** → change the playlist.

---

## Architecture

| Component | Role |
|-----------|------|
| `SpotifyAuthService` | OAuth PKCE login UI |
| `SpotifyTokenProvider` | Shared token refresh + Keychain |
| `SpotifyAPIService` | Spotify Web API calls |
| `PlaylistManager` | Add-song workflow and duplicate detection |
| `KeychainManager` | Secure token storage (shared via Keychain groups) |
| `SharedStorage` | App Group: cached playlists, widget status |
| `ConfigurePlaylistWidgetIntent` | Per-widget playlist configuration |
| `AddCurrentSongIntent` | Widget button: add song to configured playlist |
| `SettingsViewModel` | MVVM app UI logic |

## Spotify API scopes used

- `user-read-currently-playing`
- `playlist-modify-private`
- `playlist-modify-public`
- `playlist-read-private`
- `playlist-read-collaborative`

## Spotify Development Mode (important)

If your Spotify app is in **Development Mode**:

1. The **app owner** must have **Spotify Premium**
2. Each Spotify account that signs into your iPhone app must be added under **User Management** in the Developer Dashboard
3. Spotify changed playlist APIs in **February 2026** — this project uses the new `/playlists/{id}/items` endpoints (not the old `/tracks` endpoints)

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Login fails immediately | Check Client ID and redirect URI in Spotify Dashboard |
| "INVALID_CLIENT" | Client ID typo or redirect URI mismatch |
| Permission denied on add | Use a playlist **you own** (not followed/mixes); sign out/in after updating; confirm account is in User Management |
| Playlists won't load | Sign out and sign in again |
| No playlists in widget config | Open app → Sign in → wait for green “X playlists ready” message. Confirm App Groups match on both targets. Delete and re-add the widget after fetching. |
| Widget shows login required | Open app and sign in to Spotify |
| Widget does nothing | Configure widget with a playlist; play music in Spotify first |
| App Groups error | Match App Group ID in entitlements and `SpotifyConfig.swift` |
| Build signing error | Set Team on both app and widget targets |

## License

Personal use. Spotify is a trademark of Spotify AB.
