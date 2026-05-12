# JSS Air Express — Bill Management App

A Flutter mobile app built for **JSS Air Express** to manage courier billing, generate invoices, and export them as PDF or Excel. Built as a family-use internal tool.

---

## Branches

| Branch | Description |
|--------|-------------|
| `main` | Latest version — includes Google Drive sync for multi-device use |
| `no-sync` | Offline-only version — no internet required, data stays on device |

---

## Features

### Bill Management
- Create and manage multiple parties (clients)
- Create bills per party with a unique bill number and date
- Add, edit, and delete entries per bill (AWB no., date, weight, mode, destination, client name, amount)
- Duplicate AWB number detection across all bills

### Totals & Tax
- Auto-calculated gross total, fuel charges, CGST, SGST, and net amount
- Configurable tax percentages per bill

### Export
- **PDF** — professional A4 invoice with company header, party details, itemised table, tax breakup, amount in words, bank details, and authorised signature
- **Excel (.xlsx)** — same data in spreadsheet format, styled with colour-coded rows

### Amount in Words
- Net amount automatically converted to Indian number system words (lakhs, crores)
- Displayed as a navy blue highlighted band above bank details in both PDF and Excel

### Company Settings
- Editable company name, address, phone, email, GST number
- Editable bank details (account number, IFSC, branch)
- Support for extra custom fields on invoices

### Autocomplete
- Destination and client name fields autocomplete from past entries

---

## Google Drive Sync (`main` branch only)

All three family members use the same Gmail account. The app syncs data through Google Drive's App Data folder (hidden from Drive UI, uses the account's free 15 GB).

**Sync behaviour:**
- On app launch — pulls latest data from Drive and merges
- While app is open — polls Drive every 4 seconds; downloads only if something changed
- On every save — instantly pushes to Drive
- App backgrounded — all sync pauses, no battery/data drain
- Offline — app works normally, syncs when back online

**Merge strategy:** Entries are unioned by unique ID — if two people add entries simultaneously, neither is lost.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State management | Provider + ChangeNotifier |
| Local storage | shared_preferences |
| PDF generation | pdf package |
| Excel generation | excel package |
| Google auth | google_sign_in |
| Drive API | HTTP REST (no googleapis package) |
| UI | Material 3, custom navy blue theme |

---

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── bill.dart
│   ├── company_info.dart
│   ├── entry.dart
│   ├── party.dart
│   └── totals.dart
├── providers/
│   └── app_provider.dart
├── screens/
│   ├── all_bills_screen.dart
│   ├── bill_list_screen.dart
│   ├── bill_preview_screen.dart
│   ├── company_info_screen.dart
│   ├── entry_screen.dart
│   ├── home_screen.dart
│   └── parties_screen.dart
├── services/
│   └── drive_sync_service.dart     ← main branch only
├── utils/
│   ├── bill_exporter.dart
│   ├── helpers.dart
│   └── theme.dart
└── widgets/
    ├── common_widgets.dart
    └── sync_button.dart            ← main branch only
```

---

## Setup — Google Drive Sync (main branch)

Follow `SETUP.md` in the root of the project for the full step-by-step Google Cloud Console configuration. It takes about 20 minutes and is completely free.

---

## Getting Started

```bash
# Clone the repo
git clone https://github.com/yourname/jss-air-express.git

# Switch to the branch you want
git checkout main        # sync version
git checkout no-sync     # offline version

# Install dependencies
flutter pub get

# Run the app
flutter run
```

---

## Built By

Personal project built for JSS Air Express, Bangalore.  
A family courier billing tool — not intended for public distribution.
