import '../bin/chaos_system_core.dart';

void main() {
  var demand = AbsoluteDemand(filter: (seat, room) {
    return true;
  });
  demand.update();
}
