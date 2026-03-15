// lib/screens/estadisticas_screen.dart

import 'package:flutter/material.dart';
import '../models/sorteo_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../data/libro_suenos.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  Map<int, EstadisticaNumero>? _stats;
  int _totalSorteos = 0;
  bool _loading = true;
  String? _error;
  int? _numeroSeleccionado;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _service.calcularEstadisticas();
      final total = await _service.totalSorteos();
      if (mounted) {
        setState(() {
          _stats = stats;
          _totalSorteos = total;
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

  Color _colorParaFrecuencia(int frecuencia, int maxFrecuencia) {
    if (frecuencia == 0) return Colors.grey.withOpacity(0.2);
    final ratio = frecuencia / maxFrecuencia;
    if (ratio >= 0.8) return AppTheme.accentColor;
    if (ratio >= 0.6) return AppTheme.orangeColor;
    if (ratio >= 0.4) return AppTheme.goldColor;
    if (ratio >= 0.2) return AppTheme.primaryColor;
    return AppTheme.primaryColor.withOpacity(0.4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Estadísticas'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.goldColor,
          tabs: const [
            Tab(text: 'MAPA DE CALOR'),
            Tab(text: 'TABLA 00-99'),
          ],
        ),
      ),
      body: _loading
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
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _cargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildResumen(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildMapaCalor(), _buildTabla()],
                  ),
                ),
                if (_numeroSeleccionado != null) _buildDetalleNumero(),
              ],
            ),
    );
  }

  Widget _buildResumen() {
    final stats = _stats!;
    final maxFrecuencia = stats.values
        .map((e) => e.frecuencia)
        .fold(0, (a, b) => a > b ? a : b);
    final numSinSalir = stats.values.where((e) => e.frecuencia == 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🎯', 'Sorteos', '$_totalSorteos'),
          _buildStatItem('📅', 'Días', '${_totalSorteos ~/ 3}'),
          _buildStatItem('🏆', 'Máx frec.', '$maxFrecuencia'),
          _buildStatItem('❄️', 'Sin salir', '$numSinSalir'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String valor) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.goldColor,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildMapaCalor() {
    final stats = _stats!;
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
                        color: stat.frecuencia == 0
                            ? Colors.grey
                            : Colors.white,
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
          (AppTheme.primaryColor.withOpacity(0.4), 'Baja'),
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
              Text(
                e.$2,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabla() {
    final stats = _stats!.values.toList()
      ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: 100,
      itemBuilder: (ctx, i) {
        final stat = stats[i];
        final porcentaje = stat.porcentaje(_totalSorteos);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _colorParaFrecuencia(
                  stat.frecuencia,
                  _stats!.values
                      .map((e) => e.frecuencia)
                      .fold(1, (a, b) => a > b ? a : b),
                ),
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
            title: Row(
              children: [
                Text(
                  '${stat.numero.toString().padLeft(2, '0')} · ${significadoCorto(stat.numero)}',
                ),
                const SizedBox(width: 6),
                Text(stat.temperatura, style: const TextStyle(fontSize: 11)),
              ],
            ),
            subtitle: LinearProgressIndicator(
              value: _totalSorteos > 0
                  ? stat.frecuencia / (_totalSorteos == 0 ? 1 : _totalSorteos)
                  : 0,
              backgroundColor: Colors.grey.withOpacity(0.2),
              color: AppTheme.goldColor,
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
                  '${porcentaje.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            onTap: () => setState(() {
              _numeroSeleccionado = _numeroSeleccionado == stat.numero
                  ? null
                  : stat.numero;
              _tabController.index = 0;
            }),
          ),
        );
      },
    );
  }

  Widget _buildDetalleNumero() {
    final stat = _stats![_numeroSeleccionado!]!;
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      'Ha salido ${stat.frecuencia} veces · ${stat.porcentaje(_totalSorteos).toStringAsFixed(2)}% de probabilidad empírica',
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
