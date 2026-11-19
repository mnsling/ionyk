import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local workstation appearance preferences. Not server-wide configuration.
class IonykBrand extends ChangeNotifier {
  IonykBrand._();
  static final IonykBrand instance = IonykBrand._();
  static const _accentKey = 'ionyk_appearance_accent';
  static const _logoKey = 'ionyk_appearance_logo_b64';
  static const _nameKey = 'ionyk_appearance_business_name';
  final accents = const <String, Color>{
    'Electric Lime': Color(0xFFD9FF57),
    'Cobalt Blue': Color(0xFF85A9FF),
    'Soft Teal': Color(0xFF75DEBC),
    'Warm Coral': Color(0xFFFFAB89),
  };
  String selectedAccent = 'Electric Lime';
  String businessName = 'IONYK SYSTEMS';
  Uint8List? logo;
  Color get accent => accents[selectedAccent] ?? const Color(0xFFD9FF57);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      selectedAccent = prefs.getString(_accentKey) ?? selectedAccent;
      businessName = prefs.getString(_nameKey) ?? businessName;
      final saved = prefs.getString(_logoKey);
      if (saved != null && saved.isNotEmpty) logo = base64Decode(saved);
      notifyListeners();
    } catch (_) { /* Keep safe defaults if local settings are unavailable. */ }
  }

  Future<void> setAccent(String value) async {
    if (!accents.containsKey(value)) return;
    selectedAccent = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentKey, value);
  }

  Future<void> setBusinessName(String value) async {
    businessName = value.trim().isEmpty ? 'IONYK SYSTEMS' : value.trim();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, businessName);
  }

  Future<String?> chooseLogo() async {
    try {
      const group = XTypeGroup(label: 'Logo images', extensions: ['png', 'jpg', 'jpeg', 'webp']);
      final file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.length > 1024 * 1024) return 'Select an image smaller than 1 MB.';
      logo = bytes;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_logoKey, base64Encode(bytes));
      return null;
    } catch (e) {
      return 'Could not open image: $e';
    }
  }

  Future<void> clearLogo() async {
    logo = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logoKey);
  }
}

class IonykBrandMark extends StatelessWidget {
  const IonykBrandMark({super.key, this.size = 36, this.dark = true});
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: IonykBrand.instance,
    builder: (context, _) {
      final brand = IonykBrand.instance;
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * .28),
        child: Container(
          width: size, height: size,
          color: dark ? const Color(0xFF303837) : const Color(0xFF171B1C),
          child: brand.logo == null
            ? Icon(Icons.all_inclusive_rounded, color: brand.accent, size: size * .65)
            : Image.memory(brand.logo!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.all_inclusive_rounded, color: brand.accent)),
        ),
      );
    },
  );
}


class IonykBrandName extends StatelessWidget {
  const IonykBrandName({super.key, this.dark = true});
  final bool dark;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: IonykBrand.instance,
    builder: (context, _) {
      final parts = IonykBrand.instance.businessName.trim().split(RegExp(r'\s+'));
      final top = parts.first;
      final bottom = parts.length > 1 ? parts.skip(1).join(' ') : 'SYSTEMS';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(top, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: dark ? Colors.white : const Color(0xFF171B1C), fontWeight: FontWeight.w700, letterSpacing: -.4, height: 1.1)),
        Text(bottom.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, letterSpacing: 1.5, color: dark ? const Color(0xFFBEC0C4) : const Color(0xFF687272))),
      ]);
    },
  );
}
