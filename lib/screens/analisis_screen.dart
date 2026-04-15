// lib/screens/analisis_screen.dart

import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sorteo_model.dart';
import '../services/database.dart';
import '../theme/app_theme.dart';
import '../data/libro_suenos.dart';


class AnalisisScreen extends StatefulWidget {
  const AnalisisScreen({super.key});
  @override
  State<AnalisisScreen> createState() => _AnalisisScreenState();
}

class _AnalisisScreenState extends State<AnalisisScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService.instance;

  // Datos cargados
  List<SorteoModel> _sorteos = [];

  Map<int, EstadisticaNumero>? _allStats;
  bool _loading = true;
  String? _error;

  // Derivados
  Map<int, Map<String, int>> _porHorario = {};
  Map<int, int> _totalPorDia = {};
  Map<int, List<MapEntry<int, int>>> _frecPorDia = {};

  // Búsqueda global
  final String _searchGlobal = '';
  late TextEditingController _searchController;



  // Tab Pares
  int? _paresNumBuscado;
  String _paresPeriodo = 'historico';
  late TextEditingController _paresCtrl;

  // Ciclos (Max ausencia tracking)
  Map<int, int> _ciclosMax = {}; // max days without appearing per number
  Map<int, int> _ciclosActuales = {}; // current days without appearing

  // Patrones
  int _puntoMapa = 9; // punto activo en el mapa de afinidad
  Map<int, Map<int, int>> _coOcurrenciaPuntos = {}; // puntoA → puntoB → días juntos
  Map<int, int> _diasPorPunto = {};                 // punto → total días que apareció
  Map<int, Map<int, int>> _siguienteDiaPunto = {};  // puntoHoy → {puntoManiana: count}
  List<({DateTime fecha, int punto, int veces})> _diasConcentrados = [];

  late TabController _tabController;

  static const _diasNombre = [
    '',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _paresCtrl = TextEditingController();
    _tabController = TabController(length: 6, vsync: this);
    _db.addListener(_sincronizar);
    _sincronizar();
  }

  @override
  void dispose() {
    _db.removeListener(_sincronizar);
    _tabController.dispose();
    _searchController.dispose();
    _paresCtrl.dispose();
    super.dispose();
  }

  // ── CARGA ────────────────────────────────────────────────────────────────────

  void _sincronizar() {
    if (!mounted) return;
    if (_db.cargando) {
      setState(() { _loading = true; _error = null; });
      return;
    }
    if (_db.error != null) {
      setState(() { _loading = false; _error = _db.error; });
      return;
    }
    _procesarSorteos(_db.sorteos);
  }

  Future<void> _cargar() => _db.cargar(forzar: true);

  void _procesarSorteos(List<SorteoModel> sorteos) {
    final allStats = _computeStats(sorteos);

    final porHorario     = _computePorHorario(sorteos);
    if (mounted) {
      setState(() {
        _sorteos = sorteos;
        _allStats = allStats;
        _porHorario = porHorario;
        _totalPorDia = _computeTotalPorDia(sorteos);
        _frecPorDia = _computeFrecPorDia(sorteos);
        _ciclosMax = _computeCiclosMax(allStats);
        _ciclosActuales = _computeCiclosActuales(allStats);
        _coOcurrenciaPuntos = _computeCoOcurrenciaPuntos(sorteos);
        _diasPorPunto       = _computeDiasPorPunto(sorteos);
        _siguienteDiaPunto  = _computeSiguienteDiaPunto(sorteos);
        _diasConcentrados   = _computeDiasConcentrados(sorteos);
        _loading = false;
      });
    }
  }

  // ── CÓMPUTOS ─────────────────────────────────────────────────────────────────

  Map<int, EstadisticaNumero> _computeStats(List<SorteoModel> sorteos) {
    final stats = {
      for (int i = 0; i <= 99; i++) i: EstadisticaNumero(numero: i),
    };
    void proc(int? num, DateTime fecha) {
      if (num == null || num < 0 || num > 99) {
        return;
      }
      stats[num]!.frecuencia++;
      stats[num]!.apariciones.add(fecha);
      if (stats[num]!.ultimaVez == null ||
          fecha.isAfter(stats[num]!.ultimaVez!)) {
        stats[num]!.ultimaVez = fecha;
      }
    }

    for (final s in sorteos) {
      proc(s.numeroManiana, s.fecha);
      proc(s.numeroTarde, s.fecha);
      proc(s.numeroNoche, s.fecha);
    }
    return stats;
  }


  Map<int, Map<String, int>> _computePorHorario(List<SorteoModel> sorteos) {
    final r = {
      for (int i = 0; i <= 99; i++) i: {'m': 0, 't': 0, 'n': 0},
    };
    for (final s in sorteos) {
      if (s.numeroManiana != null) {
        r[s.numeroManiana!]!['m'] = r[s.numeroManiana!]!['m']! + 1;
      }
      if (s.numeroTarde != null) {
        r[s.numeroTarde!]!['t'] = r[s.numeroTarde!]!['t']! + 1;
      }
      if (s.numeroNoche != null) {
        r[s.numeroNoche!]!['n'] = r[s.numeroNoche!]!['n']! + 1;
      }
    }
    return r;
  }

  Map<int, int> _computeTotalPorDia(List<SorteoModel> sorteos) {
    final r = {for (int d = 1; d <= 7; d++) d: 0};
    for (final s in sorteos) {
      r[s.fecha.weekday] = r[s.fecha.weekday]! + 1;
    }
    return r;
  }

  Map<int, List<MapEntry<int, int>>> _computeFrecPorDia(
    List<SorteoModel> sorteos,
  ) {
    final frec = {
      for (int d = 1; d <= 7; d++) d: {for (int n = 0; n <= 99; n++) n: 0},
    };
    for (final s in sorteos) {
      final d = s.fecha.weekday;
      if (s.numeroManiana != null) {
        frec[d]![s.numeroManiana!] = frec[d]![s.numeroManiana!]! + 1;
      }
      if (s.numeroTarde != null) {
        frec[d]![s.numeroTarde!] = frec[d]![s.numeroTarde!]! + 1;
      }
      if (s.numeroNoche != null) {
        frec[d]![s.numeroNoche!] = frec[d]![s.numeroNoche!]! + 1;
      }
    }
    return {
      for (final e in frec.entries)
        e.key:
            (e.value.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
                .toList(),
    };
  }



  List<SorteoModel> _filtrarPorPeriodo(String periodo) {
    final ahora = DateTime.now();
    DateTime inicio;
    switch (periodo) {
      case 'mes':       inicio = DateTime(ahora.year, ahora.month, 1);
      case 'trimestre': final t = (ahora.month - 1) ~/ 3; inicio = DateTime(ahora.year, t * 3 + 1, 1);
      case 'anio':      inicio = DateTime(ahora.year, 1, 1);
      default:          return _sorteos;
    }
    return _sorteos.where((s) => !s.fecha.isBefore(inicio)).toList();
  }

  List<MapEntry<int, int>> _computeCompanieros(int numero, List<SorteoModel> sorteos) {
    final conteo = <int, int>{};
    for (final s in sorteos) {
      final nums = [s.numeroManiana, s.numeroTarde, s.numeroNoche].whereType<int>().toList();
      if (!nums.contains(numero)) continue;
      for (final n in nums) {
        if (n != numero) conteo[n] = (conteo[n] ?? 0) + 1;
      }
    }
    return conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  List<MapEntry<String, int>> _computePares(List<SorteoModel> sorteos) {
    final Map<String, int> conteo = {};
    for (final s in sorteos) {
      final nums = [
        s.numeroManiana,
        s.numeroTarde,
        s.numeroNoche,
      ].where((n) => n != null).toList();
      for (int i = 0; i < nums.length; i++) {
        for (int j = i + 1; j < nums.length; j++) {
          if (nums[i] == nums[j]) continue;
          final a = min(nums[i]!, nums[j]!);
          final b = max(nums[i]!, nums[j]!);
          final k =
              '${a.toString().padLeft(2, '0')}-${b.toString().padLeft(2, '0')}';
          conteo[k] = (conteo[k] ?? 0) + 1;
        }
      }
    }
    return (conteo.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .take(20)
        .toList();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('🔍 Análisis'),
        
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.goldColor,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'General'),
            Tab(icon: Icon(Icons.schedule_rounded), text: 'Horarios'),
            Tab(icon: Icon(Icons.calendar_view_week_rounded), text: 'Semana'),
            Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Pares'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Ciclos'),
            Tab(icon: Icon(Icons.hub_rounded), text: 'Patrones'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: const SizedBox(),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.goldColor),
                  )
                : _error != null
                ? _buildError()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabGeneral(),
                      _buildTabHorarios(),
                      _buildTabSemana(),
                      _buildTabPares(),
                      _buildTabCiclos(),
                      _buildTabPatrones(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          const Text(
            'Error al cargar datos:',
            style: TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 4),
          Text(
            _error!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
        ],
      ),
    ),
  );

  // ── TAB 1: GENERAL ───────────────────────────────────────────────────────────

  Widget _buildTabGeneral() {
    if (_allStats == null || _sorteos.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.goldColor));
    }

    final ahora    = DateTime.now();
    final inicio30 = ahora.subtract(const Duration(days: 30));
    final sorteos30 = _sorteos.where((s) => !s.fecha.isBefore(inicio30)).toList();
    final total    = _sorteos.length;
    final total30  = sorteos30.length;

    // ── Tendencia 30d ─────────────────────────────────────────────────────────
    final freq30 = <int, int>{for (int i = 0; i <= 99; i++) i: 0};
    for (final s in sorteos30) {
      for (final n in [s.numeroManiana, s.numeroTarde, s.numeroNoche].whereType<int>()) {
        freq30[n] = freq30[n]! + 1;
      }
    }

    final enAlza = <({int n, double ratio})>[];
    final enBaja = <({int n, double ratio})>[];

    if (total > 0 && total30 > 0) {
      for (int n = 0; n <= 99; n++) {
        final histRate = _allStats![n]!.frecuencia / total;
        if (histRate == 0) continue;
        final rate30 = freq30[n]! / total30;
        final ratio  = rate30 / histRate;
        if (ratio >= 1.5 && freq30[n]! >= 2) enAlza.add((n: n, ratio: ratio));
        if (ratio <= 0.35 && _allStats![n]!.frecuencia >= 5) enBaja.add((n: n, ratio: ratio));
      }
      enAlza.sort((a, b) => b.ratio.compareTo(a.ratio));
      enBaja.sort((a, b) => a.ratio.compareTo(b.ratio));
    }

    // ── Números bajo presión ──────────────────────────────────────────────────
    final topPresion = List.generate(100, (i) => i)
        .where((n) => (_ciclosMax[n] ?? 0) > 0)
        .map((n) => (n: n, ratio: (_ciclosActuales[n] ?? 0) / _ciclosMax[n]!))
        .where((e) => e.ratio >= 0.5)
        .toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    // ── Top del día de semana ─────────────────────────────────────────────────
    final hoy    = ahora.weekday;
    final topHoy = _frecPorDia[hoy]?.take(5).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Presión ────────────────────────────────────────────────────
          _buildSeccionTitle(
            '🎯 Bajo presión',
            'Llevan más tiempo sin salir respecto a su récord personal',
          ),
          const SizedBox(height: 10),
          if (topPresion.isEmpty)
            const Text('Pocos datos aún', style: TextStyle(color: Colors.grey))
          else
            ...topPresion.take(10).map((e) => _buildPresionRow(e.n, e.ratio)),
          const SizedBox(height: 22),

          // ── 2. Tendencia ─────────────────────────────────────────────────
          _buildSeccionTitle(
            '📊 Tendencia 30 días',
            'Comparado con su promedio histórico',
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTendenciaCol(
                  '📈 En alza',
                  enAlza.take(6).toList(),
                  AppTheme.greenColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTendenciaCol(
                  '📉 En baja',
                  enBaja.take(6).toList(),
                  AppTheme.accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── 3. Día de semana ─────────────────────────────────────────────
          _buildSeccionTitle(
            '📅 Los de hoy (${_diasNombre[hoy]})',
            'Números que más salen este día de la semana históricamente',
          ),
          const SizedBox(height: 10),
          if (topHoy.isEmpty)
            const Text('Sin datos', style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topHoy
                  .map((e) => _buildMiniNumConFrec(e.key, e.value))
                  .toList(),
            ),
          const SizedBox(height: 22),

          // ── 4. Distribución decenas ──────────────────────────────────────
          _buildDistribucionDecenas(),
        ],
      ),
    );
  }

  // ── Row de presión ────────────────────────────────────────────────────────
  Widget _buildPresionRow(int numero, double ratio) {
    final actual  = _ciclosActuales[numero] ?? 0;
    final maximo  = _ciclosMax[numero] ?? 1;
    final pct     = ratio.clamp(0.0, 1.0);
    final sig     = significadoCorto(numero);

    final Color color;
    if (pct >= 0.85) {
      color = Colors.red;
    } else if (pct >= 0.65) {
      color = AppTheme.orangeColor;
    } else {
      color = AppTheme.goldColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Número
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                numero.toString().padLeft(2, '0'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Significado + barra
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(sig,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    const Spacer(),
                    Text('${actual}d / $maximo d',
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 7,
                    backgroundColor: AppTheme.cardBorder,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Porcentaje
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  // ── Columna tendencia ─────────────────────────────────────────────────────
  Widget _buildTendenciaCol(
      String titulo, List<({int n, double ratio})> items, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('Sin señal',
                style: TextStyle(
                    fontSize: 11, color: color.withOpacity(0.5),
                    fontStyle: FontStyle.italic))
          else
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      _buildMiniNum(e.n, color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          significadoCorto(e.n),
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '×${e.ratio.toStringAsFixed(1)}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ── Mini chip con frecuencia ──────────────────────────────────────────────
  Widget _buildMiniNumConFrec(int numero, int veces) {
    final sig = significadoCorto(numero);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(numero.toString().padLeft(2, '0'),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor)),
          Text(sig,
              style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis),
          Text('$veces×',
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldColor)),
        ],
      ),
    );
  }

  Map<int, int> _computeCiclosMax(Map<int, EstadisticaNumero> stats) {
    final result = <int, int>{};
    for (final entry in stats.entries) {
      final numero = entry.key;
      final stat = entry.value;
      if (stat.apariciones.isEmpty) {
        result[numero] = 0;
        continue;
      }

      final apariciones = (stat.apariciones.toList()..sort()).cast<DateTime>();
      int maxGap = 0;

      // Solo gaps entre apariciones consecutivas reales
      for (int i = 1; i < apariciones.length; i++) {
        final gap = apariciones[i].difference(apariciones[i - 1]).inDays;
        if (gap > maxGap) maxGap = gap;
      }

      result[numero] = maxGap;
    }
    return result;
  }

  // ── CÓMPUTOS PATRONES ────────────────────────────────────────────────────────

  /// Para cada par de puntos (A, B), cuántos días aparecieron juntos en el mismo día.
  Map<int, Map<int, int>> _computeCoOcurrenciaPuntos(List<SorteoModel> sorteos) {
    final co = <int, Map<int, int>>{
      for (int i = 0; i <= 18; i++) i: {for (int j = 0; j <= 18; j++) j: 0},
    };
    for (final s in sorteos) {
      final puntos = [s.numeroManiana, s.numeroTarde, s.numeroNoche]
          .whereType<int>()
          .map((n) => n ~/ 10 + n % 10)
          .toSet()
          .toList();
      for (int i = 0; i < puntos.length; i++) {
        for (int j = 0; j < puntos.length; j++) {
          if (i != j) co[puntos[i]]![puntos[j]] = co[puntos[i]]![puntos[j]]! + 1;
        }
      }
    }
    return co;
  }

  /// Total de días en que apareció cada punto.
  Map<int, int> _computeDiasPorPunto(List<SorteoModel> sorteos) {
    final r = <int, int>{for (int i = 0; i <= 18; i++) i: 0};
    for (final s in sorteos) {
      for (final n in [s.numeroManiana, s.numeroTarde, s.numeroNoche].whereType<int>()) {
        final p = n ~/ 10 + n % 10;
        r[p] = r[p]! + 1;
      }
    }
    return r;
  }

  /// Para cada punto hoy, qué puntos tienden a caer AL DÍA SIGUIENTE.
  Map<int, Map<int, int>> _computeSiguienteDiaPunto(List<SorteoModel> sorteos) {
    final r = <int, Map<int, int>>{
      for (int i = 0; i <= 18; i++) i: {for (int j = 0; j <= 18; j++) j: 0},
    };
    final porFecha = <String, SorteoModel>{};
    for (final s in sorteos) { porFecha[s.fechaKey] = s; }
    for (final s in sorteos) {
      final siguiente = DateTime(s.fecha.year, s.fecha.month, s.fecha.day + 1);
      final sigKey = '${siguiente.year}-${siguiente.month.toString().padLeft(2,'0')}-${siguiente.day.toString().padLeft(2,'0')}';
      final sig = porFecha[sigKey];
      if (sig == null) continue;
      final puntosHoy = [s.numeroManiana, s.numeroTarde, s.numeroNoche]
          .whereType<int>().map((n) => n ~/ 10 + n % 10).toSet();
      final puntosSig = [sig.numeroManiana, sig.numeroTarde, sig.numeroNoche]
          .whereType<int>().map((n) => n ~/ 10 + n % 10).toSet();
      for (final ph in puntosHoy) {
        for (final ps in puntosSig) {
          r[ph]![ps] = r[ph]![ps]! + 1;
        }
      }
    }
    return r;
  }

  /// Días donde el mismo punto salió en los 3 sorteos (concentración total).
  List<({DateTime fecha, int punto, int veces})> _computeDiasConcentrados(List<SorteoModel> sorteos) {
    final result = <({DateTime fecha, int punto, int veces})>[];
    for (final s in sorteos) {
      final nums = [s.numeroManiana, s.numeroTarde, s.numeroNoche].whereType<int>().toList();
      final puntos = nums.map((n) => n ~/ 10 + n % 10).toList();
      // Contar apariciones de cada punto ese día
      final conteo = <int, int>{};
      for (final p in puntos) { conteo[p] = (conteo[p] ?? 0) + 1; }
      for (final e in conteo.entries) {
        if (e.value >= 2) {
          result.add((fecha: s.fecha, punto: e.key, veces: e.value));
        }
      }
    }
    result.sort((a, b) => b.fecha.compareTo(a.fecha));
    return result;
  }

  Map<int, int> _computeCiclosActuales(Map<int, EstadisticaNumero> stats) {
    final result = <int, int>{};
    for (final entry in stats.entries) {
      final numero = entry.key;
      final stat = entry.value;
      result[numero] = stat.diasSinSalir();
    }
    return result;
  }

  // ── TAB 2: HORARIOS ──────────────────────────────────────────────────────────

  Widget _buildTabHorarios() {
    final topM =
        (_porHorario.entries.toList()
              ..sort((a, b) => b.value['m']!.compareTo(a.value['m']!)))
            .take(8)
            .toList();
    final topT =
        (_porHorario.entries.toList()
              ..sort((a, b) => b.value['t']!.compareTo(a.value['t']!)))
            .take(8)
            .toList();
    final topN =
        (_porHorario.entries.toList()
              ..sort((a, b) => b.value['n']!.compareTo(a.value['n']!)))
            .take(8)
            .toList();

    final biased =
        _porHorario.entries.where((e) {
          final total = e.value['m']! + e.value['t']! + e.value['n']!;
          return total >= 20;
        }).toList()..sort((a, b) {
          double bias(Map<String, int> v) {
            final total = v['m']! + v['t']! + v['n']!;
            final mx = max(max(v['m']!, v['t']!), v['n']!);
            return total > 0 ? mx / total : 0;
          }

          return bias(b.value).compareTo(bias(a.value));
        });

    final biasedFiltered = _filterHorarioList(biased);
    final topMFiltered = _filterHorarioList(topM);
    final topTFiltered = _filterHorarioList(topT);
    final topNFiltered = _filterHorarioList(topN);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeccionTitle('📊 Más sesgados', 'Mayor diferencia M / T / N'),
          const SizedBox(height: 8),
          if (biasedFiltered.isEmpty)
            _buildEmptySearchState()
          else
            ...biasedFiltered
                .take(8)
                .map((e) => _buildHorarioRow(e.key, e.value)),
          const SizedBox(height: 20),
          _buildSeccionTitle('🌅 Top Mañana', 'Más frecuentes a las 11:00 AM'),
          const SizedBox(height: 8),
          if (topMFiltered.isEmpty)
            _buildEmptySearchState()
          else
            ...topMFiltered.map((e) => _buildHorarioRow(e.key, e.value)),
          const SizedBox(height: 20),
          _buildSeccionTitle('☀️ Top Tarde', 'Más frecuentes a las 3:00 PM'),
          const SizedBox(height: 8),
          if (topTFiltered.isEmpty)
            _buildEmptySearchState()
          else
            ...topTFiltered.map((e) => _buildHorarioRow(e.key, e.value)),
          const SizedBox(height: 20),
          _buildSeccionTitle('🌙 Top Noche', 'Más frecuentes a las 9:00 PM'),
          const SizedBox(height: 8),
          if (topNFiltered.isEmpty)
            _buildEmptySearchState()
          else
            ...topNFiltered.map((e) => _buildHorarioRow(e.key, e.value)),
        ],
      ),
    );
  }

  List<MapEntry<int, Map<String, int>>> _filterHorarioList(
    List<MapEntry<int, Map<String, int>>> lista,
  ) {
    if (_searchGlobal.isEmpty) return lista;
    return lista.where((e) {
      final num = e.key.toString().padLeft(2, '0');
      final sig = significadoCorto(e.key).toLowerCase();
      return num.contains(_searchGlobal) ||
          sig.contains(_searchGlobal.toLowerCase());
    }).toList();
  }

  Widget _buildEmptySearchState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'No hay resultados para "$_searchGlobal"',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildHorarioRow(int numero, Map<String, int> slots) {
    final m = slots['m'] ?? 0;
    final t = slots['t'] ?? 0;
    final n = slots['n'] ?? 0;
    final mx = max(max(m, t), n);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  numero.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: Text(
                significadoCorto(numero),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  _buildSlotBar('M', m, mx, AppTheme.goldColor),
                  const SizedBox(width: 4),
                  _buildSlotBar('T', t, mx, AppTheme.orangeColor),
                  const SizedBox(width: 4),
                  _buildSlotBar('N', n, mx, Colors.purple),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotBar(String label, int valor, int maxVal, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: maxVal == 0 ? 0 : valor / maxVal,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: color,
              minHeight: 10,
            ),
          ),
          Text(
            '$valor',
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── TAB 4: SEMANA ─────────────────────────────────────────────────────────────

  Widget _buildTabSemana() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: 7,
      itemBuilder: (ctx, i) {
        final dia = i + 1;
        return _buildDiaCard(
          dia,
          _totalPorDia[dia] ?? 0,
          _frecPorDia[dia] ?? [],
        );
      },
    );
  }

  Widget _buildDiaCard(int dia, int totalDias, List<MapEntry<int, int>> top) {
    final maxCount = top.isEmpty ? 1 : top.first.value;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _diasNombre[dia],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '$totalDias días registrados',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...top.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        e.key.toString().padLeft(2, '0'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 72,
                      child: Text(
                        significadoCorto(e.key),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: maxCount > 0 ? e.value / maxCount : 0,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          color: AppTheme.primaryColor,
                          minHeight: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${e.value}x',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.goldColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 5: PARES ─────────────────────────────────────────────────────────────

  Widget _buildTabPares() {
    final sorteosFiltrados = _filtrarPorPeriodo(_paresPeriodo);
    final numBuscado = _paresNumBuscado;

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _paresCtrl,
            keyboardType: TextInputType.number,
            maxLength: 2,
            decoration: InputDecoration(
              hintText: 'Buscar número para ver sus compañeros...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.goldColor),
              suffixIcon: _paresCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () { _paresCtrl.clear(); setState(() => _paresNumBuscado = null); },
                    )
                  : null,
              counterText: '',
            ),
            onChanged: (v) => setState(() => _paresNumBuscado = int.tryParse(v)),
          ),
        ),
        // Selector de período
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in [('historico', 'Histórico'), ('mes', 'Mes'), ('trimestre', 'Trimestre'), ('anio', 'Año')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(p.$2),
                      selected: _paresPeriodo == p.$1,
                      onSelected: (_) => setState(() => _paresPeriodo = p.$1),
                      selectedColor: AppTheme.goldColor.withOpacity(0.25),
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color: _paresPeriodo == p.$1 ? AppTheme.goldColor : Colors.grey,
                        fontWeight: _paresPeriodo == p.$1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Lista
        Expanded(
          child: numBuscado != null && numBuscado >= 0 && numBuscado <= 99
              ? _buildCompanierosDeNumero(numBuscado, sorteosFiltrados)
              : _buildParesGlobales(sorteosFiltrados),
        ),
      ],
    );
  }

  Widget _buildCompanierosDeNumero(int numero, List<SorteoModel> sorteos) {
    final companieros = _computeCompanieros(numero, sorteos);
    final diasConNumero = sorteos.where((s) =>
      [s.numeroManiana, s.numeroTarde, s.numeroNoche].contains(numero)).length;

    if (companieros.isEmpty) {
      return Center(
        child: Text(
          'El ${numero.toString().padLeft(2, '0')} no salió en el período seleccionado',
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    final maxCount = companieros.first.value;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: companieros.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Row(
              children: [
                _buildMiniNum(numero, AppTheme.goldColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(significadoCorto(numero),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldColor)),
                      Text('Salió $diasConNumero veces · ${companieros.length} compañeros distintos',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        final entry = companieros[i - 1];
        final companion = entry.key;
        final veces = entry.value;
        final pct = diasConNumero > 0 ? veces / diasConNumero : 0.0;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text('$i.', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(width: 8),
                _buildMiniNum(companion, AppTheme.orangeColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(significadoCorto(companion),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: maxCount > 0 ? veces / maxCount : 0,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          color: AppTheme.primaryColor,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${veces}x', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldColor)),
                    Text('${(pct * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParesGlobales(List<SorteoModel> sorteos) {
    final pares = _computePares(sorteos);
    if (pares.isEmpty) {
      return const Center(child: Text('Sin datos suficientes', style: TextStyle(color: Colors.grey)));
    }
    final maxCount = pares.first.value;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: pares.length,
      itemBuilder: (ctx, i) {
        final entry = pares[i];
        final parts = entry.key.split('-');
        final a = int.parse(parts[0]);
        final b = int.parse(parts[1]);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Text('${i + 1}.', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 8),
                _buildMiniNum(a, AppTheme.goldColor),
                const SizedBox(width: 4),
                const Text('+', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 4),
                _buildMiniNum(b, AppTheme.orangeColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${significadoCorto(a)} · ${significadoCorto(b)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: maxCount > 0 ? entry.value / maxCount : 0,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          color: AppTheme.primaryColor,
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${entry.value}x', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.goldColor)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniNum(int numero, Color color) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Center(
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 12,
        ),
      ),
    ),
  );

  // ── WIDGETS COMPARTIDOS ──────────────────────────────────────────────────────

  Widget _buildSeccionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );

  Widget _buildDistribucionDecenas() {
    if (_allStats == null) return const SizedBox();
    final Map<String, int> decenas = {};
    for (int d = 0; d <= 9; d++) {
      final label = '${d == 0 ? '00' : '${d}0'}s';
      int total = 0;
      for (int j = 0; j <= 9; j++) {
        total += _allStats![d * 10 + j]!.frecuencia;
      }
      decenas[label] = total;
    }
    final maxVal = decenas.values.fold(1, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 Distribución por Decenas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Qué decena ha salido más en todo el historial',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...decenas.entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    e.key,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / maxVal,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      color: AppTheme.primaryColor,
                      minHeight: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${e.value}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── TAB 7: PATRONES ──────────────────────────────────────────────────────────

  Widget _buildTabPatrones() {
    if (_coOcurrenciaPuntos.isEmpty) {
      return const Center(child: Text('Sin datos', style: TextStyle(color: Colors.grey)));
    }
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.compare_arrows_rounded, size: 16), text: '¿Juntos?'),
              Tab(icon: Icon(Icons.calendar_today_rounded, size: 16), text: '¿Qué sigue?'),
              Tab(icon: Icon(Icons.repeat_rounded, size: 16), text: 'Repetidos'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPatronMapa(),
                _buildPatronSiguienteDia(),
                _buildPatronConcentraciones(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sub-tab A: Mapa de afinidad / exclusión entre puntos ──────────────────

  Widget _buildPatronLeyenda(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
    ],
  );

  Widget _buildPatronMapa() {
    return StatefulBuilder(
      builder: (ctx, setLocal) {
        final dias = _diasPorPunto[_puntoMapa] ?? 0;
        if (dias == 0) {
          return Center(
            child: Text('El punto ${_puntoMapa.toString().padLeft(2,'0')} no tiene datos',
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        final co = _coOcurrenciaPuntos[_puntoMapa]!;
        final entries = List.generate(19, (i) => i)
            .where((i) => i != _puntoMapa)
            .map((i) => MapEntry(i, co[i] ?? 0))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxCo = entries.isEmpty ? 1 : entries.first.value;

        return Column(
          children: [
            // Intro explicativa
            Container(
              color: AppTheme.cardColor,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tocá un punto para ver con cuáles suele caer el mismo día y cuáles evita.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Punto = suma de dígitos del número. Ej: 72 → 7+2 = punto 09.',
                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(19, (i) {
                        final sel = _puntoMapa == i;
                        return GestureDetector(
                          onTap: () => setLocal(() => _puntoMapa = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 6),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.primaryColor.withOpacity(0.2)
                                  : AppTheme.bgDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: sel ? AppTheme.primaryColor : AppTheme.cardBorder,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                    color: sel ? AppTheme.primaryColor : AppTheme.textSecondary,
                                  )),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Resumen del punto seleccionado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppTheme.primaryColor.withOpacity(0.12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(_puntoMapa.toString().padLeft(2, '0'),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor)),
                        Text(significadoCorto(_puntoMapa),
                            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Apareció $dias veces en el historial',
                            style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(
                          'Más frecuente junto a él: ${entries.first.key.toString().padLeft(2,'0')} (${entries.first.value} días)',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        Text(
                          'Menos frecuente: ${entries.last.key.toString().padLeft(2,'0')} (${entries.last.value} días)',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Leyenda
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  _buildPatronLeyenda(AppTheme.greenColor, 'Van juntos'),
                  const SizedBox(width: 12),
                  _buildPatronLeyenda(AppTheme.goldColor, 'A veces'),
                  const SizedBox(width: 12),
                  _buildPatronLeyenda(AppTheme.accentColor, 'Se evitan'),
                ],
              ),
            ),

            // Lista de afinidad
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                itemCount: entries.length,
                itemBuilder: (ctx2, i) {
                  final e = entries[i];
                  final pct = dias > 0 ? e.value / dias : 0.0;
                  final color = pct > 0.35
                      ? AppTheme.greenColor
                      : pct > 0.18
                          ? AppTheme.goldColor
                          : AppTheme.accentColor;
                  final etiqueta = pct > 0.35
                      ? 'Van juntos'
                      : pct > 0.18
                          ? 'A veces'
                          : 'Se evitan';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 22,
                          child: Text('${i+1}.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(e.key.toString().padLeft(2,'0'),
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: color, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(significadoCorto(e.key),
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(etiqueta,
                                        style: TextStyle(fontSize: 9, color: color,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: maxCo > 0 ? e.value / maxCo : 0,
                                  minHeight: 5,
                                  backgroundColor: AppTheme.cardBorder,
                                  color: color.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${e.value}d',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: color, fontSize: 13)),
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Sub-tab B: Al día siguiente ────────────────────────────────────────────

  Widget _buildPatronSiguienteDia() {
    return StatefulBuilder(
      builder: (ctx, setLocal) {
        final puntoHoy = _puntoMapa;
        final totalDias = _diasPorPunto[puntoHoy] ?? 1;
        final sig = _siguienteDiaPunto[puntoHoy]!;
        final entries = List.generate(19, (i) => MapEntry(i, sig[i] ?? 0))
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxV = entries.isEmpty ? 1 : entries.first.value;

        return Column(
          children: [
            // Intro + selector
            Container(
              color: AppTheme.cardColor,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Si hoy cayó este punto, ¿qué punto es más probable mañana?',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(19, (i) {
                        final sel = puntoHoy == i;
                        return GestureDetector(
                          onTap: () => setLocal(() => _puntoMapa = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 6),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.goldColor.withOpacity(0.2)
                                  : AppTheme.bgDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: sel ? AppTheme.goldColor : AppTheme.cardBorder,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(i.toString().padLeft(2, '0'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                    color: sel ? AppTheme.goldColor : AppTheme.textSecondary,
                                  )),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // Encabezado con top 3
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: AppTheme.goldColor.withOpacity(0.12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.goldColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(puntoHoy.toString().padLeft(2, '0'),
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                                color: AppTheme.goldColor)),
                        Icon(Icons.arrow_downward, color: AppTheme.goldColor, size: 12),
                        Text('HOY', style: TextStyle(fontSize: 8, color: AppTheme.goldColor,
                            fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Más probable mañana:',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6, runSpacing: 4,
                          children: entries.take(3).map((e) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.goldColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.goldColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              '${e.key.toString().padLeft(2,'0')} · ${e.value}x',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: AppTheme.goldColor, fontSize: 12),
                            ),
                          )).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Leyenda
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  _buildPatronLeyenda(AppTheme.greenColor, 'Muy probable'),
                  const SizedBox(width: 12),
                  _buildPatronLeyenda(AppTheme.goldColor, 'Probable'),
                  const SizedBox(width: 12),
                  _buildPatronLeyenda(AppTheme.textSecondary, 'Poco frecuente'),
                ],
              ),
            ),

            // Lista
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                itemCount: entries.length,
                itemBuilder: (ctx2, i) {
                  final e = entries[i];
                  final pct = totalDias > 0 ? e.value / totalDias : 0.0;
                  final color = pct > 0.3
                      ? AppTheme.greenColor
                      : pct > 0.15
                          ? AppTheme.goldColor
                          : AppTheme.textSecondary;
                  final etiqueta = pct > 0.3
                      ? 'Muy probable'
                      : pct > 0.15
                          ? 'Probable'
                          : 'Poco frecuente';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 22,
                            child: Text('${i+1}.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11))),
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(e.key.toString().padLeft(2,'0'),
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: color, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(significadoCorto(e.key),
                                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(etiqueta,
                                        style: TextStyle(fontSize: 9, color: color,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: maxV > 0 ? e.value / maxV : 0,
                                  minHeight: 5,
                                  backgroundColor: AppTheme.cardBorder,
                                  color: color.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${e.value}x',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    color: color, fontSize: 13)),
                            Text('${(pct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Sub-tab C: Días concentrados ───────────────────────────────────────────

  Widget _buildBadgeConc({required int veces, required bool esTriple}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: esTriple
          ? AppTheme.accentColor.withOpacity(0.18)
          : AppTheme.orangeColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('$veces × ${esTriple ? 'triple' : 'doble'}',
        style: TextStyle(
            fontSize: 10,
            color: esTriple ? AppTheme.accentColor : AppTheme.orangeColor,
            fontWeight: FontWeight.bold)),
  );

  Widget _buildPatronConcentraciones() {
    if (_diasConcentrados.isEmpty) {
      return Center(
        child: Text('No hay días con punto repetido 2+ veces',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    final porPunto = <int, List<({DateTime fecha, int veces})>>{};
    for (final d in _diasConcentrados) {
      porPunto.putIfAbsent(d.punto, () => []).add((fecha: d.fecha, veces: d.veces));
    }
    final ranking = porPunto.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    const fmt = 'd MMM yy';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Explicación con ejemplo concreto
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text('¿Qué son los "repetidos"?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Es cuando el mismo punto cayó en 2 o 3 sorteos del mismo día '
                '(mañana, tarde, noche). Un doble es 2 veces, un triple es las 3.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ejemplo: si cayeron 72, 45 y 27 en el mismo día, todos tienen punto 09 '
                  '(7+2=9, 4+5=9, 2+7=9) — eso sería un triple del punto 09.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cuando un punto se concentra, suele tardar varios días en repetirse.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),

        // Leyenda
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildBadgeConc(veces: 0, esTriple: true),
                const SizedBox(width: 6),
                Text('= los 3 sorteos del día', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
              Row(mainAxisSize: MainAxisSize.min, children: [
                _buildBadgeConc(veces: 0, esTriple: false),
                const SizedBox(width: 6),
                Text('= 2 de 3 sorteos', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ]),
            ],
          ),
        ),

        // Ranking
        _buildSeccionTitle('Ranking de concentración', '¿Qué punto se repite más en un mismo día?'),
        const SizedBox(height: 10),
        ...ranking.take(10).map((e) {
          final p = e.key;
          final ocurrencias = e.value;
          final triples = ocurrencias.where((o) => o.veces == 3).length;
          final dobles  = ocurrencias.where((o) => o.veces == 2).length;
          final ultimo  = ocurrencias.first.fecha;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(p.toString().padLeft(2,'0'),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(significadoCorto(p),
                              style: TextStyle(fontSize: 12, color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (triples > 0) _buildBadgeConc(veces: triples, esTriple: true),
                              if (dobles > 0) _buildBadgeConc(veces: dobles, esTriple: false),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${ocurrencias.length} días',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor, fontSize: 14)),
                        Text('Último: ${DateFormat(fmt, 'es').format(ultimo)}',
                            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ocurrencias.take(8).map((o) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: o.veces == 3
                            ? AppTheme.accentColor.withOpacity(0.12)
                            : AppTheme.orangeColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: o.veces == 3
                              ? AppTheme.accentColor.withOpacity(0.35)
                              : AppTheme.orangeColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(o.veces == 3 ? '●●●' : '●●',
                              style: TextStyle(fontSize: 8,
                                  color: o.veces == 3 ? AppTheme.accentColor : AppTheme.orangeColor)),
                          const SizedBox(width: 4),
                          Text(DateFormat(fmt, 'es').format(o.fecha),
                              style: TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── TAB 5: CICLOS ──────────────────────────────────────────────────────────

  Widget _buildTabCiclos() {
    if (_allStats == null || _ciclosMax.isEmpty) {
      return const Center(child: Text('No hay datos de ciclos'));
    }

    // Build sorted list with pressure data
    final todos = List.generate(100, (i) {
      final max    = _ciclosMax[i] ?? 0;
      final actual = _ciclosActuales[i] ?? 0;
      final pct    = max > 0 ? (actual / max).clamp(0.0, 1.0) : 0.0;
      return (n: i, max: max, actual: actual, pct: pct);
    })..sort((a, b) => b.pct.compareTo(a.pct));

    final criticos     = todos.where((e) => e.pct >= 0.85).toList();
    final observacion  = todos.where((e) => e.pct >= 0.60 && e.pct < 0.85).toList();
    final normales     = todos.where((e) => e.pct < 0.60 && e.max > 0).toList();

    return _CiclosTabView(
      criticos: criticos,
      observacion: observacion,
      normales: normales,
    );
  }
}

// ── _CiclosTabView ─────────────────────────────────────────────────────────────

typedef _CicloEntry = ({int n, int max, int actual, double pct});

class _CiclosTabView extends StatefulWidget {
  final List<_CicloEntry> criticos;
  final List<_CicloEntry> observacion;
  final List<_CicloEntry> normales;

  const _CiclosTabView({
    required this.criticos,
    required this.observacion,
    required this.normales,
  });

  @override
  State<_CiclosTabView> createState() => _CiclosTabViewState();
}

class _CiclosTabViewState extends State<_CiclosTabView> {
  bool _mostrarNormales = false;

  @override
  Widget build(BuildContext context) {
    final criticos    = widget.criticos;
    final observacion = widget.observacion;
    final normales    = widget.normales;
    final total       = criticos.length + observacion.length + normales.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Resumen rápido ─────────────────────────────────────────────────
          Row(
            children: [
              _buildResumenChip(
                '🔴 ${criticos.length}',
                'Críticos',
                Colors.red,
              ),
              const SizedBox(width: 8),
              _buildResumenChip(
                '🟠 ${observacion.length}',
                'En obs.',
                AppTheme.orangeColor,
              ),
              const SizedBox(width: 8),
              _buildResumenChip(
                '🟢 ${normales.length}',
                'Normales',
                AppTheme.greenColor,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$total números con historial · ordenados por presión',
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          // ── Zona crítica ───────────────────────────────────────────────────
          _buildCicloSeccion(
            icon: Icons.warning_amber_rounded,
            titulo: 'Zona crítica',
            subtitulo: '≥ 85% del récord personal sin salir',
            color: Colors.red,
            items: criticos,
            modo: _ModoCard.grande,
          ),

          // ── En observación ─────────────────────────────────────────────────
          if (observacion.isNotEmpty) ...[
            const SizedBox(height: 22),
            _buildCicloSeccion(
              icon: Icons.visibility_rounded,
              titulo: 'En observación',
              subtitulo: '60 – 84% · acercándose al máximo',
              color: AppTheme.orangeColor,
              items: observacion,
              modo: _ModoCard.compacto,
            ),
          ],

          // ── Normales (colapsable) ──────────────────────────────────────────
          if (normales.isNotEmpty) ...[
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => setState(() => _mostrarNormales = !_mostrarNormales),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.greenColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.check_circle_outline_rounded,
                          color: AppTheme.greenColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dentro del ciclo normal',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          Text('${normales.length} números · < 60% de presión',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    Icon(
                      _mostrarNormales
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_mostrarNormales) ...[
              const SizedBox(height: 8),
              ...normales.map((e) => _buildCicloRow(e, AppTheme.greenColor)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildResumenChip(String valor, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    ),
  );

  Widget _buildCicloSeccion({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required List<_CicloEntry> items,
    required _ModoCard modo,
  }) {
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
                Text(subtitulo,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (modo == _ModoCard.grande)
          ...items.map((e) => _buildCicloCard(e, color))
        else
          ...items.map((e) => _buildCicloRow(e, color)),
      ],
    );
  }

  // ── Tarjeta grande (zona crítica) ──────────────────────────────────────────
  Widget _buildCicloCard(_CicloEntry e, Color color) {
    final sig = significadoCorto(e.n);
    final pct = e.pct.clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          // Número badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                e.n.toString().padLeft(2, '0'),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(sig,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary)),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    backgroundColor: AppTheme.cardBorder,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sin salir ${e.actual}d · récord ${e.max}d',
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fila compacta (observación / normales) ─────────────────────────────────
  Widget _buildCicloRow(_CicloEntry e, Color color) {
    final pct = e.pct.clamp(0.0, 1.0);
    final sig = significadoCorto(e.n);
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                e.n.toString().padLeft(2, '0'),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sig,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: AppTheme.cardBorder,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${e.actual}d / ${e.max}d',
                  style: TextStyle(
                      fontSize: 9,
                      color: color,
                      fontWeight: FontWeight.w600)),
              Text('${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ModoCard { grande, compacto }
