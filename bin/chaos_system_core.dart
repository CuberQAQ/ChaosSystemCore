import 'dart:math' as math;

const maxUpdateLoopTimes = 10;
const maxStress = 5; // TODO

// ChaosSystemCore类是一个用于安排人员座位的系统
class ChaosSystemCore {
  // personList属性是一个包含所有参与人员的列表
  List<Person> personList;
  // room属性是一个表示房间的对象
  Room room;
  // logger属性是一个用于打印日志信息的函数，默认为print
  void Function(String) logger;
  // ChaosSystemCore类的构造函数，接受personList, room, logger作为参数
  ChaosSystemCore(
      {required this.personList, required this.room, this.logger = print});
  // arrange方法是系统的主要方法，它负责初始化人员，更新人员的需求和目标，排序人员的优先级，绘制热图，解决冲突，判断座位是否满足需求等
  void arrange() {
    // Init All Person
    logger("[提示]初始化...");
    for (var person in personList) {
      person.init(room: room, core: this);
    }
    // Update All Person
    for (int times = 1; times <= maxUpdateLoopTimes; ++times) {
      bool dirty = false;
      logger("[提示]第$times次update所有人");
      for (var person in personList) {
        if (person.update() == true) dirty = true;
      }
      if (times == maxUpdateLoopTimes) {
        logger("[错误]update次数超过最大深度，终止update");
      }
      if (!dirty) break;
    }
    List<Person> arrangeQuene = List.from(personList);
    var loopTimes = 0;
    while (true) {
      logger("第${++loopTimes}次尝试找人安排座位");
      // Sort Quene (RankPoint from Small to Big)
      arrangeQuene.sort((person1, person2) =>
          person1.getRankPoint() - person2.getRankPoint());
      // Redraw Heatmap
      room.heatmap.clear();
      for (var person in arrangeQuene) {
        person.drawHeatmap();
      }
      logger("当前热图:\n${room.heatmap}");
      // Resolve one by one
      ArrangedInfo? arrangedInfo;
      for (var resolvingPerson in arrangeQuene) {
        var chosenSeat = resolvingPerson.resolve();
        if (chosenSeat == null) {
          logger("${resolvingPerson.name} 暂时不想决定座位");
          logger("$resolvingPerson现在的压力值为${++resolvingPerson.stress}");
          continue;
        } else {
          logger("${resolvingPerson.name} 选定了座位：$chosenSeat");
          resolvingPerson.resolved = true;
          chosenSeat.empty = false;
          chosenSeat.owner = resolvingPerson;
          arrangedInfo =
              ArrangedInfo(seat: chosenSeat, person: resolvingPerson);
          break;
        }
      }
      // If arranged success
      if (arrangedInfo != null) {
        // Clear Person Arranged
        arrangeQuene.remove(arrangedInfo.person);
        // Call All person to Process Arrangement
        room.heatmap.clear();
        for (var person in arrangeQuene) {
          person.processArranged(arrangedInfo: arrangedInfo);
        }
        // TODO Update All Person 是否要放在arranged!=null外面？？
        // Update All Person
        for (int times = 1; times <= maxUpdateLoopTimes; ++times) {
          bool dirty = false;
          logger("[提示]第$times次update所有人");
          for (var person in arrangeQuene) {
            if (person.update() == true) dirty = true;
          }
          if (times == maxUpdateLoopTimes) {
            logger("[错误]update次数超过最大深度，终止update");
          }
          if (!dirty) break;
        }
      }
      // Finish Arrangement
      if (loopTimes >= 200) {
        logger("循环次数过多，终止程序");
        break;
      }
      if (arrangeQuene.isEmpty) {
        logger("座位编排完成，终止程序");
        break;
      }
    }
  }
}

