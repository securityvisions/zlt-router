# Samantel PWA API Documentation
# Captured automatically from live traffic

## Authentication Flow

### 1. Login with OTP
- **Endpoint**: `POST https://pwa.samantel.ir/api/auth/callback/credentials`
- **Method**: NextAuth.js credentials provider
- **Request Body**:
  ```json
  {
    "csrfToken": "<from /api/auth/csrf>",
    "phoneNumber": "09999XXXXXX",
    "otp": "123456",
    "callbackUrl": "https://pwa.samantel.ir/",
    "json": "true"
  }
  ```

### 2. Get CSRF Token
- **Endpoint**: `GET https://pwa.samantel.ir/api/auth/csrf`
- **Response**:
  ```json
  {
    "csrfToken": "71ae2a22c790ef8d81c3ae0812af8f0721a8f0657bbf8027ea81d495d9d925c6"
  }
  ```

### 3. Session Management
- **Endpoint**: `GET https://pwa.samantel.ir/api/auth/session`
- **Response** (after login):
  ```json
  {
    "user": {
      "phoneNumber": "09999985823",
      "defaultPhoneNumber": "09999985823",
      "accessToken": "eyJhbGciOiJIUzI1NiIs...",
      "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
      "simType": 1,
      "simType2": "Y"
    },
    "expires": "2026-09-03T13:35:04.851Z"
  }
  ```

## User Profile APIs

### 4. Get User Profile
- **Endpoint**: `GET https://pwa.samantel.ir/api/SamantelApi/Profile?phoneNumber=09999985823`
- **Response**:
  ```json
  {
    "result": [{
      "PROVINCE": "تهران",
      "CITY": "تهران",
      "NAME": "نام",
      "FAMILY": "نام خانوادگی",
      "CODEMELLI": "0150805721",
      "NUMBER": "9999985823",
      "SIM_TYPE": "سیم کارت دائمی",
      "STATUS": "فعال"
    }],
    "errCode": 0
  }
  ```

### 5. Get Remaining Data & Balance
- **Endpoint**: `GET https://pwa.samantel.ir/api/SamantelApi/Remain?phoneNumber=09999985823`
- **Response**:
  ```json
  {
    "result": [
      {
        "BalanceName": "Benefit Data(Whole Day)",
        "BalanceValue": "-23605890",  // Remaining bytes (negative = used)
        "ExpDate": "2027-08-01 02:03:53",
        "Comments": "دیتا",
        "InternalUsage": -63799703  // Used bytes
      },
      {
        "BalanceName": "Local Currency(IRR)",
        "BalanceValue": "-463727",  // Remaining IRR (negative = used)
        "Comments": "Local Currency|اعتبار ریالی"
      }
    ],
    "errCode": 0
  }
  ```

## Package APIs

### 6. Get Available Packages
- **Endpoint**: `GET https://pwa.samantel.ir/api/SamantelApi/GetPackageList?phoneNumber=09999985823`
- **Response** (example):
  ```json
  {
    "result": [
      {
        "OfferID": "350",
        "OfferName": "1 روزه،1 گیگابایت",
        "totaldata": 1,  // GB
        "price": 126500,  // IRR with tax
        "priceNoTax": 115000,
        "expire": "(کد 533685)1",  // 1 day
        "type": "DATA"
      },
      {
        "OfferID": "385",
        "OfferName": "30 روزه، 8گیگابایت",
        "totaldata": 8,
        "price": 924000,
        "expire": "(کد 534063)30",  // 30 days
        "type": "DATA"
      },
      {
        "OfferID": "619",
        "OfferName": "365 روزه، 150 گیگابایت",
        "totaldata": 150,
        "price": 11550000,
        "expire": "(کد 534063)365",  // 365 days
        "type": "DATA"
      }
    ]
  }
  ```

## Payment Flow

### 7. Initiate Package Purchase
- **Endpoint**: `GET https://pwa.samantel.ir/api/SamantelApi/OrderPackagePay`
- **Parameters**:
  - `Mobile`: Phone number (e.g., 09999985823)
  - `OfferId`: Package ID (e.g., 619)
  - `Success`: Success callback URL
  - `Fail`: Failure callback URL
- **Response**:
  ```json
  {
    "result": {
      "OfferID": "619",
      "OfferName": "365 روزه، 150 گیگابایت",
      "price": 11550000,
      "payURL": "https://ws.samantel.ir/samantel/v1//?method=goforpayv2&token=e7704d1c83074419936dd4e8b53a7d31&pt=PG2608041706227275"
    }
  }
  ```

### 8. Record Payment
- **Endpoint**: `POST https://pwa.samantel.ir/api/Payment/AddPayment`
- **Request Body**:
  ```json
  {
    "serviceType": 5,
    "price": 11550000,
    "transactionId": "PG2608041706227275"
  }
  ```

### 9. Shaparak Payment Gateway
- **URL**: `https://sep.shaparak.ir/OnlinePG/SendToken?token=<token>`
- **Payment Form Fields**:
  - `cardNumber`: 16-digit card number
  - `cvv2`: 3-4 digit CVV
  - `expiryDate`: MM/YY format
  - `password`: Card PIN (for some banks)
  - `captcha`: Captcha code
- **OTP Verification**: Bank sends OTP to phone, submit to verify

## Usage Notes

1. **Token Expiry**: JWT tokens expire after ~1 month
2. **Friday Discount**: 40% discount on all packages every Friday
3. **Data Units**: Balance values are in bytes (divide by 1024^2 for MB, 1024^3 for GB)
4. **Price Units**: Prices are in Iranian Rial (IRR)
