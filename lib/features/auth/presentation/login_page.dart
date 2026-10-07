import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/preview_notice.dart';
import 'backend_status.dart';
import 'auth_providers.dart';
import '../domain/account_repository.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, required this.previewEnabled});

  final bool previewEnabled;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  Future<void> _signIn() async {
    if (_submitting) return;
    final email = _emailController.text.trim();
    if (!email.contains('@') || _passwordController.text.isEmpty) {
      setState(() => _error = 'E-posta ve parolanızı girin.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final repository = await ref.read(accountRepositoryProvider.future);
      if (repository == null) throw const SignInException();
      await repository.signIn(email, _passwordController.text);
      if (mounted) context.go('/account');
    } catch (_) {
      if (mounted) setState(() => _error = const SignInException().toString());
    } finally {
      if (mounted) {
        _passwordController.clear();
        setState(() => _submitting = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openPreview() {
    FocusManager.instance.primaryFocus?.unfocus();
    _emailController.clear();
    _passwordController.clear();
    context.go('/preview');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ready = ref.watch(accountRepositoryProvider).asData?.value != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.eco_outlined,
                          color: colors.secondaryContainer,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pekşen Gıda',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tedarikten teslimata',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'İşinizin her adımı,\naynı yerde.',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sipariş, saha, depo ve teslimat için ortak çalışma alanı.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Hoş geldiniz',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ready
                                ? 'Müşteri veya çalışan hesabınızla giriş yapın.'
                                : 'Giriş ekranı şu anda arayüz önizlemesidir.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            key: const ValueKey('login-email'),
                            controller: _emailController,
                            enabled: !_submitting,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const ValueKey('login-password'),
                            controller: _passwordController,
                            enabled: !_submitting,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            enableIMEPersonalizedLearning: false,
                            onSubmitted: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            decoration: InputDecoration(
                              labelText: 'Parola',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Parolayı göster'
                                    : 'Parolayı gizle',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_error != null)
                            Text(_error!, key: const ValueKey('login-error')),
                          FilledButton(
                            key: const ValueKey('login-submit'),
                            onPressed: ready && !_submitting ? _signIn : null,
                            child: Text(
                              _submitting ? 'Giriş yapılıyor…' : 'Giriş yap',
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            ready
                                ? 'Giriş bilgileri yapılandırılan sunucuya gönderilir. Oturum cihazın güvenli deposunda saklanır. Ortak cihazda çıkış yapın.'
                                : 'Oturum açma henüz bağlı değil. Girilen bilgiler '
                                      'gönderilmez veya kaydedilmez.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          if (ready) ...[
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/register'),
                              child: const Text('Müşteri hesabı oluştur'),
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/accept-invite'),
                              child: const Text('Daveti kabul et'),
                            ),
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => context.push('/recover'),
                              child: const Text('Parolamı unuttum'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (widget.previewEnabled) ...[
                    const SizedBox(height: 16),
                    const BackendStatus(),
                    const SizedBox(height: 24),
                    const PreviewNotice(),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const ValueKey('preview-entry'),
                      onPressed: _submitting ? null : _openPreview,
                      child: const Text(
                        'Geliştirme önizlemesini aç',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
