// lib/screens/analisis_screen.dart

import 'dart:math' show max, min;
import 'package:flutter/material.dart';
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

  // Base
  List<EstadisticaNumero> _calientes = [];
  List<EstadisticaNumero> _frios = [];
  List<EstadisticaNumero> _repetidosMes = [];
  Map<int, EstadisticaNumero>? _allStats;
  bool _loading = true;
  String? _error;

  // Derivados
  Map<int, Map<String, int>> _porHorario = {};
  Map<int, int> _totalPorDia = {};
  Map<int, List<MapEntry<int, int>>> _frecPorDia = {};
  List<MapEntry<String, int>> _pares = [];

  // Búsqueda global
  String _searchGlobal = '';
  late TextEditingController _searchController;

  // Ciclos (Max ausencia tracking)
  Map<int, int> _ciclosMax = {}; // max days without appearing per number
  Map<int, int> _ciclosActuales = {}; // current days without appearing

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
    _tabController = TabController(length: 5, vsync: this);
    _db.addListener(_sincronizar);
    _sincronizar();
  }

  @override
  void dispose() {
    _db.removeListener(_sincronizar);
    _tabController.dispose();
    _searchController.dispose();
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

      final calientes = allStats.values.toList()
        ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));

      final frios = allStats.values.where((e) => e.frecuencia > 0).toList()
        ..sort((a, b) {
          final d = b.diasSinSalir().compareTo(a.diasSinSalir());
          return d != 0 ? d : a.frecuencia.compareTo(b.frecuencia);
        });

      if (mounted) {
        setState(() {
          _sorteos = sorteos;
          _allStats = allStats;
          _calientes = calientes.take(15).toList();
          _frios = frios.take(15).toList();
          _porHorario = _computePorHorario(sorteos);
          _totalPorDia = _computeTotalPorDia(sorteos);
          _frecPorDia = _computeFrecPorDia(sorteos);
          _pares = _computePares(sorteos);
          _ciclosMax = _computeCiclosMax(allStats);
          _ciclosActuales = _computeCiclosActuales(allStats);
          _repetidosMes = _computeRepetidosMes(sorteos);
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
      if (num == null || num < 0 || num > 99) return;
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


  List<int> _generarSugerencia() {
    if (_allStats == null) return [];
    final ord = _allStats!.values.toList()
      ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));
    final caliente = ord.first.numero;
    final frios = _allStats!.values.where((e) => e.frecuencia > 0).toList()
      ..sort((a, b) => b.diasSinSalir().compareTo(a.diasSinSalir()));
    final frio = frios.isNotEmpty ? frios.first.numero : 50;
    final medios = ord
        .where((e) => e.numero != caliente && e.numero != frio)
        .skip(ord.length ~/ 3)
        .take(20)
        .toList();
    return [caliente, frio, medios.isNotEmpty ? medios.first.numero : 33];
  }

  // ── RELACIONES PROFUNDAS ──────────────────────────────────────────────────────


  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Análisis'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
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
    final faltanMes = _numerosNoSalidosMesActual();
    final calientesFaltantesMes = _calientes
        .where((e) => faltanMes.contains(e.numero))
        .toList();
    final friosFaltantesMes = _frios
        .where((e) => faltanMes.contains(e.numero))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSugerencia(),
          const SizedBox(height: 20),
          _buildSeccionTitle(
            '🔥 Números Calientes',
            'Más frecuentes en el historial',
          ),
          const SizedBox(height: 8),
          _buildChipList(
            _filterBySearch(_calientes),
            AppTheme.accentColor,
            true,
            null, // Remove faltantesMes to avoid repetition
          ),
          const SizedBox(height: 20),
          _buildSeccionTitle('❄️ Números Fríos', 'Llevan más tiempo sin salir'),
          const SizedBox(height: 8),
          _buildChipList(
            _filterBySearch(_frios),
            Colors.lightBlue,
            false,
            null, // Remove faltantesMes
          ),
          const SizedBox(height: 20),
          if (calientesFaltantesMes.isNotEmpty ||
              friosFaltantesMes.isNotEmpty) ...[
            _buildSeccionTitle(
              '⚠️ Calientes/Fríos faltantes este mes',
              'Números frecuentes/infrecuentes que no han salido este mes',
            ),
            const SizedBox(height: 8),
            if (calientesFaltantesMes.isNotEmpty) ...[
              Text(
                '🔥 Calientes faltantes:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _buildChipList(
                _filterBySearch(calientesFaltantesMes),
                AppTheme.accentColor,
                true,
                null,
              ),
              const SizedBox(height: 12),
            ],
            if (friosFaltantesMes.isNotEmpty) ...[
              Text(
                '❄️ Fríos faltantes:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              _buildChipList(
                _filterBySearch(friosFaltantesMes),
                Colors.lightBlue,
                false,
                null,
              ),
            ],
            const SizedBox(height: 20),
          ],
          _buildSeccionTitle(
            '📅 Más repetidos este mes',
            'Números que más veces han salido en el mes actual',
          ),
          const SizedBox(height: 8),
          _buildChipList(
            _filterBySearch(_repetidosMes),
            Colors.orange,
            true,
            null,
          ),
          const SizedBox(height: 20),
          _buildSeccionTitle(
            '🗓️ Números faltantes',
            'No han salido este año, trimestre o mes actual',
          ),
          const SizedBox(height: 8),
          _buildMissingNumbersSection(),
          const SizedBox(height: 20),
          _buildDistribucionDecenas(),
        ],
      ),
    );
  }

  List<EstadisticaNumero> _filterBySearch(List<EstadisticaNumero> lista) {
    if (_searchGlobal.isEmpty) return lista;
    return lista.where((e) {
      final num = e.numero.toString().padLeft(2, '0');
      final sig = significadoCorto(e.numero).toLowerCase();
      return num.contains(_searchGlobal) ||
          sig.contains(_searchGlobal.toLowerCase());
    }).toList();
  }

  List<int> _filterMissingBySearch(List<int> lista) {
    if (_searchGlobal.isEmpty) return lista;
    return lista.where((n) {
      final num = n.toString().padLeft(2, '0');
      final sig = significadoCorto(n).toLowerCase();
      return num.contains(_searchGlobal) ||
          sig.contains(_searchGlobal.toLowerCase());
    }).toList();
  }

  List<int> _numerosNoSalidosEntre(DateTime inicio, DateTime fin) {
    final seen = <int>{};
    for (final s in _sorteos) {
      if (s.fecha.isBefore(inicio) || s.fecha.isAfter(fin)) continue;
      seen.addAll(
        [
          s.numeroManiana,
          s.numeroTarde,
          s.numeroNoche,
        ].where((n) => n != null).cast<int>(),
      );
    }
    return List.generate(
      100,
      (i) => i,
    ).where((n) => !seen.contains(n)).toList();
  }

  List<int> _numerosNoSalidosAnioActual() {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, 1, 1);
    final fin = DateTime(
      ahora.year + 1,
      1,
      1,
    ).subtract(const Duration(days: 1));
    return _numerosNoSalidosEntre(inicio, fin);
  }

  List<int> _numerosNoSalidosTrimestreActual() {
    final ahora = DateTime.now();
    final trimestre = ((ahora.month - 1) ~/ 3);
    final inicio = DateTime(ahora.year, trimestre * 3 + 1, 1);
    final fin = DateTime(
      ahora.year,
      trimestre * 3 + 4,
      1,
    ).subtract(const Duration(days: 1));
    return _numerosNoSalidosEntre(inicio, fin);
  }

  List<int> _numerosNoSalidosMesActual() {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, 1);
    final fin = DateTime(
      ahora.year,
      ahora.month + 1,
      1,
    ).subtract(const Duration(days: 1));
    return _numerosNoSalidosEntre(inicio, fin);
  }

  List<EstadisticaNumero> _computeRepetidosMes(List<SorteoModel> sorteos) {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, 1);
    final fin = DateTime(ahora.year, ahora.month + 1, 1)
        .subtract(const Duration(days: 1));
    final stats = {
      for (int i = 0; i <= 99; i++) i: EstadisticaNumero(numero: i),
    };
    for (final s in sorteos) {
      if (s.fecha.isBefore(inicio) || s.fecha.isAfter(fin)) continue;
      for (final num in [s.numeroManiana, s.numeroTarde, s.numeroNoche]) {
        if (num == null || num < 0 || num > 99) continue;
        stats[num]!.frecuencia++;
        stats[num]!.apariciones.add(s.fecha);
        if (stats[num]!.ultimaVez == null ||
            s.fecha.isAfter(stats[num]!.ultimaVez!)) {
          stats[num]!.ultimaVez = s.fecha;
        }
      }
    }
    return (stats.values.where((e) => e.frecuencia > 0).toList()
          ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia)))
        .take(15)
        .toList();
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

      // Calcula gap entrada primera aparición
      if (apariciones.isNotEmpty) {
        maxGap = apariciones.first.difference(DateTime(2000, 1, 1)).inDays;
      }

      // Calcula gaps entre apariciones
      for (int i = 1; i < apariciones.length; i++) {
        final gap = apariciones[i].difference(apariciones[i - 1]).inDays;
        if (gap > maxGap) maxGap = gap;
      }

      // Calcula gap desde última aparición hasta hoy
      if (apariciones.isNotEmpty) {
        final currentGap = DateTime.now().difference(apariciones.last).inDays;
        if (currentGap > maxGap) maxGap = currentGap;
      }

      result[numero] = maxGap;
    }
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
    if (_pares.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos suficientes',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final maxCount = _pares.first.value;
    return Column(
      children: [
        
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _pares.length,
            itemBuilder: (ctx, i) {
              final entry = _pares[i];
              final parts = entry.key.split('-');
              final a = int.parse(parts[0]);
              final b = int.parse(parts[1]);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
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
                            Text(
                              '${significadoCorto(a)} · ${significadoCorto(b)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: maxCount > 0
                                    ? entry.value / maxCount
                                    : 0,
                                backgroundColor: Colors.grey.withValues(
                                  alpha: 0.2,
                                ),
                                color: AppTheme.primaryColor,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.value}x',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

  Widget _buildSugerencia() {
    final sugeridos = _generarSugerencia();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF0a2a5e)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppTheme.goldColor),
              const SizedBox(width: 8),
              const Text(
                'Sugerencia del día',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Estrategia mixta',
                  style: TextStyle(fontSize: 10, color: AppTheme.goldColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (sugeridos.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSugerenciaItem(sugeridos[0], '🔥 Caliente'),
                _buildSugerenciaItem(sugeridos[1], '❄️ Frío'),
                _buildSugerenciaItem(sugeridos[2], '⚖️ Medio'),
              ],
            )
          else
            const Text(
              'Registra al menos 7 días para ver sugerencias',
              style: TextStyle(color: Colors.grey),
            ),
          
        ],
      ),
    );
  }

  Widget _buildSugerenciaItem(int numero, String label) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      const SizedBox(height: 6),
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.goldColor, AppTheme.orangeColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.goldColor.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            numero.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        significadoCorto(numero),
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    ],
  );

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

  Widget _buildChipList(
    List<EstadisticaNumero> lista,
    Color color,
    bool mostrarFrecuencia,
    Set<int>? faltantesMes,
  ) {
    if (lista.isEmpty) {
      return Card(
        color: color.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info, color: color.withValues(alpha: 0.6)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _searchGlobal.isEmpty
                      ? 'Sin datos suficientes'
                      : 'No encontramos números que coincidan con "$_searchGlobal"',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: lista.map((stat) {
          final sig = significadoCorto(stat.numero);
          final isCaliente = _calientes.any((e) => e.numero == stat.numero);
          final isFrio = _frios.any((e) => e.numero == stat.numero);
          String tipo = '';
          if (isCaliente) {
            tipo = '🔥';
          } else if (isFrio) {
            tipo = '❄️';
          }
          return GestureDetector(
            onTap: () {
              final val = stat.numero.toString().padLeft(2, '0');
              _searchController.text = val;
              setState(() {
                _searchGlobal = val;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    stat.numero.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (tipo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tipo,
                      style: TextStyle(
                        fontSize: 16,
                        color: tipo == '🔥'
                            ? Colors.red
                            : tipo == '❄️'
                            ? Colors.blue
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    mostrarFrecuencia
                        ? '${stat.frecuencia}x'
                        : '${stat.diasSinSalir()}d',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sig.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      sig,
                      style: TextStyle(
                        fontSize: 9,
                        color: color.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (faltantesMes?.contains(stat.numero) ?? false) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🚫 Faltante',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMissingNumbersSection() {
    final faltanAnioRaw = _numerosNoSalidosAnioActual();
    final faltanAnio = _filterMissingBySearch(faltanAnioRaw);
    final faltanAnioItems = faltanAnio.map((n) {
      final isCaliente = _calientes.any((e) => e.numero == n);
      final isFrio = _frios.any((e) => e.numero == n);
      String tipo = '';
      String info = '';
      if (isCaliente) {
        tipo = '🔥';
        info = '${_allStats![n]!.frecuencia}x';
      } else if (isFrio) {
        tipo = '❄️';
        info = '${_allStats![n]!.diasSinSalir()}d';
      }
      return {'numero': n, 'tipo': tipo, 'info': info};
    }).toList();

    final faltanTrimestreRaw = _numerosNoSalidosTrimestreActual();
    final faltanTrimestre = _filterMissingBySearch(faltanTrimestreRaw);
    final faltanTrimestreItems = faltanTrimestre.map((n) {
      final isCaliente = _calientes.any((e) => e.numero == n);
      final isFrio = _frios.any((e) => e.numero == n);
      String tipo = '';
      String info = '';
      if (isCaliente) {
        tipo = '🔥';
        info = '${_allStats![n]!.frecuencia}x';
      } else if (isFrio) {
        tipo = '❄️';
        info = '${_allStats![n]!.diasSinSalir()}d';
      }
      return {'numero': n, 'tipo': tipo, 'info': info};
    }).toList();

    // Para mes actual: incluir todos, pero marcar calientes/fríos
    final faltanMesRaw = _numerosNoSalidosMesActual();
    final faltanMesItems = faltanMesRaw.map((n) {
      final isCaliente = _calientes.any((e) => e.numero == n);
      final isFrio = _frios.any((e) => e.numero == n);
      String tipo = '';
      String info = '';
      if (isCaliente) {
        tipo = '🔥';
        info = '${_allStats![n]!.frecuencia}x';
      } else if (isFrio) {
        tipo = '❄️';
        info = '${_allStats![n]!.diasSinSalir()}d';
      }
      return {'numero': n, 'tipo': tipo, 'info': info};
    }).toList();

    // Filtrar por búsqueda
    final faltanMesFiltered = _searchGlobal.isEmpty
        ? faltanMesItems
        : faltanMesItems.where((item) {
            final n = item['numero'] as int;
            final num = n.toString().padLeft(2, '0');
            final sig = significadoCorto(n).toLowerCase();
            return num.contains(_searchGlobal) ||
                sig.contains(_searchGlobal.toLowerCase());
          }).toList();

    if (faltanAnio.isEmpty &&
        faltanTrimestre.isEmpty &&
        faltanMesFiltered.isEmpty) {
      return Card(
        color: AppTheme.cardColor,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Todos los números han salido este año. ¡Buen trabajo!',
              ),
              if (_searchGlobal.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No hay resultados para "$_searchGlobal".',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (faltanAnio.isNotEmpty) ...[
          Text(
            '• Este año: ${faltanAnio.length} números no han salido',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildMissingChips(faltanAnioItems),
          const SizedBox(height: 14),
        ],
        if (faltanTrimestre.isNotEmpty) ...[
          Text(
            '• Último trimestre: ${faltanTrimestre.length} números no han salido',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildMissingChips(faltanTrimestreItems),
          const SizedBox(height: 14),
        ],
        if (faltanMesFiltered.isNotEmpty) ...[
          Text(
            '• Mes actual: ${faltanMesFiltered.length} números no han salido',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildMissingChips(faltanMesFiltered, maxMostrar: null),
        ],
      ],
    );
  }

  Widget _buildMissingChips(
    List<Map<String, dynamic>> items, {
    int? maxMostrar,
  }) {
    final toShow = maxMostrar != null && items.length > maxMostrar
        ? items.take(maxMostrar).toList()
        : items;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: toShow.map((item) {
          final numero = item['numero'] as int;
          final tipo = item['tipo'] as String;
          final info = item['info'] as String;
          final sig = significadoCorto(numero);
          return GestureDetector(
            onTap: () {
              final val = numero.toString().padLeft(2, '0');
              _searchController.text = val;
              setState(() {
                _searchGlobal = val;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    numero.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (tipo.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tipo,
                      style: TextStyle(
                        fontSize: 16,
                        color: tipo == '🔥'
                            ? Colors.red
                            : tipo == '❄️'
                            ? Colors.blue
                            : Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (info.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      info,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    sig,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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

  // ── TAB 5: CICLOS ──────────────────────────────────────────────────────────

  Widget _buildTabCiclos() {
    if (_allStats == null || _ciclosMax.isEmpty) {
      return const Center(child: Text('No hay datos de ciclos'));
    }

    // Ordena por % de ciclo actual vs máximo (descendente)
    final numeros = List<int>.generate(100, (i) => i);
    numeros.sort((a, b) {
      final maxA = _ciclosMax[a] ?? 1;
      final actualA = _ciclosActuales[a] ?? 0;
      final pctA = actualA / (maxA > 0 ? maxA : 1);

      final maxB = _ciclosMax[b] ?? 1;
      final actualB = _ciclosActuales[b] ?? 0;
      final pctB = actualB / (maxB > 0 ? maxB : 1);

      return pctB.compareTo(pctA);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '♻️ Análisis de Ciclos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Seguimiento de máximas ausencias y ciclos actuales',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.9,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 100,
            itemBuilder: (ctx, i) {
              final n = numeros[i];
              final maxDias = _ciclosMax[n] ?? 0;
              final actualDias = _ciclosActuales[n] ?? 0;
              final pct = maxDias > 0 ? (actualDias / maxDias) : 0.0;

              Color bgColor;
              if (pct > 0.8) {
                bgColor = Colors.red.withOpacity(0.2);
              } else if (pct > 0.6) {
                bgColor = Colors.orange.withOpacity(0.2);
              } else {
                bgColor = Colors.green.withOpacity(0.2);
              }

              Color borderColor;
              if (pct > 0.8) {
                borderColor = Colors.red;
              } else if (pct > 0.6) {
                borderColor = Colors.orange;
              } else {
                borderColor = Colors.green;
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      n.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${actualDias}d',
                      style: TextStyle(fontSize: 10, color: borderColor),
                    ),
                    Text(
                      'max:${maxDias}d',
                      style: const TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📊 Leyenda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🟢 < 60%: Dentro del ciclo normal',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🟡 60-80%: Aproximándose a máximo',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '🔴 > 80%: En zona de riesgo (puede romper récord)',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
