/*
 * AppSymbols.ets
 * Houpe
 *
 * 全局图标常量表。
 *
 * 重要：鸿蒙的 sys.symbol 命名规则与 iOS SF Symbols 完全不同，
 * 不能按字面直译。下面每一条都在本机 SDK 编译验证过。
 *
 * 注释里标注了该符号对应 Loupe 原版的哪个 SF Symbol。
 */

export class AppSymbols {
  /* ---------- 三档敏感度 ---------- */
  /** 对应 iOS: eye */
  static readonly PASSIVE: Resource = $r('sys.symbol.eye');
  /** 对应 iOS: lock.shield */
  static readonly PERMISSIONED: Resource = $r('sys.symbol.lock_shield');
  /** 对应 iOS: lock.shield（实心版，用于徽章） */
  static readonly PERMISSIONED_FILL: Resource = $r('sys.symbol.lock_shield_fill');
  /** 对应 iOS: flask（烧瓶）——鸿蒙无烧瓶，用灯泡表达"技巧/发现" */
  static readonly ADVANCED: Resource = $r('sys.symbol.lightbulb_max');
  /** 对应 iOS: flask（描边版） */
  static readonly ADVANCED_ALT: Resource = $r('sys.symbol.lightbulb');
  /** 对应 iOS: xmark.shield.fill（未授权） */
  static readonly DENIED: Resource = $r('sys.symbol.xmark');
  /** 权限清单里的「未申请」标记 */
  static readonly CROSS: Resource = $r('sys.symbol.xmark');
  /** 权限说明页入口 */
  static readonly PERMISSION_INFO: Resource = $r('sys.symbol.lock_shield_fill');
  /** 对应 iOS: checkmark.shield.fill（已授权反馈） */
  static readonly GRANTED: Resource = $r('sys.symbol.checkmark_shield_fill');

  /* ---------- 分类图标 ---------- */
  /** 对应 iOS: iphone.gen3 */
  static readonly DEVICE: Resource = $r('sys.symbol.phone');
  /** 对应 iOS: cpu */
  static readonly SYSTEM: Resource = $r('sys.symbol.gearshape');
  /** 对应 iOS: battery.100percent.bolt */
  static readonly BATTERY: Resource = $r('sys.symbol.battery_100percent');
  /** 对应 iOS: internaldrive */
  static readonly STORAGE: Resource = $r('sys.symbol.archivebox');
  /** 对应 iOS: display */
  static readonly DISPLAY: Resource = $r('sys.symbol.display');
  /** 对应 iOS: speaker.wave.2 */
  static readonly AUDIO: Resource = $r('sys.symbol.speaker');
  /** 对应 iOS: globe.badge.chevron.backward */
  static readonly LOCALE: Resource = $r('sys.symbol.map');
  /** 对应 iOS: accessibility */
  static readonly ACCESSIBILITY: Resource = $r('sys.symbol.figure');
  /** 对应 iOS: gyroscope */
  static readonly SENSOR: Resource = $r('sys.symbol.gyroscope');
  /** 对应 iOS: network */
  static readonly NETWORK: Resource = $r('sys.symbol.wifi');
  /** 对应 iOS: textformat */
  static readonly FONTS: Resource = $r('sys.symbol.textformat');
  /** 对应 iOS: app.badge */
  static readonly APP_INFO: Resource = $r('sys.symbol.doc_text');
  /** 对应 iOS: doc.on.clipboard */
  static readonly PASTEBOARD: Resource = $r('sys.symbol.doc_plaintext');
  /** 对应 iOS: bolt.horizontal.circle（Metal / GPU） */
  static readonly GRAPHICS: Resource = $r('sys.symbol.paintbrush');
  /** 对应 iOS: dot.radiowaves.right */
  static readonly WIRELESS: Resource = $r('sys.symbol.bluetooth');
  /** 对应 iOS: figure.walk */
  static readonly MOTION: Resource = $r('sys.symbol.figure_walk');
  /** 对应 iOS: location.fill */
  static readonly LOCATION: Resource = $r('sys.symbol.scope');
  /** 对应 iOS: camera.aperture */
  static readonly CAMERA: Resource = $r('sys.symbol.camera');
  /** 麦克风（Houpe 新增分类） */
  static readonly MICROPHONE: Resource = $r('sys.symbol.mic');
  /** 对应 iOS: photo.stack */
  static readonly MEDIA: Resource = $r('sys.symbol.film');
  /** 对应 iOS: square.grid.3x3 */
  static readonly INSTALLED_APPS: Resource = $r('sys.symbol.square_grid_2x2');
  /** 网页视图指纹（Houpe 新增高阶分类）——沿用已验证的 link 符号表达"网页" */
  static readonly WEBVIEW: Resource = $r('sys.symbol.link');

