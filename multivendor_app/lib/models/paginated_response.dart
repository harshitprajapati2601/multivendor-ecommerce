/// Mirrors the JSON shape of Spring Data's Page<T>, which every browse/list
/// endpoint in the backend returns (products, orders, reviews).
class PaginatedResponse<T> {
  final List<T> content;
  final int totalPages;
  final int totalElements;
  final int number; // current page index (0-based)
  final int size;
  final bool last;
  final bool first;

  PaginatedResponse({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.number,
    required this.size,
    required this.last,
    required this.first,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawContent = (json['content'] as List?) ?? [];
    return PaginatedResponse<T>(
      content: rawContent.map((e) => fromJsonT(e as Map<String, dynamic>)).toList(),
      totalPages: json['totalPages'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      number: json['number'] ?? 0,
      size: json['size'] ?? 20,
      last: json['last'] ?? true,
      first: json['first'] ?? true,
    );
  }
}
