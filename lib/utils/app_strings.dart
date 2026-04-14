/// Centralized localization strings for Petoteco
/// Supports: English (en) and Chinese Simplified (zh)
/// Usage: S.of(context).appName
/// Toggle: context.read<LocaleProvider>().toggle()

class AppStrings {
  final String locale;
  const AppStrings._(this.locale);

  static const AppStrings en = AppStrings._('en');
  static const AppStrings zh = AppStrings._('zh');

  factory AppStrings.of(String locale) =>
      locale == 'zh' ? zh : en;

  // ── App ──────────────────────────────────────────────────────────────────
  String get appName => _t('Petoteco', 'Petoteco');

  // ── Greetings ─────────────────────────────────────────────────────────────
  String get greetingMorning => _t('Morning', '早上好');
  String get greetingAfternoon => _t('Afternoon', '下午好');
  String get greetingEvening => _t('Evening', '晚上好');

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  String get navHealth => _t('Health', '健康');
  String get navMyPet => _t('My Pet', '宠物');
  String get navShop => _t('Shop', '商城');
  String get navMe => _t('Me', '我的');

  // ── Dashboard ─────────────────────────────────────────────────────────────
  String get deviceLive => _t('ZenBelly Collar · Live', 'ZenBelly 项圈 · 实时');
  String get deviceOffline => _t('No Device Connected', '设备未连接');
  String get deviceConnect => _t('Connect', '连接');
  String get deviceBle => _t('BLE', '蓝牙');

  // ── Feeding Timer ─────────────────────────────────────────────────────────
  String get timerTitle => _t('ZenBelly Tracker', 'ZenBelly 追踪器');
  String get timerSubtitle => _t('Calm Response Timer', '平静响应计时器');
  String get timerDesc => _t(
    'Tap after giving ZenBelly to start tracking how quickly your pup returns to calm.',
    '喂食 ZenBelly 后点击，记录爱宠恢复平静所需的时间。',
  );
  String get timerStart => _t('Fed ZenBelly — Start Timer', '已喂食 — 开始计时');
  String get timerActive => _t('Calm Tracker Active', '平静追踪中');
  String get timerCancel => _t('Cancel', '取消');
  String get timerElapsed => _t('elapsed', '已计时');
  String get timerCalmProgress => _t('Calm Progress', '平静进度');
  String timerCalmPct(int v) => _t('$v% calm', '$v% 平静');
  String get timerLastSession => _t('Last session:', '上次记录：');
  String get timerToCalm => _t('to calm', '恢复平静');
  String get timerNoSession => _t('No sessions yet', '暂无记录');
  String get timerNoSessionDesc => _t(
    'Tap "Fed ZenBelly" above to start tracking how fast your pet calms down.',
    '点击上方"已喂食"按钮，开始记录爱宠平静时间。',
  );
  // Milestone labels
  String get milestoneJustGiven => _t('Just given', '刚服用');
  String get milestoneAbsorbing => _t('Absorbing', '吸收中');
  String get milestoneSettling => _t('Settling', '趋平静');
  String get milestoneCalm => _t('Calm!', '平静了！');
  // Behavior labels in progress bar
  String get behaviorAnxious => _t('Anxious', '焦虑');
  String get behaviorSettling => _t('Settling', '平静中');
  String get behaviorCalm => _t('Calm', '平静');

  // ── Behavior States ───────────────────────────────────────────────────────
  String get stateCalm => _t('Calm & Relaxed', '平静放松');
  String get stateCalmDesc => _t('Biscuit is resting comfortably', '正在舒适地休息');
  String get statePacing => _t('Anxious Pacing', '焦虑踱步');
  String get statePacingDesc => _t('Repetitive movement detected', '检测到重复性踱步');
  String get stateStressed => _t('Stressed', '应激状态');
  String get stateStressedDesc => _t('High stress behavior detected', '检测到高压应激行为');
  String get statePlaying => _t('Playing', '玩耍中');
  String get statePlayingDesc => _t('Active, healthy movement!', '活力四射，健康玩耍！');
  String get stateShivering => _t('Shivering ⚠️', '发抖 ⚠️');
  String get stateSiveringDesc => _t('Possible pain, fear, or cold', '可能疼痛、恐惧或寒冷');
  String get stateSleeping => _t('Sleeping', '睡眠中');
  String get stateSleepingDesc => _t('Resting peacefully', '安静休眠中');
  String get rightNow => _t('Right Now: ', '当前状态：');

