// lib/screens/registro_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/sorteo_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/libro_suenos_sheet.dart';
import '../data/libro_suenos.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _service = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  final _manianaCtrl = TextEditingController();
  final _tardeCtrl = TextEditingController();
  final _nocheCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now();
  bool _guardando = false;

  bool get _bloqueado => false; // Permitir editar siempre

  @override
  void initState() {
    super.initState();
    _cargarSorteoExistente();
  }

  Future<void> _cargarSorteoExistente() async {
    final sorteo = await _service.obtenerSorteoPorFecha(_fechaSeleccionada);
    if (mounted) {
      setState(() {
        if (sorteo != null) {
          _manianaCtrl.text = sorteo.numeroManiana == null
              ? ''
              : sorteo.numeroManiana!.toString().padLeft(2, '0');
          _tardeCtrl.text = sorteo.numeroTarde == null
              ? ''
              : sorteo.numeroTarde!.toString().padLeft(2, '0');
          _nocheCtrl.text = sorteo.numeroNoche == null
              ? ''
              : sorteo.numeroNoche!.toString().padLeft(2, '0');
          _notasCtrl.text = sorteo.notas;
        } else {
          _manianaCtrl.clear();
          _tardeCtrl.clear();
          _nocheCtrl.clear();
          _notasCtrl.clear();
        }
      });
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.goldColor,
            onPrimary: Colors.black,
            surface: AppTheme.cardColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _fechaSeleccionada = picked);
      await _cargarSorteoExistente();
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final sorteo = SorteoModel(
        id: '',
        fecha: _fechaSeleccionada,
        numeroManiana: _manianaCtrl.text.isEmpty
            ? null
            : int.parse(_manianaCtrl.text),
        numeroTarde: _tardeCtrl.text.isEmpty
            ? null
            : int.parse(_tardeCtrl.text),
        numeroNoche: _nocheCtrl.text.isEmpty
            ? null
            : int.parse(_nocheCtrl.text),
        notas: _notasCtrl.text,
      );
      await _service.guardarSorteo(sorteo);
      await _cargarSorteoExistente();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sorteo guardado correctamente'),
            backgroundColor: AppTheme.greenColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }


  Future<void> _abrirLibroSuenos() async {
    final numero = await mostrarLibroSuenos(context);
    if (numero == null || !mounted) return;

    final significado = libroSuenos[numero] ?? '';
    final numStr = numero.toString().padLeft(2, '0');

    // Preguntar a qué sorteo asignar el número
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  numStr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Número $numStr', style: const TextStyle(fontSize: 15)),
                  Text(
                    significado,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
        content: const Text('¿Asignar a qué sorteo?'),
        actions: [
          TextButton(
            onPressed: () {
              _manianaCtrl.text = numStr;
              Navigator.pop(ctx);
            },
            child: const Text(
              '🌅 Mañana',
              style: TextStyle(color: AppTheme.goldColor),
            ),
          ),
          TextButton(
            onPressed: () {
              _tardeCtrl.text = numStr;
              Navigator.pop(ctx);
            },
            child: const Text(
              '☀️ Tarde',
              style: TextStyle(color: AppTheme.orangeColor),
            ),
          ),
          TextButton(
            onPressed: () {
              _nocheCtrl.text = numStr;
              Navigator.pop(ctx);
            },
            child: const Text(
              '🌙 Noche',
              style: TextStyle(color: Colors.purple),
            ),
          ),
        ],
      ),
    );
  }

  String? _validarNumero(String? value) {
    if (value == null || value.isEmpty) return null; // Permitir vacío
    final n = int.tryParse(value);
    if (n == null || n < 0 || n > 99) return 'Debe ser entre 00 y 99';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fechaStr = DateFormat(
      'EEEE d MMM yyyy',
      'es',
    ).format(_fechaSeleccionada);
    final esHoy =
        DateFormat('yyyy-MM-dd').format(_fechaSeleccionada) ==
        DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildAppBarBg(),
              title: Text(
                'La Diaria · Loto Honduras',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selector de fecha
                    _buildFechaSelector(fechaStr, esHoy),
                    const SizedBox(height: 12),

                    // Campos de números
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Números del sorteo'),
                        if (!_bloqueado)
                          TextButton.icon(
                            onPressed: _abrirLibroSuenos,
                            icon: const Text(
                              '🔮',
                              style: TextStyle(fontSize: 14),
                            ),
                            label: const Text(
                              'Libro de sueños',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.goldColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildNumeroField(
                      controller: _manianaCtrl,
                      label: '🌅 Sorteo Mañana (11:00 AM)',
                      color: AppTheme.goldColor,
                      enabled: true,
                    ),
                    const SizedBox(height: 12),
                    _buildNumeroField(
                      controller: _tardeCtrl,
                      label: '☀️ Sorteo Tarde (3:00 PM)',
                      color: AppTheme.orangeColor,
                      enabled: true,
                    ),
                    const SizedBox(height: 12),
                    _buildNumeroField(
                      controller: _nocheCtrl,
                      label: '🌙 Sorteo Noche (9:00 PM)',
                      color: Colors.purple,
                      enabled: true,
                    ),
                    const SizedBox(height: 20),

                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _guardando
                              ? 'Guardando...'
                              : 'Guardar/Actualizar Sorteo',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.bgDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(
        child: Icon(Icons.casino_rounded, size: 48, color: AppTheme.goldColor),
      ),
    );
  }

  Widget _buildFechaSelector(String fechaStr, bool esHoy) {
    return GestureDetector(
      onTap: _seleccionarFecha,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppTheme.goldColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esHoy ? 'HOY' : 'Fecha seleccionada',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    fechaStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildNumeroField({
    required TextEditingController controller,
    required String label,
    required Color color,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: enabled ? _validarNumero : null,
      keyboardType: TextInputType.number,
      maxLength: 2,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        filled: true,
        fillColor: AppTheme.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        prefixIcon: Icon(Icons.tag, color: color),
        suffix: Text(
          '(00-99)',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manianaCtrl.dispose();
    _tardeCtrl.dispose();
    _nocheCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }
}
