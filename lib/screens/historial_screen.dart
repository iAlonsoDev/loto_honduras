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
  int? _decenaFiltro;
  String? _grupoFiltro;
  int? _sumaFiltro;

  // Análisis por rango de días del mes
  bool _analisisDiaExpanded = false;
  int  _diaDesde = (DateTime.now().day - 2).clamp(1, 28);
  int  _diaHasta = (DateTime.now().day + 2).clamp(1, 31);

  @override
  void initState() {
    super.initState();
    _db.addListener(_sincronizar);
    _sincronizar();
  }

  void _sincronizar() {
    if (!mounted) return;
    setState(() {
      _loading = _db.cargando;
      _error = _db.error;
      _sorteos = _db.sorteos;
    });
    _aplicarFiltros();
  }

  //Future<void> _refrescar() async => _db.cargar(forzar: true);

  void _buscar(String query) {
    _numBuscado = int.tryParse(query);
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    var lista = _sorteos;
    if (_numBuscado != null && _numBuscado! >= 0 && _numBuscado! <= 99) {
      lista = lista.where((s) => s.numeros.contains(_numBuscado)).toList();
    } else if (_busquedaCtrl.text.isNotEmpty && _numBuscado == null) {
      lista = [];
    }
    if (_decenaFiltro != null) {
      lista = lista.where((s) =>
        s.numeros.whereType<int>().any((n) => n ~/ 10 == _decenaFiltro)
      ).toList();
    }
    if (_grupoFiltro != null) {
      lista = lista.where((s) =>
        s.numeros.whereType<int>().any((n) => _enGrupo(n, _grupoFiltro!))
      ).toList();
    }
    if (_sumaFiltro != null) {
      lista = lista.where((s) =>
        s.numeros.whereType<int>().any((n) => n ~/ 10 + n % 10 == _sumaFiltro)
      ).toList();
    }
    setState(() => _filtrados = lista);
  }

  bool _enGrupo(int numero, String grupo) {
    // Membresía directa (el número aparece en la lista del grupo)
    final miembros = gruposSemanticos[grupo] ?? [];
    if (miembros.contains(numero)) return true;
    // Membresía por punto: 83 → 8+3=11=Perro → Animales
    final punto = numero ~/ 10 + numero % 10;
    if (miembros.contains(punto)) return true;
    // Segundo nivel: punto del punto (ej: 99 → 18 → 1+8=9 → si 9 está en grupo)
    final punto2 = punto ~/ 10 + punto % 10;
    return miembros.contains(punto2);
  }

  int _contarGrupo(String grupo) =>
      _sorteos.where((s) =>
        s.numeros.whereType<int>().any((n) => _enGrupo(n, grupo))
      ).length;

  bool get _hayFiltros =>
      _decenaFiltro != null || _grupoFiltro != null || _sumaFiltro != null;

  int get _contFiltros =>
      (_decenaFiltro != null ? 1 : 0) +
      (_grupoFiltro != null ? 1 : 0) +
      (_sumaFiltro != null ? 1 : 0);

  void _limpiarFiltros() {
    setState(() {
      _decenaFiltro = null;
      _grupoFiltro  = null;
      _sumaFiltro   = null;
    });
    _aplicarFiltros();
  }

  // ── Quebrado helpers ────────────────────────────────────────────────────────
  // Tabla estándar Honduras: cada dígito tiene su equivalente directo.
  // Grupo 0-1-4-7 (intercambiables entre sí)
  // Grupo 2-5 · Grupo 3-8 · Grupo 6-9

  static const Map<int, List<int>> _eqDigito = {
    0: [1, 4, 7],
    1: [0, 4, 7],
    2: [5],
    3: [8],
    4: [0, 1, 7],
    5: [2],
    6: [9],
    7: [0, 1, 4],
    8: [3],
    9: [6],
  };

  /// Devuelve todos los quebrados de [numero] aplicando equivalencias
  /// solo sobre sus dígitos directos (no sobre la suma).
  Set<int> _todosQuebradosDe(int numero) {
    final result = <int>{};
    final a = numero ~/ 10;
    final b = numero % 10;
    // Equivalentes del dígito de las decenas (incluye el original)
    final eqA = [a, ...(_eqDigito[a] ?? [])];
    // Equivalentes del dígito de las unidades (incluye el original)
    final eqB = [b, ...(_eqDigito[b] ?? [])];
    for (final da in eqA) {
      for (final db in eqB) {
        final n = da * 10 + db;
        if (n >= 0 && n <= 99) result.add(n);
      }
    }
    result.remove(numero); // excluir el número mismo
    return result;
  }

  bool _esQuebraDo(int origen, int candidato) =>
      _todosQuebradosDe(origen).contains(candidato);

  String? _relacionQuebrado(SorteoModel a, SorteoModel b) {
    final numsA = [a.numeroManiana, a.numeroTarde, a.numeroNoche].whereType<int>().toList();
    final numsB = [b.numeroManiana, b.numeroTarde, b.numeroNoche].whereType<int>().toList();
    for (final x in numsA) {
      for (final y in numsB) {
        if (_esQuebraDo(x, y)) return '${x.toString().padLeft(2,'0')}→${y.toString().padLeft(2,'0')}';
      }
    }
    return null;
  }

  // ── Grupo semántico con fallback por punto ──────────────────────────────────
  // grupoDeNumero() solo busca membresía directa (ej: 11=Perro en Animales).
  // Esta versión también busca por suma de dígitos: 83 → 8+3=11 → Animales.
  String? _grupoDeNumeroExt(int numero) {
    final directo = grupoDeNumero(numero);
    if (directo != null) return directo;
    final punto = numero ~/ 10 + numero % 10;
    return grupoDeNumero(punto);
  }

  String? _relacionSemantica(SorteoModel a, SorteoModel b) {
    final numsA = [a.numeroManiana, a.numeroTarde, a.numeroNoche].whereType<int>().toList();
    final numsB = [b.numeroManiana, b.numeroTarde, b.numeroNoche].whereType<int>().toList();
    for (final x in numsA) {
      final gx = _grupoDeNumeroExt(x);
      if (gx == null) continue;
      for (final y in numsB) {
        if (y != x && _grupoDeNumeroExt(y) == gx) return gx;
      }
    }
    return null;
  }

  String? _relacionReves(SorteoModel a, SorteoModel b) {
    final numsA = [a.numeroManiana, a.numeroTarde, a.numeroNoche].whereType<int>().toList();
    final numsB = [b.numeroManiana, b.numeroTarde, b.numeroNoche].whereType<int>().toList();
    for (final x in numsA) {
      final r = (x % 10) * 10 + (x ~/ 10);
      if (r != x && numsB.contains(r)) {
        return '${x.toString().padLeft(2,'0')}↔${r.toString().padLeft(2,'0')}';
      }
    }
    return null;
  }

  
  // ── Análisis por rango de días del mes ─────────────────────────────────────

  /// Calcula la fecha de inicio para [ultMeses] meses calendario atrás.
  /// Ej: si hoy es abril 2026 y ultMeses=3 → inicio = enero 2026 (día 1).
  DateTime _inicioMeses(int ultMeses) {
    final ahora = DateTime.now();
    int mes = ahora.month - ultMeses;
    int anio = ahora.year;
    while (mes <= 0) { mes += 12; anio--; }
    return DateTime(anio, mes, 1);
  }

  /// Frecuencia de cada punto (suma de dígitos) en sorteos cuyo día del mes
  /// cae dentro del rango [desde..hasta], limitado a los últimos [ultMeses]
  /// meses calendario (null = todo el historial).
  Map<int, int> _puntosEnRango(int desde, int hasta, {int? ultMeses}) {
    final inicio = ultMeses != null ? _inicioMeses(ultMeses) : null;
    final conteo = <int, int>{};
    for (final s in _sorteos) {
      final d = s.fecha.day;
      if (d < desde || d > hasta) continue;
      if (inicio != null && s.fecha.isBefore(inicio)) continue;
      for (final n in s.numeros.whereType<int>()) {
        final p = n ~/ 10 + n % 10;
        conteo[p] = (conteo[p] ?? 0) + 1;
      }
    }
    return conteo;
  }

  /// Frecuencia de cada número concreto cuyo punto coincide con [punto],
  /// en sorteos del rango [desde..hasta], con ventana de [ultMeses] meses.
  Map<int, int> _numerosDeUnPuntoEnRango(int desde, int hasta, int punto,
      {int? ultMeses}) {
    final inicio = ultMeses != null ? _inicioMeses(ultMeses) : null;
    final conteo = <int, int>{};
    for (final s in _sorteos) {
      final d = s.fecha.day;
      if (d < desde || d > hasta) continue;
      if (inicio != null && s.fecha.isBefore(inicio)) continue;
      for (final n in s.numeros.whereType<int>()) {
        if (n ~/ 10 + n % 10 == punto) conteo[n] = (conteo[n] ?? 0) + 1;
      }
    }
    return conteo;
  }

  /// Top-[n] entradas de un mapa de conteo, ordenadas de mayor a menor.
  List<MapEntry<int, int>> _topEntradas(Map<int, int> conteo, {int n = 5}) {
    final lista = conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return lista.take(n).toList();
  }

  Widget _buildAnalisisDia() {
    if (_sorteos.isEmpty) return const SizedBox.shrink();

    final totalSorteos = _sorteos
        .where((s) => s.fecha.day >= _diaDesde && s.fecha.day <= _diaHasta)
        .length;

    // Períodos a mostrar como columnas
    final periodos = [
      (label: '3M',   meses: 3    as int?),
      (label: '6M',   meses: 6    as int?),
      (label: '1A',   meses: 12   as int?),
      (label: 'Todo', meses: null as int?),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header (tap para expandir) ───────────────────────────────────
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _analisisDiaExpanded = !_analisisDiaExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: AppTheme.goldColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Patrones días $_diaDesde–$_diaHasta',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '($totalSorteos sorteos)',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const Spacer(),
                  Icon(
                    _analisisDiaExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido expandido ──────────────────────────────────────────
          if (_analisisDiaExpanded) ...[
            const Divider(height: 1, color: AppTheme.cardBorder),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Selectores de rango ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _diaBtn(Icons.chevron_left_rounded, () {
                        setState(() =>
                            _diaDesde = (_diaDesde - 1).clamp(1, _diaHasta));
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Día $_diaDesde',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      _diaBtn(Icons.chevron_right_rounded, () {
                        setState(() =>
                            _diaDesde = (_diaDesde + 1).clamp(1, _diaHasta));
                      }),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('→',
                            style: TextStyle(
                                fontSize: 16, color: AppTheme.textSecondary)),
                      ),

                      _diaBtn(Icons.chevron_left_rounded, () {
                        setState(() =>
                            _diaHasta = (_diaHasta - 1).clamp(_diaDesde, 31));
                      }),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.goldColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.goldColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Día $_diaHasta',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      _diaBtn(Icons.chevron_right_rounded, () {
                        setState(() =>
                            _diaHasta = (_diaHasta + 1).clamp(_diaDesde, 31));
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Columnas por período ─────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: periodos.map((p) {
                      final conteo =
                          _puntosEnRango(_diaDesde, _diaHasta, ultMeses: p.meses);
                      final top = _topEntradas(conteo, n: 3);
                      return Expanded(
                        child: _buildPeriodoCol(
                          label: p.label,
                          top: top,
                          ultMeses: p.meses,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toca un punto para filtrar la lista',
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodoCol({
    required String label,
    required List<MapEntry<int, int>> top,
    required int? ultMeses,
  }) {
    return Column(
      children: [
        // Encabezado del período
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (top.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('—', style: TextStyle(fontSize: 11, color: Colors.grey)),
          )
        else
          ...top.map((e) {
            final punto   = e.key;
            final veces   = e.value;
            final sig     = significadoCorto(punto);
            final nums    = _numerosDeUnPuntoEnRango(
                _diaDesde, _diaHasta, punto, ultMeses: ultMeses);
            final topNums = (nums.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3)
                .map((e) => e.key.toString().padLeft(2, '0'))
                .join(' ');

            return GestureDetector(
              onTap: () {
                setState(() {
                  _sumaFiltro = punto;
                  _analisisDiaExpanded = false;
                });
                _aplicarFiltros();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.goldColor.withOpacity(0.35)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '=${punto.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$veces×',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.goldColor.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      sig,
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (topNums.isNotEmpty)
                      Text(
                        topNums,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color.fromARGB(255, 37, 38, 41),
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _diaBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
      );

  // ── Abrir bottom sheet de filtros ──────────────────────────────────────────
  void _abrirFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void applyAndClose() {
            _aplicarFiltros();
            Navigator.pop(ctx);
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                  child: Row(
                    children: [
                      const Text('Filtros',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      if (_hayFiltros)
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _decenaFiltro = null;
                              _grupoFiltro  = null;
                              _sumaFiltro   = null;
                            });
                            applyAndClose();
                          },
                          child: const Text('Limpiar todo',
                              style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.cardBorder),
                // Contenido scrollable
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      // ── Sección Dígito ─────────────────────────────────
                      _sheetSectionTitle('Dígito inicial', Icons.filter_1_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(10, (d) {
                          final sel = _decenaFiltro == d;
                          final count = _sorteos.where((s) =>
                            s.numeros.whereType<int>().any((n) => n ~/ 10 == d)
                          ).length;
                          return _sheetChip(
                            label: '${d}x · $count',
                            selected: sel,
                            color: AppTheme.goldColor,
                            onTap: () => setSheetState(() {
                              _decenaFiltro = sel ? null : d;
                              applyAndClose();
                            }),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),

                      // ── Sección Grupo ──────────────────────────────────
                      _sheetSectionTitle('Grupo semántico', Icons.category_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: gruposSemanticos.keys.map((grupo) {
                          final sel = _grupoFiltro == grupo;
                          final count = _contarGrupo(grupo);
                          return _sheetChip(
                            label: '$grupo  $count',
                            selected: sel,
                            color: AppTheme.accentColor,
                            onTap: () => setSheetState(() {
                              _grupoFiltro = sel ? null : grupo;
                              applyAndClose();
                            }),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // ── Sección Suma ───────────────────────────────────
                      _sheetSectionTitle('Suma de dígitos (punto)', Icons.calculate_rounded),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: List.generate(19, (s) {
                          final sel = _sumaFiltro == s;
                          final sig = significadoCorto(s);
                          final count = _sorteos.where((so) =>
                            so.numeros.whereType<int>().any((n) => n ~/ 10 + n % 10 == s)
                          ).length;
                          return _sheetChip(
                            label: '${s.toString().padLeft(2, '0')} $sig · $count',
                            selected: sel,
                            color: Colors.teal,
                            onTap: () => setSheetState(() {
                              _sumaFiltro = sel ? null : s;
                              applyAndClose();
                            }),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sheetSectionTitle(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 14, color: AppTheme.textSecondary),
      const SizedBox(width: 6),
      Text(title,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.4)),
    ],
  );

  Widget _sheetChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppTheme.bgLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : AppTheme.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? color : AppTheme.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      );

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hayBusqueda = _numBuscado != null;
    final hayAlgunFiltro = hayBusqueda || _hayFiltros;

    return Scaffold(
      appBar: AppBar(
        //title: const Text('📋 Historial'),
      ),
      body: Column(
        children: [
          // ── Buscador + botón filtros ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _busquedaCtrl,
                    onChanged: _buscar,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: InputDecoration(
                      hintText: 'Buscar número (00–99)...',
                      prefixIcon:
                          const Icon(Icons.search, color: AppTheme.goldColor),
                      suffixIcon: _busquedaCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
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
                const SizedBox(width: 8),
                // Botón filtros con badge
                Stack(
                  children: [
                    InkWell(
                      onTap: _abrirFiltros,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: _hayFiltros
                              ? AppTheme.primaryColor.withOpacity(0.12)
                              : AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hayFiltros
                                ? AppTheme.primaryColor
                                : AppTheme.cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: _hayFiltros
                                  ? AppTheme.primaryColor
                                  : AppTheme.textSecondary,
                            ),
                            if (_hayFiltros) ...[
                              const SizedBox(width: 4),
                              Text(
                                '$_contFiltros',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Chips de filtros activos ───────────────────────────────────
          if (_hayFiltros)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_decenaFiltro != null)
                            _activeFiltroChip(
                              label: 'Dígito ${_decenaFiltro}x',
                              color: AppTheme.goldColor,
                              onRemove: () {
                                setState(() => _decenaFiltro = null);
                                _aplicarFiltros();
                              },
                            ),
                          if (_grupoFiltro != null)
                            _activeFiltroChip(
                              label: _grupoFiltro!,
                              color: AppTheme.accentColor,
                              onRemove: () {
                                setState(() => _grupoFiltro = null);
                                _aplicarFiltros();
                              },
                            ),
                          if (_sumaFiltro != null)
                            _activeFiltroChip(
                              label:
                                  '=${_sumaFiltro.toString().padLeft(2, '0')} ${significadoCorto(_sumaFiltro!)}',
                              color: Colors.teal,
                              onTap: () => _abrirDetalleSuma(_sumaFiltro!),
                              onRemove: () {
                                setState(() => _sumaFiltro = null);
                                _aplicarFiltros();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_hayFiltros)
                    GestureDetector(
                      onTap: _limpiarFiltros,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Text('Limpiar',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),

          // ── Análisis del día ──────────────────────────────────────────
          _buildAnalisisDia(),
          const SizedBox(height: 4),

          // ── Banner resultado ───────────────────────────────────────────
          if (hayAlgunFiltro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppTheme.goldColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _numBuscado != null
                          ? 'El ${_numBuscado!.toString().padLeft(2, '0')} salió ${_filtrados.length} veces'
                          : _sumaFiltro != null
                              ? '=${_sumaFiltro.toString().padLeft(2,'0')} ${significadoCorto(_sumaFiltro!)}: ${_filtrados.length} días'
                              : _decenaFiltro != null
                                  ? 'Dígito ${_decenaFiltro}x: ${_filtrados.length} días'
                                  : '$_grupoFiltro: ${_filtrados.length} días',
                      style: const TextStyle(
                          color: AppTheme.goldColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // (detalle de suma se abre como sheet al tocar el chip activo)

          // ── Lista ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.goldColor))
                : _error != null
                    ? _buildError()
                    : _filtrados.isEmpty
                        ? const Center(
                            child: Text('No hay registros',
                                style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            itemCount: _filtrados.length,
                            itemBuilder: (ctx, i) => _buildSorteoCard(
                              _filtrados[i],
                              prevSorteo: i + 1 < _filtrados.length
                                  ? _filtrados[i + 1]
                                  : null,
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _activeFiltroChip({
    required String label,
    required Color color,
    required VoidCallback onRemove,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.bar_chart_rounded, size: 12, color: color),
                ),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded, size: 14, color: color),
              ),
            ],
          ),
        ),
      );

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          const Text('Error al cargar datos:',
              style: TextStyle(color: Colors.red)),
          const SizedBox(height: 4),
          Text(_error!,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildSorteoCard(SorteoModel sorteo, {SorteoModel? prevSorteo}) {
    final fecha = DateFormat('EEE d MMM yyyy', 'es').format(sorteo.fecha);
    final esHoy = sorteo.fecha.year == DateTime.now().year &&
        sorteo.fecha.month == DateTime.now().month &&
        sorteo.fecha.day == DateTime.now().day;

    return Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: esHoy
                ? AppTheme.goldColor.withOpacity(0.5)
                : AppTheme.cardBorder,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (esHoy)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('HOY',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  Expanded(
                    child: Text(fecha,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: esHoy
                              ? AppTheme.goldColor
                              : AppTheme.textSecondary,
                        )),
                  ),
                  
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildSlot('🌅', sorteo.numeroManiana, AppTheme.goldColor),
                  const SizedBox(width: 8),
                  _buildSlot('☀️', sorteo.numeroTarde, AppTheme.orangeColor),
                  const SizedBox(width: 8),
                  _buildSlot('🌙', sorteo.numeroNoche, AppTheme.primaryColor),
                ],
              ),
              if (prevSorteo != null) ...[
                const SizedBox(height: 6),
                _buildRelacionBar(sorteo, prevSorteo),
              ],
              if (sorteo.notas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('📝 ${sorteo.notas}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                ),
            ],
          ),
        ),
      );
  }

  Widget _buildSlot(String emoji, int? numero, Color color) {
    final hayFiltroNum   = _numBuscado != null;
    final hayFiltroSuma  = _sumaFiltro != null;
    final hayFiltroGrupo = _grupoFiltro != null;
    final hayFiltroDecena = _decenaFiltro != null;

    if (numero == null) {
      return Expanded(
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text('$emoji --',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ),
      );
    }

    final suma = numero ~/ 10 + numero % 10;
    final sig  = significadoCorto(numero);
    final matchNum    = !hayFiltroNum    || numero == _numBuscado;
    final matchSuma   = !hayFiltroSuma   || suma == _sumaFiltro;
    final matchGrupo  = !hayFiltroGrupo  || _enGrupo(numero, _grupoFiltro!);
    final matchDecena = !hayFiltroDecena || numero ~/ 10 == _decenaFiltro;
    final hayFiltro   = hayFiltroNum || hayFiltroSuma || hayFiltroGrupo || hayFiltroDecena;
    final match       = matchNum && matchSuma && matchGrupo && matchDecena;
    final sumaResaltada = hayFiltroSuma && matchSuma;
    final activeColor = match ? color : Colors.grey.withOpacity(0.3);
    final opacity     = (hayFiltro && !match) ? 0.3 : 1.0;

    return Expanded(
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: match ? color.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                numero.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: sumaResaltada
                            ? Colors.teal.withOpacity(0.25)
                            : AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '=${suma.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: sumaResaltada ? Colors.teal : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$emoji $sig',
                      style: TextStyle(
                        fontSize: 9,
                        color: match
                            ? activeColor.withOpacity(0.8)
                            : Colors.grey.withOpacity(0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
    if (qRel == null && sRel == null && rRel == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (qRel != null)
            _buildRelChip(color: AppTheme.goldColor, label: '🔗 Quebrado: $qRel'),
          if (rRel != null)
            _buildRelChip(color: AppTheme.orangeColor, label: '↔ Revés: $rRel'),
          if (sRel != null)
            _buildRelChip(color: Colors.teal, label: '🎭 $sRel'),
        ],
      ),
    );
  }

  Widget _buildRelChip({required Color color, required String label}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4), width: 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _buildSubseleccionSuma(int suma) {
    final conteo = <int, int>{};
    for (final s in _sorteos) {
      for (final n in [s.numeroManiana, s.numeroTarde, s.numeroNoche]
          .whereType<int>()) {
        if (n ~/ 10 + n % 10 == suma) conteo[n] = (conteo[n] ?? 0) + 1;
      }
    }
    if (conteo.isEmpty) return const SizedBox.shrink();

    final ordenados = conteo.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = ordenados.first.value;
    final sig = significadoCorto(suma);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '=${suma.toString().padLeft(2, '0')}  $sig',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
              ),
              const SizedBox(width: 8),
              Text('${conteo.length} números · ${_filtrados.length} días',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ordenados.map((e) {
              final pct = e.value / maxCount;
              final numSig = significadoCorto(e.key);
              final esPrimero = e.key == ordenados.first.key;
              return GestureDetector(
                onTap: () {
                  _busquedaCtrl.text = e.key.toString().padLeft(2, '0');
                  _numBuscado = e.key;
                  _aplicarFiltros();
                },
                child: Container(
                  width: 64,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: esPrimero
                        ? Colors.teal.withOpacity(0.2)
                        : Colors.teal.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      if (esPrimero)
                        const Text('★',
                            style: TextStyle(
                                fontSize: 9, color: Colors.teal)),
                      Text(
                        e.key.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              Color.lerp(Colors.grey, Colors.teal, pct)!,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 3,
                          backgroundColor:
                              Colors.teal.withOpacity(0.1),
                          color: Colors.teal.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('${e.value}x',
                          style: const TextStyle(
                              fontSize: 9, color: Colors.teal)),
                      Text(numSig,
                          style: const TextStyle(
                              fontSize: 8, color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Text('Toca un número para filtrarlo',
              style: TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  void _abrirDetalleSuma(int suma) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _buildSubseleccionSuma(suma),
    );
  }

  @override
  void dispose() {
    _db.removeListener(_sincronizar);
    _busquedaCtrl.dispose();
    super.dispose();
  }
}
