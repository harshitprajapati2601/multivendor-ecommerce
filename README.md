# MultiMart --- Multi-Vendor E-Commerce Platform

MultiMart is a full-stack multi-vendor e-commerce application built with
a **Spring Boot REST API backend** and a **Flutter mobile frontend**.

The platform provides separate role-aware experiences for **Customers,
Sellers, and Administrators**, with authentication, product management,
inventory, shopping cart, orders, reviews, seller approval, reporting,
and image uploads.

## Project Architecture

``` text
┌──────────────────────────────┐
│       Flutter Frontend       │
│       Android / iOS / Web    │
└──────────────┬───────────────┘
               │ REST API / JSON
               ▼
┌──────────────────────────────┐
│      Spring Boot Backend     │
│  Security • JWT • OAuth2     │
│  Services • Controllers      │
└──────────────┬───────────────┘
               │ JPA / Hibernate
               ▼
┌──────────────────────────────┐
│          MySQL DB            │
└──────────────────────────────┘
```

Uploaded product and profile images are stored on the backend's local
filesystem under `uploads/`.

## Main Features

### Customer

-   Register and verify email with OTP
-   Password login
-   Passwordless OTP login
-   JWT access and refresh tokens
-   Automatic access-token refresh on expired sessions
-   Browse and search products
-   Category filtering
-   Price/rating filtering and sorting
-   Product details and product photos
-   Product reviews
-   Add, update, and remove cart items
-   Checkout and order placement
-   Order history and order details
-   Cancel eligible orders
-   Profile management
-   Profile-picture upload
-   Phone-number OTP verification
-   Logout

### Seller

-   Seller registration with shop information
-   Email verification
-   Seller approval workflow
-   Create products
-   Edit products
-   Deactivate products
-   Product photo upload/change
-   Restock inventory
-   View seller products
-   Seller-specific product management

### Administrator

-   Approve pending sellers
-   Create, edit, and delete categories
-   Order lookup and order-status actions
-   Revenue reports by category
-   Top-selling product reports
-   Top-seller reports

### Authentication & Security

-   Spring Security
-   JWT access tokens
-   JWT refresh tokens
-   Role-based authorization
-   Method-level authorization
-   Password hashing with BCrypt
-   Email verification
-   OTP authentication
-   Google OAuth2 login
-   Automatic refresh of expired access tokens in the Flutter client

## Technology Stack

### Backend

-   Java
-   Spring Boot
-   Spring Security
-   Spring Data JPA
-   Hibernate
-   MySQL
-   Maven
-   JWT
-   OAuth2 / OpenID Connect
-   Lombok
-   REST APIs
-   Multipart file uploads

### Frontend

-   Flutter
-   Dart
-   Provider / ChangeNotifier
-   Dio
-   Secure token storage
-   Image Picker
-   Android

### Development / Deployment

-   Git
-   GitHub
-   Docker / Docker Compose configuration is included as an optional
    setup
-   Swagger / OpenAPI

## Repository Structure

``` text
multivendor-ecommerce/
│
├── .env.example
├── .gitignore
├── README.md
│
├── multivendor-ecommerce/          # Spring Boot backend
│   ├── pom.xml
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── src/
│   │   ├── main/
│   │   └── test/
│   └── uploads/
│       └── .gitkeep
│
└── multivendor_app/                # Flutter frontend
    ├── README.md
    ├── pubspec.yaml
    ├── lib/
    ├── android/
    └── test/
```

## Backend Setup

### Requirements

Install the following before running the backend:

-   JDK 21
-   Maven
-   MySQL 8.x
-   Git

### 1. Create the database

Create a MySQL database:

``` sql
CREATE DATABASE multivendor_db;
```

The application uses environment variables for database credentials.

### 2. Configure environment variables

The backend reads sensitive configuration from environment variables
instead of storing passwords and secrets in source code.

Use the repository's `.env.example` as the reference:

``` text
DB_URL
DB_USERNAME
DB_PASSWORD

JWT_SECRET

MAIL_HOST
MAIL_PORT
MAIL_USERNAME
MAIL_PASSWORD
MAIL_FROM

GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET

ADMIN_EMAIL
ADMIN_PASSWORD

UPLOAD_DIR
```

Do **not** commit real passwords, API secrets, OAuth client secrets, JWT
secrets, or other credentials to GitHub.

### 3. Run the backend

From the backend directory:

``` powershell
cd multivendor-ecommerce
mvn spring-boot:run
```

The backend runs on:

``` text
http://localhost:8080
```

