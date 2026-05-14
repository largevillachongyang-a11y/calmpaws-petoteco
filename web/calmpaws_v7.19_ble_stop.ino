/*
 * CalmPaws ESP32-C3 固件 V7.19
 *
 * V7.19 修复：离线/实时上传 HTTP -3/-1（根因：BLE stack 常驻占用 ~20KB 堆）
 *
 *   【根因分析（Serial堆日志确认）】
 *   第1次上传前堆: 52024 bytes
 *   第2次上传前堆: 43320 bytes（第1次SSL未完全释放，减少8.7KB）
 *   SSL context 需求: ~40KB（mbedTLS TLS握手缓冲，不可减少）
 *   body_buf(520行):  ~11.6KB
 *   合计需求:         ~51.6KB → 第2次起可用堆不足 → HTTP -3/-1
 *
 *   【根本原因】
 *   BLE stack 在 WiFi 连接成功后仍常驻堆内存（~20KB），
 *   导致可用堆峰值仅 52KB，SSL 握手内存不足。
 *   BLE 只在配网阶段需要，WiFi 连接成功后完全无用。
 *
 *   【V7.19 修复】
 *   WiFi 连接成功后立即调用 btStop() 彻底释放 BLE/BT controller 内存。
 *   修复位置：
 *     A. setup() 中保存的 WiFi 连接成功后
 *     B. BLE 配网回调 connectWiFi() 成功后（delay后再btStop，确保OK通知发出）
 *   修复效果：释放 ~20KB → 可用堆提升至 ~72KB → 上传安全边际 ~18KB
 *
 * V7.18 修复：上传 HTTP -3，心跳/上传同帧触发 + TCP FIN 未完成导致 mbedTLS 状态混乱
 *
 *   【curl 诊断结论（2026-05-14 已验证）】
 *   - curl --http1.1 POST /api/upload (6KB/300行) → HTTP 200 ✅
 *   - curl 心跳→上传 keep-alive 复用 → 全部成功 ✅
 *   - 服务器端 100% 正常，WAF 不拦截，路径没问题
 *   - 问题在 ESP32 客户端 mbedTLS TCP 关闭时序
 *
 *   【根因分析】
 *   g_sc.stop() 调用 mbedtls_ssl_close_notify()，TCP FIN 在 lwIP 栈里异步排队。
 *   realtime 模式下心跳(5s)和上传(5s)极大概率在同一 loop() 迭代触发：
 *     sendHeartbeat() → g_sc.stop() → [TCP FIN 还在排队]
 *     uploadXYZData() → resetSSL() → delay(100) [不够] → g_sc 重新连接
 *   → 新连接的 SSL 握手期间收到上个连接的 FIN/RST → mbedTLS 内部状态混乱
 *   → SSL 握手完成但 body 发送时连接被断开 → HTTP -3
 *
 *   【V7.18 三项修复】
 *   1. resetSSL() delay: 100ms → 300ms（给 TCP FIN 充足时间）
 *   2. loop() 中 did_heartbeat 标志：心跳后上传额外等 600ms
 *   3. uploadXYZData/uploadOfflineData 加堆内存诊断日志
 *
 * V7.17 修复：全局唯一 WiFiClientSecure g_sc + resetSSL()
 * V7.16 修复：离线上传期间 interval→60s + 包间心跳维活
 * V7.15 修复：NTP 超时 3s→10s+重试，time_synced 检查
 * V7.14 修复：所有 POST 加 Expect:"" 禁用 100-continue
 * V7.13 修复：局部 sc + sc.stop() 防 AES 内存堆积
 * V7.10 修复：彻底解决 esp-aes: Failed to allocate memory 导致的 HTTP -3/-1
 * V7.3 更新说明：多物种支持（猫/狗），26Hz/104Hz 切换
 * V7.2 更新说明：USB 供电检测
 */

#include <Wire.h>
#include <Adafruit_ISM330DHCX.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <LittleFS.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <sys/time.h>
#include <Preferences.h>

// ===================================================
// ⚙️ 配置区
// ===================================================
#define DEVICE_ID      "collar_001"
#define DEVICE_KEY     "calmpaws_secret"
#define SERVER_DEFAULT "https://api.myvideotest2026.top"

#define SAMPLE_RATE_HZ_DOG  104
#define SAMPLE_RATE_HZ_CAT   26
#define SAMPLE_RATE_HZ      100
int current_sample_rate_hz = SAMPLE_RATE_HZ_DOG;
int sample_interval_ms     = 1000 / SAMPLE_RATE_HZ_DOG;

char current_species[8] = "dog";

#define HEARTBEAT_INTERVAL_MS 5000

int heartbeat_fail_count = 0;
int heartbeat_ok_count   = 0;

int upload_interval_ms = 60000;

