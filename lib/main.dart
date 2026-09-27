import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

import 'plantnet_api.dart';
import 'tree_facts_api.dart';

void main() {
  runApp(const TreeApp());
}

// ============================================================
// APP
// ============================================================

class TreeApp extends StatelessWidget {
  const TreeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Derevarium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================
// TREE MODEL
// ============================================================

class Tree {
  String type;
  String location;
  String locationType;
  String facts;
  String notes;
  String? imageBase64;
  DateTime dateFound;
  bool foundTogether;
  bool isRare;

  Tree({
    required this.type,
    required this.location,
    required this.locationType,
    required this.facts,
    this.notes = '',
    required this.dateFound,
    this.imageBase64,
    this.foundTogether = false,
    this.isRare = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'location': location,
      'locationType': locationType,
      'facts': facts,
      'notes': notes,
      'imageBase64': imageBase64,
      'dateFound': dateFound.toIso8601String(),
      'foundTogether': foundTogether,
      'isRare': isRare,
    };
  }

  factory Tree.fromJson(Map<String, dynamic> json) {
    return Tree(
      type: json['type'] ?? json['name'] ?? '',
      location: json['location'] ?? '',
      locationType: json['locationType'] ?? 'Місто',
      facts: json['facts'] ?? '',
      notes: json['notes'] ?? '',
      imageBase64: json['imageBase64'],
      dateFound:
          DateTime.tryParse(
            json['dateFound'] ?? '',
          ) ??
          DateTime.now(),
      foundTogether: json['foundTogether'] ?? false,
      isRare: json['isRare'] ?? false,
    );
  }
}

// ============================================================
// TREE ACTION
// ============================================================

class TreeAction {
  final Tree? tree;
  final bool deleted;

  TreeAction({
    this.tree,
    this.deleted = false,
  });
}

// ============================================================
// FILTER
// ============================================================

const String allFilter = '__ALL__';

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Tree> trees = [];

  String searchQuery = '';
  String selectedLocationFilter = allFilter;
  String selectedTypeFilter = allFilter;

  // 0 - Головна
  // 1 - Бестіарій
  // 2 - Карта
  // 3 - Досягнення
  int selectedTab = 0;

  @override
  void initState() {
    super.initState();
    loadTrees();
  }

  // ============================================================
  // LOAD / SAVE
  // ============================================================

  Future<void> loadTrees() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTrees = prefs.getStringList('trees') ?? [];

    final loadedTrees = savedTrees.map((item) {
      return Tree.fromJson(jsonDecode(item));
    }).toList();

    if (!mounted) return;

    setState(() {
      trees = loadedTrees;
    });
  }

  Future<void> saveTrees() async {
    final prefs = await SharedPreferences.getInstance();

    final data = trees.map((tree) {
      return jsonEncode(tree.toJson());
    }).toList();

    await prefs.setStringList('trees', data);
  }

  // ============================================================
  // ADD TREE
  // ============================================================

  Future<void> addTree() async {
    final result = await Navigator.push<TreeAction>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddTreePage(),
      ),
    );

    if (result != null && result.tree != null) {
      setState(() {
        trees.add(result.tree!);
      });

      await saveTrees();
    }
  }

  // ============================================================
  // OPEN TREE
  // ============================================================

  Future<void> openTree(int index) async {
    final result = await Navigator.push<TreeAction>(
      context,
      MaterialPageRoute(
        builder: (_) => TreeDetailsPage(
          tree: trees[index],
        ),
      ),
    );

    if (result == null) return;

    if (result.deleted) {
      setState(() {
        trees.removeAt(index);
      });

      await saveTrees();
      return;
    }

    if (result.tree != null) {
      setState(() {
        trees[index] = result.tree!;
      });

      await saveTrees();
    }
  }

  // ============================================================
  // DATA
  // ============================================================

  List<String> get locations {
    final list = trees
        .map((tree) => tree.location.trim())
        .where((location) => location.isNotEmpty)
        .toSet()
        .toList();

    list.sort();
    return list;
  }

  List<String> get treeTypes {
    final list = trees
        .map((tree) => tree.type.trim())
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    list.sort();
    return list;
  }

  int get uniqueTypesCount {
    return trees
        .map((tree) => tree.type.trim().toLowerCase())
        .where((type) => type.isNotEmpty)
        .toSet()
        .length;
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Tree> get filteredTrees {
    return trees.where((tree) {
      final query = searchQuery.toLowerCase().trim();

      final matchesSearch =
          query.isEmpty ||
          tree.type.toLowerCase().contains(query) ||
          tree.location.toLowerCase().contains(query) ||
          tree.facts.toLowerCase().contains(query) ||
          tree.notes.toLowerCase().contains(query);

      final matchesLocation =
          selectedLocationFilter == allFilter ||
          tree.location == selectedLocationFilter;

      final matchesType =
          selectedTypeFilter == allFilter ||
          tree.type == selectedTypeFilter;

      return matchesSearch &&
          matchesLocation &&
          matchesType;
    }).toList();
  }

  void resetFilters() {
    setState(() {
      searchQuery = '';
      selectedLocationFilter = allFilter;
      selectedTypeFilter = allFilter;
    });
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void openMap() {
    setState(() {
      selectedTab = 2;
    });
  }

  void openAchievements() {
    setState(() {
      selectedTab = 3;
    });
  }

  void openBestiary() {
    setState(() {
      selectedTab = 1;
    });
  }

  void openStats() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatsPage(
          trees: trees,
        ),
      ),
    );
  }

  // ============================================================
  // HOME CONTENT
  // ============================================================

