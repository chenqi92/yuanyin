import 'dart:io';

import 'package:flutter/widgets.dart';

const _yyCompanionCoverNames = [
  'folder.jpg',
  'folder.jpeg',
  'folder.png',
  'folder.webp',
  'cover.jpg',
  'cover.jpeg',
  'cover.png',
  'cover.webp',
  'front.jpg',
  'front.jpeg',
  'front.png',
  'front.webp',
  'album.jpg',
  'album.jpeg',
  'album.png',
  'album.webp',
  'artwork.jpg',
  'artwork.jpeg',
  'artwork.png',
  'artwork.webp',
];

const _yySongImageExts = ['.jpg', '.jpeg', '.png', '.webp'];

bool yyIsRemoteCoverUrl(String? coverUrl) {
  final normalized = _yyNormalizeCoverUrl(coverUrl);
  if (normalized == null) return false;
  final uri = Uri.tryParse(normalized);
  final scheme = uri?.scheme.toLowerCase();
  return scheme == 'http' || scheme == 'https';
}

String? yyResolveCoverPath(String? coverUrl) {
  final normalized = _yyNormalizeCoverUrl(coverUrl);
  if (normalized == null) return null;

  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.scheme.toLowerCase() == 'file') {
    return uri.toFilePath();
  }

  return normalized;
}

File? yyResolveLocalCoverFile(String? coverUrl) {
  if (yyIsRemoteCoverUrl(coverUrl)) return null;
  final path = yyResolveCoverPath(coverUrl);
  if (path == null || path.isEmpty) return null;
  return File(path);
}

List<String> yyResolveCoverCandidates({String? coverUrl, String? filePath}) {
  final resolved = <String>[];
  final seen = <String>{};

  void addCandidate(String? value) {
    final normalized = _yyNormalizeCoverUrl(value);
    if (normalized == null || !seen.add(normalized)) return;
    resolved.add(normalized);
  }

  addCandidate(coverUrl);
  for (final candidate in _yyCompanionCandidates(filePath)) {
    addCandidate(candidate);
  }

  return resolved;
}

ImageProvider<Object>? yyBuildCoverImageProvider(
  String? coverUrl, {
  String? filePath,
}) {
  final candidates = yyResolveCoverCandidates(
    coverUrl: coverUrl,
    filePath: filePath,
  );
  if (candidates.isEmpty) return null;
  return yyBuildCoverImageProviderFromCandidate(candidates.first);
}

ImageProvider<Object>? yyBuildCoverImageProviderFromCandidate(
  String candidate,
) {
  final path = yyResolveCoverPath(candidate);
  if (path == null || path.isEmpty) return null;

  if (yyIsRemoteCoverUrl(candidate)) {
    return NetworkImage(path);
  }

  return FileImage(File(path));
}

String? _yyNormalizeCoverUrl(String? coverUrl) {
  if (coverUrl == null) return null;

  final trimmed = coverUrl.trim();
  if (trimmed.isEmpty) return null;

  final decoded = Uri.decodeFull(trimmed);
  if (decoded.startsWith('file://')) {
    return decoded;
  }

  final uri = Uri.tryParse(decoded);
  if (uri == null) {
    return decoded;
  }

  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https' || scheme == 'file') {
    return uri.toString();
  }

  if (scheme.isNotEmpty) {
    return null;
  }

  return decoded;
}

Iterable<String> _yyCompanionCandidates(String? filePath) sync* {
  final normalized = _yyNormalizeCoverUrl(filePath);
  if (normalized == null) return;

  if (yyIsRemoteCoverUrl(normalized)) {
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    final synologyCandidates = _yySynologyCompanionCandidates(uri);
    if (synologyCandidates.isNotEmpty) {
      yield* synologyCandidates;
      return;
    }

    if (uri.pathSegments.isEmpty) return;
    final stem = _yyStem(uri.pathSegments.last);
    final directorySegments = uri.pathSegments.take(
      uri.pathSegments.length - 1,
    );
    for (final ext in _yySongImageExts) {
      yield uri
          .replace(pathSegments: [...directorySegments, '$stem$ext'])
          .toString();
    }
    for (final fileName in _yyCompanionCoverNames) {
      yield uri
          .replace(pathSegments: [...directorySegments, fileName])
          .toString();
    }
    return;
  }

  final localPath = yyResolveCoverPath(normalized);
  if (localPath == null || localPath.isEmpty) return;
  final mediaFile = File(localPath);
  final parent = mediaFile.parent.path;
  final stem = _yyStem(mediaFile.uri.pathSegments.last);
  for (final ext in _yySongImageExts) {
    yield '$parent/$stem$ext';
  }
  for (final fileName in _yyCompanionCoverNames) {
    yield '$parent/$fileName';
  }
}

List<String> _yySynologyCompanionCandidates(Uri uri) {
  final parameters = Map<String, String>.from(uri.queryParameters);
  final remotePath = parameters['path'];
  if (remotePath == null || remotePath.isEmpty) return const [];

  final slashIndex = remotePath.lastIndexOf('/');
  if (slashIndex <= 0) return const [];

  final directory = remotePath.substring(0, slashIndex);
  final stem = _yyStem(remotePath.substring(slashIndex + 1));
  final candidates = <String>[];
  for (final ext in _yySongImageExts) {
    final updatedParameters = Map<String, String>.from(parameters)
      ..['path'] = '$directory/$stem$ext';
    candidates.add(uri.replace(queryParameters: updatedParameters).toString());
  }
  for (final fileName in _yyCompanionCoverNames) {
    final updatedParameters = Map<String, String>.from(parameters)
      ..['path'] = '$directory/$fileName';
    candidates.add(uri.replace(queryParameters: updatedParameters).toString());
  }
  return candidates;
}

String _yyStem(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0) return fileName;
  return fileName.substring(0, dotIndex);
}
