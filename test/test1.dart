import 'dart:math';

/// str: (-3~,1~4)3 之类
ParsedCoordinateData? parseDataStr(String str) {
  str = str.replaceAll(' ', '');
  var regExp = RegExp(
      r'^\((?<columnBegin>-?[0-9]+)?(?<columnRanged>~)?(?<columnEnd>-?[0-9]+)?,(?<rowBegin>-?[0-9]+)?(?<rowRanged>~)?(?<rowEnd>-?[0-9]+)?\)(?<distanceBegin>-?[0-9]+)?(?<distanceRanged>~)?(?<distanceEnd>-?[0-9]+)?$');
  if (!regExp.hasMatch(str)) return null;
  var match = regExp.allMatches(str).first;
  ParsedCoordinateData result = ParsedCoordinateData();
  result.columnBegin = num.tryParse(match.namedGroup("columnBegin").toString());
  result.columnEnd = num.tryParse(match.namedGroup("columnEnd").toString());
  result.rowBegin = num.tryParse(match.namedGroup("rowBegin").toString());
  result.rowEnd = num.tryParse(match.namedGroup("rowEnd").toString());
  result.distanceBegin =
      num.tryParse(match.namedGroup("distanceBegin").toString());
  result.distanceEnd = num.tryParse(match.namedGroup("distanceEnd").toString());
  result.columnRanged = match.namedGroup("columnRanged") != null;
  result.rowRanged = match.namedGroup("rowRanged") != null;
  result.distanceRanged = match.namedGroup("distanceRanged") != null;
  result.columnDemanded =
      result.columnBegin != null || result.columnEnd != null;
  result.rowDemanded = result.rowBegin != null || result.rowEnd != null;
  result.distanceDemanded =
      result.distanceBegin != null || result.distanceEnd != null;
  return result;
}

class ParsedCoordinateData {
  num? columnBegin;
  num? columnEnd;
  num? rowBegin;
  num? rowEnd;
  num? distanceBegin;
  num? distanceEnd;
  late bool columnRanged;
  late bool rowRanged;
  late bool distanceRanged;
  late bool columnDemanded;
  late bool rowDemanded;
  late bool distanceDemanded;
  @override
  String toString() {
    return "{columnDemanded: $columnDemanded, columnBegin: $columnBegin, columnRanged: $columnRanged, columnEnd: $columnEnd, rowDemanded: $rowDemanded, rowBegin: $rowBegin, rowRanged: $rowRanged, rowEnd: $rowEnd, distanceDemanded: $distanceDemanded, distanceBegin: $distanceBegin, distanceRanged: $distanceRanged, distanceEnd: $distanceEnd, }";
  }

  String toRawString() {
    return "(${columnBegin ?? ''}${columnRanged ? '~' : ''}${columnRanged ? (columnEnd ?? '') : ''},${rowBegin ?? ''}${rowRanged ? '~' : ''}${rowRanged ? (rowEnd ?? '') : ''})${distanceBegin ?? ''}${distanceRanged ? '~' : ''}${distanceRanged ? (distanceEnd ?? '') : ''}";
  }

  ParsedCoordinateData();
  ParsedCoordinateData.random() {
    columnDemanded = Random().nextBool();
    rowDemanded = Random().nextBool();
    distanceDemanded = Random().nextBool();
    if (columnDemanded) {
      columnRanged = Random().nextBool();
      if (columnRanged) {
        if (Random().nextBool()) {
          columnBegin = Random().nextInt(6) + 1;
        }
        if (Random().nextBool()) {
          columnEnd = Random().nextInt(6) + 1;
        }
      } else {
        if (Random().nextBool()) {
          columnBegin = Random().nextInt(6) + 1;
        }
      }
    } else {
      columnRanged = false;
    }
    if (rowDemanded) {
      rowRanged = Random().nextBool();
      if (rowRanged) {
        if (Random().nextBool()) {
          rowBegin = Random().nextInt(6) + 1;
        }
        if (Random().nextBool()) {
          rowEnd = Random().nextInt(6) + 1;
        }
      } else {
        if (Random().nextBool()) {
          rowBegin = Random().nextInt(6) + 1;
        }
      }
    } else {
      rowRanged = false;
    }
    if (distanceDemanded) {
      distanceRanged = Random().nextBool();
      if (distanceRanged) {
        if (Random().nextBool()) {
          distanceBegin = Random().nextInt(6) + 1;
        }
        if (Random().nextBool()) {
          distanceEnd = Random().nextInt(6) + 1;
        }
      } else {
        if (Random().nextBool()) {
          distanceBegin = Random().nextInt(6) + 1;
        }
      }
    } else {
      distanceRanged = false;
    }
  }
}

void main() {
  print(ParsedCoordinateData.random().toRawString());
}