  // ── Mini Stats ────────────────────────────────────────────────────────────
  String get statStress => _t('Stress', '应激');
  String get statPacing => _t('Pacing', '踱步');
  String get statPlay => _t('Play', '玩耍');

  // ── Time-to-Calm Card ─────────────────────────────────────────────────────
  String get ttcTitle => _t('Time to Calm', '平静用时');
  String ttcSessions(int n) => _t('$n sessions', '$n 次记录');
  String get ttcMin => _t('min', '分钟');
  String ttcAvg(String v) => _t('avg $v min', '均值 $v 分钟');
  String get ttcWeekTrend => _t('↓ 12% this week', '本周降低 12%');
  String get ttcLastSession => _t('Last session · ', '上次 · ');
  String get ttcStressBefore => _t('Stress Before', '喂食前应激');
  String get ttcStressAfter => _t('Stress After', '喂食后应激');
  String get ttcEvents => _t('events', '次');

  // ── Stress Chart ──────────────────────────────────────────────────────────
  String get chartTitle => _t('Stress Reduction', '应激减少趋势');
  String get chartSubtitle => _t(
    '14-day trend · Before vs After ZenBelly',
    '14天行为趋势 · ZenBelly 服用前后对比',
  );
  String get chartLegendBefore => _t('Before treatment', '服用前');
  String get chartLegendAfter => _t('After ZenBelly', '服用后');
  String chartReduction(String v) => _t('↓ $v%', '降低 $v%');

  // ── Status Cards ──────────────────────────────────────────────────────────
  String get cardSleep => _t('Last Night Sleep', '昨夜睡眠');
  String get cardSleepOk => _t('✅ Healthy restful sleep', '✅ 睡眠质量良好');
  String get cardSleepBad => _t('⚠️ Restless night', '⚠️ 夜间躁动');
  String get cardAnxiety => _t('Today\'s Anxiety', '今日焦虑');
  String get cardAnxietyVsYday => _t('vs yday', '较昨日');
  String get cardAnxietyLess => _t('✅ Less anxious today', '✅ 今日焦虑减少');
  String get cardAnxietyMore => _t('⚠️ More anxious today', '⚠️ 今日焦虑增加');
  String get cardActivity => _t('Activity Score', '活力评分');
  String get cardActivityOut => _t('/ 100', '/ 100');
  String get cardActivityOk => _t('✅ Normal vitality', '✅ 活力正常');
  String get cardActivityLow => _t('⚠️ Low activity', '⚠️ 活力偏低');
  String get cardStress => _t('Stress Events', '应激事件');
  String get cardStressWindow => _t('this window', '本次窗口');
  String get cardStressOk => _t('✅ Under control', '✅ 控制良好');
  String get cardStressHigh => _t('⚠️ Elevated stress', '⚠️ 应激偏高');

  // ── Alert ─────────────────────────────────────────────────────────────────
  String alertShiver(String name, int sec) => _t(
    '⚠️ $name has been shivering for over ${sec}s. Check for pain, cold, or fear.',
    '⚠️ $name 已持续发抖超 ${sec} 秒，请检查是否疼痛、寒冷或恐惧。',
  );
  String alertActivity(String name) => _t(
    '⚠️ ${name}\'s activity is 30% below normal. Consider a vet check.',
    '⚠️ $name 今日活动量低于均值 30%，建议咨询兽医。',
  );

  // ── Journal ───────────────────────────────────────────────────────────────
  String get journalTitle => _t('Daily Journal', '每日日记');
  String get journalLoggedToday => _t('✅ Logged today', '✅ 今日已记录');
  String get journalQuestion => _t('How is Biscuit doing today?', '今天 Biscuit 状态如何？');
  String get journalFullEntry => _t('Full Journal Entry', '完整日记记录');
  String get journalSaved => _t('Journal entry saved!', '日记已保存！');
  String get journalTodayTitle => _t('📓 Today\'s Journal', '📓 今日日记');
  String get journalSave => _t('Save Journal', '保存日记');
  String get journalNotes => _t('Any observations? (optional)', '备注（可选）');
  String get journalMood => _t('Mood', '情绪');
  String get journalAppetite => _t('Appetite', '食欲');
  String get journalEnergy => _t('Energy', '精力');
  String get journalStool => _t('Stool', '粪便');
  // Quick mood labels
  String get moodHappy => _t('Happy', '开心');
  String get moodOkay => _t('Okay', '一般');
  String get moodAnxious => _t('Anxious', '焦虑');
  String get moodStressed => _t('Stressed', '应激');
  String get moodUnwell => _t('Unwell', '不适');

