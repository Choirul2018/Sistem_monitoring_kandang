class SupabaseConstants {
  SupabaseConstants._();

  // ─── Supabase Configuration ───
  // TODO: Replace with your actual Supabase project credentials
  static const String projectUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String anonKey = 'YOUR_ANON_KEY';

  // ─── Table Names ───
  static const String profilesTable = 'profiles';
  static const String locationsTable = 'locations';
  static const String auditsTable = 'audits';
  static const String auditPartsTable = 'audit_parts';
  static const String auditPhotosTable = 'audit_photos';
  static const String auditLivestockSamplesTable = 'livestock_samples';

  // ─── Storage Buckets ───
  static const String photosBucket = 'audit-photos';
  static const String signaturesBucket = 'signatures';
  static const String reportsBucket = 'reports';
}
