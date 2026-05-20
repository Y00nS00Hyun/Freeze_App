// lib/widgets/clova_panel.dart
import 'package:flutter/material.dart';
import '../models/events.dart';

class ClovaPanel extends StatelessWidget {
  const ClovaPanel({super.key, this.event});
  final ClovaEvent? event;

  @override
  Widget build(BuildContext context) {
    final hasText = event != null && event!.text.trim().isNotEmpty;
    final header = hasText ? '인식 결과' : '인식 중';
    final text = hasText ? event!.text : '주변 음성을 분석하는 중입니다';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F6F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mic_none_rounded,
                      size: 14,
                      color: Color(0xFF0E9AAB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      header,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: Color(0xFF0E9AAB),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'CLOVA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                text,
                style: TextStyle(
                  color: hasText
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                  fontSize: 20,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
