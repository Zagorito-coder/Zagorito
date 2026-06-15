// ============================================================
//  techniques_page.dart — Encyclopédie des Techniques & Montages
//  GridView 2 colonnes + Détail avec 5 onglets TabBar
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/models/technique.dart';
import 'package:spots_app/services/technique_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/models/fish_species.dart' show FishingTechnique;
import 'package:spots_app/l10n/app_localizations.dart';


class TechniquesPage extends StatefulWidget {

  const TechniquesPage({super.key});

  @override
  State<TechniquesPage> createState() => _TechniquesPageState();
}

class _TechniquesPageState extends State<TechniquesPage> {
  List<Technique> _all = [];
  List<Technique> _filtered = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String? _regionFilter;

  final List<String> _regions = [
    'Toutes',
    'Méditerranée',
    'Atlantique',
    'Méditerranée & Atlantique',
    'Océan Atlantique',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await TechniqueService.loadTechniques();
      setState(() {
        _all = data;
        _filtered = data;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[TechniquesPage] Erreur chargement techniques: $e');
      debugPrint('$st');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _all.where((t) {
        final matchSearch = _searchQuery.isEmpty ||
            t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.scientificName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.family.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchRegion = _regionFilter == null ||
            _regionFilter == 'Toutes' ||
            t.region.contains(_regionFilter!);
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          Icons.phishing,
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
                              context.tr('techniques.title'),
                              style: TextStyle(
                                color: tc.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              context.trArgs('techniques.count', args: {'count': _all.length.toString()}),
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
                              hintText: 'Rechercher une technique...',
                              hintStyle: TextStyle(color: tc.textMuted),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                            child: Icon(Icons.close,
                                color: tc.textMuted, size: 18),
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
                      itemCount: _regions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final region = _regions[index];
                        final isActive = _regionFilter == region ||
                            (_regionFilter == null && region == 'Toutes');
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _regionFilter =
                                  region == 'Toutes' ? null : region;
                            });
                            _applyFilters();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
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
                              region,
                              style: TextStyle(
                                color: isActive
                                    ? tc.oceanLight
                                    : tc.textSecondary,
                                fontSize: 12,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w500,
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

            // ── GRID ──
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
                                  color: tc.error.withValues(alpha: 0.6),
                                  size: 48),
                              const SizedBox(height: 12),
                              Text(
                                context.tr('techniques.loadingError'),
                                style: TextStyle(
                                    color: tc.textMuted, fontSize: 15),
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
                                child: Text(context.tr('techniques.retry')),
                              ),
                            ],
                          ),
                        )
                      : _filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off,
                                      color: tc.textMuted, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aucune technique trouvée',
                                    style: TextStyle(
                                        color: tc.textMuted, fontSize: 15),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                return _TechniqueGridCard(
                                  technique: _filtered[index],
                                  onTap: () =>
                                      _openDetail(_filtered[index]),
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

  void _openDetail(Technique technique) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TechniqueDetailPage(technique: technique),
      ),
    );
  }
}

// ──────────────────────────────────────────────
//  CARTE GRID MODERNE
// ──────────────────────────────────────────────

class _TechniqueGridCard extends StatelessWidget {
  final Technique technique;
  final VoidCallback onTap;

  const _TechniqueGridCard({required this.technique, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image de fond
            Image.network(
              technique.photoUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: tc.surfaceElevated,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: tc.oceanLight,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: tc.surfaceElevated,
                child: Icon(Icons.image_not_supported,
                    color: tc.textMuted, size: 32),
              ),
            ),

            // Dégradé sombre en bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Badge région en haut à droite
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  technique.region.length > 12
                      ? '${technique.region.substring(0, 12)}...'
                      : technique.region,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // Infos texte en bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      technique.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${technique.sizeMinCm}-${technique.sizeMaxCm} cm  •  ${technique.family}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  PAGE DE DÉTAIL TECHNIQUE — 5 ONGLETS
// ============================================================

class TechniqueDetailPage extends StatefulWidget {
  final Technique technique;

  const TechniqueDetailPage({super.key, required this.technique});

  @override
  State<TechniqueDetailPage> createState() => _TechniqueDetailPageState();
}

class _TechniqueDetailPageState extends State<TechniqueDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);
    final t = widget.technique;

