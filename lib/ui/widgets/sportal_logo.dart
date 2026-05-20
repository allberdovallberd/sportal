import 'package:flutter/material.dart';

class SportalLogo extends StatelessWidget {
  const SportalLogo({super.key, this.size = 176});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
    );
  }
}
