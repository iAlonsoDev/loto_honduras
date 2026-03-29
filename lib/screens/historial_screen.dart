// lib/screens/historial_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sorteo_model.dart';
import '../services/database.dart';
import '../theme/app_theme.dart';
import '../data/libro_suenos.dart';
import '../data/grupos_semanticos.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  final _db = DatabaseService.instance;
  List<SorteoModel> _sorteos = [];
  List<SorteoModel> _filtrados = [];
  bool _loading = true;
  String? _error;
  final _busquedaCtrl = TextEditingController();
  int? _numBuscado;

  @override
  void initState() {
    super.initState();
    _db.addListener(_sincronizar);
    _sincronizar();
  }

  void _sincronizar() {
    if (!mounted) return;
    final sorteos = _db.sorteos;
    setState(() {
      _loading = _db.cargando;
      _error = _db.error;
      _sorteos = sorteos;
      _filtrados = _numBuscado == null
          ? sorteos
          : sorteos.where((s) => s.numeros.contains(_numBuscado)).toList();
    });
  }

  Future<void> _refrescar() async {
    await _db.cargar(forzar: true);
  }

  void _buscar(String query) {
    final num = int.tryParse(query);
    setState(() {
      _numBuscado = num;
      if (query.isEmpty) {
        _filtrados = _sorteos;
      } else if (num != null && num >= 0 && num <= 99) {
        _filtrados = _sorteos.where((s) => s.numeros.contains(num)).toList();
      } else {
        _filtrados = [];
      }
    });
  }

  // ── Quebrado helpers ────────────────────────────────────────────────────────

  List<int> _equivalentesDigito(int d) {
    switch (d) {
      case 0: return [0, 1, 7, 4];
      case 1: return [1, 7, 4, 0];
      case 2: return [2, 5];
      case 3: return [3, 8];
      case 4: return [4, 0, 1, 7];
      case 5: return [5, 2];
      case 6: return [6, 9];
      case 7: return [7, 1, 4, 0];
      case 8: return [8, 3];
      case 9: return [9, 6];
      default: return [d];
    }
  }

  Set<int> _todosQuebradosDe(int numero) {
    final result = <int>{};
    final a = numero ~/ 10;
    final b = numero % 10;
    final suma = a + b;
    final sa = suma ~/ 10;
    final sb = suma % 10;
    final eqA = _equivalentesDigito(sa);
    // 010 rule: when sum ends in 0 (e.g. 6+4=10) → trailing 0 merges families A+C
    final eqB = (sb == 0 && sa > 0) ? const [0, 1, 7, 4, 8, 3] : _equivalentesDigito(sb);
    for (final da in eqA) {
      for (final db in eqB) {
        final n = da * 10 + db;
        if (n >= 0 && n <= 99) { result.add(n); }
      }
    }
    // directo: equivalences on raw digits
    final eqRa = _equivalentesDigito(a);
    final eqRb = _equivalentesDigito(b);
    for (final da in eqRa) {
      for (final db in eqRb) {
        final n = da * 10 + db;
        if (n >= 0 && n <= 99) { result.add(n); }
      }
    }
    result.remove(numero);
    return result;
  }

  bool _esQuebraDo(int origen, int candidato) {
    return _todosQuebradosDe(origen).contains(candidato);
  }

  // Returns true if any number in sorteoB is a quebrado of any number in sorteoA
  String? _relacionQuebrado(SorteoModel sorteoA, SorteoModel sorteoB) {
    final numsA = [sorteoA.numeroManiana, sorteoA.numeroTarde, sorteoA.numeroNoche]
        .whereType<int>().toList();
    final numsB = [sorteoB.numeroManiana, sorteoB.numeroTarde, sorteoB.numeroNoche]
        .whereType<int>().toList();
    for (final a in numsA) {
      for (final b in numsB) {
        if (_esQuebraDo(a, b)) {
          return '${a.toString().padLeft(2,'0')}→${b.toString().padLeft(2,'0')}';
        }
      }
    }
    return null;
  }

  // Check if any numbers share a semantic group across/within sorteos
  String? _relacionSemantica(SorteoModel sorteoA, SorteoModel sorteoB) {
    final numsA = [sorteoA.numeroManiana, sorteoA.numeroTarde, sorteoA.numeroNoche]
        .whereType<int>().toList();
    final numsB = [sorteoB.numeroManiana, sorteoB.numeroTarde, sorteoB.numeroNoche]
        .whereType<int>().toList();
    for (final a in numsA) {
      final grupoA = grupoDeNumero(a);
      if (grupoA == null) { continue; }
      for (final b in numsB) {
        if (b != a && grupoDeNumero(b) == grupoA) {
          return grupoA;
        }
      }
    }
    return null;
  }

  // Check reverse pairs between sorteos
  String? _relacionReves(SorteoModel sorteoA, SorteoModel sorteoB) {
    final numsA = [sorteoA.numeroManiana, sorteoA.numeroTarde, sorteoA.numeroNoche]
        .whereType<int>().toList();
    final numsB = [sorteoB.numeroManiana, sorteoB.numeroTarde, sorteoB.numeroNoche]
        .whereType<int>().toList();
    for (final a in numsA) {
      final reves = (a % 10) * 10 + (a ~/ 10);
      if (reves != a && numsB.contains(reves)) {
        return '${a.toString().padLeft(2,'0')}↔${reves.toString().padLeft(2,'0')}';
      }
    }
    return null;
  }

  Future<void> _confirmarEliminar(SorteoModel sorteo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('¿Eliminar sorteo?'),
        content: Text(
          'Se eliminará el registro del ${DateFormat('d MMM yyyy', 'es').format(sorteo.fecha)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.eliminarSorteo(sorteo.fechaKey);
      // listener _sincronizar se encarga del re-render
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Historial'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refrescar),
        ],
      ),
      body: Column(
        children: [
          // Buscador por número
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: _buscar,
              keyboardType: TextInputType.number,
              maxLength: 2,
              decoration: InputDecoration(
                hintText: 'Buscar número (00-99)...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.goldColor),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _busquedaCtrl.clear();
                          _buscar('');
                        },
                      )
                    : null,
                counterText: '',
              ),
            ),
          ),

          // Resultado de búsqueda
          if (_numBuscado != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.2),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppTheme.goldColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'El número ${_numBuscado!.toString().padLeft(2, '0')} ha salido ${_filtrados.length} veces',
                    style: const TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // Lista
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.goldColor),
                  )
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Error al cargar datos:',
                            style: TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _refrescar,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filtrados.isEmpty
                ? const Center(
                    child: Text(
                      'No hay registros',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtrados.length,
                    itemBuilder: (ctx, i) => _buildSorteoCard(
                      _filtrados[i],
                      prevSorteo: i + 1 < _filtrados.length ? _filtrados[i + 1] : null,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSorteoCard(SorteoModel sorteo, {SorteoModel? prevSorteo}) {
    final fecha = DateFormat('EEEE d MMMM yyyy', 'es').format(sorteo.fecha);
    final esHoy =
        DateFormat('yyyy-MM-dd').format(sorteo.fecha) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    final puntoManiana = sorteo.numeroManiana != null ? (sorteo.numeroManiana! ~/ 10 + sorteo.numeroManiana! % 10) : null;
    final puntoTarde = sorteo.numeroTarde != null ? (sorteo.numeroTarde! ~/ 10 + sorteo.numeroTarde! % 10) : null;
    final puntoNoche = sorteo.numeroNoche != null ? (sorteo.numeroNoche! ~/ 10 + sorteo.numeroNoche! % 10) : null;

    return Dismissible(
      key: Key(sorteo.fechaKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _confirmarEliminar(sorteo);
        return false;
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (esHoy)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HOY',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (esHoy) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fecha,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 18,
                    ),
                    onPressed: () => _confirmarEliminar(sorteo),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNumBadge(
                    '🌅 Mañana',
                    sorteo.numeroManiana,
                    AppTheme.goldColor,
                    _numBuscado,
                  ),
                  _buildNumBadge(
                    '☀️ Tarde',
                    sorteo.numeroTarde,
                    AppTheme.orangeColor,
                    _numBuscado,
                  ),
                  _buildNumBadge(
                    '🌙 Noche',
                    sorteo.numeroNoche,
                    Colors.purple,
                    _numBuscado,
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNumBadgePunto(
                    '🔢 Suma',
                    puntoManiana,
                    AppTheme.greenColor,
                  ),
                  _buildNumBadgePunto(
                    '🔢 Suma',
                    puntoTarde,
                    AppTheme.orangeColor,
                  ),
                  _buildNumBadgePunto(
                    '🔢 Suma',
                    puntoNoche,
                    Colors.purple,
                  ),
                ],
              ),
              
              // ── Relación con el sorteo anterior ──────────────────────────
              if (prevSorteo != null) ...[
                const SizedBox(height: 8),
                _buildRelacionBar(sorteo, prevSorteo),
              ],

              if (sorteo.notas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '📝 ${sorteo.notas}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelacionBar(SorteoModel actual, SorteoModel prev) {
    final qRel = _relacionQuebrado(prev, actual);
    final sRel = _relacionSemantica(prev, actual);
    final rRel = _relacionReves(prev, actual);

    if (qRel == null && sRel == null && rRel == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (qRel != null)
            _buildRelChip(
              icon: Icons.link,
              color: AppTheme.goldColor,
              label: '🔗 Quebrado: $qRel',
            ),
          if (rRel != null)
            _buildRelChip(
              icon: Icons.swap_horiz,
              color: AppTheme.orangeColor,
              label: '↔ Revés: $rRel',
            ),
          if (sRel != null)
            _buildRelChip(
              icon: Icons.category_outlined,
              color: Colors.teal,
              label: '🎭 $sRel',
            ),
        ],
      ),
    );
  }

  Widget _buildRelChip({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNumBadge(String label, int? numero, Color color, int? buscado) {
    if (numero == null) {
      return Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey, width: 1),
            ),
            child: const Center(
              child: Text(
                '--',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final highlighted = buscado != null && buscado == numero;
    final sig = significadoCorto(numero);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: highlighted ? AppTheme.accentColor : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted ? AppTheme.accentColor : color,
              width: highlighted ? 3 : 1,
            ),
          ),
          child: Center(
            child: Text(
              numero.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: highlighted ? Colors.white : color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 60,
          child: Text(
            sig,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildNumBadgePunto(String label, int? numero, Color color) {
    if (numero == null) {
      return Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey, width: 1),
            ),
            child: const Center(
              child: Text(
                '--',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final sig = significadoCorto(numero);
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
            ),
          ),
          child: Center(
            child: Text(
              numero.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 60,
          child: Text(
            sig,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }


  @override
  void dispose() {
    _db.removeListener(_sincronizar);
    _busquedaCtrl.dispose();
    super.dispose();
  }
}
