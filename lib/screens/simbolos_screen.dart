// lib/screens/simbolos_screen.dart
//
// Pantalla de simbología: agrupa los números 00-99 por el significado de su
// suma de dígitos (punto).  Ej.: 83 → 8+3 = 11 = Perro (Animales).
//
// Estructura:
//   TabBar  → un tab por grupo semántico
//   Contenido → una card por número del libro dentro del grupo,
//               mostrando todos los números 00-99 que producen esa suma.

import 'package:flutter/material.dart';
import '../data/grupos_semanticos.dart';
import '../data/libro_suenos.dart';
import '../services/database.dart';
import '../theme/app_theme.dart';

// Icono representativo por grupo
const Map<String, String> _iconoGrupo = {
  'Animales':   '🐾',
  'Armas':      '⚔️',
  'Familia':    '👨‍👩‍👧',
  'Casa/Hogar': '🏠',
  'Religión':   '⛪',
  'Dinero':     '💰',
  'Naturaleza': '🌿',
  'Oficios':    '🔧',
  'Bebidas':    '🍺',
  'Transporte': '🚗',
  'Cuerpo':     '👣',
  'Objetos':    '📦',
};

class SimbolosScreen extends StatefulWidget {
  const SimbolosScreen({super.key});

  @override
  State<SimbolosScreen> createState() => _SimbolosScreenState();
}

class _SimbolosScreenState extends State<SimbolosScreen>
    with SingleTickerProviderStateMixin {
  final _db = DatabaseService.instance;
  late TabController _tabController;

  // Grupos en orden fijo
  final _grupos = gruposSemanticos.keys.toList();

  // Cache de frecuencias, última aparición y set de "jugó este mes"
  Map<int, int>       _frecuencias  = {};
  Map<int, DateTime?> _ultimaVez    = {};
  Set<int>            _jugadosMes   = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _grupos.length, vsync: this);
    _db.addListener(_actualizarFrecuencias);
    _actualizarFrecuencias();
  }

  @override
  void dispose() {
    _db.removeListener(_actualizarFrecuencias);
    _tabController.dispose();
    super.dispose();
  }

  void _actualizarFrecuencias() {
    if (!mounted) return;
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);

    final freq  = <int, int>{for (int i = 0; i <= 99; i++) i: 0};
    final ultra = <int, DateTime?>{for (int i = 0; i <= 99; i++) i: null};
    final mes   = <int>{};

    for (final s in _db.sorteos) {
      final esMes = !s.fecha.isBefore(inicioMes);
      for (final n in s.numeros) {
        if (n != null && n >= 0 && n <= 99) {
          freq[n] = (freq[n] ?? 0) + 1;
          if (ultra[n] == null || s.fecha.isAfter(ultra[n]!)) {
            ultra[n] = s.fecha;
          }
          if (esMes) mes.add(n);
        }
      }
    }
    setState(() {
      _frecuencias = freq;
      _ultimaVez   = ultra;
      _jugadosMes  = mes;
    });
  }

  /// Todos los números 00-99 que "apuntan" a [punto]:
  ///  - el número [punto] mismo (él ES ese símbolo directamente)
  ///  - cualquier número cuya suma de dígitos = [punto]
  List<int> _numerosParaPunto(int punto) {
    final result = <int>{};
    // El número símbolo en sí (ej. 11 = Perro → incluir 11 aunque 1+1=2)
    if (punto >= 0 && punto <= 99) result.add(punto);
    // Números cuya suma de dígitos da ese símbolo
    for (int n = 0; n <= 99; n++) {
      if (n ~/ 10 + n % 10 == punto) result.add(n);
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔮 Simbología'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.goldColor,
          labelColor: AppTheme.goldColor,
          unselectedLabelColor: Colors.grey,
          tabs: _grupos.map((g) {
            final icono = _iconoGrupo[g] ?? '📌';
            return Tab(text: '$icono $g');
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _grupos.map((grupo) => _buildGrupoTab(grupo)).toList(),
      ),
    );
  }

  Widget _buildGrupoTab(String grupo) {
    final puntosDelGrupo = gruposSemanticos[grupo] ?? [];
    // Ordenar puntos por número ascendente
    final puntosOrdenados = [...puntosDelGrupo]..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: puntosOrdenados.length,
      itemBuilder: (ctx, i) => _buildPuntoCard(puntosOrdenados[i]),
    );
  }

  Widget _buildPuntoCard(int punto) {
    final significado = libroSuenos[punto] ?? '?';
    final numeros = _numerosParaPunto(punto);
    // Ordenar por frecuencia descendente para ver los más calientes primero
    numeros.sort((a, b) => (_frecuencias[b] ?? 0).compareTo(_frecuencias[a] ?? 0));
    final maxFreq = numeros
        .map((n) => _frecuencias[n] ?? 0)
        .fold(1, (a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: punto + significado
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.accentColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      punto.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 18,
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
                        significado,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldColor,
                        ),
                      ),
                      Text(
                        'Suma de dígitos = ${punto.toString().padLeft(2, '0')}  ·  ${numeros.length} números',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white12),
            const SizedBox(height: 10),

            // Grid de números
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: numeros.map((n) => _buildNumChip(n, maxFreq)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumChip(int numero, int maxFreq) {
    final freq   = _frecuencias[numero] ?? 0;
    final sig    = significadoCorto(numero);
    final ultima = _ultimaVez[numero];
    final dias   = ultima != null
        ? DateTime.now().difference(ultima).inDays
        : null;
    final jugado = _jugadosMes.contains(numero);

    // Verde = jugó este mes · Rojo = pendiente este mes
    final baseColor = jugado ? AppTheme.greenColor : AppTheme.accentColor;

    return Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            numero.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: baseColor,
            ),
          ),
          Text(
            sig,
            style: const TextStyle(fontSize: 8, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (freq > 0)
            Text(
              '${freq}x',
              style: TextStyle(
                fontSize: 9,
                color: baseColor.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            dias != null ? '${dias}d' : 'nunca',
            style: TextStyle(
              fontSize: 8,
              color: dias == null
                  ? Colors.grey
                  : dias <= 7
                      ? AppTheme.greenColor
                      : dias <= 30
                          ? AppTheme.orangeColor
                          : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
