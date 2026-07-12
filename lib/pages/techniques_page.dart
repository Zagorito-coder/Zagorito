// ============================================================
//  techniques_page.dart — Encyclopédie des Nœuds de Pêche
// ============================================================

import 'package:flutter/material.dart';
import 'package:spots_app/models/technique.dart';
import 'package:spots_app/services/technique_service.dart';
import 'package:spots_app/theme.dart';
import 'package:spots_app/theme_controller.dart';
import 'package:spots_app/l10n/app_localizations.dart';
import 'package:spots_app/widgets/app_back_button.dart';

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
  String? _categoryFilter;

  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    LanguageController.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageController.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (!mounted) return;
    TechniqueService.clearCache();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await TechniqueService.loadTechniques();
      final cats = data
          .map((t) => t.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      cats.sort();
      setState(() {
        _all = data;
        _filtered = data;
        _categories = ['__all__', ...cats];
        _categoryFilter = null;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[TechniquesPage] Erreur chargement: $e');
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
            t.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.targetFish.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchCategory =
            _categoryFilter == null || t.category == _categoryFilter;
        return matchSearch && matchCategory;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ThemeController.instance,
        LanguageController.instance,
      ]),
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
                      const AppBackButton(),
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
                              Icons.linear_scale,
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
                                  context.trArgs('techniques.count',
                                      args: {'count': _all.length.toString()}),
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
                            Icon(Icons.search,
                                color: tc.textMuted, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                style: TextStyle(
                                    color: tc.textPrimary, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: context.tr('techniques.search'),
                                  hintStyle:
                                      TextStyle(color: tc.textMuted),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14),
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
                      // Category filters
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isAll = cat == '__all__';
                            final isActive = _categoryFilter == null
                                ? isAll
                                : _categoryFilter == cat;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _categoryFilter = isAll ? null : cat;
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
                                        : tc.textPrimary
                                            .withValues(alpha: 0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isAll
                                      ? context.tr('techniques.all')
                                      : cat,
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
                                      color:
                                          tc.textMuted.withValues(alpha: 0.7),
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: _loadData,
                                    child: Text(
                                        context.tr('techniques.retry')),
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
                                        context.tr('techniques.noResults'),
                                        style: TextStyle(
                                            color: tc.textMuted, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                )
                              : GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 0, 16, 16),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final t = _filtered[index];
                                    return _TechniqueGridCard(
                                      key: ValueKey('${t.id}_${LanguageController.instance.langCode}'),
                                      technique: t,
                                      onTap: () =>
                                          _openDetail(t),
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
//  CARTE GRID
// ──────────────────────────────────────────────
class _TechniqueGridCard extends StatelessWidget {
  final Technique technique;
  final VoidCallback onTap;

  const _TechniqueGridCard(
      {super.key, required this.technique, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tc = ThemeColors.of(context);

    Color difficultyColor;
    switch (technique.difficulty.toLowerCase()) {
      case 'facile':
      case 'easy':
      case 'سهل':
        difficultyColor = Colors.green;
        break;
      case 'moyen':
      case 'medium':
      case 'متوسط':
        difficultyColor = Colors.orange;
        break;
      case 'difficile':
      case 'difficult':
      case 'صعب':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = tc.textMuted;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tc.surfaceElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: tc.textPrimary.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGE CENTRÉE ──
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tc.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                ),
                child: _TechniqueImage(
                  url: technique.photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: tc.oceanLight,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: tc.textMuted,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            // ── INFOS TEXTE ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          technique.name,
                          style: TextStyle(
                            color: tc.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: difficultyColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          technique.difficulty,
                          style: TextStyle(
                            color: difficultyColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    technique.category,
                    style: TextStyle(
                      color: tc.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  PAGE DE DÉTAIL — 3 ONGLETS
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
    _tabController = TabController(length: 3, vsync: this);
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
          SliverAppBar(
            expandedHeight: 320,
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
                ),
              ),
              background: Container(
                color: tc.surface,
                padding: const EdgeInsets.only(
                    top: 80, left: 16, right: 16, bottom: 60),
                child: Center(
                  child: _TechniqueImage(
                    url: t.photoUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(color: tc.surfaceElevated);
                    },
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_not_supported,
                      color: tc.textMuted,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  color: tc.surface.withValues(alpha: 0.95),
                  border: Border(
                    top: BorderSide(
                      color: tc.textPrimary.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                child: TabBar(
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
              tabs: [
                Tab(text: context.tr('techniques.tabInfos')),
                Tab(text: context.tr('techniques.tabMateriel')),
                Tab(text: context.tr('techniques.tabConseils')),
              ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _InfosTab(t: t, tc: tc),
            _MaterielTab(t: t, tc: tc),
            _ConseilsTab(t: t, tc: tc),
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
    Color difficultyColor;
    switch (t.difficulty.toLowerCase()) {
      case 'facile':
      case 'easy':
      case 'سهل':
        difficultyColor = Colors.green;
        break;
      case 'moyen':
      case 'medium':
      case 'متوسط':
        difficultyColor = Colors.orange;
        break;
      case 'difficile':
      case 'difficult':
      case 'صعب':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = tc.textMuted;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (t.category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tc.oceanLight.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.category,
                style: TextStyle(
                  color: tc.oceanLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _SectionTitle(title: context.tr('techniques.information'), tc: tc),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoTile(
                icon: Icons.category,
                label: context.tr('techniques.category'),
                value: t.category,
                color: tc.oceanLight,
                tc: tc,
              ),
              _InfoTile(
                icon: Icons.signal_cellular_alt,
                label: context.tr('techniques.difficulty'),
                value: t.difficulty,
                color: difficultyColor,
                tc: tc,
              ),
              _InfoTile(
                icon: Icons.set_meal,
                label: context.tr('techniques.technique'),
                value: t.techniqueType,
                color: tc.gold,
                tc: tc,
              ),
              _InfoTile(
                icon: Icons.water,
                label: context.tr('techniques.targetFish'),
                value: t.targetFish,
                color: tc.success,
                tc: tc,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: context.tr('techniques.description'), tc: tc),
          const SizedBox(height: 8),
          _TextCard(text: t.description, tc: tc),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 2 — MATÉRIEL
// ═══════════════════════════════════════════════════════════
class _MaterielTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _MaterielTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (t.requiredMaterial.isEmpty) {
      return _EmptyTab(
          message: context.tr('techniques.noMaterial'), tc: tc);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: context.tr('techniques.requiredMaterial'), tc: tc),
          const SizedBox(height: 10),
          _TextCard(text: t.requiredMaterial, tc: tc),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  ONGLET 3 — CONSEILS
// ═══════════════════════════════════════════════════════════
class _ConseilsTab extends StatelessWidget {
  final Technique t;
  final ThemeColors tc;

  const _ConseilsTab({required this.t, required this.tc});

  @override
  Widget build(BuildContext context) {
    if (t.tips.isEmpty) {
      return _EmptyTab(message: context.tr('techniques.noTips'), tc: tc);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: context.tr('techniques.tips'), tc: tc),
          const SizedBox(height: 10),
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
          Icon(Icons.folder_open_outlined,
              color: tc.textMuted, size: 48),
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

// ── WIDGET IMAGE ASSET ──
class _TechniqueImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?) loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?) errorBuilder;

  const _TechniqueImage({
    required this.url,
    required this.fit,
    required this.loadingBuilder,
    required this.errorBuilder,
  });

  @override
  Widget build(BuildContext context) {
    // La clé avec langCode force le rebuild quand la langue change
    final langKey = LanguageController.instance.langCode;
    return Image.asset(
      url,
      fit: fit,
      key: ValueKey('${langKey}_$url'),
      errorBuilder: errorBuilder,
    );
  }
}
