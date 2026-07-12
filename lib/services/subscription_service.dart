import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:spots_app/models/subscription_model.dart';

class SubscriptionService {
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('subscriptions');

  static Future<SubscriptionModel> getOrCreateSubscription(String userId) async {
    debugPrint('[SubscriptionService] getOrCreateSubscription userId=$userId');
    try {
      final doc = await _col.doc(userId).get();
      debugPrint('[SubscriptionService] doc.exists=${doc.exists} data=${doc.data()}');
      if (doc.exists && doc.data() != null) {
        final sub = SubscriptionModel.fromMap(userId, doc.data()!);
        debugPrint('[SubscriptionService] existing sub plan=${sub.planType} registration=${sub.registrationDate}');
        if (sub.planType == PlanType.trial && !sub.isTrialActive) {
          return sub.copyWith(planType: PlanType.free);
        }
        return sub;
      }
      final newSub = SubscriptionModel.newUser(userId);
      debugPrint('[SubscriptionService] creating new sub plan=trial registration=${newSub.registrationDate}');
      await _col.doc(userId).set(newSub.toMap());
      return newSub;
    } on FirebaseException catch (e) {
      debugPrint('[SubscriptionService] FirebaseException getOrCreateSubscription: $e');
      return SubscriptionModel.newUser(userId);
    } catch (e) {
      debugPrint('[SubscriptionService] Erreur getOrCreateSubscription: $e');
      return SubscriptionModel.newUser(userId);
    }
  }

  static Stream<SubscriptionModel> subscriptionStream(String userId) {
    return _col.doc(userId).snapshots().handleError((e) {
      debugPrint('[SubscriptionService] subscriptionStream error: $e');
    }).map((snap) {
      if (!snap.exists || snap.data() == null) {
        return SubscriptionModel.newUser(userId);
      }
      final sub = SubscriptionModel.fromMap(userId, snap.data()!);
      if (sub.planType == PlanType.trial && !sub.isTrialActive) {
        return sub.copyWith(planType: PlanType.free);
      }
      return sub;
    });
  }

  static Future<void> activateMonthly(String userId) async {
    final expiry = DateTime.now().add(const Duration(days: 30));
    await _col.doc(userId).update({
      'planType': PlanType.monthly.name,
      'expiryDate': expiry.toIso8601String(),
    });
  }

  static Future<void> activateAnnual(String userId) async {
    final expiry = DateTime.now().add(const Duration(days: 365));
    await _col.doc(userId).update({
      'planType': PlanType.annual.name,
      'expiryDate': expiry.toIso8601String(),
    });
  }

  static Future<void> activateLifetime(String userId) async {
    await _col.doc(userId).update({
      'planType': PlanType.lifetime.name,
      'expiryDate': null,
    });
  }
}
