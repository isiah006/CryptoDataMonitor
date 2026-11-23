# Implementation Plan - Fix Inflow/Outflow (Migration to MS/Charts API)

Through network inspection, I have discovered that CryptoQuant has migrated the Inflow and Outflow metrics to a new internal API endpoint (`/live/v4/ms/`). The standard chart API (`/live/v4/charts/`) is no longer being triggered for these metrics, which is why the scraper was failing to capture them.

## User Review Required

> [!IMPORTANT]
> **API Migration**: I found that Inflow and Outflow now use a "Multi-Series" (MS) API structure. I have identified the exact IDs for these metrics and will update the scraper to support this new format while remaining compatible with the older chart API.

## Proposed Changes

### Backend (Scraper Logic Update)

#### [MODIFY] [CryptoQuantScraper.ts](file:///C:/Users/PC/CryptoDataMonitor/backend/src/scrapers/CryptoQuantScraper.ts)
- **Support `/live/v4/ms/`**: Update the response listener to intercept the new MS API endpoint.
- **Universal Data Parser**: Refactor `getMetric` to handle two JSON structures:
    1. **Old (v4 Chart)**: Data at `result.data`.
    2. **New (v4 MS Chart)**: Data at `charts[0].result.data`.
- **Matching Strategy**: Match the captured response if the URL contains the metric's keyword (e.g., `inflow`) OR if the internal `metricId` matches.
- **Identified IDs**:
    - BTC Inflow: `61762cae142904287d6a7f39`
    - BTC Outflow: `61762e8d142904287d6a7fa1`

### Frontend
- No changes required.

## Verification Plan

### Manual Verification
1. **Restart Backend**: Run `npm run dev`.
2. **Fetch BTC Data**: Click "FETCH BTC DATA" in the app.
3. **Monitor Logs**:
    - Verify that the terminal logs `DEBUG: Response -> https://api.cryptoquant.com/live/v4/ms/.../charts`.
    - Look for `✅ API Captured for exchange-inflow`.
4. **App UI**: Confirm that real Bitcoin volume numbers appear for Inflow and Outflow.