// /// [seatChart] (col, row) (列，排)
// void chaosSystemCore(
//     {required List<Person> personList,
//     required Room room,
//     void Function(String)? newLogger})

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
  ChaosSystemCore? core;
  Room? room;

  String name;
  Gender gender;
  int stress = 0;
  bool resolved = false;
  late Set<Seat> targetSet;
  List<Demand> demandList;
  int? nowDemand;
  Person({
    required this.name,
    required this.gender,
    required this.demandList,
  });
  init({required Room room, ChaosSystemCore? core}) {
    this.core = core;
    this.room = room;
    targetSet = room.getEmptySeat(source: Set.from(room.seats));
    for (var demand in demandList) {
      demand.init(room: room, demander: this, core: core);
    }
    // Flash Demand
    nowDemand = null;
    targetSet = room.getEmptySeat(source: Set.from(room.seats));
    for (int i = 0; i < demandList.length; ++i) {
      var demand = demandList[i];
      var coTarget = targetSet.intersection(demand.target); // 已有目标和需求目标的交集
      if (coTarget.isNotEmpty) {
        nowDemand = i;
        targetSet = coTarget;
      }
    }
  }

  void drawHeatmap() {
    if (targetSet.isEmpty || nowDemand == null) return;
    demandList[nowDemand!].drawHeatmap(targetSet);
  }

  void processArranged({required ArrangedInfo arrangedInfo}) {
    if (demandList.isNotEmpty) {
      for (int i = 0; i < demandList.length; ++i) {
        var demand = demandList[i];
        demand.processArranged(arrangedInfo: arrangedInfo);
      }
    } else {
      targetSet = room?.getEmptySeat(source: Set.from(room?.seats ?? [])) ?? {};
    }
  }

  // 返回true说明发生了target的的变动，core会再次进行一轮update以保证针对他人的需求被正确更新
  bool update() {
    targetSet = room?.getEmptySeat(source: Set.from(room?.seats ?? [])) ?? {};
    nowDemand = null;
    bool result = false;
    for (int i = 0; i < demandList.length; ++i) {
      var demand = demandList[i];
      if (demand.update()) result = true;
      var coTarget = targetSet.intersection(demand.target); // 已有目标和需求目标的交集
      if (coTarget.isNotEmpty) {
        nowDemand = i;
        targetSet = coTarget;
      }
    }
    return result;
  }

  Seat? resolve() {
    late Seat? finalSeat;
    // Choose Best Seat in Target Set
    if (nowDemand == null) {
      finalSeat = room?.chooseBestSeat(range: targetSet);
    } else {
      finalSeat = demandList[nowDemand!].resolve(targetSet);
    }
    if (finalSeat == null) return null;
    // Judgment
    for (var demand in demandList) {
      if (!demand.judgment(finalSeat)) {
        (core?.logger ?? print)("[提示]$this选择的座位被$demand拒绝");
        return null;
      }
      if (demand.target.contains(finalSeat)) {
        (core?.logger ?? print)("[提示]$name的需求$demand已被满足");
      } else {
        (core?.logger ?? print)("[提示]$name的需求$demand未被满足");
      }
    }
    return finalSeat;
  }

  int getRankPoint() {
    // rankPoint决定了arrangeList的排序
    if (targetSet.length <= 3) {
      return targetSet.length;
    } else {
      return targetSet.length + math.pow(2, stress).toInt() - 1;
    }
  }

  // 由其他人调用，负责获取主动服从调剂者的座位范围
  Set<Seat> getCompromiserSeats(Person compromiser) {
    Set<Seat> compromiserSeats = {};
    if (nowDemand == null) return compromiserSeats;
    for (int i = 0; i < nowDemand!; ++i) {
      var tempPromiserSeats = demandList[nowDemand!]
          .getCompromiserSeats(compromiser: compromiser, range: targetSet);
      if (compromiserSeats.isEmpty) {
        compromiserSeats = tempPromiserSeats;
      } else {
        var intersection = compromiserSeats.intersection(tempPromiserSeats);
        if (intersection.isNotEmpty) {
          compromiserSeats = intersection;
        }
      }
    }
    return compromiserSeats;
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
      if (value != 0) str += "$key:$value\n";
    });

    return str.substring(0, str.isNotEmpty ? str.length - 1 : 0);
  }
}

