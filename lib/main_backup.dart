import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const TreeApp());
}

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

// =========================
// ГОЛОВНА
// =========================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Tree> trees = [];

  @override
  void initState() {
    super.initState();
    loadTrees();
  }

  Future<void> saveTrees() async {
    final prefs = await SharedPreferences.getInstance();

    final treeData = trees.map((tree) {
      return jsonEncode(tree.toJson());
    }).toList();

    await prefs.setStringList('trees', treeData);
  }

  Future<void> loadTrees() async {
    final prefs = await SharedPreferences.getInstance();

    final treeData = prefs.getStringList('trees');

    if (treeData == null) {
      return;
    }

    setState(() {
      trees.clear();

      for (final data in treeData) {
        try {
          final decoded = jsonDecode(data);

          trees.add(
            Tree.fromJson(decoded),
          );
        } catch (e) {
          // Пропускаємо пошкоджені записи
        }
      }
    });
  }

  Future<void> addTree(Tree tree) async {
    setState(() {
      trees.add(tree);
    });

    await saveTrees();
  }

  Future<void> updateTree(
    int index,
    Tree tree,
  ) async {
    setState(() {
      trees[index] = tree;
    });

    await saveTrees();
  }

  Future<void> deleteTree(int index) async {
    setState(() {
      trees.removeAt(index);
    });

    await saveTrees();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🌳 Derevarium'),
      ),

      body: trees.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    'Моя колекція порожня',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 10),

                  Text(
                    'Додай своє перше дерево 🌱',
                    style: TextStyle(
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trees.length,

              itemBuilder: (context, index) {
                final tree = trees[index];

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  clipBehavior: Clip.antiAlias,

                  child: InkWell(
                    onTap: () async {
                      final result =
                          await Navigator.push<TreeAction>(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TreeDetailsPage(
                            tree: tree,
                          ),
                        ),
                      );

                      if (result == null) {
                        return;
                      }

                      if (result.deleted) {
                        await deleteTree(index);
                      } else if (result.tree != null) {
                        await updateTree(
                          index,
                          result.tree!,
                        );
                      }
                    },

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        if (tree.imageBase64 != null)
                          Image.memory(
                            base64Decode(
                              tree.imageBase64!,
                            ),
                            width: double.infinity,
                            height: 220,
                            fit: BoxFit.cover,
                          ),

                        ListTile(
                          leading: const CircleAvatar(
                            child: Text('🌳'),
                          ),

                          title: Text(
                            tree.name,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          subtitle: Text(
                            tree.location,
                            style: const TextStyle(
                              fontSize: 15,
                            ),
                          ),

                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () async {
          final tree =
              await Navigator.push<Tree>(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const AddTreePage(),
            ),
          );

          if (tree != null) {
            await addTree(tree);
          }
        },

        icon: const Icon(Icons.add),

        label: const Text(
          'Додати дерево',
        ),
      ),
    );
  }
}

// =========================
// МОДЕЛЬ ДЕРЕВА
// =========================

class Tree {
  final String name;
  final String location;
  final String facts;
  final String? imageBase64;
  final DateTime? dateFound;

  Tree({
    required this.name,
    required this.location,
    required this.facts,
    this.imageBase64,
    this.dateFound,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'facts': facts,
      'imageBase64': imageBase64,
      'dateFound':
          dateFound?.toIso8601String(),
    };
  }

  factory Tree.fromJson(
    Map<String, dynamic> json,
  ) {
    DateTime? date;

    if (json['dateFound'] != null) {
      date = DateTime.tryParse(
        json['dateFound'].toString(),
      );
    }

    return Tree(
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      facts: json['facts'] ?? '',
      imageBase64:
          json['imageBase64'],
      dateFound: date,
    );
  }
}

// =========================
// ДІЇ З ДЕРЕВОМ
// =========================

class TreeAction {
  final Tree? tree;
  final bool deleted;

  TreeAction({
    this.tree,
    this.deleted = false,
  });
}

// =========================
// ДОДАВАННЯ / РЕДАГУВАННЯ
// =========================

class AddTreePage extends StatefulWidget {
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
  final TextEditingController
      nameController =
      TextEditingController();

  final TextEditingController
      locationController =
      TextEditingController();

  final TextEditingController
      factsController =
      TextEditingController();

  String? imageBase64;
  DateTime? selectedDate;

  String? selectedLocation;
  String? selectedTreeType;

  final List<String> locations = [
    'Чернівці',
    'Львів',
    'Київ',
    'Будапешт',
    'Інше...',
  ];

