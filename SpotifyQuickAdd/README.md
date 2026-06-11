# Spotify Quick Add

An iPhone app with a Home Screen widget that adds your currently playing Spotify track to a playlist you choose.

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

## Part 4: First-Time App Setup

1. Open **Spotify Quick Add** on your iPhone
2. Tap **Sign In with Spotify** and approve permissions
3. Tap **Fetch Playlists**
4. Select the playlist you want songs added to
5. Tap **Test Add Current Song** to verify (play something in Spotify first)

---

## Part 5: Add the Home Screen Widget

1. Long-press your iPhone Home Screen
2. Tap **+** (top left)
3. Search for **Spotify Quick Add**
4. Choose a widget size and tap **Add Widget**
5. Tap the widget's **Add Current Song** button

The widget opens the app, which:

1. Reads your selected playlist
2. Fetches your currently playing track
3. Checks if the song is already in the playlist (paginated search)
4. Adds it if not already present
5. Shows a success or error message

---

## Architecture

| Component | Role |
|-----------|------|
| `SpotifyAuthService` | OAuth PKCE login, token refresh, Keychain storage |
| `SpotifyAPIService` | Spotify Web API calls |
| `PlaylistManager` | Add-song workflow and duplicate detection |
| `KeychainManager` | Secure token storage |
| `SharedStorage` | App Group storage for selected playlist |
| `SettingsViewModel` / `AddSongViewModel` | MVVM UI logic |

## Spotify API scopes used

- `user-read-currently-playing`
- `playlist-modify-private`
- `playlist-modify-public`
- `playlist-read-private`
- `playlist-read-collaborative`

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Login fails immediately | Check Client ID and redirect URI in Spotify Dashboard |
| "INVALID_CLIENT" | Client ID typo or redirect URI mismatch |
| Playlists won't load | Sign out and sign in again |
| Widget does nothing | Open app once, sign in, select a playlist |
| App Groups error | Match App Group ID in entitlements and `SpotifyConfig.swift` |
| Build signing error | Set Team on both app and widget targets |

## License

Personal use. Spotify is a trademark of Spotify AB.
