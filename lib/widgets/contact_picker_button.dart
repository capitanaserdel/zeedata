import 'package:flutter/material.dart';
import '../services/contact_service.dart';

class ContactPickerButton extends StatefulWidget {
  final TextEditingController? controller;
  final Function(ContactPickerResult result)? onContactPicked;
  final Color? iconColor;

  const ContactPickerButton({
    super.key,
    this.controller,
    this.onContactPicked,
    this.iconColor,
  });

  @override
  State<ContactPickerButton> createState() => _ContactPickerButtonState();
}

class _ContactPickerButtonState extends State<ContactPickerButton> {
  final ContactService _contactService = ContactService();
  bool _isPicking = false;

  Future<void> _handlePickContact() async {
    if (_isPicking) return;

    setState(() => _isPicking = true);

    final result = await _contactService.pickContact();

    if (result.success && result.phoneNumber != null) {
      if (widget.controller != null) {
        widget.controller!.text = result.phoneNumber!;
      }
      if (widget.onContactPicked != null) {
        widget.onContactPicked!(result);
      }
    } else if (result.error != null && result.error != 'No contact selected') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _isPicking ? null : _handlePickContact,
      icon: _isPicking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              Icons.contact_phone_rounded,
              color: widget.iconColor ?? const Color(0xFF011B60),
            ),
      tooltip: 'Pick from contacts',
    );
  }
}