  final List<String> treeTypes = [
    'Дуб',
    'Клен',
    'Береза',
    'Сосна',
    'Ялина',
    'Липа',
    'Яблуня',
    'Тополя',
    'Інше...',
  ];

  bool get isEditing =>
      widget.tree != null;

  @override
  void initState() {
    super.initState();

    if (widget.tree != null) {
      nameController.text =
          widget.tree!.name;

      locationController.text =
          widget.tree!.location;

      factsController.text =
          widget.tree!.facts;

      imageBase64 =
          widget.tree!.imageBase64;

      selectedDate =
          widget.tree!.dateFound;

      // Якщо старе місце є у списку
      if (locations.contains(
          widget.tree!.location)) {
        selectedLocation =
            widget.tree!.location;
      } else if (
          widget.tree!.location.isNotEmpty) {
        selectedLocation = 'Інше...';
      }

      // Якщо стару назву можна знайти
      if (treeTypes.contains(
          widget.tree!.name)) {
        selectedTreeType =
            widget.tree!.name;
      } else if (
          widget.tree!.name.isNotEmpty) {
        selectedTreeType = 'Інше...';
      }
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final XFile? image =
        await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) {
      return;
    }

    final bytes =
        await image.readAsBytes();

    setState(() {
      imageBase64 =
          base64Encode(bytes);
    });
  }

  Future<void> pickDate() async {
    final DateTime? date =
        await showDatePicker(
      context: context,
      initialDate:
          selectedDate ??
              DateTime.now(),
      firstDate:
          DateTime(2000),
      lastDate:
          DateTime.now(),
    );

    if (date == null) {
      return;
    }

    setState(() {
      selectedDate = date;
    });
  }

