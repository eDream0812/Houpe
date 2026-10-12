/*
 * CardStyles.ets
 * Houpe
 *
 * 玻璃卡片样式——跨文件复用的唯一实现。
 *
 * 参考 HarmonySend 的 CardStyles：@Styles 无法跨文件导出，所以用 AttributeModifier
 * 把卡片背景、模糊、圆角封装成可复用类。所有需要“卡片”视觉的地方统一挂这个 modifier，
 * 避免改一处漏一处。
 */

export class GlassCardModifier implements AttributeModifier<CommonAttribute> {
  /** 卡片圆角 */
  private readonly radius: number;

  constructor(radius: number = 16) {
    this.radius = radius;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance
      .backgroundColor($r('app.color.card_bg'))
      .backgroundBlurStyle(BlurStyle.COMPONENT_THIN, {
        colorMode: ThemeColorMode.SYSTEM,
        adaptiveColor: AdaptiveColor.DEFAULT,
        scale: 1.0
      })
      .borderRadius(this.radius);
  }
}

/**
 * 实色卡片修饰器——在不支持或不想用模糊玻璃的地方兜底。
 */
export class SolidCardModifier implements AttributeModifier<CommonAttribute> {
  private readonly radius: number;

  constructor(radius: number = 16) {
    this.radius = radius;
  }

  applyNormalAttribute(instance: CommonAttribute): void {
    instance
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(this.radius);
  }
}