#define UPLOAD_SECONDS  5

#define FLASH_WARN_PCT          80
#define FLASH_EMERG_INTERVAL_MS 10000

#define BAT_PIN  2
const float R1 = 100.0;
const float R2 = 100.0;
#define BAT_CHECK_INTERVAL_MS 60000

#define SWITCH_PIN 13
#define OFFLINE_FILE "/offline_data.bin"
#define OFFLINE_MAX_PACKETS  3600

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

#define NTP_SERVER "pool.ntp.org"
#define NTP_OFFSET 0

#define RING_BUF_SIZE 2100
float ring_buf[RING_BUF_SIZE * 3];
volatile int ring_head  = 0;
volatile int ring_count = 0;

// ===================================================
// 全局变量
// ===================================================
Adafruit_ISM330DHCX imu;
Preferences prefs;

String wifi_ssid     = "";
String wifi_password = "";
String server_url    = SERVER_DEFAULT;

bool wifi_connected      = false;
bool time_synced         = false;
bool _pending_ntp        = false;
bool _pending_offline_up = false;
int  battery_level  = 100;

// V7.17：全局唯一 SSL 客户端，三个函数串行共用，避免双 context 内存竞争
WiFiClientSecure g_sc;

unsigned long last_sample_time    = 0;
unsigned long last_heartbeat_time = 0;
unsigned long last_upload_time    = 0;
unsigned long last_bat_check_time = 0;

BLEServer*         pServer         = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool ble_client_connected = false;

// ===================================================
// 工具函数
// ===================================================
int getUploadRows() {
    return current_sample_rate_hz * UPLOAD_SECONDS;
}

int getFlashUsePct() {
    size_t total = LittleFS.totalBytes();
    size_t used  = LittleFS.usedBytes();
    if (total == 0) return 0;
    return (int)(used * 100 / total);
}

// ===================================================
// 🔄 切换 IMU 采样率
// ===================================================
void setImuSampleRate(int rate_hz) {
    if (rate_hz == current_sample_rate_hz) return;
    if (rate_hz == SAMPLE_RATE_HZ_CAT) {
        imu.setAccelDataRate(LSM6DS_RATE_26_HZ);
        current_sample_rate_hz = SAMPLE_RATE_HZ_CAT;
        sample_interval_ms     = 1000 / SAMPLE_RATE_HZ_CAT;
        Serial.printf("🐱 IMU 切换至 26Hz（猫模式）\n");
    } else {
        imu.setAccelDataRate(LSM6DS_RATE_104_HZ);
        current_sample_rate_hz = SAMPLE_RATE_HZ_DOG;
        sample_interval_ms     = 1000 / SAMPLE_RATE_HZ_DOG;
        Serial.printf("🐶 IMU 切换至 104Hz（狗模式）\n");
    }
    ring_head  = 0;
    ring_count = 0;
    Serial.printf("   缓冲已清空，新采样间隔：%dms，上传行数：%d行/包\n",
                  sample_interval_ms, getUploadRows());
}

// ===================================================
// 🔋 电量检测
// ===================================================
int getBatteryLevel() {
    uint32_t total_mv = 0;
    for (int i = 0; i < 5; i++) {
        total_mv += analogReadMilliVolts(BAT_PIN);
        delay(2);
    }
    uint32_t pin_mv = total_mv / 5;
    float pin_v = pin_mv / 1000.0f;
    if (pin_v < 0.5f) {
        Serial.println("🔋 USB 供电模式（无电池），电量显示 100%");
        return 100;
    }
    float bat_v = pin_v * ((R1 + R2) / R2);
    int pct = (int)((bat_v - 3.3f) / (4.2f - 3.3f) * 100);
    if (pct > 100) pct = 100;
    if (pct < 0)   pct = 0;
    Serial.printf("🔋 电量: 引脚=%umV  电压=%.2fV  百分比=%d%%\n", pin_mv, bat_v, pct);
    return pct;
}

// ===================================================
// 🔘 拨动开关
// ===================================================
void checkSwitch() {
    static bool last_sw = HIGH;
    bool cur_sw = digitalRead(SWITCH_PIN);
    if (cur_sw == last_sw) return;
    delay(30);
    cur_sw = digitalRead(SWITCH_PIN);
    if (cur_sw == last_sw) return;
    last_sw = cur_sw;
    if (cur_sw == LOW) {
        Serial.println("🔵 拨动开关状态：【ON（导通）】");
    } else {
        Serial.println("⚫ 拨动开关状态：【OFF（断开）】");
    }
}

