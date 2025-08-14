import 'dart:convert';

class ConnectedOptionsRequest {
  final int table_id;
  final int controlId;
  final Map<String, dynamic> flitter;
  final int pageSize;
  final String fields; // default
  final String order;
  final String q;
  final Map<String, dynamic> extraFilters;
  final Map<String, dynamic> controlValues;

  ConnectedOptionsRequest({
    required this.table_id,
    required this.controlId,
    this.flitter = const {},
    this.pageSize = 50,
    this.fields = 'default',
    this.order = '',
    this.q = '',
    this.extraFilters = const {},
    this.controlValues = const {},
  });

  Map<String, String> toQuery() {
    return {
      'table_id': table_id.toString(),
      'connected_control_id': controlId.toString(),
      'filters': jsonEncode(flitter),
      'page_size': pageSize.toString(),
      'fields': fields,
      if (order.isNotEmpty) 'order': order,
      if (q.isNotEmpty) 'q': q,
      if (extraFilters.isNotEmpty) 'filters': jsonEncode(extraFilters),
      if (controlValues.isNotEmpty) 'control_values': jsonEncode(controlValues),
    };
  }
}

class GetDataFormRequest {
  final int tableId;
  final int maxRowNumber;
  final int howManyRows;
  final String fields;
  final String filters; // JSON كـ نص
  final String ordertype;
  final int? connectedControlId;
  final Map<String, dynamic> controlValues;
  final String? orderfields;

  GetDataFormRequest({
    required this.tableId,
    this.maxRowNumber = 0,
    this.howManyRows = 50,
    this.fields = 'default',
    this.filters = '',
    this.ordertype = 'DESC',
    this.connectedControlId,
    this.controlValues = const {},
    this.orderfields,
  });

  Map<String, String> toQuery() {
    return {
      'table_id': tableId.toString(),
      'maxRowNumber': maxRowNumber.toString(),
      'howManyRows': howManyRows.toString(),
      'fields': fields,
      if (filters.isNotEmpty) 'filters': filters,
      'ordertype': ordertype,
      if (connectedControlId != null)
        'connected_control_id': connectedControlId.toString(),
      if (controlValues.isNotEmpty) 'control_values': jsonEncode(controlValues),
      if (orderfields != null) 'orderfields': orderfields!,
    };
  }
}