  /* ---------- 交互图标 ---------- */
  /** 对应 iOS: info.circle（关于） */
  static readonly ABOUT: Resource = $r('sys.symbol.info_circle');
  /** 对应 iOS: chevron.left.forwardslash.chevron.right */
  static readonly BACK: Resource = $r('sys.symbol.chevron_left');
  /** 列表行右侧的箭头 */
  static readonly CHEVRON: Resource = $r('sys.symbol.chevron_right');
  /** 对应 iOS: arrow.counterclockwise.circle（刷新） */
  static readonly REFRESH: Resource = $r('sys.symbol.arrow_clockwise');
  /** 对应 iOS: xmark */
  static readonly CLOSE: Resource = $r('sys.symbol.xmark');
  /** 对应 iOS: checkmark（完成） */
  static readonly DONE: Resource = $r('sys.symbol.checkmark');
  /** 对应 iOS: lock（未授权态） */
  static readonly LOCKED: Resource = $r('sys.symbol.lock');
  /** 对应 iOS: lock.open.fill（授权按钮） */
  static readonly UNLOCKED: Resource = $r('sys.symbol.lock_open');
  /** 对应 iOS: questionmark.circle（解释块） */
  static readonly QUESTION: Resource = $r('sys.symbol.questionmark_circle');
  /** 对应 iOS: bolt.fill（高亮） */
  static readonly HIGHLIGHT: Resource = $r('sys.symbol.bolt');
  /** 对应 iOS: ellipsis.circle */
  static readonly MORE: Resource = $r('sys.symbol.ellipsis_circle');
  /** 对应 iOS: hourglass（未读取态） */
  static readonly TIMER: Resource = $r('sys.symbol.hourglass');

  /* ---------- 洞察卡片 ---------- */
  /** 对应 iOS: globe（区域） */
  static readonly GLOBE_INSIGHT: Resource = $r('sys.symbol.map');
  /** 对应 iOS: character.bubble（键盘语言） */
  static readonly KEYBOARD_INSIGHT: Resource = $r('sys.symbol.character');
  /** 对应 iOS: gift（存储/设备） */
  static readonly GIFT_INSIGHT: Resource = $r('sys.symbol.archivebox');
  /** 对应 iOS: doc.on.clipboard（剪贴板） */
  static readonly CLIPBOARD_INSIGHT: Resource = $r('sys.symbol.list_bullet');
  /** 对应 iOS: clock.arrow.circlepath（运行时长） */
  static readonly UPTIME_INSIGHT: Resource = $r('sys.symbol.clock');
  /** 对应 iOS: textformat.size（无障碍设置） */
  static readonly ACCESSIBILITY_INSIGHT: Resource = $r('sys.symbol.figure');
  /** 对应 iOS: airplane（旅行猜测） */
  static readonly JOURNEY_INSIGHT: Resource = $r('sys.symbol.paperplane');
  /** 对应 iOS: app.badge.checkmark（已装应用） */
  static readonly APPS_INSIGHT: Resource = $r('sys.symbol.grid');
  /** 对应 iOS: link（拼合指纹） */
  static readonly CHAIN_INSIGHT: Resource = $r('sys.symbol.link');
  /** 高亮页头图 */
  static readonly HIGHLIGHT_HERO: Resource = $r('sys.symbol.lightbulb_max');

  /* ---------- 应用推断规则用 ---------- */
  /** 对应 iOS: lock.shield（隐私意识） */
  static readonly INFER_PRIVACY: Resource = $r('sys.symbol.lock_shield');
  /** 对应 iOS: heart.circle（社交） */
  static readonly INFER_SOCIAL: Resource = $r('sys.symbol.heart');
  /** 对应 iOS: music.note.list（音乐流媒体） */
  static readonly INFER_MEDIA: Resource = $r('sys.symbol.music_note_list');
  /** 对应 iOS: gamecontroller（游戏） */
  static readonly INFER_GAME: Resource = $r('sys.symbol.headphones');
  /** 对应 iOS: banknote（购物支付） */
  static readonly INFER_SHOPPING: Resource = $r('sys.symbol.star_fill');
  /** 对应 iOS: book（文档协作） */
  static readonly INFER_WORK: Resource = $r('sys.symbol.book');
  /** 对应 iOS: car（导航出行） */
  static readonly INFER_TRAVEL: Resource = $r('sys.symbol.compass');
  /** 对应 iOS: person.2.fill（协作沟通） */
  static readonly INFER_TEAM: Resource = $r('sys.symbol.person_2');
}