// ===================================================
// 📡 WiFi + NTP
// ===================================================
// V7.17：每次 HTTP 请求前调用，确保 g_sc 状态干净
// V7.18：delay 从 100ms 增加到 300ms，确保 TCP FIN 在 lwIP 栈中完成发送
void resetSSL() {
    g_sc.stop();
    delay(300);  // V7.18: 300ms 足够 lwIP 完成 TCP FIN 四次挥手
    g_sc.setInsecure();
}
bool connectWiFi(const String& ssid, const String& pass, int timeout_sec = 15) {
    Serial.printf("📶 连接 WiFi：%s\n", ssid.c_str());
    WiFi.begin(ssid.c_str(), pass.c_str());
    unsigned long t = millis();
    while (WiFi.status() != WL_CONNECTED &&
           millis() - t < (unsigned long)(timeout_sec * 1000)) {
        delay(500);
        Serial.print(".");
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("\n✅ WiFi 已连接，本机 IP：%s\n", WiFi.localIP().toString().c_str());
        return true;
    }
    Serial.println("\n❌ WiFi 连接失败");
    return false;
}

void syncNTP() {
    // V7.15: 超时 10s，最多重试 3 次，确保 SSL 证书时间校验通过
    const int MAX_NTP_RETRY = 3;
    for (int attempt = 1; attempt <= MAX_NTP_RETRY; attempt++) {
        configTime(NTP_OFFSET, 0, NTP_SERVER);
        Serial.printf("⏱️  NTP 同步第%d/%d次", attempt, MAX_NTP_RETRY);
        unsigned long t = millis();
        while (time(nullptr) < 1000000000UL && millis() - t < 10000) {
            delay(300);
            Serial.print(".");
        }
        if (time(nullptr) > 1000000000UL) {
            time_synced = true;
            struct tm ti;
            getLocalTime(&ti);
            Serial.printf("\n✅ NTP同步成功：%04d-%02d-%02d %02d:%02d:%02d UTC\n",
                ti.tm_year + 1900, ti.tm_mon + 1, ti.tm_mday,
                ti.tm_hour, ti.tm_min, ti.tm_sec);
            return;  // 成功，立即返回
        }
        Serial.printf("\n⚠️  NTP第%d次失败，%s\n",
                      attempt, attempt < MAX_NTP_RETRY ? "2秒后重试..." : "放弃");
        if (attempt < MAX_NTP_RETRY) delay(2000);
    }
    // 三次全失败：time_synced 保持 false，离线上传将跳过
    Serial.println("❌ NTP 同步失败，离线上传将暂停直到时间就绪");
}

// ===================================================
// 💓 心跳（固定 5 秒）
// V7.14：局部 sc + stop() + Expect:"" 禁用100-continue（修复400）
// ===================================================
void sendHeartbeat() {
    if (!wifi_connected) return;

    StaticJsonDocument<256> doc;
    doc["device_id"] = DEVICE_ID;
    doc["key"]       = DEVICE_KEY;
    doc["battery"]   = battery_level;
    doc["timestamp"] = (long)time(nullptr);
    doc["flash_pct"] = getFlashUsePct();
    doc["species"]   = current_species;

    String body;
    serializeJson(doc, body);

    resetSSL();  // V7.17: 重置全局 sc，确保无残留 session
    HTTPClient http;
    http.begin(g_sc, server_url + "/api/heartbeat");
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Expect", "");
    http.setTimeout(8000);
    int code = http.POST(body);

    if (code == 200) {
        String resp = http.getString();
        StaticJsonDocument<256> rdoc;
        if (!deserializeJson(rdoc, resp)) {
            int new_interval    = rdoc["interval"] | 60;
            int new_interval_ms = new_interval * 1000;
            Serial.printf("💓 心跳OK #%d (HTTP 200) | 模式:%s 间隔:%ds | RSSI:%ddBm\n",
                          ++heartbeat_ok_count, (rdoc["mode"] | "bg"), new_interval, WiFi.RSSI());
            if (new_interval_ms != upload_interval_ms) {
                upload_interval_ms = new_interval_ms;
            }
            int new_rate = rdoc["sample_rate"] | current_sample_rate_hz;
            if (new_rate != current_sample_rate_hz) {
                Serial.printf("💓 心跳 → 采样率变更：%dHz → %dHz\n",
                              current_sample_rate_hz, new_rate);
                setImuSampleRate(new_rate);
            }
            const char* new_species = rdoc["species"] | "";
            if (strlen(new_species) > 0 &&
                strncmp(new_species, current_species, sizeof(current_species)) != 0) {
                strncpy(current_species, new_species, sizeof(current_species) - 1);
                current_species[sizeof(current_species) - 1] = '\0';
                Serial.printf("💓 心跳 → 物种更新：%s\n", current_species);
                prefs.begin("calmpaws", false);
                prefs.putString("species", current_species);
                prefs.end();
            }
        }
    } else {
        heartbeat_fail_count++;
        Serial.printf("💓 心跳失败 #%d (HTTP %d) | WiFi状态:%d RSSI:%ddBm | 服务器:%s\n",
                      heartbeat_fail_count, code,
                      (int)WiFi.status(), WiFi.RSSI(), server_url.c_str());
        if (WiFi.status() != WL_CONNECTED) {
            Serial.println("   ⚠️  WiFi已断开");
            wifi_connected = false;
        } else if (code == -1) {
            Serial.println("   ❌ -1: 连接被拒绝");
        } else if (code == -3) {
            Serial.println("   ❌ -3: SSL发送失败");
        } else if (code == -11) {
            Serial.println("   ❌ -11: TCP连接被重置");
        }
    }
    http.end();
    g_sc.stop();
}

