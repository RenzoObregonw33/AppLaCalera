import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lacalera/models/registro_constants.dart';
import 'package:lacalera/models/country_model.dart';

// Widget para construir encabezados de sección
Widget buildSectionHeader({required String title, required IconData icon}) {
  return Row(
    children: [
      Icon(icon, color: PRIMARY_COLOR, size: ICON_SIZE),
      const SizedBox(width: SPACING_MEDIUM),
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: PRIMARY_COLOR,
        ),
      ),
    ],
  );
}

// Widget para construir botones de fotos del DNI
Widget buildFotoButton(String label, File? image, VoidCallback onTap) {
  return Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      const SizedBox(height: SPACING_MEDIUM),
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: PHOTO_BUTTON_SIZE,
          height: PHOTO_BUTTON_SIZE,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(INPUT_FIELD_RADIUS),
            border: Border.all(color: PRIMARY_COLOR, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: image != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(image, fit: BoxFit.cover),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt,
                      color: PRIMARY_COLOR,
                      size: LARGE_ICON_SIZE,
                    ),
                    const SizedBox(height: SPACING_MEDIUM),
                    Text(
                      "Tomar foto",
                      style: const TextStyle(
                        color: PRIMARY_COLOR,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ],
  );
}

// Widget selector de país
Widget buildCountrySelector(Country selectedCountry, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 100,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(INPUT_FIELD_RADIUS),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              selectedCountry.flag,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: SPACING_SMALL),
          Flexible(
            child: Text(
              selectedCountry.dialCode,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
        ],
      ),
    ),
  );
}

// Widget para el diálogo del selector de países
Widget buildCountryPickerDialog(
  BuildContext dialogContext,
  List<Country> countries,
  Function(Country) onCountrySelected,
) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      padding: const EdgeInsets.all(SPACING_LARGE),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Seleccionar País',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: SPACING_LARGE),
          SizedBox(
            height: 300,
            width: 300,
            child: ListView.builder(
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                return ListTile(
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(country.name),
                  trailing: Text(
                    country.dialCode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    onCountrySelected(country);
                    Navigator.pop(dialogContext);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: SPACING_LARGE),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
}
