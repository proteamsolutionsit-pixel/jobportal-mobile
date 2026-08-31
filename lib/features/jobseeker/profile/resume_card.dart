/// CV upload and photograph upload.
///
/// **A resume is never written to the device's disk.** `GET /api/files/resume/{id}`
/// is session-checked and answers `octet-stream` with `no-store`; a cached CV on
/// a shared or lost phone is the whole employment history of the person carrying
/// it. Photos are public and cache normally — that asymmetry is the server's and
/// this file keeps it.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/common.dart';
import '../../../routing/router.dart';
import 'profile_controller.dart';

/// What the server accepts. Checked here as a courtesy so the reader is told
/// before a 20 MB upload fails — **the server is still the boundary.**
const _resumeExtensions = ['pdf', 'doc', 'docx', 'rtf', 'txt'];
const _maxResumeBytes = 5 * 1024 * 1024;
const _maxPhotoBytes = 5 * 1024 * 1024;

class ResumeCard extends ConsumerStatefulWidget {
  const ResumeCard({super.key});

  @override
  ConsumerState<ResumeCard> createState() => _ResumeCardState();
}

class _ResumeCardState extends ConsumerState<ResumeCard> {
  double? _progress;

  Future<void> _upload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _resumeExtensions,
      withData: false,
    );
    final file = picked?.files.singleOrNull;
    if (file == null || file.path == null) return;

    if (file.size > _maxResumeBytes) {
      if (mounted) {
        showSnack(
          context,
          'That file is ${fileSizeLabel(file.size)}. The limit is 5 MB.',
          bad: true,
        );
      }
      return;
    }

    setState(() => _progress = 0);
    try {
      await ref.read(seekerRepositoryProvider).uploadResume(
            filePath: file.path!,
            fileName: file.name,
            onProgress: (sent, total) {
              if (mounted && total > 0) setState(() => _progress = sent / total);
            },
          );
      ref.invalidate(profileProvider);
      if (mounted) showSnack(context, 'CV uploaded.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, bad: true);
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final has = profile?.hasResume ?? false;

    return SectionCard(
      title: 'CV / Resume',
      icon: Icons.description_outlined,
      actionLabel: has ? 'Replace' : null,
      onAction: has && _progress == null ? _upload : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_progress != null) ...[
            Text(
              'Uploading… ${((_progress ?? 0) * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Sp.x2),
            ClipRRect(
              borderRadius: BorderRadius.circular(R.pill),
              child: LinearProgressIndicator(value: _progress, minHeight: 5),
            ),
          ] else if (has) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: C.bad50,
                    borderRadius: BorderRadius.circular(R.md),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      size: 20, color: C.bad500),
                ),
                const SizedBox(width: Sp.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.resumeName ?? 'Your CV',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        [
                          if (profile?.resumeSize != null)
                            fileSizeLabel(profile!.resumeSize),
                          if (profile?.resumeUploadedAt != null)
                            'uploaded ${timeAgo(profile!.resumeUploadedAt)}',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Recruiters look for a CV first. Upload yours as a PDF or Word '
              'document — up to 5 MB.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Sp.x4),
            PrimaryButton(
              label: 'Upload your CV',
              icon: Icons.upload_file_rounded,
              onPressed: _upload,
            ),
          ],
          if (_progress == null) ...[
            const SizedBox(height: Sp.x2),
            // The highest-value shortcut in the app: typing a profile on a
            // phone is the worst part of the experience, and the parser
            // already exists.
            Center(
              child: TextButton.icon(
                onPressed: () => context.push(Routes.importCv),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 17),
                label: Text(
                  has
                      ? 'Fill my profile from a CV'
                      : 'Or fill my profile from a CV',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Choose and upload a profile photograph.
///
/// **A deliberate upload does not go through the document detector** — somebody
/// choosing their own photograph is making a statement, not leaving us a guess.
/// It *is* re-encoded through Pillow server-side, which strips EXIF, colour
/// profiles and anything appended after the image data.
Future<void> uploadPhoto(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null) return;

  final picked = await ImagePicker().pickImage(
    source: source,
    // Resized before upload: a 12 MP phone photograph is 4 MB of nothing useful
    // for a 200px avatar, and the server re-encodes it anyway.
    maxWidth: 1200,
    maxHeight: 1200,
    imageQuality: 88,
  );
  if (picked == null) return;

  final size = await picked.length();
  if (size > _maxPhotoBytes) {
    if (context.mounted) {
      showSnack(context, 'That image is too large. The limit is 5 MB.', bad: true);
    }
    return;
  }

  try {
    await ref.read(seekerRepositoryProvider).uploadPhoto(
          filePath: picked.path,
          fileName: picked.name,
        );
    ref.invalidate(profileProvider);
    if (context.mounted) showSnack(context, 'Photo updated.');
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, bad: true);
  }
}
