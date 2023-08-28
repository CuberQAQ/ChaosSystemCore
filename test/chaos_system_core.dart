import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import '../bin/chaos_system_core.dart';

var excelFile = "./template.xlsx";
var namelistFile = "./names.txt";
var personJsonFile = "./person.json";
var outputFile = "./result.xlsx";
var logFile = "./out.log";

class ExcelSeat extends Seat {
  String excelPostion;
  ExcelSeat(
      {required super.location,
      required super.empty,
      required super.nullable,
      super.owner,
      required this.excelPostion});
}

void main() {
  var bytes = File(excelFile).readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  var sheetName =
      excel.sheets.keys.first; // Only load the first sheet of the xlsx file
  var sheetObj = excel[sheetName];

  print('''当前工作表：$sheetName
工作表最大列数：${sheetObj.maxCols}
工作表最大行数：${sheetObj.maxRows}
''');
  // Search for all cells with available seat
  var availableColsIndexesSet = <int>{};
  var availableRowsIndexesSet = <int>{};
  var availableSeatNumber = 0;
  var nullableSeatNumber = 0;
  // Record all the rows in excel with available seat
  for (var row in sheetObj.rows) {
    for (var cell in row) {
      if (cell == null) continue;
      if (isAvailableCell(cell)) {
        availableRowsIndexesSet.add(cell.rowIndex);
        availableColsIndexesSet.add(cell.colIndex);
        ++availableSeatNumber;
        if (isNullableSeat(cell)) ++nullableSeatNumber;
        // print("[$availableSeatNumber] availableCell: Row=${cell.rowIndex} Col=${cell.colIndex}");
      }
    }
  }

  var availableColsIndexesList = availableColsIndexesSet.toList();
  var availableRowsIndexesList = availableRowsIndexesSet.toList();
  availableColsIndexesList.sort((a, b) => a - b);
  availableRowsIndexesList.sort((a, b) => a - b);
  // print("availableColsIndexes = $availableColsIndexesList");
  // print("availableRowsIndexes = $availableRowsIndexesList");
  var seats = <ExcelSeat>[]; // (col, row) (列，排)

  for (int factColIndex = 1;
      factColIndex <= availableColsIndexesList.length;
      ++factColIndex) {
    for (int factRowIndex = 1;
        factRowIndex <= availableRowsIndexesList.length;
        ++factRowIndex) {
      var cell = sheetObj.rows[availableRowsIndexesList[factRowIndex - 1]]
          [availableColsIndexesList[factColIndex - 1]];
      // print("now: row=$factRowIndex col=$factColIndex");
      if (cell == null || !isAvailableCell(cell)) {
      } else {
        seats.add(ExcelSeat(
            location: Location(row: factRowIndex, column: factColIndex),
            nullable: isNullableSeat(cell),
            empty: true,
            excelPostion: cell.cellIndex.cellId));
      }
    }
  }

  // Load Name

  // //loop print test
  // for (var i = 0; i < seats.length; ++i) {
  //   print("Column ${i + 1}:");
  //   for (var j = 0; j < seats[i].length; ++j) {
  //     print("[${j + 1}]:${seats[i][j].toString()}");
  //   }
  // }

  print('''共检测到$availableSeatNumber个座位，其中$nullableSeatNumber个座位可选
''');

  // // Get Name List
  // var nameRawList = File(namelistFile).readAsLinesSync();
  // var names = <String>{};
  // for (int i = 0; i < nameRawList.length; ++i) {
  //   var text = nameRawList[i].trim();
  //   if (text == "") {
  //     print("[提示] 姓名列表第${i + 1}行为空，可删除");
  //   }
  //   if (!names.add(text)) {
  //     print("[警告] 姓名列表第${i + 1}行为重复名字，可删除");
  //   }
  // }
  // // print("names:$names");

  var personRawList = json.decode(File(personJsonFile).readAsStringSync());
  // print(personRawList);
  // Calculate Names Length and Seats Number
  print('''共有${personRawList.length}个人
''');

  if (personRawList.length > availableSeatNumber) {
    print("[错误] 座位不够，还少${personRawList.length - availableSeatNumber}个座位");
    return;
  } else if (personRawList.length == availableSeatNumber) {
    print("[提示] 座位数量刚好够");
  } else if (personRawList.length < availableSeatNumber) {
    print("[提示] 将空出${availableSeatNumber - personRawList.length}个座位");
  }

  // Construct Person Object List
  var personList = <Person>[];
  for (var personRawObj in personRawList) {
    // print(
    // "personRawObjType: ${personRawObj.runtimeType} personRawObj:$personRawObj");
    personList.add(parsePersonObj(personRawObj)!);
  }

  // TODO test
  AbsoluteDemand testDemand = personList
      .firstWhere((element) => element.name == "秦浩朗")
      .demandList
      .first as AbsoluteDemand;
  print(testDemand.filter(
      Seat(location: Location(column: 3, row: 1), nullable: false, empty: true),
      Room(seats: seats)));

  String log = '';
  var chaosSystemCore = ChaosSystemCore(
      personList: personList,
      room: Room(seats: seats),
      logger: (str) {
        log += str;
        log += '\n';
      });
  chaosSystemCore.arrange();
  File(logFile).writeAsStringSync(log);
  // Write Result
  File(excelFile).copySync(outputFile);
  for (var seat in seats) {
    sheetObj.updateCell(
        CellIndex.indexByString(seat.excelPostion), seat.owner ?? "empty");
  }
  File(outputFile).writeAsBytesSync(excel.encode()!);
  print("排座完成！");
} // main

