// ============================================================
//  species_page.dart — Encyclopédie des poissons
//  Adaptatif clair/sombre + recherche + filtres
// ============================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:spots_app/models/fish_species.dart';
import 'package:spots_app/services/species_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';

class SpeciesPage extends StatefulWidget {
  const SpeciesPage({super.key});

  @override
  State<SpeciesPage> createState() => _SpeciesPageState();
}

class _SpeciesPageState extends State<SpeciesPage> {
  List<FishSpecies> _allSpecies = [];
  List<FishSpecies> _filtered = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _regionFilter;

  final List<String> _regionKeys = [
    'species.all',
    'species.mediterranean',
    'species.atlantic',
    'species.medAtl',
    'species.oceanAtl',
  ];

  @override
  void initState() {
    super.initState();
    LanguageController.instance.addListener(_onLanguageChanged);
    _loadData();
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    SpeciesService.clearCache();
    setState(() {
      _loading = true;
      _regionFilter = null;
      _searchQuery = '';
    });
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await SpeciesService.loadSpecies();
      if (!mounted) return;
      setState(() {
        _allSpecies = data;
        _filtered = data;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[SpeciesPage] Erreur chargement espèces: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _allSpecies.where((s) {
        final matchSearch = _searchQuery.isEmpty ||
            s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.scientificName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.family.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchRegion = _regionFilter == null ||
            _regionFilter == context.tr('species.all') ||
            s.region.contains(_regionFilter!);
        return matchSearch && matchRegion;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final tc = ThemeColors.of(context);
        return Scaffold(
          backgroundColor: tc.background,
          body: SafeArea(
            child: Column(
              children: [
                // ── HEADER ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppBackButton(toHome: true),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: tc.oceanLight.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.set_meal,
                              color: tc.oceanLight,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('species.title'),
                                  style: TextStyle(
                                    color: tc.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  context.trArgs('species.speciesCount', args: {'count': _allSpecies.length.toString()}),
                                  style: TextStyle(
                                    color: tc.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: tc.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: tc.textPrimary.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: tc.textMuted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                style: TextStyle(color: tc.textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: context.tr('species.search'),
                                  hintStyle: TextStyle(color: tc.textMuted),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onChanged: (v) {
                                  _searchQuery = v;
                                  _applyFilters();
                                },
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchQuery = '';
                                  _applyFilters();
                                },
                                child: Icon(Icons.close, color: tc.textMuted, size: 18),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Region filters
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _regionKeys.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final regionKey = _regionKeys[index];
                            final regionLabel = context.tr(regionKey);
                            final isActive = _regionFilter == regionLabel ||
                                (_regionFilter == null && regionKey == 'species.all');
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _regionFilter = regionKey == 'species.all' ? null : regionLabel;
                                });
                                _applyFilters();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? tc.oceanLight.withValues(alpha: 0.15)
                                      : tc.surfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isActive
                                        ? tc.oceanLight.withValues(alpha: 0.5)
                                        : tc.textPrimary.withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  regionLabel,
                                  style: TextStyle(
                                    color: isActive ? tc.oceanLight : tc.textSecondary,
                                    fontSize: 12,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ── LISTE ──
                Expanded(
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: tc.oceanLight,
                            strokeWidth: 2.5,
                          ),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline,
                                      color: tc.error.withValues(alpha: 0.6), size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('species.loadingError'),
                                    style: TextStyle(color: tc.textMuted, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _error!,
                                    style: TextStyle(
                                      color: tc.textMuted.withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _loadData,
                                    child: Text(context.tr('species.retry')),
                                  ),
                                ],
                              ),
                            )
                          : _filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_off, color: tc.textMuted, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        context.tr('species.noSpeciesFound'),
                                        style: TextStyle(color: tc.textMuted, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    return _SpeciesCard(
                                      species: _filtered[index],
                                      onTap: () => _openDetail(_filtered[index]),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDetail(FishSpecies species) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpeciesDetailPage(species: species),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  CARTE D'ESPÈCE
// ──────────────────────────────────────────────

class _SpeciesCard extends StatelessWidget {
  final FishSpecies species;
  final VoidCallback onTap;

  const _SpeciesCard({required this.species, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tc.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tc.textPrimary.withValues(alpha: 0.06),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: tc.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Photo
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 90,
                height: 90,
                child: _SpeciesImage(
                  path: species.photoUrl,
                  fit: BoxFit.cover,
                  width: 90,
                  height: 90,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    species.name,
                    style: TextStyle(
                      color: tc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    species.scientificName,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Tag(text: species.family, color: tc.oceanLight),
                      const SizedBox(width: 6),
                      _Tag(
                        text: '${species.sizeMinCm}-${species.sizeMaxCm} cm',
                        color: tc.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.place, color: tc.textMuted, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          species.region,
                          style: TextStyle(
                            color: tc.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: tc.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
//  PAGE DE DÉTAIL
// ============================================================

class SpeciesDetailPage extends StatelessWidget {
  final FishSpecies species;

  const SpeciesDetailPage({super.key, required this.species});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return Scaffold(
      backgroundColor: tc.background,
      body: CustomScrollView(
        slivers: [
          // ── APP BAR avec photo ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: tc.surface,
            foregroundColor: tc.textPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                species.name,
                style: TextStyle(
                  color: tc.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
          background: Stack(
                fit: StackFit.expand,
                children: [
                  _SpeciesImage(
                    path: species.photoUrl,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── CONTENU ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom scientifique
                  Text(
                    species.scientificName,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── INFOS RAPIDES ──
                  _SectionTitle(title: context.tr('species.information'), tc: tc),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoTile(
                        icon: Icons.category,
                        label: context.tr('species.family'),
                        value: species.family,
                        color: tc.oceanLight,
                        tc: tc,
                      ),
                      _InfoTile(
                        icon: Icons.straighten,
                        label: context.tr('species.size'),
                        value: '${species.sizeMinCm}-${species.sizeMaxCm} cm',
                        color: tc.gold,
                        tc: tc,
                      ),
                      _InfoTile(
                        icon: Icons.scale,
                        label: context.tr('species.weight'),
                        value: '${species.weightMinKg}-${species.weightMaxKg} kg',
                        color: tc.success,
                        tc: tc,
                      ),
                      _InfoTile(
                        icon: Icons.place,
                        label: context.tr('species.region'),
                        value: species.region,
                        color: tc.warning,
                        tc: tc,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── SAISON ──
                  _InfoRow(
                    icon: Icons.calendar_today,
                    label: context.tr('species.fishingSeason'),
                    value: species.season,
                    tc: tc,
                  ),

                  const SizedBox(height: 20),

                  // ── HABITAT ──
                  _SectionTitle(title: context.tr('species.habitat'), tc: tc),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tc.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: tc.textPrimary.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      species.habitat,
                      style: TextStyle(
                        color: tc.textPrimary.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── DESCRIPTION ──
                  _SectionTitle(title: context.tr('species.description'), tc: tc),
                  const SizedBox(height: 8),
                  Text(
                    species.description,
                    style: TextStyle(
                      color: tc.textPrimary.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── TECHNIQUES ET APPÂTS ──
                  _SectionTitle(title: context.tr('species.techniquesAndBaits'), tc: tc),
                  const SizedBox(height: 10),
                  ...species.techniques.map((tech) => _TechniqueCard(technique: tech, tc: tc)),

                  const SizedBox(height: 20),

                  // ── CONSEILS ──
                  _SectionTitle(title: context.tr('species.tips'), tc: tc),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tc.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: tc.success.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb, color: tc.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            species.tips,
                            style: TextStyle(
                              color: tc.textPrimary.withValues(alpha: 0.85),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── RÉGLEMENTATION ──
                  _SectionTitle(title: context.tr('species.regulation'), tc: tc),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tc.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: tc.warning.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.gavel, color: tc.warning, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            species.regulation,
                            style: TextStyle(
                              color: tc.textPrimary.withValues(alpha: 0.85),
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── WIDGETS UTILITAIRES ──

class _SectionTitle extends StatelessWidget {
  final String title;
  final ThemeColors tc;

  const _SectionTitle({required this.title, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: tc.oceanLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: tc.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeColors tc;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tc.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: tc.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: tc.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeColors tc;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tc.oceanLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: tc.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: tc.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeciesImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  const _SpeciesImage({
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  bool get _isAsset => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final errorWidget = Container(
      color: tc.surfaceElevated,
      width: width,
      height: height,
      child: Icon(Icons.image_not_supported, color: tc.textMuted),
    );

    if (_isAsset) {
      return Image.asset(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }

    return CachedNetworkImage(
      imageUrl: path,
      fit: fit,
      width: width,
      height: height,
      placeholder: (context, url) => Container(
        color: tc.surfaceElevated,
        width: width,
        height: height,
        child: Center(
          child: CircularProgressIndicator(
            color: tc.oceanLight,
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => errorWidget,
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  final FishingTechnique technique;
  final ThemeColors tc;

  const _TechniqueCard({required this.technique, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tc.oceanLight.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.phishing, color: tc.oceanLight, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      technique.name,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (technique.description.isNotEmpty)
                      Text(
                        technique.description,
                        style: TextStyle(
                          color: tc.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (technique.baits.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: technique.baits.map((bait) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tc.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: tc.gold.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bait.name,
                        style: TextStyle(
                          color: tc.gold.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bait.description.isNotEmpty)
                        Text(
                          bait.description,
                          style: TextStyle(
                            color: tc.textMuted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
