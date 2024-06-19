import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import 'candle_data.dart';
import 'chart_painter.dart';
import 'chart_style.dart';
import 'painter_params.dart';

class InteractiveChart extends StatefulWidget {
  const InteractiveChart({Key? key, required this.candles}) : super(key: key);

  /// The full list of [CandleData] to be used for this chart.
  ///
  /// It needs to have at least 3 data points. If data is sufficiently large,
  /// the chart will default to display the most recent 90 data points when
  /// first opened (configurable with initialVisibleCandleCount parameter),
  /// and allow users to freely zoom and pan however they like.
  final List<CandleData> candles;

  @override
  InteractiveChartState createState() => InteractiveChartState();
}

class InteractiveChartState extends State<InteractiveChart> {
  final style = const ChartStyle();

  final initialVisibleCandleCount = 90;

  // The width of an individual bar in the chart.
  late double _candleWidth;

  // The x offset (in px) of current visible chart window,
  // measured against the beginning of the chart.
  // i.e. a value of 0.0 means we are displaying data for the very first day,
  // and a value of 20 * _candleWidth would be skipping the first 20 days.
  late double _startOffset;

  // The position that user is currently tapping, null if user let go.
  Offset? _tapPosition;

  double? _prevChartWidth; // used by _handleResize
  late double _prevCandleWidth;
  late double _prevStartOffset;
  late Offset _initialFocalPoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final size = constraints.biggest;
        final w = size.width - style.priceLabelWidth;
        _handleResize(w);

        // Find the visible data range
        final start = (_startOffset / _candleWidth).floor();
        final count = (w / _candleWidth).ceil();
        final end = (start + count).clamp(start, widget.candles.length);
        final candlesInRange = widget.candles.getRange(start, end).toList();
        if (end < widget.candles.length) {
          // Put in an extra item, since it can become visible when scrolling
          final nextItem = widget.candles[end];
          candlesInRange.add(nextItem);
        }

        // If possible, find neighbouring trend line data,
        // so the chart could draw better-connected lines
        final leadingTrends = widget.candles.at(start - 1)?.trends;
        final trailingTrends = widget.candles.at(end + 1)?.trends;

        // Find the horizontal shift needed when drawing the candles.
        // First, always shift the chart by half a candle, because when we
        // draw a line using a thick paint, it spreads to both sides.
        // Then, we find out how much "fraction" of a candle is visible, since
        // when users scroll, they don't always stop at exact intervals.
        final halfCandle = _candleWidth / 2;
        final fractionCandle = _startOffset - start * _candleWidth;
        final xShift = halfCandle - fractionCandle;

        final maxPrice =
            candlesInRange.map((c) => c.high).whereType<double>().reduce(max);

        final minPrice =
            candlesInRange.map((c) => c.low).whereType<double>().reduce(min);

        final maxVol = candlesInRange
            .map((c) => c.volume)
            .whereType<double>()
            .fold(double.negativeInfinity, max);
        final minVol = candlesInRange
            .map((c) => c.volume)
            .whereType<double>()
            .fold(double.infinity, min);

