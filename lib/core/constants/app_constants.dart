class AppConstants {
  AppConstants._();

  // ─── App Info ───
  static const String appName = 'Monitoring Kandang';
  static const String appVersion = '1.0.0';

  // ─── Geofencing ───
  static const double defaultGeofenceRadiusMeters = 500.0;
  static const double gpsAccuracyThreshold = 50.0; // meters

  // ─── Auto-Save ───
  static const int autoSaveIntervalSeconds = 5;
  static const int autoSaveDebounceMs = 1000;

  // ─── Photo Quality (AI) ───
  static const double blurThreshold = 100.0;
  static const double minBrightness = 40.0;
  static const double maxBrightness = 220.0;
  static const double minVariance = 15.0; // below = blank image
  static const double objectConfidenceThreshold = 0.6;

  // ─── Photo ───
  static const int maxPhotoWidth = 1920;
  static const int maxPhotoHeight = 1080;
  static const int watermarkFontSize = 14;
  static const int photoTimestampToleranceSeconds = 60;

  // ─── Sync ───
  static const int syncRetryMaxAttempts = 5;
  static const int syncChunkSizeBytes = 1024 * 512; // 512KB chunks
  static const Duration syncInterval = Duration(minutes: 15);

  // ─── Audit Parts (Default Order) ───
  static const List<String> defaultAuditParts = [
    'Gerbang',
    'Jalan Masuk',
    'Area Kantor/Pos',
    'Gudang',
    'Tempat Pakan',
    'Tempat Minum',
    'Kandang 1',
    'Kandang 2',
  ];

  // ─── Condition Options ───
  static const List<String> conditionOptions = ['Baik', 'Cukup', 'Buruk'];

  // ─── Audit Status ───
  static const String statusDraft = 'draft';
  static const String statusInProgress = 'in_progress';
  static const String statusPendingReview = 'pending_review';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // ─── User Roles ───
  static const String roleAuditor = 'auditor';
  static const String roleKabag = 'kabag';
  static const String roleKadiv = 'kadiv';
  static const String roleAdmin = 'admin';
}
