import 'package:flutter/material.dart';
import 'model_boleto.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      // Para Android 11+ solicitar permissão especial
      var manageStatus = await Permission.manageExternalStorage.request();
      if (!manageStatus.isGranted) {
        // O usuário precisa permitir manualmente nas configurações
        await openAppSettings();
      }
    }
  }

  final List<Boleto> _boletos = [];
  final _formKey = GlobalKey<FormState>();
  DateTime? _data;
  double? _valor;
  String? _nome;
  final _nomeController = TextEditingController();
  final _valorController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    final header = ['Nome', 'Data', 'Valor'];
    final rows = _boletos
        .map(
          (b) => [
            b.nome,
            DateFormat('dd/MM/yyyy').format(b.data),
            NumberFormat.currency(
              locale: 'pt_BR',
              symbol: 'R\$',
            ).format(b.valor),
          ],
        )
        .toList();
    final csv = StringBuffer();
    csv.writeln(header.join(','));
    for (var row in rows) {
      csv.writeln(row.join(','));
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Escolha a pasta para salvar o CSV',
    );
    if (selectedDirectory == null) {
      // Usuário cancelou
      return;
    }
    String baseName = 'boletos.csv';
    String filePath = '$selectedDirectory/$baseName';
    int count = 1;
    while (await File(filePath).exists()) {
      filePath = '$selectedDirectory/boletos($count).csv';
      count++;
    }
    final file = File(filePath);
    await file.writeAsString(csv.toString());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Arquivo CSV salvo em: ${file.path}')),
    );
    // Solicita permissão de armazenamento
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissão de armazenamento negada!')),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boletos para Exportar'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do boleto',
                          ),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Informe o nome' : null,
                          onSaved: (v) => _nome = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _valorController,
                          decoration: const InputDecoration(labelText: 'Valor'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Informe o valor';
                            if (double.tryParse(v.replaceAll(',', '.')) == null)
                              return 'Valor inválido';
                            return null;
                          },
                          onSaved: (v) =>
                              _valor = double.tryParse(v!.replaceAll(',', '.')),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => _data = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data',
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _data == null
                                      ? 'Selecione'
                                      : DateFormat('dd/MM/yyyy').format(_data!),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar boleto'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              if (_formKey.currentState?.validate() ?? false) {
                                _formKey.currentState?.save();
                                if (_data != null &&
                                    _valor != null &&
                                    _nome != null) {
                                  setState(() {
                                    _boletos.add(
                                      Boleto(
                                        nome: _nome!,
                                        data: _data!,
                                        valor: _valor!,
                                      ),
                                    );
                                    _data = null;
                                    _valorController.clear();
                                    _nomeController.clear();
                                    _formKey.currentState?.reset();
                                  });
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Boletos adicionados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _boletos.isEmpty
                  ? const Center(child: Text('Nenhum boleto adicionado'))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _boletos.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final b = _boletos[i];
                        return ListTile(
                          leading: CircleAvatar(child: Text('${i + 1}')),
                          title: Text(
                            b.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Data: ${DateFormat('dd/MM/yyyy').format(b.data)}\nValor: ${NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(b.valor)}',
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_alt),
                label: const Text('Exportar CSV'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _boletos.isEmpty ? null : _exportCsv,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
