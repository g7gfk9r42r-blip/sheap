/// Name Step - Persönliche Ansprache
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/grocify_theme.dart';
import '../models/user_profile_local.dart';

class NameStep extends StatefulWidget {
  final UserProfileLocal profile;
  final Function(UserProfileLocal) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const NameStep({
    super.key,
    required this.profile,
    required this.onUpdate,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> {
  final _nameController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.name ?? '';
    // Auto-focus after a short delay for better UX
    Future.delayed(const Duration(milliseconds: 300), () {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateProfile() {
    widget.onUpdate(
      widget.profile.copyWith(name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasName = _nameController.text.trim().isNotEmpty;
    
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(
              left: GrocifyTheme.screenPadding,
              right: GrocifyTheme.screenPadding,
              top: GrocifyTheme.spaceXXXL,
              bottom: MediaQuery.of(context).viewInsets.bottom + GrocifyTheme.spaceLG,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - MediaQuery.of(context).viewInsets.bottom),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Text(
                      'Wie sollen wir dich nennen? 👋',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: GrocifyTheme.spaceMD),
                    Text(
                      'Optional – für eine persönliche Ansprache in der App.',
                      style: TextStyle(
                        fontSize: 16,
                        color: GrocifyTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXXXXL),
                    
                    // Name Input
                    TextField(
                      controller: _nameController,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Dein Name',
                        hintText: 'z.B. Roman',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                        ),
                        filled: true,
                        fillColor: GrocifyTheme.surface,
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        _updateProfile();
                      },
                      onSubmitted: (_) {
                        if (hasName) {
                          HapticFeedback.lightImpact();
                          widget.onNext();
                        }
                      },
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceXL),
                    
                    // Info
                    Container(
                      padding: const EdgeInsets.all(GrocifyTheme.spaceMD),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
                        border: Border.all(
                          color: GrocifyTheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: GrocifyTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: GrocifyTheme.spaceSM),
                          Expanded(
                            child: Text(
                              'Wir nutzen deinen Namen nur für die persönliche Ansprache in der App (z.B. "Hallo ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Roman'}").',
                              style: TextStyle(
                                fontSize: 13,
                                color: GrocifyTheme.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    const SizedBox(height: GrocifyTheme.spaceLG),
                    
                    // Next Button
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.onSkip();
                            },
                            child: const Text('Später'),
                          ),
                        ),
                        const SizedBox(width: GrocifyTheme.spaceMD),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: () {
                              _updateProfile();
                              HapticFeedback.mediumImpact();
                              widget.onNext();
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceLG),
                            ),
                            child: Text(
                              hasName ? 'Weiter 🚀' : 'Ohne Namen weiter',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceLG),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

