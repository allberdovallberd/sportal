// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:go_router/go_router.dart';

// import '../../auth/providers/auth_session_provider.dart';
// import '../../auth/services/auth_api_client.dart';
// import '../../auth/models/auth_models.dart';
// import '../../../ui/sportal_colors.dart';
// import '../../../ui/sportal_text_styles.dart';
// import '../../../ui/widgets/sportal_background.dart';

// final profileDetailsProvider = FutureProvider.autoDispose<SportalUser>((ref) async {
//   final session = ref.watch(authSessionProvider);
//   if (!session.isAuthenticated) {
//     return session.user;
//   }

//   final api = ref.watch(authApiClientProvider);
//   final user = await api.fetchMe(accessToken: session.accessToken);
//   ref.read(authSessionProvider.notifier).setUser(user);
//   return user;
// });

// class ProfileDetailsPage extends ConsumerWidget {
//   const ProfileDetailsPage({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final asyncUser = ref.watch(profileDetailsProvider);
//     final fallbackUser = ref.watch(authSessionProvider).user;

//     return Scaffold(
//       body: SportalBackground(
//         child: SafeArea(
//           child: ListView(
//             padding: const EdgeInsets.fromLTRB(12, 24, 12, 20),
//             children: [
//               Row(
//                 children: [
//                   IconButton(
//                     onPressed: () => context.pop(),
//                     icon: const Icon(Icons.arrow_back, color: Colors.white),
//                     splashRadius: 18,
//                   ),
//                   const SizedBox(width: 4),
//                   Text(
//                     'Profil maglumatlary',
//                     style: SportalTextStyles.h2.copyWith(
//                       fontWeight: FontWeight.w700,
//                       fontSize: 24,
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 18),
//               asyncUser.when(
//                 loading: () => const Padding(
//                   padding: EdgeInsets.only(top: 80),
//                   child: Center(child: CircularProgressIndicator()),
//                 ),
//                 error: (error, _) => _ProfileDetailsContent(
//                   user: fallbackUser,
//                   errorText: '$error',
//                 ),
//                 data: (user) => _ProfileDetailsContent(user: user),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _ProfileDetailsContent extends StatelessWidget {
//   const _ProfileDetailsContent({required this.user, this.errorText});

//   final SportalUser user;
//   final String? errorText;

//   @override
//   Widget build(BuildContext context) {
//     final statusText = user.isVerified ? 'Tassyklanan' : 'Tassyklanmadyk';
//     final roleText = user.role == SportalUserRole.admin ? 'Admin' : 'Ulanyjy';

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         Container(
//           padding: const EdgeInsets.all(18),
//           decoration: BoxDecoration(
//             color: SportalColors.fieldBackground,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
//           ),
//           child: Column(
//             children: [
//               Container(
//                 width: 84,
//                 height: 84,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: Colors.white.withValues(alpha: 0.08),
//                   border: Border.all(
//                     color: SportalColors.primaryBlue.withValues(alpha: 0.6),
//                     width: 1.4,
//                   ),
//                 ),
//                 alignment: Alignment.center,
//                 child: SvgPicture.asset(
//                   'assets/icons/profile.svg',
//                   width: 36,
//                   height: 36,
//                   colorFilter: const ColorFilter.mode(
//                     Colors.white,
//                     BlendMode.srcIn,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               Text(
//                 user.email.isEmpty ? 'Ulanyjy' : user.email,
//                 textAlign: TextAlign.center,
//                 style: SportalTextStyles.h3.copyWith(
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Text(
//                 roleText,
//                 style: SportalTextStyles.b2.copyWith(
//                   color: Colors.white.withValues(alpha: 0.72),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 16),
//         Container(
//           decoration: BoxDecoration(
//             color: SportalColors.fieldBackground,
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
//           ),
//           child: Column(
//             children: [
//               _DetailRow(
//                 iconAsset: 'assets/icons/mail.svg',
//                 label: 'Email',
//                 value: user.email.isEmpty ? '-' : user.email,
//               ),
//               _divider(),
//               _DetailRow(
//                 iconAsset: 'assets/icons/shield-exclamation.svg',
//                 label: 'Status',
//                 value: statusText,
//               ),
//               _divider(),
//               _DetailRow(
//                 iconAsset: 'assets/icons/profile.svg',
//                 label: 'Rol',
//                 value: roleText,
//               ),
//               _divider(),
//               _DetailRow(
//                 iconAsset: 'assets/icons/information-circle.svg',
//                 label: 'ID',
//                 value: user.id.isEmpty ? '-' : user.id,
//                 isMultiline: true,
//               ),
//             ],
//           ),
//         ),
//         if (errorText != null) ...[
//           const SizedBox(height: 12),
//           Text(
//             errorText!,
//             style: SportalTextStyles.b2.copyWith(
//               color: SportalColors.errorRed,
//             ),
//           ),
//         ],
//       ],
//     );
//   }

//   Widget _divider() {
//     return Divider(
//       height: 1,
//       color: Colors.white.withValues(alpha: 0.14),
//     );
//   }
// }

// class _DetailRow extends StatelessWidget {
//   const _DetailRow({
//     required this.iconAsset,
//     required this.label,
//     required this.value,
//     this.isMultiline = false,
//   });

//   final String iconAsset;
//   final String label;
//   final String value;
//   final bool isMultiline;

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
//       child: Row(
//         crossAxisAlignment: isMultiline
//             ? CrossAxisAlignment.start
//             : CrossAxisAlignment.center,
//         children: [
//           SvgPicture.asset(
//             iconAsset,
//             width: 18,
//             height: 18,
//             colorFilter: const ColorFilter.mode(
//               Colors.white,
//               BlendMode.srcIn,
//             ),
//           ),
//           const SizedBox(width: 10),
//           SizedBox(
//             width: 70,
//             child: Text(
//               label,
//               style: SportalTextStyles.b2.copyWith(
//                 color: Colors.white.withValues(alpha: 0.72),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               value,
//               textAlign: TextAlign.right,
//               style: SportalTextStyles.b2.copyWith(
//                 fontWeight: FontWeight.w500,
//                 height: 1.35,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
