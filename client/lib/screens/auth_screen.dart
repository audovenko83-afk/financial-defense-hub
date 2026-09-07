import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'portfolio_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool isRegistering = false;
  bool isLoading = false;
  bool isRestoringSession = true;
  String? errorMessage;

  String? _savedToken;
  bool _showBiometricUnlockButton = false;

  int _adminTapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await SessionStore.readToken();
    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      _savedToken = token;
      final isBioEnabled = await SessionStore.isBiometricsEnabled();

      bool canCheck = false;
      try {
        canCheck = (await _localAuth.canCheckBiometrics) || (await _localAuth.isDeviceSupported());
      } catch (_) {
        canCheck = false;
      }

      if (isBioEnabled && canCheck) {
        final authenticated = await _authenticateBiometrics();
        if (authenticated) {
          _navigateToPortfolio(token);
          return;
        } else {
          if (mounted) {
            setState(() {
              _showBiometricUnlockButton = true;
              isRestoringSession = false;
            });
          }
          return;
        }
      } else {
        _navigateToPortfolio(token);
        return;
      }
    } else {
      if (mounted) {
        setState(() => isRestoringSession = false);
      }
    }
  }

  Future<bool> _authenticateBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Підтвердіть біометрію для входу в Million Dollar Way',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  void _navigateToPortfolio(String token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PortfolioScreen(token: token)),
      );
    });
  }

  Future<void> _submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => errorMessage = null);

    if (email.isEmpty || password.length < 8) {
      setState(() {
        errorMessage = 'Введіть коректний email та пароль (щонайменше 8 символів)';
      });
      return;
    }

    setState(() => isLoading = true);
    final endpoint = isRegistering ? '/auth/register' : '/auth/login';

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;
        await SessionStore.writeToken(token, email: email);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PortfolioScreen(token: token)),
        );
      } else {
        setState(() {
          if (response.statusCode == 401) {
            errorMessage = 'Невірна пошта або пароль.\nЯкщо у вас ще немає акаунту — натисніть «Створити профіль» нижче.';
          } else if (response.statusCode == 409) {
            errorMessage = 'Користувач із такою поштою вже існує. Натисніть «Увійти» нижче.';
          } else {
            errorMessage = 'Помилка сервера: ${response.body}';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Немає звʼязку із сервером:\n${ApiConfig.baseUrl}\n\n'
            'Перевірте, чи запущено сервер (`go run ./cmd/api`) та налаштування адреси (⚙️ вгорі).';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': account.email,
          'name': account.displayName ?? '',
          'token': auth.idToken ?? auth.accessToken ?? '',
          'provider': 'google',
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String;
        await SessionStore.writeToken(token, email: account.email);
        _navigateToPortfolio(token);
      } else {
        setState(() {
          errorMessage = 'Помилка Google авторизації: ${res.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Не вдалося увійти через Google: $e';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  Future<void> _signInWithGitHub() async {
    final githubUserCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.code_rounded, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text('Вхід через GitHub', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Введіть ваш GitHub username або email для авторизації:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: githubUserCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'GitHub username або email',
                prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF00FF94), size: 20),
                filled: true,
                fillColor: const Color(0xFF0F131C),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FF94),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              final val = githubUserCtrl.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
            child: const Text('Увійти'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final email = result.contains('@') ? result : '$result@users.noreply.github.com';
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/github'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'name': result,
          'provider': 'github',
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final token = data['token'] as String;
        await SessionStore.writeToken(token, email: email);
        _navigateToPortfolio(token);
      } else {
        setState(() {
          errorMessage = 'Помилка GitHub авторизації: ${res.body}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Не вдалося увійти через GitHub: $e';
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }


  void _onLogoTapped() {
    final now = DateTime.now();
    if (now.difference(_lastTapTime).inSeconds > 2) {
      _adminTapCount = 0;
    }
    _lastTapTime = now;
    _adminTapCount++;
    if (_adminTapCount >= 5) {
      _adminTapCount = 0;
      _showServerSettingsDialog();
    }
  }

  void _showServerSettingsDialog() {
    final urlController = TextEditingController(text: ApiConfig.baseUrl);
    String pingResult = '';
    bool isTesting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> testPing(String testUrl) async {
            setDialogState(() {
              isTesting = true;
              pingResult = 'Перевірка зʼєднання...';
            });
            try {
              final trimmed = testUrl.trim();
              final pingEndpoint = trimmed.endsWith('/api') ? '$trimmed/ping' : '$trimmed/api/ping';
              final res = await http.get(Uri.parse(pingEndpoint)).timeout(const Duration(seconds: 4));
              if (res.statusCode == 200) {
                setDialogState(() {
                  pingResult = '✅ Зʼєднання успішне (HTTP 200 OK)';
                  isTesting = false;
                });
              } else {
                setDialogState(() {
                  pingResult = '⚠️ Сервер відповів: ${res.statusCode}';
                  isTesting = false;
                });
              }
            } catch (err) {
              setDialogState(() {
                pingResult = '❌ Помилка зʼєднання: $err';
                isTesting = false;
              });
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF141417),
            title: const Text('Налаштування сервера API', style: TextStyle(color: Colors.white, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Вкажіть адресу сервера Go-бекенду:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E1E24),
                      labelText: 'Адреса сервера API',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Швидкий вибір:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.cloud_done, size: 16, color: Color(0xFF00FF94)),
                        label: const Text('Render Хмара'),
                        onPressed: () => urlController.text = 'https://audovenko-mdw-apits.onrender.com/api',
                      ),
                      ActionChip(
                        label: const Text('127.0.0.1 (USB / ПК)'),
                        onPressed: () => urlController.text = 'http://127.0.0.1:8080/api',
                      ),
                      ActionChip(
                        label: const Text('192.168.0.7 (Wi-Fi)'),
                        onPressed: () => urlController.text = 'http://192.168.0.7:8080/api',
                      ),
                      ActionChip(
                        label: const Text('10.0.2.2 (Емулятор)'),
                        onPressed: () => urlController.text = 'http://10.0.2.2:8080/api',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: isTesting ? null : () => testPing(urlController.text.trim()),
                    icon: const Icon(Icons.network_check, size: 18),
                    label: const Text('Перевірити зʼєднання'),
                  ),
                  if (pingResult.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      pingResult,
                      style: TextStyle(
                        fontSize: 12,
                        color: pingResult.startsWith('✅') ? const Color(0xFF00FF94) : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Скасувати'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF94),
                  foregroundColor: Colors.black,
                ),
                onPressed: () async {
                  final newUrl = urlController.text.trim();
                  if (newUrl.isNotEmpty) {
                    await ApiConfig.setBaseUrl(newUrl);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Збережено адресу API: $newUrl')),
                      );
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(dialogCtx);
                    setState(() {});
                  }
                },
                child: const Text('Зберегти'),
              ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (isRestoringSession) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00FF94))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0B),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _onLogoTapped,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.shield_outlined, size: 64, color: Color(0xFF00FF94)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  AppStrings.appTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
                ),
                const SizedBox(height: 4),
                const Text(
                  AppStrings.appSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF00FF94), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                if (_showBiometricUnlockButton && _savedToken != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00FF94),
                        side: const BorderSide(color: Color(0xFF00FF94), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.fingerprint_rounded, size: 28),
                      label: const Text(
                        'Вхід за біометрією (Відбиток / Face ID)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        final auth = await _authenticateBiometrics();
                        if (auth && _savedToken != null) {
                          _navigateToPortfolio(_savedToken!);
                        }
                      },
                    ),
                  ),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Електронна пошта',
                    filled: true,
                    fillColor: const Color(0xFF141417),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Пароль (від 8 символів)',
                    filled: true,
                    fillColor: const Color(0xFF141417),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                if (errorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF331B1E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(color: Color(0xFFFFC0C0), fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF94),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isLoading ? null : _submit,
                    child: Text(
                      isRegistering ? 'Створити акаунт' : 'Увійти',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isRegistering = !isRegistering;
                      errorMessage = null;
                    });
                  },
                  child: Text(
                    isRegistering ? 'Вже маєте акаунт? Увійти' : 'Створити профіль',
                    style: const TextStyle(color: Color(0xFF00E0FF)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('або увійдіть через', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF161B26),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isLoading ? null : _signInWithGoogle,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://www.gstatic.com/images/branding/product/1x/gsa_512dp.png',
                              height: 20,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 8),
                            const Text('Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF161B26),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: isLoading ? null : _signInWithGitHub,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.code_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('GitHub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse('https://cream-lion-12hfp5j.mystrikingly.com/blog/privacy-policy-for-million-dollar-way');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(url, mode: LaunchMode.inAppWebView);
                    }
                  },
                  child: const Text('Політика конфіденційності', style: TextStyle(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
