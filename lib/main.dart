import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const ShuvamFootballClubApp());
}

class ShuvamFootballClubApp extends StatelessWidget {
  const ShuvamFootballClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SHUVAM FC',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.blue,
          primary: AppColors.blue,
          secondary: AppColors.green,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.page,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: AppColors.dark,
          foregroundColor: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.green.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
        ),
      ),
      home: const ClubShell(),
    );
  }
}

class AppColors {
  static const Color dark = Color(0xFF071B33);
  static const Color blue = Color(0xFF0B5ED7);
  static const Color green = Color(0xFF18A558);
  static const Color mint = Color(0xFFE7F7EE);
  static const Color sky = Color(0xFFE9F2FF);
  static const Color page = Color(0xFFF4F8FB);
  static const Color ink = Color(0xFF162235);
  static const Color muted = Color(0xFF667085);
  static const Color line = Color(0xFFDDE5EE);
}

class ApiService {
  ApiService({this.baseUrl = 'http://localhost:3000/api'});

  final String baseUrl;

  Future<List<T>> fetchList<T>(
    String collection,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final response = await http.get(Uri.parse('$baseUrl/$collection'));

    if (response.statusCode != 200) {
      throw Exception('Could not load $collection');
    }

    final List<dynamic> decoded = jsonDecode(response.body);
    return decoded
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String memberId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'memberId': memberId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  Future<void> saveItem(
    String collection,
    Map<String, dynamic> item,
    String adminEmail,
  ) async {
    final String id = item['id']?.toString() ?? '';
    final bool isEditing = id.isNotEmpty;
    final response = isEditing
        ? await http.put(
            Uri.parse('$baseUrl/$collection/$id'),
            headers: _adminHeaders(adminEmail),
            body: jsonEncode(item),
          )
        : await http.post(
            Uri.parse('$baseUrl/$collection'),
            headers: _adminHeaders(adminEmail),
            body: jsonEncode(item),
          );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not save $collection item');
    }
  }

  Future<void> deleteItem(
    String collection,
    String id,
    String adminEmail,
  ) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/$collection/$id'),
      headers: {'x-admin-email': adminEmail},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Could not delete $collection item');
    }
  }

  Map<String, String> _adminHeaders(String adminEmail) {
    return {'Content-Type': 'application/json', 'x-admin-email': adminEmail};
  }
}

class AppController extends ChangeNotifier {
  AppController();

  final ApiService _api = ApiService();
  bool isLoading = true;
  bool isBackendOnline = false;
  bool isAdmin = false;
  String userEmail = '';
  String memberId = '';
  String errorMessage = '';

  List<Player> players = _fallbackPlayers;
  List<Fixture> fixtures = _fallbackFixtures;
  List<ClubNews> news = _fallbackNews;
  List<FormationLayout> formations = _fallbackFormations;
  List<ClubUpdate> updates = _fallbackUpdates;

