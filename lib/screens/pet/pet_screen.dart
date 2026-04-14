import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/pet_health_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class PetScreen extends StatelessWidget {
  const PetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetHealthProvider>();
    final pet = provider.pet;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, pet, provider)),
            SliverToBoxAdapter(child: _buildHealthTags(pet)),
            SliverToBoxAdapter(child: _buildDeviceSection(context, provider)),
            SliverToBoxAdapter(child: _buildJournalHistory(provider)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext ctx, PetProfile pet, PetHealthProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.sageLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sageGreen, width: 3),
                ),
                child: const Center(child: Text('🐶', style: TextStyle(fontSize: 38))),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: AppTextStyles.headlineLarge),
                    const SizedBox(height: 4),
                    Text('${pet.breed} · ${pet.ageLabel}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('${pet.weightKg} kg · ${pet.species == 'dog' ? '🐕' : '🐈'} ${pet.species}', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showEditDialog(ctx, pet, provider),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.sageMuted, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, color: AppColors.sageGreen, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTags(PetProfile pet) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏷️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('Health Tags', style: AppTextStyles.headlineSmall),
            ],
          ),
          const SizedBox(height: 14),
          if (pet.healthTags.isEmpty)
            Text('No health tags added yet.', style: AppTextStyles.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pet.healthTags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warmOrangeMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.warmOrangeLight),
                ),
                child: Text(tag, style: AppTextStyles.labelMedium.copyWith(color: AppColors.warmOrange, fontSize: 13)),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceSection(BuildContext context, PetHealthProvider provider) {
    final connected = provider.deviceConnected;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📡', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('ZenBelly Collar', style: AppTextStyles.headlineSmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: connected ? AppColors.sageMuted : AppColors.alertRedMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  connected ? '● Connected' : '○ Offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: connected ? AppColors.sageGreen : AppColors.alertRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _DeviceStat(label: 'Battery', value: '${provider.battery}%', icon: Icons.battery_4_bar_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _DeviceStat(label: 'Signal', value: 'Good', icon: Icons.bluetooth_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _DeviceStat(label: 'Sync', value: 'Live', icon: Icons.sync_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          // Anxiety slider demo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Simulated Anxiety Level', style: AppTextStyles.labelMedium),
                  Text('${(provider.anxietyLevel * 100).round()}%', style: AppTextStyles.labelMedium.copyWith(color: AppColors.warmOrange, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Drag to simulate different anxiety levels for demo', style: AppTextStyles.bodySmall),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.warmOrange,
                  inactiveTrackColor: AppColors.warmOrangeLight,
                  thumbColor: AppColors.warmOrange,
                  overlayColor: AppColors.warmOrange.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: provider.anxietyLevel,
                  onChanged: (v) => provider.anxietyLevel = v,
                  min: 0,
                  max: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: connected ? provider.disconnectDevice : provider.connectDevice,
              icon: Icon(connected ? Icons.bluetooth_disabled_rounded : Icons.bluetooth_rounded, size: 18),
              label: Text(connected ? 'Disconnect Device' : 'Connect Device'),
              style: OutlinedButton.styleFrom(
                foregroundColor: connected ? AppColors.alertRed : AppColors.sageGreen,
                side: BorderSide(color: connected ? AppColors.alertRed : AppColors.sageGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalHistory(PetHealthProvider provider) {
    final entries = provider.journalEntries;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📓', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('Journal History', style: AppTextStyles.headlineSmall),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text('No journal entries yet.', style: AppTextStyles.bodySmall)
          else
            ...entries.take(5).map((e) => _JournalRow(entry: e)),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, PetProfile pet, PetHealthProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => _EditPetDialog(pet: pet, provider: provider),
    );
  }
}

class _DeviceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _DeviceStat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Icon(icon, color: AppColors.sageGreen, size: 20),
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.headlineSmall.copyWith(fontSize: 16, color: AppColors.sageGreen)),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  final JournalEntry entry;
  const _JournalRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text('${_dateLabel(entry.date)}', style: AppTextStyles.labelSmall),
          const SizedBox(width: 12),
          Text(entry.moodEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(entry.appetiteEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(entry.energyEmoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(entry.stoolEmoji, style: const TextStyle(fontSize: 20)),
          if (entry.notes != null) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(entry.notes!, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (d.day == now.day) return 'Today';
    if (d.day == now.day - 1) return 'Yesterday';
    return '${d.month}/${d.day}';
  }
}

class _EditPetDialog extends StatefulWidget {
  final PetProfile pet;
  final PetHealthProvider provider;
  const _EditPetDialog({required this.pet, required this.provider});

  @override
  State<_EditPetDialog> createState() => _EditPetDialogState();
}

class _EditPetDialogState extends State<_EditPetDialog> {
  late TextEditingController _nameCtrl;
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.pet.name);
    _selectedTags = List.from(widget.pet.healthTags);
  }

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
              const Text('Edit Pet Profile', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 20),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Pet Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppColors.cream,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Health Tags', style: AppTextStyles.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kHealthTags.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return GestureDetector(
                    onTap: () => setState(() {
                      selected ? _selectedTags.remove(tag) : _selectedTags.add(tag);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.sageMuted : AppColors.cream,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: selected ? AppColors.sageGreen : AppColors.divider),
                      ),
                      child: Text(tag, style: TextStyle(fontSize: 13, color: selected ? AppColors.sageGreen : AppColors.textSecondary, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    widget.provider.updatePet(widget.pet.copyWith(name: _nameCtrl.text, healthTags: _selectedTags));
                    Navigator.pop(context);
                  },
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
