import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class BtcPriceChart extends StatefulWidget {
  const BtcPriceChart({super.key});

  @override
  State<BtcPriceChart> createState() => _BtcPriceChartState();
}

class _BtcPriceChartState extends State<BtcPriceChart> {
  List<Candle> _candles = [];
  WebSocketChannel? _channel;
  bool _isLoading = true;
  String _currentInterval = '1h';

  final List<String> _intervals = ['15m', '1h', '4h', '1d'];

  @override
  void initState() {
    super.initState();
    _initChart();
  }

  Future<void> _initChart() async {
    setState(() => _isLoading = true);
    await _fetchHistory();
    _connectWebSocket();
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.binance.com/api/v3/klines?symbol=BTCUSDT&interval=$_currentInterval&limit=100'));
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _candles = data.map((e) => Candle(
              date: DateTime.fromMillisecondsSinceEpoch(e[0]),
              high: double.parse(e[2]),
              low: double.parse(e[3]),
              open: double.parse(e[1]),
              close: double.parse(e[4]),
              volume: double.parse(e[5]),
            )).toList().reversed.toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Chart history error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _connectWebSocket() {
    _channel?.sink.close();
    
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://stream.binance.com:9443/ws/btcusdt@kline_$_currentInterval'),
    );

    _channel!.stream.listen((message) {
      final map = json.decode(message);
      final kline = map['k'];
      final candle = Candle(
        date: DateTime.fromMillisecondsSinceEpoch(kline['t']),
        high: double.parse(kline['h']),
        low: double.parse(kline['l']),
        open: double.parse(kline['o']),
        close: double.parse(kline['c']),
        volume: double.parse(kline['v']),
      );

      if (mounted) {
        setState(() {
          if (_candles.isNotEmpty && _candles[0].date == candle.date) {
            _candles[0] = candle;
          } else {
            _candles.insert(0, candle);
          }
        });
      }
    }, onError: (err) {
      debugPrint('Chart WebSocket error: $err');
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Timeframe Selector
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _intervals.map((interval) {
                final isSelected = _currentInterval == interval;
                return ChoiceChip(
                  label: Text(interval.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected && _currentInterval != interval) {
                      setState(() => _currentInterval = interval);
                      _initChart();
                    }
                  },
                );
              }).toList(),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _candles.isEmpty
                ? const Center(child: Text('No data available'))
                : ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: Candlesticks(candles: _candles),
                  ),
          ),
        ],
      ),
    );
  }
}
