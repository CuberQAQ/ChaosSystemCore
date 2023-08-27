import 'dart:ffi';
import 'dart:math' as math;

/// [seatChart] (col, row) (列，排)
void chaosSystemCore({required List<Person> personList, required Room room}) {
  for (var person in personList) {
    person.init(room: room);
  }
  List<Person> arrangeQuene = List.from(personList);
  var loopTimes = 0;
  while (true) {
    print("第${++loopTimes}次尝试找人安排座位");
    // Sort Quene (RankPoint from Small to Big)
    arrangeQuene.sort(
        (person1, person2) => person1.getRankPoint() - person2.getRankPoint());
    // Resolve one by one
    ArrangedInfo? arrangedInfo;
    for (var resolvingPerson in arrangeQuene) {
      var chosenSeat = resolvingPerson.resolve();
      if (chosenSeat == null) {
        print("${resolvingPerson.name} 暂时不想决定座位");
        continue;
      } else {
        print(
            "${resolvingPerson.name} 选定了座位：${chosenSeat.location.column}列 ${chosenSeat.location.row}排");
        resolvingPerson.resolved = true;
        chosenSeat.empty = false;
        chosenSeat.owner = resolvingPerson;
        arrangedInfo = ArrangedInfo(seat: chosenSeat, person: resolvingPerson);
        break;
      }
    }
    // If arranged success
    if (arrangedInfo != null) {
      // Clear Person Arranged
      arrangeQuene.remove(arrangedInfo.person);
      // Update all person & Redraw Heatmap
      room.heatmap.clear();
      for (var person in arrangeQuene) {
        person.update(arrangedInfo: arrangedInfo);
        person.drawHeatmap();
      }
      print("当前热图:${room.heatmap}");
    }
    // Finish Arrangement
    if (loopTimes >= 200) {
      print("循环次数过多，终止程序");
      break;
    }
    if (arrangeQuene.isEmpty) {
      print("座位编排完成，终止程序");
      break;
    }
  }
}

enum Gender {
  girl,
  boy,
  unknown,
  neutral,
  transgender,
}

class ArrangedInfo {
  Seat seat;
  Person person;
  ArrangedInfo({required this.seat, required this.person});
}

class Person {
  String name;
  Gender gender;
  bool resolved = false;
  List<Demand> demandList;
  late Room room;
  int? nowDemand;
  int stress = 0;
  late Set<Seat> targetSet;
  Person({required this.name, required this.gender, required this.demandList});
  init({required Room room}) {
    this.room = room;
    targetSet = room.getEmptySeat(source: Set.from(room.seats));
    for (var demand in demandList) {
      demand.init(room: room, demander: this);
    }
    update();
  }

  void drawHeatmap() {
    //TODO
    if (targetSet.isEmpty) return;
    for (var seat in targetSet) {
      if (room.heatmap[seat] == null) continue;
      room.heatmap[seat] = room.heatmap[seat]! + 1 / targetSet.length;
    }
  }

  void update({ArrangedInfo? arrangedInfo}) {
    nowDemand = null;

    targetSet = room.getEmptySeat(source: Set.from(room.seats));
    for (int i = 0; i < demandList.length; ++i) {
      var demand = demandList[i];
      demand.update(arrangedInfo: arrangedInfo);
      var coTarget = targetSet.intersection(demand.target); // 已有目标和需求目标的交集
      if (coTarget.isNotEmpty) {
        nowDemand = i;
        targetSet = coTarget;
      }
    }
  }

  Seat? resolve() {
    var finalSeat = room.chooseBestSeat(range: targetSet);
    for (var demand in demandList) {
      if (demand.target.contains(finalSeat)) {
        print("[提示]$name的需求$demand已被满足");
      } else {
        print("[提示]$name的需求$demand未被满足");
      }
    }
    return finalSeat;
  }

  int getRankPoint() {
    return targetSet.length;
  }

  @override
  String toString() {
    return name;
  }
}

class Heatmap {
  Map<Seat, num> data;
  Heatmap({required Set<Seat> seats, num initValue = 0}) : data = {} {
    for (var seat in seats) {
      data[seat] = initValue;
    }
  }
  clear({num newValue = 0}) {
    data.forEach((key, value) {
      data[key] = newValue;
    });
  }