  // ── Pet Profile ───────────────────────────────────────────────────────────
  String get petTabTitle => _t('My Pet', '我的宠物');
  String get petHealthTags => _t('Health Tags', '健康标签');
  String get petNoTags => _t('No health tags added yet.', '暂未添加健康标签。');
  String get petDevice => _t('ZenBelly Collar', 'ZenBelly 项圈');
  String get petConnected => _t('● Connected', '● 已连接');
  String get petOffline => _t('○ Offline', '○ 未连接');
  String get petBattery => _t('Battery', '电量');
  String get petSignal => _t('Signal', '信号');
  String get petSync => _t('Sync', '同步');
  String get petSyncLive => _t('Live', '实时');
  String get petSignalGood => _t('Good', '良好');
  String get petAnxietySlider => _t('Demo: Simulate Anxiety', '演示模式：模拟焦虑');
  String get petAnxietySliderDesc =>
      _t('Drag to preview how the app responds to anxiety levels', '拖动滑块，预览不同焦虑程度时 App 的显示效果');
  String get petDemoTag => _t('DEMO', '演示');
  String get petDisconnect => _t('Disconnect Device', '断开设备');
  String get petConnectBtn => _t('Connect Device', '连接设备');
  String get petJournalHistory => _t('Journal History', '日记历史');
  String get petNoJournal => _t('No journal entries yet.', '暂无日记记录。');
  String get petEditTitle => _t('Edit Pet Profile', '编辑宠物档案');
  String get petNameLabel => _t('Pet Name', '宠物名称');
  String get petSave => _t('Save Changes', '保存修改');

  // ── Shop ──────────────────────────────────────────────────────────────────
  String get shopTitle => _t('Shop', '商城');
  String get shopSubtitle => _t('ZenBelly products', 'ZenBelly 产品');
  String get shopBestSeller => _t('⭐ Best Seller', '⭐ 热销');
  String get shopProductName => _t('ZenBelly\nCalm Chews', 'ZenBelly\n舒缓软糖');
  String get shopProductDesc => _t('No CBD · Probiotic-based\nAnxiety relief for dogs', '无 CBD · 益生菌配方\n狗狗情绪舒缓');
  String get shopNow => _t('Shop Now', '立即购买');
  String get shopBundle => _t('Starter Bundle', '入门套装');
  String get shopBundleDesc =>
      _t('3x ZenBelly + Smart Collar\n6-month FREE app access', '3罐 ZenBelly + 智能项圈\n6个月免费使用APP');
  String get shopAllProducts => _t('All Products', '全部产品');
  String get shopVisitStore =>
      _t('Visit Full Store at petoteco.com', '访问独立站 petoteco.com');
  String get shopOpenTitle => _t('Open Petoteco Store', '打开 Petoteco 商城');
  String get shopOpenDesc => _t(
    'This will open the full store in your browser.\n\nIn the live app, this opens your Shopify store in a seamless WebView with your login automatically synced.',
    '即将在浏览器中打开完整商城。\n\n正式版 APP 中，将以 WebView 无缝嵌入 Shopify 独立站，并自动同步登录状态。',
  );
  String get shopOpenBtn => _t('Open Store', '打开商城');