// 需求父抽象类
abstract class Demand {
  Person? demander;
  ChaosSystemCore? core;
  Room? room;
  bool resolved = false;
  late bool closed;
  late Set<Seat> target;
  void init(
      {required Room room, required Person demander, ChaosSystemCore? core});
  void processArranged({required ArrangedInfo arrangedInfo});
  bool update();
  Seat? resolve(Set<Seat> range);
  void drawHeatmap(Set<Seat> range);
  // TODO 按需重载
  Set<Seat> getCompromiserSeats(
      {required Set<Seat> range, required Person compromiser});

  bool judgment(Seat finalSeat);
}

// 绝对需求
class AbsoluteDemand extends Demand {
  bool Function(Seat, Room) filter;
  AbsoluteDemand({required this.filter});
  @override
  void init(
      {required Room room, required Person demander, ChaosSystemCore? core}) {
    this.room = room;
    this.demander = demander;
    this.core = core;
    target = room.getEmptySeat(
        source: room.findSeat((Seat seat) => filter(seat, room)));
  }

  @override
  void processArranged({required ArrangedInfo arrangedInfo}) {
    if (target.contains(arrangedInfo.seat)) {
      target = room?.getEmptySeat(
              source:
                  room?.findSeat((Seat seat) => filter(seat, room!)) ?? {}) ??
          {};
    }
  }

  @override
  bool update() {
    // TODO: implement update
    return false;
  }

  @override
  Set<Seat> getCompromiserSeats(
      {required Set<Seat> range, required Person compromiser}) {
    return {};
  }

  @override
  Seat? resolve(Set<Seat> range) {
    return room?.chooseBestSeat(range: range);
  }

  @override
  void drawHeatmap(Set<Seat> range) {
    for (var seat in range) {
      if (room?.heatmap[seat] == null) continue;
      room!.heatmap[seat] = room!.heatmap[seat]! + 1 / range.length;
    }
  }

  @override
  bool judgment(Seat finalSeat) {
    return true;
  }
}

// TODO 带半确定状态的相对需求
class RelativeDemand extends Demand {
  Seat? relativeSeat;
  Set<Seat>? tempRelativeTarget;
  Person? relativePerson;
  String relativePersonName;
  bool Function(
      {required Seat filteringSeat,
      required Room room,
      required Seat relativeSeat}) filter;
  RelativeDemand({required this.relativePersonName, required this.filter});

  @override
  void init(
      {required Room room, required Person demander, ChaosSystemCore? core}) {
    this.room = room;
    if (core != null) {
      this.core = core;
      var temp =
          core.personList.where((person) => relativePersonName == person.name);
      if (temp.isEmpty) {
        // TODO 处理不存在
        core.logger(
            "[错误]$demander的需求$this中指定的relativePerson:$relativePersonName不存在");
      } else {
        relativePerson = temp.first;
      }
    }
    this.demander = demander;
    target = {};
  }

  @override
  void processArranged({required ArrangedInfo arrangedInfo}) {
    if (arrangedInfo.person.name == relativePersonName) {
      (core?.logger ?? print)("[提示]$demander的相对需求$this的目标个体已确定座位，监听响应");
      relativeSeat = arrangedInfo.seat;
      target = room?.getEmptySeat(
              source: room?.findSeat((Seat seat) => filter(
                      filteringSeat: seat,
                      relativeSeat: relativeSeat!,
                      room: room!)) ??
                  {}) ??
          {};
    } else if (relativeSeat != null && target.contains(arrangedInfo.seat)) {
      target = room?.getEmptySeat(
              source: room?.findSeat((Seat seat) => filter(
                      filteringSeat: seat,
                      relativeSeat: relativeSeat!,
                      room: room!)) ??
                  {}) ??
          {};
    } else {
      target = room?.getEmptySeat(source: target) ?? {};
    }
  }

