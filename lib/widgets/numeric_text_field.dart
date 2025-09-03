import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumericTextField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Color? prefixIconColor;
  final bool allowDecimal;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final bool enabled;
  final FocusNode? focusNode;
  final bool forceNumericKeyboard;

  const NumericTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.prefixIcon,
    this.prefixIconColor,
    this.allowDecimal = true,
    this.validator,
    this.onTap,
    this.enabled = true,
    this.focusNode,
    this.forceNumericKeyboard = true,
  }) : super(key: key);

  @override
  State<NumericTextField> createState() => _NumericTextFieldState();
}

class _NumericTextFieldState extends State<NumericTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && !_isFocused) {
      _isFocused = true;
      _forceNumericKeyboard();
    } else if (!_focusNode.hasFocus && _isFocused) {
      _isFocused = false;
    }
  }

  void _forceNumericKeyboard() {
    if (widget.forceNumericKeyboard) {
      // Forzar el teclado numérico usando SystemChannels
      if (widget.allowDecimal) {
        SystemChannels.textInput.invokeMethod('TextInput.setKeyboardType', {
          'type': 'TextInputType.numberWithOptions',
          'options': {'decimal': true}
        });
      } else {
        SystemChannels.textInput.invokeMethod('TextInput.setKeyboardType', {
          'type': 'TextInputType.number'
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: widget.allowDecimal 
          ? TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      textInputAction: TextInputAction.done,
      enableInteractiveSelection: true,
      inputFormatters: widget.allowDecimal 
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [FilteringTextInputFormatter.digitsOnly],
      onTap: () {
        widget.onTap?.call();
        _forceNumericKeyboard();
      },
      onEditingComplete: () {
        _forceNumericKeyboard();
      },
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon != null 
            ? Icon(widget.prefixIcon, color: widget.prefixIconColor ?? Colors.green)
            : null,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: widget.validator,
    );
  }
}
