import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/account_lifecycle.dart';
import 'auth_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, required this.purpose});
  final EmailCodePurpose purpose;
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _name = TextEditingController(),
      _company = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _code = TextEditingController();
  bool _busy = false, _codeSent = false;
  String? _message;
  @override
  void dispose() {
    for (final c in [_name, _company, _email, _password, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _perform({bool verify = false, bool resend = false}) async {
    if (_busy) return;
    final needsPassword =
        (widget.purpose == EmailCodePurpose.signup && !verify && !resend) ||
        (widget.purpose != EmailCodePurpose.signup && verify);
    if (!_email.text.contains('@') ||
        (verify && !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) ||
        (widget.purpose == EmailCodePurpose.signup &&
            !verify &&
            !resend &&
            (_name.text.trim().isEmpty || _company.text.trim().isEmpty))) {
      setState(
        () => _message = 'Alanları doldurun. Parola en az 8 karakter, e-posta kodu 6 rakam olmalıdır.',
      );
      return;
    }
    if (needsPassword && !validNewPassword(_password.text)) {
      setState(() => _message = newPasswordError(_password.text));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final service = await ref.read(accountLifecycleProvider.future);
      if (service == null) throw const AccountLifecycleException();
      if (verify) {
        await service.verify(
          _email.text,
          _code.text,
          widget.purpose,
          _password.text,
        );
        ref.invalidate(accountProfileProvider);
        if (mounted) {
          context.go(
            widget.purpose == EmailCodePurpose.recovery ? '/' : '/account',
          );
        }
      } else if (widget.purpose == EmailCodePurpose.signup && !resend) {
        await service.register(
          _name.text,
          _company.text,
          _email.text,
          _password.text,
        );
      } else {
        await service.resend(_email.text, widget.purpose);
      }
      if (mounted && !verify) {
        setState(() {
          _codeSent = true;
          _message = 'İşlem uygunsa kod e-posta adresinize gönderildi. Gelen kutunuzu kontrol edin.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = const AccountLifecycleException().toString());
      }
    } finally {
      if (mounted) {
        _password.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signup = widget.purpose == EmailCodePurpose.signup;
    final invite = widget.purpose == EmailCodePurpose.invite;
    final verification = _codeSent || invite;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          signup
              ? 'Müşteri kaydı'
              : invite
              ? 'Daveti kabul et'
              : 'Parolamı unuttum',
        ),
        leading: IconButton(
          onPressed: _busy ? null : () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              signup
                  ? 'Yeni müşteri kuruluşunuz yönetici onayı beklemeden aktif oluşturulur. Giriş için e-postanızı doğrulayın.'
                  : invite
                  ? 'Yöneticinizin gönderdiği kodu girin ve parolanızı belirleyin. Rolünüzü yönetici belirler.'
                  : 'Parolanızı e-posta koduyla yenileyin. İşlem sonunda yeniden giriş yapın.',
            ),
            const SizedBox(height: 16),
            if (signup && !verification) ...[
              _field('Ad soyad', _name, 'signup-name'),
              _field('Firma adı', _company, 'signup-company'),
            ],
            _field('E-posta', _email, 'onboarding-email', email: true),
            if (verification)
              _field('E-posta kodu', _code, 'onboarding-code', number: true),
            if (!verification && signup || verification && !signup)
              _field(
                'Yeni parola (en az 8 karakter)',
                _password,
                'onboarding-password',
                secret: true,
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _message!,
                  key: const ValueKey('onboarding-message'),
                ),
              ),
            FilledButton(
              key: const ValueKey('onboarding-submit'),
              onPressed: _busy ? null : () => _perform(verify: verification),
              child: Text(
                _busy
                    ? 'İşleniyor…'
                    : verification
                    ? 'Kodu doğrula'
                    : signup
                    ? 'Kayıt ol'
                    : 'Kod gönder',
              ),
            ),
            if (verification && !invite)
              TextButton(
                onPressed: _busy ? null : () => _perform(resend: true),
                child: const Text('Kodu yeniden gönder'),
              ),
            if (signup && !verification)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _codeSent = true),
                child: const Text('Zaten kodum var'),
              ),
            if (invite)
              const Text(
                'Kodun süresi dolduysa yöneticinizden daveti yenilemesini isteyin.',
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String key, {
    bool secret = false,
    bool email = false,
    bool number = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_busy,
      obscureText: secret,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      keyboardType: email
          ? TextInputType.emailAddress
          : number
          ? TextInputType.number
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    ),
  );
}