  @override
  bool update() {
    // TODO: 目前采用暴力解法 需要优化
    tempRelativeTarget ??= {};
    Set<Seat> rawSemiTarget = Set.from(target);
    if (relativePerson != null) {
      // // 判断 relativePerson.targetSet 是否不等于 tempRelativeTarget (不互为子集)
      // if (!relativePerson!.targetSet.containsAll(tempRelativeTarget!) ||
      //     !tempRelativeTarget!.containsAll(relativePerson!.targetSet)) {
      //   // 不相等 更新
      //   tempRelativeTarget = Set.from(relativePerson!.targetSet);
      // }
      tempRelativeTarget = Set.from(relativePerson!.targetSet);
    }

    if (room == null) {
      (core?.logger ?? print)("[错误]$demander的需求$this缺少room属性");
      return false;
    }
    // 更新semiTarget
    Map<Seat, int> rateMap = {for (var seat in target) seat: 0};
    for (var relativeTargetSeat in tempRelativeTarget!) {
      for (var targetSeat in target) {
        if (filter(
            filteringSeat: targetSeat,
            relativeSeat: relativeTargetSeat,
            room: room!)) {
          // 符合要求
          rateMap[targetSeat] = rateMap[targetSeat]! + 1; // 只能这样写
        }
      }
    }
    // TODO rateMap投入使用
    // 生成semiTarget
    target = {};
    rateMap.forEach((key, value) {
      if (value > 0) target.add(key);
    });
    // 判断semiTarget是否有变动
    return !target.containsAll(rawSemiTarget) ||
        !rawSemiTarget.containsAll(target);
  }

  @override
  void drawHeatmap(Set<Seat> range) {
    // TODO: 开发不均匀热图
    if (relativePerson == null ||
        range.containsAll(room!.getEmptySeat(source: Set.from(room!.seats)))) {
      return;
    }
    for (var seat in range) {
      if (room?.heatmap[seat] == null) continue;
      room!.heatmap[seat] = room!.heatmap[seat]! + 1 / range.length;
    }
  }

  @override
  Seat? resolve(Set<Seat> range) {
    // TODO: 融入最近理论？
    return room?.chooseBestSeat(range: range);
  }

  @override
  bool judgment(Seat finalSeat) {
    if (relativeSeat == null) {
      if (demander != null && demander!.stress >= maxStress) {
        (core?.logger ?? print)(
            "[提示]$demander选定的位置本不满足$this（监听对象还未确定位置），但迫于压力$demander只能先选择座位$filter");
        return true;
      } else {
        (core?.logger ??
            print)("[提示]$demander选定的位置不满足$this（监听对象还未确定位置），拒绝接受座位");
        return false;
      }
    } else {
      return true;
    }
  }

  @override
  Set<Seat> getCompromiserSeats(
      {required Set<Seat> range, required Person compromiser}) {
    // TODO: implement getCompromiserSeats
    // TODO 暴力解法 需要优化
    Set<Seat> result = {};
    if (room == null) return result;
    if (compromiser.name == relativePersonName) {
      Set<Seat> emptySeat = room!.getEmptySeat(source: Set.from(room!.seats));
      for (Seat masterSeat in range) {
        for (var compromiserSeat in emptySeat) {
          if (filter(
              filteringSeat: masterSeat,
              relativeSeat: compromiserSeat,
              room: room!)) {
            result.add(compromiserSeat);
          }
        }
      }
    }
    return result;
  }
}

/// 妥协需求
/// 响应其它成员的需求 的协调请求
class CompromiserDemand extends Demand {
  late Set<Person> targetPersons;
  late List<String> targetPersonNames;
  CompromiserDemand({required this.targetPersonNames});
  Map<Person, Set<Seat>> targetSeatMap = {};
  Map<Person, Set<Seat>> targetSeatMapTemp = {};
  @override
  void init(
      {required Room room, required Person demander, ChaosSystemCore? core}) {
    this.room = room;
    this.demander = demander;
    if (core != null) {
      this.core = core;
      targetPersons = {};
      for (var targetPersonName in targetPersonNames) {
        var temp =
            core.personList.where((person) => targetPersonName == person.name);
        if (temp.isEmpty) {
          // TODO 处理不存在
          core.logger(
              "[错误]$demander的需求$this中指定的targetPersonName:$targetPersonName");
        } else {
          targetPersons.add(temp.first);
        }
      }
      // 若targetPersonNames为空 targetPerson为所有人
      if (targetPersonNames.isEmpty) targetPersons = Set.from(core.personList);
    }
    target = room.getEmptySeat(source: Set.from(room.seats));
  }

