import 'package:sitramix/config/app_config.dart';

class PageQuery {
  const PageQuery({
    this.page = AppConfig.defaultPage,
    this.pageSize = AppConfig.defaultPageSize,
    this.filters = const <String, String>{},
  }) : assert(page >= 1, 'page inicia en 1'),
       assert(
         pageSize >= 1 && pageSize <= AppConfig.maxPageSize,
         'pageSize debe estar entre 1 y ${AppConfig.maxPageSize}',
       );

  final int page;
  final int pageSize;

  final Map<String, String> filters;

  Map<String, String> toQueryParameters() => <String, String>{
    'page': '$page',
    'pageSize': '$pageSize',
    ...filters,
  };

  PageQuery nextPage() =>
      PageQuery(page: page + 1, pageSize: pageSize, filters: filters);

  bool hasNext(int receivedItems) => receivedItems >= pageSize;
}
