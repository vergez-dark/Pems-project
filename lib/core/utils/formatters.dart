import 'package:intl/intl.dart';

String formatMoney(int amount, [String currency = 'FCFA']) =>
    '${NumberFormat.decimalPattern('fr_FR').format(amount)} $currency';

String formatDay(DateTime date) =>
    DateFormat('d MMM yyyy', 'fr_FR').format(date);
