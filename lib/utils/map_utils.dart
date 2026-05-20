import 'package:google_maps_flutter/google_maps_flutter.dart';

BitmapDescriptor getCorMarker(String status) {
  switch (status) {
    case "fechado":
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    case "prospect":
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
    case "concorrente":
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    default:
      return BitmapDescriptor.defaultMarker;
  }
}