import { PACKAGE_DEFINITIONS } from "./momo_config";

export interface FirestoreAdminAdapter {
  Timestamp: {
    now(): unknown;
    fromDate(date: Date): unknown;
  };
  FieldValue: {
    serverTimestamp(): unknown;
  };
}

export async function isUserAdmin(
  db: any,
  uid: string,
  decodedToken?: Record<string, any>
): Promise<boolean> {
  if (decodedToken?.role === "admin") return true;
  try {
    const userDoc = await db.collection("users").doc(uid).get();
    return userDoc.exists && userDoc.data()?.role === "admin";
  } catch {
    return false;
  }
}

export async function recalculateRoomRatingInternal(
  db: any,
  roomId: string
): Promise<{ averageRating: number; totalReviews: number }> {
  const snap = await db.collection("reviews").where("roomId", "==", roomId).get();
  const totalReviews = snap.size;
  let sum = 0;
  for (const doc of snap.docs) {
    sum += Number(doc.data()?.rating || 0);
  }
  const averageRating = totalReviews > 0 ? Number((sum / totalReviews).toFixed(1)) : 0;
  await db.collection("rooms").doc(roomId).update({
    averageRating,
    totalReviews,
  });
  return { averageRating, totalReviews };
}

export async function activatePromotionForOrder(params: {
  db: any;
  firestoreAdmin: FirestoreAdminAdapter;
  orderData: Record<string, any>;
  transId: string;
  onInfo?: (message: string) => void;
}): Promise<void> {
  const { db, firestoreAdmin, orderData, transId, onInfo } = params;
  const roomId = orderData.roomId;
  const packageId = orderData.packageId as "bronze" | "silver" | "gold";
  const packageDef = PACKAGE_DEFINITIONS[packageId] || PACKAGE_DEFINITIONS.bronze;
  const durationDays = packageDef.durationDays;
  const priority = packageDef.priority;

  const roomRef = db.collection("rooms").doc(roomId);
  const roomSnap = await roomRef.get();
  if (!roomSnap.exists) return;

  const roomData = roomSnap.data()!;
  const now = new Date();
  const startAt = now;
  let expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000);

  const currentExpiresAt = roomData.packageExpiresAt?.toDate?.() || null;
  const currentPriority = (roomData.priority || 0) as number;

  if (currentExpiresAt && currentExpiresAt > now && currentPriority > 0) {
    if (currentPriority === priority) {
      expiresAt = new Date(currentExpiresAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
      onInfo?.(`Gia hạn gói cùng hạng ${packageId}: Hạn mới = ${expiresAt.toISOString()}`);
    } else if (priority > currentPriority) {
      const remainingMs = currentExpiresAt.getTime() - now.getTime();
      expiresAt = new Date(now.getTime() + durationDays * 24 * 60 * 60 * 1000 + remainingMs);
      onInfo?.(`Nâng cấp gói lên hạng cao hơn ${packageId}: Hạn mới = ${expiresAt.toISOString()}`);
    } else {
      expiresAt = new Date(currentExpiresAt.getTime() + durationDays * 24 * 60 * 60 * 1000);
    }
  }

  const batch = db.batch();

  batch.update(roomRef, {
    packageType: packageId,
    priority,
    packageStartAt: firestoreAdmin.Timestamp.fromDate(startAt),
    packageExpiresAt: firestoreAdmin.Timestamp.fromDate(expiresAt),
    vipType: packageId,
  });

  batch.set(db.collection("room_promotions").doc(roomId), {
    roomId,
    ownerId: orderData.userId,
    packageId,
    packageName: packageDef.name,
    priority,
    status: "active",
    startAt: firestoreAdmin.Timestamp.fromDate(startAt),
    expiresAt: firestoreAdmin.Timestamp.fromDate(expiresAt),
    lastOrderId: orderData.orderId,
    updatedAt: firestoreAdmin.FieldValue.serverTimestamp(),
  });

  batch.update(db.collection("package_orders").doc(orderData.orderId), {
    status: "completed",
    transactionId: transId,
    paidAt: firestoreAdmin.FieldValue.serverTimestamp(),
    startAt: firestoreAdmin.Timestamp.fromDate(startAt),
    expiresAt: firestoreAdmin.Timestamp.fromDate(expiresAt),
    updatedAt: firestoreAdmin.FieldValue.serverTimestamp(),
  });

  const dateFormatted = `${expiresAt.getDate()}/${expiresAt.getMonth() + 1}/${expiresAt.getFullYear()}`;
  batch.set(db.collection("notifications").doc(), {
    recipientId: orderData.userId,
    type: "package_activated",
    title: `Kích hoạt ${packageDef.name} thành công! 🎉`,
    body: `Phòng trọ "${orderData.roomTitle}" đã được nâng cấp lên ${packageDef.name} (Hạng ưu tiên ${priority}). Thời hạn sử dụng đến hết ngày ${dateFormatted}.`,
    roomId,
    orderId: orderData.orderId,
    isRead: false,
    createdAt: firestoreAdmin.FieldValue.serverTimestamp(),
  });

  await batch.commit();
}

export async function sweepExpiredPromotions(params: {
  db: any;
  firestoreAdmin: FirestoreAdminAdapter;
  onInfo?: (message: string) => void;
}): Promise<{ expiredCount: number }> {
  const { db, firestoreAdmin, onInfo } = params;
  const now = firestoreAdmin.Timestamp.now();
  const expiredPromosSnap = await db
    .collection("room_promotions")
    .where("status", "==", "active")
    .where("expiresAt", "<=", now)
    .get();

  if (expiredPromosSnap.empty) {
    return { expiredCount: 0 };
  }

  onInfo?.(`Phát hiện ${expiredPromosSnap.docs.length} gói đã hết hạn. Đang hoàn về tin thường...`);

  const batch = db.batch();
  let expiredCount = 0;

  for (const doc of expiredPromosSnap.docs) {
    const promo = doc.data();
    const roomId = promo.roomId as string | undefined;
    expiredCount += 1;

    batch.update(doc.ref, {
      status: "expired",
      updatedAt: firestoreAdmin.FieldValue.serverTimestamp(),
    });

    if (roomId) {
      batch.update(db.collection("rooms").doc(roomId), {
        priority: 0,
        packageType: "normal",
        vipType: "normal",
      });

      if (promo.ownerId) {
        batch.set(db.collection("notifications").doc(), {
          recipientId: promo.ownerId,
          type: "package_expired",
          title: "Gói đăng tin đã hết hạn ⏰",
          body: `Gói ${promo.packageName} của phòng trọ đã hết hạn sử dụng. Tin đăng đã tự động chuyển về trạng thái tin thường. Bạn có thể gia hạn bất kỳ lúc nào để tiếp tục nhận ưu tiên.`,
          roomId,
          isRead: false,
          createdAt: firestoreAdmin.FieldValue.serverTimestamp(),
        });
      }
    }
  }

  await batch.commit();
  return { expiredCount };
}
