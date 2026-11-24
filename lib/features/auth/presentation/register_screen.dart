import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
          nickname: _nicknameController.text,
          invitationCode: _inviteCodeController.text,
        );

    if (!mounted) return;

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
      return;
    }

    if (result.needsEmailConfirmation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cuenta creada. Revisa tu correo para confirmarla e inicia sesión.',
          ),
        ),
      );
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AppScaffold(
      appBar: AppBar(title: const Text('Crear cuenta privada')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Únete al círculo',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'El acceso está limitado a 30 amigos autorizados por invitación.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.gray),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppTextField(
                controller: _nameController,
                label: 'Nombre completo',
                hint: 'Cómo te conocen tus amigos',
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 2) {
                    return 'Ingresa tu nombre (mínimo 2 caracteres).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _nicknameController,
                label: 'Nickname único',
                hint: 'ej. abel_aqp',
                prefixIcon: Icons.alternate_email_rounded,
                validator: (value) {
                  final clean = value?.trim() ?? '';
                  if (!RegExp(r'^[a-zA-Z0-9_]{3,24}$').hasMatch(clean)) {
                    return 'Usa entre 3 y 24 caracteres (letras, números o _).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _emailController,
                label: 'Correo electrónico',
                hint: 'tu@correo.com',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty || !v.contains('@')) {
                    return 'Ingresa un correo válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _passwordController,
                label: 'Contraseña',
                hint: 'Mínimo 8 caracteres',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return 'La contraseña debe tener al menos 8 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _inviteCodeController,
                label: 'Código de invitación',
                hint: 'Ej. EN-8492-X (opcional si eres el fundador)',
                prefixIcon: Icons.vpn_key_outlined,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'Registrarme',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Ya tengo cuenta · Iniciar sesión',
                variant: AppButtonVariant.ghost,
                onPressed:
                    isLoading ? null : () => context.go(RouteNames.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}