  // ── Profile ───────────────────────────────────────────────────────────────
  String get profileTitle => _t('Me', '我的');
  String get profileSubscriber => _t('✅ Pro Subscriber', '✅ 专业订阅用户');
  String get profilePlan => _t('Plan', '套餐');
  String get profilePlanValue => _t('Pro · \$4.99/mo', '专业版 · \$4.99/月');
  String get profileNextBilling => _t('Next Billing', '下次扣费');
  String get profileNextBillingDate => _t('Aug 14, 2025', '2025年8月14日');
  String get profileDaysLeft => _t('23 days left', '还剩 23 天');
  String get profileZenBelly => _t('ZenBelly', '软糖余量');
  String get profileManage => _t('Manage', '管理');
  String get profileReorder => _t('Reorder', '续订');
  String get profileOrders => _t('Order History', '订单历史');
  String get profileSupport => _t('Customer Support', '客服支持');
  String get profileSupportBadge => _t('Chat', '在线');
  String get profileDeviceGuide => _t('Device Setup Guide', '设备使用指南');
  String get profileReports => _t('Health Reports', '健康报告');
  String get profileNotifications => _t('Notifications', '消息通知');
  String get profilePrivacy => _t('Privacy & Data', '隐私与数据');
  String get profileSignOut => _t('Sign Out', '退出登录');
  String get profileLanguage => _t('Language / 语言', 'Language / 语言');
  // Subscription management sheet
  String get subSheetTitle => _t('Manage Subscription', '管理订阅');
  String subSheetBody(String name) =>
      _t('You\'re making a difference for $name\'s wellbeing 🐾', '你在为 $name 的健康作出改变 🐾');
  String get subProgress => _t('📊 Your Health Progress This Month', '📊 本月健康进展');
  String get subAnxiety => _t('Anxiety events reduced', '焦虑事件减少');
  String get subTtc => _t('Time to calm improved', '平静用时缩短');
  String get subSleep => _t('Sleep quality increased', '睡眠质量提升');
  String get subWarning => _t(
    'Pausing now means losing 34 days of behavioral baseline data.',
    '暂停将导致 34 天行为基线数据丢失。',
  );
  String get subPause => _t('Pause for 1 Month Instead', '改为暂停 1 个月');
  String get subCancel => _t('Cancel Subscription', '取消订阅');
  // Support dialog
  String get supportTitle => _t('💬 Customer Support', '💬 客服支持');
  String get supportDesc => _t(
    'In the live app, this opens Crisp or Intercom live chat embedded inside the app, with your account pre-loaded.',
    '正式版 APP 中将嵌入 Crisp/Intercom 在线客服，账户信息自动加载。',
  );
  String get supportResponse => _t('Response time: Usually < 2 hours', '响应时间：通常 2 小时内');
  String get supportChat => _t('Start Chat', '开始聊天');
  // Device guide
  String get guideTitle => _t('📡 Device Setup Guide', '📡 设备使用指南');
  String get guideStep1 => _t('Charge the ZenBelly collar for 2 hours before first use', '首次使用前充电 2 小时');
  String get guideStep2 => _t('Enable Bluetooth on your phone', '开启手机蓝牙');
  String get guideStep3 => _t('Hold your phone within 30cm of the collar', '手机靠近项圈 30cm 以内');
  String get guideStep4 => _t('Tap "Connect Device" in the My Pet tab', '在"宠物"页点击"连接设备"');
  String get guideStep5 => _t('Attach collar to pet — not too tight, 2-finger gap', '佩戴项圈，保留两指宽松度');
  String get guideStep6 => _t('Data will begin syncing within 30 seconds', '30 秒内数据开始同步');
  String get guideGotIt => _t('Got it!', '明白了！');
  // Sign out
  String get signOutTitle => _t('Sign Out', '退出登录');
  String get signOutConfirm => _t('Are you sure you want to sign out?', '确定要退出登录吗？');
  String get signOutBtn => _t('Sign Out', '退出');
  // Reorder dialog
  String get reorderBody => _t(
    'In the live app, this will open the store to reorder ZenBelly supplies with your subscription discount applied.',
    '正式版 APP 中，将打开商城以订阅折扣价续购 ZenBelly 产品。',
  );

  // Subscription section labels
  String get subLabel => _t('Subscription', '订阅');
  String get subActive => _t('Active ✓', '已激活 ✓');

  // Notifications dialog
  String get notifSettingsBody => _t(
    'Notification settings will be available in the full release.',
    '消息通知设置将在正式版本中开放。',
  );

  // Privacy dialog
  String get privacyBody => _t(
    'Your data is stored locally and never sold. Full privacy policy available at petoteco.com/privacy',
    '您的数据仅存储在本地，不会被出售。完整隐私政策请访问 petoteco.com/privacy',
  );

  // Session report (health reports dialog)
  String sessionMinToCalm(String mins) => _t('$mins min to calm', '$mins 分钟恢复平静');

  // Cancel timer dialog
  String get timerCancelBody => _t(
    'This will discard the current timing session. Are you sure?',
    '这将丢弃当前的计时记录，确定要取消吗？',
  );
  String get timerKeepTracking => _t('Keep Tracking', '继续计时');

  // Shop unit
  String get shopPerBag => _t('/bag', '/袋');

  // OK button
  String get ok => _t('OK', '好的');

  // Common
  String get cancel => _t('Cancel', '取消');
  String get close => _t('Close', '关闭');
  String get gotIt => _t('Got it!', '好的！');

  // ── Time Labels ───────────────────────────────────────────────────────────
  String get today => _t('Today', '今天');
  String get yesterday => _t('Yesterday', '昨天');
  String daysAgo(int d) => _t('${d}d ago', '$d 天前');
  String hoursAgo(int h) => _t('${h}h ago', '$h 小时前');
  String minutesAgo(int m) => _t('${m}m ago', '$m 分钟前');

