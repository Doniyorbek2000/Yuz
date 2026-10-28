import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/photo_project_controller.dart';
import '../data/project_repository.dart';
import '../domain/photo_project.dart';

/// Picks an image file; overridable in tests.
typedef PhotoPicker = Future<String?> Function();

final photoPickerProvider = Provider<PhotoPicker>((ref) {
  return () async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: true);
    return picked?.path;
  };
});

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  bool _importing = false;

  Future<void> _newProject() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = await ref.read(photoPickerProvider)();
    if (path == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final project = await ref.read(projectRepositoryProvider).create(path);
      ref.invalidate(projectsListProvider);
      if (mounted) await context.push('/photo/${project.id}');
      ref.invalidate(projectsListProvider);
    } on FileSystemException catch (error) {
      debugPrint('Import failed: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.projectsImportFailed)));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _delete(PhotoProject project) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.projectsDeleteTitle),
        content: Text(l10n.projectsDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.actionCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    await ref.read(projectRepositoryProvider).delete(project.id);
    ref.invalidate(projectsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(projectsListProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('new-project'),
        onPressed: _importing ? null : _newProject,
        icon: _importing
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_photo_alternate_outlined),
        label: Text(l10n.projectsNew),
      ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (error, _) => Center(child: Text(l10n.errorUnknown)),
        data: (items) => items.isEmpty
            ? _EmptyProjects(onImport: _importing ? null : _newProject)
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final project = items[index];
                  return _ProjectTile(
                    key: ValueKey('project-${project.id}'),
                    project: project,
                    onOpen: () async {
                      await context.push('/photo/${project.id}');
                      ref.invalidate(projectsListProvider);
                    },
                    onDelete: () => _delete(project),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onImport});

  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.projectsEmptyTitle, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.projectsEmptyBody, textAlign: TextAlign.center, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ProjectTile extends ConsumerStatefulWidget {
  const _ProjectTile({required this.project, required this.onOpen, required this.onDelete, super.key});

  final PhotoProject project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  ConsumerState<_ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends ConsumerState<_ProjectTile> {
  late Future<File?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _thumbnail();
  }

  @override
  void didUpdateWidget(_ProjectTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.updatedAt != widget.project.updatedAt) _thumbnailFuture = _thumbnail();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onOpen = widget.onOpen;
    final onDelete = widget.onDelete;
    return FutureBuilder<File?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.all(AppRadii.md),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            onLongPress: onDelete,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (file != null)
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                  ),
                Positioned(
                  right: AppSpacing.xxs,
                  top: AppSpacing.xxs,
                  child: IconButton(
                    tooltip: l10n.actionDelete,
                    style: IconButton.styleFrom(backgroundColor: AppColors.scrim),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Latest export, else the newest preview, else the original.
  Future<File?> _thumbnail() async {
    final project = widget.project;
    final files = await ref.read(projectRepositoryProvider).filesFor(project);
    final export = project.lastExportFileName;
    if (export != null) {
      final exported = File('${files.exports.path}/$export');
      if (await exported.exists()) return exported;
    }
    File? newest;
    for (final candidate in [files.preview(0), files.preview(1)]) {
      if (!await candidate.exists()) continue;
      if (newest == null || (await candidate.lastModified()).isAfter(await newest.lastModified())) {
        newest = candidate;
      }
    }
    return newest ?? files.original;
  }
}
