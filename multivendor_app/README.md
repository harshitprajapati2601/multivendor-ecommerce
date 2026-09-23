# MultiMart — Flutter Frontend

A complete, professionally-designed Flutter client for your **Multi-Vendor E-Commerce Spring Boot backend**.
It was built by reading your actual controllers, DTOs, entities and security config, so every screen maps
directly to a real endpoint your backend exposes — no guessed or invented APIs.

## What's included

Three role-aware experiences behind one login screen (the app reads the `role` returned by `/auth/login`
and routes automatically):

**Customer**
- Browse products — search, category filter, price/rating filter, sort, infinite scroll
- Product detail — description, price, stock, rating, real product photos, reviews (write / delete your own)
- Cart — add/update/remove items, live totals
- Checkout — places the order against your mock payment gateway
- Order history & order detail — cancel a `PLACED` order
- Profile — tap-to-change profile picture, phone number OTP verification, logout

**Seller**
- My Products — create, edit, deactivate, **upload/change a product photo**
- Restock — add inventory to a product
- Reminder banner that a shop needs admin approval before products go live (matches your
  `SellerNotApprovedException` flow)

**Admin**
- Approve pending sellers
- Manage categories (create / edit / delete)
- Reports — revenue by category, top-selling products, top sellers
- Order lookup — enter an order ID to mark it shipped / delivered (your backend has no "list all
  orders" endpoint for admins, only per-ID actions, so this mirrors that exactly)

Auth covers: register (customer or seller, with shop fields), email OTP verification + resend,
password login, passwordless OTP login, JWT access + refresh tokens with **automatic silent refresh**
on 401s, and logout. The login, register, verify-email and OTP-login screens are all a centered
card with a centered logo, on a soft tinted background.

> Every authenticated user (customer, seller, admin) can tap their avatar on the Profile/Account
> screen to upload a profile picture. Sellers can tap a product's thumbnail (in "My Products") or
> the photo box at the top of the product form to add/replace its photo. Both are backed by real
> upload endpoints added to your backend — see "Backend changes" below.

## Backend changes required

**Your original backend has no image storage at all** — no image field on `Product`, no profile
picture on `User`, no upload endpoint. To make photo upload actually work, this delivery includes
an **updated copy of your Spring Boot backend** alongside the Flutter app, with these additions:

- `Product.imageUrl` and `User.profileImageUrl` columns (nullable — nothing breaks for existing rows)
- `FileStorageService` — validates (type, 5MB max) and saves images to `uploads/products/` or
  `uploads/avatars/` on local disk
- Files are served back publicly at `GET /uploads/**`
- `POST /api/products/{id}/image` (seller, must own the product) — multipart field name `file`
- `GET /api/account/me` and `POST /api/account/profile-picture` (any authenticated user) — multipart
  field name `file`

Rebuild/restart your backend with these changes before testing photo upload from the app. If you're
running the backend as-is without these changes, everything else in the app still works — the
photo-upload calls will simply 404/405 until you apply them.

## Project structure

```
lib/
  core/        # API client (Dio + auto-refresh), theme, secure storage, constants
  models/      # Plain Dart models matching your DTOs exactly
  services/    # One file per backend controller (auth, product, cart, order, review, inventory, admin, report, category)
  providers/   # State management (Provider/ChangeNotifier) per feature
  screens/     # auth/, customer/, seller/, admin/ + shared account screen
  widgets/     # Reusable UI: buttons, fields, cards, badges, empty/error states
```

## Setup

### 1. Generate the native platform folders

This delivery contains Dart source only (`lib/`, `pubspec.yaml`). Flutter needs native
`android/`, `ios/`, etc. folders that are specific to your installed Flutter SDK version, so
generate them once:

```bash
cd multivendor_app
flutter create . --project-name multivendor_app --org com.yourcompany
flutter pub get
```

This won't touch your `lib/` folder — it only fills in the missing platform scaffolding.

### 2. Point the app at your backend

Your backend runs on `http://localhost:8080/api`. Which URL to use from the Flutter app depends
on where it runs (see the comment in `lib/core/constants.dart`):

| Run target          | Base URL                       |
|----------------------|---------------------------------|
| Android emulator      | `http://10.0.2.2:8080/api` (default) |
| iOS simulator          | `http://localhost:8080/api`    |
| Physical device        | `http://<your-computer-LAN-IP>:8080/api` |
| Chrome (web)            | `http://localhost:8080/api` (needs CORS enabled on the backend) |

Either edit the default in `lib/core/constants.dart`, or override at launch:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8080/api
```

### 3. Allow plain HTTP while developing

Since your local backend runs on `http://` (not `https://`), allow cleartext traffic:

- **Android**: in `android/app/src/main/AndroidManifest.xml`, add
  `android:usesCleartextTraffic="true"` to the `<application>` tag.
- **iOS**: in `ios/Runner/Info.plist`, add an `NSAppTransportSecurity` exception for your dev host,
  or use `NSAllowsArbitraryLoads` for local development only.

(Skip this once your backend is deployed behind HTTPS.)

### 4. Enable the photo picker (camera + gallery)

The `image_picker` package needs a couple of permission entries that `flutter create .` doesn't
add by default:

- **iOS**: in `ios/Runner/Info.plist`, add:
  ```xml
  <key>NSCameraUsageDescription</key>
  <string>Used to take a photo for your product listing or profile picture.</string>
  <key>NSPhotoLibraryUsageDescription</key>
  <string>Used to choose a photo for your product listing or profile picture.</string>
  ```
- **Android**: no manifest changes needed for the gallery picker on modern Android (it uses the
  system Photo Picker). If you target older Android versions and want the camera option to work,
  make sure `android/app/src/main/AndroidManifest.xml` includes:
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  ```

### 5. Run it

```bash
flutter run
```

Make sure your Spring Boot backend is running first (`http://localhost:8080` by default, per your
`application.properties`).

## Trying it out

1. Register as a **Customer** — you'll be asked to verify your email with the OTP your backend
   emails/logs (check your mail-sending config or logs, depending on how you configured it).
2. Log in, browse products, add to cart, and place an order.
3. Register a second account as a **Seller** and verify its email too. Products won't be creatable
   until an admin approves the shop.
4. Register (or seed) an **Admin** account, log in, and approve the pending seller from the
   "Sellers" tab.
5. Log back in as the seller to create products, then check them as the customer.

## Notes

- All API calls are typed and centralized in `lib/services/` — if you change a DTO shape on the
  backend, update the matching model in `lib/models/` and you're done.
- `lib/core/api_client.dart` automatically retries a request once after refreshing the access
  token on a 401, and logs the session out if the refresh token itself is invalid/expired.
- State is kept simple and explicit with `provider` — no code generation step required.
