// lib/screens/analisis_screen.dart

import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import '../models/sorteo_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../data/libro_suenos.dart';
import '../data/grupos_semanticos.dart';

class AnalisisScreen extends StatefulWidget {
  const AnalisisScreen({super.key});
  @override
  State<AnalisisScreen> createState() => _AnalisisScreenState();
}

class _AnalisisScreenState extends State<AnalisisScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();

  // Datos cargados
  List<SorteoModel> _sorteos = [];

  // Base
  List<EstadisticaNumero> _calientes = [];
  List<EstadisticaNumero> _frios = [];
  List<EstadisticaNumero> _repetidosMes = [];
  Map<int, EstadisticaNumero>? _allStats;
  int _totalSorteos = 0;
  bool _loading = true;
  String? _error;

  // Derivados
  Map<int, int> _maxAusencias = {};
  Map<int, Map<String, int>> _porHorario = {};
  Map<int, int> _totalPorDia = {};
  Map<int, List<MapEntry<int, int>>> _frecPorDia = {};
  List<MapEntry<String, int>> _pares = [];
  Map<int, List<MapEntry<int, int>>> _siguientesPorNumero = {};
  int? _numeroBuscado;

  // Búsqueda global
  String _searchGlobal = '';
  late TextEditingController _searchController;

  // Quebrados
  int? _numeroQuebradoAnalizado;
  late TextEditingController _quebradoCtrl;
  String _qPeriodo = 'historico';

  // Relaciones profundas
  Map<int, List<int>> _espejos = {};
  Map<int, List<int>> _sumas = {};
  Map<int, List<int>> _cruzados = {};
  Map<int, Map<String, dynamic>> _estadisticasProfundas = {};
  Map<int, List<MapEntry<int, int>>> _secuenciasHistoricas = {};
  Map<int, Map<String, dynamic>> _prediccionesProfundas = {};

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
    _quebradoCtrl = TextEditingController();
    _tabController = TabController(length: 6, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _quebradoCtrl.dispose();
    super.dispose();
  }

  // ── CARGA ────────────────────────────────────────────────────────────────────

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sorteos = await _service.obtenerTodosLosSorteos();
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
          _totalSorteos = sorteos.length * 3;
          _maxAusencias = _computeMaxAusencias(allStats);
          _porHorario = _computePorHorario(sorteos);
          _totalPorDia = _computeTotalPorDia(sorteos);
          _frecPorDia = _computeFrecPorDia(sorteos);
          _pares = _computePares(sorteos);
          _siguientesPorNumero = _computeSiguientes(sorteos);
          _espejos = _computeEspejos();
          _sumas = _computeSumas();
          _cruzados = _computeCruzados();
          _estadisticasProfundas = _computeEstadisticasProfundas(sorteos);
          _secuenciasHistoricas = _computeSecuenciasHistoricas(sorteos);
          _prediccionesProfundas = _computePrediccionesProfundas(sorteos);
          _repetidosMes = _computeRepetidosMes(sorteos);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
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

  Map<int, int> _computeMaxAusencias(Map<int, EstadisticaNumero> stats) {
    final Map<int, int> result = {};
    for (final e in stats.entries) {
      final ap = [...e.value.apariciones]..sort();
      if (ap.length < 2) {
        result[e.key] = 0;
        continue;
      }
      int maxGap = 0;
      for (int i = 1; i < ap.length; i++) {
        final gap = ap[i].difference(ap[i - 1]).inDays;
        if (gap > maxGap) maxGap = gap;
      }
      result[e.key] = maxGap;
    }
    return result;
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

  Map<int, List<MapEntry<int, int>>> _computeSiguientes(
    List<SorteoModel> sorteos,
  ) {
    final List<int> secuencia = [];
    final sortedSorteos = sorteos..sort((a, b) => a.fecha.compareTo(b.fecha));
    for (var s in sortedSorteos) {
      if (s.numeroManiana != null) secuencia.add(s.numeroManiana!);
      if (s.numeroTarde != null) secuencia.add(s.numeroTarde!);
      if (s.numeroNoche != null) secuencia.add(s.numeroNoche!);
    }
    final Map<int, Map<int, int>> conteo = {};
    for (int i = 0; i < secuencia.length - 1; i++) {
      int actual = secuencia[i];
      int siguiente = secuencia[i + 1];
      conteo.putIfAbsent(actual, () => {})[siguiente] =
          (conteo[actual]![siguiente] ?? 0) + 1;
    }
    return {
      for (var e in conteo.entries)
        e.key:
            (e.value.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
                .toList(),
    };
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

  Map<int, List<int>> _computeEspejos() {
    final Map<int, List<int>> espejos = {};
    for (int n = 0; n <= 99; n++) {
      final espejo = _getEspejo(n);
      if (espejo != n) {
        espejos.putIfAbsent(n, () => []).add(espejo);
        espejos.putIfAbsent(espejo, () => []).add(n);
      }
    }
    return espejos;
  }

  Map<int, List<int>> _computeSumas() {
    final Map<int, List<int>> sumas = {};
    for (int n = 0; n <= 99; n++) {
      final suma = _getSuma(n);
      if (suma != n && suma >= 0 && suma <= 99) {
        sumas.putIfAbsent(n, () => []).add(suma);
        sumas.putIfAbsent(suma, () => []).add(n);
      }
    }
    return sumas;
  }

  Map<int, List<int>> _computeCruzados() {
    final Map<int, List<int>> cruzados = {};
    for (int n = 0; n <= 99; n++) {
      final cruzado = _getCruzado(n);
      if (cruzado != n && cruzado >= 0 && cruzado <= 99) {
        cruzados.putIfAbsent(n, () => []).add(cruzado);
        cruzados.putIfAbsent(cruzado, () => []).add(n);
      }
    }
    return cruzados;
  }

  Map<int, Map<String, dynamic>> _computeEstadisticasProfundas(
    List<SorteoModel> sorteos,
  ) {
    final Map<int, Map<String, dynamic>> stats = {};

    for (int n = 0; n <= 99; n++) {
      final apariciones = <DateTime>[];
      final diasSemana = <int, int>{};
      final horarios = <String, int>{};

      for (var sorteo in sorteos) {
        if (sorteo.numeroManiana != null && sorteo.numeroManiana == n) {
          apariciones.add(sorteo.fecha);
          diasSemana[sorteo.fecha.weekday] =
              (diasSemana[sorteo.fecha.weekday] ?? 0) + 1;
          horarios['M'] = (horarios['M'] ?? 0) + 1;
        }
        if (sorteo.numeroTarde != null && sorteo.numeroTarde == n) {
          apariciones.add(sorteo.fecha);
          diasSemana[sorteo.fecha.weekday] =
              (diasSemana[sorteo.fecha.weekday] ?? 0) + 1;
          horarios['T'] = (horarios['T'] ?? 0) + 1;
        }
        if (sorteo.numeroNoche != null && sorteo.numeroNoche == n) {
          apariciones.add(sorteo.fecha);
          diasSemana[sorteo.fecha.weekday] =
              (diasSemana[sorteo.fecha.weekday] ?? 0) + 1;
          horarios['N'] = (horarios['N'] ?? 0) + 1;
        }
      }

      if (apariciones.isNotEmpty) {
        final diaMasFrecuente = diasSemana.entries.fold<MapEntry<int, int>?>(
          null,
          (prev, curr) => prev == null || curr.value > prev.value ? curr : prev,
        );

        final horarioMasFrecuente = horarios.entries
            .fold<MapEntry<String, int>?>(
              null,
              (prev, curr) =>
                  prev == null || curr.value > prev.value ? curr : prev,
            );

        stats[n] = {
          'totalApariciones': apariciones.length,
          'diaMasFrecuente': diaMasFrecuente?.key ?? 0,
          'diaFrecuencia': diaMasFrecuente?.value ?? 0,
          'horarioMasFrecuente': horarioMasFrecuente?.key ?? '',
          'horarioFrecuencia': horarioMasFrecuente?.value ?? 0,
          'ultimaAparicion': apariciones.last,
        };
      }
    }

    return stats;
  }

  Map<int, List<MapEntry<int, int>>> _computeSecuenciasHistoricas(
    List<SorteoModel> sorteos,
  ) {
    final Map<int, Map<int, int>> secuencias = {};

    // Analizar secuencias de 3 sorteos consecutivos
    final sortedSorteos = sorteos..sort((a, b) => a.fecha.compareTo(b.fecha));
    final secuenciaNumeros = <int>[];

    for (var sorteo in sortedSorteos) {
      if (sorteo.numeroManiana != null) {
        secuenciaNumeros.add(sorteo.numeroManiana!);
      }
      if (sorteo.numeroTarde != null) secuenciaNumeros.add(sorteo.numeroTarde!);
      if (sorteo.numeroNoche != null) secuenciaNumeros.add(sorteo.numeroNoche!);
    }

    // Buscar patrones: si A salió, luego B, ¿qué sigue?
    for (int i = 0; i < secuenciaNumeros.length - 2; i++) {
      final actual = secuenciaNumeros[i];
      final siguiente = secuenciaNumeros[i + 1];
      final despues = secuenciaNumeros[i + 2];

      secuencias.putIfAbsent(actual, () => {});
      secuencias[actual]!.putIfAbsent(siguiente, () => 0);
      secuencias[actual]![siguiente] = secuencias[actual]![siguiente]! + 1;

      // También registrar qué números siguen después de esta secuencia
      final key =
          actual * 100 +
          siguiente; // Crear una clave única para la secuencia A->B
      secuencias.putIfAbsent(key, () => {});
      secuencias[key]!.putIfAbsent(despues, () => 0);
      secuencias[key]![despues] = secuencias[key]![despues]! + 1;
    }

    return secuencias.map(
      (key, value) => MapEntry(
        key,
        value.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
      ),
    );
  }

  Map<int, Map<String, dynamic>> _computePrediccionesProfundas(
    List<SorteoModel> sorteos,
  ) {
    final Map<int, Map<String, dynamic>> predicciones = {};

    for (int n = 0; n <= 99; n++) {
      final relacionados = <int>[];
      final explicaciones = <String>[];
      final confianza = <double>[];

      // 1. Espejos
      final espejo = _getEspejo(n);
      if (espejo != n) {
        relacionados.add(espejo);
        explicaciones.add('Espejo directo');
        confianza.add(0.7);
      }

      // 2. Sumas y operaciones matemáticas
      final suma = _getSuma(n);
      if (suma >= 0 && suma <= 99 && suma != n) {
        relacionados.add(suma);
        explicaciones.add('Suma de dígitos');
        confianza.add(0.5);
      }

      // 3. Cruzados
      final cruzado = _getCruzado(n);
      if (cruzado != n && cruzado >= 0 && cruzado <= 99) {
        relacionados.add(cruzado);
        explicaciones.add('Dígitos cruzados');
        confianza.add(0.6);
      }

      // 4. Análisis de frecuencia reciente (últimos 30 días)
      final fechaLimite = DateTime.now().subtract(const Duration(days: 30));
      final aparicionesRecientes = sorteos
          .where(
            (s) =>
                (s.numeroManiana == n ||
                    s.numeroTarde == n ||
                    s.numeroNoche == n) &&
                s.fecha.isAfter(fechaLimite),
          )
          .length;

      // 5. Análisis de secuencias históricas
      final secuencias = _secuenciasHistoricas[n] ?? [];
      if (secuencias.isNotEmpty) {
        final masProbable = secuencias.first.key;
        if (!relacionados.contains(masProbable)) {
          relacionados.add(masProbable);
          explicaciones.add('Patrón histórico frecuente');
          confianza.add(0.8);
        }
      }

      // 6. Análisis por día de la semana
      final stats = _estadisticasProfundas[n];
      if (stats != null) {
        final diaActual = DateTime.now().weekday;
        final diaMasFrecuente = stats['diaMasFrecuente'] as int;

        if (diaActual == diaMasFrecuente) {
          explicaciones.add('Día favorable (${_diasNombre[diaMasFrecuente]})');
          confianza.add(0.4);
        }
      }

      // 7. Análisis de rachas (si está cerca de salir)
      final racha = _allStats?[n]?.diasSinSalir() ?? 0;
      final maxRacha = _maxAusencias[n] ?? 0;

      if (maxRacha > 0) {
        final ratio = racha / maxRacha;
        if (ratio > 0.8) {
          explicaciones.add('Cerca de récord de ausencia');
          confianza.add(0.9);
        } else if (ratio > 0.6) {
          explicaciones.add('Ausencia prolongada');
          confianza.add(0.7);
        }
      }

      // Crear lista ordenada por confianza
      final resultados = <Map<String, dynamic>>[];
      for (int i = 0; i < relacionados.length; i++) {
        resultados.add({
          'numero': relacionados[i],
          'explicacion': explicaciones[i],
          'confianza': confianza[i],
          'significado': significadoCorto(relacionados[i]),
        });
      }

      resultados.sort(
        (a, b) =>
            (b['confianza'] as double).compareTo(a['confianza'] as double),
      );

      predicciones[n] = {
        'predicciones': resultados.take(8).toList(), // Top 8 predicciones
        'aparicionesRecientes': aparicionesRecientes,
        'rachaActual': racha,
        'maxRacha': maxRacha,
      };
    }

    return predicciones;
  }

  int _getEspejo(int numero) {
    final str = numero.toString().padLeft(2, '0');
    return int.parse(str[1] + str[0]);
  }

  int _getSuma(int numero) {
    final d1 = numero ~/ 10;
    final d2 = numero % 10;
    return (d1 + d2) % 10;
  }

  int _getCruzado(int numero) {
    final d1 = numero ~/ 10;
    final d2 = numero % 10;
    return d2 * 10 + d1;
  }

  int _getQuebrado(int numero) {
    const Map<int, int> quebrados = {
      0: 0,
      1: 1,
      2: 5,
      5: 2,
      6: 9,
      9: 6,
      7: 1,
      8: 8,
    };
    final str = numero.toString().padLeft(2, '0');
    final d1 = quebrados[int.parse(str[0])] ?? int.parse(str[0]);
    final d2 = quebrados[int.parse(str[1])] ?? int.parse(str[1]);
    return d1 * 10 + d2;
  }

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
            Tab(icon: Icon(Icons.psychology_rounded), text: 'Predicciones'),
            Tab(icon: Icon(Icons.grid_view_rounded), text: 'Quebrados'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: _buildBuscadorUnificado(),
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
                      _buildTabPredicciones(),
                      _buildTabQuebrados(),
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
                _numeroBuscado = stat.numero;
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
                _numeroBuscado = numero;
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

  // ── TAB 6: PREDICCIONES ────────────────────────────────────────────────────────

  Widget _buildTabPredicciones() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🔮 Predicciones Inteligentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Busca un número específico para análisis detallado o filtra todos los números por patrón.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _numeroBuscado != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAnalisisDetallado(_numeroBuscado!),
                )
              : _buildPrediccionesFiltradas(),
        ),
      ],
    );
  }

  Widget _buildBuscadorUnificado() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF0a2a5e)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldColor.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: TextField(
        controller: _searchController,
        keyboardType: TextInputType.text,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Número (0-99) o significado...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: AppTheme.goldColor),
          suffixIcon: _searchGlobal.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.goldColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchGlobal = '';
                      _numeroBuscado = null;
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchGlobal = value;
            // Si es un número válido, mostrar análisis específico
            final num = int.tryParse(value);
            _numeroBuscado = (num != null && num >= 0 && num <= 99)
                ? num
                : null;
          });
        },
      ),
    );
  }

  Widget _buildPrediccionesFiltradas() {
    if (_allStats == null) return const SizedBox();

    final filteredNumbers = _searchGlobal.isEmpty
        ? List.generate(100, (i) => i)
        : List.generate(100, (i) => i).where((n) {
            final num = n.toString().padLeft(2, '0');
            final sig = significadoCorto(n).toLowerCase();
            return num.contains(_searchGlobal) ||
                sig.contains(_searchGlobal.toLowerCase());
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección especial de números reves/espejos destacados
          if (_searchGlobal.isEmpty) ...[
            _buildNumerosRevesDestacados(),
            const SizedBox(height: 20),
          ],

          Text(
            _searchGlobal.isEmpty
                ? '📈 Todas las Predicciones (${filteredNumbers.length})'
                : '🔍 Resultados para "$_searchGlobal" (${filteredNumbers.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),
          const Text(
            'Análisis inteligente de números basado en múltiples factores históricos.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),

          Column(
            children: [
              for (var n in filteredNumbers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPrediccionCard(n),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalisisDetallado(int numero) {
    final predicciones = _prediccionesProfundas[numero];
    final siguientes = _siguientesPorNumero[numero];
    final quebrado = _getQuebrado(numero);
    final mayorQuebrado = (quebrado + 1) % 100;
    final menorQuebrado = (quebrado - 1 + 100) % 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Número analizado
        Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.goldColor, AppTheme.orangeColor],
                ),
                borderRadius: BorderRadius.circular(16),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    significadoCorto(numero),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Análisis completo de patrones y predicciones',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ¿Por qué salió este número?
        const Text(
          '❓ ¿Por qué salió este número?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (predicciones != null) ...[
          _buildExplicacionCard(
            '📊 Apariciones recientes',
            'En los últimos 30 días: ${predicciones['aparicionesRecientes']} veces',
            predicciones['aparicionesRecientes'] > 2
                ? Colors.green
                : Colors.orange,
          ),

          if (predicciones['rachaActual'] > 0) ...[
            const SizedBox(height: 8),
            _buildExplicacionCard(
              '⏰ Racha actual',
              'Sin salir: ${predicciones['rachaActual']} días (máximo histórico: ${predicciones['maxRacha']} días)',
              (predicciones['rachaActual'] / (predicciones['maxRacha'] ?? 1)) >
                      0.8
                  ? Colors.red
                  : Colors.blue,
            ),
          ],
        ],

        const SizedBox(height: 20),

        // ¿Qué debía seguir?
        const Text(
          '🎪 ¿Qué números debían seguir?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (siguientes != null && siguientes.isNotEmpty) ...[
          ...siguientes
              .take(5)
              .map(
                (siguiente) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accentColor),
                          ),
                          child: Center(
                            child: Text(
                              siguiente.key.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${siguiente.key.toString().padLeft(2, '0')} - ${significadoCorto(siguiente.key)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${siguiente.value} veces ha salido después',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.goldColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${siguiente.value}x',
                            style: const TextStyle(
                              color: AppTheme.goldColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ] else ...[
          const Text(
            'No hay suficientes datos históricos para este número.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],

        const SizedBox(height: 20),

        // Predicciones profundas
        const Text(
          '🔮 Predicciones basadas en patrones',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        if (predicciones != null &&
            predicciones['predicciones'].isNotEmpty) ...[
          ...predicciones['predicciones'].map(
            (pred) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          pred['numero'].toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pred['numero'].toString().padLeft(2, '0')} - ${pred['significado']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            pred['explicacion'],
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getConfianzaColor(pred['confianza']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(pred['confianza'] * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Números quebrados
        const Text(
          '🔄 Números Quebrados',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _buildExplicacionCard(
          'Número quebrado',
          '$quebrado (${significadoCorto(quebrado)})',
          Colors.blue,
        ),

        const SizedBox(height: 8),

        _buildExplicacionCard(
          'Mayor al quebrado',
          '$mayorQuebrado (${significadoCorto(mayorQuebrado)})',
          Colors.green,
        ),

        const SizedBox(height: 8),

        _buildExplicacionCard(
          'Menor al quebrado',
          '$menorQuebrado (${significadoCorto(menorQuebrado)})',
          Colors.orange,
        ),

        const SizedBox(height: 20),

        // Números relacionados con datos históricos
        const Text(
          '🔗 Números Relacionados (con historial)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        _buildNumerosRelacionadosHistoricos(numero),
      ],
    );
  }

  Widget _buildNumerosRelacionadosHistoricos(int numero) {
    final relacionados = <Map<String, dynamic>>[];

    // Espejos
    final espejo = _getEspejo(numero);
    if (espejo != numero) {
      final statsEspejo = _allStats?[espejo];
      if (statsEspejo != null) {
        relacionados.add({
          'numero': espejo,
          'tipo': 'Espejo',
          'icono': '🪞',
          'color': Colors.red,
          'frecuencia': statsEspejo.frecuencia,
          'diasSinSalir': statsEspejo.diasSinSalir(),
          'probabilidad': statsEspejo.frecuencia / _totalSorteos * 100,
        });
      }
    }

    // Sumas
    final suma = _getSuma(numero);
    if (suma >= 0 && suma <= 99 && suma != numero) {
      final statsSuma = _allStats?[suma];
      if (statsSuma != null) {
        relacionados.add({
          'numero': suma,
          'tipo': 'Suma de dígitos',
          'icono': '➕',
          'color': Colors.green,
          'frecuencia': statsSuma.frecuencia,
          'diasSinSalir': statsSuma.diasSinSalir(),
          'probabilidad': statsSuma.frecuencia / _totalSorteos * 100,
        });
      }
    }

    // Cruzados
    final cruzado = _getCruzado(numero);
    if (cruzado != numero && cruzado >= 0 && cruzado <= 99) {
      final statsCruzado = _allStats?[cruzado];
      if (statsCruzado != null) {
        relacionados.add({
          'numero': cruzado,
          'tipo': 'Dígitos cruzados',
          'icono': '🔄',
          'color': Colors.blue,
          'frecuencia': statsCruzado.frecuencia,
          'diasSinSalir': statsCruzado.diasSinSalir(),
          'probabilidad': statsCruzado.frecuencia / _totalSorteos * 100,
        });
      }
    }

    if (relacionados.isEmpty) {
      return const Text(
        'No hay números relacionados con datos históricos suficientes.',
        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
      );
    }

    // Ordenar por frecuencia (más frecuentes primero)
    relacionados.sort(
      (a, b) => (b['frecuencia'] as int).compareTo(a['frecuencia'] as int),
    );

    return Column(
      children: relacionados
          .map(
            (rel) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Tipo de relación
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: rel['color'].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: rel['color']),
                      ),
                      child: Center(
                        child: Text(
                          rel['icono'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Número y significado
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [rel['color'], rel['color'].shade600],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          rel['numero'].toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Información detallada
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${rel['numero'].toString().padLeft(2, '0')} - ${significadoCorto(rel['numero'])}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                rel['tipo'],
                                style: TextStyle(
                                  color: rel['color'],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Frecuencia: ${rel['frecuencia']}x',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Sin salir: ${rel['diasSinSalir']}d',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Probabilidad histórica: ${(rel['probabilidad'] as double).toStringAsFixed(2)}%',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Indicador de "caliente" o "frío"
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: rel['diasSinSalir'] < 7
                            ? Colors.green.withValues(alpha: 0.2)
                            : rel['diasSinSalir'] > 14
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: rel['diasSinSalir'] < 7
                              ? Colors.green
                              : rel['diasSinSalir'] > 14
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        rel['diasSinSalir'] < 7
                            ? '🔥'
                            : rel['diasSinSalir'] > 14
                            ? '❄️'
                            : '⚖️',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildNumerosRevesDestacados() {
    if (_allStats == null) return const SizedBox();

    // Calcular números espejo destacados
    final revesDestacados = <Map<String, dynamic>>[];

    for (int n = 0; n <= 99; n++) {
      final espejo = _getEspejo(n);
      if (espejo <= n) continue; // Evitar duplicados

      final statsN = _allStats![n]!;
      final statsEspejo = _allStats![espejo]!;

      // Calcular puntuación de "destacado" basada en múltiples factores
      final frecuenciaTotal = statsN.frecuencia + statsEspejo.frecuencia;
      final diasSinSalirPromedio =
          (statsN.diasSinSalir() + statsEspejo.diasSinSalir()) / 2;
      final esCaliente = diasSinSalirPromedio < 7;
      final esFrio = diasSinSalirPromedio > 21;

      // Puntuación: frecuencia alta + estado caliente o muy frío
      final puntuacion =
          (frecuenciaTotal * 10 +
                  (esCaliente ? 50 : 0) +
                  (esFrio ? 30 : 0) +
                  (diasSinSalirPromedio < 14 ? 20 : 0))
              .toDouble();

      revesDestacados.add({
        'numero1': n,
        'numero2': espejo,
        'frecuenciaTotal': frecuenciaTotal,
        'diasSinSalirPromedio': diasSinSalirPromedio,
        'esCaliente': esCaliente,
        'esFrio': esFrio,
        'puntuacion': puntuacion,
      });
    }

    // Ordenar por puntuación descendente y tomar los top 8
    revesDestacados.sort(
      (a, b) => (b['puntuacion'] as num).compareTo(a['puntuacion'] as num),
    );
    final topReves = revesDestacados.take(8).toList();

    if (topReves.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '🪞 Números Espejo Destacados',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple),
              ),
              child: const Text(
                'TOP 8',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Parejas de números espejo con mejor rendimiento histórico y estado actual.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            // aspecto más bajo para maximizar altura de tarjeta
            childAspectRatio: 1.0,
          ),
          itemCount: topReves.length,
          itemBuilder: (ctx, i) {
            final rev = topReves[i];
            final num1 = rev['numero1'] as int;
            final num2 = rev['numero2'] as int;
            final esCaliente = rev['esCaliente'] as bool;
            final esFrio = rev['esFrio'] as bool;

            return Card(
              elevation: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: esCaliente
                        ? [Colors.green.shade50, Colors.green.shade100]
                        : esFrio
                        ? [Colors.blue.shade50, Colors.blue.shade100]
                        : [Colors.grey.shade50, Colors.grey.shade100],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: esCaliente
                        ? Colors.green
                        : esFrio
                        ? Colors.blue
                        : Colors.grey,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Números espejo
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              num1.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('🪞', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              num2.toString().padLeft(2, '0'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Estadísticas
                    Text(
                      '${rev['frecuenciaTotal']} apariciones totales',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rev['diasSinSalirPromedio'].toStringAsFixed(1)}d promedio sin salir',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),

                    // Estado
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: esCaliente
                            ? Colors.green.withValues(alpha: 0.2)
                            : esFrio
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: esCaliente
                              ? Colors.green
                              : esFrio
                              ? Colors.blue
                              : Colors.orange,
                        ),
                      ),
                      child: Text(
                        esCaliente
                            ? '🔥 Caliente'
                            : esFrio
                            ? '❄️ Muy frío'
                            : '⚖️ Normal',
                        style: TextStyle(
                          color: esCaliente
                              ? Colors.green
                              : esFrio
                              ? Colors.blue
                              : Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildExplicacionCard(String titulo, String descripcion, Color color) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descripcion,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── QUEBRADOS: lógica ────────────────────────────────────────────────────────

  List<int> _equivalentesDigito(int d) {
    switch (d) {
      case 0: return [0, 1, 7, 4];      // familia del 0/1 (sin 8)
      case 1: return [1, 0, 7, 4];
      case 2: return [2, 5];
      case 3: return [3, 8];
      case 4: return [4, 7, 1, 0];
      case 5: return [5, 2];
      case 6: return [6, 9];
      case 7: return [7, 4, 1, 0];
      case 8: return [8, 3];             // familia del 8 (separada del 0)
      case 9: return [9, 6];
      default: return [d];
    }
  }

  /// Quebrados directos: aplica equivalencias a los dígitos del número
  /// tal como es, SIN hacer la sumatoria. Genera el revés y sustituciones.
  Map<String, List<int>> _quebradosDirectosCat(int numero) {
    final d1 = numero ~/ 10;
    final d2 = numero % 10;
    final subs1 = _equivalentesDigito(d1).where((d) => d != d1).toList();
    final subs2 = _equivalentesDigito(d2).where((d) => d != d2).toList();

    void addPar(Set<int> set, int a, int b) {
      set.add(a * 10 + b);
      if (a != b) set.add(b * 10 + a);
    }

    final reves = <int>{};
    final unDigito = <int>{};
    final ambos = <int>{};

    if (d1 != d2) reves.add(d2 * 10 + d1);

    for (final s in subs1) { addPar(unDigito, s, d2); }
    for (final s in subs2) { addPar(unDigito, d1, s); }

    for (final s1 in subs1) {
      for (final s2 in subs2) { addPar(ambos, s1, s2); }
    }

    reves.remove(numero);
    unDigito.remove(numero);
    ambos.remove(numero);
    unDigito.removeAll(reves);
    ambos.removeAll(reves);
    ambos.removeAll(unDigito);

    return {
      'reves': reves.toList()..sort(),
      'unDigito': unDigito.toList()..sort(),
      'ambos': ambos.toList()..sort(),
    };
  }

  /// Devuelve quebrados categorizados en 3 niveles:
  /// - fuertes: AMBOS dígitos de la suma son sustituidos
  /// - normales: solo UNO de los dígitos es sustituido
  /// - basicos: ninguno sustituido (la suma y su espejo)
  ///
  /// Regla "010": cuando la suma termina en 0 (ej: 6+4=10 → "010"),
  /// ese 0 final une las familias 0/1 y 8/3 (0 y 8 son equivalentes
  /// únicamente en este caso especial).
  Map<String, List<int>> _categorizarQuebrados(int numero) {
    final d1 = numero ~/ 10;
    final d2 = numero % 10;
    final suma = d1 + d2;
    final sa = suma ~/ 10;
    final sb = suma % 10;

    // Regla "010": sb=0 con sa>0 (suma como 10, 20...) — el 0 final
    // equivale a toda la familia 0-1-7-4 Y también a 8-3.
    final eqA = _equivalentesDigito(sa);
    final eqB = (sb == 0 && sa > 0)
        ? const [0, 1, 7, 4, 8, 3]
        : _equivalentesDigito(sb);
    final subsA = eqA.where((d) => d != sa).toList();
    final subsB = eqB.where((d) => d != sb).toList();

    final fuertes = <int>{};
    final normales = <int>{};
    final basicos = <int>{};

    // Básicos: ningún dígito cambia (solo la suma y su espejo)
    void addPar(Set<int> set, int a, int b) {
      set.add(a * 10 + b);
      if (a != b) set.add(b * 10 + a);
    }

    addPar(basicos, sa, sb);

    // Normales: solo un dígito cambia
    for (final a in subsA) {
      addPar(normales, a, sb);
    }
    for (final b in subsB) {
      addPar(normales, sa, b);
    }

    // Fuertes: ambos dígitos cambian
    for (final a in subsA) {
      for (final b in subsB) {
        addPar(fuertes, a, b);
      }
    }

    // Limpiar duplicados entre categorías (fuerte > normal > basico)
    normales.removeAll(basicos);
    fuertes
      ..removeAll(basicos)
      ..removeAll(normales);

    // Quitar el número original de todas
    fuertes.remove(numero);
    normales.remove(numero);
    basicos.remove(numero);

    return {
      'fuertes': (fuertes.toList()..sort()),
      'normales': (normales.toList()..sort()),
      'basicos': (basicos.toList()..sort()),
    };
  }

  // ── TAB QUEBRADOS: UI ────────────────────────────────────────────────────────

  Widget _buildTabQuebrados() {
    final faltanMes = _numerosNoSalidosMesActual().toSet();
    final numero = _numeroQuebradoAnalizado;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, Color(0xFF0a2a5e)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.goldColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: TextField(
              controller: _quebradoCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ingresá un número (0-99)...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(
                  Icons.grid_view_rounded,
                  color: AppTheme.goldColor,
                ),
                suffixIcon: _numeroQuebradoAnalizado != null
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppTheme.goldColor),
                        onPressed: () {
                          _quebradoCtrl.clear();
                          setState(() => _numeroQuebradoAnalizado = null);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (val) {
                final n = int.tryParse(val);
                setState(() {
                  _numeroQuebradoAnalizado =
                      (n != null && n >= 0 && n <= 99) ? n : null;
                });
              },
            ),
          ),
        ),
        if (numero == null)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Ingresá un número para ver sus quebrados',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildQuebradosDetalle(numero, faltanMes),
            ),
          ),
      ],
    );
  }

  // ── PATRÓN HISTÓRICO DE QUEBRADO ─────────────────────────────────────────────

  Set<int> _todosQuebrados(int numero) {
    final cats = _categorizarQuebrados(numero);
    final dir  = _quebradosDirectosCat(numero);
    return {
      ...cats['fuertes']!,
      ...cats['normales']!,
      ...cats['basicos']!,
      ...dir['reves']!,
      ...dir['unDigito']!,
      ...dir['ambos']!,
    };
  }

  /// Analiza cuántas veces tras caer [numero] su quebrado apareció
  /// dentro de los siguientes [maxLag] sorteos.
  Map<String, dynamic> _analizarPatronQuebrado(int numero) {
    // Aplanar todos los sorteos en secuencia: más viejo → más reciente
    final draws = <({DateTime fecha, String slot, int valor})>[];
    for (final s in _sorteos.reversed) {
      if (s.numeroManiana != null) {
        draws.add((fecha: s.fecha, slot: 'mañana', valor: s.numeroManiana!));
      }
      if (s.numeroTarde != null) {
        draws.add((fecha: s.fecha, slot: 'tarde', valor: s.numeroTarde!));
      }
      if (s.numeroNoche != null) {
        draws.add((fecha: s.fecha, slot: 'noche', valor: s.numeroNoche!));
      }
    }

    const maxLag = 9; // hasta 3 días (9 sorteos)
    final qs = _todosQuebrados(numero);

    int totalOcurrencias = 0;
    int conQuebrado = 0;
    int sumLag = 0;
    final lagCount  = <int, int>{};  // lag en sorteos → frecuencia
    final slotCount = <String, int>{};
    final cadenas   = <Map<String, dynamic>>[];

    for (int i = 0; i < draws.length; i++) {
      if (draws[i].valor != numero) continue;
      totalOcurrencias++;

      for (int lag = 1; lag <= maxLag && i + lag < draws.length; lag++) {
        final next = draws[i + lag];
        if (!qs.contains(next.valor)) continue;
        conQuebrado++;
        sumLag += lag;
        lagCount[lag] = (lagCount[lag] ?? 0) + 1;
        slotCount[next.slot] = (slotCount[next.slot] ?? 0) + 1;
        cadenas.add({
          'fechaOrigen': draws[i].fecha,
          'slotOrigen': draws[i].slot,
          'fechaQ': next.fecha,
          'slotQ': next.slot,
          'quebrado': next.valor,
          'lag': lag,
        });
        break; // solo primer quebrado tras cada ocurrencia
      }
    }

    return {
      'total': totalOcurrencias,
      'conQuebrado': conQuebrado,
      'avgLag': conQuebrado > 0 ? sumLag / conQuebrado : 0.0,
      'lagCount': lagCount,
      'slotCount': slotCount,
      'cadenas': cadenas.reversed.take(6).toList(),
    };
  }

  // ── TOP 5 CANDIDATOS ─────────────────────────────────────────────────────────

  String _categoriaLabel(int n, Map<String, List<int>> cats, Map<String, List<int>> dir) {
    if (cats['fuertes']!.contains(n)) return 'Fuerte';
    if (dir['reves']!.contains(n)) return 'Dir. revés';
    if (dir['unDigito']!.contains(n)) return 'Directo';
    if (cats['normales']!.contains(n)) return 'Normal';
    if (dir['ambos']!.contains(n)) return 'Dir. ambos';
    return 'Base';
  }

  List<({int numero, int score, String categoria, int vecesTraX, int diasSin, int freqGen, bool mismoGrupo})>
      _top5Candidatos(int numero) {
    final cats = _categorizarQuebrados(numero);
    final dir  = _quebradosDirectosCat(numero);

    // Peso base por categoría
    final pesos = <int, double>{};
    for (final n in cats['fuertes']!)  { pesos[n] = (pesos[n] ?? 0) + 10; }
    for (final n in dir['reves']!)     { pesos[n] = (pesos[n] ?? 0) + 9; }
    for (final n in dir['unDigito']!)  { pesos[n] = (pesos[n] ?? 0) + 8; }
    for (final n in cats['normales']!) { pesos[n] = (pesos[n] ?? 0) + 6; }
    for (final n in dir['ambos']!)     { pesos[n] = (pesos[n] ?? 0) + 5; }
    for (final n in cats['basicos']!)  { pesos[n] = (pesos[n] ?? 0) + 4; }

    // Historial: cuántas veces cada candidato apareció dentro de 9 sorteos tras `numero`
    final draws = <int>[];
    for (final s in _sorteos.reversed) {
      if (s.numeroManiana != null) draws.add(s.numeroManiana!);
      if (s.numeroTarde   != null) draws.add(s.numeroTarde!);
      if (s.numeroNoche   != null) draws.add(s.numeroNoche!);
    }
    final vecesTraX = <int, int>{};
    for (int i = 0; i < draws.length; i++) {
      if (draws[i] != numero) continue;
      for (int lag = 1; lag <= 9 && i + lag < draws.length; lag++) {
        final next = draws[i + lag];
        if (pesos.containsKey(next)) {
          vecesTraX[next] = (vecesTraX[next] ?? 0) + 1;
          break;
        }
      }
    }

    // Grupo semántico del número analizado
    final grupoOrigen = grupoDeNumero(numero);

    // Score final
    final scored = pesos.entries.map((e) {
      final n         = e.key;
      final cat       = e.value;
      final freq      = _allStats?[n]?.frecuencia ?? 0;
      final dias      = _allStats?[n]?.diasSinSalir() ?? 0;
      final after     = vecesTraX[n] ?? 0;
      final mismoGrupo = grupoOrigen != null && grupoDeNumero(n) == grupoOrigen;
      final score = cat
          + after * 3
          + freq * 0.2
          + (dias > 7  ? 3.0 : 0)
          + (dias > 14 ? 2.0 : 0)
          + (dias > 21 ? 2.0 : 0)
          + (mismoGrupo ? 4.0 : 0);   // bonus semántico
      return (
        numero: n,
        score: score.round(),
        categoria: _categoriaLabel(n, cats, dir),
        vecesTraX: after,
        diasSin: dias,
        freqGen: freq,
        mismoGrupo: mismoGrupo,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(5).toList();
  }

  // ── HELPERS QUEBRADOS ────────────────────────────────────────────────────────

  int _frecPeriodo(int n) {
    if (_qPeriodo == 'historico') return _allStats?[n]?.frecuencia ?? 0;
    final ahora = DateTime.now();
    return _sorteos.fold(0, (acc, s) {
      final ok = _qPeriodo == 'mes'
          ? s.fecha.year == ahora.year && s.fecha.month == ahora.month
          : s.fecha.year == ahora.year;
      if (!ok) return acc;
      return acc +
          (s.numeroManiana == n ? 1 : 0) +
          (s.numeroTarde == n ? 1 : 0) +
          (s.numeroNoche == n ? 1 : 0);
    });
  }

  List<int> _ordenarPorFrec(List<int> nums) =>
      [...nums]..sort((a, b) => _frecPeriodo(b).compareTo(_frecPeriodo(a)));

  Widget _buildPeriodoSelector() {
    const opciones = [('mes', 'Mes'), ('anio', 'Año'), ('historico', 'Total')];
    return Row(
      children: [
        const Text('Ordenar por: ', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ...opciones.map((p) {
          final sel = _qPeriodo == p.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: GestureDetector(
              onTap: () => setState(() => _qPeriodo = p.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.goldColor.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? AppTheme.goldColor : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  p.$2,
                  style: TextStyle(
                    fontSize: 10,
                    color: sel ? AppTheme.goldColor : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPatronContenido(Map<String, dynamic> patron, int numero) {
    final total     = patron['total']      as int;
    final conQ      = patron['conQuebrado'] as int;
    final avgLag    = patron['avgLag']      as double;
    final slotCount = patron['slotCount']   as Map<String, int>;
    final lagCount  = patron['lagCount']    as Map<int, int>;
    final cadenas   = patron['cadenas']     as List<Map<String, dynamic>>;
    final pct       = total > 0 ? (conQ / total * 100).round() : 0;

    String slotTop = '-';
    if (slotCount.isNotEmpty) {
      slotTop = slotCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    int lagTop = 0;
    if (lagCount.isNotEmpty) {
      lagTop = lagCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }
    final lagLabel = lagTop == 0 ? '-'
        : lagTop == 1 ? 'sorteo siguiente'
        : lagTop <= 3 ? 'mismo día'
        : lagTop <= 6 ? 'al día siguiente'
        : 'a los 2-3 días';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatChip('Cayó', '$total veces', Colors.teal),
            _buildStatChip('Con quebrado', '$conQ ($pct%)', conQ > 0 ? Colors.green : Colors.grey),
            _buildStatChip('Lag promedio', '${avgLag.toStringAsFixed(1)} sorteos', Colors.blue),
            _buildStatChip('Más frecuente', lagLabel, Colors.orange),
            _buildStatChip('Turno habitual', slotTop, Colors.purple),
          ],
        ),
        if (cadenas.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Últimas cadenas:', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          ...cadenas.map((c) {
            final fO  = c['fechaOrigen'] as DateTime;
            final fQ  = c['fechaQ']      as DateTime;
            final lag = c['lag']         as int;
            final q   = c['quebrado']    as int;
            final sO  = c['slotOrigen']  as String;
            final sQ  = c['slotQ']       as String;
            final mismodia = fO.year == fQ.year && fO.month == fQ.month && fO.day == fQ.day;
            final cuando = mismodia ? 'mismo día' : '+${fQ.difference(fO).inDays}d';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    '${fO.day.toString().padLeft(2, '0')}/${fO.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  Text(numero.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.goldColor)),
                  Text(' ($sO)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                  ),
                  Text(q.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const SizedBox(width: 3),
                  Text(significadoCorto(q),
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  Text(' ($sQ)', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$cuando · lag $lag',
                        style: const TextStyle(fontSize: 9, color: Colors.teal)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCardQ({
    required String titulo,
    required String descripcion,
    required Color color,
    required int count,
    required Widget contenido,
  }) {
    return Card(
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$count', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(descripcion, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 10),
            contenido,
          ],
        ),
      ),
    );
  }

  Widget _buildQuebradosDetalle(int numero, Set<int> faltanMes) {
    final d1 = numero ~/ 10;
    final d2 = numero % 10;
    final suma = d1 + d2;
    final directo    = _quebradosDirectosCat(numero);
    final patron     = _analizarPatronQuebrado(numero);
    final candidatos = _top5Candidatos(numero);
    final cats = _categorizarQuebrados(numero);
    final fuertes  = _ordenarPorFrec(cats['fuertes']!);
    final normales = _ordenarPorFrec(cats['normales']!);
    final basicos  = cats['basicos']!;
    final todos = [...fuertes, ...normales, ...basicos];
    final noSalieronMes = todos.where((n) => faltanMes.contains(n)).length;

    // Básicos: separar derecho (suma exacta) y revés
    final puntoStr = suma.toString().padLeft(2, '0');
    final saB = suma ~/ 10;
    final sbB = suma % 10;
    final derecho = saB * 10 + sbB;
    final reves   = sbB * 10 + saB;
    final basicosDerecho = basicos.where((n) => n == derecho).toList();
    final basicosReves   = basicos.where((n) => n == reves && n != derecho).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera ─────────────────────────────────────
        Card(
          color: AppTheme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.goldColor, AppTheme.orangeColor],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      numero.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$d1 + $d2 = $suma  →  punto $puntoStr',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fuertes.length} fuertes  •  $noSalieronMes sin salir este mes',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Top 5 Candidatos ──────────────────────────────
        Card(
          color: AppTheme.goldColor.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppTheme.goldColor.withValues(alpha: 0.4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🎯 Top 5 candidatos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Text('scored por categoría · historial · días sin salir', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 10),
                ...candidatos.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final c    = e.value;
                  final rankColor = rank == 1
                      ? AppTheme.goldColor
                      : rank == 2
                          ? Colors.grey.shade400
                          : rank == 3
                              ? Colors.brown.shade300
                              : Colors.grey.shade600;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '$rank',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: rankColor),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: rankColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: rankColor.withValues(alpha: 0.6)),
                          ),
                          child: Center(
                            child: Text(
                              c.numero.toString().padLeft(2, '0'),
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: rankColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                significadoCorto(c.numero),
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${c.categoria}  •  ${c.freqGen}x  •  ${c.diasSin}d sin salir',
                                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                                  ),
                                  if (c.mismoGrupo) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        grupoDeNumero(c.numero) ?? '',
                                        style: const TextStyle(fontSize: 8, color: Colors.teal),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('score ${c.score}', style: TextStyle(fontSize: 9, color: rankColor)),
                            if (c.vecesTraX > 0)
                              Text(
                                '${c.vecesTraX}x tras ${numero.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 9, color: Colors.teal),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // ── Leyenda ───────────────────────────────────────
        Row(
          children: [
            _buildLeyendaChip(Colors.red, 'No salió este mes'),
            const SizedBox(width: 16),
            _buildLeyendaChip(Colors.green, 'Ya salió este mes'),
          ],
        ),

        const SizedBox(height: 10),

        // ── Selector de período ───────────────────────────
        _buildPeriodoSelector(),

        const SizedBox(height: 12),

        // 1 ── Fuertes ─────────────────────────────────────
        _buildCardQ(
          titulo: '🔥 Quebrados Fuertes',
          descripcion: 'Ambos dígitos del punto sustituidos — mayor probabilidad',
          color: Colors.orange,
          count: fuertes.length,
          contenido: _buildGrillaNiveles(fuertes, faltanMes, grande: true),
        ),

        const SizedBox(height: 10),

        // 2 ── Quebrado directo ────────────────────────────
        _buildCardQ(
          titulo: '🔀 Quebrado directo',
          descripcion: 'Equivalencias sobre los dígitos del número tal como es (sin sumar)',
          color: Colors.purple,
          count: directo['reves']!.length + directo['unDigito']!.length + directo['ambos']!.length,
          contenido: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (directo['reves']!.isNotEmpty) ...[
                const Text('Revés:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 6),
                _buildGrillaNiveles(directo['reves']!, faltanMes, grande: false),
                const SizedBox(height: 10),
              ],
              if (directo['unDigito']!.isNotEmpty) ...[
                const Text('Un dígito sustituido:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 6),
                _buildGrillaNiveles(directo['unDigito']!, faltanMes, grande: false),
                const SizedBox(height: 10),
              ],
              if (directo['ambos']!.isNotEmpty) ...[
                const Text('Ambos dígitos sustituidos:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 6),
                _buildGrillaNiveles(directo['ambos']!, faltanMes, grande: false),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3 ── Normales ────────────────────────────────────
        _buildCardQ(
          titulo: '⚡ Quebrados Normales',
          descripcion: 'Un dígito del punto sustituido',
          color: Colors.blue,
          count: normales.length,
          contenido: _buildGrillaNiveles(normales, faltanMes, grande: false),
        ),

        const SizedBox(height: 10),

        // 4 ── Punto base ──────────────────────────────────
        _buildCardQ(
          titulo: '🔵 Punto base',
          descripcion: 'La suma exacta (derecho) y su espejo (revés)',
          color: Colors.grey,
          count: basicos.length,
          contenido: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (basicosDerecho.isNotEmpty) ...[
                const Text('Derecho:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 6),
                _buildGrillaNiveles(basicosDerecho, faltanMes, grande: false),
                const SizedBox(height: 10),
              ],
              if (basicosReves.isNotEmpty) ...[
                const Text('Revés:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 6),
                _buildGrillaNiveles(basicosReves, faltanMes, grande: false),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 5 ── Grupo semántico ────────────────────────────
        if (grupoDeNumero(numero) != null) ...[
          _buildCardQ(
            titulo: '🌐 Grupo semántico — ${grupoDeNumero(numero)}',
            descripcion: 'Números del mismo grupo simbólico del libro de sueños',
            color: Colors.teal,
            count: companerosSemanticos(numero).length,
            contenido: _buildGrillaNiveles(
              _ordenarPorFrec(companerosSemanticos(numero)),
              faltanMes,
              grande: false,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 6 ── Patrón histórico ────────────────────────────
        _buildCardQ(
          titulo: '📊 Patrón histórico',
          descripcion: 'Qué tan seguido cae el quebrado después de este número',
          color: Colors.teal,
          count: patron['total'] as int,
          contenido: _buildPatronContenido(patron, numero),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildGrillaNiveles(
    List<int> numeros,
    Set<int> faltanMes, {
    required bool grande,
  }) {
    if (numeros.isEmpty) {
      return const Text(
        'Sin resultados',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }
    final size = grande ? 84.0 : 72.0;
    final fontSize = grande ? 22.0 : 18.0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: numeros.map((q) {
        final noSalio = faltanMes.contains(q);
        final stats = _allStats?[q];
        final dias = stats?.diasSinSalir() ?? 0;
        final freq = stats?.frecuencia ?? 0;
        final sig = significadoCorto(q);

        return Container(
          width: size,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: noSalio
                ? Colors.red.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: noSalio
                  ? Colors.red.withValues(alpha: 0.7)
                  : Colors.green.withValues(alpha: 0.5),
              width: grande ? 2.0 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                q.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: noSalio ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sig,
                style: const TextStyle(fontSize: 8, color: Colors.grey),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 3),
              Text(
                noSalio ? '${dias}d sin salir' : 'salió',
                style: TextStyle(
                  fontSize: 9,
                  color: noSalio
                      ? Colors.red.withValues(alpha: 0.8)
                      : Colors.green.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${freq}x',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatChip(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildLeyendaChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getConfianzaColor(double confianza) {
    if (confianza >= 0.8) return Colors.green;
    if (confianza >= 0.6) return Colors.orange;
    if (confianza >= 0.4) return Colors.blue;
    return Colors.grey;
  }

  Widget _buildPrediccionCard(int numero) {
    final predicciones = _prediccionesProfundas[numero];
    final stats = _estadisticasProfundas[numero];

    final diaNombre = stats != null
        ? _diasNombre[stats['diaMasFrecuente'] as int]
        : '';
    final horario = stats != null ? stats['horarioMasFrecuente'] as String : '';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Número principal
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.goldColor, AppTheme.orangeColor],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  numero.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    significadoCorto(numero),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  if (stats != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$diaNombre (${stats['diaFrecuencia']}x)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.purple),
                        const SizedBox(width: 4),
                        Text(
                          "${horario == 'M'
                              ? 'Mañana'
                              : horario == 'T'
                              ? 'Tarde'
                              : 'Noche'} (${stats['horarioFrecuencia']}x)",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (predicciones != null &&
                      predicciones['predicciones'].isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      '🎯 Mejores predicciones:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ...predicciones['predicciones']
                            .take(4)
                            .map(
                              (pred) => _buildMiniPrediccion(
                                pred['numero'],
                                pred['confianza'],
                              ),
                            ),
                      ],
                    ),
                  ],

                  // Relaciones profundas: espejos, sumas, cruzados
                  const SizedBox(height: 8),
                  Builder(
                    builder: (ctx) {
                      final espejos = _espejos[numero] ?? [];
                      final sumas = _sumas[numero] ?? [];
                      final cruzados = _cruzados[numero] ?? [];
                      if (espejos.isEmpty &&
                          sumas.isEmpty &&
                          cruzados.isEmpty) {
                        return const SizedBox();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔗 Relaciones',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ...espejos.map(
                                (n) => _buildMiniNum(n, Colors.red),
                              ),
                              ...sumas.map(
                                (n) => _buildMiniNum(n, Colors.green),
                              ),
                              ...cruzados.map(
                                (n) => _buildMiniNum(n, Colors.blue),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPrediccion(int numero, double confianza) {
    final color = _getConfianzaColor(confianza);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        numero.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
