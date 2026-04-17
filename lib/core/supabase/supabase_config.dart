import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration
/// Replace these values with your actual Supabase project credentials
/// Found in: Supabase Dashboard → Settings → API
class SupabaseConfig {
  // 🔴 REPLACE WITH YOUR ACTUAL VALUES
  static const String supabaseUrl = 'https://ecafovpohzocxsorgpku.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVjYWZvdnBvaHpvY3hzb3JncGt1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMTY2OTEsImV4cCI6MjA5MTg5MjY5MX0.nkTSL_BrXqgHrrkPCDk4oz1REwJHEUOowqymO9165g8';
  // Use service_role key for server-side operations (keep this secret)
  static const String supabaseServiceKey = 'sb_secret_wkhJ8wRW6OVUxevSKAc1ag_uOgLo9xo';
}

/// Global Supabase client accessor
class SupabaseClientHelper {
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase — call once in main()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  /// Quick access to tables
  static SupabaseQueryBuilder table(String name) => client.from(name);
}