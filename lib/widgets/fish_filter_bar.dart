// ============================================================
//  fish_filter_bar.dart — Barre horizontale de sélection de poissons
// ============================================================

import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:spots_app/models/fish_model.dart';
import 'package:spots_app/theme.dart';

class FishFilterBar extends StatelessWidget {
  final List<FishModel> fishes;
  final FishModel? selectedFish;
  final void Function(FishModel) onFishSelected;
  final VoidCallback onFishDeselected;

  const FishFilterBar({
    super.key,
    required this.fishes,
    required this.selectedFish,
    required this.onFishSelected,
    required this.onFishDeselected,
  });

  static const double _barHeight = 120;
  static const double _cardWidth = 72;
  static const double _cardHeight = 100;
  static const double _imageSize = 56;
  static const Color _selectedRing = Color(0xFF48CAE4);
  static const Color _selectedBg = Color(0xFF48CAE4);

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return SizedBox(
      height: _barHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: tc.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tc.glassBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: tc.shadowColor,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: fishes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final fish = fishes[index];
                final isSelected = selectedFish?.id == fish.id;
                return _FishCard(
                  fish: fish,
                  isSelected: isSelected,
                  onTap: () {
                    if (isSelected) {
                      onFishDeselected();
                    } else {
                      onFishSelected(fish);
                    }
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _FishCard extends StatelessWidget {
  final FishModel fish;
  final bool isSelected;
  final VoidCallback onTap;

  const _FishCard({
    required this.fish,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: FishFilterBar._cardWidth,
          height: FishFilterBar._cardHeight,
          decoration: BoxDecoration(
            color: isSelected
                ? FishFilterBar._selectedBg.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: isSelected
                ? Border.all(color: FishFilterBar._selectedRing, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isSelected ? 1.05 : 1.0,
                child: Container(
                  width: FishFilterBar._imageSize,
                  height: FishFilterBar._imageSize,
                  padding: isSelected ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? FishFilterBar._selectedRing : null,
                  ),
                  child: ClipOval(
                    child: _buildImage(context),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fish.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (fish.imageUrl.startsWith('assets/')) {
      return Image.asset(
        fish.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(context),
      );
    }
    return CachedNetworkImage(
      imageUrl: fish.imageUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => _placeholder(context),
      errorWidget: (_, __, ___) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: const Color(0xFF1E6091),
      child: const Center(
        child: Text(
          '🐟',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }

}