// ===================================================
// 📤 实时上传 XYZ 数据
// V7.14：局部 sc + stop() + Expect:"" 禁用100-continue（修复400）
// ===================================================
bool uploadXYZData() {
    if (!wifi_connected) return false;

    int upload_rows = getUploadRows();
    if (ring_count < upload_rows) {
        Serial.printf("⏳ 采样不足 %d/%d 行，等待缓冲...\n", ring_count, upload_rows);
        return false;
    }

    int body_max = 140 + upload_rows * 22 + 4;
    char* body_buf = (char*)malloc(body_max);
    if (!body_buf) {
        upload_rows = 300;
        body_max    = 140 + upload_rows * 22 + 4;
        body_buf    = (char*)malloc(body_max);
        Serial.printf("⚠️  内存不足，降级上传 %d 行\n", upload_rows);
        if (!body_buf) {
            Serial.println("❌ 上传中止：malloc 二次失败");
            return false;
        }
    }

    int start_idx = (ring_head - upload_rows * 3 + RING_BUF_SIZE * 3) % (RING_BUF_SIZE * 3);
    int pos = snprintf(body_buf, body_max,
        "{\"device_id\":\"%s\",\"key\":\"%s\","
        "\"species\":\"%s\",\"battery\":%d,"
        "\"timestamp\":%ld,\"samples\":[",
        DEVICE_ID, DEVICE_KEY, current_species, battery_level, (long)time(nullptr));

    for (int i = 0; i < upload_rows; i++) {
        int idx = (start_idx + i * 3) % (RING_BUF_SIZE * 3);
        pos += snprintf(body_buf + pos, body_max - pos,
            "%s[%.2f,%.2f,%.2f]",
            i > 0 ? "," : "",
            ring_buf[idx], ring_buf[idx+1], ring_buf[idx+2]);
    }
    pos += snprintf(body_buf + pos, body_max - pos, "]}");

    Serial.printf("📦 [V7.18] 上传body: %d字节 / %d行 | 堆可用: %d bytes\n",
                  pos, upload_rows, (int)ESP.getFreeHeap());

    resetSSL();  // V7.18: 300ms 延迟确保 TCP FIN 完成
    HTTPClient http;
    http.begin(g_sc, server_url + "/api/upload");
    http.addHeader("Content-Type", "application/json");
    http.addHeader("Expect", "");
    http.setTimeout(20000);
    int code = http.POST((uint8_t*)body_buf, (size_t)pos);
    http.end();
    g_sc.stop();
    free(body_buf);

    if (code == 200 || code == 202) {
        Serial.printf("📤 上传成功 (HTTP %d) [%s / %dHz / %d行]\n",
                      code, current_species, current_sample_rate_hz, upload_rows);
        return true;
    }
    Serial.printf("❌ 上传失败 (HTTP %d) [%s / %dHz / %d行]\n",
                  code, current_species, current_sample_rate_hz, upload_rows);
    return false;
}

// ===================================================
// 💾 离线存储
// ===================================================
void saveOfflineData() {
    int upload_rows = getUploadRows();
    if (ring_count < upload_rows) return;

    int pkt_size = 5 + upload_rows * 3 * 2;
    size_t current_offline_size = 0;
    File fc = LittleFS.open(OFFLINE_FILE, "r");
    if (fc) { current_offline_size = fc.size(); fc.close(); }
    int current_packets = (pkt_size > 0) ? (int)(current_offline_size / pkt_size) : 0;

    if (current_packets >= OFFLINE_MAX_PACKETS) {
        Serial.printf("⚠️  离线存储已达上限（%d包），停止写入\n", OFFLINE_MAX_PACKETS);
        return;
    }

    time_t now = time(nullptr);
    File f = LittleFS.open(OFFLINE_FILE, "a");
    if (!f) { Serial.println("❌ 离线文件打开失败"); return; }

    f.write((uint8_t*)&now, 4);
    f.write((uint8_t*)&battery_level, 1);

    int start_idx = (ring_head - upload_rows * 3 + RING_BUF_SIZE * 3) % (RING_BUF_SIZE * 3);
    for (int i = 0; i < upload_rows * 3; i++) {
        int idx   = (start_idx + i) % (RING_BUF_SIZE * 3);
        int16_t v = (int16_t)(ring_buf[idx] * 100);
        f.write((uint8_t*)&v, 2);
    }
    f.close();
    Serial.printf("💾 离线已保存（%d/%d包，Flash：%d%%）\n",
                  current_packets + 1, OFFLINE_MAX_PACKETS, getFlashUsePct());
}

