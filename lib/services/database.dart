// lib/services/database.dart
//
// Caché central de sorteos.
// ─ Carga todos los registros una vez desde Firestore.
// ─ Expone la lista en memoria para que las pantallas no vuelvan a pedir datos.
// ─ Tras guardar o eliminar actualiza el caché y notifica a los listeners.
//
// Uso en pantalla:
//   final db = DatabaseService.instance;
//   await db.cargar();           // solo necesario si aún no está cargado
//   db.sorteos                   // lista en memoria
//   ListenableBuilder(listenable: db, builder: (ctx, _) { ... })

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sorteo_model.dart';

class DatabaseService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────────
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  // ── Firebase ─────────────────────────────────────────────────────────────────
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _col = 'sorteos_diaria';

  // ── Estado del caché ─────────────────────────────────────────────────────────
  List<SorteoModel> _sorteos = [];
  bool _cargado = false;
  bool _cargando = false;
  String? _error;

  List<SorteoModel> get sorteos => List.unmodifiable(_sorteos);
  bool get cargado => _cargado;
  bool get cargando => _cargando;
  String? get error => _error;

  // ── Carga inicial ─────────────────────────────────────────────────────────────
  /// Trae todos los sorteos de Firestore y los deja en memoria.
  /// Si ya están cargados, retorna inmediatamente sin ir a Firebase.
  /// Pasá [forzar: true] para recargar desde cero (ej. pull-to-refresh).
  Future<void> cargar({bool forzar = false}) async {
    if (_cargado && !forzar) return;
    if (_cargando) return;

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final snap = await _db
          .collection(_col)
          .orderBy('fecha', descending: true)
          .get();
      _sorteos = snap.docs.map((d) => SorteoModel.fromFirestore(d)).toList();
      _cargado = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ── Guardar / actualizar ──────────────────────────────────────────────────────
  /// Persiste en Firestore y actualiza el caché local sin necesidad de recargar.
  Future<void> guardarSorteo(SorteoModel sorteo) async {
    await _db
        .collection(_col)
        .doc(sorteo.fechaKey)
        .set(sorteo.toFirestore(), SetOptions(merge: true));

    // Actualizar caché: reemplazar si ya existe, insertar si es nuevo
    final idx = _sorteos.indexWhere((s) => s.fechaKey == sorteo.fechaKey);
    if (idx >= 0) {
      _sorteos[idx] = sorteo;
    } else {
      _sorteos.add(sorteo);
      // Mantener orden descendente por fecha
      _sorteos.sort((a, b) => b.fecha.compareTo(a.fecha));
    }

    notifyListeners();
  }

  // ── Eliminar ─────────────────────────────────────────────────────────────────
  Future<void> eliminarSorteo(String fechaKey) async {
    await _db.collection(_col).doc(fechaKey).delete();
    _sorteos.removeWhere((s) => s.fechaKey == fechaKey);
    notifyListeners();
  }

  // ── Consultas derivadas (sin ir a Firebase) ───────────────────────────────────

  /// Sorteo de una fecha específica, directo del caché.
  SorteoModel? buscarPorFecha(DateTime fecha) {
    final key =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    try {
      return _sorteos.firstWhere((s) => s.fechaKey == key);
    } catch (_) {
      return null;
    }
  }

  /// Estadísticas de frecuencia para los 100 números (00-99), calculadas del caché.
  Map<int, EstadisticaNumero> calcularEstadisticas() {
    final Map<int, EstadisticaNumero> stats = {
      for (int i = 0; i <= 99; i++) i: EstadisticaNumero(numero: i),
    };

    for (final sorteo in _sorteos) {
      for (final numero in sorteo.numeros) {
        if (numero != null && numero >= 0 && numero <= 99) {
          stats[numero]!.frecuencia++;
          stats[numero]!.apariciones.add(sorteo.fecha);
          if (stats[numero]!.ultimaVez == null ||
              sorteo.fecha.isAfter(stats[numero]!.ultimaVez!)) {
            stats[numero]!.ultimaVez = sorteo.fecha;
          }
        }
      }
    }

    return stats;
  }

  /// Top N más frecuentes, del caché.
  List<EstadisticaNumero> topCalientes(int n) {
    final lista = calcularEstadisticas().values.toList()
      ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));
    return lista.take(n).toList();
  }

  /// Top N más fríos (mayor días sin salir), del caché.
  List<EstadisticaNumero> topFrios(int n) {
    final lista = calcularEstadisticas().values
        .where((e) => e.frecuencia > 0)
        .toList()
      ..sort((a, b) {
        final d = b.diasSinSalir().compareTo(a.diasSinSalir());
        return d != 0 ? d : a.frecuencia.compareTo(b.frecuencia);
      });
    return lista.take(n).toList();
  }

  /// Total de sorteos individuales (cada día tiene 3).
  int get totalSorteos => _sorteos.length * 3;
}
