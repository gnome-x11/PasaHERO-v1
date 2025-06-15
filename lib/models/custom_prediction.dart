//models/custom_prediction_helper.dart

class CustomPrediction {
  final String description;
  final String placeId;
  final bool isCurrentLocation;
  final bool isHistory;

  final String mainText;
  final String secondaryText;

  CustomPrediction({
    required this.description,
    required this.placeId,
    this.isCurrentLocation = false,
    this.isHistory = false,
    this.mainText = '',
    this.secondaryText = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'placeId': placeId,
      'isCurrentLocation': isCurrentLocation,
      'isHistory': isHistory,
    };
  }

  factory CustomPrediction.fromJson(Map<String, dynamic> json) {
    return CustomPrediction(
      description: json['description'],
      placeId: json['placeId'],
      isCurrentLocation: json['isCurrentLocation'] ?? true,
      isHistory: json['isHistory'] ?? false,
    );
  }
}
