
class JourneyPlanSupervisor {
  final String name;
  final double lat;
  final double lng;
  bool isVisited;

  // NEW: time fields
  DateTime? checkIn;
  DateTime? checkOut;
  int? durationMinutes;

  JourneyPlanSupervisor({
    required this.name,
    required this.lat,
    required this.lng,
    this.isVisited = false,
    this.checkIn,
    this.checkOut,
    this.durationMinutes,
  });
}

final List<JourneyPlanSupervisor> kJourneyPlan = [
  JourneyPlanSupervisor(
    name: 'Paracha Textile Mill (Ghee Unit)',
    lat: 24.887257,
    lng: 66.9772325,
  ),
  JourneyPlanSupervisor(
    name: 'Imtiaz Super Store – Karachi',
    lat: 24.8829,
    lng: 67.0660,
  ),
  JourneyPlanSupervisor(
    name: 'Imtiaz Super Store – Defence',
    lat: 24.8129,
    lng: 67.0648,
  ),
  JourneyPlanSupervisor(
    name: 'Naheed – Bahadurabad',
    lat: 24.8822,
    lng: 67.0729,
  ),
  JourneyPlanSupervisor(
    name: 'Imtiaz Super Store – Gulshan',
    lat: 24.9180,
    lng: 67.0971,
  ),
  JourneyPlanSupervisor(
    name: 'Imtiaz Super Store – Defence 2',
    lat: 24.8075,
    lng: 67.0675,
  ),
];
