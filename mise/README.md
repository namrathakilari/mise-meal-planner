# Mise - Plan the week. Shop once.

A Flutter web app with a small Node backend. Plan breakfast, lunch and dinner for each day of the
week, and the grocery list **builds itself** from your plan: matching ingredients are added up,
grouped by aisle, and you tick them off while shopping.

New in this version:

- **Real-time sync.** Create a household, share the 6-character code, and every device sees edits
  instantly (meals, plan, grocery checkmarks), including "who is online". Works offline too:
  edits are saved locally and synced when the connection returns.
- **AI features (Groq).** Generate a meal from a description, fill the week's empty slots from
  your preferences, and smart-merge duplicate ingredients ("Tomato" + "Tomatoes").
  Without an API key the server uses a built-in offline engine, so the buttons always work.

The app still works with no server at all (local-only mode, data in the browser).

## Quick start

You need Node 18+ and the Flutter SDK (3.19 or newer).

```bash
# 1. Backend (sync + AI)
cd server
npm install
cp .env.example .env        # then paste your key: GROQ_API_KEY=gsk_...
npm start                   # http://localhost:8787

# 2. Frontend (new terminal, project root)
flutter create . --platforms=web --project-name mise   # one time
flutter pub get
flutter run -d chrome
```

Click the cloud chip ("Local only") at the top of the app, then **Create a household**. Open the
app in a second browser window, choose **Join**, enter the code, and edit in one window to watch
the other update live.

Get a Groq API key at https://console.groq.com. The key lives only in `server/.env`; it is
never sent to the browser. Check `http://localhost:8787/api/health`: `"ai":"groq"` means the key
is active, `"ai":"offline"` means the built-in engine is being used. Set `GROQ_MODEL` in `.env`
to use a different Groq model (see https://console.groq.com/docs/models).

### One-server deployment

```bash
flutter build web --release
cd server && npm install && npm start
```

The server detects `build/web` and serves the app and the API from the same address, so the app
connects with no configuration. Host it anywhere that runs Node (Render, Railway, Fly.io, a VPS);
set `GROQ_API_KEY` and, if the disk is ephemeral, `DATA_DIR` to a persistent volume.
If you host the frontend separately, build it with
`flutter build web --dart-define=MISE_API=https://your-server.example.com`.

### Server tests

```bash
cd server && npm test      # realtime sync between two clients, AI endpoints, Groq fallback (mocked)
```

## Server API

| Route | Purpose |
| --- | --- |
| `GET /api/health` | `{ai: "groq" or "offline"}` |
| `POST /api/households` | create a household, returns `{code}` |
| `GET /api/households/:code` | does it exist |
| `POST /api/ai/meal` | `{prompt, servings}` to a generated meal |
| `POST /api/ai/plan` | `{preferences, meals, slots, allowNew}` to slot assignments (+ new meals) |
| `POST /api/ai/normalize` | `{names}` to `{aliases}` for smart merge |
| `WS /ws?code=ABC234` | live channel: server sends `state`, `ops`, `presence`; client sends `ops`, `snapshot`, `replace` |

Sync is operation based (`meal.set`, `meal.del`, `plan.set`, `plan.del`, `check.set`,
`alias.set`), so two people editing different slots never overwrite each other; for the same
slot the last write wins. AI endpoints are rate-limited per IP (20 per minute).

Security note: there are no accounts. The household code is the secret, so anyone who has it can
edit that household. Treat it like a shared-document link.

## Run it (frontend only)

You need the Flutter SDK (3.19 or newer). Install: https://docs.flutter.dev/get-started/install

```bash
cd mise

# 1. One-time: generate the web/ folder for your Flutter version (keeps all existing code)
flutter create . --platforms=web --project-name mise

# 2. Install packages
flutter pub get

# 3. Run in Chrome
flutter run -d chrome
```

If `flutter create` adds `test/widget_test.dart`, delete that file (it is the default counter test).

Run the unit tests: `flutter test`

Build for submission / hosting:

```bash
flutter build web --release
# output is in build/web  ->  test locally:
cd build/web && python3 -m http.server 8080     # then open http://localhost:8080
```

GitHub Pages: `flutter build web --release --base-href "/<your-repo-name>/"` and publish `build/web`.

## What to demo (30 seconds)

1. Open the app: sample meals and a pre-filled week are already there.
2. **Meal plan** tab: Monday has Shakshuka (breakfast) and Pasta pomodoro (dinner).
3. **Grocery list** tab: Tomato shows **10**, Garlic **6 cloves**. Tap items to check them off.
4. Go back, change a meal, return: the list updates instantly.
5. Press the next-week arrow: the list is empty and checkmarks are gone (they are stored per week).
6. Resize the browser: the desktop grid turns into day chips on a narrow window.
7. Meal library: add a new meal (autocomplete reuses ingredients), delete one and press Undo.

## Features

- Weekly planner (7 days x 3 meals), week navigation, "copy last week", "clear week" with undo
- Meal library: create / edit / delete, emoji + colour tags, servings, live preview
- Ingredient editor with autocomplete, fractions ("1/2", "1 1/2"), "to taste" items, validation
- Grocery list computed from the plan: sums quantities, groups by category, shows which meals need
  each item, progress bar, copy-to-clipboard, per-week checkmarks
- Responsive: sidebar + grid on desktop, bottom navigation + day view on mobile
- Light and dark mode, persistence across refreshes, unit tests for the aggregation logic
- Real-time household sync with offline queue, presence, and auto-reconnect
- AI: meal generator, one-tap week planner, smart ingredient merging

## Code map

```
lib/
  main.dart                      app entry, providers, theme
  models/models.dart             Meal, RecipeIngredient, GroceryItem (pure Dart)
  services/grocery_service.dart  plan -> grocery list aggregation (pure, unit-tested)
  services/storage_service.dart  JSON persistence
  services/api_client.dart       HTTP client for households + AI endpoints
  services/sync_service.dart     WebSocket client: reconnect, offline queue
  services/config.dart           default server address
  state/app_state.dart           ChangeNotifier holding all app state
  utils/formatters.dart          dates, quantity parsing / formatting (pure Dart)
  data/sample_data.dart          demo meals and a demo week
  theme/app_theme.dart           palette, fonts (Fraunces + DM Sans), light/dark themes
  screens/                       home_shell, plan, meals, meal_editor, grocery
  widgets/                       meal_slot_card, meal_picker_sheet, common,
                                 sync_sheet (sync chip + dialog), ai_dialogs
server/
  server.js                      Express + WebSocket (rooms per household)
  store.js                       household state, validation, JSON file persistence
  ai.js                          Groq calls with validation + offline fallback
  offline_recipes.js             built-in recipe engine used without an API key
  test/smoke.js                  end-to-end test
test/grocery_service_test.dart   unit tests
```

## Design decisions (good for your report)

- **Derived state**: the grocery list is never stored. `GroceryService.aggregate` recomputes it from
  the plan, so it can never go out of sync.
- **Different units are not converted**: 2 cloves garlic and 1 tsp garlic stay as two rows.
- **Deleting a planned meal** removes it from the plan and offers Undo.
- **Checkmarks are keyed by week**, so a new week starts clean automatically.
- **Local-first, sync optional**: the browser copy is always the working copy; the server relays
  and stores changes. Joining an empty household uploads your data; joining an existing one loads
  theirs.
- **AI output is validated server-side** (units, categories, quantities, ids) before it reaches the
  app, and AI-generated meals open in the editor for review before saving.
- "tomato" vs "tomatoes": use **Grocery list > AI tools > Smart merge**; merges are stored per
  household and can be undone.