Widget buildHomeContent() {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF3E8055),
          Color(0xFF17452F),
        ],
      ),
    ),
    child: Stack(
      children: [
        // ======================================================
        // DECORATIVE LEAVES
        // ======================================================

        const Positioned(
          top: 105,
          left: -18,
          child: Text(
            '🍃',
            style: TextStyle(fontSize: 78),
          ),
        ),

        const Positioned(
          top: 220,
          right: -28,
          child: Text(
            '🌿',
            style: TextStyle(fontSize: 88),
          ),
        ),

        const Positioned(
          bottom: 205,
          left: -25,
          child: Text(
            '🌿',
            style: TextStyle(fontSize: 82),
          ),
        ),

        const Positioned(
          bottom: 135,
          right: -18,
          child: Text(
            '🍃',
            style: TextStyle(fontSize: 72),
          ),
        ),

        // ======================================================
        // TITLE
        // ======================================================

        Positioned(
          top: 24,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: const Center(
              child: Text(
                '🌿 Derevarium',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),

        // ======================================================
        // MAIN BUTTON
        // ======================================================

        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: addTree,
                child: Container(
                  width: 165,
                  height: 165,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF78A878),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.photo_camera_rounded,
                        size: 62,
                        color: Colors.white,
                      ),

                      Positioned(
                        right: 38,
                        bottom: 38,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 25,
                            color: Color(0xFF2F6B45),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Знайти дерево',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'Сфотографуйте новий вид',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.72),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // COLLECTION COUNTER
        // ======================================================

        Positioned(
          left: 0,
          right: 0,
          bottom: 92,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
              child: Text(
                trees.isEmpty
                    ? '🌱 Почніть свою колекцію'
                    : '🌳 Відкрито видів: $uniqueTypesCount',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedTab,
        children: [
          buildHomeContent(),
          BestiaryPage(trees: trees),
          MapPage(trees: trees),
          AchievementsPage(trees: trees),
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,

        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Головна',
          ),

          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Бестіарій',
          ),

          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Карта',
          ),

          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Досягнення',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HOME STAT CARD
// ============================================================

class _HomeStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HomeStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.green,
            size: 25,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TREE CARD
// ============================================================

class TreeCard extends StatelessWidget {
  final Tree tree;
  final VoidCallback onTap;

  const TreeCard({
    super.key,
    required this.tree,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(12),
                child: tree.imageBase64 != null
                    ? Image.memory(
                        base64Decode(
                          tree.imageBase64!,
                        ),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 90,
                        height: 90,
                        color:
                            Colors.green.shade100,
                        child: const Icon(
                          Icons.park,
                          size: 45,
                          color: Colors.green,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tree.type,
                            style:
                                const TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ),
                        if (tree.isRare)
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 20,
                          ),
                        if (tree.foundTogether)
                          const Padding(
                            padding:
                                EdgeInsets.only(
                              left: 5,
                            ),
                            child: Icon(
                              Icons.favorite,
                              color: Colors.pink,
                              size: 19,
                            ),
                          ),
                        if (tree.notes
                            .trim()
                            .isNotEmpty)
                          const Padding(
                            padding:
                                EdgeInsets.only(
                              left: 5,
                            ),
                            child: Icon(
                              Icons
                                  .sticky_note_2_outlined,
                              color:
                                  Colors.orange,
                              size: 19,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tree.location,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons
                              .calendar_month_outlined,
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tree.dateFound.day.toString().padLeft(2, '0')}.'
                          '${tree.dateFound.month.toString().padLeft(2, '0')}.'
                          '${tree.dateFound.year}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BESTIARY PAGE
// ============================================================

class BestiaryPage extends StatefulWidget {
  final List<Tree> trees;

  const BestiaryPage({
    super.key,
    required this.trees,
  });

  @override
  State<BestiaryPage> createState() =>
      _BestiaryPageState();
}

class _BestiaryPageState
    extends State<BestiaryPage> {
  final TextEditingController searchController =
      TextEditingController();

  String filter = 'Усі';

  final List<String> catalog = [
    'Дуб',
    'Клен',
    'Береза',
    'Сосна',
    'Ялина',
    'Липа',
    'Тополя',
    'Каштан',
    'Бук',
    'Ясен',
    'Акація',
    'Горіх',
    'Вишня',
    'Яблуня',
    'Глід',
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Map<String, List<Tree>> get groupedTrees {
    final groups = <String, List<Tree>>{};

    for (final tree in widget.trees) {
      final type = tree.type.trim();

      if (type.isEmpty) continue;

      groups.putIfAbsent(type, () => []).add(tree);
    }

    return groups;
  }

  List<String> get allSpecies {
    final result = <String>{
      ...catalog,
      ...groupedTrees.keys,
    };

    final query =
        searchController.text.trim().toLowerCase();

    final filtered = result.where((type) {
      final matchesSearch =
          query.isEmpty ||
          type.toLowerCase().contains(query);

      final found =
          groupedTrees.containsKey(type);

      final matchesFilter =
          filter == 'Усі' ||
          (filter == 'Знайдені' && found) ||
          (filter == 'Незнайдені' && !found);

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      final aFound =
          groupedTrees.containsKey(a);
      final bFound =
          groupedTrees.containsKey(b);

      if (aFound != bFound) {
        return aFound ? -1 : 1;
      }

      return a.compareTo(b);
    });

    return filtered;
  }

  void openSpecies(String type) {
    final speciesTrees =
        groupedTrees[type] ?? [];

    if (speciesTrees.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BestiarySpeciesPage(
          type: type,
          trees: speciesTrees,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final species = allSpecies;
    final foundCount = groupedTrees.length;
    final totalCount = species.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📖 Бестіарій',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$foundCount / $totalCount',
                        style:
                            const TextStyle(
                          fontSize: 25,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'видів відкрито',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.auto_stories,
                  size: 38,
                  color: Colors.green,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: TextField(
              controller:
                  searchController,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText:
                    'Пошук виду...',
                prefixIcon:
                    const Icon(Icons.search),
                suffixIcon:
                    searchController
                            .text
                            .isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {});
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          )
                        : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection:
                Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: Row(
              children: [
                _BestiaryFilterChip(
                  label: 'Усі',
                  selected:
                      filter == 'Усі',
                  onTap: () {
                    setState(() {
                      filter = 'Усі';
                    });
                  },
                ),
                _BestiaryFilterChip(
                  label: '🌳 Знайдені',
                  selected:
                      filter == 'Знайдені',
                  onTap: () {
                    setState(() {
                      filter =
                          'Знайдені';
                    });
                  },
                ),
                _BestiaryFilterChip(
                  label: '🔒 Незнайдені',
                  selected:
                      filter == 'Незнайдені',
                  onTap: () {
                    setState(() {
                      filter =
                          'Незнайдені';
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: species.isEmpty
                ? const Center(
                    child: Text(
                      'Нічого не знайдено 🔍',
                      style:
                          TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount:
                        species.length,
                    itemBuilder:
                        (context, index) {
                      final type =
                          species[index];

                      final finds =
                          groupedTrees[type];

                      final isFound =
                          finds != null &&
                              finds.isNotEmpty;

                      return _BestiaryTile(
                        type: type,
                        trees: finds ?? [],
                        isFound:
                            isFound,
                        onTap: isFound
                            ? () =>
                                openSpecies(type)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BESTIARY FILTER CHIP
// ============================================================

class _BestiaryFilterChip
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BestiaryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

// ============================================================
// BESTIARY TILE
// ============================================================

class _BestiaryTile
    extends StatelessWidget {
  final String type;
  final List<Tree> trees;
  final bool isFound;
  final VoidCallback? onTap;

  const _BestiaryTile({
    required this.type,
    required this.trees,
    required this.isFound,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstTree =
        isFound ? trees.first : null;

    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isFound &&
                      firstTree!.imageBase64 !=
                          null
                  ? Image.memory(
                      base64Decode(
                        firstTree
                            .imageBase64!,
                      ),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: isFound
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                      child: Center(
                        child: isFound
                            ? const Icon(
                                Icons.park,
                                size: 65,
                                color:
                                    Colors.green,
                              )
                            : Icon(
                                Icons.lock_outline,
                                size: 52,
                                color: Colors
                                    .grey.shade500,
                              ),
                      ),
                    ),
            ),
            Padding(
              padding:
                  const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    isFound ? type : '???',
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  if (isFound)
                    Row(
                      children: [
                        const Icon(
                          Icons.eco,
                          size: 16,
                          color:
                              Colors.green,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          '${trees.length} ${trees.length == 1 ? 'знахідка' : 'знахідки'}',
                          style:
                              const TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      'Ще не знайдено',
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// BESTIARY SPECIES PAGE
// ============================================================

class BestiarySpeciesPage
    extends StatelessWidget {
  final String type;
  final List<Tree> trees;

  const BestiarySpeciesPage({
    super.key,
    required this.type,
    required this.trees,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          type,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(
                      Icons.eco,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          type,
                          style:
                              const TextStyle(
                            fontSize: 23,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          'У вашій колекції: ${trees.length}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          ...trees.asMap().entries.map(
            (entry) {
              final index =
                  entry.key;
              final tree =
                  entry.value;

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                clipBehavior:
                    Clip.antiAlias,
                child: InkWell(
                  onTap: () async {
                    final result =
                        await Navigator.push<
                            TreeAction>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TreeDetailsPage(
                          tree:
                              tree,
                        ),
                      ),
                    );

                    if (result !=
                        null) {
                      Navigator.pop(
                        context,
                        result,
                      );
                    }
                  },
                  child: Row(
                    children: [
                      if (tree.imageBase64 !=
                          null)
                        Image.memory(
                          base64Decode(
                            tree.imageBase64!,
                          ),
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          width: 110,
                          height: 110,
                          color:
                              Colors.green.shade100,
                          child:
                              const Icon(
                            Icons.park,
                            size: 45,
                            color:
                                Colors.green,
                          ),
                        ),
                      Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            14,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Знахідка №${index + 1}',
                                style:
                                    const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(
                                height: 6,
                              ),
                              Text(
                                '📍 ${tree.location}',
                                maxLines: 2,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                '${tree.dateFound.day.toString().padLeft(2, '0')}.'
                                '${tree.dateFound.month.toString().padLeft(2, '0')}.'
                                '${tree.dateFound.year}',
                              ),
                              if (tree.foundTogether)
                                const Padding(
                                  padding:
                                      EdgeInsets.only(
                                    top: 6,
                                  ),
                                  child:
                                      Text(
                                    '❤️ Знайдено разом',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.pink,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.only(
                          right: 10,
                        ),
                        child:
                            Icon(
                          Icons.chevron_right,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ADD / EDIT TREE PAGE
// ============================================================

class AddTreePage
    extends StatefulWidget {
  final Tree? tree;

  const AddTreePage({
    super.key,
    this.tree,
  });

  @override
  State<AddTreePage> createState() =>
      _AddTreePageState();
}

class _AddTreePageState
    extends State<AddTreePage> {
  final locationController =
      TextEditingController();

  final factsController =
      TextEditingController();

  final notesController =
      TextEditingController();

  final ImagePicker picker =
      ImagePicker();

  String? selectedTreeType;
  String? selectedLocation;
  String selectedLocationType =
      'Місто';

  DateTime selectedDate =
      DateTime.now();

  String? imageBase64;

  bool foundTogether = false;
  bool isRare = false;

  bool identifying = false;
  bool loadingFacts = false;

  bool get isEditing =>
      widget.tree != null;

  final List<String> standardTreeTypes = [
    'Дуб',
    'Клен',
    'Береза',
    'Сосна',
    'Ялина',
    'Липа',
    'Яблуня',
    'Тополя',
  ];

  final List<String> standardLocations = [
    'Чернівці',
    'Львів',
    'Київ',
    'Будапешт',
  ];

  final List<String> locationTypes = [
    'Місто',
    'Парк',
    'Ліс',
    'Село',
    'За містом',
    'Інше',
  ];

  @override
  void initState() {
    super.initState();

    if (widget.tree != null) {
      final tree =
          widget.tree!;

      selectedTreeType =
          tree.type;
      selectedLocation =
          tree.location;
      selectedLocationType =
          tree.locationType;

      locationController.text =
          tree.location;

      factsController.text =
          tree.facts;

      notesController.text =
          tree.notes;

      selectedDate =
          tree.dateFound;

      imageBase64 =
          tree.imageBase64;

      foundTogether =
          tree.foundTogether;

      isRare =
          tree.isRare;
    }
  }

  @override
  void dispose() {
    locationController.dispose();
    factsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  List<String> get typeItems {
    final items = [
      ...standardTreeTypes,
    ];

    if (selectedTreeType != null &&
        selectedTreeType!.isNotEmpty &&
        !items.contains(
          selectedTreeType,
        )) {
      items.add(
        selectedTreeType!,
      );
    }

    items.add(
      'Інше...',
    );

    return items;
  }

  List<String> get locationItems {
    final items = [
      ...standardLocations,
    ];

    if (selectedLocation != null &&
        selectedLocation!.isNotEmpty &&
        !items.contains(
          selectedLocation,
        )) {
      items.add(
        selectedLocation!,
      );
    }

    items.add(
      'Інше...',
    );

    return items;
  }

  Future<void> pickImage() async {
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 75,
    maxWidth: 1000,
  );

  if (image == null) return;

  final bytes = await image.readAsBytes();

  try {
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      setState(() {
        imageBase64 = base64Encode(bytes);
      });
      return;
    }

    // Додатково зменшуємо фото.
    final resizedImage = img.copyResize(
      originalImage,
      width: originalImage.width > 1000
          ? 1000
          : originalImage.width,
    );

    // Зберігаємо як JPEG із якістю 70%.
    final compressedBytes = img.encodeJpg(
      resizedImage,
      quality: 70,
    );

    setState(() {
      imageBase64 = base64Encode(compressedBytes);
    });
  } catch (_) {
    // Якщо стиснення не вдалося —
    // зберігаємо оригінальне фото.
    setState(() {
      imageBase64 = base64Encode(bytes);
    });
  }
}

  Future<void> pickDate() async {
    final date =
        await showDatePicker(
      context:
          context,
      initialDate:
          selectedDate,
      firstDate:
          DateTime(2000),
      lastDate:
          DateTime.now(),
    );

    if (date != null) {
      setState(() {
        selectedDate =
            date;
      });
    }
  }

  // ==========================================================
  // PLANTNET
  // ==========================================================

  Future<void> identifyTree() async {
    try {
      Uint8List bytes;

      if (imageBase64 != null) {
        bytes =
            base64Decode(
          imageBase64!,
        );
      } else {
        final XFile? image =
            await picker.pickImage(
          source:
              ImageSource.gallery,
          imageQuality:
              80,
          maxWidth:
              1200,
        );

        if (image == null) return;

        bytes =
            await image.readAsBytes();

        setState(() {
          imageBase64 =
              base64Encode(bytes);
        });
      }

      setState(() {
        identifying = true;
      });

      final results =
          await PlantNetApi.identify(
        bytes,
      );

      if (!mounted) return;

      setState(() {
        identifying = false;
      });

      if (results.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content:
                Text(
              'Pl@ntNet не зміг визначити дерево 😕',
            ),
          ),
        );
        return;
      }

      showPlantNetResults(results);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        identifying = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            'Помилка визначення:\n$e',
          ),
          duration:
              const Duration(
            seconds: 7,
          ),
        ),
      );
    }
  }

  Future<void> selectPlantNetResult(
    PlantNetResult result,
    BuildContext sheetContext,
  ) async {
    setState(() {
      selectedTreeType =
          result.name;

      loadingFacts = true;

      factsController.text =
          '🔎 Шукаю цікаві факти про ${result.name}...';
    });

    Navigator.pop(sheetContext);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          'Вибрано: ${result.name} 🌳',
        ),
        duration:
            const Duration(
          seconds: 2,
        ),
      ),
    );

    try {
      final factsResult =
          await TreeFactsApi.getFacts(
        commonName:
            result.name,
        scientificName:
            result.scientificName,
      );

      if (!mounted) return;

      setState(() {
        loadingFacts = false;

        if (factsResult != null) {
          factsController.text =
              factsResult.facts;
        } else {
          factsController.text =
              'Не вдалося автоматично знайти факти про цей вид.\n\n'
              'Можеш написати їх вручну.';
        }
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loadingFacts = false;
        factsController.text =
            'Не вдалося автоматично завантажити факти.\n\n'
            'Можеш написати їх вручну.';
      });
    }
  }

  void showPlantNetResults(
    List<PlantNetResult> results,
  ) {
    showModalBottomSheet(
      context:
          context,
      isScrollControlled:
          true,
      builder:
          (sheetContext) {
        return SafeArea(
          child:
              Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child:
                SingleChildScrollView(
              child:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🤖 Результат AI',
                    style:
                        TextStyle(
                      fontSize:
                          24,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  const Text(
                    'Ось найімовірніші варіанти:',
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  ...results.map(
                    (result) {
                      final percent =
                          (result.score * 100)
                              .round();

                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom:
                              10,
                        ),
                        child:
                            ListTile(
                          leading:
                              CircleAvatar(
                            backgroundColor:
                                Colors.green.shade100,
                            child:
                                const Icon(
                              Icons.eco,
                              color:
                                  Colors.green,
                            ),
                          ),
                          title:
                              Text(
                            result.name,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          subtitle:
                              Text(
                            result.scientificName,
                          ),
                          trailing:
                              Text(
                            '$percent%',
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          onTap:
                              () {
                            selectPlantNetResult(
                              result,
                              sheetContext,
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  const Text(
                    '💡 AI може помилятися. Перед збереженням перевір результат.',
                    style:
                        TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // OTHER TREE
  // ==========================================================

  Future<void> selectOtherTree() async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context:
          context,
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Інший вид дерева',
          ),
          content:
              TextField(
            controller:
                controller,
            autofocus:
                true,
            decoration:
                const InputDecoration(
              hintText:
                  'Наприклад: Каштан',
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
              ),
              child:
                  const Text(
                'Скасувати',
              ),
            ),
            FilledButton(
              onPressed:
                  () {
                final text =
                    controller
                        .text
                        .trim();

                if (text.isNotEmpty) {
                  Navigator.pop(
                    context,
                    text,
                  );
                }
              },
              child:
                  const Text(
                'Додати',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null &&
        result.isNotEmpty) {
      setState(() {
        selectedTreeType =
            result;
      });
    }
  }

  // ==========================================================
  // OTHER LOCATION
  // ==========================================================

  Future<void> selectOtherLocation() async {
    final controller =
        TextEditingController(
      text:
          selectedLocation ?? '',
    );

    final result =
        await showDialog<String>(
      context:
          context,
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Інша локація',
          ),
          content:
              TextField(
            controller:
                controller,
            autofocus:
                true,
            decoration:
                const InputDecoration(
              hintText:
                  'Наприклад: Деражня',
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
              ),
              child:
                  const Text(
                'Скасувати',
              ),
            ),
            FilledButton(
              onPressed:
                  () {
                final text =
                    controller
                        .text
                        .trim();

                if (text.isNotEmpty) {
                  Navigator.pop(
                    context,
                    text,
                  );
                }
              },
              child:
                  const Text(
                'Додати',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null &&
        result.isNotEmpty) {
      setState(() {
        selectedLocation =
            result;

        locationController.text =
            result;
      });
    }
  }

  // ==========================================================
  // SAVE
  // ==========================================================

  void saveTree() {
    if (selectedTreeType == null ||
        selectedTreeType!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Вибери або визнач вид дерева 🌳',
          ),
        ),
      );
      return;
    }

    final location =
        locationController.text.trim();

    if (location.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Вкажи локацію 📍',
          ),
        ),
      );
      return;
    }

    final tree = Tree(
      type:
          selectedTreeType!,
      location:
          location,
      locationType:
          selectedLocationType,
      facts:
          factsController.text.trim(),
      notes:
          notesController.text.trim(),
      imageBase64:
          imageBase64,
      dateFound:
          selectedDate,
      foundTogether:
          foundTogether,
      isRare:
          isRare,
    );

    Navigator.pop(
      context,
      TreeAction(
        tree: tree,
      ),
    );
  }

  // ==========================================================
  // DELETE
  // ==========================================================

  Future<void> deleteTree() async {
    final confirmed =
        await showDialog<bool>(
      context:
          context,
      builder:
          (context) {
        return AlertDialog(
          title:
              const Text(
            'Видалити дерево?',
          ),
          content:
              Text(
            'Ти точно хочеш видалити '
            '«${widget.tree?.type}»?',
          ),
          actions: [
            TextButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
                false,
              ),
              child:
                  const Text(
                'Скасувати',
              ),
            ),
            FilledButton(
              onPressed:
                  () =>
                      Navigator.pop(
                context,
                true,
              ),
              child:
                  const Text(
                'Видалити',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      Navigator.pop(
        context,
        TreeAction(
          deleted: true,
        ),
      );
    }
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            Text(
          isEditing
              ? 'Редагувати дерево'
              : 'Нове дерево',
        ),
        actions: [
          if (isEditing)
            IconButton(
              onPressed:
                  deleteTree,
              icon:
                  const Icon(
                Icons.delete_outline,
              ),
            ),
        ],
      ),
      body:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap:
                  pickImage,
              child:
                  ClipRRect(
                borderRadius:
                    BorderRadius.circular(18),
                child:
                    imageBase64 != null
                        ? Image.memory(
                            base64Decode(
                              imageBase64!,
                            ),
                            height:
                                230,
                            fit:
                                BoxFit.cover,
                          )
                        : Container(
                            height:
                                230,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.green.shade50,
                              border:
                                  Border.all(
                                color:
                                    Colors.green.shade200,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                18,
                              ),
                            ),
                            child:
                                const Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons
                                      .add_a_photo_outlined,
                                  size:
                                      55,
                                  color:
                                      Colors.green,
                                ),
                                SizedBox(
                                  height:
                                      10,
                                ),
                                Text(
                                  'Додати фото',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            SizedBox(
              height:
                  52,
              child:
                  OutlinedButton.icon(
                onPressed:
                    identifying ||
                            loadingFacts
                        ? null
                        : identifyTree,
                icon:
                    identifying
                        ? const SizedBox(
                            width:
                                20,
                            height:
                                20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                          ),
                label:
                    Text(
                  identifying
                      ? 'AI визначає дерево...'
                      : '🤖 Визначити дерево по фото',
                ),
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            DropdownButtonFormField<String>(
              initialValue:
                  selectedTreeType,
              decoration:
                  InputDecoration(
                labelText:
                    'Вид дерева',
                prefixIcon:
                    const Icon(
                  Icons.eco,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              items:
                  typeItems.map(
                (type) {
                  return DropdownMenuItem<String>(
                    value:
                        type,
                    child:
                        Text(
                      type,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (value) async {
                if (value ==
                    'Інше...') {
                  await selectOtherTree();
                  return;
                }

                setState(() {
                  selectedTreeType =
                      value;
                });
              },
            ),

            const SizedBox(
              height:
                  16,
            ),

            DropdownButtonFormField<String>(
              initialValue:
                  selectedLocation,
              decoration:
                  InputDecoration(
                labelText:
                    'Локація',
                prefixIcon:
                    const Icon(
                  Icons
                      .location_on_outlined,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              items:
                  locationItems.map(
                (location) {
                  return DropdownMenuItem<String>(
                    value:
                        location,
                    child:
                        Text(
                      location,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (value) async {
                if (value ==
                    'Інше...') {
                  await selectOtherLocation();
                  return;
                }

                setState(() {
                  selectedLocation =
                      value;

                  locationController.text =
                      value ?? '';
                });
              },
            ),

            const SizedBox(
              height:
                  16,
            ),

            DropdownButtonFormField<String>(
              initialValue:
                  selectedLocationType,
              decoration:
                  InputDecoration(
                labelText:
                    'Тип локації',
                prefixIcon:
                    const Icon(
                  Icons.category_outlined,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              items:
                  locationTypes.map(
                (type) {
                  return DropdownMenuItem<String>(
                    value:
                        type,
                    child:
                        Text(
                      type,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (value) {
                if (value == null) return;

                setState(() {
                  selectedLocationType =
                      value;
                });
              },
            ),

            const SizedBox(
              height:
                  10,
            ),

            Card(
              child:
                  SwitchListTile(
                value:
                    foundTogether,
                onChanged:
                    (value) {
                  setState(() {
                    foundTogether =
                        value;
                  });
                },
                title:
                    const Text(
                  '❤️ Знайдено разом',
                ),
                subtitle:
                    const Text(
                  'Ви фотографували дерево разом',
                ),
              ),
            ),

            const SizedBox(
              height:
                  4,
            ),

            Card(
              child:
                  SwitchListTile(
                value:
                    isRare,
                onChanged:
                    (value) {
                  setState(() {
                    isRare =
                        value;
                  });
                },
                title:
                    const Text(
                  '⭐ Рідкісний вид',
                ),
                subtitle:
                    const Text(
                  'Поки що можна позначати вручну',
                ),
              ),
            ),

            const SizedBox(
              height:
                  10,
            ),

            InkWell(
              onTap:
                  pickDate,
              borderRadius:
                  BorderRadius.circular(14),
              child:
                  InputDecorator(
                decoration:
                    InputDecoration(
                  labelText:
                      'Дата знаходження',
                  prefixIcon:
                      const Icon(
                        Icons.calendar_month,
                      ),
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
                child:
                    Text(
                  '${selectedDate.day.toString().padLeft(2, '0')}.'
                  '${selectedDate.month.toString().padLeft(2, '0')}.'
                  '${selectedDate.year}',
                ),
              ),
            ),

            const SizedBox(
              height:
                  16,
            ),

            TextField(
              controller:
                  factsController,
              maxLines:
                  6,
              decoration:
                  InputDecoration(
                labelText:
                    '📚 Цікаві факти',
                hintText:
                    'Після визначення дерева факти з’являться тут автоматично...',
                prefixIcon:
                    const Icon(
                  Icons.menu_book_outlined,
                ),
                suffixIcon:
                    loadingFacts
                        ? const Padding(
                            padding:
                                EdgeInsets.all(
                              14,
                            ),
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : null,
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),

            if (loadingFacts)
              const Padding(
                padding:
                    EdgeInsets.only(
                  top:
                      8,
                ),
                child:
                    Text(
                  '🤖 Шукаємо інформацію про цей вид...',
                  style:
                      TextStyle(
                    color:
                        Colors.green,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

            const SizedBox(
              height:
                  18,
            ),

            TextField(
              controller:
                  notesController,
              maxLines:
                  5,
              decoration:
                  InputDecoration(
                labelText:
                    '❤️ Наша історія',
                hintText:
                    'Наприклад: Знайшли, гуляючи після роботи. Маша першою його помітила 😄',
                prefixIcon:
                    const Icon(
                  Icons.favorite_border,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(
              height:
                  25,
            ),

            SizedBox(
              height:
                  55,
              child:
                  FilledButton.icon(
                onPressed:
                    saveTree,
                icon:
                    const Icon(
                  Icons.save,
                ),
                label:
                    Text(
                  isEditing
                      ? 'Зберегти зміни'
                      : 'Додати дерево',
                  style:
                      const TextStyle(
                    fontSize:
                        17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height:
                  30,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TREE DETAILS
// ============================================================

class TreeDetailsPage
    extends StatelessWidget {
  final Tree tree;

  const TreeDetailsPage({
    super.key,
    required this.tree,
  });

  Future<void> editTree(
    BuildContext context,
  ) async {
    final result =
        await Navigator.push<TreeAction>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddTreePage(
          tree:
              tree,
        ),
      ),
    );

    if (result != null) {
      Navigator.pop(
        context,
        result,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Дерево',
        ),
        actions: [
          IconButton(
            icon:
                const Icon(
              Icons.edit,
            ),
            onPressed:
                () =>
                    editTree(context),
          ),
        ],
      ),
      body:
          SingleChildScrollView(
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (tree.imageBase64 !=
                null)
              Image.memory(
                base64Decode(
                  tree.imageBase64!,
                ),
                width:
                    double.infinity,
                height:
                    300,
                fit:
                    BoxFit.cover,
              )
            else
              Container(
                width:
                    double.infinity,
                height:
                    300,
                color:
                    Colors.green.shade100,
                child:
                    const Icon(
                  Icons.park,
                  size:
                      100,
                  color:
                      Colors.green,
                ),
              ),

            Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            Text(
                          tree.type,
                          style:
                              const TextStyle(
                            fontSize:
                                30,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      if (tree.isRare)
                        const Icon(
                          Icons.star,
                          color:
                              Colors.amber,
                          size:
                              30,
                        ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        15,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color:
                            Colors.green,
                      ),
                      const SizedBox(
                        width:
                            8,
                      ),
                      Expanded(
                        child:
                            Text(
                          tree.location,
                          style:
                              const TextStyle(
                            fontSize:
                                17,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height:
                        6,
                  ),

                  Text(
                    'Тип локації: ${tree.locationType}',
                    style:
                        const TextStyle(
                      color:
                          Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color:
                            Colors.green,
                      ),
                      const SizedBox(
                        width:
                            8,
                      ),
                      Text(
                        '${tree.dateFound.day.toString().padLeft(2, '0')}.'
                        '${tree.dateFound.month.toString().padLeft(2, '0')}.'
                        '${tree.dateFound.year}',
                        style:
                            const TextStyle(
                          fontSize:
                              17,
                        ),
                      ),
                    ],
                  ),

                  if (tree.foundTogether)
                    const Padding(
                      padding:
                          EdgeInsets.only(
                        top:
                            12,
                      ),
                      child:
                          Chip(
                        avatar:
                            Icon(
                          Icons.favorite,
                          size:
                              17,
                        ),
                        label:
                            Text(
                          'Знайдено разом ❤️',
                        ),
                      ),
                    ),

                  const SizedBox(
                    height:
                        25,
                  ),

                  const Text(
                    '📚 Цікаві факти',
                    style:
                        TextStyle(
                      fontSize:
                          21,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      16,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.green.shade50,
                      borderRadius:
                          BorderRadius.circular(
                        16,
                      ),
                    ),
                    child:
                        Text(
                      tree.facts.isEmpty
                          ? 'Фактів поки немає.'
                          : tree.facts,
                      style:
                          const TextStyle(
                        fontSize:
                            17,
                        height:
                            1.5,
                      ),
                    ),
                  ),

                  if (tree.notes
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(
                      height:
                          28,
                    ),

                    const Text(
                      '❤️ Наша історія',
                      style:
                          TextStyle(
                        fontSize:
                            21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.pink.shade50,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                      child:
                          Text(
                        tree.notes,
                        style:
                            const TextStyle(
                          fontSize:
                              17,
                          height:
                              1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MAP PAGE
// ============================================================

class MapPage extends StatefulWidget {
  final List<Tree> trees;

  const MapPage({
    super.key,
    required this.trees,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Map<String, LatLng> coordinatesCache = {};

  bool loading = true;

  // ============================================================
  // КООРДИНАТИ ВІДОМИХ МІСТ
  // ============================================================

  final Map<String, LatLng> standardCoordinates = {
    'чернівці': const LatLng(48.2915, 25.9403),
    'львів': const LatLng(49.8397, 24.0297),
    'київ': const LatLng(50.4501, 30.5234),
    'будапешт': const LatLng(47.4979, 19.0402),
  };

  // ============================================================
  // НОРМАЛІЗАЦІЯ
  // ============================================================

  String normalizeLocation(String location) {
    String value = location.trim().toLowerCase();

    value = value.replaceAll(RegExp(r'\s+'), ' ');

    if (value.startsWith('м. ')) {
      value = value.substring(3);
    }

    if (value.startsWith('м ')) {
      value = value.substring(2);
    }

    return value.trim();
  }

  // ============================================================
  // ПОШУК КООРДИНАТ ВІДОМОГО МІСТА
  // ============================================================

  LatLng? getStandardCoordinates(String location) {
    final normalized = normalizeLocation(location);

    for (final entry in standardCoordinates.entries) {
      final city = entry.key;

      // Точний збіг
      if (normalized == city) {
        return entry.value;
      }

      // Наприклад:
      // "чернівці, україна"
      // "чернівці україна"
      // "чернівці (україна)"
      // "м. Чернівці"
      if (normalized.startsWith('$city,')) {
        return entry.value;
      }

      if (normalized.startsWith('$city ')) {
        return entry.value;
      }

      if (normalized.contains(city)) {
        return entry.value;
      }
    }

    return null;
  }

  // ============================================================
  // ОТРИМАТИ КООРДИНАТИ ДЛЯ ЛОКАЦІЇ
  // ============================================================

  LatLng? getCoordinates(String location) {
    // СПОЧАТКУ завжди перевіряємо відомі міста.
    // Це захищає їх від старого/неправильного кешу.
    final standard = getStandardCoordinates(location);

    if (standard != null) {
      return standard;
    }

    // Потім дивимося кеш
    final normalized = normalizeLocation(location);

    return coordinatesCache[normalized];
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadCoordinates();
  }

  // ============================================================
  // ЗАВАНТАЖЕННЯ КООРДИНАТ
  // ============================================================

  Future<void> loadCoordinates() async {
    final prefs = await SharedPreferences.getInstance();

    final cached = prefs.getString('map_coordinates');

    if (cached != null && cached.isNotEmpty) {
      try {
        final decoded = jsonDecode(cached);

        if (decoded is Map) {
          for (final entry in decoded.entries) {
            try {
              final value = entry.value;

              if (value is Map &&
                  value['lat'] != null &&
                  value['lng'] != null) {
                coordinatesCache[
                    normalizeLocation(entry.key.toString())] = LatLng(
                  (value['lat'] as num).toDouble(),
                  (value['lng'] as num).toDouble(),
                );
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    await findMissingCoordinates();

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  // ============================================================
  // ЗБЕРЕЖЕННЯ КООРДИНАТ
  // ============================================================

  Future<void> saveCoordinates() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> data = {};

    for (final entry in coordinatesCache.entries) {
      data[entry.key] = {
        'lat': entry.value.latitude,
        'lng': entry.value.longitude,
      };
    }

    await prefs.setString(
      'map_coordinates',
      jsonEncode(data),
    );
  }

  // ============================================================
  // GEOCODING
  // ============================================================

  Future<LatLng?> geocodeLocation(String location) async {
    final normalized = normalizeLocation(location);

    // Відоме місто
    final standard = getStandardCoordinates(location);

    if (standard != null) {
      coordinatesCache[normalized] = standard;
      return standard;
    }

    // Кеш
    if (coordinatesCache.containsKey(normalized)) {
      return coordinatesCache[normalized];
    }

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': location,
          'format': 'jsonv2',
          'limit': '1',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Derevarium/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        if (data.isNotEmpty) {
          final lat = double.tryParse(
            data[0]['lat'].toString(),
          );

          final lon = double.tryParse(
            data[0]['lon'].toString(),
          );

          if (lat != null && lon != null) {
            final point = LatLng(lat, lon);

            coordinatesCache[normalized] = point;

            return point;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // ПОШУК КООРДИНАТ ДЛЯ ВСІХ ЛОКАЦІЙ
  // ============================================================

  Future<void> findMissingCoordinates() async {
    final Set<String> locations = widget.trees
        .map((tree) => tree.location.trim())
        .where((location) => location.isNotEmpty)
        .toSet();

    for (final location in locations) {
      final normalized = normalizeLocation(location);

      // Відоме місто
      final standard = getStandardCoordinates(location);

      if (standard != null) {
        coordinatesCache[normalized] = standard;
        continue;
      }

      // Вже є в кеші
      if (coordinatesCache.containsKey(normalized)) {
        continue;
      }

      // OpenStreetMap
      await Future.delayed(
        const Duration(milliseconds: 1100),
      );

      await geocodeLocation(location);
    }

    await saveCoordinates();
  }

  // ============================================================
  // ГРУПУВАННЯ ДЕРЕВ
  // ============================================================

  Map<String, List<Tree>> get groupedTrees {
    final Map<String, List<Tree>> result = {};

    for (final tree in widget.trees) {
      final originalLocation = tree.location.trim();

      if (originalLocation.isEmpty) {
        continue;
      }

      final normalized = normalizeLocation(originalLocation);

      result.putIfAbsent(
        normalized,
        () => [],
      ).add(tree);
    }

    return result;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final groups = groupedTrees;

    // ============================================================
    // ВАЖЛИВО:
    // координати беремо через getCoordinates(),
    // а не напряму з coordinatesCache.
    //
    // Тому навіть якщо кеш зламаний,
    // Чернівці та Будапешт все одно покажуться.
    // ============================================================

    final mappedGroups = groups.entries.where((entry) {
      return getCoordinates(entry.key) != null;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🗺️ Карта відкриттів',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 15),
                  Text(
                    'Шукаємо локації на карті...',
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // ==================================================
                // MAP
                // ==================================================

                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(
                      48.2915,
                      25.9403,
                    ),
                    initialZoom: 6,
                    minZoom: 3,
                    maxZoom: 18,
                  ),

                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.derevarium',
                    ),

                    // ==================================================
                    // MARKERS
                    // ==================================================

                    MarkerLayer(
                      markers: mappedGroups.map(
                        (entry) {
                          final location = entry.key;

                          final treesAtLocation =
                              entry.value;

                          // ОТРИМУЄМО КООРДИНАТИ
                          final coordinates =
                              getCoordinates(location)!;

                          return Marker(
                            point: coordinates,
                            width: 110,
                            height: 110,

                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  builder: (context) {
                                    return SafeArea(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.all(
                                          20,
                                        ),
                                        child: Column(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '📍 $location',
                                              style:
                                                  const TextStyle(
                                                fontSize: 22,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(
                                              height: 10,
                                            ),

                                            Text(
                                              'Знайдено дерев: ${treesAtLocation.length}',
                                              style:
                                                  const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),

                                            const SizedBox(
                                              height: 12,
                                            ),

                                            ...treesAtLocation.map(
                                              (tree) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 6,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.eco,
                                                        size: 18,
                                                        color:
                                                            Colors.green,
                                                      ),

                                                      const SizedBox(
                                                        width: 8,
                                                      ),

                                                      Expanded(
                                                        child: Text(
                                                          tree.type,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },

                              child: Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 54,
                                    height: 54,

                                    decoration:
                                        BoxDecoration(
                                      color: Colors.green,
                                      shape:
                                          BoxShape.circle,

                                      border:
                                          Border.all(
                                        color:
                                            Colors.white,
                                        width: 4,
                                      ),

                                      boxShadow:
                                          const [
                                        BoxShadow(
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),

                                    child: const Icon(
                                      Icons.park,
                                      color:
                                          Colors.white,
                                      size: 28,
                                    ),
                                  ),

                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),

                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.white,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        10,
                                      ),
                                    ),

                                    child: Text(
                                      '${treesAtLocation.length}',
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ],
                ),

                // ==================================================
                // ПОПЕРЕДЖЕННЯ
                // ==================================================

                if (mappedGroups.length < groups.length)
                  Positioned(
                    left: 16,
                    top: 16,
                    right: 16,

                    child: Card(
                      child: Padding(
                        padding:
                            const EdgeInsets.all(12),

                        child: Text(
                          '⚠️ Деякі локації ще не знайдені на карті.',
                          textAlign:
                              TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                // ==================================================
                // ЛІЧИЛЬНИК
                // ==================================================

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,

                  child: Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(14),

                      child: Row(
                        children: [
                          const Icon(
                            Icons.forest_outlined,
                            color: Colors.green,
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child: Text(
                              'Усього відкриттів: ${widget.trees.length}',
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
// ============================================================
// STATS PAGE
// ============================================================

class StatsPage
    extends StatelessWidget {
  final List<Tree> trees;

  const StatsPage({
    super.key,
    required this.trees,
  });

  int get uniqueTypes {
    return trees
        .map(
          (tree) =>
              tree.type
                  .trim()
                  .toLowerCase(),
        )
        .where(
          (type) =>
              type.isNotEmpty,
        )
        .toSet()
        .length;
  }

  int get uniqueLocations {
    return trees
        .map(
          (tree) =>
              tree.location
                  .trim()
                  .toLowerCase(),
        )
        .where(
          (location) =>
              location.isNotEmpty,
        )
        .toSet()
        .length;
  }

  String get mostCommonTree {
    if (trees.isEmpty) {
      return '—';
    }

    final counts =
        <String, int>{};

    for (final tree in trees) {
      final type =
          tree.type.trim();

      if (type.isEmpty) {
        continue;
      }

      counts[type] =
          (counts[type] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return '—';
    }

    String result =
        counts.keys.first;

    for (final type
        in counts.keys) {
      if (counts[type]! >
          counts[result]!) {
        result = type;
      }
    }

    return result;
  }

  Map<String, int> get typeCounts {
    final counts =
        <String, int>{};

    for (final tree in trees) {
      final type =
          tree.type.trim();

      if (type.isEmpty) {
        continue;
      }

      counts[type] =
          (counts[type] ?? 0) + 1;
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    const goal = 20;

    final progress =
        (uniqueTypes / goal)
            .clamp(0.0, 1.0);

    final sortedTypes =
        typeCounts.entries.toList()
          ..sort(
            (a, b) =>
                b.value.compareTo(
              a.value,
            ),
          );

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          '📊 Статистика',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body:
          ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        children: [
          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Column(
                children: [
                  const Icon(
                    Icons
                        .forest_rounded,
                    size:
                        55,
                    color:
                        Colors.green,
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  Text(
                    '${trees.length}',
                    style:
                        const TextStyle(
                      fontSize:
                          42,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'усього відкриттів',
                    style:
                        TextStyle(
                      fontSize:
                          17,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height:
                14,
          ),
          Row(
            children: [
              Expanded(
                child:
                    _StatCard(
                  icon:
                      Icons.eco,
                  value:
                      '$uniqueTypes',
                  label:
                      'Різних видів',
                ),
              ),
              const SizedBox(
                width:
                    10,
              ),
              Expanded(
                child:
                    _StatCard(
                  icon:
                      Icons.location_on,
                  value:
                      '$uniqueLocations',
                  label:
                      'Локацій',
                ),
              ),
            ],
          ),
          const SizedBox(
            height:
                14,
          ),
          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    '🌳 Прогрес колекції',
                    style:
                        TextStyle(
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height:
                        8,
                  ),
                  Text(
                    '$uniqueTypes із $goal різних видів',
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                    child:
                        LinearProgressIndicator(
                      value:
                          progress.toDouble(),
                      minHeight:
                          14,
                    ),
                  ),
                  const SizedBox(
                    height:
                        8,
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height:
                14,
          ),
          Card(
            child:
                ListTile(
              leading:
                  const CircleAvatar(
                child:
                    Icon(
                  Icons.eco,
                ),
              ),
              title:
                  const Text(
                'Найчастіше знайдене дерево',
              ),
              subtitle:
                  Text(
                mostCommonTree,
              ),
            ),
          ),
          const SizedBox(
            height:
                14,
          ),
          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    '🌱 Види у твоїй колекції',
                    style:
                        TextStyle(
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height:
                        12,
                  ),
                  if (sortedTypes.isEmpty)
                    const Text(
                      'Поки що немає відкриттів.',
                    )
                  else
                    ...sortedTypes.map(
                      (entry) {
                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom:
                                10,
                          ),
                          child:
                              Row(
                            children: [
                              const Icon(
                                Icons
                                    .park_outlined,
                                size:
                                    20,
                                color:
                                    Colors.green,
                              ),
                              const SizedBox(
                                width:
                                    8,
                              ),
                              Expanded(
                                child:
                                    Text(
                                  entry.key,
                                ),
                              ),
                              Text(
                                '${entry.value}',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

// ============================================================
// STAT CARD
// ============================================================

class _StatCard
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child:
            Column(
          children: [
            Icon(
              icon,
              size:
                  32,
              color:
                  Colors.green,
            ),
            const SizedBox(
              height:
                  8,
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize:
                    28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height:
                  4,
            ),
            Text(
              label,
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ACHIEVEMENT MODEL
// ============================================================

class Achievement {
  final String title;
  final String description;
  final IconData icon;
  final int progress;
  final int goal;
  final bool unlocked;

  Achievement({
    required this.title,
    required this.description,
    required this.icon,
    required this.progress,
    required this.goal,
    required this.unlocked,
  });
}

// ============================================================
// ACHIEVEMENTS PAGE
// ============================================================

class AchievementsPage
    extends StatelessWidget {
  final List<Tree> trees;

  const AchievementsPage({
    super.key,
    required this.trees,
  });

  int get uniqueTypes {
    return trees
        .map(
          (tree) =>
              tree.type
                  .trim()
                  .toLowerCase(),
        )
        .where(
          (type) =>
              type.isNotEmpty,
        )
        .toSet()
        .length;
  }

  int get uniqueLocations {
    return trees
        .map(
          (tree) =>
              tree.location
                  .trim()
                  .toLowerCase(),
        )
        .where(
          (location) =>
              location.isNotEmpty,
        )
        .toSet()
        .length;
  }

  int get parkTrees {
    return trees
        .where(
          (tree) =>
              tree.locationType ==
              'Парк',
        )
        .length;
  }

  int get outsideCityTrees {
    return trees
        .where(
          (tree) =>
              tree.locationType ==
                  'За містом' ||
              tree.locationType ==
                  'Село' ||
              tree.locationType ==
                  'Ліс',
        )
        .length;
  }

  int get treesWithFacts {
    return trees
        .where(
          (tree) =>
              tree.facts
                  .trim()
                  .isNotEmpty,
        )
        .length;
  }

  int get autumnTrees {
    return trees
        .where(
          (tree) =>
              tree.dateFound.month ==
                  9 ||
              tree.dateFound.month ==
                  10 ||
              tree.dateFound.month ==
                  11,
        )
        .length;
  }

  int get togetherTrees {
    return trees
        .where(
          (tree) =>
              tree.foundTogether,
        )
        .length;
  }

  int get rareTrees {
    return trees
        .where(
          (tree) =>
              tree.isRare,
        )
        .length;
  }

  int get maxStreak {
    if (trees.isEmpty) {
      return 0;
    }

    final dates =
        trees
            .map(
              (tree) =>
                  DateTime(
                tree.dateFound.year,
                tree.dateFound.month,
                tree.dateFound.day,
              ),
            )
            .toSet()
            .toList();

    dates.sort();

    if (dates.isEmpty) {
      return 0;
    }

    int longest = 1;
    int current = 1;

    for (int i = 1;
        i < dates.length;
        i++) {
      final difference =
          dates[i]
              .difference(
                dates[i - 1],
              )
              .inDays;

      if (difference == 1) {
        current++;
      } else {
        current = 1;
      }

      if (current > longest) {
        longest = current;
      }
    }

    return longest;
  }

  List<Achievement> get achievements {
    return [
      Achievement(
        title:
            'Перший листок',
        description:
            'Додай своє перше дерево в колекцію.',
        icon:
            Icons.eco,
        progress:
            trees.isEmpty ? 0 : 1,
        goal:
            1,
        unlocked:
            trees.isNotEmpty,
      ),
      Achievement(
        title:
            'Разом веселіше',
        description:
            'Додай дерево, яке сфотографували разом.',
        icon:
            Icons.favorite,
        progress:
            togetherTrees > 0
                ? 1
                : 0,
        goal:
            1,
        unlocked:
            togetherTrees > 0,
      ),
      Achievement(
        title:
            'Трилогія',
        description:
            'Збери 3 різні види дерев.',
        icon:
            Icons.filter_3,
        progress:
            uniqueTypes.clamp(
          0,
          3,
        ),
        goal:
            3,
        unlocked:
            uniqueTypes >= 3,
      ),
      Achievement(
        title:
            'Ботанік-початківець',
        description:
            'Збери 10 різних видів дерев.',
        icon:
            Icons.local_florist,
        progress:
            uniqueTypes.clamp(
          0,
          10,
        ),
        goal:
            10,
        unlocked:
            uniqueTypes >= 10,
      ),
      Achievement(
        title:
            'Дендролог',
        description:
            'Збери 25 різних видів дерев.',
        icon:
            Icons.forest,
        progress:
            uniqueTypes.clamp(
          0,
          25,
        ),
        goal:
            25,
        unlocked:
            uniqueTypes >= 25,
      ),
      Achievement(
        title:
            'Лісовий магістр',
        description:
            'Збери 50 різних видів дерев.',
        icon:
            Icons.workspace_premium,
        progress:
            uniqueTypes.clamp(
          0,
          50,
        ),
        goal:
            50,
        unlocked:
            uniqueTypes >= 50,
      ),
      Achievement(
        title:
            'Рідкісний екземпляр',
        description:
            'Знайди вид, який позначений як рідкісний.',
        icon:
            Icons.star,
        progress:
            rareTrees > 0
                ? 1
                : 0,
        goal:
            1,
        unlocked:
            rareTrees > 0,
      ),
      Achievement(
        title:
            'Перша мандрівка',
        description:
            'Відкрий першу нову локацію.',
        icon:
            Icons.place,
        progress:
            uniqueLocations >= 1
                ? 1
                : 0,
        goal:
            1,
        unlocked:
            uniqueLocations >= 1,
      ),
      Achievement(
        title:
            'Мандрівники',
        description:
            'Додай дерева з 5 різних локацій.',
        icon:
            Icons.map,
        progress:
            uniqueLocations.clamp(
          0,
          5,
        ),
        goal:
            5,
        unlocked:
            uniqueLocations >= 5,
      ),
      Achievement(
        title:
            'Парковий детектив',
        description:
            'Знайди 10 дерев у парках.',
        icon:
            Icons.park,
        progress:
            parkTrees.clamp(
          0,
          10,
        ),
        goal:
            10,
        unlocked:
            parkTrees >= 10,
      ),
      Achievement(
        title:
            'За межами міста',
        description:
            'Додай дерево за межами міста.',
        icon:
            Icons.nature_people,
        progress:
            outsideCityTrees > 0
                ? 1
                : 0,
        goal:
            1,
        unlocked:
            outsideCityTrees > 0,
      ),
      Achievement(
        title:
            'Цікавий факт',
        description:
            'Додай перший факт про дерево.',
        icon:
            Icons.menu_book,
        progress:
            treesWithFacts > 0
                ? 1
                : 0,
        goal:
            1,
        unlocked:
            treesWithFacts > 0,
      ),
      Achievement(
        title:
            'Енциклопедія',
        description:
            'Додай факти до 10 різних дерев.',
        icon:
            Icons.auto_stories,
        progress:
            treesWithFacts.clamp(
          0,
          10,
        ),
        goal:
            10,
        unlocked:
            treesWithFacts >= 10,
      ),
      Achievement(
        title:
            'Тижневий похід',
        description:
            'Додавай хоча б одне дерево 7 днів підряд.',
        icon:
            Icons.local_fire_department,
        progress:
            maxStreak.clamp(
          0,
          7,
        ),
        goal:
            7,
        unlocked:
            maxStreak >= 7,
      ),
      Achievement(
        title:
            'Осінній сезон',
        description:
            'Додай 5 дерев восени.',
        icon:
            Icons.park_outlined,
        progress:
            autumnTrees.clamp(
          0,
          5,
        ),
        goal:
            5,
        unlocked:
            autumnTrees >= 5,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all =
        achievements;

    final unlocked =
        all.where(
      (a) => a.unlocked,
    ).length;

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          '🏆 Досягнення',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body:
          ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
        children: [
          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child:
                  Column(
                children: [
                  const Icon(
                    Icons
                        .emoji_events,
                    size:
                        58,
                    color:
                        Colors.amber,
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  Text(
                    '$unlocked / ${all.length}',
                    style:
                        const TextStyle(
                      fontSize:
                          32,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'досягнень відкрито',
                    style:
                        TextStyle(
                      fontSize:
                          16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height:
                16,
          ),
          ...all.map(
            (achievement) {
              return _AchievementCard(
                achievement:
                    achievement,
              );
            },
          ),
          const SizedBox(
            height:
                20,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ACHIEVEMENT CARD
// ============================================================

class _AchievementCard
    extends StatelessWidget {
  final Achievement achievement;

  const _AchievementCard({
    required this.achievement,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        (achievement.progress /
                achievement.goal)
            .clamp(
      0.0,
      1.0,
    );

    return Card(
      margin:
          const EdgeInsets.only(
        bottom:
            12,
      ),
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child:
            Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            Container(
              width:
                  58,
              height:
                  58,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    achievement
                            .unlocked
                        ? Colors
                            .amber
                            .withValues(
                            alpha:
                                0.18,
                          )
                        : Colors
                            .grey
                            .withValues(
                            alpha:
                                0.15,
                          ),
              ),
              child:
                  Icon(
                achievement
                    .icon,
                size:
                    30,
                color:
                    achievement
                            .unlocked
                        ? Colors
                            .amber
                        : Colors
                            .grey,
              ),
            ),
            const SizedBox(
              width:
                  14,
            ),
            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child:
                            Text(
                          achievement
                              .title,
                          style:
                              const TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        achievement
                                .unlocked
                            ? Icons
                                .check_circle
                            : Icons
                                .lock_outline,
                        size:
                            20,
                        color:
                            achievement
                                    .unlocked
                                ? Colors
                                    .green
                                : Colors
                                    .grey,
                      ),
                    ],
                  ),
                  const SizedBox(
                    height:
                        5,
                  ),
                  Text(
                    achievement
                        .description,
                  ),
                  const SizedBox(
                    height:
                        10,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child:
                            ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                          child:
                              LinearProgressIndicator(
                            value:
                                progress.toDouble(),
                            minHeight:
                                8,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width:
                            10,
                      ),
                      Text(
                        '${achievement.progress}/${achievement.goal}',
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}