  Future<void> loadAll() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.fetchList('players', Player.fromJson),
        _api.fetchList('matches', Fixture.fromJson),
        _api.fetchList('news', ClubNews.fromJson),
        _api.fetchList('formations', FormationLayout.fromJson),
        _api.fetchList('updates', ClubUpdate.fromJson),
      ]);

      players = results[0] as List<Player>;
      fixtures = results[1] as List<Fixture>;
      news = results[2] as List<ClubNews>;
      formations = results[3] as List<FormationLayout>;
      updates = results[4] as List<ClubUpdate>;
      isBackendOnline = true;
    } catch (error) {
      isBackendOnline = false;
      errorMessage = 'Backend offline. Showing starter data.';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String memberIdValue) async {
    final result = await _api.login(email: email, memberId: memberIdValue);
    final user = Map<String, dynamic>.from(result['user']);

    userEmail = user['email']?.toString() ?? email;
    memberId = user['memberId']?.toString() ?? memberIdValue;
    isAdmin = result['isAdmin'] == true;
    isBackendOnline = true;
    notifyListeners();
  }

  Future<void> savePlayer(Player player) async {
    await _save('players', player.toJson());
  }

  Future<void> deletePlayer(Player player) async {
    await _delete('players', player.id);
  }

  Future<void> saveFixture(Fixture fixture) async {
    await _save('matches', fixture.toJson());
  }

  Future<void> deleteFixture(Fixture fixture) async {
    await _delete('matches', fixture.id);
  }

  Future<void> saveNews(ClubNews item) async {
    await _save('news', item.toJson());
  }

  Future<void> deleteNews(ClubNews item) async {
    await _delete('news', item.id);
  }

  Future<void> saveUpdate(ClubUpdate item) async {
    await _save('updates', item.toJson());
  }

  Future<void> deleteUpdate(ClubUpdate item) async {
    await _delete('updates', item.id);
  }

  Future<void> saveFormation(FormationLayout item) async {
    await _save('formations', item.toJson());
  }

  Future<void> deleteFormation(FormationLayout item) async {
    await _delete('formations', item.id);
  }

  Future<void> _save(String collection, Map<String, dynamic> item) async {
    _requireAdmin();
    await _api.saveItem(collection, item, userEmail);
    await loadAll();
  }

  Future<void> _delete(String collection, String id) async {
    _requireAdmin();
    await _api.deleteItem(collection, id, userEmail);
    await loadAll();
  }

  void _requireAdmin() {
    if (!isAdmin) {
      throw Exception('Admin login required.');
    }
  }

  static const List<Player> _fallbackPlayers = [
    Player(
      id: 'p1',
      number: 1,
      name: 'Ayush Giri',
      position: 'Goalkeeper',
      age: 23,
    ),
    Player(
      id: 'p2',
      number: 4,
      name: 'Anil Neupane',
      position: 'Defender',
      age: 22,
    ),
    Player(
      id: 'p3',
      number: 5,
      name: 'Suprim Rai',
      position: 'Defender',
      age: 22,
    ),
    Player(
      id: 'p4',
      number: 8,
      name: 'Prashanna Bhattrai',
      position: 'Midfielder',
      age: 22,
    ),
    Player(
      id: 'p5',
      number: 10,
      name: 'Shuvam Gautam',
      position: 'Midfielder',
      age: 22,
    ),
    Player(
      id: 'p6',
      number: 9,
      name: 'Shri Manandhar',
      position: 'Forward',
      age: 22,
    ),
    Player(
      id: 'p7',
      number: 11,
      name: 'Roshan Rijal',
      position: 'Forward',
      age: 21,
    ),
    Player(
      id: 'p8',
      number: 21,
      name: 'Ishan Kafle',
      position: 'Forward',
      age: 23,
    ),
    Player(
      id: 'p9',
      number: 13,
      name: 'Kamal Joshi',
      position: 'Forward',
      age: 23,
    ),
    Player(
      id: 'p10',
      number: 12,
      name: 'Aasish Acharya',
      position: 'Forward',
      age: 22,
    ),
    Player(
      id: 'p11',
      number: 19,
      name: 'Arpan B.K',
      position: 'Forward',
      age: 25,
    ),
  ];

  static const List<Fixture> _fallbackFixtures = [
    Fixture(
      id: 'm1',
      homeTeam: 'SHUVAM FC',
      awayTeam: 'Summit United',
      date: 'Sunday, June 2',
      time: '4:30 PM',
      venue: 'Shuvam Arena',
      status: 'Upcoming',
      competition: 'League',
      result: '',
    ),
    Fixture(
      id: 'm2',
      homeTeam: 'SHUVAM FC',
      awayTeam: 'Valley Rangers',
      date: 'Saturday, June 8',
      time: '3:00 PM',
      venue: 'City Stadium',
      status: 'Away',
      competition: 'Cup',
      result: '',
    ),
    Fixture(
      id: 'm3',
      homeTeam: 'Hill Stars',
      awayTeam: 'SHUVAM FC',
      date: 'Friday, June 14',
      time: '5:15 PM',
      venue: 'Hill Ground',
      status: 'League',
      competition: 'League',
      result: '',
    ),
    Fixture(
      id: 'm4',
      homeTeam: 'SHUVAM FC',
      awayTeam: 'River Boys',
      date: 'Saturday, May 18',
      time: '4:00 PM',
      venue: 'Shuvam Arena',
      status: 'Result',
      competition: 'League',
      result: '3 - 1',
    ),
    Fixture(
      id: 'm5',
      homeTeam: 'SHUVAM FC',
      awayTeam: 'Mountain City',
      date: 'Sunday, May 12',
      time: '2:30 PM',
      venue: 'City Stadium',
      status: 'Result',
      competition: 'Friendly',
      result: '2 - 2',
    ),
    Fixture(
      id: 'm6',
      homeTeam: 'Green Valley',
      awayTeam: 'SHUVAM FC',
      date: 'Saturday, May 4',
      time: '5:00 PM',
      venue: 'Valley Park',
      status: 'Result',
      competition: 'Cup',
      result: '0 - 1',
    ),
  ];

  static const List<FormationLayout> _fallbackFormations = [
    FormationLayout(
      id: 'f1',
      name: '4-3-3',
      style: 'Wide attack',
      lines: [
        ['11 Roshan', '9 Shri', '21 Ishan'],
        ['8 Prashanna', '10 Shuvam', '13 Kamal'],
        ['4 Anil', '5 Suprim', '19 Arpan', '12 Aasish'],
        ['1 Ayush'],
      ],
    ),
    FormationLayout(
      id: 'f2',
      name: '4-4-2',
      style: 'Balanced classic',
      lines: [
        ['11 Roshan', '9 Shri'],
        ['21 Ishan', '8 Prashanna', '10 Shuvam', '13 Kamal'],
        ['4 Anil', '5 Suprim', '19 Arpan', '12 Aasish'],
        ['1 Ayush'],
      ],
    ),
    FormationLayout(
      id: 'f3',
      name: '3-5-2',
      style: 'Midfield control',
      lines: [
        ['11 Roshan', '9 Shri'],
        ['21 Ishan', '8 Prashanna', '10 Shuvam', '13 Kamal', '12 Aasish'],
        ['4 Anil', '5 Suprim', '19 Arpan'],
        ['1 Ayush'],
      ],
    ),
    FormationLayout(
      id: 'f4',
      name: '4-2-3-1',
      style: 'Press and create',
      lines: [
        ['9 Shri'],
        ['11 Roshan', '10 Shuvam', '21 Ishan'],
        ['8 Prashanna', '13 Kamal'],
        ['4 Anil', '5 Suprim', '19 Arpan', '12 Aasish'],
        ['1 Ayush'],
      ],
    ),
    FormationLayout(
      id: 'f5',
      name: '5-3-2',
      style: 'Defensive wall',
      lines: [
        ['11 Roshan', '9 Shri'],
        ['8 Prashanna', '10 Shuvam', '13 Kamal'],
        ['4 Anil', '5 Suprim', '19 Arpan', '12 Aasish', '21 Ishan'],
        ['1 Ayush'],
      ],
    ),
  ];

  static const List<ClubNews> _fallbackNews = [
    ClubNews(
      id: 'n1',
      icon: Icons.fitness_center,
      title: 'Training Schedule Updated',
      category: 'Training',
      message:
          'Evening training starts at 5:30 PM every Monday, Wednesday, and Friday.',
      detail:
          'Players should arrive 15 minutes early for warm-up, hydration check, and tactical briefing.',
    ),
    ClubNews(
      id: 'n2',
      icon: Icons.sports_score,
      title: 'Home Match This Sunday',
      category: 'Match',
      message: 'SHUVAM FC hosts Summit United at Shuvam Arena this Sunday.',
      detail:
          'Supporters are encouraged to wear blue and green. Gates open one hour before kickoff.',
    ),
    ClubNews(
      id: 'n3',
      icon: Icons.person_add_alt_1,
      title: 'New Forward Joins Squad',
      category: 'Squad',
      message:
          'SHUVAM FC welcomes young forward Anish Tamang to the senior team.',
      detail:
          'Anish brings pace, pressing, and confident finishing to the attacking unit.',
    ),
    ClubNews(
      id: 'n4',
      icon: Icons.volunteer_activism,
      title: 'Community Coaching Day',
      category: 'Community',
      message: 'The club will host a free youth coaching session next weekend.',
      detail:
          'Young players can learn passing, movement, teamwork, and match basics from the SHUVAM FC squad.',
    ),
  ];

  static const List<ClubUpdate> _fallbackUpdates = [
    ClubUpdate(
      id: 'u1',
      title: 'Club Office Hours',
      message: 'The club office opens from 10 AM to 4 PM on training days.',
    ),
    ClubUpdate(
      id: 'u2',
      title: 'Kit Collection',
      message: 'Members can collect new blue-green kits after Friday training.',
    ),
  ];
}

