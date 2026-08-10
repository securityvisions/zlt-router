# Spec: Fully Automatic Samantel Internet Package Purchase System

## Problem Statement

The user has an Iranian ISP (Samantel) internet package that expires periodically. Currently, purchasing a new package requires manual interaction with the Samantel PWA or mobile app, including:

1. Logging into the Samantel account
2. Selecting a package
3. Completing payment on Shaparak gateway (Iran's national payment system)
4. Entering a 5-digit CAPTCHA manually
5. Entering bank OTP manually

This manual process is inconvenient and can lead to:
- Internet disconnection when package expires
- Missing the 40% Friday discount
- Forgetting to purchase before expiry

The existing automation system (samantel_v2.sh) handles steps 1-3 automatically but fails at step 4 (CAPTCHA) because Shaparak's WAF blocks programmatic CAPTCHA requests. The CAPTCHA cannot be solved automatically due to server-side generation and WAF protection.

## Solution

Implement a fully automatic package purchase system that:
1. Uses the mobile PWA API endpoints (config, user/login, account/poap/pin) which may not require CAPTCHA
2. RSA-encrypts the password using public keys from the config endpoint
3. Obtains authentication tokens via the mobile login flow
4. Requests OTP through the mobile API (account/poap/pin endpoint)
5. Receives bank OTP via MacroDroid HTTP forwarding
6. Completes payment without any manual intervention
7. Maintains active packages before expiry
8. Optimizes timing for Friday discounts
9. Prevents duplicate purchases

## User Stories

1. As a user, I want my internet package to be automatically renewed before expiry, so that I never experience disconnection
2. As a user, I want the system to automatically select the best value package, so that I get maximum data for minimum cost
3. As a user, I want the system to apply the 40% Friday discount when available, so that I save money
4. As a user, I want the system to handle all payment steps automatically, so that I don't need to manually interact with the payment gateway
5. As a user, I want the system to receive bank OTPs automatically via MacroDroid, so that I don't need to manually enter codes
6. As a user, I want the system to prevent duplicate purchases, so that I don't waste money on overlapping packages
7. As a user, I want the system to log all activity, so that I can troubleshoot issues
8. As a user, I want the system to notify me of purchase status, so that I know when a package is activated
9. As a user, I want the system to check balance periodically, so that it knows when to purchase
10. As a user, I want the system to handle network errors gracefully, so that it retries failed operations
11. As a user, I want the system to store payment information securely, so that my credentials are protected
12. As a user, I want the system to work on my OpenWrt router, so that it runs 24/7 without needing my computer
13. As a user, I want the system to use the mobile API flow, so that it bypasses the Shaparak CAPTCHA
14. As a user, I want the system to RSA-encrypt my password, so that it can authenticate via the mobile API
15. As a user, I want the system to obtain public keys from the config endpoint, so that it can encrypt credentials
16. As a user, I want the system to request OTP via the mobile API, so that it doesn't rely on the web PWA
17. As a user, I want the system to complete payment without CAPTCHA, so that it achieves full automation
18. As a user, I want the system to handle token refresh automatically, so that it maintains authentication
19. As a user, I want the system to respect package validity periods, so that it doesn't purchase overlapping packages
20. As a user, I want the system to consider my usage rate, so that it purchases appropriate package sizes
21. As a user, I want the system to work even if my computer is off, so that it's truly autonomous
22. As a user, I want the system to store card details securely on the router, so that it can complete payments
23. As a user, I want the system to handle multiple payment attempts, so that it recovers from failures
24. As a user, I want the system to check for existing active packages, so that it doesn't purchase unnecessarily
25. As a user, I want the system to calculate remaining data accurately, so that it knows when to purchase
26. As a user, I want the system to run on a schedule (e.g., every 30 minutes), so that it's always monitoring
27. As a user, I want the system to start automatically on router boot, so that it survives power outages
28. As a user, I want the system to provide status via web interface, so that I can check it from my phone
29. As a user, I want the system to send notifications on purchase success/failure, so that I'm informed
30. As a user, I want the system to handle Shaparak redirects properly, so that payments complete successfully
31. As a user, I want the system to extract payment tokens from URLs, so that it can submit card details
32. As a user, I want the system to submit card details automatically, so that manual entry is eliminated
33. As a user, I want the system to wait for bank OTP after card submission, so that payment verification happens
34. As a user, I want the system to submit OTP automatically, so that payment completes end-to-end
35. As a user, I want the system to verify payment success, so that it confirms package activation
36. As a user, I want the system to record transaction history, so that I can track purchases
37. As a user, I want the system to calculate savings from Friday discounts, so that I see the benefit
38. As a user, I want the system to handle multiple packages (data, voice, etc.), so that it's flexible
39. As a user, I want the system to work with different Samantel SIM types, so that it's compatible
40. As a user, I want the system to validate input parameters, so that it doesn't make invalid requests

## Implementation Decisions

### Modules to Build/Modify

1. **Mobile API Client** (new)
   - Endpoints: config, user/login, account/poap/pin
   - RSA encryption using public keys from config
   - Authentication token management

2. **Payment Gateway Client** (modify samantel_auto_pay.sh)
   - Bypass CAPTCHA using mobile API flow
   - Submit card details programmatically
   - Handle OTP submission

3. **Orchestrator** (modify samantel_v2.sh)
   - Integrate mobile API client
   - Remove CAPTCHA dependency
   - Add token refresh logic

4. **OTP Receiver** (existing otp_handler.sh)
   - No changes needed (MacroDroid integration works)

5. **Configuration** (modify samantel.conf)
   - Add mobile API settings
   - Add card details (encrypted)

### Interfaces

- **Mobile API Client**: `get_config()`, `login_with_rsa()`, `request_otp()`
- **Payment Gateway Client**: `submit_card()`, `submit_otp()`, `verify_payment()`
- **Orchestrator**: `check_balance()`, `select_package()`, `initiate_purchase()`, `complete_payment()`

### Technical Clarifications

1. **RSA Encryption**:
   - Use public keys from config endpoint
   - Encrypt password before submitting to user/login
   - Keys: publicKey, ecPublicKey

2. **Mobile API Endpoints**:
   - `GET /config` → returns publicKey, ecPublicKey
   - `POST /user/login` → RSA-encrypted password, returns auth token
   - `POST /account/poap/pin` → requests OTP for device

3. **Payment Flow**:
   - Mobile API login → get token
   - Request OTP via mobile API
   - Submit card details to Shaparak (no CAPTCHA?)
   - Receive bank OTP via MacroDroid
   - Submit OTP to Shaparak
   - Verify payment success

4. **Shaparak CAPTCHA Bypass**:
   - Mobile API may not require CAPTCHA
   - Need to test if mobile payment flow skips CAPTCHA
   - If CAPTCHA still required, explore alternative: inject mobile User-Agent to mimic mobile browser

### Architectural Decisions

1. **Router-Based**: All logic runs on OpenWrt router (24/7 operation)
2. **Shell Scripts**: BusyBox ash shell (no bash, limited grep)
3. **CGI for OTP**: uhttpd on port 5000 for MacroDroid HTTP POST
4. **Cron Scheduling**: Every 30 minutes for balance checks
5. **File-Based State**: JSON files for status, tokens, history

### API Contracts

1. **Samantel Mobile API**:
   - Base URL: `https://pwa.samantel.ir` (TBD - may be different for mobile)
   - Auth: Bearer token from login
   - Responses: JSON with errCode field

2. **Shaparak Payment Gateway**:
   - URL: `https://sep.shaparak.ir/OnlinePG/SendToken?token=<token>`
   - Form fields: cardNumber, cvv2, expiryDate, password, captcha
   - OTP submission: Pin2 field

3. **MacroDroid → Router**:
   - POST `http://192.168.1.1:5000/cgi-bin/otp_handler.sh`
   - Body: `otp=123456`

### Schema Changes

1. **samantel.conf** additions:
   - `CARD_NUMBER` (encrypted)
   - `CARD_CVV` (encrypted)
   - `CARD_EXPIRY` (MM/YY)
   - `MOBILE_API_BASE` (mobile API URL)
   - `RSA_PUBLIC_KEY` (from config endpoint)

2. **Status JSON** additions:
   - `mobile_api_token` (temporary)
   - `payment_pending` (boolean)
   - `captcha_required` (boolean - should be false)

## Testing Decisions

### What Makes a Good Test

1. **External Behavior**: Test API responses, not implementation details
2. **Integration Tests**: Test full flow from login to payment
3. **Error Scenarios**: Test network failures, invalid credentials, expired tokens
4. **Edge Cases**: Test Friday discount, multiple packages, concurrent purchases

### Modules to Test

1. **Mobile API Client**: Login, token refresh, OTP request
2. **Payment Gateway**: Card submission, OTP submission, verification
3. **Orchestrator**: Balance check, package selection, purchase flow
4. **OTP Receiver**: MacroDroid integration, file writing

### Prior Art

- Existing tests in `test_samantel_api.sh`, `test_balance.sh`, `test_otp_flow.sh`
- Manual testing via SSH commands
- Web interface for visual verification

## Out of Scope

1. **Bank Card Management**: System uses pre-configured card, no card addition UI
2. **Multiple Accounts**: System handles single Samantel account
3. **Package Comparison UI**: System auto-selects best value, no manual selection
4. **Historical Analytics**: Basic logging only, no dashboard
5. **Refund Handling**: System doesn't handle payment reversals
6. **Voice/Data Package Switching**: System focuses on data packages
7. **International SIM Support**: Iran-only (Samantel)
8. **Mobile App Development**: System uses existing MacroDroid for OTP
9. **Web Interface for CAPTCHA**: If mobile API requires CAPTCHA, semi-automated solution exists (samantel_web.sh)
10. **Multi-Router Support**: Single router deployment

## Further Notes

### Current Blocker

The main blocker is the Shaparak CAPTCHA. The mobile API endpoints (config, user/login, account/poap/pin) may bypass this, but need to be tested. If mobile API still requires CAPTCHA:

1. **Option A**: Use mobile User-Agent in web requests to mimic mobile browser
2. **Option B**: Keep semi-automated CAPTCHA entry (samantel_web.sh)
3. **Option C**: Explore if mobile payment flow skips CAPTCHA entirely

### Next Steps

1. Decompile APK to find mobile API endpoints and RSA encryption
2. Test mobile API flow on router
3. Implement RSA encryption in shell script
4. Test payment flow without CAPTCHA
5. Deploy to router
6. Monitor for issues

### Risk Mitigation

1. **Token Expiry**: Refresh tokens before expiry
2. **Payment Failures**: Retry logic with exponential backoff
3. **Duplicate Purchases**: Status tracking prevents overlapping purchases
4. **Network Issues**: Graceful error handling, log for debugging
5. **Security**: Encrypt card details, don't expose to internet

### Success Criteria

1. System runs 24/7 on router without manual intervention
2. Packages are purchased automatically before expiry
3. Friday discounts are applied when available
4. No duplicate purchases occur
5. All activity is logged for debugging
6. User is notified of purchase status
7. No CAPTCHA entry required (primary goal)
