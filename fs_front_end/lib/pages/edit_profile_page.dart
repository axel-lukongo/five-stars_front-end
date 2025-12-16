import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  bool _isLoading = false;

  // Liste des postes possibles
  final List<String> _positions = [
    'Gardien',
    'Défenseur',
    'Milieu défensif',
    'Milieu offensif',
    'Ailier gauche',
    'Ailier droit',
    'Attaquant',
    'Buteur',
  ];

  String? _selectedPosition;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les valeurs actuelles
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      _phoneController.text = user.phone ?? '';
      _selectedPosition = user.preferredPosition;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.instance.updateCurrentUser(
      phone: _phoneController.text.trim(),
      preferredPosition: _selectedPosition,
    );

    setState(() => _isLoading = false);

    if (result['ok'] == true) {
      // Rafraîchir les données utilisateur dans le provider
      if (mounted) {
        await Provider.of<AuthProvider>(
          context,
          listen: false,
        ).refreshCurrentUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Erreur lors de la mise à jour',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;
    final Color inputFillColor = isDarkMode
        ? Colors.grey[800]!
        : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier le profil',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informations personnelles',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Modifiez vos informations de profil',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 30),

                // Champ Téléphone
                Text(
                  'Numéro de téléphone',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Ex: 06 12 34 56 78',
                    prefixIcon: Icon(Icons.phone, color: myAccentVibrantBlue),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: myAccentVibrantBlue,
                        width: 2,
                      ),
                    ),
                  ),
                  style: TextStyle(color: titleColor),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Validation basique du format téléphone
                      final phoneRegex = RegExp(r'^[0-9\s\+\-\.]+$');
                      if (!phoneRegex.hasMatch(value)) {
                        return 'Format de téléphone invalide';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Champ Poste préféré
                Text(
                  'Poste préféré',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPosition,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.sports_soccer,
                      color: myAccentVibrantBlue,
                    ),
                    filled: true,
                    fillColor: inputFillColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: myAccentVibrantBlue,
                        width: 2,
                      ),
                    ),
                  ),
                  dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                  style: TextStyle(color: titleColor),
                  hint: Text(
                    'Sélectionnez votre poste',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  items: _positions.map((position) {
                    return DropdownMenuItem<String>(
                      value: position,
                      child: Text(position),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPosition = value;
                    });
                  },
                ),
                const SizedBox(height: 40),

                // Bouton Sauvegarder
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myAccentVibrantBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Sauvegarder',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Bouton Annuler
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: myAccentVibrantBlue, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Annuler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: myAccentVibrantBlue,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
