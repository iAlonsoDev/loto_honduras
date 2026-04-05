// lib/data/grupos_semanticos.dart
// Grupos semánticos basados en el libro de sueños oficial - La Diaria Honduras

const Map<String, List<int>> gruposSemanticos = {
  'Transporte':     [0, 53, 81, 83, 94],        // Avión, Llanta, Rieles, Bote, Carro
  'Animales':       [4, 6, 8, 11, 12, 13, 15, 23, 24, 28, 31, 32, 43, 52, 58, 62, 67, 87, 89, 91, 92],
                                                  // Tigre, Elefante, Conejo, Perro, Caballo, Gato,
                                                  // Ratón, Mono, Sapo, Gallo, Alacrán, Culebra, Pantera,
                                                  // Zorrillo, Venado, Lagarto, Vaca, León, Búho, Tortuga, Águila
  'Familia':        [2, 9, 14, 16, 17, 29, 36, 41, 42, 46, 97],
                                                  // Mujer, Hombre, Boda, Niña, Joven,
                                                  // Padre, Viejita, Novia, Madre, Familia, Viejito
  'Casa/Hogar':     [44, 64, 74, 85, 88],        // Mesas, Mueble, Edificio, Casa, Platos
  'Religión':       [3, 18, 22, 35, 40, 45, 66, 84],
                                                  // Muerto, Ángel, Ataúd, Virgen, Cielo,
                                                  // Iglesia, Diablo, Coronas
  'Dinero':         [25, 47, 70, 96],            // Balanza, Banco, Oro, Dinero
  'Armas':          [7, 38, 57, 61, 69],         // Navaja, Pistola, Cuchillo, Guerra, Soldado
  'Naturaleza':     [19, 21, 48, 49, 50, 56, 59, 76, 79],
                                                  // Mariposa, Pájaro, Estrella, Sombra, Luna nueva,
                                                  // Árbol, Selva, Palomas, Flores
  'Oficios':        [33, 51, 68, 93, 95],        // Carpintero, Policía, Ladrón, Cartero, Costurera
  'Bebidas':        [30, 54, 80],                // Bolo, Licor, Café
  'Cuerpo':         [1, 5, 71],                  // Pies, Embarazada, Zapatos
  'Objetos':        [10, 20, 26, 27, 34, 37, 39, 55, 60, 63, 65, 72, 73, 75, 77, 78, 82, 86, 90, 98, 99],
                                                  // Anillo, Espejo, Bandera, Juego, Música, Suerte, Jabón,
                                                  // Olas, Dragón, Coco, Pintura, Arco, Fuego, Reina,
                                                  // Humo, Tienda, Escuela, Reloj, Lentes, Bailes, Aretes
};

/// Devuelve el nombre del grupo al que pertenece [numero], o null si no está clasificado.
String? grupoDeNumero(int numero) {
  for (final entry in gruposSemanticos.entries) {
    if (entry.value.contains(numero)) return entry.key;
  }
  return null;
}

/// Devuelve todos los números del mismo grupo semántico que [numero],
/// excluyendo el propio número.
List<int> companerosSemanticos(int numero) {
  for (final entry in gruposSemanticos.entries) {
    if (entry.value.contains(numero)) {
      return entry.value.where((n) => n != numero).toList();
    }
  }
  return [];
}
