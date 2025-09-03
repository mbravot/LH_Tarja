import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumericTextField extends StatelessWidget {
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: allowDecimal 
          ? TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      textInputAction: TextInputAction.done,
      enableInteractiveSelection: true,
      inputFormatters: allowDecimal 
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : [FilteringTextInputFormatter.digitsOnly],
      onTap: onTap,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: prefixIconColor ?? Colors.green)
            : null,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: validator,
      onEditingComplete: () {
        // Forzar el teclado numérico al completar la edición
        if (allowDecimal) {
          SystemChannels.textInput.invokeMethod('TextInput.setKeyboardType', {
            'type': 'TextInputType.numberWithOptions',
            'options': {'decimal': true}
          });
        } else {
          SystemChannels.textInput.invokeMethod('TextInput.setKeyboardType', {
            'type': 'TextInputType.number'
          });
        }
      },
    );
  }
}