bool isAvailableCell(Data? cell) {
  if (cell == null) return false;
  if (cell.value.toString().trim() == r"$$$" ||
      cell.value.toString().trim() == "???") {
    return true;
  } else {
    return false;
  }
}

bool isNullableSeat(Data? cell) {
  if (cell == null) return false;
  if (cell.value.toString().trim() == "???") return true;
  return false;
}

Person? parsePersonObj(dynamic personRawObj) {
  // Parse Gender
  var genderRaw = personRawObj["gender"];
  var genderParsed = Gender.unknown;
  for (var gender in Gender.values) {
    if (gender.toString() == genderRaw) {
      genderParsed = gender;
    }
  }

  // Parse Demand List
  var demandList = <Demand>[];
  for (var demandRaw in personRawObj["demands"]) {
    switch (demandRaw["type"]) {
      case "absolute":
        demandList.add(AbsoluteDemand(filter: (seat, room) {
          for (String absoluteDataRaw in demandRaw["data"]) {
            bool result = true;
            ParsedCoordinateData? parsedCoordinateData =
                parseDataStr(absoluteDataRaw);
            if (parsedCoordinateData == null) {
              print('不符合要求的Absolute Data: "$absoluteDataRaw" in $demandRaw');
              continue;
            }
            // 转换列要求值 Analyse Column Demand
            if (parsedCoordinateData.columnDemanded) {
              if (parsedCoordinateData.columnRanged) {
                // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
                if (parsedCoordinateData.columnBegin != null &&
                    parsedCoordinateData.columnBegin! < 0) {
                  parsedCoordinateData.columnBegin =
                      (parsedCoordinateData.columnBegin ?? 0) +
                          room.maxCols +
                          1;
                }
                if (parsedCoordinateData.columnEnd != null &&
                    parsedCoordinateData.columnEnd! < 0) {
                  parsedCoordinateData.columnEnd =
                      (parsedCoordinateData.columnEnd ?? 0) + room.maxCols + 1;
                }
              } else {
                // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
                if (parsedCoordinateData.columnBegin != null &&
                    parsedCoordinateData.columnBegin! < 0) {
                  parsedCoordinateData.columnBegin =
                      (parsedCoordinateData.columnBegin ?? 0) +
                          room.maxCols +
                          1;
                }
              }
            }

            // 转换行要求值 Analyse Row Demand
            if (parsedCoordinateData.rowDemanded) {
              if (parsedCoordinateData.rowRanged) {
                // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
                if (parsedCoordinateData.rowBegin != null &&
                    parsedCoordinateData.rowBegin! < 0) {
                  parsedCoordinateData.rowBegin =
                      (parsedCoordinateData.rowBegin ?? 0) + room.maxRows + 1;
                }
                if (parsedCoordinateData.rowEnd != null &&
                    parsedCoordinateData.rowEnd! < 0) {
                  parsedCoordinateData.rowEnd =
                      (parsedCoordinateData.rowEnd ?? 0) + room.maxRows + 1;
                }
              } else {
                // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
                if (parsedCoordinateData.rowBegin != null &&
                    parsedCoordinateData.rowBegin! < 0) {
                  parsedCoordinateData.rowBegin =
                      (parsedCoordinateData.rowBegin ?? 0) + room.maxRows + 1;
                }
              }
            }

            // 转换距离要求值 & 做出判断  Analyse Distance Demand & Make Judgment
            if (parsedCoordinateData.distanceDemanded) {
              // With Distance Demanded
              // TODO
              var exactDistance = getMinDistance(
                      area: room.findSeat((seat) {
                        if (parsedCoordinateData.columnDemanded) {
                          if (parsedCoordinateData.columnRanged) {
                            // 检查是否在范围内
                            if (parsedCoordinateData.columnBegin != null &&
                                seat.location.column <
                                    parsedCoordinateData.columnBegin!) {
                              return false;
                            }
                            if (parsedCoordinateData.columnEnd != null &&
                                seat.location.column >
                                    parsedCoordinateData.columnEnd!) {
                              return false;
                            }
                          } else {
                            if (seat.location.column !=
                                parsedCoordinateData.columnBegin) {
                              return false;
                            }
                          }
                        }
                        if (parsedCoordinateData.rowDemanded) {
                          if (parsedCoordinateData.rowRanged) {
                            // 检查是否在范围内
                            if (parsedCoordinateData.rowBegin != null &&
                                seat.location.row <
                                    parsedCoordinateData.rowBegin!) {
                              return false;
                            }
                            if (parsedCoordinateData.rowEnd != null &&
                                seat.location.row >
                                    parsedCoordinateData.rowEnd!) {
                              return false;
                            }
                          } else {
                            if (seat.location.row !=
                                parsedCoordinateData.rowBegin) {
                              return false;
                            }
                          }
                        }
                        return true;
                      }),
                      target: seat) ??
                  1; // TODO ??1 null????
              if (parsedCoordinateData.distanceRanged) {
                if (parsedCoordinateData.distanceBegin != null &&
                    exactDistance < parsedCoordinateData.distanceBegin!) {
                  result = false;
                }
                if (parsedCoordinateData.distanceEnd != null &&
                    exactDistance > parsedCoordinateData.distanceEnd!) {
                  result = false;
                }
              } else {
                if (parsedCoordinateData.distanceBegin != null &&
                    exactDistance != parsedCoordinateData.distanceBegin!) {
                  result = false;
                }
              }
            } else {
              // Without Distance Demanded
              if (parsedCoordinateData.columnDemanded) {
                if (parsedCoordinateData.columnRanged) {
                  // 检查是否在范围内
                  if (parsedCoordinateData.columnBegin != null &&
                      seat.location.column <
                          parsedCoordinateData.columnBegin!) {
                    result = false;
                  }
                  if (parsedCoordinateData.columnEnd != null &&
                      seat.location.column > parsedCoordinateData.columnEnd!) {
                    result = false;
                  }
                } else {
                  if (seat.location.column !=
                      parsedCoordinateData.columnBegin) {
                    result = false;
                  }
                }
              }
              if (parsedCoordinateData.rowDemanded) {
                if (parsedCoordinateData.rowRanged) {
                  // 检查是否在范围内
                  if (parsedCoordinateData.rowBegin != null &&
                      seat.location.row < parsedCoordinateData.rowBegin!) {
                    result = false;
                  }
                  if (parsedCoordinateData.rowEnd != null &&
                      seat.location.row > parsedCoordinateData.rowEnd!) {
                    result = false;
                  }
                } else {
                  if (seat.location.row != parsedCoordinateData.rowBegin) {
                    result = false;
                  }
                }
              }
            }
            if (result == true) return true;
          }
          return false;
        }));
        break;
      case "relative":
        demandList.add(RelativeDemandWithSemiConfirm(
          relativePersonName: demandRaw["target"],
          filter: (
              {required Seat filteringSeat,
              required Seat relativeSeat,
              required Room room}) {
            for (String relativeDataRaw in demandRaw["data"]) {
              bool result = true;
              ParsedCoordinateData? parsedCoordinateData =
                  parseDataStr(relativeDataRaw);
              if (parsedCoordinateData == null) {
                print('不符合要求的Relative Data: "$relativeDataRaw" in $demandRaw');
                continue;
              }

              // 转换列要求值 Analyse Column Demand
              if (parsedCoordinateData.columnDemanded) {
                if (parsedCoordinateData.columnRanged) {
                  // 将相对描述转为绝对描述 比如相对于 (2,3) 的 (-1,2) 将变为 (1,5)
                  if (parsedCoordinateData.columnBegin != null) {
                    parsedCoordinateData.columnBegin =
                        (parsedCoordinateData.columnBegin ?? 0) +
                            relativeSeat.location.column;
                  }
                  if (parsedCoordinateData.columnEnd != null) {
                    parsedCoordinateData.columnEnd =
                        (parsedCoordinateData.columnEnd ?? 0) +
                            relativeSeat.location.column;
                  }
                } else {
                  // 将相对描述转为绝对描述 比如相对于 (2,3) 的 (-1,2) 将变为 (1,5)
                  if (parsedCoordinateData.columnBegin != null) {
                    parsedCoordinateData.columnBegin =
                        (parsedCoordinateData.columnBegin ?? 0) +
                            relativeSeat.location.column;
                  }
                }
              }

              // 转换行要求值 Analyse Row Demand
              if (parsedCoordinateData.rowDemanded) {
                if (parsedCoordinateData.rowRanged) {
                  // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
                  if (parsedCoordinateData.rowBegin != null) {
                    parsedCoordinateData.rowBegin =
                        (parsedCoordinateData.rowBegin ?? 0) +
                            relativeSeat.location.row;
                  }
                  if (parsedCoordinateData.rowEnd != null) {
                    parsedCoordinateData.rowEnd =
                        (parsedCoordinateData.rowEnd ?? 0) +
                            relativeSeat.location.row;
                  }
                } else {
                  // 将倒数描述转为正数描述 比如共8排 -1排变为第8排
                  if (parsedCoordinateData.rowBegin != null) {
                    parsedCoordinateData.rowBegin =
                        (parsedCoordinateData.rowBegin ?? 0) +
                            relativeSeat.location.row;
                  }
                }
              }

              // 转换距离要求值 & 做出判断  Analyse Distance Demand & Make Judgment
              if (parsedCoordinateData.distanceDemanded) {
                // With Distance Demanded
                // TODO
                // TODO
                var exactDistance = getMinDistance(
                        area: room.findSeat((seat) {
                          if (parsedCoordinateData.columnDemanded) {
                            if (parsedCoordinateData.columnRanged) {
                              // 检查是否在范围内
                              if (parsedCoordinateData.columnBegin != null &&
                                  seat.location.column <
                                      parsedCoordinateData.columnBegin!) {
                                return false;
                              }
                              if (parsedCoordinateData.columnEnd != null &&
                                  seat.location.column >
                                      parsedCoordinateData.columnEnd!) {
                                return false;
                              }
                            } else {
                              if (seat.location.column !=
                                  parsedCoordinateData.columnBegin) {
                                return false;
                              }
                            }
                          }
                          if (parsedCoordinateData.rowDemanded) {
                            if (parsedCoordinateData.rowRanged) {
                              // 检查是否在范围内
                              if (parsedCoordinateData.rowBegin != null &&
                                  seat.location.row <
                                      parsedCoordinateData.rowBegin!) {
                                return false;
                              }
                              if (parsedCoordinateData.rowEnd != null &&
                                  seat.location.row >
                                      parsedCoordinateData.rowEnd!) {
                                return false;
                              }
                            } else {
                              if (seat.location.row !=
                                  parsedCoordinateData.rowBegin) {
                                return false;
                              }
                            }
                          }
                          return true;
                        }),
                        target: filteringSeat) ??
                    0; // TODO ??0
                if (parsedCoordinateData.distanceRanged) {
                  if (parsedCoordinateData.distanceBegin != null &&
                      exactDistance < parsedCoordinateData.distanceBegin!) {
                    result = false;
                  }
                  if (parsedCoordinateData.distanceEnd != null &&
                      exactDistance > parsedCoordinateData.distanceEnd!) {
                    result = false;
                  }
                } else {
                  if (parsedCoordinateData.distanceBegin != null &&
                      exactDistance != parsedCoordinateData.distanceBegin!) {
                    result = false;
                  }
                }
              } else {
                // Without Distance Demanded
                if (parsedCoordinateData.columnDemanded) {
                  if (parsedCoordinateData.columnRanged) {
                    // 检查是否在范围内
                    if (parsedCoordinateData.columnBegin != null &&
                        filteringSeat.location.column <
                            parsedCoordinateData.columnBegin!) {
                      result = false;
                    }
                    if (parsedCoordinateData.columnEnd != null &&
                        filteringSeat.location.column >
                            parsedCoordinateData.columnEnd!) {
                      result = false;
                    }
                  } else {
                    if (filteringSeat.location.column !=
                        parsedCoordinateData.columnBegin) {
                      result = false;
                    }
                  }
                }
                if (parsedCoordinateData.rowDemanded) {
                  if (parsedCoordinateData.rowRanged) {
                    // 检查是否在范围内
                    if (parsedCoordinateData.rowBegin != null &&
                        filteringSeat.location.row <
                            parsedCoordinateData.rowBegin!) {
                      result = false;
                    }
                    if (parsedCoordinateData.rowEnd != null &&
                        filteringSeat.location.row >
                            parsedCoordinateData.rowEnd!) {
                      result = false;
                    }
                  } else {
                    if (filteringSeat.location.row !=
                        parsedCoordinateData.rowBegin) {
                      result = false;
                    }
                  }
                }
              }
              if (result == true) return true;
            }
            return false;
          },
        ));
        break;
      default:
        print("Unknown Demand Type in $demandRaw");
    }
  }

  return Person(
      name: personRawObj["name"], gender: genderParsed, demandList: demandList);
}

num? getMinDistance({required Set<Seat> area, required Seat target}) {
  if (area.isEmpty) return null;
  num minDistance = -1;
  for (var areaMember in area) {
    var distance = Room.getEuclideanDistance(areaMember, target);
    if (minDistance == -1 || distance < minDistance) minDistance = distance;
  }
  return minDistance == -1 ? null : minDistance;
}

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
}
