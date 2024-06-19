import 'dart:ui';

import 'candle_data.dart';
import 'chart_style.dart';

class PainterParams {
  PainterParams({
    required this.candles,
    required this.style,
    required this.size,
    required this.candleWidth,
    required this.startOffset,
    required this.maxPrice,
    required this.minPrice,
    required this.maxVol,
    required this.minVol,
    required this.xShift,
    required this.tapPosition,
    required this.leadingTrends,
    required this.trailingTrends,
  });
  final List<CandleData> candles;
  final ChartStyle style;
  final Size size;
  final double candleWidth;
  final double startOffset;

  final double maxPrice;
  final double minPrice;
  final double maxVol;
  final double minVol;

  final double xShift;
  final Offset? tapPosition;
  final List<double?>? leadingTrends;
  final List<double?>? trailingTrends;

  // width without price labels
  double get chartWidth => size.width - style.priceLabelWidth;

  // height without time labels
  double get chartHeight => size.height - style.timeLabelHeight;

  double get volumeHeight => chartHeight * style.volumeHeightFactor;

  double get priceHeight => chartHeight - volumeHeight;

  int getCandleIndexFromOffset(double x) {
    final adjustedPos = x - xShift + candleWidth / 2;
    final i = adjustedPos ~/ candleWidth;
    return i;
  }

  double fitPrice(double y) =>
      priceHeight * (maxPrice - y) / (maxPrice - minPrice);

  double fitVolume(double y) {
    // the gap between price bars and volume bars
    const gap = 12;
    // display at least "something" for the lowest volume
    const baseAmount = 2;

    if (maxVol == minVol) {
      // Since they are equal, we just draw all volume bars as half height.
      return priceHeight + volumeHeight / 2;
    }

    final volGridSize = (volumeHeight - baseAmount - gap) / (maxVol - minVol);
    final vol = (y - minVol) * volGridSize;
    return volumeHeight - vol + priceHeight - baseAmount;
  }

  bool shouldRepaint(PainterParams other) {
    if (candles.length != other.candles.length) {
      return true;
    }

    if (size != other.size ||
        candleWidth != other.candleWidth ||
        startOffset != other.startOffset ||
        xShift != other.xShift) {
      return true;
    }

    if (maxPrice != other.maxPrice ||
        minPrice != other.minPrice ||
        maxVol != other.maxVol ||
        minVol != other.minVol) {
      return true;
    }

    if (tapPosition != other.tapPosition) {
      return true;
    }

    if (leadingTrends != other.leadingTrends ||
        trailingTrends != other.trailingTrends) {
      return true;
    }

    if (style != other.style) {
      return true;
    }

    return false;
  }
}
