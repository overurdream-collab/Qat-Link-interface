enum CurrencyCode { yer, sar, usd }

enum MovementType { debt, payment }

enum MovementStatus { pending, approved, rejected }

class MovementModel {
  const MovementModel({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.currency,
    required this.type,
    required this.status,
    required this.date,
    this.description,
  }) : assert(amount > 0, 'Movement amount must be greater than zero.');

  final String id;
  final String customerId;
  final double amount;
  final CurrencyCode currency;
  final MovementType type;
  final MovementStatus status;
  final DateTime date;
  final String? description;
}

class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.primaryCurrency,
  });

  final String id;
  final String name;
  final String phone;
  final CurrencyCode primaryCurrency;
}
