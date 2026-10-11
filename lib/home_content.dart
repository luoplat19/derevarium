import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'tree.dart';

class HomeContent extends StatelessWidget {
  final List<Tree> trees;
  final bool loaded;
  final VoidCallback onAdd;
  final VoidCallback onStorage;
  final VoidCallback onStats;
  final ValueChanged<Tree> onOpenTree;
  const HomeContent({
    super.key,
    required this.trees,
    required this.loaded,
    required this.onAdd,
    required this.onStorage,
    required this.onStats,
    required this.onOpenTree,
  });

  @override
  Widget build(BuildContext context) {
    final latest = trees.isEmpty
        ? null
        : trees.reduce((a, b) => a.dateFound.isAfter(b.dateFound) ? a : b);
    final species = trees
        .map((t) => t.type.trim().toLowerCase())
        .where((type) => type.isNotEmpty)
        .toSet()
        .length;
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.eco_outlined,
                          color: AppColors.sage,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Derevarium',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            tooltip: 'Сховище та копії',
                            onPressed: loaded ? onStorage : null,
                            icon: const Icon(
                              Icons.storage_rounded,
                              color: AppColors.sage,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'КОЛЕКЦІЯ ДЛЯ ДВОХ',
                      style: TextStyle(
                        color: AppColors.sage,
                        fontSize: 11,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Що знайдемо\nсьогодні?',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned(
                            left: 8,
                            bottom: 20,
                            child: _QuietLeaf(
                              color: AppColors.card,
                              angle: -0.4,
                            ),
                          ),
                          const Positioned(
                            right: 4,
                            top: 12,
                            child: _QuietLeaf(
                              color: AppColors.bgMid,
                              angle: 0.2,
                            ),
                          ),
                          Container(
                            width: 174,
                            height: 174,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.bgMid,
                              border: Border.all(color: AppColors.card),
                            ),
                            alignment: Alignment.center,
                            child: Semantics(
                              button: true,
                              enabled: loaded,
                              label: 'Додати дерево',
                              child: Material(
                                color: AppColors.sage,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: loaded ? onAdd : null,
                                  customBorder: const CircleBorder(),
                                  child: SizedBox(
                                    width: 144,
                                    height: 144,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const ExcludeSemantics(
                                          child: Icon(
                                            Icons.photo_camera_outlined,
                                            size: 64,
                                            color: AppColors.bgDark,
                                          ),
                                        ),
                                        Positioned(
                                          right: 10,
                                          bottom: 10,
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.bgDark,
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              size: 21,
                                              color: AppColors.mint,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Знайти дерево',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Збережіть фото й спогад про прогулянку.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.sage, fontSize: 14),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: _CollectionCount(
                            value: loaded ? '${trees.length}' : '…',
                            label: 'знахідок',
                            onTap: onStats,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CollectionCount(
                            value: loaded ? '$species' : '…',
                            label: 'видів відкрито',
                            onTap: onStats,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (latest != null)
                      Material(
                        color: AppColors.bgMid,
                        borderRadius: BorderRadius.circular(20),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onOpenTree(latest),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: latest.imageBase64 == null
                                      ? const SizedBox(
                                          width: 60,
                                          height: 72,
                                          child: ColoredBox(
                                            color: AppColors.cardLight,
                                            child: Icon(
                                              Icons.park_outlined,
                                              size: 32,
                                              color: AppColors.mint,
                                            ),
                                          ),
                                        )
                                      : Image.memory(
                                          base64Decode(latest.imageBase64!),
                                          width: 60,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const SizedBox(
                                                width: 60,
                                                height: 72,
                                                child: ColoredBox(
                                                  color: AppColors.cardLight,
                                                  child: Icon(
                                                    Icons.park_outlined,
                                                    color: AppColors.mint,
                                                  ),
                                                ),
                                              ),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Остання знахідка',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.sage,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        latest.type,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        latest.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.sage,
                                        ),
                                      ),
                                      if (latest.foundTogether)
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.favorite_border,
                                              size: 13,
                                              color: AppColors.sage,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Знайшли разом',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.sage,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.bgMid,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.park_outlined, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loaded
                                    ? 'Перша знахідка стане початком вашої історії.'
                                    : 'Завантажуємо вашу колекцію…',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.sage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietLeaf extends StatelessWidget {
  final Color color;
  final double angle;
  const _QuietLeaf({required this.color, required this.angle});
  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: angle,
    child: Container(
      width: 62,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(65),
          bottomRight: Radius.circular(65),
        ),
      ),
    ),
  );
}

class _CollectionCount extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;
  const _CollectionCount({
    required this.value,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.bar_chart_rounded,
                  size: 20,
                  color: AppColors.sage,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.sage),
            ),
          ],
        ),
      ),
    ),
  );
}
