import 'package:flutter/foundation.dart';

import '../models/division.dart';
import '../models/kart.dart';
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

  void addDivision(String name, {KartClass kartClass = KartClass.pro}) {
    final divisions = List<Division>.from(_season.divisions);
    divisions.add(Division(name: name, sortOrder: divisions.length, kartClass: kartClass));
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void renameDivision(int divisionIndex, String name) {
    final divisions = List<Division>.from(_season.divisions);
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(name: name);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void updateDivisionClass(int divisionIndex, KartClass kartClass) {
    final divisions = List<Division>.from(_season.divisions);
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(kartClass: kartClass);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  void removeDivision(int divisionIndex) {
    final divisions = List<Division>.from(_season.divisions)
      ..removeAt(divisionIndex);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  // --- Racer edits -------------------------------------------------

  void addRacer(int divisionIndex,
      {required String firstName,
      required String lastName,
      double weight = 0,
      String? importName,
      String? phone,
      String? email}) {
    final divisions = List<Division>.from(_season.divisions);
    final division = divisions[divisionIndex];
    final racers = List<Racer>.from(division.racers);
    racers.add(Racer(
      firstName: firstName,
      lastName: lastName,
      sortOrder: racers.length,
      weight: weight,
      importName: importName,
      phone: phone,
      email: email,
      weeklyResults: List.generate(
        _season.weekCount,
        (i) => WeeklyResult(weekNumber: i + 1, weight: weight),
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
      {String? firstName,
      String? lastName,
      double? weight,
      String? importName,
      bool clearImportName = false,
      String? phone,
      bool clearPhone = false,
      String? email,
      bool clearEmail = false}) {
    final divisions = List<Division>.from(_season.divisions);
    final racers = List<Racer>.from(divisions[divisionIndex].racers);
    racers[racerIndex] = racers[racerIndex].copyWith(
      firstName: firstName,
      lastName: lastName,
      weight: weight,
      importName: importName,
      clearImportName: clearImportName,
      phone: phone,
      clearPhone: clearPhone,
      email: email,
      clearEmail: clearEmail,
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

  /// Sets a racer's weight for a given week, used to order who picks a kart
  /// first (heaviest first) before that week's heats. Pass null to clear it.
  void updateWeeklyWeight(
      int divisionIndex, int racerIndex, int weekNumber, double? weight) {
    final divisions = List<Division>.from(_season.divisions);
    final racers = List<Racer>.from(divisions[divisionIndex].racers);
    racers[racerIndex] = racers[racerIndex].withUpdatedWeek(
        weekNumber, (r) => r.copyWith(weight: weight, clearWeight: weight == null));
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(racers: racers);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  /// Assigns the kart a racer picked for a given week. Pass null to clear it.
  void updateWeeklyKartNumber(
      int divisionIndex, int racerIndex, int weekNumber, int? kartNumber) {
    final divisions = List<Division>.from(_season.divisions);
    final racers = List<Racer>.from(divisions[divisionIndex].racers);
    racers[racerIndex] = racers[racerIndex].withUpdatedWeek(
        weekNumber,
        (r) => r.copyWith(
              kartNumber: kartNumber,
              clearKartNumber: kartNumber == null,
            ));
    divisions[divisionIndex] = divisions[divisionIndex].copyWith(racers: racers);
    _setSeason(_season.copyWith(divisions: divisions));
  }

  // --- Kart pool edits -------------------------------------------------

  /// Adds a kart to the season's pool. No-ops if that number is already in
  /// the pool.
  void addKart(int number, KartClass kartClass) {
    if (_season.kartPool.any((k) => k.number == number)) return;
    final kartPool = List<Kart>.from(_season.kartPool)
      ..add(Kart(number: number, classType: kartClass));
    _setSeason(_season.copyWith(kartPool: kartPool));
  }

  void removeKart(int number) {
    final kartPool = List<Kart>.from(_season.kartPool)
      ..removeWhere((k) => k.number == number);
    _setSeason(_season.copyWith(kartPool: kartPool));
  }

  /// Marks a kart as broken/out of service for a given week, or clears that
  /// mark. Other weeks are unaffected.
  void setKartDownForWeek(int number, int weekNumber, bool isDown) {
    final kartPool = List<Kart>.from(_season.kartPool);
    final index = kartPool.indexWhere((k) => k.number == number);
    if (index == -1) return;
    final downWeeks = Set<int>.from(kartPool[index].downWeeks);
    if (isDown) {
      downWeeks.add(weekNumber);
    } else {
      downWeeks.remove(weekNumber);
    }
    kartPool[index] = kartPool[index].copyWith(downWeeks: downWeeks);
    _setSeason(_season.copyWith(kartPool: kartPool));
  }

  /// Saves the current kart pool to a standalone roster file so it can be
  /// reloaded into a future season without retyping every kart number.
  Future<bool> saveKartRosterToFile() async {
    final path =
        await _fileService.pickKartRosterSavePath(suggestedName: '${_season.name} karts');
    if (path == null) return false;
    await _fileService.writeKartRoster(path, _season.kartPool);
    return true;
  }

  /// Loads a standalone roster file and merges it into the current kart
  /// pool. Karts whose number is already in the pool are left untouched
  /// (existing down-for-week status is preserved).
  Future<bool> loadKartRosterFromFile() async {
    final path = await _fileService.pickKartRosterOpenPath();
    if (path == null) return false;
    final loaded = await _fileService.readKartRoster(path);
    final kartPool = List<Kart>.from(_season.kartPool);
    for (final kart in loaded) {
      if (kartPool.any((k) => k.number == kart.number)) continue;
      kartPool.add(kart);
    }
    _setSeason(_season.copyWith(kartPool: kartPool));
    return true;
  }
}
