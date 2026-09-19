import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/clipboard_service.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  double _length = 20;
  bool _useUpper = true;
  bool _useLower = true;
  bool _useDigits = true;
  bool _useSymbols = true;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const digits = '0123456789';
    const symbols = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    String pool = '';
    if (_useUpper) pool += upper;
    if (_useLower) pool += lower;
    if (_useDigits) pool += digits;
    if (_useSymbols) pool += symbols;

    if (pool.isEmpty) {
      setState(() => _generatedPassword = '');
      return;
    }

    final rand = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < _length.toInt(); i++) {
      buffer.write(pool[rand.nextInt(pool.length)]);
    }

    setState(() {
      _generatedPassword = buffer.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display da Senha Gerada
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                SelectableText(
                  _generatedPassword,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 1.2,
                    color: AppColors.accent,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Nova Senha'),
                      onPressed: _generate,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copiar'),
                      onPressed: () {
                        ClipboardService.copySecure(_generatedPassword);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Senha copiada para a área de transferência!')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Controles de Customização
          Text('Tamanho: ${_length.toInt()} caracteres', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Slider(
            value: _length,
            min: 8,
            max: 64,
            divisions: 56,
            label: _length.toInt().toString(),
            activeColor: AppColors.primaryLight,
            onChanged: (v) {
              setState(() => _length = v);
              _generate();
            },
          ),
          const SizedBox(height: 14),

          SwitchListTile(
            title: const Text('Letras Maiúsculas (A-Z)'),
            value: _useUpper,
            activeColor: AppColors.accent,
            onChanged: (v) {
              setState(() => _useUpper = v);
              _generate();
            },
          ),
          SwitchListTile(
            title: const Text('Letras Minúsculas (a-z)'),
            value: _useLower,
            activeColor: AppColors.accent,
            onChanged: (v) {
              setState(() => _useLower = v);
              _generate();
            },
          ),
          SwitchListTile(
            title: const Text('Números (0-9)'),
            value: _useDigits,
            activeColor: AppColors.accent,
            onChanged: (v) {
              setState(() => _useDigits = v);
              _generate();
            },
          ),
          SwitchListTile(
            title: const Text('Símbolos Especiais (!@#\$)'),
            value: _useSymbols,
            activeColor: AppColors.accent,
            onChanged: (v) {
              setState(() => _useSymbols = v);
              _generate();
            },
          ),
        ],
      ),
    );
  }
}
