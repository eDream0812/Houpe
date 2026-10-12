/*
 * PermissionRationale.ets
 * Houpe
 *
 * 权限说明数据层。
 *
 * 这个应用的核心主张是：能少要一个权限就少要一个。
 * 每一个我们没有申请的权限，这里都写清了原因——
 * 因为在 HarmonyOS 上，不申请本身就是最强的保护。
 */

/**
 * 权限的申请状态分类。
 */
export enum PermissionDecision {
  /** 已申请，且是展示该类数据所必需的 */
  REQUESTED = 'requested',
  /** 主动不申请——用其他公开接口拿到了同样的信息 */
  NOT_NEEDED = 'notNeeded',
  /** 主动不申请——出于隐私边界，即使能申请也不要 */
  REFUSED = 'refused'
}

/**
 * 一条权限决策记录。
 */
export class PermissionRecord {
  /** 权限中文名 */
  name: string;
  /** 系统权限标识 */
  systemName: string;
  /** 决策 */
  decision: PermissionDecision;
  /** 为什么不申请 / 为什么申请 */
  reason: string;

  constructor(name: string, systemName: string, decision: PermissionDecision, reason: string) {
    this.name = name;
    this.systemName = systemName;
    this.decision = decision;
    this.reason = reason;
  }
}

/**
 * 决策分类的展示信息。
 */
export class DecisionInfo {
  title: string;
  subtitle: string;
  tint: string;

  constructor(title: string, subtitle: string, tint: string) {
    this.title = title;
    this.subtitle = subtitle;
    this.tint = tint;
  }
}

/**
 * 决策分类元数据。
 */
export function decisionInfo(d: PermissionDecision): DecisionInfo {
  if (d === PermissionDecision.REQUESTED) {
    return new DecisionInfo('我们申请的', '这些是展示对应分类所必需的，且都在你点开后才请求',
      '#34C759');
  }
  if (d === PermissionDecision.NOT_NEEDED) {
    return new DecisionInfo('我们不申请的', '这些数据用公开接口就能读到，无需向你索取权限',
      '#FF9500');
  }
  return new DecisionInfo('我们拒绝申请的', '即便系统允许，我们也不拿——因为展示它不需要',
    '#FF375F');
}

/**
 * 决策顺序，与首页敏感度分档的展示逻辑一致。
 */
export const DECISION_ORDER: PermissionDecision[] = [
  PermissionDecision.REQUESTED,
  PermissionDecision.NOT_NEEDED,
  PermissionDecision.REFUSED
];

/**
 * 完整的权限决策清单。
 */
