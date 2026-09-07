import 'package:flutter/material.dart';
import 'info_topics.dart';
export 'info_topics.dart';

class InfoHelperSheet {
  static void show(BuildContext context, InfoTopic topic) {
    final data = InfoTopics.all[topic]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF131722),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(top: 14, left: 20, right: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: data.accentColor.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(data.icon, color: data.accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data.shortTag, style: TextStyle(color: data.accentColor, fontSize: 10, fontWeight: FontWeight.w900)),
                        Text(data.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              _section('Що це таке?', data.whatIsIt, const Color(0xFF00FF94)),
              const SizedBox(height: 10),
              _section('Чому це важливо?', data.whyImportant, const Color(0xFF00E5FF)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [data.accentColor.withValues(alpha: 0.12), const Color(0xFF161B26)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: data.accentColor.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_rounded, color: data.accentColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ПОРАДА ДЛЯ НОВАЧКА', style: TextStyle(color: data.accentColor, fontSize: 10, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(data.tip, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.35)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2433),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Зрозуміло', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _section(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35)),
        ],
      ),
    );
  }
}

class InfoButton extends StatelessWidget {
  final InfoTopic topic;
  final double size;

  const InfoButton({super.key, required this.topic, this.size = 18.0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => InfoHelperSheet.show(context, topic),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(Icons.help_outline_rounded, size: size, color: Colors.white38),
      ),
    );
  }
}
