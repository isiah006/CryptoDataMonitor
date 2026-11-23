class CryptoQuantModel {
  final String asset;
  final String timestamp;

  final MetricData exchangeInflowTotal;
  final MetricData exchangeOutflowTotal;
  final MetricData exchangeReserve;
  final MetricData openInterest;
  final MetricData fundingRates;
  final MetricData? longLiquidations;
  final MetricData? shortLiquidations;
  final BtcPriceData? btcPrice;
  final ArkhamIntelligenceData? arkhamIntelligence;
  final CoinglassFlowData? coinglassFlows;

  CryptoQuantModel({
    required this.asset,
    required this.timestamp,
    required this.exchangeInflowTotal,
    required this.exchangeOutflowTotal,
    required this.exchangeReserve,
    required this.openInterest,
    required this.fundingRates,
    this.longLiquidations,
    this.shortLiquidations,
    this.btcPrice,
    this.arkhamIntelligence,
    this.coinglassFlows,
  });

  factory CryptoQuantModel.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? {};

    return CryptoQuantModel(
      asset: json['asset'] ?? 'BTC',
      timestamp: json['timestamp'] ?? '',

      exchangeInflowTotal:
      MetricData.fromJson(data['exchangeInflowTotal']),

      exchangeOutflowTotal:
      MetricData.fromJson(data['exchangeOutflowTotal']),

      exchangeReserve:
      MetricData.fromJson(data['exchangeReserve']),

      openInterest:
      MetricData.fromJson(data['openInterest']),

      fundingRates:
      MetricData.fromJson(data['fundingRates']),

      longLiquidations: data['longLiquidations'] != null
          ? MetricData.fromJson(data['longLiquidations'])
          : null,

      shortLiquidations: data['shortLiquidations'] != null
          ? MetricData.fromJson(data['shortLiquidations'])
          : null,

      btcPrice: data['btcPrice'] != null
          ? BtcPriceData.fromJson(data['btcPrice'])
          : null,

      arkhamIntelligence: data['arkhamIntelligence'] != null
          ? ArkhamIntelligenceData.fromJson(data['arkhamIntelligence'])
          : null,

      coinglassFlows: data['coinglassFlows'] != null
          ? CoinglassFlowData.fromJson(data['coinglassFlows'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset': asset,
      'timestamp': timestamp,
      'data': {
        'exchangeInflowTotal': exchangeInflowTotal.toJson(),
        'exchangeOutflowTotal': exchangeOutflowTotal.toJson(),
        'exchangeReserve': exchangeReserve.toJson(),
        'openInterest': openInterest.toJson(),
        'fundingRates': fundingRates.toJson(),
        'longLiquidations': longLiquidations?.toJson(),
        'shortLiquidations': shortLiquidations?.toJson(),
        'btcPrice': btcPrice?.toJson(),
        'arkhamIntelligence': arkhamIntelligence?.toJson(),
        'coinglassFlows': coinglassFlows?.toJson(),
      }
    };
  }
}

class BtcPriceData {
  final bool success;
  final String? message;
  final double? price;
  final double? changePercent24H;
  final double? changePercent7D;
  final double? marketCap;
  final double? volume;
  final double? circulatingSupply;

  BtcPriceData({
    required this.success,
    this.message,
    this.price,
    this.changePercent24H,
    this.changePercent7D,
    this.marketCap,
    this.volume,
    this.circulatingSupply,
  });

  factory BtcPriceData.fromJson(Map<String, dynamic> json) {
    return BtcPriceData(
      success: json['success'] ?? false,
      message: json['message'],
      price: json['price']?.toDouble(),
      changePercent24H: json['changePercent24H']?.toDouble(),
      changePercent7D: json['changePercent7D']?.toDouble(),
      marketCap: json['marketCap']?.toDouble(),
      volume: json['volume']?.toDouble(),
      circulatingSupply: json['circulatingSupply']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'price': price,
      'changePercent24H': changePercent24H,
      'changePercent7D': changePercent7D,
      'marketCap': marketCap,
      'volume': volume,
      'circulatingSupply': circulatingSupply,
    };
  }
}

class MetricData {
  final bool success;
  final String? message;
  final int? latestTimestamp;
  final double? latestValue;
  final int? totalPoints;

  MetricData({
    required this.success,
    this.message,
    this.latestTimestamp,
    this.latestValue,
    this.totalPoints,
  });

  factory MetricData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MetricData(
        success: false,
        message: 'Metric data not found.',
      );
    }

    return MetricData(
      success: json['success'] ?? false,
      message: json['message'],
      latestTimestamp: json['latestTimestamp'],
      latestValue: json['latestValue']?.toDouble(),
      totalPoints: json['totalPoints'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'latestTimestamp': latestTimestamp,
      'latestValue': latestValue,
      'totalPoints': totalPoints,
    };
  }
}

