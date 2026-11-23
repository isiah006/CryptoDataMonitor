import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/cryptoquant_api_service.dart';
import 'models/cryptoquant_model.dart';
import 'logic/market_signal_engine.dart';
import 'widgets/btc_price_chart.dart';

void main() {
  runApp(const CryptoDataMonitorApp());
}

class CryptoDataMonitorApp extends StatelessWidget {
  const CryptoDataMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Crypto Data Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const CryptoQuantDashboard(),
    );
  }
}

class CryptoQuantDashboard extends StatefulWidget {
  const CryptoQuantDashboard({super.key});

  @override
  State<CryptoQuantDashboard> createState() => _CryptoQuantDashboardState();
}

class _CryptoQuantDashboardState extends State<CryptoQuantDashboard> {
  CryptoQuantModel? previousSnapshot;
  CryptoQuantModel? currentSnapshot;
  MarketSignalResult? signalResult;

  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await CryptoQuantApiService.loadCustomBaseUrl();
    await _loadLocalData();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    _syncCache();
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentJson = prefs.getString('current_snapshot');
      final previousJson = prefs.getString('previous_snapshot');

      if (currentJson != null) {
        final currentData = CryptoQuantModel.fromJson(jsonDecode(currentJson));
        CryptoQuantModel? previousData;
        if (previousJson != null) {
          previousData = CryptoQuantModel.fromJson(jsonDecode(previousJson));
        }

        final signal = MarketSignalEngine.analyze(
          current: currentData,
          previous: previousData,
        );

        if (mounted) {
          setState(() {
            currentSnapshot = currentData;
            previousSnapshot = previousData;
            signalResult = signal;
          });
        }
      }
    } catch (e) {
      debugPrint('Local load error: $e');
    }
  }

  Future<void> _syncCache() async {
    try {
      final cachedData = await CryptoQuantApiService.getCachedBTCData();
      if (cachedData != null && mounted) {
        if (currentSnapshot == null || cachedData.timestamp != currentSnapshot!.timestamp) {
          final signal = MarketSignalEngine.analyze(
            current: cachedData,
            previous: currentSnapshot,
          );
          setState(() {
            previousSnapshot = currentSnapshot;
            currentSnapshot = cachedData;
            signalResult = signal;
          });
          _saveToLocal();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (currentSnapshot != null) {
        await prefs.setString('current_snapshot', jsonEncode(currentSnapshot!.toJson()));
      }
      if (previousSnapshot != null) {
        await prefs.setString('previous_snapshot', jsonEncode(previousSnapshot!.toJson()));
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> _clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await CryptoQuantApiService.clearBackendStorage();
      if (mounted) {
        setState(() {
          currentSnapshot = null;
          previousSnapshot = null;
          signalResult = null;
          _error = null;
        });
      }
    } catch (_) {}
  }

  Future<void> fetchBTCData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newData = await CryptoQuantApiService.getBTCData();
      final newSignal = MarketSignalEngine.analyze(
        current: newData,
        previous: currentSnapshot,
      );

      if (mounted) {
        setState(() {
          previousSnapshot = currentSnapshot;
          currentSnapshot = newData;
          signalResult = newSignal;
        });
        await _saveToLocal();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSettingsDialog() {
    final urlController = TextEditingController(text: CryptoQuantApiService.baseUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 8),
              Text('Server Connection Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Backend Server URL:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g. https://cryptodatamonitor-api.onrender.com',
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Default Local: http://192.168.100.36:3000\nCloud 24/7: Enter your Render / Railway URL',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                await CryptoQuantApiService.setCustomBaseUrl(urlController.text);
                if (mounted) {
                  Navigator.pop(context);
                  fetchBTCData();
                }
              },
              child: const Text('SAVE & CONNECT'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BTC Market Data'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSettingsDialog,
            tooltip: 'Server Settings',
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchBTCData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderActions(),
                  const SizedBox(height: 16),
                  const BtcPriceChart(),
                  const SizedBox(height: 20),
                  if (_error != null) _buildErrorCard(),
                  if (currentSnapshot == null && !_isLoading && _error == null) _buildEmptyState(),
                  if (currentSnapshot != null) _buildDashboard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : fetchBTCData,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLoading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.refresh),
                  const SizedBox(width: 12),
                  Text(_isLoading ? 'Fetching...' : 'FETCH BTC DATA', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        if (currentSnapshot != null && !_isLoading) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_off, size: 18, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text('CONNECTION WARNING', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)),
              ],
            ),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            const Text('Displaying last cached snapshot below. Open Settings to verify server URL.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: Text('Press FETCH to start monitoring market data.', textAlign: TextAlign.center)),
    );
  }

  String _formatTimestamp(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoTimestamp).toLocal();
      final year = dateTime.year;
      final month = dateTime.month.toString().padLeft(2, '0');
      final day = dateTime.day.toString().padLeft(2, '0');

      int hour = dateTime.hour;
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';

      hour = hour % 12;
      if (hour == 0) hour = 12;
      final hourStr = hour.toString().padLeft(2, '0');

      return 'Last Fetch: Date: $year-$month-$day, Time: $hourStr:$minute:$second $period';
    } catch (_) {
      return 'Last Fetch: Date: N/A, Time: N/A';
    }
  }

  Widget _buildDashboard() {
    final current = currentSnapshot!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(current.asset, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (signalResult != null) _buildSignalCard(signalResult!),
        const SizedBox(height: 16),
        if (current.btcPrice != null) _buildBtcPriceCard(current.btcPrice!, previousSnapshot?.btcPrice),
        const SizedBox(height: 16),
        if (current.coinglassFlows != null) _buildCoinglassCard(current.coinglassFlows!),
        if (current.coinglassFlows != null) const SizedBox(height: 16),
        if (current.arkhamIntelligence != null) _buildArkhamCard(current.arkhamIntelligence!),
        const SizedBox(height: 16),
        _buildMetricsTable(),
        const SizedBox(height: 24),
        Center(
          child: Text(
            _formatTimestamp(current.timestamp),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoinglassCard(CoinglassFlowData coinglass) {
    Color spotColor = Colors.grey;
    if (coinglass.spotFlowBias == 'SPOT_ACCUMULATION') {
      spotColor = Colors.green;
    } else if (coinglass.spotFlowBias == 'SPOT_SELLING_PRESSURE') {
      spotColor = Colors.red;
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.candlestick_chart_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('COINGLASS FLOWS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: spotColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    coinglass.spotFlowBias.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: spotColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(coinglass.flowSummary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _flowBox('Spot Netflow', '${coinglass.spotNetInflow >= 0 ? "+" : ""}${coinglass.spotNetInflow.toStringAsFixed(0)} BTC', spotColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _flowBox('Futures Netflow', '${coinglass.futuresNetInflow >= 0 ? "+" : ""}${coinglass.futuresNetInflow.toStringAsFixed(0)} BTC', Colors.orangeAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildArkhamCard(ArkhamIntelligenceData arkham) {
    Color sentimentColor = Colors.grey;
    if (arkham.whaleSentiment == 'BULLISH_ACCUMULATION') {
      sentimentColor = Colors.green;
    } else if (arkham.whaleSentiment == 'BEARISH_DEPOSIT') {
      sentimentColor = Colors.red;
    }

    return Card(
      color: sentimentColor.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.remove_red_eye_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('ARKHAM INTELLIGENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    arkham.whaleSentiment.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sentimentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(arkham.topEntityAction, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _arkhamStatBox('Whale -> CEX', '${arkham.whaleToCexFlow.toStringAsFixed(0)} BTC', Colors.redAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _arkhamStatBox('CEX -> Whale', '${arkham.cexToWhaleFlow.toStringAsFixed(0)} BTC', Colors.greenAccent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _arkhamStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildMetricsTable() {
    final current = currentSnapshot!;
    final prev = previousSnapshot;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _columnHeader('PREVIOUS')),
            const SizedBox(width: 12),
            Expanded(child: _columnHeader('CURRENT')),
          ],
        ),
        const SizedBox(height: 10),
        _metricRow('Inflow', prev?.exchangeInflowTotal.latestValue, current.exchangeInflowTotal.latestValue, 'BTC'),
        _metricRow('Outflow', prev?.exchangeOutflowTotal.latestValue, current.exchangeOutflowTotal.latestValue, 'BTC'),
        _metricRow('Reserve', prev?.exchangeReserve.latestValue, current.exchangeReserve.latestValue, 'BTC'),
        _metricRow('OI', prev?.openInterest.latestValue, current.openInterest.latestValue, 'USD'),
        _metricRow('Funding', prev?.fundingRates.latestValue, current.fundingRates.latestValue, '%', isRate: true),
        _metricRow('Long Liq', prev?.longLiquidations?.latestValue, current.longLiquidations?.latestValue, 'USD'),
        _metricRow('Short Liq', prev?.shortLiquidations?.latestValue, current.shortLiquidations?.latestValue, 'USD'),
      ],
    );
  }

  Widget _columnHeader(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Theme.of(context).colorScheme.surfaceContainerHighest),
      child: Center(child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
    );
  }

  Widget _metricRow(String title, double? p, double? c, String u, {bool isRate = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _valBox(p, u, isRate)),
                const SizedBox(width: 12),
                Expanded(child: _valBox(c, u, isRate, prevForChange: p)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _valBox(double? v, String u, bool isRate, {double? prevForChange}) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(6)),
          child: Text(_fmt(v, u, isRate), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        if (prevForChange != null && v != null) ...[
          const SizedBox(height: 4),
          _percentageBadge(prevForChange, v),
        ],
      ],
    );
  }

  String _fmt(double? v, String u, bool isRate) {
    if (v == null) return 'N/A';
    if (isRate) return '${v.toStringAsFixed(6)}%';
    if (u == 'USD') {
      if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
      if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
      return '\$${v.toStringAsFixed(2)}';
    }
    return '${v.toStringAsFixed(2)} $u';
  }

  Widget _percentageBadge(double? p, double? c) {
    if (p == null || c == null || p == 0) return const SizedBox.shrink();
    final ch = ((c - p) / p) * 100;
    return Text('${ch >= 0 ? "+" : ""}${ch.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: ch >= 0 ? Colors.green : Colors.red));
  }

  Widget _buildSignalCard(MarketSignalResult r) {
    return Card(
      color: _getSigCol(r.signal).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(_getSigIcon(r.signal), size: 40, color: _getSigCol(r.signal)),
            const SizedBox(height: 8),
            Text(r.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _getSigCol(r.signal))),
            const SizedBox(height: 4),
            Text(r.explanation, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  IconData _getSigIcon(MarketSignal s) {
    switch (s) {
      case MarketSignal.bullish: return Icons.trending_up;
      case MarketSignal.bearish: return Icons.trending_down;
      case MarketSignal.shortSqueezeRisk: return Icons.rocket_launch;
      case MarketSignal.longSqueezeRisk: return Icons.warning_amber;
      case MarketSignal.conflictingSignals: return Icons.published_with_changes;
      default: return Icons.remove_circle_outline;
    }
  }

  Color _getSigCol(MarketSignal s) {
    switch (s) {
      case MarketSignal.bullish: return Colors.green;
      case MarketSignal.bearish: return Colors.red;
      case MarketSignal.shortSqueezeRisk: return Colors.orange;
      case MarketSignal.longSqueezeRisk: return Colors.deepOrange;
      case MarketSignal.conflictingSignals: return Colors.amber;
      default: return Colors.grey;
    }
  }

  Widget _buildBtcPriceCard(BtcPriceData current, BtcPriceData? previous) {
    final double? price = current.price;
    final double? prevPrice = previous?.price;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('LIVE BTC PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(price != null ? '\$${price.toStringAsFixed(2)}' : 'N/A', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                if (price != null && prevPrice != null) ...[
                  const SizedBox(width: 10),
                  _percentageBadge(prevPrice, price),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