  @override
  void drawHeatmap(Set<Seat> range) {
    // TODO: 开发不均匀热图
    if (targetPersons.isEmpty ||
        range.containsAll(room!.getEmptySeat(source: Set.from(room!.seats)))) {
      return;
    }
    // TODO 更合理的热图绘制
    // for (var seat in range) {
    //   if (room?.heatmap[seat] == null) continue;
    //   room!.heatmap[seat] = room!.heatmap[seat]! + 0.7 / range.length;
    // }
  }

  @override
  bool judgment(Seat finalSeat) {
    // TODO: implement judgment
    // bool result = false;
    // if(target.isEmpty || target.containsAll(room!.getEmptySeat(source: Set.from(room!.seats)))) return true;
    // targetSeatMap.forEach((person, seats) {
    //   if (person.resolved && seats.contains(finalSeat)) result = true;
    // });
    // if(!result) {
    //   if (demander != null && demander!.stress >= maxStress) {
    //     (core?.logger ?? print)(
    //         "[提示]$demander选定的位置本不满足$this（监听对象还未确定位置），但迫于压力$demander只能先选择座位$finalSeat");
    //     return true;
    //   } else {
    //     (core?.logger ??
    //         print)("[提示]$demander选定的位置不满足$this（监听对象还未确定位置），拒绝接受座位");
    //     return false;
    //   }
    // }
    return true;
  }

  @override
  Seat? resolve(Set<Seat> range) {
    return room?.chooseBestSeat(
        range: range,
        getRankFunc: (seat, room) {
          int times = 1000000; // TODO
          targetSeatMap.forEach((key, value) {
            if (value.contains(seat)) --times;
          });
          return times;
        });
  }

  @override
  void processArranged({required ArrangedInfo arrangedInfo}) {
    // TODO: implement update
    if (room == null) return;
    target = room!.getEmptySeat(source: target);
  }

  @override
  bool update() {
    bool result = false;
    if (demander == null) return false;
    for (var person in targetPersons) {
      targetSeatMapTemp[person] = person.getCompromiserSeats(demander!);
    }
    for (var person in targetSeatMapTemp.keys) {
      if (!targetSeatMap.containsKey(person)) {
        targetSeatMap[person] = targetSeatMapTemp[person]!;
        result = true;
      }
      if (!targetSeatMapTemp[person]!.containsAll(targetSeatMap[person]!) ||
          !targetSeatMap[person]!.containsAll(targetSeatMapTemp[person]!)) {
        result = true;
        targetSeatMap[person] = targetSeatMapTemp[person]!;
      }
    }
    if (result) {
      // 刷新target
      Set<Seat> targetBefore = Set.from(target);
      target = {};
      targetSeatMap.forEach((key, value) {
        for (var seat in value) {
          target.add(seat);
        }
      });
      if (target.isEmpty) {
        target = room?.getEmptySeat(source: target) ?? {};
      }
      return !target.containsAll(targetBefore) ||
          !targetBefore.containsAll(target);
    }
    return false;
  }

  @override
  Set<Seat> getCompromiserSeats(
      {required Set<Seat> range, required Person compromiser}) {
    // TODO: implement getCompromiserSeats
    return {};
  }
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

  static num getEuclideanDistance(Seat seat1, Seat seat2) {
    return math.sqrt(math.pow(seat1.location.row - seat2.location.row, 2) +
        math.pow(seat1.location.column - seat2.location.column, 2));
  }

  static num getManhattanDistance(Seat seat1, Seat seat2) {
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
    return "${owner ?? "空座位"}:(${location.column},${location.row})";
  }
}

class Location {
  int row;
  int column;
  Location({required this.row, required this.column});
}
