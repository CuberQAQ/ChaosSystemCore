import '../bin/chaos_system_core.dart';
import 'dart:convert';

void main() {
  var result = parseDataStr("(1~-2,)~3");
  print(result);
  List<Seat> seats = [];
  for(var col = 1; i < 8)
  Room(seats: );
  parseAbsoluteData(json.decode('{ "type": "absolute", "data": ["(,2~)"] }'))
      .filter(Seat(
          location: Location(row: 2, column: 3), nullable: false, empty: true));
}

/// str: (-3~,1~4)3 之类
ParsedAbsoluteData? parseDataStr(String str) {
  str = str.replaceAll(' ', '');
  var regExp = RegExp(
      r'^\((?<columnBegin>-?[0-9]+)?(?<columnRanged>~)?(?<columnEnd>-?[0-9]+)?,(?<rowBegin>-?[0-9]+)?(?<rowRanged>~)?(?<rowEnd>-?[0-9]+)?\)(?<distanceBegin>-?[0-9]+)?(?<distanceRanged>~)?(?<distanceEnd>-?[0-9]+)?$');
  if (!regExp.hasMatch(str)) return null;
  var match = regExp.allMatches(str).first;
  ParsedAbsoluteData result = ParsedAbsoluteData();
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

class ParsedAbsoluteData {
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
}

AbsoluteDemand parseAbsoluteData(dynamic demandRaw) {
  return AbsoluteDemand(filter: (seat, room) {
    for (String absoluteDataRaw in demandRaw.data) {
      bool result = true;
      ParsedAbsoluteData? parsedAbsoluteData = parseDataStr(absoluteDataRaw);
      if (parsedAbsoluteData == null) {
        print('不符合要求的Absolute Data: "$absoluteDataRaw" in $demandRaw');
        continue;
      }
      if (parsedAbsoluteData.distanceDemanded) {
        // With Distance Demanded
        // TODO
        print("还不支持Distanced Data");
      } else {
        // Without Distance Demanded
        if (parsedAbsoluteData.columnDemanded) {
          if (parsedAbsoluteData.columnRanged) {
            // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
            if (parsedAbsoluteData.columnBegin != null &&
                parsedAbsoluteData.columnBegin! < 0) {
              parsedAbsoluteData.columnBegin =
                  (parsedAbsoluteData.columnBegin ?? 0) + room.maxCols + 1;
            }
            if (parsedAbsoluteData.columnEnd != null &&
                parsedAbsoluteData.columnEnd! < 0) {
              parsedAbsoluteData.columnEnd =
                  (parsedAbsoluteData.columnEnd ?? 0) + room.maxCols + 1;
            }
            // 检查是否在范围内
            if (parsedAbsoluteData.columnBegin != null &&
                seat.location.column < parsedAbsoluteData.columnBegin!) {
              result = false;
            }
            if (parsedAbsoluteData.columnEnd != null &&
                seat.location.column > parsedAbsoluteData.columnEnd!) {
              result = false;
            }
          } else {
            // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
            if (parsedAbsoluteData.columnBegin != null &&
                parsedAbsoluteData.columnBegin! < 0) {
              parsedAbsoluteData.columnBegin =
                  (parsedAbsoluteData.columnBegin ?? 0) + room.maxCols + 1;
            }
            if (seat.location.column != parsedAbsoluteData.columnBegin) {
              result = false;
            }
          }
        }
        if (parsedAbsoluteData.rowDemanded) {
          if (parsedAbsoluteData.rowRanged) {
            // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
            if (parsedAbsoluteData.rowBegin != null &&
                parsedAbsoluteData.rowBegin! < 0) {
              parsedAbsoluteData.rowBegin =
                  (parsedAbsoluteData.rowBegin ?? 0) + room.maxRows + 1;
            }
            if (parsedAbsoluteData.rowEnd != null &&
                parsedAbsoluteData.rowEnd! < 0) {
              parsedAbsoluteData.rowEnd =
                  (parsedAbsoluteData.rowEnd ?? 0) + room.maxRows + 1;
            }
            // 检查是否在范围内
            if (parsedAbsoluteData.rowBegin != null &&
                seat.location.row < parsedAbsoluteData.rowBegin!) {
              result = false;
            }
            if (parsedAbsoluteData.rowEnd != null &&
                seat.location.row > parsedAbsoluteData.rowEnd!) {
              result = false;
            }
          } else {
            // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
            if (parsedAbsoluteData.rowBegin != null &&
                parsedAbsoluteData.rowBegin! < 0) {
              parsedAbsoluteData.rowBegin =
                  (parsedAbsoluteData.rowBegin ?? 0) + room.maxRows + 1;
            }
            if (seat.location.row != parsedAbsoluteData.rowBegin) {
              result = false;
            }
          }
        }
      }
      if (result == true) return true;
    }
    return false;
  });
}
