import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';

import '../data/app_update_repo.dart';
import '../data/storage_maintenance.dart';
import '../theme/kawaii.dart';
import 'kawaii.dart';

/// Update dialog: direct download + install on Android when the release
/// carries an APK asset, otherwise a shortcut to the release page
/// (iOS and asset-less releases). Shared by the shell auto-check and the
/// manual "Check for update" row in Settings.
class AppUpdateDialog extends StatefulWidget {
  final AppRelease release;
  final VoidCallback onLater;
  final VoidCallback onOpenRelease;
  const AppUpdateDialog({
    super.key,
    required this.release,
    required this.onLater,
    required this.onOpenRelease,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _busy = false;
  bool _installing = false;
  int _progress = 0;
  String? _error;
  StreamSubscription<OtaEvent>? _sub;

  bool get _direct =>
      Platform.isAndroid && widget.release.supportsDirectInstall;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _startDownload() {
    if (_busy) return;
    setState(() {
      _busy = true;
      _installing = false;
      _progress = 0;
      _error = null;
    });
    // Free space first: old ourspace-*.apk otherwise pile up (~54MB each)
    // in files/ota_update/ and storage balloons.
    pruneOtaUpdates(keepNewest: 0).then((_) {
      if (!mounted) return;
      final tag = widget.release.tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
      _sub = OtaUpdate()
          .execute(widget.release.apkUrl,
              destinationFilename: 'ourspace-$tag.apk')
          .listen((e) {
        if (!mounted) return;
        switch (e.status) {
          case OtaStatus.DOWNLOADING:
            setState(() => _progress = int.tryParse(e.value ?? '0') ?? 0);
          case OtaStatus.INSTALLING:
            setState(() {
              _installing = true;
              _progress = 100;
            });
          case OtaStatus.INSTALLATION_DONE:
            if (mounted) Navigator.of(context).maybePop();
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            setState(() {
              _busy = false;
              _error = 'Allow “install unknown apps” for ourspace, then retry.';
            });
          case OtaStatus.DOWNLOAD_ERROR:
            setState(() {
              _busy = false;
              _error = 'Download failed — check connection and retry.';
            });
          default:
            setState(() {
              _busy = false;
              _error = 'Update hiccuped — try the release page instead.';
            });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final rel = widget.release;
    final notes = rel.notes.trim();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: KawaiiCard(
        color: Kawaii.sunnySubtle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KawaiiPill(label: 'fresh sticker drop', color: Kawaii.sunny),
            const SizedBox(height: 12),
            Text('ourspace ${rel.tag} is here',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: Kawaii.displayFamily)),
            const SizedBox(height: 6),
            Text(
              notes.isEmpty
                  ? 'A cuter build is waiting on GitHub.'
                  : (notes.length > 220 ? '${notes.substring(0, 220)}…' : notes),
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (_busy) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _installing ? null : _progress / 100,
                        minHeight: 12,
                        backgroundColor: Colors.white,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Kawaii.mint),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_installing ? '…' : '$_progress%',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _installing
                    ? 'Installing — confirm on the system prompt.'
                    : 'Downloading update… keep the app open.',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ] else if (_direct)
              KawaiiButton(
                label: 'Download & install',
                icon: Icons.file_download_rounded,
                color: KawaiiBtnColor.sunny,
                onTap: _startDownload,
              )
            else
              KawaiiButton(
                label: 'View release',
                icon: Icons.file_download_rounded,
                color: KawaiiBtnColor.sunny,
                onTap: widget.onOpenRelease,
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Kawaii.ink)),
              if (_direct)
                TextButton(
                  onPressed: widget.onOpenRelease,
                  child: const Text('Open release page instead',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Kawaii.ink,
                          decoration: TextDecoration.underline)),
                ),
            ],
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy && _error == null ? null : widget.onLater,
                child: const Text('Later',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Kawaii.ink,
                        decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
