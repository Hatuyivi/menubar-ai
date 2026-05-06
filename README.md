# MenuBar AI — macOS Menubar App

A native macOS menubar app with two AI-powered modules. Requires macOS 13+.

## Build & Run

### Requirements
- macOS 13 (Ventura) or later
- Xcode 15+

### Steps

1. Open Terminal in the `artifacts/macos-app` folder
2. Build with Swift Package Manager:
   ```bash
   swift build -c release
   ```
3. Run:
   ```bash
   swift run
   ```
   Or open in Xcode:
   ```bash
   open Package.swift
   ```
   Then press **⌘R** to build and run.

### First launch

On first launch macOS will ask for **Screen Recording** permission — required for Module 1. Grant it in:
> System Settings → Privacy & Security → Screen Recording → MenuBarAI ✓

The app icon appears in the **top menu bar** (⌘-click to reorder). Click it to open the panel.

---

## Module 1 — Screen OCR

1. Go to **Settings** and add your API key (Gemini, OpenRouter, or Cloudflare)
2. Switch to the **OCR** tab
3. Select your provider and model (only free-tier vision models shown)
4. Click **Select Screen Area** — the screen dims, drag to select any rectangle
5. Click **Recognize Numbers** to extract numbers from the captured area
6. Results appear with a **Copy** button

### Available Models (Module 1 — image → text)

| Provider | Models |
|---|---|
| Gemini | 2.0 Flash, 2.0 Flash Lite, 1.5 Flash, 1.5 Flash 8B |
| OpenRouter | Gemini 2.0 Flash Exp (free), Llama 3.2 90B/11B Vision (free), Qwen2 VL 72B/7B (free) |
| Cloudflare | LLaVA 1.5 7B, UForm Gen2 Qwen 500M, Llama 3.2 11B Vision |

---

## Module 2 — Floor Plan Colliders

1. Go to **Settings** and add your API key
2. Switch to the **Floor Plan** tab
3. Click **Load Floor Plan** and choose a PNG/JPG image
4. Select provider and model, then click **Detect Rooms via API**
5. The API identifies rooms and places colored colliders on them
6. **Resize** colliders by dragging corner handles
7. **Check/uncheck** rooms to include/exclude them
8. Click **Save Selected** to save the layout by name

### Available Models (Module 2 — vision models for room detection)

| Provider | Models |
|---|---|
| Gemini | All Flash models (image → structured JSON) |
| OpenRouter | Llama Vision, Qwen VL (image → structured JSON) |
| Cloudflare | LLaVA, Llama Vision (image → JSON), SD img2img models |

---

## API Key Setup

All keys are stored securely in the **macOS Keychain** (never in plain files).

| Provider | Free Tier | Where to get key |
|---|---|---|
| Gemini | 1,500 req/day (Flash models) | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |
| OpenRouter | Models with `:free` suffix | [openrouter.ai/keys](https://openrouter.ai/keys) |
| Cloudflare | 10,000 neurons/day | [dash.cloudflare.com → API Tokens](https://dash.cloudflare.com/profile/api-tokens) |

For Cloudflare you also need your **Account ID** (found in the right sidebar of the Cloudflare dashboard).

---

## Architecture

- `AppDelegate.swift` — NSStatusItem + NSPopover setup
- `Views/ContentView.swift` — Tab bar host
- `Views/Module1View.swift` — Screen capture + OCR UI
- `Views/Module2View.swift` — Floor plan canvas + collider editor
- `Views/SettingsView.swift` — API key management
- `Views/SharedComponents.swift` — ProviderSelector, ModelPickerView
- `Models/APIModels.swift` — Free model registry, data types
- `Services/GeminiService.swift` — Gemini API calls
- `Services/OpenRouterService.swift` — OpenRouter API calls
- `Services/CloudflareService.swift` — Cloudflare Workers AI calls
- `Services/ScreenCaptureService.swift` — Screen selection overlay
- `Utils/KeychainHelper.swift` — Secure key storage

## Dependencies

**Zero external dependencies.** Uses only:
- SwiftUI (Apple framework)
- AppKit (Apple framework)
- CoreGraphics (Apple framework)
- Security (Apple framework — Keychain)
- Foundation (Apple framework — URLSession, JSON)
