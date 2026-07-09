import 'package:flutter/foundation.dart';

import '../models/division.dart';
import '../models/racer.dart';
import '../models/season.dart';
import '../models/weekly_result.dart';
import '../utils/constants.dart';
import 'file_service.dart';

/// Holds the in-memory Season document (like an open Word document), plus
/// the file it was opened from/saved to and whether it has unsaved edits.
/// All season/division/racer mutations go through this class so it can
/// track dirty state and notify the UI in one place.
class SeasonDocument extends ChangeNotifier {
  SeasonDocument({FileService? fileService})
      : _fileService = fileService ?? FileService(),
        _season = Season.blankTemplate(
            weekCount: defaultWeekCount, scoredPositions: defaultScoredPositions);

  final FileService _fileService;

  Season _season;
  Season get season => _season;

  String? _currentFilePath;
  String? get currentFilePath => _currentFilePath;

  bool _hasUnsavedChanges = false;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  String get displayName {
    if (_currentFilePath == null) return 'Untitled.$seasonFileExtension';
    final normalized = _currentFilePath!.replaceAll('\\', '/');
    return normalized.substring(normalized.lastIndexOf('/') + 1);
  }

  void _setSeason(Season newSeason) {
    _season = newSeason;
    _hasUnsavedChanges = true;
    notifyListeners();
  }

  // --- File lifecycle ---------------------------------------------------

  void newSeason() {
    _season = Season.blankTemplate(
        weekCount: defaultWeekCount, scoredPositions: defaultScoredPositions);
    _currentFilePath = null;
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  Future<bool> openFromPicker() async {
    final path = await _fileService.pickOpenPath();
    if (path == null) return false;
    final loaded = await _fileService.readSeason(path);
    _season = loaded;
    _currentFilePath = path;
    _hasUnsavedChanges = false;
    notifyListeners();
    return true;
  }

  Future<bool> save() async {
    if (_currentFilePath == null) {
      return saveAs();
    }
    await _fileService.writeSeason(_currentFilePath!, _season);
    _hasUnsavedChanges = false;
    notifyListeners();
    return true;
  }

  Future<bool> saveAs() async {
    final path = await _fileService.pickSavePath(suggestedName: _season.name);
    if (path == null) return false;
    await _fileService.writeSeason(path, _season);
    _currentFilePath = path;
    _hasUnsavedChanges = false;
    notifyListeners();
    return true;
  }

  // --- Season-level edits -------------------------------------------------

  void updateSeasonInfo({
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    int? weekCount,
    int? scoredPositions,
  }) {
    var updated = _season.copyWith(
      name: name,
      startDate: startDate,
      endDate: endDate,
      scoredPositions: scoredPositions,
    );
    if (weekCount != null && weekCount != _season.weekCount) {
      updated = updated.copyWith(
        weekCount: weekCount,
        divisions: updated.divisions
            .map((d) => d.copyWith(
                  racers: d.racers
                      .map((r) => r.copyWith(
                          weeklyResults: _resizeWeeklyResults(
                              r.weeklyResults, weekCount)))
                      .toList(),
                ))
            .toList(),
      );
    }
    _setSeason(updated);
  }

  List<WeeklyResult> _resizeWeeklyResults(
      List<WeeklyResult> current, int weekCount) {
    final byWeek = {for (final r in current) r.weekNumber: r};
    return List.generate(
      weekCount,
      (i) => byWeek[i + 1] ?? WeeklyResult(weekNumber: i + 1),
    );
  }

  // --- Division edits -------------------------------------------------

  void addDivision(String name) {
    final divisions = List<Division>.from(_season.divisions);
    divisions.add(Division(name: name, sortOrder: divisions.length));
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void renameDivision(int divisionIndex, String name) {
    final divisions = List<Division>.from(_season.divisions);
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(name: name);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void removeDivision(int divisionIndex) {
    final divisions = List<Division>.from(_season.divisions)
      ..removeAt(divisionIndex);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  // --- Racer edits -------------------------------------------------

  void addRacer(int divisionIndex, {required String firstName, required String lastName}) {
    final divisions = List<Division>.from(_season.divisions);
    final division = divisions[divisionIndex];
    final racers = List<Racer>.from(division.racers);
    racers.add(Racer(
      firstName: firstName,
      lastName: lastName,
      sortOrder: racers.length,
      weeklyResults: List.generate(
        _season.weekCount,
        (i) => WeeklyResult(weekNumber: i + 1),
      ),
    ));
    divisions[divisionIndex] = division.copyWith(racers: racers);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void removeRacer(int divisionIndex, int racerIndex) {
    final divisions = List<Division>.from(_season.divisions);
    final racers = List<Racer>.from(divisions[divisionIndex].racers)
      ..removeAt(racerIndex);
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(racers: racers);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void updateRacerInfo(int divisionIndex, int racerIndex,
      {String? firstName, String? lastName}) {
    final divisions = List<Division>.from(_season.divisions);
    final racers = List<Racer>.from(divisions[divisionIndex].racers);
    racers[racerIndex] = racers[racerIndex].copyWith(
      firstName: firstName,
      lastName: lastName,
    );
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(racers: racers);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  // --- Weekly result edits -------------------------------------------------

  /// Sets a racer's finish position for a given week. Pass null to clear it
  /// (no result recorded for that week). Points and totals are derived from
  /// this automatically.
  void updateWeeklyFinishPosition(
      int divisionIndex, int racerIndex, int weekNumber, int? finishPosition) {
    final divisions = List<Division>.from(_season.divisions);
    final racers = List<Racer>.from(divisions[divisionIndex].racers);
    racers[racerIndex] = racers[racerIndex].withUpdatedWeek(
        weekNumber,
        (r) => r.copyWith(
              finishPosition: finishPosition,
              clearFinishPosition: finishPosition == null,
            ));
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(racers: racers);
    _setSeason(_season.copyWith(divisions: divisions));
  }
}
