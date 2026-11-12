import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

// Khởi tạo Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

/**
 * Ngưỡng số lượng báo cáo vi phạm để hệ thống tự động ẩn tin đăng phòng trọ.
 * Khi một phòng đạt đủ hoặc vượt quá ngưỡng này (>= 5 reports), tin đăng sẽ bị ẩn ngay lập tức.
 */
const AUTO_MODERATION_REPORT_THRESHOLD = 5;

/**
 * TRIGGER FIRESTORE V2: Lắng nghe sự kiện tạo báo cáo mới tại `reports/{reportId}`
 *
 * Quy trình xử lý tự động (Auto-Moderation Pipeline):
 * 1. Lấy thông tin `roomId` từ bản ghi report mới được tạo.
 * 2. Kiểm tra trạng thái hiện tại của phòng. Nếu phòng đã bị ẩn ('hidden') thì bỏ qua để tránh spam thông báo.
 * 3. Đếm tổng số báo cáo của phòng trọ này trong collection `reports` (sử dụng .count() aggregate query).
 * 4. Nếu tổng số reports >= 5:
 *    - Cập nhật trạng thái `status: 'hidden'` cho document `rooms/{roomId}`.
 *    - Ghi nhận `autoModerated: true`, thời điểm và lý do tự động ẩn.
 *    - Tạo 1 document thông báo khẩn gửi cho Quản trị viên (`recipientId: 'admin'`, `type: 'system_alert'`).
 *    - Gửi thêm thông báo nhắc nhở cho chủ phòng (`ownerId`) báo rằng tin đã bị tạm ẩn chờ phúc khảo.
 *
 * Sử dụng Firestore Batch Write để đảm bảo toàn vẹn dữ liệu (Atomic write).
 */
export const onReportCreatedAutoModerate = onDocumentCreated(
  {
    document: "reports/{reportId}",
    region: "asia-southeast1", // Khu vực Đông Nam Á tối ưu độ trễ cho Việt Nam
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.warn("onReportCreatedAutoModerate: Không tìm thấy dữ liệu event document snapshot.");
      return;
    }

    const reportData = snap.data();
    const roomId = reportData?.roomId;
    const roomTitle = reportData?.roomTitle || "Phòng trọ";

    if (!roomId || typeof roomId !== "string" || roomId.trim().length === 0) {
      logger.warn("onReportCreatedAutoModerate: Báo cáo thiếu roomId hợp lệ.", {
        reportId: event.params.reportId,
      });
      return;
    }

    try {
      // 1. Kiểm tra trạng thái hiện tại của phòng trọ trong Firestore
      const roomRef = db.collection("rooms").doc(roomId);
      const roomSnap = await roomRef.get();

      if (!roomSnap.exists) {
        logger.warn(`Phòng trọ mã "${roomId}" không tồn tại trong hệ thống.`);
        return;
      }

      const roomData = roomSnap.data();
      const currentStatus = roomData?.status;
      const ownerId = roomData?.ownerId;
      const effectiveTitle = roomData?.title || roomTitle;

      // Nếu phòng đã ở trạng thái 'hidden' (đã ẩn trước đó), không gửi lại thông báo lặp lại
      if (currentStatus === "hidden") {
        logger.info(`Phòng "${roomId}" đã ở trạng thái 'hidden'. Bỏ qua quá trình tự động ẩn.`);
        return;
      }

      // 2. Query đếm tổng số reports của phòng này trong collection 'reports'
      // Sử dụng API .count() của Firestore Admin SDK để tối ưu băng thông và chi phí đọc
      const reportsCountSnap = await db
        .collection("reports")
        .where("roomId", "==", roomId)
        .count()
        .get();

      const totalReports = reportsCountSnap.data().count;
      logger.info(`Phòng "${roomId}" ("${effectiveTitle}") hiện có tổng cộng ${totalReports} lượt báo cáo.`);

      // 3. Kiểm tra điều kiện vượt ngưỡng kiểm duyệt tự động (>= 5 reports)
      if (totalReports >= AUTO_MODERATION_REPORT_THRESHOLD) {
        logger.warn(
          `CẢNH BÁO: Phòng "${roomId}" đã nhận ${totalReports}/${AUTO_MODERATION_REPORT_THRESHOLD} lượt báo cáo. Thực hiện tự động ẩn tin!`
        );

        // Khởi tạo batch write để đảm bảo cập nhật trạng thái phòng và tạo các thông báo diễn ra đồng thời
        const batch = db.batch();

        // 3.1. Cập nhật trạng thái phòng thành 'hidden'
        batch.update(roomRef, {
          status: "hidden",
          autoModerated: true,
          autoModeratedAt: admin.firestore.FieldValue.serverTimestamp(),
          autoModeratedReason: `Tự động ẩn do vượt quá ${totalReports} lượt báo cáo vi phạm từ người dùng`,
        });

        // 3.2. Tạo thông báo khẩn gửi tới Quản trị viên (Admin)
        const adminNotificationRef = db.collection("notifications").doc();
        batch.set(adminNotificationRef, {
          recipientId: "admin",
          type: "system_alert",
          title: "🚨 Cảnh báo khẩn: Tin đăng bị báo cáo nhiều lần",
          body: `Phòng "${effectiveTitle}" (Mã: ${roomId}) đã bị ẩn tự động do nhận ${totalReports} lượt báo cáo vi phạm. Vui lòng kiểm tra và xử lý!`,
          roomId: roomId,
          totalReports: totalReports,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 3.3. Tùy chọn: Gửi thông báo đến chủ phòng (ownerId) để họ nắm tình trạng
        if (ownerId && typeof ownerId === "string" && ownerId.trim().length > 0) {
          const ownerNotificationRef = db.collection("notifications").doc();
          batch.set(ownerNotificationRef, {
            recipientId: ownerId,
            type: "room_rejected",
            title: "Tin đăng tạm thời bị ẩn để kiểm duyệt ⚠️",
            body: `Tin đăng "${effectiveTitle}" của bạn nhận được nhiều phản ánh vi phạm từ người dùng và đã được hệ thống tạm ẩn tự động để Quản trị viên kiểm duyệt lại nội dung.`,
            roomId: roomId,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Thực thi batch write lên Firestore
        await batch.commit();

        logger.info(
          `Đã hoàn tất tự động ẩn phòng "${roomId}" và phát thông báo tới Admin & Chủ phòng thành công.`
        );
      }
    } catch (error) {
      logger.error("Lỗi ngoại lệ khi thực thi trigger onReportCreatedAutoModerate:", error);
      throw error;
    }
  }
);

