import '../models/cryptoquant_model.dart';

enum MarketSignal {
  bullish,
  bearish,
  longSqueezeRisk,
  shortSqueezeRisk,
  conflictingSignals,
  neutral,
}

class MarketSignalResult {
  final MarketSignal signal;
  final String title;
  final String explanation;

  MarketSignalResult({
    required this.signal,
    required this.title,
    required this.explanation,
  });
}

class MarketSignalEngine {

  static MarketSignalResult analyze({
    required CryptoQuantModel current,
    CryptoQuantModel? previous,
  }) {

    // ==================================================
    // FIRST FETCH (BASELINE)
    // ==================================================

    if (previous == null) {
      return MarketSignalResult(
        signal: MarketSignal.neutral,
        title: 'BASELINE',
        explanation:
        'First fetch established. Waiting for the next fetch for 7-Tier comparison.',
      );
    }

    // ==================================================
    // RAW VALUES
    // ==================================================

    final currentPrice = current.btcPrice?.price;
    final previousPrice = previous.btcPrice?.price;

    final currentInflow = current.exchangeInflowTotal.latestValue;
    final previousInflow = previous.exchangeInflowTotal.latestValue;

    final currentOutflow = current.exchangeOutflowTotal.latestValue;
    final previousOutflow = previous.exchangeOutflowTotal.latestValue;

    final currentReserve = current.exchangeReserve.latestValue;
    final previousReserve = previous.exchangeReserve.latestValue;

    final currentOI = current.openInterest.latestValue;
    final previousOI = previous.openInterest.latestValue;

    final currentFunding = current.fundingRates.latestValue;

    final currentLongLiq = current.longLiquidations?.latestValue;
    final previousLongLiq = previous.longLiquidations?.latestValue;

    final currentShortLiq = current.shortLiquidations?.latestValue;
    final previousShortLiq = previous.shortLiquidations?.latestValue;

    final arkham = current.arkhamIntelligence;
    final coinglass = current.coinglassFlows;

    // ==================================================
    // SAFETY CHECK
    // ==================================================

    if (currentPrice == null ||
        previousPrice == null ||
        currentInflow == null ||
        previousInflow == null ||
        currentOutflow == null ||
        previousOutflow == null ||
        currentReserve == null ||
        previousReserve == null ||
        currentOI == null ||
        previousOI == null ||
        currentFunding == null) {

      return MarketSignalResult(
        signal: MarketSignal.neutral,
        title: 'NEUTRAL',
        explanation: 'Insufficient data across 7 tiers to determine market condition.',
      );
    }

    // ==================================================
    // MOMENTUM CALCULATIONS (% CHANGE)
    // ==================================================

    double calcChange(double? prev, double? curr) {
      if (prev == null || curr == null || prev == 0) return 0.0;
      return ((curr - prev) / prev) * 100;
    }

    final double priceChange = calcChange(previousPrice, currentPrice);
    final double inflowChange = calcChange(previousInflow, currentInflow);
    final double outflowChange = calcChange(previousOutflow, currentOutflow);
    final double reserveChange = calcChange(previousReserve, currentReserve);
    final double oiChange = calcChange(previousOI, currentOI);
    final double longLiqChange = calcChange(previousLongLiq, currentLongLiq);
    final double shortLiqChange = calcChange(previousShortLiq, currentShortLiq);

    // ==================================================
    // 1. DIRECTIONAL FLAGS & CALIBRATED THRESHOLDS
    // ==================================================

    final bool priceUp = priceChange > 0;
    final bool priceDown = priceChange < 0;
    final bool priceStrongUp = priceChange >= 0.3;
    final bool priceStrongDown = priceChange <= -0.3;

    // Calibrated Short-Term Thresholds
    final bool inflowUp = inflowChange >= 2.0;
    final bool outflowUp = outflowChange >= 2.0;

    final bool reserveDown = reserveChange <= -0.01;
    final bool reserveUp = reserveChange >= 0.01;

    final bool oiUpStrong = oiChange >= 1.5;
    final bool oiUpGradual = oiChange >= 0.3 && oiChange < 1.5;
    final bool oiDown = oiChange <= -0.5;

    final bool shortLiqSpike = shortLiqChange > 15.0 || (currentShortLiq != null && currentShortLiq > 1.0);
    final bool longLiqSpike = longLiqChange > 15.0 || (currentLongLiq != null && currentLongLiq > 1.0);

    final bool fundingNegative = currentFunding < 0;
    final bool fundingPositive = currentFunding > 0;

    final bool arkhamBullish = arkham?.whaleSentiment == 'BULLISH_ACCUMULATION';
    final bool arkhamBearish = arkham?.whaleSentiment == 'BEARISH_DEPOSIT';

    // Coinglass Spot vs Futures Flow Flags
    final bool spotAccumulation = coinglass?.spotFlowBias == 'SPOT_ACCUMULATION';
    final bool spotSelling = coinglass?.spotFlowBias == 'SPOT_SELLING_PRESSURE';
    final bool futuresMarginBuildup = coinglass?.futuresFlowBias == 'FUTURES_MARGIN_BUILDUP';

    // Debug Logs
    print('--- 7-TIER DAY-TRADE MOMENTUM TRACKING ---');
    print('Price:     ${priceChange.toStringAsFixed(4)}%');
    print('Flows:     In:${inflowChange.toStringAsFixed(1)}% | Out:${outflowChange.toStringAsFixed(1)}%');
    print('OI:        ${oiChange.toStringAsFixed(2)}% | Funding: $currentFunding');
    print('Arkham:    ${arkham?.whaleSentiment} (${arkham?.topEntityAction})');
    print('Coinglass: ${coinglass?.flowSummary}');
    print('-------------------------------------------');

    // ==================================================
    // ⚔️ CONFLICT DETECTION (RULE: ON-CHAIN/ARKHAM DOES NOT OVERRIDE PRICE)
    // ==================================================

    // Price is Bullish, but Spot Dumping or Heavy CEX Deposits
    if (priceUp && (arkhamBearish || spotSelling) && inflowUp) {
      return MarketSignalResult(
        signal: MarketSignal.conflictingSignals,
        title: '🟡 CONFLICTING SIGNALS',
        explanation: 'Price Structure = Bullish | Coinglass/Arkham = Spot Selling Pressure\n\n'
            '⚠️ Caution: Heavy exchange deposits into rising price. Wait for price & derivatives confirmation.',
      );
    }

    // Price is Bearish, but Heavy Spot Accumulation
    if (priceDown && (arkhamBullish || spotAccumulation) && outflowUp) {
      return MarketSignalResult(
        signal: MarketSignal.conflictingSignals,
        title: '🟡 CONFLICTING SIGNALS',
        explanation: 'Price Structure = Bearish | Coinglass/Arkham = Spot Accumulation\n\n'
            '⚠️ Caution: Large spot withdrawals into falling price. Wait for price & derivatives confirmation.',
      );
    }

    // ==================================================
    // 🔥 SQUEEZE DETECTION (HIGHEST PRIORITY)
    // ==================================================

    // SHORT SQUEEZE: Structure Bullish + OI ↓ + Funding Neg + Short Liq Spike + Futures Collateral
    if (priceUp && oiDown && fundingNegative && shortLiqSpike) {
      return MarketSignalResult(
        signal: MarketSignal.shortSqueezeRisk,
        title: '🚀 SHORT SQUEEZE',
        explanation: 'Price ↑ | OI ↓ | Funding Negative | Short Liquidations Spike\n\n'
            'Shorts getting liquidated and closing positions while price rises.\n'
            'Coinglass: ${coinglass?.flowSummary ?? "Futures Margin Buildup"}',
      );
    }

    // LONG SQUEEZE: Structure Bearish + OI ↓ + Funding Pos + Long Liq Spike + Futures Collateral
    if (priceDown && oiDown && fundingPositive && longLiqSpike) {
      return MarketSignalResult(
        signal: MarketSignal.longSqueezeRisk,
        title: '💥 LONG SQUEEZE',
        explanation: 'Price ↓ | OI ↓ | Funding Positive | Long Liquidations Spike\n\n'
            'Longs getting liquidated and closing positions while price drops.\n'
            'Coinglass: ${coinglass?.flowSummary ?? "Futures Margin Buildup"}',
      );
    }

    // ==================================================
    // 🟢 BULLISH PATH
    // ==================================================

    if (priceUp) {
      // STRONG BULLISH BIAS (Spot Accumulation)
      if (reserveDown && (oiUpStrong || oiUpGradual) && (spotAccumulation || arkhamBullish)) {
        return MarketSignalResult(
          signal: MarketSignal.bullish,
          title: '🟢 STRONG BULLISH (Spot Accumulation)',
          explanation: 'Price ↑ | Spot Outflow (Accumulation) | Reserve ↓ | OI ↑\n\n'
              'Maximum alignment across all 7 tiers.\n'
              'Coinglass: ${coinglass?.flowSummary}',
        );
      }

      // BULLISH BUILDUP / ACCUMULATION
      if (outflowUp && oiUpGradual) {
        return MarketSignalResult(
          signal: MarketSignal.bullish,
          title: '🟢 BULLISH BUILDUP',
          explanation: 'Price ↑ | Outflow ↑ | OI Gradual ↑\n\n'
              'Smart money accumulation detected. Derivatives OI growing healthily.',
        );
      }

      // OVERLEVERAGED BULLISH (TRAP RISK)
      if (priceStrongUp && oiChange > 3.0 && fundingPositive && futuresMarginBuildup) {
        return MarketSignalResult(
          signal: MarketSignal.longSqueezeRisk,
          title: '🟡 OVERLEVERAGED BULLISH',
          explanation: 'Price ↑↑ | OI ↑↑ | Funding Positive | Futures Margin Buildup\n\n'
              '⚠️ CAUTION: Long positions are crowded. High risk of a Long Squeeze.',
        );
      }

      return MarketSignalResult(
        signal: MarketSignal.bullish,
        title: '🟢 BULLISH',
        explanation: 'Price structure is bullish with supportive momentum across derivatives.',
      );
    }

    // ==================================================
    // 🔴 BEARISH PATH
    // ==================================================

    if (priceDown) {
      // STRONG BEARISH BIAS (Spot Dumping)
      if (reserveUp && (oiUpStrong || oiUpGradual) && (spotSelling || arkhamBearish)) {
        return MarketSignalResult(
          signal: MarketSignal.bearish,
          title: '🔴 STRONG BEARISH (Spot Dumping)',
          explanation: 'Price ↓ | Spot Inflow (Sell Pressure) | Reserve ↑ | OI ↑\n\n'
              'Maximum alignment across all 7 tiers.\n'
              'Coinglass: ${coinglass?.flowSummary}',
        );
      }

      // BEARISH BUILDUP / DISTRIBUTION
      if (inflowUp && oiUpGradual) {
        return MarketSignalResult(
          signal: MarketSignal.bearish,
          title: '🔴 BEARISH BUILDUP',
          explanation: 'Price ↓ | Inflow ↑ | OI Gradual ↑\n\n'
              'Distribution detected. Derivatives preparing for potential downside.',
        );
      }

      // OVERLEVERAGED BEARISH (TRAP RISK)
      if (priceStrongDown && oiChange > 3.0 && fundingNegative && futuresMarginBuildup) {
        return MarketSignalResult(
          signal: MarketSignal.shortSqueezeRisk,
          title: '🟡 OVERLEVERAGED BEARISH',
          explanation: 'Price ↓↓ | OI ↑↑ | Funding Negative | Futures Margin Buildup\n\n'
              '⚠️ RISK: Shorts are crowded. High risk of a Short Squeeze.',
        );
      }

      return MarketSignalResult(
        signal: MarketSignal.bearish,
        title: '🔴 BEARISH',
        explanation: 'Price structure is bearish with weak momentum across derivatives.',
      );
    }

    // ==================================================
    // 🟡 NEUTRAL
    // ==================================================

    return MarketSignalResult(
      signal: MarketSignal.neutral,
      title: 'NEUTRAL',
      explanation: 'No clear 7-tier day-trade setup detected. Mixed indicators.',
    );
  }
}
