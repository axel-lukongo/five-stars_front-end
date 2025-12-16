import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_config/colors_config.dart';
import 'my_textfield.dart';
import 'signup.dart';
import '../providers/auth_provider.dart';
import '../main_screen.dart';
// // Définition des couleurs
// const Color MyprimaryDark = Color(
//   0xFF1B263B,
// ); // Dark Charcoal/Blue-Grey (Utilisé pour le texte en Light Mode)
// const Color myAccentVibrantBlue = Color(
//   0xFF00BFFF,
// ); // Bleu Ciel Vif pour les accents (énergie du foot, alternative au lime)
// const Color myLightBackground = Colors.white; // Blanc pur
// const Color myDarkBackground = Color(
//   0xFF121212,
// ); // Noir très sombre pour le Dark

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _login() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final username = usernameController.text.trim();
    final password = passwordController.text;

    auth.login(username, password).then((res) {
      if (res['ok'] == true) {
        // Remplace la route par l'écran principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Erreur de connexion'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                const Image(
                  image: AssetImage('assets/logos/soccer_silhouette_white.png'),
                  width: 150,
                  height: 150,
                ),
                const Text(
                  "FIVE-STAR",
                  style: TextStyle(
                    fontSize: 30,
                    color: myAccentVibrantBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
                MyTextField(
                  controller: usernameController,
                  hintText: 'Username',
                  obscureText: false,
                ),
                const SizedBox(height: 16),
                MyTextField(
                  controller: passwordController,
                  hintText: 'Password',
                  obscureText: true,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/forgot_password'),
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: myAccentVibrantBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 80,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 22,
                                color: MyprimaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          color: myAccentVibrantBlue,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: 25),
                        child: Divider(color: Colors.white24, thickness: 0.5),
                      ),
                    ),
                    Text(
                      "Or continue with",
                      style: TextStyle(color: Colors.white70),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: 25),
                        child: Divider(color: Colors.white24, thickness: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => debugPrint("Google"),
                      icon: const Image(
                        image: AssetImage('assets/logos/google_logo_icon.png'),
                        height: 40,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      onPressed: () => debugPrint("Apple"),
                      icon: const Image(
                        image: AssetImage('assets/logos/apple_logo_icon.png'),
                        height: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