// ===================================================
// 📦 离线上传
// V7.14：局部 sc + stop() + Expect:"" 禁用100-continue（修复400）
// ===================================================
void uploadOfflineData() {
    if (!wifi_connected) return;
    // V7.15: NTP 未同步时 time()≈0，mbedTLS 证书时间校验失败 → HTTP -3/-1
    if (!time_synced) {
        Serial.println("⏱️  离线上传跳过：NTP 尚未同步，等待时间就绪（避免SSL握手失败）");
        _pending_offline_up = true;  // 保留 pending，下次心跳后再试
        return;
    }
    File f = LittleFS.open(OFFLINE_FILE, "r");
    if (!f || f.size() < 5) { if (f) f.close(); return; }

    // V7.16: 离线上传前切换到 background 节奏（60s），避免 realtime 5s 心跳
    // 超时导致服务器端 RST 连接 → HTTP -3
    int saved_interval = upload_interval_ms;
    upload_interval_ms = 60000;
    Serial.println("📦 离线上传：临时切换 interval→60s，防止心跳超时干扰");

    int upload_rows = getUploadRows();
    Serial.printf("📦 开始上传离线数据（%d B）...\n", (int)f.size());
    const int PKT = 5 + upload_rows * 3 * 2;
    int total        = f.size() / PKT;
    int uploaded     = 0;
    int skipped      = 0;
    int consec_fails = 0;
    const int MAX_RETRY  = 3;
    const int MAX_CONSEC = 5;

    while (f.available() >= PKT) {
        uint32_t ts; uint8_t bat;
        f.read((uint8_t*)&ts, 4);
        f.read(&bat, 1);

        int body_max = 140 + upload_rows * 22 + 4;
        char* body_buf = (char*)malloc(body_max);
        if (!body_buf) {
            for (int i = 0; i < upload_rows; i++) {
                int16_t xv,yv,zv;
                f.read((uint8_t*)&xv,2); f.read((uint8_t*)&yv,2); f.read((uint8_t*)&zv,2);
            }
            skipped++; consec_fails++;
            Serial.println("⚠️  malloc失败，跳过该离线包");
            if (consec_fails >= MAX_CONSEC) break;
            continue;
        }

        int pos = snprintf(body_buf, body_max,
            "{\"device_id\":\"%s\",\"key\":\"%s\","
            "\"species\":\"%s\",\"battery\":%d,"
            "\"timestamp\":%lu,\"offline\":true,\"samples\":[",
            DEVICE_ID, DEVICE_KEY, current_species, bat, (unsigned long)ts);

        for (int i = 0; i < upload_rows; i++) {
            int16_t xv, yv, zv;
            f.read((uint8_t*)&xv, 2);
            f.read((uint8_t*)&yv, 2);
            f.read((uint8_t*)&zv, 2);
            pos += snprintf(body_buf + pos, body_max - pos,
                "%s[%.2f,%.2f,%.2f]",
                i > 0 ? "," : "",
                xv/100.0f, yv/100.0f, zv/100.0f);
        }
        pos += snprintf(body_buf + pos, body_max - pos, "]}");

        // 重试循环：每次重试独立创建 SSL，确保连接干净
        bool ok = false;
        for (int attempt = 1; attempt <= MAX_RETRY; attempt++) {
        resetSSL();  // V7.18: 300ms 延迟，每次重试都是干净连接
            HTTPClient http;
            http.begin(g_sc, server_url + "/api/upload");
            http.addHeader("Content-Type", "application/json");
            http.addHeader("Expect", "");
            http.setTimeout(20000);
            Serial.printf("📦 [离线] 包%d/%d: %d字节 | 堆: %d\n",
                          uploaded+skipped+1, total, pos, (int)ESP.getFreeHeap());
            int code = http.POST((uint8_t*)body_buf, (size_t)pos);
            http.end();

            if (code == 200 || code == 202) {
                ok = true;
                g_sc.stop();
                break;
            } else {
                Serial.printf("⚠️  离线包失败 (HTTP %d) 第%d/%d次\n", code, attempt, MAX_RETRY);
                g_sc.stop();
                if (attempt < MAX_RETRY) delay(2000);
            }
        }
        free(body_buf);

        if (ok) {
            uploaded++;
            consec_fails = 0;
        } else {
            skipped++;
            consec_fails++;
            Serial.printf("⏭️  跳过包（已跳%d包，连续失败%d次）\n", skipped, consec_fails);
            if (consec_fails >= MAX_CONSEC) {
                Serial.printf("🔴 连续失败%d次，网络异常，暂停上传\n", MAX_CONSEC);
                break;
            }
        }

        // V7.16: 包间发一次心跳，保持服务器连接活跃，防止 OpenResty RST
        sendHeartbeat();
        delay(1500);  // 包间延迟 1500ms，给 TCP 连接充分恢复
    }
    f.close();

    // V7.16: 恢复原始 upload_interval_ms（让下次心跳重新协商实时/后台模式）
    upload_interval_ms = saved_interval;
    Serial.printf("📦 离线上传结束，interval 恢复→%ds\n", upload_interval_ms / 1000);

    if (skipped == 0 && uploaded > 0) {
        LittleFS.remove(OFFLINE_FILE);
        Serial.printf("✅ 离线数据全部上传（%d/%d 包），已清除\n", uploaded, total);
    } else if (uploaded > 0) {
        Serial.printf("⚠️  离线数据部分上传（成功%d / 跳过%d / 总%d 包）\n",
                      uploaded, skipped, total);
    } else {
        Serial.printf("❌ 离线数据上传全部失败，保留文件等待重试\n");
    }
}

