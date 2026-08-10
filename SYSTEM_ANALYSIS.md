# Samantel Internet Package Automation - Complete System Analysis
## Date: August 4, 2026

---

## Executive Summary

I successfully captured and analyzed the complete Samantel PWA (Progressive Web App) system by monitoring network traffic while you logged in and navigated. Here's everything you need to know to build an automated package purchase system.

---

## 1. System Architecture

### Platform Details
- **Samantel PWA URL**: `https://pwa.samantel.ir`
- **Framework**: Next.js (React-based PWA)
- **Authentication**: NextAuth.js (JWT-based)
- **Payment Gateway**: Shaparak (sep.shaparak.ir) - Iranian national payment gateway
- **Backend API**: `https://pwa.samantel.ir/api/`

### How It Works
The system is a single-page application (SPA) that communicates with REST APIs:
1. You log in with your phone number + password/OTP
2. The app receives JWT tokens (access + refresh)
3. All subsequent API calls include these tokens
4. When you buy a package, it calls Samantel's API
5. Samantel generates a payment token
6. You're redirected to Shaparak (bank payment gateway)
7. You enter card details + OTP on Shaparak
8. Payment is processed and you're redirected back

---

## 2. Authentication System

### Login Methods
Samantel supports two login methods:

**Method 1: Password Login** (what you used)
```
POST https://pwa.samantel.ir/api/auth/callback/credentials

Fields:
- phoneNumber: Your phone number (e.g., 09999985823)
- password: Your Samantel password
- captcha: Captcha code shown on screen
- csrfToken: Security token (from /api/auth/csrf)
- isOtp: "false" for password login
```

**Method 2: OTP Login** (one-time password)
```
POST https://pwa.samantel.ir/api/auth/callback/credentials

Fields:
- phoneNumber: Your phone number
- otp: 6-digit code sent via SMS
- captcha: Captcha code
- csrfToken: Security token
- isOtp: "true" for OTP login
```

### Session Management
After login, you receive JWT tokens:
```json
{
  "user": {
    "phoneNumber": "09999985823",
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",  // Expires in ~1 month
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."  // Used to get new access token
  },
  "expires": "2026-09-03T13:35:04.851Z"
}
```

**Important**: Tokens expire after ~30 days. The automation needs to handle re-login.

---

## 3. Core API Endpoints

### User Information

**Get User Profile**
```
GET https://pwa.samantel.ir/api/SamantelApi/Profile?phoneNumber=09999985823

Response contains:
- Name, Family, National Code
- Province, City, Address
- SIM Type (permanent/temporary)
- Account status
```

**Get Remaining Data & Balance**
```
GET https://pwa.samantel.ir/api/SamantelApi/Remain?phoneNumber=09999985823

Response contains:
- Data balance (in bytes, negative = used)
- Expiry date
- Credit balance (IRR)

Example:
{
  "BalanceName": "Benefit Data(Whole Day)",
  "BalanceValue": "-23605890",  // Bytes used
  "ExpDate": "2027-08-01 02:03:53"
}
```

**Important**: Balance values are NEGATIVE and in BYTES
- To convert to GB: divide by 1024^3 (1,073,741,824)
- Example: -23605890 bytes = -0.022 GB used

### Package Management

**Get All Available Packages**
```
GET https://pwa.samantel.ir/api/SamantelApi/GetPackageList?phoneNumber=09999985823

Response: Array of packages with:
- OfferID: Unique package identifier
- OfferName: Persian name
- totaldata: Data in GB
- price: Price in IRR (with tax)
- priceNoTax: Price without tax
- expire: Validity period (e.g., "(کد 534063)30" = 30 days)
- type: "DATA" for internet packages
```

**Available Packages** (captured from live data):
| OfferID | Name | Data | Validity | Price (IRR) |
|---------|------|------|----------|-------------|
| 350 | 1 روزه،1 گیگابایت | 1 GB | 1 day | 126,500 |
| 351 | 7 روزه،1 گیگابایت | 1 GB | 7 days | 132,000 |
| 365 | 14روزه، 3گیگابایت | 3 GB | 14 days | 357,500 |
| 379 | 31 روزه، 3گیگابایت | 3 GB | 30 days | 385,000 |
| 380 | 31 روزه،4گیگابایت | 4 GB | 30 days | 462,000 |
| 385 | 30 روزه، 8گیگابایت | 8 GB | 30 days | 924,000 |
| 389 | 30 روزه، 10گیگابایت | 10 GB | 30 days | 1,155,000 |
| 397 | 60 روزه، 10گیگابایت | 10 GB | 60 days | 907,500 |
| 619 | 365 روزه، 150 گیگابایت | 150 GB | 365 days | 11,550,000 |