        final params = PainterParams(
          candles: candlesInRange,
          style: style,
          size: size,
          candleWidth: _candleWidth,
          startOffset: _startOffset,
          maxPrice: maxPrice,
          minPrice: minPrice,
          maxVol: maxVol,
          minVol: minVol,
          xShift: xShift,
          tapPosition: _tapPosition,
          leadingTrends: leadingTrends,
          trailingTrends: trailingTrends,
        );

        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              final dy = signal.scrollDelta.dy;
              if (dy.abs() > 0) {
                _onScaleStart(signal.position);
                _onScaleUpdate(
                  dy > 0 ? 0.9 : 1.1,
                  signal.position,
                  w,
                );
              }
            }
          },
          child: GestureDetector(
            // Tap and hold to view candle details
            onTapDown: (details) => setState(() {
              _tapPosition = details.localPosition;
            }),
            onTapCancel: () => setState(() => _tapPosition = null),
            onTapUp: (_) {
              setState(() => _tapPosition = null);
            },
            // Pan and zoom
            onScaleStart: (details) => _onScaleStart(details.localFocalPoint),
            onScaleUpdate: (details) =>
                _onScaleUpdate(details.scale, details.localFocalPoint, w),
            child: CustomPaint(
              size: size,
              painter: ChartPainter(
                params: params,
                getTimeLabel: defaultTimeLabel,
                getPriceLabel: defaultPriceLabel,
                getOverlayInfo: defaultOverlayInfo,
              ),
            ),
          ),
        );
      },
    );
  }

  void _onScaleStart(Offset focalPoint) {
    _prevCandleWidth = _candleWidth;
    _prevStartOffset = _startOffset;
    _initialFocalPoint = focalPoint;
  }

  void _onScaleUpdate(double scale, Offset focalPoint, double w) {
    // Handle zoom
    final candleWidth = (_prevCandleWidth * scale)
        .clamp(_getMinCandleWidth(w), _getMaxCandleWidth(w));
    final clampedScale = candleWidth / _prevCandleWidth;
    var startOffset = _prevStartOffset * clampedScale;

    // Handle pan
    final dx = (focalPoint - _initialFocalPoint).dx * -1;
    startOffset += dx;

    // Adjust pan when zooming
    final prevCount = w / _prevCandleWidth;
    final currCount = w / candleWidth;
    final zoomAdjustment = (currCount - prevCount) * candleWidth;
    final focalPointFactor = focalPoint.dx / w;
    startOffset -= zoomAdjustment * focalPointFactor;
    startOffset = startOffset.clamp(0, _getMaxStartOffset(w, candleWidth));

    // Apply changes
    setState(() {
      _candleWidth = candleWidth;
      _startOffset = startOffset;
    });
  }

  void _handleResize(double w) {
    if (w == _prevChartWidth) {
      return;
    }
    if (_prevChartWidth != null) {
      // Re-clamp when size changes (e.g. screen rotation)
      _candleWidth = _candleWidth.clamp(
        _getMinCandleWidth(w),
        _getMaxCandleWidth(w),
      );
      _startOffset = _startOffset.clamp(
        0,
        _getMaxStartOffset(w, _candleWidth),
      );
    } else {
      // Default zoom level. Defaults to a 90 day chart, but configurable.
      // If data is shorter, we use the whole range.
      final count = min(
        widget.candles.length,
        initialVisibleCandleCount,
      );
      _candleWidth = w / count;
      // Default show the latest available data, e.g. the most recent 90 days.
      _startOffset = (widget.candles.length - count) * _candleWidth;
    }
    _prevChartWidth = w;
  }

  // The narrowest candle width, i.e. when drawing all available data points.
  double _getMinCandleWidth(double w) => w / widget.candles.length;

  // The widest candle width, e.g. when drawing 14 day chart
  double _getMaxCandleWidth(double w) => w / min(14, widget.candles.length);

  // Max start offset: how far can we scroll towards the end of the chart
  double _getMaxStartOffset(double w, double candleWidth) {
    final count = w / candleWidth; // visible candles in the window
    final start = widget.candles.length - count;
    return max(0, candleWidth * start);
  }

  String defaultTimeLabel(int timestamp, int visibleDataCount) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp)
        .toIso8601String()
        .split('T')
        .first
        .split('-');

    if (visibleDataCount > 20) {
      // If more than 20 data points are visible, we should show year and month.
      return '${date[0]}-${date[1]}'; // yyyy-mm
    } else {
      // Otherwise, we should show month and date.
      return '${date[1]}-${date[2]}'; // mm-dd
    }
  }

  String defaultPriceLabel(double price) => price.toStringAsFixed(2);

  Map<String, String> defaultOverlayInfo(CandleData candle) {
    final date = intl.DateFormat.yMMMd()
        .format(DateTime.fromMillisecondsSinceEpoch(candle.timestamp));
    return {
      'Date': date,
      'Open': candle.open.toStringAsFixed(2),
      'High': candle.high.toStringAsFixed(2),
      'Low': candle.low.toStringAsFixed(2),
      'Close': candle.close.toStringAsFixed(2),
      'Volume': candle.volume?.asAbbreviated() ?? '-',
    };
  }
}

extension Formatting on double {
  String asPercent() {
    final format = this < 100 ? '##0.00' : '#,###';
    final v = intl.NumberFormat(format, 'en_US').format(this);
    return "${this >= 0 ? '+' : ''}$v%";
  }

  String asAbbreviated() {
    if (this < 1000) {
      return toStringAsFixed(3);
    }
    if (this >= 1e18) {
      return toStringAsExponential(3);
    }
    final s = intl.NumberFormat('#,###', 'en_US').format(this).split(',');
    const suffixes = ['K', 'M', 'B', 'T', 'Q'];
    return '${s[0]}.${s[1]}${suffixes[s.length - 2]}';
  }
}