  // ── Pet breeds ────────────────────────────────────────────────────────────
  // 常见犬猫品种翻译（仅 zh 时翻译，en 原样返回）
  String translateBreed(String breed) {
    if (locale != 'zh') return breed;
    const map = {
      'Golden Retriever': '金毛寻回犬',
      'Labrador Retriever': '拉布拉多犬',
      'French Bulldog': '法国斗牛犬',
      'German Shepherd': '德国牧羊犬',
      'Poodle': '贵宾犬',
      'Beagle': '比格犬',
      'Chihuahua': '吉娃娃',
      'Shih Tzu': '西施犬',
      'Border Collie': '边境牧羊犬',
      'Husky': '哈士奇',
      'Corgi': '柯基犬',
      'Samoyed': '萨摩耶',
      'Shiba Inu': '柴犬',
      'Persian': '波斯猫',
      'British Shorthair': '英国短毛猫',
      'Maine Coon': '缅因猫',
      'Mixed Breed': '混血犬',
      'Unknown': '未知品种',
    };
    return map[breed] ?? breed;
  }

  // 年龄标签本地化
  String ageLabelLocalized(int ageMonths) {
    if (ageMonths < 12) {
      return _t('${ageMonths}mo', '$ageMonths 月');
    }
    final years = ageMonths ~/ 12;
    final months = ageMonths % 12;
    if (months == 0) {
      return _t('${years}y', '$years 岁');
    }
    return _t('${years}y ${months}mo', '$years 岁 $months 月');
  }

  // 物种本地化
  String translateSpecies(String species) {
    if (locale != 'zh') return species;
    return species == 'dog' ? '狗狗' : species == 'cat' ? '猫咪' : species;
  }

  // ── Health Tags ───────────────────────────────────────────────────────────
  String translateTag(String tag) {
    const tagMap = {
      'Separation Anxiety': '分离焦虑',
      'Joint Stiffness': '关节僵硬',
      'Digestive Issues': '消化问题',
      'Skin Allergies': '皮肤过敏',
      'Food Sensitivity': '食物敏感',
      'Noise Phobia': '噪声恐惧',
      'Hyperactivity': '过度活跃',
      'Weight Management': '体重管理',
      'Senior Care': '老年护理',
      'Post-Surgery': '术后恢复',
      'Dental Issues': '牙齿问题',
      'Heart Condition': '心脏疾病',
    };
    if (locale == 'zh') return tagMap[tag] ?? tag;
    return tag;
  }

  // ── Health Calendar ───────────────────────────────────────────────────────
  String get calendarTitle   => _t('Health Calendar', '健康日历');
  String get calendarSensor  => _t('Sensor', '传感器');
  String get calendarOwner   => _t('My Notes', '我的记录');
  String get calendarFed     => _t('ZenBelly ✓', '已喂食 ✓');
  String get calendarOffline => _t('Device offline', '设备离线');
  String get calendarNoEntry => _t('Not recorded', '未填写');
  String get calendarNoData  => _t('No data for this day', '当天暂无数据');
  String get calendarStress  => _t('Stress', '应激');
  String get calendarEvents  => _t('Events', '事件');
  String get calendarActivity=> _t('Activity', '活动');
  String get calendarTtc     => _t('To calm', '平静用时');
  String get calendarPts     => _t('pts', '分');
  String get calendarTimes   => _t('x', '次');
  String get calendarWriteJournal => _t('Write', '写日记');
  String get calendarTodayExists  => _t("Today's entry already saved. Saving again will add a new entry.", '今天已有记录，再次保存将新增一条。');

  // ── Order & Billing ────────────────────────────────────────────────────────
  String get orderDelivered => _t('Delivered', '已送达');
  String get orderShipped   => _t('Shipped', '已发货');
  String get orderPending   => _t('Processing', '处理中');

  /// 格式化日期：zh → "7月14日"，en → "Jul 14, 2025"
  String formatDate(DateTime d) {
    if (locale == 'zh') {
      return '${d.year}年${d.month}月${d.day}日';
    }
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  // ── Pet Device Demo Slider ─────────────────────────────────────────────────
  String get petAnxietySliderHint =>
      _t('Demo only — real data comes from the collar sensor',
         '演示专用 — 正式版由项圈传感器自动检测');

  // ── Internal helper ───────────────────────────────────────────────────────
  String _t(String en, String zh) => locale == 'zh' ? zh : en;
}
