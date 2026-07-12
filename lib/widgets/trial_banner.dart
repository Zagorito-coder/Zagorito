import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spots_app/providers/premium_provider.dart';
import 'package:spots_app/models/subscription_model.dart';

class TrialBanner extends StatelessWidget {
  final VoidCallback onSubscribeTap;
  const TrialBanner({super.key, required this.onSubscribeTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(builder: (ctx, provider, _) {
      if (!provider.isOnTrial) return const SizedBox.shrink();
      final days = provider.trialDaysRemaining;
      final urgency = days <= 5;
      return GestureDetector(
        onTap: onSubscribeTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: urgency
                ? const Color(0xFFFF6B35).withValues(alpha: 0.95)
                : const Color(0xFF1E6091).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                urgency ? Icons.timer_outlined : Icons.star_border_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  days == 0
                      ? 'Dernier jour d\'essai ! S\'abonner →'
                      : 'Essai gratuit : $days jour${days > 1 ? 's' : ''} restant${days > 1 ? 's' : ''} · S\'abonner →',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class SubscriptionModal extends StatelessWidget {
  final PlanType currentPlan;
  final VoidCallback onAnnualTap;
  final VoidCallback onLifetimeTap;
  final VoidCallback onClose;

  const SubscriptionModal({
    super.key,
    required this.currentPlan,
    required this.onAnnualTap,
    required this.onLifetimeTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.phishing, color: Color(0xFF1E6091), size: 48),
          const SizedBox(height: 12),
          const Text(
            'Accès complet aux spots',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            currentPlan == PlanType.free
                ? 'Votre essai gratuit est terminé.\nAbonnez-vous pour retrouver le zoom 16x et voir tous les spots de pêche en détail.'
                : 'Zoom 16x · Tous les spots · Mises à jour incluses',
            style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _FeatureRow(icon: Icons.zoom_in, label: 'Zoom 16x — voir l\'emplacement exact des spots'),
          const SizedBox(height: 8),
          _FeatureRow(icon: Icons.place, label: '6 200+ spots de pêche détaillés'),
          const SizedBox(height: 8),
          _FeatureRow(icon: Icons.update, label: 'Mises à jour et nouveaux spots inclus'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAnnualTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E6091),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Column(children: [
                Text('Abonnement annuel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Renouvellement chaque année',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLifetimeTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A83A),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.star_rounded, size: 18, color: Colors.black87),
                  SizedBox(width: 6),
                  Text('Accès à vie',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                SizedBox(height: 2),
                Text('Paiement unique — à vie',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onClose,
            child: Text('Plus tard', style: TextStyle(color: Colors.grey[500])),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: const Color(0xFF1E6091), size: 20),
      const SizedBox(width: 10),
      Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13, height: 1.4))),
    ]);
  }
}
