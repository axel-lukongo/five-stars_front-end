import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';

class ChatPage extends StatelessWidget {
  final String friendName;

  const ChatPage({
    super.key,
    required this.friendName,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final Color textColor =
        isDarkMode ? myLightBackground : MyprimaryDark;

    final Color senderBubbleColor = isDarkMode
        ? myAccentVibrantBlue.withOpacity(0.85)
        : myAccentVibrantBlue;

    final Color receiverBubbleColor = isDarkMode
        ? MyprimaryDark
        : Colors.grey[200]!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          friendName,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: Column(
        children: <Widget>[
          // ===== LISTE DES MESSAGES =====
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 10,
              itemBuilder: (BuildContext context, int index) {
                final bool isSender = index.isEven;

                return Align(
                  alignment: isSender
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(14),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isSender
                          ? senderBubbleColor
                          : receiverBubbleColor,
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomLeft: isSender
                            ? const Radius.circular(20)
                            : const Radius.circular(6),
                        bottomRight: isSender
                            ? const Radius.circular(6)
                            : const Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      isSender
                          ? "Salut $friendName 👋"
                          : "Hey ! Prêt pour le match ? ⚽",
                      style: TextStyle(
                        color: isSender
                            ? MyprimaryDark
                            : textColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ===== BARRE DE SAISIE =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Écrire un message...',
                        hintStyle: TextStyle(
                          color: isDarkMode
                              ? Colors.grey[500]
                              : Colors.grey[700],
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? MyprimaryDark.withOpacity(0.7)
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Message envoyé à $friendName'),
                        ),
                      );
                    },
                    backgroundColor: myAccentVibrantBlue,
                    elevation: 0,
                    child: const Icon(
                      Icons.send,
                      color: MyprimaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}