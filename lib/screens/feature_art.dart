part of '../main.dart';

/// An illustration placed at the top of a screen, to match what it shows.
class FeatureArt extends StatelessWidget {
  const FeatureArt(this.asset, {this.height = 150, super.key});

  final String asset;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: SizedBox(
          height: height,
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