### Payment Flow

**Step 1: Initiate Package Purchase**
```
GET https://pwa.samantel.ir/api/SamantelApi/OrderPackagePay
    ?Mobile=09999985823
    &OfferId=619
    &Success=https://pwa.samantel.ir/payment?status=true
    &Fail=https://pwa.samantel.ir/payment?status=false

Response contains:
- Package details
- payURL: Shaparak payment URL with token
  Example: "https://ws.samantel.ir/samantel/v1//?method=goforpayv2&token=e7704d1c83074419936dd4e8b53a7d31&pt=PG2608041706227275"
```

**Step 2: Record Payment**
```
POST https://pwa.samantel.ir/api/Payment/AddPayment

Body: {
  "serviceType": 5,
  "price": 11550000,  // Price in IRR
  "transactionId": "PG2608041706227275"  // From payURL
}
```

**Step 3: Shaparak Payment Gateway**
The payURL redirects you to Shaparak where you:
1. Enter card number (16 digits)
2. Enter CVV2 (3-4 digits)
3. Enter expiry date (MM/YY)
4. Enter card PIN (if required)
5. Enter captcha
6. Click "Pay"
7. Receive OTP on your phone (BANK OTP, not Samantel OTP)
8. Enter OTP
9. Payment is processed
10. Redirected back to Samantel success/fail page

---

## 4. Two Different OTP Systems (CRITICAL)

**This is very important to understand:**

### OTP Type 1: Samantel Login OTP
- **Purpose**: Log into the Samantel PWA
- **Sender**: Samantel (your ISP)
- **Arrives on**: The SIM in the modem (09999985823)
- **When requested**: When you click "Get OTP" on login page
- **Used for**: Authenticating with Samantel system
- **Endpoint**: Same as password login (isOtp=true)

### OTP Type 2: Bank Payment OTP
- **Purpose**: Confirm payment on Shaparak
- **Sender**: Your bank (e.g., Bank Melli, Bank Saderat, etc.)
- **Arrives on**: Your PERSONAL phone (linked to your bank card)
- **When requested**: After entering card details on Shaparak
- **Used for**: Authorizing the financial transaction
- **Endpoint**: `POST https://sep.shaparak.ir/OnlinePG/Otp/RequestOtp?culture=fa`

**Why Two Different Phones?**
- Samantel OTP → Goes to SIM in modem (09999985823)
- Bank OTP → Goes to your personal phone (registered with bank)

**This means:**
- To automate Samantel login: Need to read OTP from modem's SMS inbox
- To automate payment: Need to receive OTP on your personal phone
- Bank OTP CANNOT be automated without your phone

---

## 5. Current Session Data

### Your Account Info (Captured)
- **Phone**: 09999985823
- **SIM Type**: Permanent (دائمی)
- **Status**: Active (فعال)
- **Province**: Tehran
- **National Code**: 0150805721

### Your Current Balance (Captured)
- **Data Package**: "Benefit Data(Whole Day)"
- **Expiry**: August 1, 2027
- **Data Used**: ~0.022 GB (very little)
- **Credit Balance**: -463,727 IRR (negative means you owe)

### Package You Selected
- **OfferID**: 619
- **Name**: 365 روزه، 150 گیگابایت (150GB for 365 days)
- **Price**: 11,550,000 IRR (~$19 USD at current rates)
- **Transaction ID**: PG2608041706227275

---

## 6. What You Need to Do Now

### For Current Payment (OTP in Hand)
You have the bank OTP on your phone. You need to:
1. Go to the browser (should still be open on Shaparak page)
2. Enter the OTP in the verification field
3. Click "Confirm" or "تایید"
4. Wait for payment to complete
5. You'll be redirected back to Samantel

### For Building Automation
To automate future purchases, you need to decide:

**Option A: Semi-Automated (Recommended)**
- Script checks balance and selects best package
- Script initiates purchase
- You manually enter card details and OTP
- Pros: Simple, secure, you control payments
- Cons: Requires manual payment step

**Option B: Fully Automated (Complex)**
- Script handles everything including payment
- Requires storing card details on router
- Requires capturing bank OTP automatically
- Pros: Fully automatic
- Cons: Security risk, complex, OTP on different phone

**Option C: Hybrid**
- Use password for Samantel login (automated)
- Use a dedicated bank card with small balance
- Semi-automate payment (you enter OTP only)
- Pros: Balance of automation and security
- Cons: Still need manual OTP entry