// ===================================================
// 📻 BLE 配网回调
// ===================================================
class BLEConfigCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pChar) {
        String msg = pChar->getValue().c_str();
        msg.trim();
        String upper = msg;
        upper.toUpperCase();
        Serial.println("📥 BLE 收到：" + msg);

        if (upper.startsWith("WIFI:")) {
            String content = msg.substring(5);
            int c1 = content.indexOf(':');
            int c2 = content.indexOf(':', c1 + 1);
            if (c1 < 0) { pChar->setValue("FAIL:FORMAT\n"); pChar->notify(); return; }

            String new_ssid = content.substring(0, c1);
            String new_pass = (c2 < 0) ? content.substring(c1 + 1) : content.substring(c1 + 1, c2);
            String new_srv  = (c2 < 0) ? SERVER_DEFAULT : content.substring(c2 + 1);

            Serial.printf("🔧 配网 SSID=%s  SERVER=%s\n", new_ssid.c_str(), new_srv.c_str());
            WiFi.disconnect(); delay(500);
            bool ok = connectWiFi(new_ssid, new_pass, 20);

            if (ok) {
                prefs.begin("calmpaws", false);
                prefs.putString("ssid", new_ssid);
                prefs.putString("pass", new_pass);
                prefs.putString("srv",  new_srv);
                prefs.end();
                wifi_ssid = new_ssid; wifi_password = new_pass;
                server_url = new_srv; wifi_connected = true;
                _pending_ntp        = true;
                _pending_offline_up = true;
                pChar->setValue("OK\n"); pChar->notify();
                Serial.println("✅ 配网成功！");
                // V7.19：配网成功后 delay 200ms 确保 BLE 通知发出，
                // 再停止 BLE/BT，释放 ~20KB 堆供 SSL 握手使用
                delay(200);
                BLEDevice::deinit(true);
                btStop();
                Serial.printf("🔵 BLE 已停止，释放堆内存。当前可用堆: %d bytes\n",
                              (int)ESP.getFreeHeap());
            } else {
                pChar->setValue("FAIL:WIFI\n"); pChar->notify();
            }
        }
        else if (upper.startsWith("TIME:")) {
            long ts = upper.substring(5).toInt();
            if (ts > 1000000000L) {
                struct timeval tv = { ts, 0 };
                settimeofday(&tv, NULL);
                time_synced = true;
                pChar->setValue("TIME_OK\n"); pChar->notify();
                Serial.printf("⏱️  BLE 时间校准：%ld\n", ts);
            }
        }
        else if (upper == "STATUS") {
            String s = "{\"wifi\":\"" + (wifi_connected ? WiFi.localIP().toString() : String("disconnected"))
                     + "\",\"server\":\"" + server_url
                     + "\",\"species\":\"" + String(current_species) + "\""
                     + "\",\"sample_rate\":" + String(current_sample_rate_hz)
                     + ",\"battery\":" + String(battery_level) + "}\n";
            pChar->setValue(s.c_str()); pChar->notify();
        }
    }
};

class BLEConnCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* s) {
        ble_client_connected = true;
        Serial.println("📱 BLE 手机已连接");
    }
    void onDisconnect(BLEServer* s) {
        ble_client_connected = false;
        Serial.println("📱 BLE 手机已断开，重新广播...");
        BLEDevice::startAdvertising();
    }
};

