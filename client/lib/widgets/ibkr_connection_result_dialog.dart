import 'package:flutter/material.dart';
import '../models/models.dart';

class IBKRConnectionResultDialog extends StatefulWidget {
  final IBKRResult result;
  final bool isAdmin;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenGuide;
  final VoidCallback? onTryDemo;

  const IBKRConnectionResultDialog({
    super.key,
    required this.result,
    this.isAdmin = false,
    this.onRetry,
    this.onOpenGuide,
    this.onTryDemo,
  });

  static Future<void> show(
    BuildContext context, {
    required IBKRResult result,
    bool isAdmin = false,
    VoidCallback? onRetry,
    VoidCallback? onOpenGuide,
    VoidCallback? onTryDemo,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => IBKRConnectionResultDialog(
        result: result,
        isAdmin: isAdmin,
        onRetry: onRetry,
        onOpenGuide: onOpenGuide,
        onTryDemo: onTryDemo,
      ),
    );
  }

  @override
  State<IBKRConnectionResultDialog> createState() => _IBKRConnectionResultDialogState();
}

class _IBKRConnectionResultDialogState extends State<IBKRConnectionResultDialog> {
  bool _showAdminDetails = false;

  @override
  Widget build(BuildContext context) {
    final res = widget.result;
    final isSuccess = res.isSuccess;

    return AlertDialog(
      backgroundColor: const Color(0xFF161B26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.all(20),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSuccess
                        ? const Color(0xFF00FF94).withValues(alpha: 0.15)
                        : Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSuccess ? const Color(0xFF00FF94) : Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: isSuccess ? const Color(0xFF00FF94) : Colors.redAccent,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isSuccess ? 'Зʼєднання з IBKR встановлено!' : 'Не вдалося підключитися до IBKR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: isSuccess ? const Color(0xFF00FF94) : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                res.friendlyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (isSuccess) _buildSuccessBlock(res) else _buildErrorTipsBlock(),
              if (widget.isAdmin) _buildAdminDiagnosticBlock(res),
              const SizedBox(height: 16),
              _buildActions(context, isSuccess),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBlock(IBKRResult res) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF00FF94).withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Рахунок IBKR:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    res.accountId.isNotEmpty ? res.accountId : 'IBKR Live',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00FF94)),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Залишок кешу:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    '\$${res.cash.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF00E5FF)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Завантажено активів:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    '${res.positionsCount} поз.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (res.warning != null && res.warning!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFB74D).withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB74D), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.warning!,
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorTipsBlock() {
    final res = widget.result;
    final lowerFriendly = res.friendlyMessage.toLowerCase();
    final lowerRaw = (res.errorMessage ?? '').toLowerCase();
    final code = res.errorCode ?? '';

    final isExpired = code == '1012' ||
        lowerFriendly.contains('закінчився') ||
        lowerFriendly.contains('простроч') ||
        lowerRaw.contains('expired');

    final isBlockedOrLimit = code == '1025' ||
        code == '1004' ||
        code == '1005' ||
        lowerFriendly.contains('1025') ||
        lowerRaw.contains('too many failed attempts');

    final isPending = code == '1001' || code == '1016' || code == '1019';
    final isInvalidQuery = code == '1018' || code == '1014';

    String tipsTitle;
    String tipsText;
    IconData tipsIcon;
    Color tipsColor;

    if (isExpired) {
      tipsIcon = Icons.access_time_filled_rounded;
      tipsColor = const Color(0xFFFFB74D);
      tipsTitle = 'Термін дії токена закінчився (код 1012):';
      tipsText =
          '1. В IBKR термін дії Flex токена обмежено брокером (до 1 року).\n'
          '2. Увійдіть до кабінету на interactivebrokers.com.\n'
          '3. Перейдіть: Performance & Reports ➔ Flex Queries ➔ Flex Web Service.\n'
          '4. Згенеруйте новий Current Token та збережіть.\n'
          '5. Вставте новий числовий токен у налаштування додатку.';
    } else if (isBlockedOrLimit) {
      tipsIcon = Icons.security_update_warning_rounded;
      tipsColor = const Color(0xFFFF8A80);
      tipsTitle = 'Забагато спроб / Тимчасовий блок (код 1025):';
      tipsText =
          '1. Оскільки старий токен був прострочений, IBKR тимчасово призупинив доступ.\n'
          '2. Створіть новий активний токен у кабінеті IBKR.\n'
          '3. Зачекайте 15–30 хвилин для скидання блокування серверів IBKR.\n'
          '4. Спробуйте синхронізувати з новим токеном.';
    } else if (isPending) {
      tipsIcon = Icons.hourglass_top_rounded;
      tipsColor = const Color(0xFF00E5FF);
      tipsTitle = 'Сервери IBKR формують звіт:';
      tipsText =
          '1. Генерація Flex звіту на серверах IBKR триває від 30 сек до 2 хв.\n'
          '2. Перевірте, чи у звіті стоїть період «Last 365 Days» замість «Current Day».\n'
          '3. Зачекайте 1–2 хвилини і натисніть «Повторити».';
    } else if (isInvalidQuery) {
      tipsIcon = Icons.search_off_rounded;
      tipsColor = const Color(0xFFFFD700);
      tipsTitle = 'Не знайдено Query ID:';
      tipsText =
          '1. Перевірте список Flex Queries в особистому кабінеті IBKR.\n'
          '2. Скопіюйте числовий ID саме того звіту, який містить Open Positions та Cash Report.\n'
          '3. Переконайтеся, що сервіс Flex Web Service активний.';
    } else {
      tipsIcon = Icons.lightbulb_outline_rounded;
      tipsColor = const Color(0xFFFFD700);
      tipsTitle = 'Що потрібно перевірити:';
      tipsText =
          '1. Токен має містити виключно цифри без пробілів.\n'
          '2. Перевірте, чи увімкнено Flex Web Service у кабінеті IBKR.\n'
          '3. Перевірте Query ID у списку звітів Flex Queries.\n'
          '4. Якщо звіт або токен створено щойно — зачекайте 2–5 хв для його активації.';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tipsColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(tipsIcon, color: tipsColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tipsTitle,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: tipsColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tipsText,
            style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminDiagnosticBlock(IBKRResult res) {
    return Column(
      children: [
        const SizedBox(height: 12),
        InkWell(
          onTap: () => setState(() => _showAdminDetails = !_showAdminDetails),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFD700), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Звіт для адміністратора (Журнал подій)',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  _showAdminDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: const Color(0xFFFFD700),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (_showAdminDetails) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Статус: ${res.status.toUpperCase()}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                if (res.errorCode != null && res.errorCode!.isNotEmpty)
                  Text('Код помилки IBKR: ${res.errorCode}', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('Тривалість: ${res.durationMs} мс', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                if (res.errorMessage != null && res.errorMessage!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Повідомлення: ${res.errorMessage}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ],
                if (res.rawDetails != null && res.rawDetails!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Сирі дані:', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  Text(
                    res.rawDetails!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace'),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'ℹ️ Запис автоматично додано до системного Журналу подій.',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(BuildContext context, bool isSuccess) {
    if (isSuccess) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF00FF94),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text('Перейти до портфеля', style: TextStyle(fontWeight: FontWeight.w900)),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            if (widget.onRetry != null)
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onRetry?.call();
                  },
                  child: const Text('Повторити'),
                ),
              ),
            if (widget.onRetry != null) const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Зрозуміло', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        if (widget.onOpenGuide != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF00E5FF)),
            label: const Text('Інструкція з отримання токена в IBKR', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12)),
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenGuide?.call();
            },
          ),
        ],
        if (widget.onTryDemo != null) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFF00FF94)),
            label: const Text('Спробувати миттєвий тест (Demo IBKR)', style: TextStyle(color: Color(0xFF00FF94), fontSize: 12)),
            onPressed: () {
              Navigator.pop(context);
              widget.onTryDemo?.call();
            },
          ),
        ],
      ],
    );
  }
}
