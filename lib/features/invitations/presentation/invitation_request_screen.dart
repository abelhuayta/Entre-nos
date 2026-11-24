import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../auth/providers/auth_controller.dart';

class InvitationRequestScreen extends ConsumerStatefulWidget {
  const InvitationRequestScreen({super.key});

  @override
  ConsumerState<InvitationRequestScreen> createState() =>
      _InvitationRequestScreenState();
}

class _InvitationRequestScreenState
    extends ConsumerState<InvitationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = await ref
        .read(authControllerProvider.notifier)
        .redeemInvitation(_codeController.text);

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  Future<void> _claimInitialAdmin() async {
    final error =
        await ref.read(authControllerProvider.notifier).claimInitialAdmin();

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Acceso al círculo'),
        actions: [
          IconButton(
            onPressed: isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blackSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(
                  'VERIFICACIÓN DE INVITACIÓN',
                  style: AppTypography.labelSmall.copyWith(letterSpacing: 0.9),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Ingresa tu código privado',
                style: AppTypography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pide al administrador de ENTRE NOS un código personal para enviar tu solicitud de ingreso.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.gray),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AppTextField(
                controller: _codeController,
                label: 'Código de invitación',
                hint: 'EN-XXXX-XX',
                prefixIcon: Icons.vpn_key_outlined,
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if ((value?.trim().length ?? 0) < 4) {
                    return 'Ingresa un código de invitación válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Validar código y solicitar acceso',
                isLoading: isLoading,
                onPressed: _redeem,
              ),
              const SizedBox(height: AppSpacing.xxxl),
              const Divider(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '¿Eres quien creó este grupo?',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Si aún no existe administrador en el círculo, puedes activarlo ahora como fundador.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Activar como Administrador Inicial',
                variant: AppButtonVariant.secondary,
                icon: Icons.admin_panel_settings_outlined,
                isLoading: isLoading,
                onPressed: _claimInitialAdmin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}