import 'dart:io';

import 'package:chaos_system_core/chaos_system_core.dart';
import 'package:excel/excel.dart';
import 'package:test/test.dart';

import '../bin/chaos_system_core.dart';

var excelFile = "./template.xlsx";
var namelistFile = "./names.txt";

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
  var seats = <Seat>[]; // (col, row) (列，排)

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

  // Get Name List
  var nameRawList = File(namelistFile).readAsLinesSync();
  var names = <String>{};
  for (int i = 0; i < nameRawList.length; ++i) {
    var text = nameRawList[i].trim();
    if (text == "") {
      print("[提示] 姓名列表第${i + 1}行为空，可删除");
    }
    if (!names.add(text)) {
      print("[警告] 姓名列表第${i + 1}行为重复名字，可删除");
    }
  }
  // print("names:$names");

  // Calculate Names Length and Seats Number
  print('''共有${names.length}个人
''');

  if (names.length > availableSeatNumber) {
    print("[错误] 座位不够，还少${names.length - availableSeatNumber}个座位");
    return;
  } else if (names.length == availableSeatNumber) {
    print("[提示] 座位数量刚好够");
  } else if (names.length < availableSeatNumber) {
    print("[提示] 将空出${availableSeatNumber - names.length}个座位");
  }

  // Construct Person Object List
  var personList = <Person>[];
  for (var element in names) {
    personList.add(Person(name: element, gender: Gender.unknown, demandList: []));
  }
  chaosSystemCore(personList: personList, room: Room(seats: seats));
}

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
