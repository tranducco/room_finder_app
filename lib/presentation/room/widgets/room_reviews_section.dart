import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/review_service.dart';
import '../../../domain/models/review.dart';
import '../../../domain/models/room.dart';
import '../../widgets/app_button_style.dart';

class RoomReviewsSection extends StatelessWidget {
  final Room room;
  final ReviewService reviewService;
  final VoidCallback onWriteReview;

  const RoomReviewsSection({
    super.key,
    required this.room,
    required this.reviewService,
    required this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: reviewService.reviewsStream(room.roomId),
      builder: (context, snapshot) {
        final reviews = snapshot.data ?? [];

        final totalReviews = reviews.isNotEmpty
            ? reviews.length
            : (snapshot.connectionState == ConnectionState.waiting
                ? room.totalReviews
                : 0);
        final averageRating = reviews.isNotEmpty
            ? (reviews.map((r) => r.rating).reduce((a, b) => a + b) /
                reviews.length)
            : (snapshot.connectionState == ConnectionState.waiting
                ? room.averageRating
                : 0.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⭐ Đánh giá & Nhận xét',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          averageRating > 0
                              ? averageRating.toStringAsFixed(1)
                              : 'Chưa có đánh giá',
                          style: TextStyle(
                            fontSize: averageRating > 0 ? 20 : 15,
                            fontWeight: FontWeight.bold,
                            color: averageRating > 0
                                ? const Color(0xFF1A1A2E)
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (averageRating > 0) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(5, (index) {
                              return Icon(
                                index < averageRating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                          Text(
                            '($totalReviews)',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onWriteReview,
                  icon: const Icon(Icons.rate_review_outlined, size: 15),
                  label: const Text('Viết đánh giá'),
                  style: AppButtonStyle.primary(
                    borderRadius: 8,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Color(0xFF00897B)),
                ),
              )
            else if (reviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.star_outline_rounded,
                        size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa có đánh giá nào cho phòng này',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hãy là người đầu tiên trải nghiệm và để lại nhận xét cho phòng trọ này nhé!',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final r = reviews[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              const Color(0xFF00897B).withAlpha(30),
                          backgroundImage: r.userAvatar.isNotEmpty
                              ? NetworkImage(r.userAvatar)
                              : null,
                          child: r.userAvatar.isEmpty
                              ? Text(
                                  r.userName.isNotEmpty
                                      ? r.userName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF00897B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (r.createdAt != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm')
                                          .format(r.createdAt!),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (sIndex) {
                                  return Icon(
                                    sIndex < r.rating.round()
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.comment,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF1F2937),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
