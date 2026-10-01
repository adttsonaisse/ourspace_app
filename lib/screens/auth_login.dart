import 'package:flutter/material.dart';
import '../data/auth_repo.dart';
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

  Future<void> _continue() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _busy) return;
    setState(() => _busy = true);
    try {
      if (isLogin) {
        await _auth.signIn(_emailCtrl.text, _passCtrl.text);
      } else {
        await _auth.signUp(_emailCtrl.text, _passCtrl.text,
            username: _usernameCtrl.text);
      }
      if (!mounted) return;
      if (isLogin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      } else if (_auth.currentUserId == null) {
        // Email confirmation required: no session yet. Park on login.
        setState(() => isLogin = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Account created — confirm your email, then log in')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Kawaii.ink, width: 2.5),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 18),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Kawaii.ink, width: 3),
                boxShadow: const [
                  BoxShadow(color: Kawaii.ink, offset: Offset(4, 4))
                ],
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
                          setState(() => isLogin = !isLogin),
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
    return GestureDetector(
      onTap: () => setState(() => isLogin = label == 'Login'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: active ? Kawaii.ink : Colors.transparent, width: 2.5),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w900, fontFamily: Kawaii.displayFamily)),
      ),
    );
  }
}
