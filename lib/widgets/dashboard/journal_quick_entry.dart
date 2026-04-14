import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/pet_health_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class JournalQuickEntry extends StatelessWidget {
  final PetHealthProvider provider;
  const JournalQuickEntry({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final lastEntry = provider.journalEntries.isNotEmpty
        ? provider.journalEntries.first
        : null;
    final isToday = lastEntry != null &&
        _isSameDay(lastEntry.date, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warmOrangeMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('📓', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              const Text('Daily Journal', style: AppTextStyles.headlineSmall),
              const Spacer(),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.sageMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '✅ Logged today',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.sageGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isToday && lastEntry != null)
            _TodayEntry(entry: lastEntry)
          else
            _QuickLogRow(provider: provider),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _TodayEntry extends StatelessWidget {
  final JournalEntry entry;
  const _TodayEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _EmojiChip(emoji: entry.moodEmoji, label: 'Mood'),
            _EmojiChip(emoji: entry.appetiteEmoji, label: 'Appetite'),
            _EmojiChip(emoji: entry.energyEmoji, label: 'Energy'),
            _EmojiChip(emoji: entry.stoolEmoji, label: 'Stool'),
          ],
        ),
        if (entry.notes != null && entry.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '"${entry.notes}"',
              style: AppTextStyles.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickLogRow extends StatelessWidget {
  final PetHealthProvider provider;
  const _QuickLogRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How is Biscuit doing today?',
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickEmoji(emoji: '😊', label: 'Happy', onTap: () => _quickLog(context, '😊', '🍖', '⚡')),
            _QuickEmoji(emoji: '😐', label: 'Okay', onTap: () => _quickLog(context, '😐', '😐', '😴')),
            _QuickEmoji(emoji: '😰', label: 'Anxious', onTap: () => _quickLog(context, '😰', '😐', '😴')),
            _QuickEmoji(emoji: '😣', label: 'Stressed', onTap: () => _quickLog(context, '😣', '🚫', '😴')),
            _QuickEmoji(emoji: '🤒', label: 'Unwell', onTap: () => _quickLog(context, '🤒', '🚫', '😴')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showFullJournalDialog(context),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Full Journal Entry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warmOrange,
              side: const BorderSide(color: AppColors.warmOrangeLight),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  void _quickLog(BuildContext context, String mood, String appetite, String energy) {
    HapticFeedback.selectionClick();
    provider.addJournalEntry(JournalEntry(
      id: 'j_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      stoolEmoji: '🟤',
      moodEmoji: mood,
      appetiteEmoji: appetite,
      energyEmoji: energy,
      negativeFlags:
          mood == '😰' || mood == '😣' || mood == '🤒'
              ? ['anxiety', 'check_needed']
              : [],
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Journal entry saved! $mood'),
        backgroundColor: AppColors.sageGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFullJournalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _FullJournalDialog(provider: provider),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _EmojiChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _QuickEmoji extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;
  const _QuickEmoji({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.labelSmall.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _FullJournalDialog extends StatefulWidget {
  final PetHealthProvider provider;
  const _FullJournalDialog({required this.provider});

  @override
  State<_FullJournalDialog> createState() => _FullJournalDialogState();
}

class _FullJournalDialogState extends State<_FullJournalDialog> {
  String _mood = '😊';
  String _appetite = '🍖';
  String _energy = '⚡';
  String _stool = '🟤';
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📓 Today\'s Journal', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),
              _EmojiRow(title: 'Mood', options: ['😊', '😐', '😰', '😣', '🤒'], selected: _mood, onSelect: (v) => setState(() => _mood = v)),
              const SizedBox(height: 14),
              _EmojiRow(title: 'Appetite', options: ['🍖', '😐', '🚫'], selected: _appetite, onSelect: (v) => setState(() => _appetite = v)),
              const SizedBox(height: 14),
              _EmojiRow(title: 'Energy', options: ['⚡', '😴', '🐌'], selected: _energy, onSelect: (v) => setState(() => _energy = v)),
              const SizedBox(height: 14),
              _EmojiRow(title: 'Stool', options: ['🟤', '🟡', '🔴', '💧'], selected: _stool, onSelect: (v) => setState(() => _stool = v)),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Any observations? (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                  filled: true,
                  fillColor: AppColors.cream,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.provider.addJournalEntry(JournalEntry(
                      id: 'j_${DateTime.now().millisecondsSinceEpoch}',
                      date: DateTime.now(),
                      stoolEmoji: _stool,
                      moodEmoji: _mood,
                      appetiteEmoji: _appetite,
                      energyEmoji: _energy,
                      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
                      negativeFlags: _mood == '😰' || _mood == '😣' ? ['anxiety'] : [],
                    ));
                    Navigator.pop(context);
                  },
                  child: const Text('Save Journal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiRow extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _EmojiRow({required this.title, required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: options.map((e) => GestureDetector(
            onTap: () => onSelect(e),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected == e ? AppColors.sageMuted : AppColors.cream,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == e ? AppColors.sageGreen : AppColors.divider,
                  width: 1.5,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
