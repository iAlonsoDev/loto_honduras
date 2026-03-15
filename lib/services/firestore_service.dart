// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sorteo_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _coleccion = 'sorteos_diaria';

  // ─── CRUD ────────────────────────────────────────────────────────────────────

  /// Guarda o actualiza el sorteo de un día específico
  Future<void> guardarSorteo(SorteoModel sorteo) async {
    await _db
        .collection(_coleccion)
        .doc(sorteo.fechaKey)
        .set(sorteo.toFirestore(), SetOptions(merge: true));
  }

  /// Obtiene el sorteo de una fecha
  Future<SorteoModel?> obtenerSorteoPorFecha(DateTime fecha) async {
    final key =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    final doc = await _db.collection(_coleccion).doc(key).get();
    if (!doc.exists) return null;
    return SorteoModel.fromFirestore(doc);
  }

  /// Stream en tiempo real del sorteo de hoy
  Stream<SorteoModel?> streamSorteoHoy() {
    final hoy = DateTime.now();
    final key =
        '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
    return _db
        .collection(_coleccion)
        .doc(key)
        .snapshots()
        .map((doc) => doc.exists ? SorteoModel.fromFirestore(doc) : null);
  }

  /// Todos los sorteos ordenados por fecha desc
  Future<List<SorteoModel>> obtenerTodosLosSorteos() async {
    final snapshot = await _db
        .collection(_coleccion)
        .orderBy('fecha', descending: true)
        .get();
    return snapshot.docs.map((d) => SorteoModel.fromFirestore(d)).toList();
  }

  /// Eliminar un sorteo
  Future<void> eliminarSorteo(String fechaKey) async {
    await _db.collection(_coleccion).doc(fechaKey).delete();
  }

  // ─── ESTADÍSTICAS ─────────────────────────────────────────────────────────

  /// Calcula la frecuencia de cada número del 00-99
  Future<Map<int, EstadisticaNumero>> calcularEstadisticas() async {
    final sorteos = await obtenerTodosLosSorteos();

    // Inicializar todos los números del 00-99
    final Map<int, EstadisticaNumero> stats = {
      for (int i = 0; i <= 99; i++) i: EstadisticaNumero(numero: i),
    };

    for (final sorteo in sorteos) {
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

  /// Total de sorteos individuales (cada día tiene 3 sorteos)
  Future<int> totalSorteos() async {
    final snap = await _db.collection(_coleccion).count().get();
    return (snap.count ?? 0) * 3;
  }

  /// Top N números más frecuentes
  Future<List<EstadisticaNumero>> topCalientes(int n) async {
    final stats = await calcularEstadisticas();
    final lista = stats.values.toList()
      ..sort((a, b) => b.frecuencia.compareTo(a.frecuencia));
    return lista.take(n).toList();
  }

  /// Top N números más fríos (menos frecuentes pero que al menos han salido)
  Future<List<EstadisticaNumero>> topFrios(int n) async {
    final stats = await calcularEstadisticas();
    final lista = stats.values.where((e) => e.frecuencia > 0).toList()
      ..sort((a, b) {
        // Primero por días sin salir (más días = más frío)
        final diasComp = b.diasSinSalir().compareTo(a.diasSinSalir());
        if (diasComp != 0) return diasComp;
        return a.frecuencia.compareTo(b.frecuencia);
      });
    return lista.take(n).toList();
  }
}
