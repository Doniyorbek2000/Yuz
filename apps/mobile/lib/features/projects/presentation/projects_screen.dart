import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../video/application/video_editor_controller.dart';
import '../../video/data/video_project_repository.dart';
import '../../video/domain/video_project.dart';
import '../../video/presentation/video_editor_screen.dart';
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
  const ProjectsScreen({this.initialTab = 0, super.key});

  /// 0 = photos, 1 = videos.
  final int initialTab;

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> with SingleTickerProviderStateMixin {
  bool _importing = false;
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1))
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _newVideoProject() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final path = await ref.read(videoPickerProvider)();
    if (path == null || !mounted) return;
    setState(() => _importing = true);
    try {
      final project = await createVideoProject(ref, path);
      if (project == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.videoImportFailed)));
        return;
      }
      ref.invalidate(videoProjectsListProvider);
      if (mounted) await context.push('/video-editor/${project.id}');
      ref.invalidate(videoProjectsListProvider);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _deleteVideo(VideoProject project) async {
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
    await ref.read(videoProjectRepositoryProvider).delete(project.id);
    ref.invalidate(videoProjectsListProvider);
  }

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
    final videos = _tabs.index == 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectsTitle),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(key: const ValueKey('tab-photos'), text: l10n.projectsPhotosTab),
            Tab(key: const ValueKey('tab-videos'), text: l10n.projectsVideosTab),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: ValueKey(videos ? 'new-video-project' : 'new-project'),
        onPressed: _importing ? null : (videos ? _newVideoProject : _newProject),
        icon: _importing
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(videos ? Icons.video_call_outlined : Icons.add_photo_alternate_outlined),
        label: Text(videos ? l10n.projectsNewVideo : l10n.projectsNew),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _photoTab(l10n, projects),
          _VideoProjectsTab(onDelete: _deleteVideo),
        ],
      ),
    );
  }

  Widget _photoTab(AppLocalizations l10n, AsyncValue<List<PhotoProject>> projects) {
    return projects.when(
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
    );
  }
}

class _VideoProjectsTab extends ConsumerWidget {
  const _VideoProjectsTab({required this.onDelete});

  final ValueChanged<VideoProject> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projects = ref.watch(videoProjectsListProvider);
    return projects.when(
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, _) => Center(child: Text(l10n.errorUnknown)),
      data: (items) => items.isEmpty
          ? _EmptyProjects(onImport: null, body: l10n.projectsVideoEmptyBody, icon: Icons.video_library_outlined)
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
                return _VideoProjectTile(
                  key: ValueKey('video-project-${project.id}'),
                  project: project,
                  onOpen: () async {
                    await context.push('/video-editor/${project.id}');
                    ref.invalidate(videoProjectsListProvider);
                  },
                  onDelete: () => onDelete(project),
                );
              },
            ),
    );
  }
}

class _VideoProjectTile extends ConsumerWidget {
  const _VideoProjectTile({required this.project, required this.onOpen, required this.onDelete, super.key});

  final VideoProject project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final seconds = (project.durationMillis / 1000).round();
    return FutureBuilder<VideoProjectFiles>(
      future: ref.read(videoProjectRepositoryProvider).filesFor(project.id),
      builder: (context, snapshot) {
        final files = snapshot.data;
        final thumbnail = files == null ? null : File('${files.thumbnailsFor(project.clips.first).path}/thumb_0.jpg');
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
                if (thumbnail != null)
                  Image.file(
                    thumbnail,
                    fit: BoxFit.cover,
                    cacheWidth: 400,
                    errorBuilder: (_, _, _) => const Icon(Icons.movie_outlined, size: 40),
                  ),
                Positioned(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.scrim,
                      borderRadius: BorderRadius.all(AppRadii.pill),
                    ),
                    child: Text(
                      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · ${project.clips.length}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
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
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.onImport, this.body, this.icon = Icons.photo_library_outlined});

  final VoidCallback? onImport;
  final String? body;
  final IconData icon;

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
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.projectsEmptyTitle, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(body ?? l10n.projectsEmptyBody, textAlign: TextAlign.center, style: textTheme.bodyMedium),
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
