// Data contracts and illustrative snapshots for the Z-reading history UI.
/// Illustrative CLOSED-day snapshots. Replace with read-only server records later.
class ZReadingRecord {
  const ZReadingRecord({
    required this.id,
    required this.date,
    required this.counter,
    required this.openingInvoice,
    required this.closingInvoice,
    required this.gross,
    required this.discounts,
    required this.refunds,
    required this.cash,
    required this.otherPayments,
    required this.transactions,
  });
  final String id;
  final DateTime date;
  final String counter;
  final String openingInvoice;
  final String closingInvoice;
  final double gross, discounts, refunds, cash, otherPayments;
  final int transactions;
  double get net => gross - discounts - refunds;
}

final demoZReadings = <ZReadingRecord>[];

String zDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
String zMoney(double n) => '₱${n.toStringAsFixed(2)}';
