import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:io';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';

class PinLockScreen extends StatefulWidget {
  final bool isSetup; // true for setting up new PIN, false for verification

  const PinLockScreen({super.key, this.isSetup = false});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _showBiometric = false;
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _animationController = AnimationController(vsync: this);
    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    if (!widget.isSetup && Platform.isAndroid || Platform.isIOS) {
      final biometricEnabled = await SecurityService.isBiometricEnabled();
      final canUse = await SecurityService.canUseBiometric();
      setState(() => _showBiometric = biometricEnabled && canUse);
      
      // Auto-trigger biometric on launch if enabled
      if (_showBiometric) {
        _authenticateWithBiometric();
      }
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final success = await SecurityService.authenticateWithBiometric();
    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _onNumberPressed(String number) {
    if (widget.isSetup) {
      _handleSetupMode(number);
    } else {
      _handleVerifyMode(number);
    }
    
    // Animate when user starts typing
    final currentPin = _isConfirming ? _confirmPin : _pin;
    if (currentPin.length == 1) {
      // First digit entered - play animation forward (cover eyes)
      _animationController.forward();
    }
  }

  void _handleSetupMode(String number) {
    setState(() {
      if (!_isConfirming) {
        if (_pin.length < 6) {
          _pin += number;
          if (_pin.length == 6) {
            _isConfirming = true;
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += number;
          if (_confirmPin.length == 6) {
            _verifySetup();
          }
        }
      }
    });
  }

  void _handleVerifyMode(String number) {
    setState(() {
      if (_pin.length < 6) {
        _pin += number;
        if (_pin.length == 6) {
          _verifyPin();
        }
      }
    });
  }

  Future<void> _verifySetup() async {
    if (_pin == _confirmPin) {
      await SecurityService.setupPin(_pin);
      if (mounted) {
        ToastUtils.show(context, 'PIN set successfully', isError: false);
        Navigator.of(context).pop(true);
      }
    } else {
      ToastUtils.show(context, 'PINs do not match', isError: true);
      setState(() {
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      // Reset animation
      _animationController.reverse();
    }
  }

  Future<void> _verifyPin() async {
    final isValid = await SecurityService.verifyPin(_pin);
    if (isValid) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      ToastUtils.show(context, 'Invalid PIN', isError: true);
      setState(() => _pin = '');
      // Reset animation
      _animationController.reverse();
    }
  }

  void _onBackspace() {
    setState(() {
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        // If all digits removed, reverse animation (uncover eyes)
        if (_confirmPin.isEmpty) {
          _animationController.reverse();
        }
      } else if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
        // If all digits removed, reverse animation (uncover eyes)
        if (_pin.isEmpty) {
          _animationController.reverse();
        }
      } else if (_isConfirming && _confirmPin.isEmpty) {
        _isConfirming = false;
        _animationController.reverse();
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Handle number keys (0-9)
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      _onNumberPressed('0');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      _onNumberPressed('1');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      _onNumberPressed('2');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      _onNumberPressed('3');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      _onNumberPressed('4');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      _onNumberPressed('5');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      _onNumberPressed('6');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) {
      _onNumberPressed('7');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) {
      _onNumberPressed('8');
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) {
      _onNumberPressed('9');
      return KeyEventResult.handled;
    }
    // Handle backspace
    else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    // Handle Enter key (submit PIN)
    else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      final currentPin = _isConfirming ? _confirmPin : _pin;
      if (currentPin.length == 6) {
        if (widget.isSetup && !_isConfirming) {
          setState(() => _isConfirming = true);
        } else if (widget.isSetup && _isConfirming) {
          _verifySetup();
        } else {
          _verifyPin();
        }
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lottie animation with circular clip
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryPurple.withValues(alpha: 0.1),
                            AppTheme.primaryBlue.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Lottie.asset(
                          'assets/animations/Login character_Hello.json',
                          controller: _animationController,
                          fit: BoxFit.cover,
                          onLoaded: (composition) {
                            _animationController.duration = composition.duration;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isSetup
                          ? (_isConfirming ? 'Confirm PIN' : 'Set PIN')
                          : 'Enter PIN',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isSetup
                          ? (_isConfirming
                              ? 'Re-enter your 6-digit PIN'
                              : 'Create a 6-digit PIN')
                          : 'Enter your 6-digit PIN to unlock',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildPinDots(currentPin),
                    const SizedBox(height: 32),
                    _buildNumberPad(),
                    if (_showBiometric) ...[
                      const SizedBox(height: 16),
                      IconButton(
                        onPressed: _authenticateWithBiometric,
                        icon: const Icon(Icons.fingerprint, size: 40),
                        color: AppTheme.primaryPurple,
                        tooltip: 'Use biometric',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots(String pin) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppTheme.primaryPurple : Colors.transparent,
            border: Border.all(
              color: AppTheme.primaryPurple,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        _buildNumberRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildNumberRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildNumberRow(['7', '8', '9']),
        const SizedBox(height: 16),
        _buildNumberRow(['', '0', 'back']),
      ],
    );
  }

  Widget _buildNumberRow(List<String> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: numbers.map((number) {
        if (number.isEmpty) {
          return const SizedBox(width: 80, height: 80);
        }
        
        if (number == 'back') {
          return _buildBackspaceButton();
        }
        
        return _buildNumberButton(number);
      }).toList(),
    );
  }

  Widget _buildNumberButton(String number) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNumberPressed(number),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onBackspace,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.backspace_outlined,
                size: 28,
                color: AppTheme.primaryPurple,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