    return Scaffold(
      backgroundColor: tc.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── APP BAR avec photo ──
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: tc.surface,
            foregroundColor: tc.textPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                t.name,
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
                  Image.network(
                    t.photoUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(color: tc.surfaceElevated);
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: tc.surfaceElevated,
                      child: Icon(Icons.image_not_supported,
                          color: tc.textMuted, size: 48),
                    ),
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
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: tc.oceanLight,
              unselectedLabelColor: tc.textMuted,
              indicatorColor: tc.oceanLight,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: 'Infos'),
                Tab(text: 'Techniques'),
                Tab(text: 'Montages'),
                Tab(text: 'Nœuds'),
                Tab(text: 'Réglementation'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfosTab(t: t, tc: tc),
            _TechniquesTab(t: t, tc: tc),
            _MontagesTab(t: t, tc: tc),
            _NoeudsTab(t: t, tc: tc),
            _ReglementationTab(t: t, tc: tc),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 1 — INFOS
// ═══════════════════════════════════════════════════════════

class _InfosTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _InfosTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.scientificName,
            style: TextStyle(
              color: tc.textSecondary,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Informations', tc: tc),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoTile(
                icon: Icons.category,
                label: 'Famille',
                value: t.family,
                color: tc.oceanLight,
                tc: tc,
              ),
              _InfoTile(
                icon: Icons.straighten,
                label: 'Taille',
                value: '${t.sizeMinCm}-${t.sizeMaxCm} cm',
                color: tc.gold,
                tc: tc,
              ),
              _InfoTile(
                icon: Icons.scale,
                label: 'Poids',
                value: '${t.weightMinKg}-${t.weightMaxKg} kg',
                color: tc.success,
                tc: tc,
              ),
              _InfoTile(
                icon: Icons.place,
                label: 'Région',
                value: t.region,
                color: tc.warning,
                tc: tc,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Saison de pêche',
            value: t.season,
            tc: tc,
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Habitat', tc: tc),
          const SizedBox(height: 8),
          _TextCard(text: t.habitat, tc: tc),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Description', tc: tc),
          const SizedBox(height: 8),
          Text(
            t.description,
            style: TextStyle(
              color: tc.textPrimary.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Conseils du pêcheur', tc: tc),
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
                    t.tips,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 2 — TECHNIQUES & APPÂTS
// ═══════════════════════════════════════════════════════════

class _TechniquesTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _TechniquesTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (t.techniques.isEmpty) {
      return _EmptyTab(message: 'Aucune technique enregistrée', tc: tc);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: t.techniques.length,
      itemBuilder: (_, i) => _TechniqueCard(technique: t.techniques[i], tc: tc),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 3 — MONTAGES
// ═══════════════════════════════════════════════════════════

class _MontagesTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _MontagesTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (t.rigs.isEmpty) {
      return _EmptyTab(message: 'Aucun montage enregistré', tc: tc);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: t.rigs.length,
      itemBuilder: (_, i) {
        final rig = t.rigs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: tc.textPrimary.withValues(alpha: 0.06)),
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
                    child: Icon(Icons.construction,
                        color: tc.oceanLight, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rig.name,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                rig.description,
                style: TextStyle(
                  color: tc.textPrimary.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: rig.components.map((c) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tc.oceanLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tc.oceanLight.withValues(alpha: 0.25),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      c,
                      style: TextStyle(
                        color: tc.oceanLight.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 4 — NŒUDS
// ═══════════════════════════════════════════════════════════

class _NoeudsTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _NoeudsTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (t.knots.isEmpty) {
      return _EmptyTab(message: 'Aucun nœud enregistré', tc: tc);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: t.knots.length,
      itemBuilder: (_, i) {
        final knot = t.knots[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tc.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: tc.textPrimary.withValues(alpha: 0.06)),
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
                      color: tc.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.linear_scale,
                        color: tc.warning, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      knot.name,
                      style: TextStyle(
                        color: tc.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tc.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  knot.usage,
                  style: TextStyle(
                    color: tc.warning.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                knot.description,
                style: TextStyle(
                  color: tc.textPrimary.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 5 — RÉGLEMENTATION
// ═══════════════════════════════════════════════════════════

class _ReglementationTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _ReglementationTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    t.regulation,
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
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.straighten,
            label: 'Taille minimale',
            value: '${t.sizeMinCm} cm',
            tc: tc,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.scale,
            label: 'Poids indicatif min',
            value: '${t.weightMinKg} kg',
            tc: tc,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ── WIDGETS UTILITAIRES PARTAGÉS ──

class _EmptyTab extends StatelessWidget {
  final String message;
  final ThemeColors tc;

  const _EmptyTab({required this.message, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, color: tc.textMuted, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: tc.textMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

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

class _TextCard extends StatelessWidget {
  final String text;
  final ThemeColors tc;

  const _TextCard({required this.text, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: tc.textPrimary.withValues(alpha: 0.8),
          fontSize: 14,
          height: 1.5,
        ),
      ),
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
                child: Icon(Icons.phishing,
                    color: tc.oceanLight, size: 16),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
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
