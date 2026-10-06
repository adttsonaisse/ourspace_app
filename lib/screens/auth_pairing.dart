import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../data/models/space.dart';
import '../data/backend.dart';
import '../data/repos.dart';
import '../data/space_repo.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import '../widgets/kawaii_deco.dart';
import '../shell.dart';

class PairingPage extends StatefulWidget {
  final SpaceRepo? spaceRepo;
  final String? spaceName;
  const PairingPage({super.key, this.spaceRepo, this.spaceName});
  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  int tab = 0; // 0 invite, 1 join
  late final SpaceRepo _spaces;
  final codeCtrl = TextEditingController();

  Space? _space;
  InviteCode? _invite;
  bool _loading = true;
  String? _loadError;
  String? _loadDetail;
  Timer? _ticker;
  Duration _left = Duration.zero;

  bool _joining = false;
  Space? _joined;
  String? _freshError;
  String? _joinError;

  /// True when pairing cannot work because there is no backend
  /// (local demo / solo explore). Invite codes only come from Supabase.
  bool get _isDemo => _spaces is DemoSpaceRepo;

  @override
  void initState() {
    super.initState();
    _spaces = widget.spaceRepo ?? resolveSpaceRepo();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _loadDetail = null;
    });
    String step = 'mySpace';
    try {
      var space =
          await _spaces.mySpace().timeout(const Duration(seconds: 15));
      step = 'createSpace';
      space ??= await _spaces
          .createSpace(widget.spaceName ?? 'Our space')
          .timeout(const Duration(seconds: 15));
      step = 'createInvite';
      final invite = await _spaces
          .createInvite(space.id)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _space = space;
        _invite = invite;
        _loading = false;
      });
      _restartTicker();
    } catch (e) {
      debugPrint('[pairing] bootstrap failed at $step (${e.runtimeType}): $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = friendlySpaceError(e);
        _loadDetail = 'step=$step type=${e.runtimeType} err=$e';
      });
    }
  }

  void _restartTicker() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final inv = _invite;
    if (inv == null || !mounted) return;
    final left = inv.expiresAt.difference(DateTime.now());
    setState(() => _left = left.isNegative ? Duration.zero : left);
  }

  String get _countdown {
    final h = _left.inHours.toString().padLeft(2, '0');
    final m = (_left.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_left.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  bool get _expired {
    final inv = _invite;
    return inv != null && DateTime.now().isAfter(inv.expiresAt);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    codeCtrl.dispose();
    super.dispose();
  }

  void _copyCode() {
    final code = _invite?.code;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    showKawaiiToast(context, 'Code copied! Go text your person',
        kind: KawaiiAlertKind.success);
  }

  Future<void> _shareCode() async {
    final code = _invite?.code;
    if (code == null) return;
    await SharePlus.instance.share(ShareParams(
        text: 'Join me on ourspace! Pair code: $code (expires in $_countdown)'));
  }

  Future<void> _freshCode() async {
    final space = _space;
    if (space == null) return;
    try {
      final invite = await _spaces.createInvite(space.id);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _freshError = null;
      });
      _restartTicker();
    } catch (e) {
      debugPrint('[pairing] fresh code failed: $e');
      if (!mounted) return;
      setState(() => _freshError = friendlySpaceError(e));
    }
  }

  Future<void> _join() async {
    final code = codeCtrl.text.trim();
    if (code.isEmpty || _joining) return;
    setState(() {
      _joining = true;
      _joinError = null;
    });
    try {
      final space = await _spaces.joinWithCode(code);
      // Drop our own pre-created empty space so no orphan lingers.
      final own = _space;
      if (own != null && own.id != space.id) {
        try {
          await _spaces.leave(own.id);
        } catch (_) {}
        _space = null;
        _invite = null;
        _ticker?.cancel();
      }
      if (mounted) setState(() => _joined = space);
    } catch (e) {
      if (!mounted) return;
      setState(() => _joinError = friendlySpaceError(e));
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _enter(bool paired) {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final edge = Kawaii.edgeOf(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Kawaii.cardOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: edge, width: Kawaii.paperBorderW),
            ),
            child: Icon(Icons.arrow_back_rounded, size: 18, color: Kawaii.textOf(context)),
          ),
        ),
        title: const Text('pair your person',
            style:
                TextStyle(fontWeight: FontWeight.w900, fontFamily: Kawaii.displayFamily)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const KawaiiAppMascot(size: 64),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const KawaiiAvatar(text: 'Y', bg: Kawaii.peach, size: 64),
                const SizedBox(width: 4),
                const Icon(Icons.link_rounded, size: 28),
                const SizedBox(width: 4),
                KawaiiAvatar(
                    text: '?', bg: Kawaii.cardOf(context), size: 64),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KawaiiDoodles(),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Two phones,\none scrapbook',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w900, fontFamily: Kawaii.displayFamily, height: 1.1),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share a code to link spaces. It expires in 24h — cute pressure.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Kawaii.cardOf(context),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: edge, width: Kawaii.borderW),
                boxShadow: Kawaii.sticker(context),
              ),
              child: Column(children: [
                Row(children: [
                  Expanded(child: _seg('Invite them', 0, Kawaii.sunny)),
                  Expanded(child: _seg('I have a code', 1, Kawaii.mint)),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  child: tab == 0 ? _inviteCard() : _joinCard(),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            if (tab == 0)
              KawaiiButton(
                label: _isDemo
                    ? 'Explore solo for now'
                    : 'Enter ourspace together',
                color: KawaiiBtnColor.sunny,
                icon: _isDemo
                    ? Icons.explore_rounded
                    : Icons.favorite_rounded,
                onTap: _isDemo ? () => _enter(false) : (_invite == null ? null : () => _enter(true)),
              )
            else
              KawaiiButton(
                label: _joining ? 'Pairing…' : 'Pair & open home',
                color: KawaiiBtnColor.mint,
                icon: Icons.favorite_rounded,
                onTap: (_joined == null || _joining) ? null : () => _enter(true),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AppShell()),
                  (_) => false),
              child: Text('Skip for now — explore solo',
                  style: TextStyle(
                      fontFamily: Kawaii.displayFamily,
                      fontWeight: FontWeight.w700,
                      color: Kawaii.textOf(context),
                      decoration: TextDecoration.underline)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String l, int i, Color c) {
    final active = tab == i;
    final edge = Kawaii.edgeOf(context);
    return Semantics(
      button: true,
      selected: active,
      label: l,
      child: GestureDetector(
      onTap: () => setState(() => tab = i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? edge : Colors.transparent, width: Kawaii.paperBorderW),
        ),
        alignment: Alignment.center,
        child: Text(l,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontFamily: Kawaii.displayFamily,
                fontSize: 14,
                color: active ? Kawaii.ink : Kawaii.textOf(context))),
      ),
      ),
    );
  }

  Widget _inviteCard() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      final msg = _loadError!;
      final low = msg.toLowerCase();
      final KawaiiAlert alert;
      if (_isDemo || low.contains('solo demo')) {
        alert = KawaiiAlert(
          title: 'Solo mode — no code yet',
          message:
              'You\'re exploring offline. Log in to get a real 24h pair code for two phones. Notes, piles & dates all work solo.',
          kind: KawaiiAlertKind.info,
          actionLabel: 'Explore solo',
          onAction: () => _enter(false),
        );
      } else {
        final title = low.contains('log in')
            ? 'Hold on — log in first'
            : low.contains('no connection') || low.contains('check internet')
                ? 'No connection'
                : 'Could not make a code';
        alert = KawaiiAlert(
          title: title,
          message: msg,
          kind: KawaiiAlertKind.danger,
          actionLabel: 'Retry',
          onAction: _bootstrap,
        );
      }
      // Raw step + error for diagnostics. Debug builds only —
      // release builds keep the friendly copy.
      final detail = _loadDetail;
      if (!kDebugMode || detail == null) return alert;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          alert,
          const SizedBox(height: 8),
          SelectableText(
            detail,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    final edge = Kawaii.edgeOf(context);
    final cardBg = Kawaii.isDark(context) ? Kawaii.night : Kawaii.cream;
    final code = _invite?.code ?? '…';
    return Column(children: [
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: edge, width: Kawaii.paperBorderW, style: BorderStyle.solid),
        ),
        child: Column(children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KawaiiDoodles(),
            ],
          ),
          const SizedBox(height: 8),
          Text('YOUR PAIR CODE',
              style: TextStyle(
                  fontFamily: Kawaii.displayFamily,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: Kawaii.mutedOf(context),
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(code,
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontFamily: Kawaii.displayFamily,
                  color: Kawaii.textOf(context),
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          KawaiiPill(
              label: _expired ? 'expired — make a fresh one' : 'expires in $_countdown',
              color: Kawaii.sunnySubtle),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: KawaiiButton(
              label: 'Copy',
              icon: Icons.copy_rounded,
              color: KawaiiBtnColor.white,
              expanded: true,
              onTap: _invite == null ? null : _copyCode),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: KawaiiButton(
              label: 'Share',
              icon: Icons.ios_share_rounded,
              color: KawaiiBtnColor.sky,
              onTap: _invite == null ? null : _shareCode),
        ),
      ]),
      TextButton(
        onPressed: _freshCode,
        child: Text('Fresh code',
            style: TextStyle(
                fontFamily: Kawaii.displayFamily,
                fontWeight: FontWeight.w700,
                color: Kawaii.textOf(context),
                decoration: TextDecoration.underline)),
      ),
      if (_freshError != null) ...[
        const SizedBox(height: 8),
        KawaiiAlert(
          title: 'Could not make a fresh code',
          message: _freshError!,
          kind: KawaiiAlertKind.danger,
          actionLabel: 'Retry',
          onAction: _freshCode,
          onClose: () => setState(() => _freshError = null),
        ),
      ],
    ]);
  }

  Widget _joinCard() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          if (_isDemo)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: KawaiiAlert(
                title: 'Solo mode — joining needs login',
                message:
                    'Partner codes are checked on the backend. Log in first, or keep exploring solo.',
                kind: KawaiiAlertKind.info,
              ),
            ),
          KawaiiInput(
              hint: 'e.g. 482916',
              label: 'PARTNER CODE',
              controller: codeCtrl,
              keyboard: TextInputType.number,
              prefix: Icons.confirmation_number_outlined),
          const SizedBox(height: 12),
          if (_joinError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: KawaiiAlert(
                title: "That code didn't work",
                message: _joinError!,
                kind: KawaiiAlertKind.danger,
                onClose: () => setState(() => _joinError = null),
              ),
            ),
          if (_joined != null)
            KawaiiAlert(
              title: 'Found ${_joined!.name}!',
              message: 'Pair to open your shared space.',
              kind: KawaiiAlertKind.success,
            )
          else
            KawaiiButton(
              label: _joining ? 'Checking…' : 'Check code',
              icon: Icons.link_rounded,
              color: KawaiiBtnColor.mint,
              onTap: _joining ? null : _join,
            ),
        ]);
  }
}