void initBLE() {
    BLEDevice::init("CalmPaws_Config");
    BLEDevice::setMTU(512);
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new BLEConnCallbacks());
    BLEService* svc = pServer->createService(SERVICE_UUID);
    pCharacteristic = svc->createCharacteristic(
        CHARACTERISTIC_UUID,
        BLECharacteristic::PROPERTY_READ  |
        BLECharacteristic::PROPERTY_NOTIFY |
        BLECharacteristic::PROPERTY_WRITE
    );
    pCharacteristic->addDescriptor(new BLE2902());
    pCharacteristic->setCallbacks(new BLEConfigCallbacks());
    svc->start();
    BLEAdvertising* adv = BLEDevice::getAdvertising();
    adv->addServiceUUID(SERVICE_UUID);
    adv->setScanResponse(true);
    BLEDevice::startAdvertising();
    Serial.println("📻 BLE 广播已启动，设备名：CalmPaws_Config");
}

// ===================================================
// setup()
// ===================================================
void setup() {
    Serial.begin(115200);
    delay(2000);

    Serial.println("\n╔══════════════════════════════════════════╗");
    Serial.println("║  CalmPaws Collar V7.17 (测试阶段)        ║");
    Serial.println("╚══════════════════════════════════════════╝\n");

    pinMode(SWITCH_PIN, INPUT_PULLUP);
    bool sw_now = digitalRead(SWITCH_PIN);
    Serial.printf("🔘 拨动开关当前状态：【%s】\n", sw_now == LOW ? "ON（导通）" : "OFF（断开）");

    pinMode(BAT_PIN, INPUT);
    battery_level = getBatteryLevel();

    if (!LittleFS.begin(true)) {
        Serial.println("❌ LittleFS 挂载失败");
    } else {
        Serial.printf("✅ LittleFS 挂载成功（总：%d B，已用：%d B）\n",
            (int)LittleFS.totalBytes(), (int)LittleFS.usedBytes());
    }

    prefs.begin("calmpaws", true);
    wifi_ssid     = prefs.getString("ssid", "");
    wifi_password = prefs.getString("pass", "");
    server_url    = prefs.getString("srv",  SERVER_DEFAULT);
    String saved_species = prefs.getString("species", "dog");
    prefs.end();

    strncpy(current_species, saved_species.c_str(), sizeof(current_species) - 1);
    current_species[sizeof(current_species) - 1] = '\0';
    Serial.printf("📌 服务器地址：%s\n", server_url.c_str());
    Serial.printf("🐾 物种配置：%s\n", current_species);

    Wire.begin(4, 5);
    Wire.setClock(100000);
    delay(500);
    if (!imu.begin_I2C(0x6B)) {
        if (!imu.begin_I2C(0x6A)) {
            Serial.println("❌ IMU 初始化失败！请检查接线");
            while (1) delay(100);
        }
    }
    imu.setAccelRange(LSM6DS_ACCEL_RANGE_4_G);
    imu.setGyroRange(LSM6DS_GYRO_RANGE_2000_DPS);

    if (strcmp(current_species, "cat") == 0) {
        imu.setAccelDataRate(LSM6DS_RATE_26_HZ);
        current_sample_rate_hz = SAMPLE_RATE_HZ_CAT;
        sample_interval_ms     = 1000 / SAMPLE_RATE_HZ_CAT;
        Serial.println("✅ IMU 初始化成功（26Hz 猫模式）");
    } else {
        imu.setAccelDataRate(LSM6DS_RATE_104_HZ);
        current_sample_rate_hz = SAMPLE_RATE_HZ_DOG;
        sample_interval_ms     = 1000 / SAMPLE_RATE_HZ_DOG;
        Serial.println("✅ IMU 初始化成功（104Hz 狗模式）");
    }

    initBLE();

    if (wifi_ssid.length() > 0) {
        wifi_connected = connectWiFi(wifi_ssid, wifi_password, 15);
        if (wifi_connected) {
            // V7.19：已有保存的WiFi，连接成功后立即停BLE，释放~20KB堆
            BLEDevice::deinit(true);
            btStop();
            Serial.printf("🔵 BLE 已停止（已有WiFi配置），可用堆: %d bytes\n",
                          (int)ESP.getFreeHeap());
            _pending_ntp        = true;
            _pending_offline_up = true;
            Serial.println("✅ WiFi 已连接，NTP 同步和离线上传将在 loop() 中执行");
        }
    } else {
        Serial.println("⚠️  尚未配置 WiFi，请用 APP 蓝牙配网");
    }

    Serial.printf("\n🚀 开始采样（%dHz，%s模式）...\n\n",
                  current_sample_rate_hz, current_species);
}

