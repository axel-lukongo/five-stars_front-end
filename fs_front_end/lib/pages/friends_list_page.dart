import 'package:flutter/material.dart';
import '../theme_config/colors_config.dart';
import 'chat_page.dart';
class FriendsListPage extends StatelessWidget {
  const FriendsListPage({super.key});

  final List<Map<String, String>> mockFriends = const <Map<String, String>>[
    {'name': 'Clara M.', 'status': 'En ligne', 'color': 'green'},
    {'name': 'Lucas T.', 'status': 'Dernièrement en ligne', 'color': 'yellow'},
    {'name': 'Sarah B.', 'status': 'Hors ligne', 'color': 'red'},
    {'name': 'David E.', 'status': 'En ligne', 'color': 'green'},
    {'name': 'Émilie P.', 'status': 'Hors ligne', 'color': 'red'},
    {'name': 'Gabriel S.', 'status': 'Dernièrement en ligne', 'color': 'yellow'},
    {'name': 'Léa C.', 'status': 'En ligne', 'color': 'green'},
    {'name': 'Antoine F.', 'status': 'Hors ligne', 'color': 'red'},
    {'name': 'Margaux L.', 'status': 'En ligne', 'color': 'green'},
    {'name': 'Nathan D.', 'status': 'Dernièrement en ligne', 'color': 'yellow'},
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color titleColor = isDarkMode ? myLightBackground : MyprimaryDark;
    final Color cardTitleColor = isDarkMode ? myLightBackground : MyprimaryDark;

    return Scaffold(
      appBar: AppBar(title: null),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 20),
            child: Text(
              'Mes Amis',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 90),
              itemCount: mockFriends.length,
              itemBuilder: (BuildContext context, int index) {
                final Map<String, String> friend = mockFriends[index];
                return Card(
                  elevation: 4,
                  margin:
                      const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Stack(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 25,
                          backgroundColor:
                              isDarkMode ? MyprimaryDark : MyprimaryDark,
                          child: Text(
                            friend['name']![0],
                            style: const TextStyle(
                              color: myAccentVibrantBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: friend['color'] == 'green'
                                  ? Colors.green
                                  : (friend['color'] == 'yellow'
                                      ? Colors.amber
                                      : Colors.red),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode
                                    ? myDarkBackground
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      friend['name']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cardTitleColor,
                      ),
                    ),
                    subtitle: Text(
                      friend['status']!,
                      style: TextStyle(
                        color:
                            isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        color:
                            isDarkMode ? myAccentVibrantBlue : MyprimaryDark,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                ChatPage(friendName: friend['name']!),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
