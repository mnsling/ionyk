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

// Demo only — these are not actual archived Z-Readings.
final demoZReadings = <ZReadingRecord>[
  ZReadingRecord(id: '0000018', date: DateTime(2026, 11, 12), counter: 'Counter 01', openingInvoice: '00001201', closingInvoice: '00001246', gross: 12500, discounts: 250, refunds: 300, cash: 10150, otherPayments: 1800, transactions: 46),
  ZReadingRecord(id: '0000017', date: DateTime(2026, 11, 11), counter: 'Counter 01', openingInvoice: '00001158', closingInvoice: '00001200', gross: 10640, discounts: 120, refunds: 0, cash: 8800, otherPayments: 1720, transactions: 43),
  ZReadingRecord(id: '0000016', date: DateTime(2026, 11, 10), counter: 'Counter 01', openingInvoice: '00001105', closingInvoice: '00001157', gross: 15100, discounts: 450, refunds: 100, cash: 12750, otherPayments: 1800, transactions: 53),
  ZReadingRecord(id: '0000015', date: DateTime(2026, 11, 9), counter: 'Counter 01', openingInvoice: '00001060', closingInvoice: '00001104', gross: 11300, discounts: 300, refunds: 0, cash: 9200, otherPayments: 1800, transactions: 45),
  ZReadingRecord(id: '0000014', date: DateTime(2026, 11, 8), counter: 'Counter 01', openingInvoice: '00001012', closingInvoice: '00001059', gross: 13400, discounts: 100, refunds: 250, cash: 11750, otherPayments: 1300, transactions: 48),
];

String zDate(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
String zMoney(double n) => '₱${n.toStringAsFixed(2)}';

