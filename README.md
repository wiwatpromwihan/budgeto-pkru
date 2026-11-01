# แบ่งดี

แอป Flutter Web สำหรับแบ่งรายรับรายเดือนเป็นงบ 3 หมวด: จำเป็น ใช้จ่าย และออม พร้อมแท็บออมทอง ได้แรงบันดาลใจจาก [Budgeto](https://github.com/tejasbadone/budgeto) และพัฒนาเป็นโปรเจกต์ใหม่สำหรับเดโมบน localhost

แท็บออมทองใช้ [Thai Gold API](https://github.com/max180643/thai-gold-api) แสดงราคาทองคำแท่ง 96.5% เป็นข้อมูลอ้างอิง บันทึกเฉพาะทองที่ซื้อจากภายนอก โดยหักต้นทุนจากเงินออมสดสะสมข้ามเดือน ไม่ใช่การซื้อขายหรือชำระเงินจริง มูลค่าขายคืนและกำไร/ขาดทุนเป็นประมาณการเท่านั้น

## ความสามารถ

- สมัครและเข้าสู่ระบบด้วยอีเมล/รหัสผ่านหรือ Google ผ่าน Firebase Authentication
- เพิ่ม แก้ไข และลบรายรับ รายจ่าย และเงินโอนเข้าออม
- ปรับสัดส่วนงบรายเดือน โดยเริ่มที่ 50/30/20
- ดูยอดจัดสรร ใช้จริง คงเหลือ และประวัติแยกตามเดือน
- จัดเก็บข้อมูลแยกตามบัญชีใน Cloud Firestore พร้อม Security Rules

## เริ่มใช้งาน

ต้องมี Flutter 3.44 หรือใหม่กว่า และเบราว์เซอร์ Chrome

```bash
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 8085
```

เปิด `http://localhost:8085` แล้วสมัครบัญชีหรือเข้าสู่ระบบ บัญชี Firebase ปัจจุบันคือ `budgeto-pkru-20261031` และใช้ฐานข้อมูล Firestore ชื่อ `budgeto` ใน `asia-southeast1`.

การนำไปใช้กับ Firebase โปรเจกต์ของตนเอง: สร้างเว็บแอปใน Firebase, เปิด Email/Password และ Google ใน Authentication, เพิ่ม `localhost` ใน Authorized domains, สร้าง Firestore Enterprise Native Mode ชื่อ `budgeto`, เปลี่ยนค่าใน `lib/firebase_options.dart` และ `.firebaserc`, แล้ว deploy `firestore.rules` ด้วย Firebase CLI การตั้งค่า Firebase สำหรับเว็บเป็นตัวระบุโปรเจกต์สาธารณะ ไม่ใช่รหัสผ่าน; ความปลอดภัยของข้อมูลขึ้นกับ Authentication และ Security Rules

## ตรวจสอบ

```bash
flutter analyze
flutter test
flutter build web
```

แอปนี้เป็นตัวอย่างการจัดงบ ไม่มีการโอนเงินจริงหรือคำแนะนำการลงทุน