export class PermissionRationale {
  static readonly RECORDS: PermissionRecord[] = [
    /* ---------- 申请了的 ---------- */
    new PermissionRecord('位置（精确）', 'ohos.permission.LOCATION',
      PermissionDecision.REQUESTED,
      '只有你自己点开「位置」分类时才请求。展示坐标、海拔、速度这些数值确实需要它。' +
      '拒绝也没关系，页面会明确告诉你为什么读不到。'),

    new PermissionRecord('摄像头', 'ohos.permission.CAMERA',
      PermissionDecision.REQUESTED,
      '用于读取摄像头硬件清单：数量、类型、等效焦距。' +
      'Houpe 不会创建摄像头输入，不会拍下一张照片。'),

    new PermissionRecord('麦克风', 'ohos.permission.MICROPHONE',
      PermissionDecision.REQUESTED,
      '用于读取音频输入设备清单。' +
      'Houpe 不会创建录音器，不会采集任何声音——只要硬件参数，麦克风权限已经是最小的口子。'),

    new PermissionRecord('媒体库（照片视频）', 'ohos.permission.READ_IMAGEVIDEO',
      PermissionDecision.NOT_NEEDED,
      '这个权限我们没有申请，也申请不下来——索性不用它。' +
      '改用系统照片选择器：由你亲手选中哪几张，应用才看得到哪几张，' +
      '媒体库里其余的一切它都看不见。同理，音频也走系统选择器，不申请 READ_AUDIO。'),

    new PermissionRecord('传感器', 'ohos.permission.ACCELEROMETER / GYROSCOPE',
      PermissionDecision.REQUESTED,
      '用于读取加速度计与陀螺仪的硬件参数：量程、精度、厂商。' +
      '不订阅数据流，只读一次静态规格。'),

    new PermissionRecord('运动与活动识别', 'ohos.permission.ACTIVITY_MOTION',
      PermissionDecision.REQUESTED,
      '只有你点开「运动与计步」分类时才请求，用于读取计步器硬件参数。' +
      'Houpe 不订阅传感器数据流，不记录你的任何一次移动。'),

    new PermissionRecord('已安装应用', 'ohos.permission.GET_BUNDLE_INFO',
      PermissionDecision.REQUESTED,
      '用于判断你装了哪些常见应用，进而给出行为推断。' +
      '只判断是否存在，不读取任何应用的数据、不启动它们。'),

    new PermissionRecord('网络信息', 'ohos.permission.GET_NETWORK_INFO',
      PermissionDecision.REQUESTED,
      '用于读取当前连接的接口名、本地 IP 与 DNS。' +
      '只是查询系统已知的连接状态，Houpe 不会发起任何网络请求。'),

    /* ---------- 不需要的 ---------- */
    new PermissionRecord('通讯录', 'ohos.permission.READ_CONTACTS',
      PermissionDecision.NOT_NEEDED,
      'Houpe 不展示联系人相关的数据，所以完全不需要这个权限。' +
      '不是因为申请不到，是因为收了也没有对应的展示位置——收了反而会让人误以为应用在读你的通讯录。'),

    new PermissionRecord('日历', 'ohos.permission.READ_CALENDAR',
      PermissionDecision.NOT_NEEDED,
      '同通讯录。HarmonyOS 把日历数据放在独立的沙箱里，' +
      '应用不申请就完全读不到，这是系统给的隔离保证。'),

    new PermissionRecord('提醒事项', 'ohos.permission.READ_REMINDERS',
      PermissionDecision.NOT_NEEDED,
      '与日历同源。Houpe 没有展示它的入口，所以不碰。'),

    new PermissionRecord('短信与通话记录', 'ohos.permission.READ_SMS / READ_CALL_LOG',
      PermissionDecision.NOT_NEEDED,
      '这类权限在 HarmonyOS 上属于敏感权限，需要严格的用途说明与用户显式授权。' +
      'Houpe 与它们毫无关系，不申请。'),

    new PermissionRecord('剪贴板内容', 'ohos.permission.READ_PASTEBOARD',
      PermissionDecision.NOT_NEEDED,
      'Houpe 只读剪贴板的「变更次数」和「有没有内容」这两个元信息，' +
      '这两项不需要任何权限。剪贴板的实际内容属于隐私，' +
      '读它必须单独申请权限——Houpe 不读，所以不申请。'),

    new PermissionRecord('后台位置', 'ohos.permission.ACCESS_BACKGROUND_LOCATION',
      PermissionDecision.NOT_NEEDED,
      '后台位置是 HarmonyOS 里管控最严的权限之一，需要单独说明并二次授权。' +
      'Houpe 展示的是你当前打开页面那一刻的位置，不需要后台跟踪。'),

    new PermissionRecord('设备 UDID / 序列号', 'ohos.permission.sec.ACCESS_UDID',
      PermissionDecision.NOT_NEEDED,
      '这是系统级权限，普通应用永远拿不到。' +
      'HarmonyOS 用「开放设备标识 ODID」替代了它：ODID 按开发者隔离，' +
      '既能区分设备，又不会泄露设备本身的身份。这是系统层面的隐私设计。'),

    new PermissionRecord('安装来源应用列表', 'ohos.permission.GET_BUNDLE_INFO_PRIVILEGE',
      PermissionDecision.NOT_NEEDED,
      '想要读取「非上架应用」需要特权权限，普通应用申请不到。' +
      'HarmonyOS 从制度上限制了应用之间的互相探测，Houpe 因此只能查询已上架应用。'),

    /* ---------- 拒绝申请的 ---------- */
    new PermissionRecord('后台运行', 'ohos.permission.KEEP_BACKGROUND_RUNNING',
      PermissionDecision.REFUSED,
      'Houpe 没有后台保活。关掉页面即停止采集，' +
      '不留常驻服务、不自启动、不做静默持续采样。' +
      '「你能看到什么」这件事，恰恰需要「它没有在背着你做什么」才成立。'),

    new PermissionRecord('广告跟踪标识', 'ohos.permission.APP_TRACKING_CONSENT',
      PermissionDecision.REFUSED,
      'HarmonyOS 要求应用在跟踪用户前单独取得这项授权。' +
      'Houpe 不做跟踪，因此从不请求它。'),

    new PermissionRecord('剪贴板写入', 'ohos.permission.WRITE_PASTEBOARD',
      PermissionDecision.REFUSED,
      '除了你长按复制某个数值之外，Houpe 不往剪贴板写任何东西。' +
      '更不会用「写入-读取」的方式探测你复制过的内容——那是一种典型的侧信道攻击。'),

    new PermissionRecord('屏幕录制 / 截屏', 'ohos.permission.CAPTURE_SCREEN',
      PermissionDecision.REFUSED,
      '不需要。Houpe 展示的一切都来自它自己读到的数值，' +
      '不读取也不上传你的屏幕内容。'),

    new PermissionRecord('麦克风录音', 'ohos.permission.MICROPHONE（录音态）',
      PermissionDecision.REFUSED,
      '即使麦克风权限已授予，Houpe 也不创建 AudioCapturer。' +
      '权限给了不等于一定要用——我们只读硬件规格，不碰声音本身。'),

    new PermissionRecord('上传与网络', 'INTERNET（出站请求）',
      PermissionDecision.REFUSED,
      'Houpe 的网络访问能力在代码层面是空的：' +
      '不发送请求、不建立连接、不上报数据。' +
      '你看到的每一个数字都直接来自这台设备，没有任何一条离开过它。')
  ];

  /**
   * 取某决策下的全部记录。
   */
  static recordsOf(d: PermissionDecision): PermissionRecord[] {
    return PermissionRationale.RECORDS.filter(r => r.decision === d);
  }

  /**
   * 取某决策的记录数量。
   */
  static countOf(d: PermissionDecision): number {
    return PermissionRationale.recordsOf(d).length;
  }
}
