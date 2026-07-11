import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../models/kart.dart';
import '../models/season.dart';
import '../utils/constants.dart';

/// Thin wrapper around file_selector + dart:io so the rest of the app never
/// touches file dialogs or raw I/O directly.
class FileService {
  static const _typeGroup = XTypeGroup(
    label: 'League Points Season',
    extensions: [seasonFileExtension],
  );

  static const _kartRosterTypeGroup = XTypeGroup(
    label: 'Kart Roster',
    extensions: [kartRosterFileExtension],
  );

  Future<String?> pickOpenPath() async {
    final file = await openFile(acceptedTypeGroups: [_typeGroup]);
    return file?.path;
  }

  Future<String?> pickSavePath({String? suggestedName}) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: [_typeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    return location.path.endsWith('.$seasonFileExtension')
        ? location.path
        : '${location.path}.$seasonFileExtension';
  }

  Future<Season> readSeason(String path) async {
    final contents = await File(path).readAsString();
    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    final seasonJson = decoded['season'] as Map<String, dynamic>;
    return Season.fromJson(seasonJson);
  }

  Future<void> writeSeason(String path, Season season) async {
    final document = {
      'formatVersion': currentFormatVersion,
      'season': season.toJson(),
    };
    const encoder = JsonEncoder.withIndent('  ');
    await File(path).writeAsString(encoder.convert(document));
  }

  Future<String?> pickKartRosterOpenPath() async {
    final file = await openFile(acceptedTypeGroups: [_kartRosterTypeGroup]);
    return file?.path;
  }

  Future<String?> pickKartRosterSavePath({String? suggestedName}) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: [_kartRosterTypeGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    return location.path.endsWith('.$kartRosterFileExtension')
        ? location.path
        : '${location.path}.$kartRosterFileExtension';
  }

  /// Reads a standalone kart roster file. Down-week status is never part of
  /// a roster (that's specific to the season/week it was recorded for), so
  /// every kart comes back available.
  Future<List<Kart>> readKartRoster(String path) async {
    final contents = await File(path).readAsString();
    final decoded = jsonDecode(contents) as Map<String, dynamic>;
    final kartsJson = decoded['karts'] as List<dynamic>;
    return kartsJson
        .map((k) => Kart.fromJson(k as Map<String, dynamic>).copyWith(downWeeks: const {}))
        .toList();
  }

  Future<void> writeKartRoster(String path, List<Kart> karts) async {
    final document = {
      'formatVersion': currentFormatVersion,
      'karts': [
        for (final kart in karts) {'number': kart.number, 'classType': kart.classType.name},
      ],
    };
    const encoder = JsonEncoder.withIndent('  ');
    await File(path).writeAsString(encoder.convert(document));
  }
}