// ===================================================
// loop()
// ===================================================
void loop() {
    unsigned long now = millis();

    // ① 拨动开关
    checkSwitch();

    // ② 传感器采样
    if (now - last_sample_time >= (unsigned long)sample_interval_ms) {
        last_sample_time = now;
        sensors_event_t accel, gyro, temp;
        imu.getEvent(&accel, &gyro, &temp);
        int idx = ring_head;
        ring_buf[idx]   = accel.acceleration.x;
        ring_buf[idx+1] = accel.acceleration.y;
        ring_buf[idx+2] = accel.acceleration.z;
        ring_head  = (ring_head + 3) % (RING_BUF_SIZE * 3);
        if (ring_count < RING_BUF_SIZE) ring_count++;
    }

    // ③ WiFi 状态同步 + 重连
    bool hw_connected = (WiFi.status() == WL_CONNECTED);
    if (hw_connected && !wifi_connected) {
        wifi_connected = true;
        Serial.println("✅ WiFi 底层已连接，软件标志同步");
        _pending_ntp        = true;
        _pending_offline_up = true;
    } else if (!hw_connected && wifi_connected) {
        wifi_connected = false;
        Serial.println("⚠️  WiFi 断开，每15秒自动重连");
    } else if (!hw_connected && !wifi_connected) {
        if (wifi_ssid.length() > 0) {
            static unsigned long last_reconnect = 0;
            if (now - last_reconnect >= 15000UL) {
                last_reconnect = now;
                Serial.printf("🔄 尝试连接WiFi：%s\n", wifi_ssid.c_str());
                if (connectWiFi(wifi_ssid, wifi_password, 15)) {
                    wifi_connected = true;
                    _pending_ntp        = true;
                    _pending_offline_up = true;
                }
            }
        }
    }

    // ④ 心跳（固定 5 秒）
    // V7.18: 用 did_heartbeat 标记本帧是否执行了心跳，
    //        避免同一 loop() 迭代中心跳+上传连续触发导致 TCP FIN 竞争
    bool did_heartbeat = false;
    if (wifi_connected && now - last_heartbeat_time >= HEARTBEAT_INTERVAL_MS) {
        last_heartbeat_time = now;
        sendHeartbeat();
        did_heartbeat = true;
    }

    // ④.5 待执行任务：NTP → 离线上传
    if (wifi_connected && _pending_ntp) {
        _pending_ntp = false;
        Serial.println("⏱️  [pending] 开始 NTP 同步...");
        syncNTP();
    }
    if (wifi_connected && _pending_offline_up && !_pending_ntp) {
        if (!time_synced) {
            // NTP 还没就绪，本次 loop 跳过，保留 pending 等下次
            static unsigned long last_ntp_warn = 0;
            if (millis() - last_ntp_warn > 5000) {
                last_ntp_warn = millis();
                Serial.println("⏱️  等待 NTP 就绪后再上传离线数据...");
                syncNTP();  // 主动再试一次
            }
        } else {
            _pending_offline_up = false;
            Serial.println("⏳  [pending] 等待 3s 后开始离线数据上传...");
            delay(3000);
            Serial.println("📦  [pending] 开始上传离线数据...");
            uploadOfflineData();
        }
    }

    // ⑤ 数据上传
    int eff_interval = upload_interval_ms;
    if (getFlashUsePct() > FLASH_WARN_PCT) eff_interval = FLASH_EMERG_INTERVAL_MS;

    if (now - last_upload_time >= (unsigned long)eff_interval) {
        last_upload_time = now;
        if (wifi_connected) {
            // V7.18: 若本帧刚执行了心跳，等 600ms 让 TCP FIN 彻底完成
            // 这是修复 realtime 5s 模式下心跳/上传同帧触发导致 HTTP -3 的关键
            if (did_heartbeat) {
                Serial.println("⏳ [V7.18] 心跳后等 600ms 再上传（防 TCP FIN 竞争）");
                delay(600);
            }
            uploadXYZData();
        } else {
            saveOfflineData();
        }
    }

    // ⑥ 电量检测（每 60 秒）
    if (now - last_bat_check_time >= BAT_CHECK_INTERVAL_MS) {
        last_bat_check_time = now;
        battery_level = getBatteryLevel();
        if (battery_level <= 5) {
            Serial.println("🔴 电量极低（≤5%）！停止上传，仅本地保存");
            wifi_connected = false;
        } else if (battery_level <= 20) {
            Serial.println("🟡 电量低（≤20%），请尽快充电");
        }
    }

    // ⑦ NTP 每小时重新同步
    static unsigned long last_ntp_sync = 0;
    if (wifi_connected && now - last_ntp_sync >= 3600000UL) {
        last_ntp_sync = now;
        syncNTP();
    }
}
