// lib/models/sorteo_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class SorteoModel {
  final String id;
  final DateTime fecha;
  final int? numeroManiana; // Sorteo 11:00 AM
  final int? numeroTarde; // Sorteo  3:00 PM
  final int? numeroNoche; // Sorteo  9:00 PM
  final String notas;

  SorteoModel({
    required this.id,
    required this.fecha,
    required this.numeroManiana,
    required this.numeroTarde,
    required this.numeroNoche,
    this.notas = '',
  });

  /// Lista de los 3 números del día
  List<int?> get numeros => [numeroManiana, numeroTarde, numeroNoche];

  /// Clave única por fecha (YYYY-MM-DD)
  String get fechaKey =>
      '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

  factory SorteoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SorteoModel(
      id: doc.id,
      fecha: (data['fecha'] as Timestamp).toDate(),
      numeroManiana: data['numero_maniana'] as int?,
      numeroTarde: data['numero_tarde'] as int?,
      numeroNoche: data['numero_noche'] as int?,
      notas: data['notas'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'fecha': Timestamp.fromDate(fecha),
    'fecha_key': fechaKey,
    'numero_maniana': numeroManiana,
    'numero_tarde': numeroTarde,
    'numero_noche': numeroNoche,
    'notas': notas,
    'creado_en': FieldValue.serverTimestamp(),
  };
}

class EstadisticaNumero {
  final int numero;
  int frecuencia;
  DateTime? ultimaVez;
  List<DateTime> apariciones;

  EstadisticaNumero({
    required this.numero,
    this.frecuencia = 0,
    this.ultimaVez,
    List<DateTime>? apariciones,
  }) : apariciones = apariciones ?? [];

  /// Porcentaje empírico de aparición
  double porcentaje(int totalSorteos) =>
      totalSorteos == 0 ? 0 : (frecuencia / totalSorteos) * 100;

  /// Cuántos días lleva sin salir
  int diasSinSalir() {
    if (ultimaVez == null) return 999;
    return DateTime.now().difference(ultimaVez!).inDays;
  }

  /// Etiqueta de temperatura
  String get temperatura {
    if (frecuencia == 0) return '❄️ Sin datos';
    if (diasSinSalir() <= 3) return '🔥 Caliente';
    if (diasSinSalir() <= 7) return '🌡️ Tibio';
    if (diasSinSalir() <= 14) return '🌀 Frío';
    return '🧊 Muy frío';
  }
}
