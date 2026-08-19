class ReviewModel {
  final String id;
  final String userName;
  final String userInitials;
  final double rating;
  final String reviewText;
  final String date;
  int likes;
  bool isLiked;

  ReviewModel({
    required this.id,
    required this.userName,
    required this.userInitials,
    required this.rating,
    required this.reviewText,
    required this.date,
    this.likes = 0,
    this.isLiked = false,
  });
}