  String formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> selectOtherLocation() async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Введіть місце',
          ),

          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              hintText:
                  'Наприклад: Одеса',
              border:
                  OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text('Скасувати'),
            ),

            FilledButton(
              onPressed: () {
                if (controller
                    .text
                    .trim()
                    .isNotEmpty) {
                  Navigator.pop(
                    context,
                    controller.text
                        .trim(),
                  );
                }
              },
              child:
                  const Text('Готово'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedLocation = result;
        locationController.text =
            result;
      });
    }
  }

  Future<void> selectOtherTree() async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Введіть назву дерева',
          ),

          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              hintText:
                  'Наприклад: Каштан',
              border:
                  OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text('Скасувати'),
            ),

            FilledButton(
              onPressed: () {
                if (controller
                    .text
                    .trim()
                    .isNotEmpty) {
                  Navigator.pop(
                    context,
                    controller.text
                        .trim(),
                  );
                }
              },
              child:
                  const Text('Готово'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedTreeType =
            result;

        nameController.text =
            result;
      });
    }
  }

  void saveTree() {
    if (nameController.text
        .trim()
        .isEmpty) {
      return;
    }

    final tree = Tree(
      name:
          nameController.text.trim(),

      location:
          locationController.text.trim(),

      facts:
          factsController.text.trim(),

      imageBase64:
          imageBase64,

      dateFound:
          selectedDate,
    );

    Navigator.pop(
      context,
      tree,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Редагувати дерево ✏️'
              : 'Додати дерево 🌳',
        ),
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(20),

        child: ListView(
          children: [
            Text(
              isEditing
                  ? 'Редагування'
                  : 'Нове відкриття',

              style:
                  const TextStyle(
                fontSize: 28,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            if (imageBase64 != null)
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),

                child: Image.memory(
                  base64Decode(
                    imageBase64!,
                  ),

                  height: 220,

                  width:
                      double.infinity,

                  fit:
                      BoxFit.cover,
                ),
              ),

            const SizedBox(
              height: 15,
            ),

            OutlinedButton.icon(
              onPressed:
                  pickImage,

              icon:
                  const Icon(
                Icons.photo,
              ),

              label: Text(
                imageBase64 == null
                    ? 'Додати фото'
                    : 'Змінити фото',
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // =========================
            // ВИД ДЕРЕВА
            // =========================

            DropdownButtonFormField<
                String>(
              value:
                  selectedTreeType,

              decoration:
                  const InputDecoration(
                labelText:
                    'Вид дерева',
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.forest,
                ),
              ),

              items:
                  treeTypes.map(
                (type) {
                  return DropdownMenuItem(
                    value: type,
                    child:
                        Text(type),
                  );
                },
              ).toList(),

              onChanged:
                  (value) {
                if (value ==
                    'Інше...') {
                  selectOtherTree();
                } else {
                  setState(() {
                    selectedTreeType =
                        value;

                    nameController
                            .text =
                        value ?? '';
                  });
                }
              },
            ),

            const SizedBox(
              height: 15,
            ),

            // =========================
            // МІСЦЕ
            // =========================

            DropdownButtonFormField<
                String>(
              value:
                  selectedLocation,

              decoration:
                  const InputDecoration(
                labelText:
                    'Місце знаходження',
                border:
                    OutlineInputBorder(),
                prefixIcon:
                    Icon(
                  Icons.location_on,
                ),
              ),

              items:
                  locations.map(
                (location) {
                  return DropdownMenuItem(
                    value:
                        location,

                    child:
                        Text(location),
                  );
                },
              ).toList(),

              onChanged:
                  (value) {
                if (value ==
                    'Інше...') {
                  selectOtherLocation();
                } else {
                  setState(() {
                    selectedLocation =
                        value;

                    locationController
                            .text =
                        value ?? '';
                  });
                }
              },
            ),

            const SizedBox(
              height: 15,
            ),

            OutlinedButton.icon(
              onPressed:
                  pickDate,

              icon:
                  const Icon(
                Icons.calendar_month,
              ),

              label: Text(
                selectedDate == null
                    ? 'Вибрати дату знаходження'
                    : 'Дата: ${formatDate(selectedDate!)}',
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            TextField(
              controller:
                  factsController,

              maxLines: 4,

              decoration:
                  const InputDecoration(
                labelText:
                    'Цікаві факти',

                hintText:
                    'Напиши щось цікаве про це дерево...',

                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            ElevatedButton.icon(
              onPressed:
                  saveTree,

              icon: Icon(
                isEditing
                    ? Icons.check
                    : Icons.save,
              ),

              label: Text(
                isEditing
                    ? 'Зберегти зміни'
                    : 'Зберегти дерево',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// ДЕТАЛІ ДЕРЕВА
// =========================

class TreeDetailsPage
    extends StatelessWidget {
  final Tree tree;

  const TreeDetailsPage({
    super.key,
    required this.tree,
  });

  String formatDate(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> editTree(
    BuildContext context,
  ) async {
    final updatedTree =
        await Navigator.push<Tree>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTreePage(
          tree: tree,
        ),
      ),
    );

    if (updatedTree != null &&
        context.mounted) {
      Navigator.pop(
        context,
        TreeAction(
          tree: updatedTree,
        ),
      );
    }
  }

  Future<void> deleteTree(
    BuildContext context,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Видалити дерево?',
          ),

          content: Text(
            'Ти точно хочеш видалити '
            '«${tree.name}» '
            'з колекції?',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },

              child:
                  const Text(
                'Скасувати',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },

              child:
                  const Text(
                'Видалити',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true &&
        context.mounted) {
      Navigator.pop(
        context,
        TreeAction(
          deleted: true,
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(tree.name),

        actions: [
          PopupMenuButton<String>(
            onSelected:
                (value) {
              if (value ==
                  'edit') {
                editTree(
                  context,
                );
              }

              if (value ==
                  'delete') {
                deleteTree(
                  context,
                );
              }
            },

            itemBuilder:
                (context) =>
                    const [
              PopupMenuItem(
                value: 'edit',

                child: Row(
                  children: [
                    Icon(
                      Icons.edit,
                    ),

                    SizedBox(
                      width: 10,
                    ),

                    Text(
                      'Редагувати',
                    ),
                  ],
                ),
              ),

              PopupMenuItem(
                value:
                    'delete',

                child: Row(
                  children: [
                    Icon(
                      Icons.delete,
                    ),

                    SizedBox(
                      width: 10,
                    ),

                    Text(
                      'Видалити',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: ListView(
        children: [
          if (tree.imageBase64 != null)
            Image.memory(
              base64Decode(
                tree.imageBase64!,
              ),

              width:
                  double.infinity,

              height: 320,

              fit:
                  BoxFit.cover,
            ),

          Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [
                Text(
                  tree.name,

                  style:
                      const TextStyle(
                    fontSize: 30,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 15,
                ),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Icon(
                      Icons.location_on,
                      color:
                          Colors.green,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Text(
                        tree.location
                                .isEmpty
                            ? 'Місце не вказано'
                            : tree.location,

                        style:
                            const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                if (tree.dateFound !=
                    null) ...[
                  const SizedBox(
                    height: 12,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .calendar_month,
                        color:
                            Colors.green,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Text(
                        formatDate(
                          tree.dateFound!,
                        ),

                        style:
                            const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(
                  height: 30,
                ),

                const Text(
                  '🌿 Цікаві факти',

                  style:
                      TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Text(
                  tree.facts.isEmpty
                      ? 'Факти ще не додані.'
                      : tree.facts,

                  style:
                      const TextStyle(
                    fontSize: 17,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}