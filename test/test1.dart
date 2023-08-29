import 'dart:math';

/// str: (-3~,1~4)3 之类
ParsedCoordinateData? parseDataStr(String str) {
  // 添加了对输入字符串的有效性检查，如果不符合格式要求，返回null
  if (!str.startsWith('(') || !str.endsWith(')')) return null;
  str = str.substring(1, str.length - 1); // 去掉括号
  var parts = str.split(','); // 按逗号分割
  if (parts.length != 2) return null; // 如果不是两个部分，返回null
  var columnStr = parts[0]; // 列的字符串
  var rowStr = parts[1]; // 行的字符串
  ParsedCoordinateData result = ParsedCoordinateData();
  // 解析列的范围，如果有错误，返回null
  if (!parseRange(columnStr, result, true)) return null;
  // 解析行的范围，如果有错误，返回null
  if (!parseRange(rowStr, result, false)) return null;
  // 对解析出来的坐标范围进行合理性检查，如果有负数或超出网格范围，返回null
  if (!checkRange(result)) return null;
  // 对解析出来的坐标范围进行优化或简化，去掉重复或冗余的信息
  simplifyRange(result);
  return result;
}

// 解析一个表示范围的字符串，例如"2~3"或"5"，并将其赋值给ParsedCoordinateData对象的相应属性
// isColumn表示是否是列的范围，否则是行的范围
// 返回值表示是否解析成功
bool parseRange(String str, ParsedCoordinateData data, bool isColumn) {
  var parts = str.split('~'); // 按波浪线分割
  if (parts.length > 2) return false; // 如果超过两个部分，解析失败
  var begin = num.tryParse(parts[0]); // 起始值
  var end = num.tryParse(parts[1]); // 结束值
  if (isColumn) {
    data.columnBegin = begin;
    data.columnEnd = end;
    data.columnRanged = parts.length == 2; // 如果有波浪线，表示范围是不确定的
    data.columnDemanded = begin != null || end != null; // 如果有起始值或结束值，表示范围是有意义的
  } else {
    data.rowBegin = begin;
    data.rowEnd = end;
    data.rowRanged = parts.length == 2; // 如果有波浪线，表示范围是不确定的
    data.rowDemanded = begin != null || end != null; // 如果有起始值或结束值，表示范围是有意义的
  }
  return true; // 解析成功
}

// 对解析出来的坐标范围进行合理性检查，如果有负数或超出网格范围，返回false
// 这里假设网格的最大列数和行数都是6，可以根据实际情况修改
bool checkRange(ParsedCoordinateData data) {
  if (data.columnDemanded) {
    if (data.columnBegin != null &&
        (data.columnBegin! < 1 || data.columnBegin! > 6))
      return false; // 起始列不能小于1或大于6
    if (data.columnEnd != null && (data.columnEnd! < 1 || data.columnEnd! > 6))
      return false; // 结束列不能小于1或大于6
    if (data.columnBegin != null &&
        data.columnEnd != null &&
        data.columnBegin! > data.columnEnd!) return false; // 起始列不能大于结束列
  }
  if (data.rowDemanded) {
    if (data.rowBegin != null && (data.rowBegin! < 1 || data.rowBegin! > 6))
      return false; // 起始行不能小于1或大于6
    if (data.rowEnd != null && (data.rowEnd! < 1 || data.rowEnd! > 6))
      return false; // 结束行不能小于1或大于6
    if (data.rowBegin != null &&
        data.rowEnd != null &&
        data.rowBegin! > data.rowEnd!) return false; // 起始行不能大于结束行
  }
  return true; // 检查通过
}

// 对解析出来的坐标范围进行优化或简化，去掉重复或冗余的信息
void simplifyRange(ParsedCoordinateData data) {
  if (data.columnDemanded) {
    if (data.columnRanged) {
      if (data.columnBegin == null && data.columnEnd == null) {
        // 如果范围是(~)，表示任意列，可以去掉
        data.columnDemanded = false;
      } else if (data.columnBegin == 1 && data.columnEnd == null) {
        // 如果范围是(1~)，表示从第一列开始，可以去掉波浪线
        data.columnRanged = false;
      } else if (data.columnBegin == null && data.columnEnd == 6) {
        // 如果范围是(~6)，表示到第六列结束，可以去掉波浪线
        data.columnRanged = false;
      }
    } else {
      if (data.columnBegin == null) {
        // 如果范围是(,)，表示任意列，可以去掉
        data.columnDemanded = false;
      }
    }
  }
  if (data.rowDemanded) {
    if (data.rowRanged) {
      if (data.rowBegin == null && data.rowEnd == null) {
        // 如果范围是(~)，表示任意行，可以去掉
        data.rowDemanded = false;
      } else if (data.rowBegin == 1 && data.rowEnd == null) {
        // 如果范围是(1~)，表示从第一行开始，可以去掉波浪线
        data.rowRanged = false;
      } else if (data.rowBegin == null && data.rowEnd == 6) {
        // 如果范围是(~6)，表示到第六行结束，可以去掉波浪线
        data.rowRanged = false;
      }
    } else {
      if (data.rowBegin == null) {
        // 如果范围是(,)，表示任意行，可以去掉
        data.rowDemanded = false;
      }
    }
  }
}

class ParsedCoordinateData {
  num? columnBegin;
  num? columnEnd;
  num? rowBegin;
  num? rowEnd;
  late bool columnRanged;
  late bool rowRanged;
  late bool columnDemanded;
  late bool rowDemanded;

  @override
  String toString() {
    return "{columnDemanded: $columnDemanded, columnBegin: $columnBegin, columnRanged: $columnRanged, columnEnd: $columnEnd, rowDemanded: $rowDemanded, rowBegin: $rowBegin, rowRanged: $rowRanged, rowEnd: $rowEnd}";
  }

  String toRawString() {
    return "(${columnBegin ?? ''}${columnRanged ? '~' : ''}${columnRanged ? (columnEnd ?? '') : ''},${rowBegin ?? ''}${rowRanged ? '~' : ''}${rowRanged ? (rowEnd ?? '') : ''})";
  }

  ParsedCoordinateData();
  ParsedCoordinateData.random() {
    columnDemanded = Random().nextBool();
    rowDemanded = Random().nextBool();
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
  }
}

void main() {
  var range = (parseDataStr("(~3,~)")!);
  simplifyRange(range);
  print(range.toRawString());
}
