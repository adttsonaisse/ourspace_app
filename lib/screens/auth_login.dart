import 'package:flutter/material.dart';
import '../data/auth_repo.dart';
import '../data/backend.dart';
import '../data/repos.dart';
import '../theme/kawaii.dart';
import '../widgets/kawaii.dart';
import 'auth_pairing.dart';
import '../shell.dart';

class LoginRegisterPage extends StatefulWidget {
  final bool loginFirst;
  final AuthRepo? auth;
  const LoginRegisterPage({super.key, this.loginFirst = false, this.auth});

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  late bool isLogin;
  late final AuthRepo _auth;
  bool _busy = false;
  String? _alertTitle;
  String? _alertMessage;
  KawaiiAlertKind _alertKind = KawaiiAlertKind.danger;
  String? _alertAction;
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    isLogin = widget.loginFirst;
    _auth = widget.auth ?? resolveAuthRepo();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is needed';
    final email = v.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return 'That email looks off';
    }
    return null;
  }

  String? _passValidator(String? v) {
    if (v == null || v.isEmpty) return 'Password is needed';
    if (!isLogin && v.length < 6) return 'Min 6 characters';
    return null;
  }

  void _switchMode(bool toLogin) => setState(() {
        isLogin = toLogin;
        _alertTitle = null;
        _alertMessage = null;
        _alertAction = null;
      });

  void _showAlert(String title, String message, KawaiiAlertKind kind,
      [String? action]) {
    setState(() {
      _alertTitle = title;
      _alertMessage = message;
      _alertKind = kind;
      _alertAction = action;
    });
  }

  void _handleAuthError(Object e, {required bool wasLogin}) {
    final msg = friendlyAuthError(e);
    final raw = '$e $msg'.toLowerCase();
    final offline = raw.contains('no connection') ||
        raw.contains('check internet') ||
        raw.contains('timed out') ||
        raw.contains('timeout') ||
        raw.contains('network') ||
        raw.contains('failed host') ||
        raw.contains('socket');
    if (offline) {
      _showAlert('No connection', msg, KawaiiAlertKind.warning);
      return;
    }
    if (raw.contains('confirm')) {
      _showAlert(
          'Confirm your email first', msg, KawaiiAlertKind.warning);
      return;
    }
    if (raw.contains('already registered') ||
        raw.contains('already exists') ||
        raw.contains('already have an account')) {
      _showAlert('Already registered', msg, KawaiiAlertKind.info, 'Log in');
      return;
    }
    if (wasLogin &&
        (raw.contains("didn't match") ||
            raw.contains('invalid login') ||
            raw.contains('invalid credentials') ||
            raw.contains('user not found') ||
            raw.contains('not found'))) {
      _showAlert(
        'No account for this email yet',
        "We couldn't match that email + password. Check for typos or make a space instead.",
        KawaiiAlertKind.danger,
        'Create one',
      );
      return;
    }
    if (raw.contains('password')) {
      _showAlert('Check your password', msg, KawaiiAlertKind.danger);
      return;
    }
    if (raw.contains('email') || raw.contains('looks off')) {
      _showAlert('Check your email', msg, KawaiiAlertKind.danger);
      return;
    }
    _showAlert("Hmm, that didn't work", msg, KawaiiAlertKind.danger);
  }

  Future<void> _continue() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _busy) return;
    final wasLogin = isLogin;
    final email = _emailCtrl.text.trim().toLowerCase();
    setState(() {
      _busy = true;
      _alertTitle = null;
      _alertMessage = null;
      _alertAction = null;
    });
    try {
      if (wasLogin) {
        await _auth.signIn(email, _passCtrl.text);
      } else {
        await _auth.signUp(email, _passCtrl.text,
            username: _usernameCtrl.text);
      }
      if (!mounted) return;
      if (wasLogin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      } else if (_auth.currentUserId == null) {
        // Email confirmation required: no session yet. Park on login.
        setState(() => isLogin = true);
        _showAlert(
          'Check your inbox',
          'Account created — confirm your email, then log in',
          KawaiiAlertKind.info,
        );
      } else {
        final username = _usernameCtrl.text.trim();
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => PairingPage(
                  spaceName: username.isEmpty ? 'Our space' : "$username's space")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _handleAuthError(e, wasLogin: wasLogin);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        title: const Text('hi, lovebirds',
            style:
                TextStyle(fontWeight: FontWeight.w900, fontFamily: Kawaii.displayFamily)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // segmented sticker toggle
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Kawaii.cardOf(context),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: edge, width: Kawaii.borderW),
                boxShadow: Kawaii.sticker(context),
              ),
              child: Row(
                children: [
                  Expanded(child: _seg('Join', !isLogin, Kawaii.peach)),
                  Expanded(child: _seg('Login', isLogin, Kawaii.sky)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            KawaiiCard(
              color: isLogin ? Kawaii.skySubtle : Kawaii.blushSubtle,
              child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KawaiiPill(
                    label: isLogin ? 'welcome back!' : 'new sticker page!',
                    color: isLogin ? Kawaii.sky : Kawaii.peach,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isLogin ? 'Peek back inside' : 'Make your space',
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFamily: Kawaii.displayFamily),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLogin
                        ? 'Your notes, pics & plans missed you.'
                        : 'Pick a username + password. Pair in 30 seconds.',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (!isLogin)
                    KawaiiInput(
                        hint: 'e.g. alex_02',
                        label: 'USERNAME',
                        controller: _usernameCtrl,
                        validator: (v) {
                          if (isLogin) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Pick a username';
                          }
                          return null;
                        }),
                  if (!isLogin) const SizedBox(height: 12),
                  KawaiiInput(
                      hint: 'you@cutemail.com',
                      label: 'EMAIL',
                      controller: _emailCtrl,
                      keyboard: TextInputType.emailAddress,
                      prefix: Icons.alternate_email_rounded,
                      validator: _emailValidator),
                  const SizedBox(height: 12),
                  KawaiiInput(
                      hint: '••••••••',
                      label: 'PASSWORD',
                      controller: _passCtrl,
                      obscure: true,
                      prefix: Icons.lock_outline_rounded,
                      validator: _passValidator),
                  if (_alertTitle != null && _alertMessage != null) ...[
                    const SizedBox(height: 12),
                    KawaiiAlert(
                      title: _alertTitle!,
                      message: _alertMessage!,
                      kind: _alertKind,
                      actionLabel: _alertAction,
                      onAction: _alertAction == null
                          ? null
                          : () => _switchMode(_alertAction == 'Log in'),
                      onClose: () => setState(() {
                        _alertTitle = null;
                        _alertMessage = null;
                        _alertAction = null;
                      }),
                    ),
                  ],
                  const SizedBox(height: 16),
                  KawaiiButton(
                    label: _busy
                        ? 'Pasting…'
                        : (isLogin
                            ? 'Login to ourspace'
                            : 'Create our space'),
                    color: isLogin
                        ? KawaiiBtnColor.sky
                        : KawaiiBtnColor.peach,
                    icon: Icons.favorite_rounded,
                    onTap: _busy ? null : _continue,
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          _switchMode(!isLogin),
                      child: Text(
                        isLogin
                            ? "New here? Make a space instead"
                            : 'Already paired? Log in',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Kawaii.ink,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 14),
            const KawaiiAlert(
              title: 'Private by design',
              message:
                  'Only invited partners can join. No public feed, no strangers.',
              kind: KawaiiAlertKind.info,
            ),
          ],
        ),
      ),
    );
  }

  Widget _seg(String label, bool active, Color color) {
    final edge = Kawaii.edgeOf(context);
    return GestureDetector(
      onTap: () => _switchMode(label == 'Login'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? edge : Colors.transparent, width: Kawaii.paperBorderW),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontFamily: Kawaii.displayFamily,
                color: active ? Kawaii.ink : Kawaii.textOf(context))),
      ),
    );
  }
}
