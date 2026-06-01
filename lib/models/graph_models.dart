class GraphPoint {
  final String label;
  final double value;

  const GraphPoint({required this.label, required this.value});
}

class GraphSeries {
  final String title;
  final List<GraphPoint> points;
  final String colorHex;

  const GraphSeries({
    required this.title,
    required this.points,
    this.colorHex = '#FF7B00',
  });
}
