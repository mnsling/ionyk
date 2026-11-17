# IONYK Systems v0.3 — Keyboard-first POS UI prototype

This update preserves the previous login page, Admin/Cashier separation, dashboard and Products → Import Excel placeholder. It replaces the cashier's sample static POS view with a working **in-memory** cart and keyboard checkout prototype.

## Setup (Windows)

Prerequisites: Flutter SDK, Visual Studio with Desktop development with C++, VS Code, Flutter/Dart extensions, Git (optional).

1. Extract this zip to `C:\Projects\ionyk_systems_starter` (or another location).
2. Open PowerShell in that **folder**.
3. Run:

```powershell
flutter doctor -v
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

The initial `flutter create` generates missing Windows runner files. If starting from the older version 0.2, back up that folder and copy **both** `lib/main.dart` and `lib/keyboard_pos.dart` from this version; replacing `main.dart` alone will not work.

## Access

Select **Cashier** on the demonstration login page, then go to **Point of sale**. The login remains a role-selection preview, not authenticated production security. Admin does not get a checkout page.

## Keyboard workflow

| Keys/input | Action |
|---|---|
| `4800012345678` then Enter | Add 1 item; repeated scanning increments quantity |
| `12*4800012345678` then Enter | Add 12 items in one scan (quantity prefix) |
| F2 | Focus and clear barcode input |
| F4 | Edit quantity of selected line; type number then Enter |
| Ctrl+Up / Ctrl+Down | Move selected cart line |
| Ctrl+Backspace | Remove selected line (**demo only**, without manager authorization) |
| F8 | Payment preview; type cash received then Enter |
| Escape | Return focus to barcode input outside modal dialogs |

Example demo barcodes: `4800012345678` (Coke), `4800098765432` (Piattos), `4800024681357` (Lucky Me), `4800086420357` (Nescafe), `4800033333333` (Nova).

A USB barcode scanner acting as a keyboard wedge should be configured to append **Enter** after each scan. For bulk quantity input: type `12*` on the physical keyboard, then scan the barcode (scanner sends Enter).

## Important limitations

- **Not a functioning retail POS:** no database, server, tax computation, real payment, invoicing, printing, persistence, audit logging, stock deduction, or BIR approval.
- Cart uses fabricated product/price data and is cleared on app restart.
- `F8` only calculates a **payment preview**; it does not commit or clear a sale.
- Quantity supports whole units 1–9999. Weighted products/fractional quantities need a later design.
- The demo remove shortcut has no supervisor verification. Add secure authorization and transaction audit trails before real deployment.
- Multiple terminals and price sync are **not** connected in this prototype.
- Excel import under Admin → Products remains a placeholder with undecided column mapping.
- Flutter was not available in the authoring runtime, so this version was not compiled on Windows. Run `flutter analyze` locally and share errors if any.

## Source files

- `lib/main.dart` — existing UI shell with role-based navigation, dashboard, and import placeholder.
- `lib/keyboard_pos.dart` — new interactive keyboard-only cashier POS prototype.
- `pubspec.yaml` — Flutter/Google Fonts dependencies.