  num? operator [](Seat seat) => data[seat];
  void operator []=(Seat seat, num newHeat) => data[seat] = newHeat;
  num? getHeat(Seat seat) => data[seat];
  @override
  String toString() {
    var str = "";
    data.forEach((key, value) {
      if (value != 0) str += "[$key:$value]\n";
    });
    return str;
  }
}

// 需求父抽象类
abstract class Demand {
  late bool closed;
  late Person demander;
  late Room room;
  bool resolved = false;
  late Set<Seat> target;
  void init({required Room room, required Person demander});
  void update({ArrangedInfo? arrangedInfo});
  Seat? resolve();
  void drawHeatmap();
}

// 绝对需求
class AbsoluteDemand extends Demand {
  bool Function(Seat, Room) filter;
  AbsoluteDemand({required this.filter});
  @override
  void init({required Room room, required Person demander}) {
    this.room = room;
    this.demander = demander;
    update();
  }

  @override
  void update({ArrangedInfo? arrangedInfo}) {
    target = room.findSeat((Seat seat) => filter(seat, room));
  }

  @override
  Seat? resolve() {}
  @override
  void drawHeatmap() {}
}

class Room {
  List<Seat> seats;
  late Heatmap heatmap;
  int maxCols = 0;
  int maxRows = 0;
  Room({required this.seats}) {
    // 位置查重 & 最大行列
    var locationSet = <(int, int)>{};
    for (var seat in seats) {
      if (maxRows < seat.location.row) maxRows = seat.location.row;
      if (maxCols < seat.location.column) maxRows = seat.location.column;
      if (!locationSet.add((seat.location.row, seat.location.column))) {
        throw Exception("给定的seats中存在位置重复");
      }
    }
    // 初始化热图
    heatmap = Heatmap(seats: Set.from(seats));
  }
  Seat? getSeatByLocation({required int row, required int column}) {
    for (var seat in seats) {
      if (seat.location.row == row && seat.location.column == column) {
        return seat;
      }
    }
    return null;
  }

  /// Returns a list containing target seats (May be empty).
  Set<Seat> findSeat(bool Function(Seat) filter) {
    var targetList = <Seat>{};
    for (var seat in seats) {
      if (filter(seat)) targetList.add(seat);
    }
    return targetList;
  }

  Set<Seat> getEmptySeat({required Set<Seat> source}) {
    source.removeWhere((Seat element) => !element.empty);
    return source;
  }

  // rank越小越容易被抽中
  Seat? chooseBestSeat(
      {required Set<Seat> range, int Function(Seat, Room)? getRankFunc}) {
    if (range.isEmpty) return null;
    List<Seat> targetList = List.from(range);

    targetList.sort((Seat seat1, Seat seat2) {
      return (getRankFunc != null)
          ? (getRankFunc(seat1, this) - getRankFunc(seat2, this))
          : (((heatmap[seat1] ?? 0) - (heatmap[seat2] ?? 0)) * 10000).toInt();
    });

    Map<int, List<Seat>> map = {};
    Set<int> mapKeys = {};
    for (var seat in range) {
      int rank = getRankFunc != null
          ? getRankFunc(seat, this)
          : ((heatmap[seat] ?? 0) * 10000).toInt();
      if (mapKeys.add(rank)) {
        map[rank] = [seat];
      } else {
        map[rank]!.add(seat);
      }
    }
    List<int> sortedMapKeys = List<int>.from(mapKeys);
    sortedMapKeys.sort((rank1, rank2) => rank1 - rank2);
    var smallRange = map[sortedMapKeys.first]!;
    return smallRange[math.Random.secure().nextInt(smallRange.length)];
  }

  num getEuclideanDistance(Seat seat1, Seat seat2) {
    return math.sqrt(math.pow(seat1.location.row - seat2.location.row, 2) +
        math.pow(seat1.location.column - seat2.location.column, 2));
  }

  num getManhattanDistance(Seat seat1, Seat seat2) {
    return (seat1.location.row - seat2.location.row).abs() +
        (seat1.location.column - seat2.location.column).abs();
  }
}

class Seat {
  Location location;
  bool nullable;
  bool empty;
  Person? owner;
  Seat(
      {required this.location,
      required this.nullable,
      this.owner,
      required this.empty});
  @override
  String toString() {
    return "[${owner ?? "空座位"}:(${location.column},${location.row})]";
  }
}

class Location {
  int row;
  int column;
  Location({required this.row, required this.column});
}
