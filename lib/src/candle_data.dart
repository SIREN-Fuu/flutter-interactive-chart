class CandleData {
  CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    required this.timestamp,
    List<double?>? trends,
  }) : trends = List.unmodifiable(trends ?? []);

  final double open;
  final double high;
  final double low;
  final double close;
  double? volume;
  final int timestamp;

  /// Data holder for additional trend lines, for this data point.
  ///
  /// For a single trend line, we can assign it as a list with a single element.
  /// For example if we want "7 days moving average", do something like
  /// `trends = [ma7]`. If there are multiple tread lines, we can assign a list
  /// with multiple elements, like `trends = [ma7, ma30]`.
  /// If we don't want any trend lines, we can assign an empty list.
  ///
  /// This should be an unmodifiable list, so please do not use `add`
  /// or `clear` methods on the list. Always assign a new list if values
  /// are changed. Otherwise the UI might not be updated.
  List<double?> trends;

  static List<double?> computeMA(List<CandleData> data, [int period = 7]) {
    // If data is not at least twice as long as the period, return nulls.
    if (data.length < period * 2) {
      return List.filled(data.length, null);
    }

    final result = <double?>[];
    // Skip the first [period] data points. For example, skip 7 data points.
    final firstPeriod =
        data.take(period).map((d) => d.close).whereType<double>();
    var ma = firstPeriod.reduce((a, b) => a + b) / firstPeriod.length;
    result.addAll(List.filled(period, null));

    // Compute the moving average for the rest of the data points.
    for (var i = period; i < data.length; i++) {
      final curr = data[i].close;
      final prev = data[i - period].close;
      ma = (ma * period + curr - prev) / period;
      result.add(ma);
    }
    return result;
  }

  @override
  String toString() => '<CandleData ($timestamp: $close)>';
}
