class FolderData {
  final String name;
  final String path;
  final String Status;
  final String StatusMessage;
  final DateTime discoveredAt;
  final DateTime? processedAt;
  final int attempts; // عدد محاولات المعالجة
  final String? taskId;// اختياري
  final String? accessToken; // token للمصادقة
  final String? refreshToken; // refresh token لتجديد access token
  final bool isDeleted;
  FolderData({
    required this.name,
    required this.path,
    required this.Status,
    required this.StatusMessage,
    required this.discoveredAt,
    this.processedAt,
    this.attempts = 0,
    this.taskId,
    this.accessToken,
    this.refreshToken,
    this.isDeleted = false,
  });

  factory FolderData.fromJson(Map<String, dynamic> json) => FolderData(
        name: json['name'] as String,
        path: json['path'] as String,
        Status: json['Status'] as String,
        StatusMessage: json['StatusMessage'] as String,
        discoveredAt: DateTime.parse(json['discoveredAt'] as String),
        processedAt: json['processedAt'] != null ? DateTime.parse(json['processedAt'] as String) : null,
        attempts: (json['attempts'] ?? 0) as int,
        taskId: json['taskId'] as String?,
        accessToken: json['accessToken'] as String?,
        refreshToken: json['refreshToken'] as String?,
       isDeleted: (json['isDeleted'] ?? json['deleted'] ?? false) is bool
    ? (json['isDeleted'] ?? json['deleted'] ?? false) as bool
    : (json['isDeleted'] ?? json['deleted'] ?? 'false').toString().toLowerCase() == 'true',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'Status': Status,
        'StatusMessage': StatusMessage,
        'discoveredAt': discoveredAt.toIso8601String(),
        'processedAt': processedAt?.toIso8601String(),
        'attempts': attempts,
        'taskId': taskId,
        // لا نطبع الـ tokens في JSON إذا كانت الحالة Success
        if (Status != 'Success') ...{
          'accessToken': accessToken,
          'refreshToken': refreshToken,
        },
        'isDeleted': isDeleted,
      };
}

class FoldersData {
  final List<FolderData> folders;

  FoldersData({required this.folders});

  Map<String, dynamic> toJson() => {
        'folders': folders.map((f) => f.toJson()).toList(),
      };

  factory FoldersData.fromJson(Map<String, dynamic> json) => FoldersData(
        folders: (json['folders'] as List<dynamic>)
            .map((e) => FolderData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
extension FolderDataCopy on FolderData {
  FolderData copyWith({
    String? name,
    String? path,
    String? Status,
    String? StatusMessage,
    DateTime? discoveredAt,
    DateTime? processedAt,
    int? attempts,
    String? taskId,
    String? accessToken,
    String? refreshToken,
    bool? isDeleted,
  }) {
    return FolderData(
      name: name ?? this.name,
      path: path ?? this.path,
      Status: Status ?? this.Status,
      StatusMessage: StatusMessage ?? this.StatusMessage,
      discoveredAt: discoveredAt ?? this.discoveredAt,
      processedAt: processedAt ?? this.processedAt,
      attempts: attempts ?? this.attempts,
      taskId: taskId ?? this.taskId,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
