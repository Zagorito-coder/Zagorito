enum PlanType { free, trial, monthly, annual, lifetime }

class SubscriptionModel {
  final String userId;
  final DateTime registrationDate;
  final PlanType planType;
  final DateTime? expiryDate;

  const SubscriptionModel({
    required this.userId,
    required this.registrationDate,
    required this.planType,
    this.expiryDate,
  });

  int get daysSinceRegistration =>
      DateTime.now().difference(registrationDate).inDays;

  int get trialDaysRemaining => 30 - daysSinceRegistration;

  bool get isTrialActive =>
      planType == PlanType.trial && daysSinceRegistration < 30;

  bool get isPaidActive {
    if (planType == PlanType.lifetime) return true;
    if (planType == PlanType.monthly || planType == PlanType.annual) {
      if (expiryDate == null) return false;
      return DateTime.now().isBefore(expiryDate!);
    }
    return false;
  }

  bool get hasPremiumAccess => isTrialActive || isPaidActive;

  double get maxZoom => hasPremiumAccess ? 16.0 : 8.0;

  factory SubscriptionModel.fromMap(String userId, Map<String, dynamic> map) {
    return SubscriptionModel(
      userId: userId,
      registrationDate: DateTime.parse(map['registrationDate'] as String),
      planType: PlanType.values.firstWhere(
        (e) => e.name == (map['planType'] as String? ?? 'trial'),
        orElse: () => PlanType.trial,
      ),
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'registrationDate': registrationDate.toIso8601String(),
        'planType': planType.name,
        'expiryDate': expiryDate?.toIso8601String(),
      };

  factory SubscriptionModel.newUser(String userId) => SubscriptionModel(
        userId: userId,
        registrationDate: DateTime.now(),
        planType: PlanType.trial,
      );

  SubscriptionModel copyWith({PlanType? planType, DateTime? expiryDate}) =>
      SubscriptionModel(
        userId: userId,
        registrationDate: registrationDate,
        planType: planType ?? this.planType,
        expiryDate: expiryDate ?? this.expiryDate,
      );
}
