// lib/screens/registro_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/libro_suenos.dart';
import '../models/sorteo_model.dart';
import '../services/database.dart';
import '../theme/app_theme.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _db      = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();

  final _manianaCtrl = TextEditingController();
  final _tardeCtrl   = TextEditingController();
  final _nocheCtrl   = TextEditingController();

  final _manianFocus = FocusNode();
  final _tardeFocus  = FocusNode();
  final _nocheFocus  = FocusNode();

  DateTime _fecha     = DateTime.now();
  bool     _guardando = false;

  @override
  void initState() {
    super.initState();
    // Auto-avance al completar 2 dígitos
    _manianaCtrl.addListener(() => _autoAvanzar(_manianaCtrl, _tardeFocus));
    _tardeCtrl  .addListener(() => _autoAvanzar(_tardeCtrl,   _nocheFocus));
    // Al completar Noche solo cierra teclado
    _nocheCtrl  .addListener(() => _autoAvanzar(_nocheCtrl,   null));
    _cargarExistente();
  }

  // ── Lógica ────────────────────────────────────────────────────────────────

  void _autoAvanzar(TextEditingController ctrl, FocusNode? siguiente) {
    if (ctrl.text.length == 2) {
      if (siguiente != null) {
        FocusScope.of(context).requestFocus(siguiente);
      } else {
        FocusScope.of(context).unfocus();
      }
    }
  }

  void _cargarExistente() {
    final s = _db.buscarPorFecha(_fecha);
    if (!mounted) return;
    setState(() {
      _manianaCtrl.text = s?.numeroManiana != null
          ? s!.numeroManiana!.toString().padLeft(2, '0') : '';
      _tardeCtrl.text   = s?.numeroTarde   != null
          ? s!.numeroTarde!.toString().padLeft(2, '0')   : '';
      _nocheCtrl.text   = s?.numeroNoche   != null
          ? s!.numeroNoche!.toString().padLeft(2, '0')   : '';
    });
  }

  void _cambiarDia(int delta) {
    final nueva = _fecha.add(Duration(days: delta));
    if (nueva.isAfter(DateTime.now())) return;
    setState(() => _fecha = nueva);
    _cargarExistente();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            surface: AppTheme.cardColor,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _fecha = picked);
      _cargarExistente();
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await _db.guardarSorteo(SorteoModel(
        id: '',
        fecha: _fecha,
        numeroManiana: _manianaCtrl.text.isEmpty ? null : int.parse(_manianaCtrl.text),
        numeroTarde:   _tardeCtrl.text.isEmpty   ? null : int.parse(_tardeCtrl.text),
        numeroNoche:   _nocheCtrl.text.isEmpty   ? null : int.parse(_nocheCtrl.text),
        notas: '',
      ));
      _cargarExistente();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Registrado correctamente'),
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

  String? _validarNumero(String? value) {
    if (value == null || value.isEmpty) return null;
    final n = int.tryParse(value);
    if (n == null || n < 0 || n > 99) return '00–99';
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final esHoy = DateUtils.isSameDay(_fecha, DateTime.now());
    final fechaStr = DateFormat('EEE d MMM yyyy', 'es').format(_fecha);
    final puedeSiguiente = !esHoy;

    return Scaffold(
      appBar: AppBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── Selector de fecha con flechas ──────────────────────────────
            _buildFechaSelector(fechaStr, esHoy, puedeSiguiente),
            const SizedBox(height: 20),

            // ── Tres slots ─────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSlot(
                  emoji: '🌅', hora: '11 AM', label: 'Mañana',
                  color: AppTheme.goldColor,
                  controller: _manianaCtrl, focusNode: _manianFocus,
                ),
                const SizedBox(width: 10),
                _buildSlot(
                  emoji: '☀️', hora: '3 PM', label: 'Tarde',
                  color: AppTheme.orangeColor,
                  controller: _tardeCtrl, focusNode: _tardeFocus,
                ),
                const SizedBox(width: 10),
                _buildSlot(
                  emoji: '🌙', hora: '9 PM', label: 'Noche',
                  color: AppTheme.primaryColor,
                  controller: _nocheCtrl, focusNode: _nocheFocus,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Botón guardar ──────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_guardando ? 'Guardando...' : 'Guardar / Actualizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fecha con flechas ─────────────────────────────────────────────────────
  Widget _buildFechaSelector(String fechaStr, bool esHoy, bool puedeSiguiente) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esHoy ? AppTheme.goldColor.withOpacity(0.5) : AppTheme.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.06),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ← anterior
          _fechaBtn(Icons.chevron_left_rounded, () => _cambiarDia(-1)),

          // Centro: icono + texto (tappable para datepicker)
          Expanded(
            child: GestureDetector(
              onTap: _seleccionarFecha,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.goldColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_today_rounded,
                          color: AppTheme.goldColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          esHoy ? 'HOY' : 'Fecha seleccionada',
                          style: TextStyle(
                            fontSize: 10,
                            color: esHoy ? AppTheme.goldColor : Colors.grey,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          fechaStr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // → siguiente (deshabilitado si es hoy)
          _fechaBtn(
            Icons.chevron_right_rounded,
            puedeSiguiente ? () => _cambiarDia(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _fechaBtn(IconData icon, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Icon(
            icon,
            size: 22,
            color: onTap != null ? AppTheme.textSecondary : AppTheme.cardBorder,
          ),
        ),
      );

  // ── Slot de número ────────────────────────────────────────────────────────
  Widget _buildSlot({
    required String emoji,
    required String hora,
    required String label,
    required Color color,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(focusNode),
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) {
            final texto = controller.text;
            final numero = int.tryParse(texto);
            final sig = numero != null ? significadoCorto(numero) : null;
            final suma = numero != null
                ? (numero ~/ 10 + numero % 10).toString().padLeft(2, '0')
                : null;
            final lleno = texto.length == 2 && numero != null;

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: lleno ? color.withOpacity(0.6) : color.withOpacity(0.3),
                  width: lleno ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(lleno ? 0.12 : 0.05),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                  Text(hora,
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  const SizedBox(height: 8),

                  // Campo número
                  TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    validator: _validarNumero,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 2,
                    ),
                    decoration: InputDecoration(
                      hintText: '--',
                      hintStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.22),
                        letterSpacing: 2,
                      ),
                      counterText: '',
                      filled: true,
                      fillColor: color.withOpacity(0.06),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color.withOpacity(0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                      errorStyle: const TextStyle(fontSize: 9, height: 1),
                    ),
                  ),

                  // ── Preview significado ──────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: sig != null
                        ? Padding(
                            key: ValueKey(numero),
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              children: [
                                Text(
                                  '=$suma',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                                Text(
                                  sig,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: color.withOpacity(0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(key: ValueKey('empty'), height: 0),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _manianaCtrl.dispose();
    _tardeCtrl.dispose();
    _nocheCtrl.dispose();
    _manianFocus.dispose();
    _tardeFocus.dispose();
    _nocheFocus.dispose();
    super.dispose();
  }
}