class ClubShell extends StatefulWidget {
  const ClubShell({super.key});

  @override
  State<ClubShell> createState() => _ClubShellState();
}

class _ClubShellState extends State<ClubShell> {
  int _selectedIndex = 0;
  late final AppController _app;

  final List<String> _titles = const [
    'SHUVAM FC',
    'Matches',
    'Team',
    'News',
    'Profile',
    'Admin',
  ];

  @override
  void initState() {
    super.initState();
    _app = AppController()..loadAll();
  }

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
  }

  void _changePage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(onSelectTab: _changePage, app: _app),
      MatchesPage(app: _app),
      TeamPage(app: _app),
      NewsPage(app: _app),
      ProfilePage(app: _app),
      AdminPage(app: _app),
    ];

    return AnimatedBuilder(
      animation: _app,
      builder: (context, child) => Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const ClubBadge(size: 34),
              const SizedBox(width: 10),
              Text(_titles[_selectedIndex]),
              const Spacer(),
              IconButton(
                onPressed: _app.loadAll,
                icon: Icon(
                  _app.isBackendOnline ? Icons.cloud_done : Icons.cloud_off,
                ),
                tooltip: _app.isBackendOnline
                    ? 'Backend connected'
                    : 'Backend offline',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: StadiumBackdrop()),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: pages[_selectedIndex],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _changePage,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_soccer_outlined),
              selectedIcon: Icon(Icons.sports_soccer),
              label: 'Matches',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Team',
            ),
            NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'News',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.onSelectTab, required this.app});

  final ValueChanged<int> onSelectTab;
  final AppController app;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _fanEnergy = 82;
  final Set<int> _checkedItems = {0, 2};

  final List<String> _matchDayItems = const [
    'Bring blue scarf',
    'Arrive 30 min early',
    'Hydrate after training',
    'Invite a friend',
  ];

  void _toggleChecklistItem(int index, bool? value) {
    setState(() {
      if (value == true) {
        _checkedItems.add(index);
      } else {
        _checkedItems.remove(index);
      }
    });
  }

  void _showCheerMessage() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fan energy boosted to ${_fanEnergy.round()}%!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const HomeHero(),
        const SizedBox(height: 16),
        MatchCommandCard(onViewMatches: () => widget.onSelectTab(1)),
        const SizedBox(height: 16),
        SectionHeader(
          title: 'Club Pulse',
          actionText: 'Team',
          onActionTap: () => widget.onSelectTab(2),
        ),
        const SizedBox(height: 10),
        const StatsBoard(),
        const SizedBox(height: 16),
        ClubUpdatesCard(updates: widget.app.updates),
        const SizedBox(height: 16),
        QuickActionGrid(onSelectTab: widget.onSelectTab),
        const SizedBox(height: 16),
        FanEnergyCard(
          energy: _fanEnergy,
          onChanged: (value) => setState(() => _fanEnergy = value),
          onCheer: _showCheerMessage,
        ),
        const SizedBox(height: 16),
        MatchDayChecklist(
          items: _matchDayItems,
          checkedItems: _checkedItems,
          onChanged: _toggleChecklistItem,
        ),
      ],
    );
  }
}

class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [AppColors.dark, AppColors.blue, AppColors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ClubBadge(size: 66),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Match Ready',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'SHUVAM FC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Welcome to SHUVAM FC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'A modern club space for fixtures, players, news, and match-day energy.',
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HeroChip(icon: Icons.shield, text: 'Blue Green Army'),
              HeroChip(icon: Icons.terrain, text: 'Climb Higher'),
              HeroChip(icon: Icons.sports_soccer, text: 'Football First'),
            ],
          ),
        ],
      ),
    );
  }
}

class MatchCommandCard extends StatelessWidget {
  const MatchCommandCard({super.key, required this.onViewMatches});

  final VoidCallback onViewMatches;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_available, color: AppColors.blue),
              SizedBox(width: 8),
              Text(
                'Next Match',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              Spacer(),
              StatusPill(text: 'Home', color: AppColors.green),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const TeamMiniBadge(name: 'SFC', color: AppColors.blue),
              const Expanded(
                child: Column(
                  children: [
                    Text(
                      'SHUVAM FC',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'vs',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Summit United',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              TeamMiniBadge(name: 'SU', color: Colors.green.shade700),
            ],
          ),
          const SizedBox(height: 18),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoBadge(icon: Icons.calendar_today, text: 'Sun, Jun 2'),
              InfoBadge(icon: Icons.schedule, text: '4:30 PM'),
              InfoBadge(icon: Icons.location_on, text: 'Shuvam Arena'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onViewMatches,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Open Match Center'),
            ),
          ),
        ],
      ),
    );
  }
}

class StatsBoard extends StatelessWidget {
  const StatsBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool twoColumns = constraints.maxWidth > 430;

        return GridView.count(
          crossAxisCount: twoColumns ? 4 : 2,
          childAspectRatio: twoColumns ? 1.15 : 1.35,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            StatTile(icon: Icons.groups, value: '24', label: 'Players'),
            StatTile(icon: Icons.sports_soccer, value: '18', label: 'Matches'),
            StatTile(icon: Icons.emoji_events, value: '12', label: 'Wins'),
            StatTile(icon: Icons.trending_up, value: '67%', label: 'Win Rate'),
          ],
        );
      },
    );
  }
}

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth > 520;

        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          childAspectRatio: wide ? 1.65 : 1.35,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            QuickActionCard(
              icon: Icons.person_add_alt_1,
              title: 'Join Club',
              subtitle: 'Start profile',
              color: AppColors.green,
              onTap: () => onSelectTab(4),
            ),
            QuickActionCard(
              icon: Icons.calendar_month,
              title: 'Fixtures',
              subtitle: 'Match center',
              color: AppColors.blue,
              onTap: () => onSelectTab(1),
            ),
            QuickActionCard(
              icon: Icons.groups_2,
              title: 'Squad',
              subtitle: 'Players',
              color: AppColors.dark,
              onTap: () => onSelectTab(2),
            ),
            QuickActionCard(
              icon: Icons.campaign,
              title: 'News',
              subtitle: 'Announcements',
              color: Colors.orange.shade700,
              onTap: () => onSelectTab(3),
            ),
          ],
        );
      },
    );
  }
}

