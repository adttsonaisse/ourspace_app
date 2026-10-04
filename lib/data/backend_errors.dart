// Shared backend-failure helpers. One map for messages every repo and
// screen share (offline/timeout/network), instead of the same branches
// copied across friendlyAuthError/friendlySpaceError.

import 'dart:async';
import 'dart:io';

/// Message for transport-level failures, or null when [e] is not one.
/// Checked first by every friendly*Error mapper.
String? commonBackendMessage(Object e) {
  if (e is SocketException) {
    return 'No connection. Check internet and retry.';
  }
  final m = e.toString().toLowerCase();
  if (e is TimeoutException ||
      m.contains('timed out') ||
      m.contains('timeout')) {
    return 'No connection. Check internet and retry.';
  }
  if (m.contains('failed host') || m.contains('network')) {
    return 'No connection. Check internet and retry.';
  }
  return null;
}

/// Human text for any caught error. Friendly StateErrors (already mapped
/// by friendly*Error) pass through unwrapped; anything else renders raw.
/// NOTE: StateError.toString() yields 'Bad state: ...', never
/// 'StateError: ...' — strip both so toasts never leak the prefix.
String userMessage(Object e) {
  final m = e.toString();
  for (final p in ['Bad state: ', 'StateError: ']) {
    if (m.startsWith(p)) return m.substring(p.length);
  }
  return m;
}
