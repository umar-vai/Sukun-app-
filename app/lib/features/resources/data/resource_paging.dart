/// Loads a complete, stable sequence from a paginated backend.
///
/// [loadPage] receives inclusive start/end offsets. The caller must supply
/// deterministic ordering (with a unique tie-breaker) and enforce access
/// control in each query. A short page indicates the end of the sequence.
Future<List<T>> fetchAllResourcePages<T>({
  required Future<List<T>> Function(int from, int to) loadPage,
  int pageSize = 500,
}) async {
  if (pageSize < 1) {
    throw ArgumentError.value(pageSize, 'pageSize', 'Must be positive');
  }

  final items = <T>[];
  var offset = 0;
  while (true) {
    final page = await loadPage(offset, offset + pageSize - 1);
    if (page.length > pageSize) {
      throw StateError('Backend returned more than one requested page');
    }
    items.addAll(page);
    if (page.length < pageSize) break;
    offset += page.length;
  }
  return List<T>.unmodifiable(items);
}