class ClubUpdatesCard extends StatelessWidget {
  const ClubUpdatesCard({super.key, required this.updates});

  final List<ClubUpdate> updates;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.blue),
              SizedBox(width: 8),
              Text(
                'Club Updates',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (updates.isEmpty)
            const Text(
              'No updates posted yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            for (final update in updates.take(3)) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.circle,
                  size: 10,
                  color: AppColors.green,
                ),
                title: Text(
                  update.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(update.message),
              ),
            ],
        ],
      ),
    );
  }
}

class FanEnergyCard extends StatelessWidget {
  const FanEnergyCard({
    super.key,
    required this.energy,
    required this.onChanged,
    required this.onCheer,
  });

  final double energy;
  final ValueChanged<double> onChanged;
  final VoidCallback onCheer;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq, color: AppColors.green),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Fan Energy Meter',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(
                '${energy.round()}%',
                style: const TextStyle(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Slider(
            value: energy,
            min: 0,
            max: 100,
            divisions: 20,
            label: '${energy.round()}%',
            onChanged: onChanged,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Set the crowd mood before kickoff.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onCheer,
                icon: const Icon(Icons.volume_up),
                label: const Text('Cheer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MatchDayChecklist extends StatelessWidget {
  const MatchDayChecklist({
    super.key,
    required this.items,
    required this.checkedItems,
    required this.onChanged,
  });

  final List<String> items;
  final Set<int> checkedItems;
  final void Function(int index, bool? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist, color: AppColors.blue),
              SizedBox(width: 8),
              Text(
                'Match-Day Checklist',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (int index = 0; index < items.length; index++)
            CheckboxListTile(
              value: checkedItems.contains(index),
              onChanged: (value) => onChanged(index, value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(items[index]),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key, required this.app});

  final AppController app;

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  String _filter = 'Upcoming';

  List<Fixture> get _visibleFixtures {
    if (_filter == 'Recent') {
      return widget.app.fixtures
          .where((fixture) => fixture.status == 'Result')
          .toList();
    }
    if (_filter == 'All') {
      return widget.app.fixtures;
    }

    return widget.app.fixtures
        .where((fixture) => fixture.status != 'Result')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const MatchCenterHeader(),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Upcoming',
                label: Text('Upcoming'),
                icon: Icon(Icons.calendar_month),
              ),
              ButtonSegment(
                value: 'Recent',
                label: Text('Recent'),
                icon: Icon(Icons.history),
              ),
              ButtonSegment(
                value: 'All',
                label: Text('All'),
                icon: Icon(Icons.list),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) {
              setState(() => _filter = value.first);
            },
          ),
        ),
        const SizedBox(height: 14),
        for (final fixture in _visibleFixtures) ...[
          FixtureCard(fixture: fixture),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        const FormGuideCard(),
      ],
    );
  }
}

class MatchCenterHeader extends StatelessWidget {
  const MatchCenterHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      color: AppColors.dark,
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.scoreboard, color: AppColors.blue),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Center',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fixtures, venues, results, and form guide.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FixtureCard extends StatelessWidget {
  const FixtureCard({super.key, required this.fixture});

  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final bool isResult = fixture.status == 'Result';

    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                text: fixture.competition,
                color: fixture.competition == 'Cup'
                    ? Colors.orange
                    : AppColors.blue,
              ),
              const Spacer(),
              StatusPill(
                text: isResult ? fixture.result : fixture.status,
                color: isResult ? AppColors.green : AppColors.dark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  fixture.homeTeam,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.page,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  fixture.awayTeam,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              InfoBadge(icon: Icons.calendar_today, text: fixture.date),
              InfoBadge(icon: Icons.schedule, text: fixture.time),
              InfoBadge(icon: Icons.location_on, text: fixture.venue),
            ],
          ),
        ],
      ),
    );
  }
}

