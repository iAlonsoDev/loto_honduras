// lib/screens/estadisticas_screen.dart

import 'package:flutter/material.dart';
import '../models/sorteo_model.dart';
import '../services/database.dart';
import '../theme/app_theme.dart';
import '../data/libro_suenos.dart';

enum _Periodo { mes, trimestre, anio, todo }

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService.instance;
  List<SorteoModel> _allSorteos = [];
  _Periodo _periodo = _Periodo.mes;
  bool _loading = true;
  String? _error;
  int? _numeroSeleccionado;
  late TabController _tabController;

  Map<int, EstadisticaNumero> _stats = {};
  int _totalSorteos = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _db.addListener(_sincronizar);
    _sincronizar();
  }

  @override
  void dispose() {
    _db.removeListener(_sincronizar);
    _tabController.dispose();
    super.dispose();
  }

  void _sincronizar() {
    if (!mounted) return;
    setState(() {
      _loading = _db.cargando;
      _error = _db.error;
      _allSorteos = _db.sorteos;
    });
    if (!_db.cargando) _recomputar();
  }

  Future<void> _refrescar() async {
    await _db.cargar(forzar: true);
  }

  void _recomputar() {
    final ahora = DateTime.now();
    DateTime inicio;
    switch (_periodo) {
      case _Periodo.mes:
        inicio = DateTime(ahora.year, ahora.month, 1);
      case _Periodo.trimestre:
        final t = ((ahora.month - 1) ~/ 3);
        inicio = DateTime(ahora.year, t * 3 + 1, 1);
      case _Periodo.anio:
        inicio = DateTime(ahora.year, 1, 1);
      case _Periodo.todo:
        inicio = DateTime(2000);
    }

    final filtrados =
        _allSorteos.where((s) => !s.fecha.isBefore(inicio)).toList();

    final stats = {
      for (int i = 0; i <= 99; i++) i: EstadisticaNumero(numero: i),
    };
    int count = 0;
    for (final s in filtrados) {
      void proc(int? num) {
        if (num == null || num < 0 || num > 99) return;
        count++;
        stats[num]!.frecuencia++;
        stats[num]!.apariciones.add(s.fecha);
        if (stats[num]!.ultimaVez == null ||
            s.fecha.isAfter(stats[num]!.ultimaVez!)) {
          stats[num]!.ultimaVez = s.fecha;
        }
      }

      proc(s.numeroManiana);
      proc(s.numeroTarde);
      proc(s.numeroNoche);
    }

    setState(() {
      _stats = stats;
      _totalSorteos = count;
    });
  }

  void _cambiarPeriodo(_Periodo p) {
    setState(() => _periodo = p);
    _recomputar();
  }

  Color _colorParaFrecuencia(int frecuencia, int maxFrecuencia) {
    if (frecuencia == 0) return Colors.grey.withValues(alpha: 0.2);
    final ratio = frecuencia / maxFrecuencia;
    if (ratio >= 0.8) return AppTheme.accentColor;
    if (ratio >= 0.6) return AppTheme.orangeColor;
    if (ratio >= 0.4) return AppTheme.goldColor;
    if (ratio >= 0.2) return AppTheme.primaryColor;
    return AppTheme.primaryColor.withValues(alpha: 0.4);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Estadísticas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refrescar),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              _buildPeriodoSelector(),
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.goldColor,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.dashboard_rounded, size: 18),
                    text: 'RESUMEN',
                  ),
                  Tab(
                    icon: Icon(Icons.grid_view_rounded, size: 18),
                    text: 'MAPA',
                  ),
                  Tab(
                    icon: Icon(Icons.format_list_numbered_rounded, size: 18),
                    text: 'TABLA',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            )
          : _error != null
          ? _buildError()
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboard(),
                      _buildMapaCalor(),
                      _buildTabla(),
                    ],
                  ),
                ),
                if (_numeroSeleccionado != null) _buildDetalleNumero(),
              ],
            ),
    );
  }

  // ── SELECTOR DE PERÍODO ───────────────────────────────────────────────────────

  Widget _buildPeriodoSelector() {
    final opciones = [
      (_Periodo.mes, 'Mes'),
      (_Periodo.trimestre, 'Trimestre'),
      (_Periodo.anio, 'Año'),
      (_Periodo.todo, 'Todo'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: opciones.map((o) {
          final selected = _periodo == o.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => _cambiarPeriodo(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.goldColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppTheme.goldColor
                        : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    o.$2,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.black : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── ERROR ─────────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
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
            ElevatedButton(onPressed: _refrescar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: DASHBOARD ──────────────────────────────────────────────────────────

  Widget _buildDashboard() {
    final stats = _stats;
    final maxFrec = stats.values
        .map((e) => e.frecuencia)
        .fold(1, (a, b) => a > b ? a : b);
    final sorted = stats.values.toList()
      ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));
    final top10 = sorted.take(10).toList();
    final sinSalir = stats.values.where((e) => e.frecuencia == 0).length;
    final ausentes = stats.values
        .where((e) => e.frecuencia > 0)
        .toList()
      ..sort((a, b) => b.diasSinSalir().compareTo(a.diasSinSalir()));
    final top5Ausentes = ausentes.take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs
          Row(
            children: [
              _buildKpiCard(
                '🎰',
                'Sorteos',
                '$_totalSorteos',
                AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                '🏆',
                'Nº 1',
                top10.isNotEmpty
                    ? top10.first.numero.toString().padLeft(2, '0')
                    : '--',
                AppTheme.accentColor,
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                '❄️',
                'Sin salir',
                '$sinSalir',
                Colors.lightBlue,
              ),
              const SizedBox(width: 8),
              _buildKpiCard(
                '📅',
                'Días',
                '${_totalSorteos ~/ 3}',
                AppTheme.goldColor,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Top 10
          _buildSectionHeader('🔥 Top 10 más frecuentes'),
          const SizedBox(height: 8),
          ...top10.asMap().entries.map((entry) {
            final i = entry.key;
            final stat = entry.value;
            final medal = i == 0
                ? '🥇'
                : i == 1
                ? '🥈'
                : i == 2
                ? '🥉'
                : ' ${i + 1}.';
            final ratio = maxFrec > 0 ? stat.frecuencia / maxFrec : 0.0;
            final barColor = i == 0
                ? AppTheme.accentColor
                : i < 3
                ? AppTheme.goldColor
                : AppTheme.primaryColor;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                dense: true,
                leading: Text(medal, style: const TextStyle(fontSize: 16)),
                title: Text(
                  '${stat.numero.toString().padLeft(2, '0')} · ${significadoCorto(stat.numero)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: LinearProgressIndicator(
                  value: ratio.toDouble(),
                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                  color: barColor,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${stat.frecuencia}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldColor,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${stat.diasSinSalir()}d sin salir',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () => setState(
                  () => _numeroSeleccionado =
                      _numeroSeleccionado == stat.numero ? null : stat.numero,
                ),
              ),
            );
          }),
          const SizedBox(height: 20),

          // Top 5 ausentes
          _buildSectionHeader('🧊 Más días sin aparecer'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: top5Ausentes
                .map(
                  (stat) => GestureDetector(
                    onTap: () => setState(
                      () => _numeroSeleccionado =
                          _numeroSeleccionado == stat.numero
                              ? null
                              : stat.numero,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.lightBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.lightBlue.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            stat.numero.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                          ),
                          Text(
                            '${stat.diasSinSalir()}d',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            significadoCorto(stat.numero),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String emoji,
    String label,
    String valor,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppTheme.goldColor,
      ),
    );
  }

  // ── TAB 2: MAPA DE CALOR ─────────────────────────────────────────────────────

  Widget _buildMapaCalor() {
    final stats = _stats;
    final maxFrecuencia = stats.values
        .map((e) => e.frecuencia)
        .fold(1, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeyenda(),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 10,
              childAspectRatio: 1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 100,
            itemBuilder: (ctx, i) {
              final stat = stats[i]!;
              final color = _colorParaFrecuencia(
                stat.frecuencia,
                maxFrecuencia,
              );
              final isSelected = _numeroSeleccionado == i;
              return GestureDetector(
                onTap: () => setState(() {
                  _numeroSeleccionado = isSelected ? null : i;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      i.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            stat.frecuencia == 0 ? Colors.grey : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeyenda() {
    return Row(
      children: [
        const Text(
          'Frec: ',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        ...[
          (AppTheme.primaryColor.withValues(alpha: 0.4), 'Baja'),
          (AppTheme.primaryColor, 'Media'),
          (AppTheme.goldColor, 'Alta'),
          (AppTheme.orangeColor, 'Muy alta'),
          (AppTheme.accentColor, 'Máx'),
        ].map(
          (e) => Row(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: e.$1,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(e.$2, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 3: TABLA ─────────────────────────────────────────────────────────────

  Widget _buildTabla() {
    final maxFrec = _stats.values
        .map((e) => e.frecuencia)
        .fold(1, (a, b) => a > b ? a : b);
    final sorted = _stats.values.toList()
      ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: 100,
      itemBuilder: (ctx, i) {
        final stat = sorted[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _colorParaFrecuencia(stat.frecuencia, maxFrec),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  stat.numero.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            title: Text(
              '${stat.numero.toString().padLeft(2, '0')} · ${significadoCorto(stat.numero)}',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: LinearProgressIndicator(
              value: maxFrec > 0 ? stat.frecuencia / maxFrec : 0,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: AppTheme.goldColor,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stat.frecuencia}x',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldColor,
                  ),
                ),
                Text(
                  stat.frecuencia > 0
                      ? '${stat.diasSinSalir()}d sin salir'
                      : 'Nunca',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => setState(() {
              _numeroSeleccionado =
                  _numeroSeleccionado == stat.numero ? null : stat.numero;
              if (_tabController.index != 1) _tabController.index = 1;
            }),
          ),
        );
      },
    );
  }

  // ── DETALLE NÚMERO ────────────────────────────────────────────────────────────

  Widget _buildDetalleNumero() {
    final stat = _stats[_numeroSeleccionado!]!;
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.cardColor,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.accentColor],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _numeroSeleccionado!.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
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
                  '${_numeroSeleccionado!.toString().padLeft(2, '0')} · ${significadoCorto(_numeroSeleccionado!)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.goldColor,
                  ),
                ),
                Text(
                  stat.temperatura,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Ha salido ${stat.frecuencia} veces en el período seleccionado',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (stat.ultimaVez != null)
                  Text(
                    'Último sorteo: hace ${stat.diasSinSalir()} días',
                    style: const TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            onPressed: () => setState(() => _numeroSeleccionado = null),
          ),
        ],
      ),
    );
  }
}
