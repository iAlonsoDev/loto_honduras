// lib/widgets/libro_suenos_sheet.dart

import 'package:flutter/material.dart';
import '../data/libro_suenos.dart';
import '../theme/app_theme.dart';

/// Abre el bottom sheet del libro de sueños.
/// Devuelve el número seleccionado o null si se cierra sin selección.
Future<int?> mostrarLibroSuenos(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.bgDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _LibroSuenosSheet(),
  );
}

class _LibroSuenosSheet extends StatefulWidget {
  const _LibroSuenosSheet();

  @override
  State<_LibroSuenosSheet> createState() => _LibroSuenosSheetState();
}

class _LibroSuenosSheetState extends State<_LibroSuenosSheet> {
  final _searchCtrl = TextEditingController();
  List<MapEntry<int, String>> _resultados = libroSuenos.entries.toList();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _resultados = buscarEnLibro(_searchCtrl.text));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.of(context).size.height * 0.85;

    return SizedBox(
      height: alto,
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('🔮', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Libro de Sueños',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldColor,
                        ),
                      ),
                      Text(
                        'Escribe tu sueño para encontrar el número',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ej: carro, serpiente, boda...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.goldColor),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Contador de resultados
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_resultados.length} resultado${_resultados.length != 1 ? 's' : ''}',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ),

          // Lista de resultados
          Expanded(
            child: _resultados.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('😔', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 8),
                        Text(
                          'No se encontró ese sueño',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: _resultados.length,
                    itemBuilder: (ctx, i) {
                      final entry = _resultados[i];
                      return _ResultadoTile(
                        numero: entry.key,
                        significado: entry.value,
                        onSelect: () => Navigator.pop(context, entry.key),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultadoTile extends StatelessWidget {
  final int numero;
  final String significado;
  final VoidCallback onSelect;

  const _ResultadoTile({
    required this.numero,
    required this.significado,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onSelect,
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              numero.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Text(
          significado,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.goldColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.goldColor.withValues(alpha: 0.4),
            ),
          ),
          child: const Text(
            'Usar',
            style: TextStyle(
              color: AppTheme.goldColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