class FormGuideCard extends StatelessWidget {
  const FormGuideCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.green),
              SizedBox(width: 8),
              Text(
                'Recent Form',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              FormDot(text: 'W', color: AppColors.green),
              FormDot(text: 'D', color: AppColors.blue),
              FormDot(text: 'W', color: AppColors.green),
              FormDot(text: 'W', color: AppColors.green),
              FormDot(text: 'L', color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'SHUVAM FC has won 3 of the last 5 matches.',
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class TeamPage extends StatefulWidget {
  const TeamPage({super.key, required this.app});

  final AppController app;

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  String _positionFilter = 'All';
  int _selectedFormationIndex = 0;
  final Set<int> _favoriteNumbers = {10};

  List<Player> get _visiblePlayers {
    if (_positionFilter == 'All') {
      return widget.app.players;
    }

    return widget.app.players
        .where((player) => player.position == _positionFilter)
        .toList();
  }

  void _toggleFavorite(int number) {
    setState(() {
      if (_favoriteNumbers.contains(number)) {
        _favoriteNumbers.remove(number);
      } else {
        _favoriteNumbers.add(number);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formations = widget.app.formations.isEmpty
        ? AppController._fallbackFormations
        : widget.app.formations;
    final int safeFormationIndex = _selectedFormationIndex
        .clamp(0, formations.length - 1)
        .toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FormationBoard(formation: formations[safeFormationIndex]),
        const SizedBox(height: 16),
        FormationSelector(
          formations: formations,
          selectedIndex: safeFormationIndex,
          onSelected: (index) {
            setState(() => _selectedFormationIndex = index);
          },
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'All', label: Text('All')),
              ButtonSegment(value: 'Goalkeeper', label: Text('GK')),
              ButtonSegment(value: 'Defender', label: Text('DEF')),
              ButtonSegment(value: 'Midfielder', label: Text('MID')),
              ButtonSegment(value: 'Forward', label: Text('FWD')),
            ],
            selected: {_positionFilter},
            onSelectionChanged: (value) {
              setState(() => _positionFilter = value.first);
            },
          ),
        ),
        const SizedBox(height: 14),
        for (final player in _visiblePlayers) ...[
          PlayerCard(
            player: player,
            isFavorite: _favoriteNumbers.contains(player.number),
            onFavoriteTap: () => _toggleFavorite(player.number),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class FormationBoard extends StatelessWidget {
  const FormationBoard({super.key, required this.formation});

  final FormationLayout formation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.green,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Preferred XI - ${formation.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  formation.style,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int index = 0; index < formation.lines.length; index++) ...[
            PitchLine(players: formation.lines[index]),
            if (index != formation.lines.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class FormationSelector extends StatelessWidget {
  const FormationSelector({
    super.key,
    required this.formations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<FormationLayout> formations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree, color: AppColors.blue),
              SizedBox(width: 8),
              Text(
                'Formation Layout',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int index = 0; index < formations.length; index++) ...[
                  ChoiceChip(
                    label: Text(formations[index].name),
                    selected: selectedIndex == index,
                    avatar: selectedIndex == index
                        ? const Icon(Icons.check, size: 16)
                        : const Icon(Icons.grid_view, size: 16),
                    onSelected: (_) => onSelected(index),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formations[selectedIndex].style,
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class PitchLine extends StatelessWidget {
  const PitchLine({super.key, required this.players});

  final List<String> players;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final player in players)
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                player,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  final Player player;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  Color get _positionColor {
    switch (player.position) {
      case 'Goalkeeper':
        return Colors.orange.shade700;
      case 'Defender':
        return AppColors.blue;
      case 'Midfielder':
        return AppColors.green;
      default:
        return AppColors.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _positionColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '#${player.number}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(text: player.position, color: _positionColor),
                    StatusPill(
                      text: '${player.age} yrs',
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onFavoriteTap,
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber.shade700 : AppColors.muted,
            ),
            tooltip: 'Favorite player',
          ),
        ],
      ),
    );
  }
}

class NewsPage extends StatelessWidget {
  const NewsPage({super.key, required this.app});

  final AppController app;

  void _openNews(BuildContext context, ClubNews item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.sky,
                child: Icon(item.icon, color: AppColors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              StatusPill(text: item.category, color: AppColors.green),
              const SizedBox(height: 16),
              Text(
                item.message,
                style: const TextStyle(fontSize: 16, color: AppColors.ink),
              ),
              const SizedBox(height: 10),
              Text(
                item.detail,
                style: const TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.done),
                  label: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const NewsTopStory(),
        const SizedBox(height: 16),
        SectionHeader(
          title: 'Club News',
          actionText: 'Latest',
          onActionTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are viewing the latest club announcements.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        for (final item in app.news) ...[
          NewsCard(item: item, onTap: () => _openNews(context, item)),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class NewsTopStory extends StatelessWidget {
  const NewsTopStory({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Row(
        children: [
          Icon(Icons.newspaper, color: Colors.white, size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inside SHUVAM FC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Tap any story for a quick announcement sheet.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.item, required this.onTap});

  final ClubNews item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.sky,
              child: Icon(item.icon, color: AppColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StatusPill(text: item.category, color: AppColors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.app});

  final AppController app;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String _section = 'Players';

  Future<void> _runAdminAction(Future<void> Function() action) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin change saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.app.isAdmin) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClubCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock, color: AppColors.blue, size: 42),
                const SizedBox(height: 14),
                const Text(
                  'Owner Admin Panel',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Login from the Profile tab using shuvamgtm11@gmail.com to edit club data.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: widget.app.loadAll,
                  icon: const Icon(Icons.sync),
                  label: const Text('Check backend'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClubCard(
          color: AppColors.dark,
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, color: AppColors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Control Room',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.app.userEmail,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.app.loadAll,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh data',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Players',
                label: Text('Players'),
                icon: Icon(Icons.groups),
              ),
              ButtonSegment(
                value: 'Matches',
                label: Text('Matches'),
                icon: Icon(Icons.sports_soccer),
              ),
              ButtonSegment(
                value: 'News',
                label: Text('News'),
                icon: Icon(Icons.campaign),
              ),
              ButtonSegment(
                value: 'Updates',
                label: Text('Updates'),
                icon: Icon(Icons.info),
              ),
              ButtonSegment(
                value: 'Formations',
                label: Text('Formations'),
                icon: Icon(Icons.account_tree),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (value) =>
                setState(() => _section = value.first),
          ),
        ),
        const SizedBox(height: 14),
        if (_section == 'Players') _playersAdmin(),
        if (_section == 'Matches') _matchesAdmin(),
        if (_section == 'News') _newsAdmin(),
        if (_section == 'Updates') _updatesAdmin(),
        if (_section == 'Formations') _formationsAdmin(),
      ],
    );
  }

  Widget _playersAdmin() {
    return AdminSection(
      title: 'Players',
      onAdd: () => _openPlayerEditor(),
      children: [
        for (final player in widget.app.players)
          AdminItemCard(
            title: '#${player.number} ${player.name}',
            subtitle: '${player.position} - ${player.age} yrs',
            onEdit: () => _openPlayerEditor(player),
            onDelete: () =>
                _runAdminAction(() => widget.app.deletePlayer(player)),
          ),
      ],
    );
  }

  Widget _matchesAdmin() {
    return AdminSection(
      title: 'Matches',
      onAdd: () => _openFixtureEditor(),
      children: [
        for (final fixture in widget.app.fixtures)
          AdminItemCard(
            title: '${fixture.homeTeam} vs ${fixture.awayTeam}',
            subtitle: '${fixture.date} - ${fixture.status} ${fixture.result}',
            onEdit: () => _openFixtureEditor(fixture),
            onDelete: () =>
                _runAdminAction(() => widget.app.deleteFixture(fixture)),
          ),
      ],
    );
  }

  Widget _newsAdmin() {
    return AdminSection(
      title: 'News',
      onAdd: () => _openNewsEditor(),
      children: [
        for (final item in widget.app.news)
          AdminItemCard(
            title: item.title,
            subtitle: '${item.category} - ${item.message}',
            onEdit: () => _openNewsEditor(item),
            onDelete: () => _runAdminAction(() => widget.app.deleteNews(item)),
          ),
      ],
    );
  }

  Widget _updatesAdmin() {
    return AdminSection(
      title: 'Club Updates',
      onAdd: () => _openUpdateEditor(),
      children: [
        for (final item in widget.app.updates)
          AdminItemCard(
            title: item.title,
            subtitle: item.message,
            onEdit: () => _openUpdateEditor(item),
            onDelete: () =>
                _runAdminAction(() => widget.app.deleteUpdate(item)),
          ),
      ],
    );
  }

  Widget _formationsAdmin() {
    return AdminSection(
      title: 'Formations',
      onAdd: () => _openFormationEditor(),
      children: [
        for (final item in widget.app.formations)
          AdminItemCard(
            title: item.name,
            subtitle: '${item.style} - ${formationLinesToText(item.lines)}',
            onEdit: () => _openFormationEditor(item),
            onDelete: () =>
                _runAdminAction(() => widget.app.deleteFormation(item)),
          ),
      ],
    );
  }

  Future<void> _openPlayerEditor([Player? player]) async {
    final number = TextEditingController(text: player?.number.toString() ?? '');
    final name = TextEditingController(text: player?.name ?? '');
    final position = TextEditingController(text: player?.position ?? '');
    final age = TextEditingController(text: player?.age.toString() ?? '');

    final saved = await showDialog<Player>(
      context: context,
      builder: (context) => AdminFormDialog(
        title: player == null ? 'Add Player' : 'Edit Player',
        children: [
          AdminTextField(
            controller: number,
            label: 'Jersey number',
            keyboardType: TextInputType.number,
          ),
          AdminTextField(controller: name, label: 'Name'),
          AdminTextField(controller: position, label: 'Position'),
          AdminTextField(
            controller: age,
            label: 'Age',
            keyboardType: TextInputType.number,
          ),
        ],
        onSave: () => Player(
          id: player?.id ?? '',
          number: int.tryParse(number.text) ?? 0,
          name: name.text.trim(),
          position: position.text.trim(),
          age: int.tryParse(age.text) ?? 0,
        ),
      ),
    );

    if (saved != null) {
      await _runAdminAction(() => widget.app.savePlayer(saved));
    }
  }

  Future<void> _openFixtureEditor([Fixture? fixture]) async {
    final homeTeam = TextEditingController(text: fixture?.homeTeam ?? '');
    final awayTeam = TextEditingController(text: fixture?.awayTeam ?? '');
    final date = TextEditingController(text: fixture?.date ?? '');
    final time = TextEditingController(text: fixture?.time ?? '');
    final venue = TextEditingController(text: fixture?.venue ?? '');
    final status = TextEditingController(text: fixture?.status ?? 'Upcoming');
    final competition = TextEditingController(
      text: fixture?.competition ?? 'League',
    );
    final result = TextEditingController(text: fixture?.result ?? '');

    final saved = await showDialog<Fixture>(
      context: context,
      builder: (context) => AdminFormDialog(
        title: fixture == null ? 'Add Match' : 'Edit Match',
        children: [
          AdminTextField(controller: homeTeam, label: 'Home team'),
          AdminTextField(controller: awayTeam, label: 'Away team'),
          AdminTextField(controller: date, label: 'Date'),
          AdminTextField(controller: time, label: 'Time'),
          AdminTextField(controller: venue, label: 'Venue'),
          AdminTextField(controller: status, label: 'Status'),
          AdminTextField(controller: competition, label: 'Competition'),
          AdminTextField(controller: result, label: 'Result'),
        ],
        onSave: () => Fixture(
          id: fixture?.id ?? '',
          homeTeam: homeTeam.text.trim(),
          awayTeam: awayTeam.text.trim(),
          date: date.text.trim(),
          time: time.text.trim(),
          venue: venue.text.trim(),
          status: status.text.trim(),
          competition: competition.text.trim(),
          result: result.text.trim(),
        ),
      ),
    );

    if (saved != null) {
      await _runAdminAction(() => widget.app.saveFixture(saved));
    }
  }

  Future<void> _openNewsEditor([ClubNews? item]) async {
    final title = TextEditingController(text: item?.title ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final message = TextEditingController(text: item?.message ?? '');
    final detail = TextEditingController(text: item?.detail ?? '');

    final saved = await showDialog<ClubNews>(
      context: context,
      builder: (context) => AdminFormDialog(
        title: item == null ? 'Add News' : 'Edit News',
        children: [
          AdminTextField(controller: title, label: 'Title'),
          AdminTextField(controller: category, label: 'Category'),
          AdminTextField(
            controller: message,
            label: 'Short message',
            maxLines: 2,
          ),
          AdminTextField(controller: detail, label: 'Detail', maxLines: 3),
        ],
        onSave: () {
          final categoryText = category.text.trim();
          return ClubNews(
            id: item?.id ?? '',
            icon: iconForNewsCategory(categoryText),
            title: title.text.trim(),
            category: categoryText,
            message: message.text.trim(),
            detail: detail.text.trim(),
          );
        },
      ),
    );

    if (saved != null) {
      await _runAdminAction(() => widget.app.saveNews(saved));
    }
  }

  Future<void> _openUpdateEditor([ClubUpdate? item]) async {
    final title = TextEditingController(text: item?.title ?? '');
    final message = TextEditingController(text: item?.message ?? '');

    final saved = await showDialog<ClubUpdate>(
      context: context,
      builder: (context) => AdminFormDialog(
        title: item == null ? 'Add Update' : 'Edit Update',
        children: [
          AdminTextField(controller: title, label: 'Title'),
          AdminTextField(controller: message, label: 'Message', maxLines: 3),
        ],
        onSave: () => ClubUpdate(
          id: item?.id ?? '',
          title: title.text.trim(),
          message: message.text.trim(),
        ),
      ),
    );

    if (saved != null) {
      await _runAdminAction(() => widget.app.saveUpdate(saved));
    }
  }

  Future<void> _openFormationEditor([FormationLayout? item]) async {
    final name = TextEditingController(text: item?.name ?? '');
    final style = TextEditingController(text: item?.style ?? '');
    final lines = TextEditingController(
      text: item == null ? '' : formationLinesToText(item.lines),
    );

    final saved = await showDialog<FormationLayout>(
      context: context,
      builder: (context) => AdminFormDialog(
        title: item == null ? 'Add Formation' : 'Edit Formation',
        children: [
          AdminTextField(controller: name, label: 'Formation name'),
          AdminTextField(controller: style, label: 'Style'),
          AdminTextField(
            controller: lines,
            label: 'Lines',
            maxLines: 5,
            helperText:
                'Use commas for players and / for lines. Example: 11 Roshan, 9 Shri / 10 Shuvam / 1 Ayush',
          ),
        ],
        onSave: () => FormationLayout(
          id: item?.id ?? '',
          name: name.text.trim(),
          style: style.text.trim(),
          lines: parseFormationLines(lines.text),
        ),
      ),
    );

    if (saved != null) {
      await _runAdminAction(() => widget.app.saveFormation(saved));
    }
  }
}

class AdminSection extends StatelessWidget {
  const AdminSection({
    super.key,
    required this.title,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(title: title, actionText: 'Add', onActionTap: onAdd),
        const SizedBox(height: 8),
        if (children.isEmpty)
          const ClubCard(
            child: Text(
              'No items yet. Add the first one from here.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final child in children) ...[child, const SizedBox(height: 10)],
      ],
    );
  }
}

class AdminItemCard extends StatelessWidget {
  const AdminItemCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: AppColors.blue),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class AdminFormDialog<T> extends StatelessWidget {
  const AdminFormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final T Function() onSave;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, onSave()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AdminTextField extends StatelessWidget {
  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, helperText: helperText),
      ),
    );
  }
}

List<List<String>> parseFormationLines(String value) {
  return value
      .split('/')
      .map(
        (line) => line
            .split(',')
            .map((player) => player.trim())
            .where((player) => player.isNotEmpty)
            .toList(),
      )
      .where((line) => line.isNotEmpty)
      .toList();
}

String formationLinesToText(List<List<String>> lines) {
  return lines.map((line) => line.join(', ')).join(' / ');
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.app});

  final AppController app;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _memberIdController = TextEditingController();
  bool _wantsUpdates = true;
  bool _isJoining = false;

  @override
  void dispose() {
    _emailController.dispose();
    _memberIdController.dispose();
    super.dispose();
  }

  Future<void> _continueProfile() async {
    setState(() => _isJoining = true);

    try {
      await widget.app.login(
        _emailController.text.trim(),
        _memberIdController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.app.isAdmin
                ? 'Owner admin login successful.'
                : 'Member login successful.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Start backend first: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        MemberPassCard(
          isJoined: widget.app.userEmail.isNotEmpty,
          isAdmin: widget.app.isAdmin,
          email: widget.app.userEmail,
          memberId: widget.app.memberId,
        ),
        const SizedBox(height: 16),
        ClubCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Login / Join Club',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Create a simple member profile mockup.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _memberIdController,
                decoration: const InputDecoration(
                  labelText: 'Member ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _wantsUpdates,
                onChanged: (value) => setState(() => _wantsUpdates = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Receive club updates'),
                subtitle: const Text('Training, match, and team news'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isJoining ? null : _continueProfile,
                  icon: Icon(
                    _isJoining ? Icons.hourglass_top : Icons.arrow_forward,
                  ),
                  label: Text(_isJoining ? 'Connecting...' : 'Continue'),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                widget.app.isBackendOnline
                    ? 'Backend login is connected locally.'
                    : 'Start the local backend to login and unlock admin.',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MemberPassCard extends StatelessWidget {
  const MemberPassCard({
    super.key,
    required this.isJoined,
    required this.isAdmin,
    required this.email,
    required this.memberId,
  });

  final bool isJoined;
  final bool isAdmin;
  final String email;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.dark, AppColors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ClubBadge(size: 56),
              const Spacer(),
              StatusPill(
                text: isAdmin ? 'Owner Admin' : (isJoined ? 'Active' : 'Guest'),
                color: isAdmin
                    ? AppColors.blue
                    : (isJoined ? AppColors.green : Colors.orange),
                light: true,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'SHUVAM FC Member Pass',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isJoined ? email : 'Blue Green Army',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              HeroChip(
                icon: Icons.confirmation_number,
                text: isJoined ? memberId : 'SFC-2026',
              ),
              const HeroChip(icon: Icons.stadium, text: 'Home Stand'),
              const HeroChip(icon: Icons.favorite, text: 'Supporter'),
            ],
          ),
        ],
      ),
    );
  }
}

class StadiumBackdrop extends StatelessWidget {
  const StadiumBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: StadiumBackdropPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class StadiumBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect fullArea = Offset.zero & size;

    final Paint skyPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF06192F), Color(0xFF0B5ED7), Color(0xFF0F7E4D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(fullArea);

    canvas.drawRect(fullArea, skyPaint);

    _drawLightBeam(
      canvas,
      size,
      const Offset(0.10, 0.05),
      const Offset(0.38, 0.60),
    );
    _drawLightBeam(
      canvas,
      size,
      const Offset(0.90, 0.05),
      const Offset(0.62, 0.60),
    );

    final Paint standPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10);
    final Path stands = Path()
      ..moveTo(0, size.height * 0.19)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.08,
        size.width,
        size.height * 0.19,
      )
      ..lineTo(size.width, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.30,
        0,
        size.height * 0.42,
      )
      ..close();
    canvas.drawPath(stands, standPaint);

    for (int row = 0; row < 5; row++) {
      final double y = size.height * (0.22 + row * 0.035);
      final Paint rowPaint = Paint()
        ..color = row.isEven
            ? Colors.white.withValues(alpha: 0.13)
            : AppColors.dark.withValues(alpha: 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.05, y, size.width * 0.90, 5),
          const Radius.circular(4),
        ),
        rowPaint,
      );
    }

    _drawFloodlight(
      canvas,
      size,
      Offset(size.width * 0.10, size.height * 0.08),
    );
    _drawFloodlight(
      canvas,
      size,
      Offset(size.width * 0.90, size.height * 0.08),
    );

    final Rect pitch = Rect.fromLTWH(
      -size.width * 0.10,
      size.height * 0.48,
      size.width * 1.20,
      size.height * 0.60,
    );
    final Paint pitchPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF1BA85A), Color(0xFF0D743D)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(pitch);
    canvas.drawRect(pitch, pitchPaint);

    for (int stripe = 0; stripe < 8; stripe++) {
      final Paint stripePaint = Paint()
        ..color = stripe.isEven
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.black.withValues(alpha: 0.035);
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          size.height * 0.48 + stripe * size.height * 0.075,
          size.width,
          size.height * 0.075,
        ),
        stripePaint,
      );
    }

    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final Rect fieldLine = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.58,
      size.width * 0.84,
      size.height * 0.34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldLine, const Radius.circular(16)),
      linePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.75),
      Offset(size.width * 0.92, size.height * 0.75),
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.75),
      size.width * 0.12,
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.75),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  void _drawLightBeam(
    Canvas canvas,
    Size size,
    Offset startPercent,
    Offset endPercent,
  ) {
    final Offset start = Offset(
      size.width * startPercent.dx,
      size.height * startPercent.dy,
    );
    final Offset end = Offset(
      size.width * endPercent.dx,
      size.height * endPercent.dy,
    );

    final Paint beamPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.02),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: end, radius: size.width * 0.55));

    final Path beam = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx - size.width * 0.32, end.dy)
      ..lineTo(end.dx + size.width * 0.32, end.dy)
      ..close();

    canvas.drawPath(beam, beamPaint);
  }

  void _drawFloodlight(Canvas canvas, Size size, Offset center) {
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.38),
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 52));

    canvas.drawCircle(center, 52, glowPaint);

    final Paint polePaint = Paint()
      ..color = AppColors.dark.withValues(alpha: 0.35)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(center.dx, size.height * 0.25), polePaint);

    for (int index = 0; index < 3; index++) {
      canvas.drawCircle(
        Offset(center.dx + (index - 1) * 12, center.dy),
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class ClubCard extends StatelessWidget {
  const ClubCard({super.key, required this.child, this.color = Colors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: color == Colors.white ? AppColors.line : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      elevation: color == Colors.white ? 2 : 0,
      shadowColor: AppColors.dark.withValues(alpha: 0.10),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class ClubBadge extends StatelessWidget {
  const ClubBadge({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.green, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.terrain, color: AppColors.blue, size: size * 0.55),
          Positioned(
            bottom: size * 0.14,
            child: Icon(
              Icons.sports_soccer,
              color: AppColors.green,
              size: size * 0.26,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.actionText,
    required this.onActionTap,
  });

  final String title;
  final String actionText;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        TextButton(onPressed: onActionTap, child: Text(actionText)),
      ],
    );
  }
}

class HeroChip extends StatelessWidget {
  const HeroChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    this.light = false,
  });

  final String text;
  final Color color;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.18)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: light ? Colors.white : color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class InfoBadge extends StatelessWidget {
  const InfoBadge({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class TeamMiniBadge extends StatelessWidget {
  const TeamMiniBadge({super.key, required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClubCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.blue),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FormDot extends StatelessWidget {
  const FormDot({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(right: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class Fixture {
  const Fixture({
    this.id = '',
    required this.homeTeam,
    required this.awayTeam,
    required this.date,
    required this.time,
    required this.venue,
    required this.status,
    required this.competition,
    required this.result,
  });

  final String id;
  final String homeTeam;
  final String awayTeam;
  final String date;
  final String time;
  final String venue;
  final String status;
  final String competition;
  final String result;

  factory Fixture.fromJson(Map<String, dynamic> json) {
    return Fixture(
      id: json['id']?.toString() ?? '',
      homeTeam: json['homeTeam']?.toString() ?? '',
      awayTeam: json['awayTeam']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      venue: json['venue']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      competition: json['competition']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'date': date,
      'time': time,
      'venue': venue,
      'status': status,
      'competition': competition,
      'result': result,
    };
  }
}

class Player {
  const Player({
    this.id = '',
    required this.number,
    required this.name,
    required this.position,
    required this.age,
  });

  final String id;
  final int number;
  final String name;
  final String position;
  final int age;

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id']?.toString() ?? '',
      number: int.tryParse(json['number']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      age: int.tryParse(json['age']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'position': position,
      'age': age,
    };
  }
}

class FormationLayout {
  const FormationLayout({
    this.id = '',
    required this.name,
    required this.style,
    required this.lines,
  });

  final String id;
  final String name;
  final String style;
  final List<List<String>> lines;

  factory FormationLayout.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final List<List<String>> parsedLines = [];

    if (rawLines is List) {
      for (final line in rawLines) {
        if (line is List) {
          parsedLines.add(line.map((item) => item.toString()).toList());
        }
      }
    }

    return FormationLayout(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      style: json['style']?.toString() ?? '',
      lines: parsedLines,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'style': style, 'lines': lines};
  }
}

class ClubNews {
  const ClubNews({
    this.id = '',
    required this.icon,
    required this.title,
    required this.category,
    required this.message,
    required this.detail,
  });

  final String id;
  final IconData icon;
  final String title;
  final String category;
  final String message;
  final String detail;

  factory ClubNews.fromJson(Map<String, dynamic> json) {
    final category = json['category']?.toString() ?? 'Club';

    return ClubNews(
      id: json['id']?.toString() ?? '',
      icon: iconForNewsCategory(category),
      title: json['title']?.toString() ?? '',
      category: category,
      message: json['message']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'message': message,
      'detail': detail,
    };
  }
}

class ClubUpdate {
  const ClubUpdate({this.id = '', required this.title, required this.message});

  final String id;
  final String title;
  final String message;

  factory ClubUpdate.fromJson(Map<String, dynamic> json) {
    return ClubUpdate(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'message': message};
  }
}

IconData iconForNewsCategory(String category) {
  switch (category.toLowerCase()) {
    case 'training':
      return Icons.fitness_center;
    case 'match':
      return Icons.sports_score;
    case 'squad':
      return Icons.person_add_alt_1;
    case 'community':
      return Icons.volunteer_activism;
    default:
      return Icons.campaign;
  }
}
