import 'package:intl/intl.dart';

class Boleto {
  final String nome;
  final DateTime data;
  final double valor;

  Boleto({required this.nome, required this.data, required this.valor});

  List<String> toCsvRow() {
    final valorFormatado = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    ).format(valor);
    return [nome, data.toIso8601String(), valorFormatado];
  }
}
