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
    bool arranged = false; // Whether someone has been resolved in for loop
    Person? arrangedPerson;
    for (var resolvingPerson in arrangeQuene) {
      var chosenSeat = resolvingPerson.resolve(room: room);
      if (chosenSeat == null) {
        print("${resolvingPerson.name} 暂时不想决定座位");
        continue;
      } else {
        print(
            "${resolvingPerson.name} 选定了座位：${chosenSeat.location.column}列 ${chosenSeat.location.row}排");
        resolvingPerson.resolved = true;
        chosenSeat.empty = false;
        chosenSeat.owner = resolvingPerson;
        arranged = true;
        arrangedPerson = resolvingPerson;
        break;
      }
    }
    // Clear Person Arranged
    if(arranged) {
      arrangeQuene.remove(arrangedPerson);
    }
    // Update all person & Redraw Heatmap
    room.heatmap.clear();
    for (var person in personList) {
      person.update(room: room);
      person.drawHeatmap(room: room);
    }
    // Finish Arrangement
    if(loopTimes >= 200) {
      print("循环次数过多，终止程序");
      break;
    }
    if(arrangeQuene.isEmpty) {
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

class Person {
  String name;
  Gender gender;
  bool resolved = false;
  List<Demand> demandList;
  late int nowDemand;
  int stress = 0;
  late Set<Seat> targetSet;
  Person({required this.name, required this.gender, required this.demandList});
  init({required Room room}) {
    targetSet = Set.from(room.seats);
    for (int i = 0; i < demandList.length; ++i) {
      var demand = demandList[i];
      demand.init(room: room);
      var coTarget = targetSet.intersection(demand.target); // 已有目标和需求目标的交集
      if(coTarget.isEmpty) {
        demand.feasibility = false;
      }
      else {
        demand.feasibility = true;
        nowDemand = i;
        targetSet = coTarget;
      }
    }
  }
  void drawHeatmap({required Room room}) {}
  void update({required Room room}) {
    targetSet = room.getEmptySeat(source: Set.from(room.seats));
    for (int i = 0; i < demandList.length; ++i) {
      var demand = demandList[i];
      demand.update(room: room);
      var coTarget = targetSet.intersection(demand.target); // 已有目标和需求目标的交集
      if(coTarget.isEmpty) {
        demand.feasibility = false;
      }
      else {
        demand.feasibility = true;
        nowDemand = i;
        targetSet = coTarget;
      }
    } 
  }
  Seat? resolve({required Room room}) {
    return room.chooseBestSeat(range: targetSet);
  }
  int getRankPoint() {
    return targetSet.length;
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
}

// 需求父抽象类
abstract class Demand {
  late bool feasibility;
  bool resolved = false;
  late Set<Seat> target;
  void init({required Room room});
  void update({required Room room});
  Seat? resolve({required Room room});
  void drawHeatmap({required Room room});
}

// 绝对需求
class AbsoluteDemand extends Demand {
  bool Function(Seat) filter;
  AbsoluteDemand({required this.filter});
  @override
  void init({required Room room}) {
    target = room.findSeat((Seat seat) => filter(seat));
    feasibility = target.isNotEmpty;
  }

  @override
  void update({required Room room}) {
    // TODO: implement update
  }
  @override
  Seat? resolve({required Room room}) {
    // TODO: implement resolve
  }
  @override
  void drawHeatmap({required Room room}) {
    // TODO: implement drawHeatmap
  }
}

class Room {
  List<Seat> seats;
  late Heatmap heatmap;
  Room({required this.seats}) {
    // 位置查重
    var locationSet = <(int, int)>{};
    for (var seat in seats) {
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
  // TODO
  Seat? chooseBestSeat(
      {required Set<Seat> range, int Function(Seat, Seat, Room)? getRankFunc}) {
    if (range.isEmpty) return null;
    List<Seat> targetList = List.from(seats);
    targetList.sort((Seat seat1, Seat seat2) {
      return (getRankFunc != null)
          ? getRankFunc(seat1, seat2, this)
          : (((heatmap[seat1] ?? 0) - (heatmap[seat2] ?? 0)) * 10000).toInt();
    });
    return targetList.first;
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
}

class Location {
  int row;
  int column;
  Location({required this.row, required this.column});
}