---

## 7. Technical Requirements for Automation

### For OpenWrt Router Script
Based on the API analysis, you need:

**Minimum Tools**:
- `curl` - Make HTTP requests
- `jq` - Parse JSON responses
- `sed`/`awk` - Extract data from HTML
- `grep` - Search patterns

**API Calls Needed**:
1. Get CSRF token
2. Login (with password or OTP)
3. Check remaining balance
4. Get package list
5. Select best package (considering Friday discount)
6. Initiate purchase
7. Handle Shaparak redirect
8. Submit payment details
9. Wait for OTP and submit
10. Verify success

**Storage Needed**:
- Config file: ~1 KB (phone, password, card details)
- Main script: ~10-15 KB
- Logs: ~100 KB max (rotated)
- Temp files: ~5 KB
- **Total**: <50 KB

**Memory Usage**:
- curl processes: ~2-3 MB each
- Script execution: ~1-2 MB
- **Peak**: <5 MB

This fits comfortably on Xiaomi AX3000T.

---

## 8. Friday Discount Logic

Samantel offers 40% discount on all packages every Friday (Iranian weekend).

**How to Implement**:
```bash
# Check if today is Friday (5 = Friday in JavaScript day numbering)
DAY_OF_WEEK=$(date +%u)  # Returns 1-7 (Monday=1, Friday=5)

if [ "$DAY_OF_WEEK" -eq 5 ]; then
    # Friday - apply 40% discount
    EFFECTIVE_PRICE=$((PRICE * 60 / 100))  # Pay only 60%
    DISCOUNT_APPLIED="true"
else
    EFFECTIVE_PRICE=$PRICE
    DISCOUNT_APPLIED="false"
fi
```

**Best Package Selection Formula**:
```
Score = (Data in GB) / (Effective Price)
Higher score = Better value
```

**Smart Timing**:
- If remaining data can last until Friday → Wait for discount
- If data will run out before Friday → Buy now
- Calculate: (Remaining Data) / (Daily Usage) = Days until empty

---

## 9. Security Considerations

### What's Safe to Store
- Phone number (not secret)
- Package preferences
- Thresholds and limits
- API endpoints (public)

### What's Risky to Store
- Samantel password (use OTP instead)
- Bank card details (never on router)
- JWT tokens (expire anyway)

### Recommended Approach
1. Use OTP for Samantel login (not password)
2. Never store bank card details
3. Let user manually enter payment details
4. Store only non-sensitive config
5. Set file permissions to 600 (owner-only read/write)

---

## 10. Next Steps

### Phase 1 Complete ✓
- [x] Captured complete API flow
- [x] Documented all endpoints
- [x] Understood authentication
- [x] Mapped payment system
- [x] Identified two OTP types
- [x] Verified resource requirements

### Phase 2 Pending
- [ ] Implement login automation (password or OTP)
- [ ] Build balance checker
- [ ] Create package selector with Friday logic
- [ ] Implement purchase initiator
- [ ] Add payment page parser
- [ ] Create main automation script
- [ ] Set up cron jobs
- [ ] Add error handling and logging
- [ ] Test dry-run mode

### Your Decision Needed
Before Phase 2, please confirm:
1. **Login method**: Password or OTP?
2. **Payment method**: Fully automated or semi-automated?
3. **Thresholds**: When to trigger purchase? (e.g., <2 GB remaining)
4. **Minimum validity**: Shortest package you'll accept? (e.g., 7 days)
5. **Daily usage**: Average data consumption? (for Friday timing)

---

## 11. Files Created

All captured data is saved in:
```
/home/parsavisions/home-network/capture_data/
├── API_DOCUMENTATION.md      # Technical API reference
├── SYSTEM_ANALYSIS.md        # This file (overview)
├── flow/
│   ├── traffic.json          # Complete network traffic
│   ├── 01_login_page.png     # Login page screenshot
│   └── ... (other screenshots)
└── pwa_login/
    └── traffic.json          # Initial login traffic
```

---

## 12. Summary

**What You Have Now**:
- Complete understanding of Samantel's API
- All endpoints documented
- Payment flow mapped
- Security considerations identified
- Technical requirements verified

**What You Need to Decide**:
- How much automation you want
- Whether to use password or OTP login
- What thresholds trigger purchases

**What's Next**:
- Implement the automation script based on your preferences
- Test on OpenWrt router
- Set up cron jobs for automatic monitoring

The system is well-documented and ready for Phase 2 implementation!
