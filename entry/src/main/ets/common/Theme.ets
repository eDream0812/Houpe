/*
 * Theme.ets
 * Houpe
 *
 * 全局视觉常量。橙色主色与三档敏感度配色沿用 iOS 原版；
 * 文字、卡片与页面底色改用 app 级资源，自动适配深浅色且跨设备可预期。
 *
 * 参考 HarmonySend 的色板组织：所有中性色、背景色、文字色统一进 color.json，
 * 页面里不再直接引用 sys.color.*，避免不同机型/系统版本出现色差。
 */

export class Theme {
  /* 主色：iOS 系统橙 */
  static readonly ACCENT: ResourceColor = $r('app.color.primary');

  /* 主色的十六进制值，用于 alpha() 计算半透明 */
  static readonly ACCENT_HEX: string = '#FF9500';

  /* 主色上的文字（按钮等） */
  static readonly ON_PRIMARY: ResourceColor = $r('app.color.on_primary');

  /* 三档敏感度配色（语义色，保持硬编码） */
  static readonly PASSIVE: string = '#34C759';
  static readonly PERMISSIONED: string = '#FF9500';
  static readonly ADVANCED: string = '#FF375F';

  /* 文字 */
  static readonly TEXT_PRIMARY: ResourceColor = $r('app.color.text_primary');
  static readonly TEXT_SECONDARY: ResourceColor = $r('app.color.text_secondary');
  static readonly TEXT_TERTIARY: ResourceColor = $r('app.color.text_tertiary');
  static readonly TEXT_DISABLED: ResourceColor = $r('app.color.text_disabled');

  /* 页面、卡片与分隔线底色 */
  static readonly PAGE_BG: ResourceColor = $r('app.color.background');
  static readonly SURFACE: ResourceColor = $r('app.color.surface');
  static readonly CARD_BG: ResourceColor = $r('app.color.card_bg');
  static readonly SHEET_BG: ResourceColor = $r('app.color.sheet_bg');
  static readonly DIVIDER: ResourceColor = $r('app.color.divider');

  /* 状态色 */
  static readonly SUCCESS: ResourceColor = $r('app.color.success');
  static readonly DANGER: ResourceColor = $r('app.color.danger');
  static readonly WARNING: ResourceColor = $r('app.color.warning');

  /** 灰色的十六进制值，仅供 alpha() 调半透明底色时使用 */
  static readonly TERTIARY_HEX: string = '#C7C7CC';

  /* 卡片圆角 */
  static readonly CARD_RADIUS: number = 16;
  static readonly CARD_RADIUS_LG: number = 20;
  static readonly CARD_RADIUS_XL: number = 22;

  /* 列表行 */
  static readonly ROW_RADIUS: number = 12;
  static readonly ROW_HEIGHT: number = 56;
  static readonly ICON_BOX: number = 42;
  static readonly ICON_BOX_RADIUS: number = 12;
  /** 图标方块底色 = 敏感度色 15% 透明，与 iOS 原版一致 */
  static readonly ICON_TINT_ALPHA: number = 0.15;

  /* 间距 */
  static readonly PAGE_PADDING: number = 16;
  static readonly CARD_PADDING: number = 16;
  static readonly SECTION_GAP: number = 20;
  static readonly ROW_GAP: number = 12;

  /* 字号 */
  static readonly FONT_TITLE: number = 34;
  static readonly FONT_LARGE: number = 30;
  static readonly FONT_HEADLINE: number = 17;
  static readonly FONT_BODY: number = 16;
  static readonly FONT_SUBHEAD: number = 15;
  static readonly FONT_FOOTNOTE: number = 13;
  static readonly FONT_CAPTION: number = 12;
  static readonly FONT_CAPTION2: number = 11;

  /**
   * 把 #RRGGBB 转为带透明度的 rgba 字符串，用于图标方块底色。
   */
  static alpha(hex: string, a: number): string {
    const r: number = parseInt(hex.substring(1, 3), 16);
    const g: number = parseInt(hex.substring(3, 5), 16);
    const b: number = parseInt(hex.substring(5, 7), 16);
    return `rgba(${r},${g},${b},${a})`;
  }

  /**
   * 取敏感度色。
   */
  static tintOf(sensitivity: string): string {
    if (sensitivity === 'passive') {
      return Theme.PASSIVE;
    }
    if (sensitivity === 'permissioned') {
      return Theme.PERMISSIONED;
    }
    return Theme.ADVANCED;
  }
}