The REST API base path is:

``` text
http://localhost:8080/api
```

## Flutter Setup

### Requirements

Install:

-   Flutter SDK
-   Dart SDK
-   Android Studio and/or an Android device/emulator

From the Flutter directory:

``` powershell
cd multivendor_app
flutter pub get
```

### Configure the Backend URL

The Flutter application supports different backend URLs depending on
where the application runs.

  Run target                Backend URL
  ------------------------- --------------------------------
  Android emulator          `http://10.0.2.2:8080/api`
  iOS simulator             `http://localhost:8080/api`
  Physical Android device   `http://<YOUR-PC-IP>:8080/api`
  Chrome/Web                `http://localhost:8080/api`

For a physical Android device connected to the same network as the
development computer, replace `<YOUR-PC-IP>` with the computer's current
LAN IP.

You can override the URL at launch:

``` powershell
flutter run --dart-define=API_BASE_URL=http://<YOUR-PC-IP>:8080/api
```

Do not commit your local IP address if it is specific to your private
network.

### Run the Flutter application

``` powershell
cd multivendor_app
flutter run
```

Make sure the Spring Boot backend is running before using authenticated
or API-backed features.

## Google OAuth2

Google login requires a Google OAuth 2.0 client configuration and
matching backend configuration.

The repository intentionally does **not** contain the Google client
secret.

Configure these backend environment variables:

``` text
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
```

For the Flutter application, the web client ID used by the app is not a
secret. The OAuth client secret must remain on the backend and must
never be committed to the repository.

For local Spring Boot development, configure the Google OAuth redirect
URI to match the backend configuration, for example:

``` text
http://localhost:8080/login/oauth2/code/google
```

When deploying the application, use the appropriate HTTPS domain and
OAuth configuration for that environment.

## Image Uploads

The backend supports image uploads for:

-   Product images
-   User profile pictures

Runtime files are stored under:

``` text
uploads/
├── products/
└── avatars/
```

Uploaded runtime images are intentionally excluded from Git tracking.
The repository keeps the upload directories available through
`.gitkeep`.

The backend exposes uploaded files through the `/uploads/**` path.

## API Documentation

The backend includes Swagger / OpenAPI support.

When the backend is running, open the Swagger UI using the project's
configured Swagger/OpenAPI endpoint.

Use Swagger to inspect available controllers, request models, response
models, and authentication requirements.

## Authentication Flow

The general authentication flow is:

``` text
Register
   │
   ▼
Email Verification
   │
   ▼
Login / OTP Login / Google Login
   │
   ▼
JWT Access Token + Refresh Token
   │
   ▼
Authenticated API Requests
   │
   ├── Access token expires
   │
   ▼
Automatic refresh
   │
   ▼
Continue authenticated session
```

Role-based access is applied for Customer, Seller, and Admin
functionality.

## Running with Docker

Docker configuration is included in the repository as an optional setup.

Files:

``` text
multivendor-ecommerce/Dockerfile
multivendor-ecommerce/docker-compose.yml
```

The Docker configuration uses environment variables for sensitive
database configuration.

If you use Docker, configure the required environment variables before
starting the services.

The application can also be run directly with Java/Maven and MySQL
without Docker.

## Security

This repository is configured so that sensitive local configuration
should remain outside Git.

The following types of information must never be committed:

-   Database passwords
-   JWT signing secrets
-   Email passwords / app passwords
-   Google OAuth client secrets
-   Admin passwords
-   Private API keys
-   Personal `.env` files
-   Runtime uploaded user files

Before pushing changes, check the staged files:

``` powershell
git status
git diff --cached
```

If a secret has ever been committed publicly, rotate/revoke it and
replace it with a new credential.

## Development Workflow

Clone the repository:

``` powershell
git clone https://github.com/harshitprajapati2601/multivendor-ecommerce.git
cd multivendor-ecommerce
```

Backend:

``` powershell
cd multivendor-ecommerce
mvn spring-boot:run
```

Flutter:

``` powershell
cd ..\multivendor_app
flutter pub get
flutter run
```

## Frontend Documentation

For Flutter-specific information, including screens, providers,
services, API integration, and frontend project structure, see:

[`multivendor_app/README.md`](multivendor_app/README.md)

## Project Status

This repository contains both the Spring Boot backend and Flutter
frontend for the MultiMart application.

The backend and frontend are developed as separate applications that
communicate through REST APIs.

## Author

**Harshit Prajapati**

GitHub: [harshitprajapati2601](https://github.com/harshitprajapati2601)