class ArkhamIntelligenceData {
  final bool success;
  final double whaleToCexFlow;
  final double cexToWhaleFlow;
  final double stablecoinToCexFlow;
  final String whaleSentiment;
  final int largeTransfersCount;
  final String topEntityAction;
  final String timestamp;

  ArkhamIntelligenceData({
    required this.success,
    required this.whaleToCexFlow,
    required this.cexToWhaleFlow,
    required this.stablecoinToCexFlow,
    required this.whaleSentiment,
    required this.largeTransfersCount,
    required this.topEntityAction,
    required this.timestamp,
  });

  factory ArkhamIntelligenceData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ArkhamIntelligenceData(
        success: false,
        whaleToCexFlow: 0.0,
        cexToWhaleFlow: 0.0,
        stablecoinToCexFlow: 0.0,
        whaleSentiment: 'NEUTRAL',
        largeTransfersCount: 0,
        topEntityAction: 'No Arkham data available',
        timestamp: '',
      );
    }

    return ArkhamIntelligenceData(
      success: json['success'] ?? false,
      whaleToCexFlow: (json['whaleToCexFlow'] ?? 0).toDouble(),
      cexToWhaleFlow: (json['cexToWhaleFlow'] ?? 0).toDouble(),
      stablecoinToCexFlow: (json['stablecoinToCexFlow'] ?? 0).toDouble(),
      whaleSentiment: json['whaleSentiment'] ?? 'NEUTRAL',
      largeTransfersCount: json['largeTransfersCount'] ?? 0,
      topEntityAction: json['topEntityAction'] ?? 'Whale flow neutral',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'whaleToCexFlow': whaleToCexFlow,
      'cexToWhaleFlow': cexToWhaleFlow,
      'stablecoinToCexFlow': stablecoinToCexFlow,
      'whaleSentiment': whaleSentiment,
      'largeTransfersCount': largeTransfersCount,
      'topEntityAction': topEntityAction,
      'timestamp': timestamp,
    };
  }
}

class CoinglassFlowData {
  final bool success;
  final double spotNetInflow;
  final double futuresNetInflow;
  final String spotFlowBias;
  final String futuresFlowBias;
  final String flowSummary;
  final String timestamp;

  CoinglassFlowData({
    required this.success,
    required this.spotNetInflow,
    required this.futuresNetInflow,
    required this.spotFlowBias,
    required this.futuresFlowBias,
    required this.flowSummary,
    required this.timestamp,
  });

  factory CoinglassFlowData.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CoinglassFlowData(
        success: false,
        spotNetInflow: 0.0,
        futuresNetInflow: 0.0,
        spotFlowBias: 'NEUTRAL',
        futuresFlowBias: 'NEUTRAL',
        flowSummary: 'No Coinglass data available',
        timestamp: '',
      );
    }

    return CoinglassFlowData(
      success: json['success'] ?? false,
      spotNetInflow: (json['spotNetInflow'] ?? 0).toDouble(),
      futuresNetInflow: (json['futuresNetInflow'] ?? 0).toDouble(),
      spotFlowBias: json['spotFlowBias'] ?? 'NEUTRAL',
      futuresFlowBias: json['futuresFlowBias'] ?? 'NEUTRAL',
      flowSummary: json['flowSummary'] ?? 'Coinglass flow neutral',
      timestamp: json['timestamp'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'spotNetInflow': spotNetInflow,
      'futuresNetInflow': futuresNetInflow,
      'spotFlowBias': spotFlowBias,
      'futuresFlowBias': futuresFlowBias,
      'flowSummary': flowSummary,
      'timestamp': timestamp,
    };
  }
}
