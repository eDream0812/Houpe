/*
 * AboutPage.ets
 * Houpe
 *
 * 关于页：应用图标 + 版本 + 数据边界说明 + 重看引导。
 */

import { HdsNavDestination, hdsMaterial, HdsNavigationTitleBarOptions, TitleBarContentOptions, HdsNavigationTitle, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { AppSymbols } from '../common/AppSymbols';
import { GlassCardModifier } from '../common/CardStyles';

import { CATEGORY_ORDER } from '../models/SignalCategory';

@ComponentV2
export struct AboutPage {
  /** 重看引导回调 */
  @Param
  onReplayOnboarding: () => void = () => {};
  /** 跳转权限说明页 */
  @Param
  onShowPermissions: () => void = () => {};
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();
  /** 滚动器，绑定给标题栏做滚动模糊效果（与首页一致） */
  scroller: Scroller = new Scroller();

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          this.header()
          this.boundary()
          this.categories()
          this.actions()
          this.credits()
          Column()
            .height(28)
            .width('100%')
        }
        .width('100%')
        .padding({ left: Theme.PAGE_PADDING, right: Theme.PAGE_PADDING, top: 96 })
      }
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.TopStart)
      .width('100%')
      .height('100%')
    }
    .titleBar(this.titleBarOptions())
    // 迷你标题栏：56vp 单行，标题与菜单按钮同排对齐（华为 titlebar 设计规范）
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .bindToScrollable([this.scroller])
    .backgroundColor(Theme.PAGE_BG)
  }

  /**
   * 原生标题栏：固定标题 + 默认返回键。
   */
  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const title: HdsNavigationTitle = { mainTitle: '关于' };
    const content: TitleBarContentOptions = { title: title };
    // 与首页同一套悬浮透明标题栏方案：avoidLayoutSafeArea/enableComponentSafeArea
    // 均为 false，标题栏不悬浮避让由内容区 top padding 让位（状态栏 + 56vp 标题栏）。
    return {
      content: content,
      style: {
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        },
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20)
        },
        originalStyle: {
          backgroundStyle: {
            backgroundColor: Color.Transparent
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            // 渐变颜色必须与页面背景色一致，否则滚到标题栏下方会出现色差接缝
            backgroundColor: Theme.PAGE_BG,
            // 渐变模糊层比标题栏底边再高出 32vp（实际遮罩高度 = 标题栏高度 + 32），
            // 与"跟手隐藏"情况下的高度保持一致
            maskExtraHeight: 32
          }
        }
      },
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    };
  }

  @Builder
  header() {
    Row({ space: 16 }) {
      Image($r('app.media.app_icon'))
        .width(72)
        .height(72)
        .borderRadius(18)
        .backgroundColor(Theme.ACCENT)

      Column({ space: 4 }) {
        Text('Houpe')
          .fontSize(Theme.FONT_TITLE - 10)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
        Text('版本 1.0.0')
          .fontSize(Theme.FONT_SUBHEAD)
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()
    }
    .width('100%')
  }

  @Builder
  boundary() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        SymbolGlyph(AppSymbols.PERMISSIONED)
          .fontSize(17)
          .fontColor([Theme.ACCENT])
        Text('数据边界')
          .fontSize(Theme.FONT_HEADLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
      }
      .width('100%')

      Text('Houpe 只读取，不上传。没有账号，没有同步，没有网络请求。你看到的每一个数值都直接来自这台设备。')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontColor(Theme.TEXT_SECONDARY)
        .width('100%')

      Divider()
        .color(Theme.DIVIDER)

      Column({ space: 6 }) {
        BoundaryLine({ text: '不读取通讯录姓名与号码' })
        BoundaryLine({ text: '不打开任何照片，不读取缩略图' })
        BoundaryLine({ text: '不创建录音器，不采集任何声音' })
        BoundaryLine({ text: '不创建摄像头输入，不拍任何照片' })
        BoundaryLine({ text: '不读取剪贴板内容，只看类型' })
        BoundaryLine({ text: '不启动其他应用，不读它们的通知' })
        BoundaryLine({ text: '不后台运行，不静默持续采样' })
        BoundaryLine({ text: '不发起任何网络请求' })
      }
      .width('100%')

      Row({ space: 6 }) {
        Text('这些不是承诺，是配置')
          .fontSize(Theme.FONT_CAPTION2)
          .fontColor(Theme.TEXT_TERTIARY)
          .layoutWeight(1)

        Text('查看完整权限说明')
          .fontSize(Theme.FONT_CAPTION2)
          .fontColor(Theme.ACCENT)
          .margin({ right: 4 })

        SymbolGlyph(AppSymbols.CHEVRON)
          .fontSize(11)
          .fontColor([Theme.ACCENT])
      }
      .width('100%')
      .margin({ top: 4 })
      .onClick(() => {
        this.onShowPermissions();
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Theme.CARD_PADDING)
    .attributeModifier(this.cardModifier)
  }

  @Builder
  categories() {
    Column({ space: 10 }) {
      Text('覆盖的采集面')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)
        .width('100%')
        .padding({ left: 4 })

      Text(`Houpe 覆盖 ${CATEGORY_ORDER.length} 个采集面，全部为 HarmonyOS 上的真实可读项。` +
        '凡是没有等价接口的能力，Houpe 不收录，也不会用假数据填充。')
        .fontSize(Theme.FONT_CAPTION)
        .fontColor(Theme.TEXT_TERTIARY)
        .width('100%')
        .padding({ left: 4 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actions() {
    Column({ space: 10 }) {
      Button('重看引导', { type: ButtonType.Normal })
        .width('100%')
        .height(46)
        .fontSize(Theme.FONT_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(Theme.ACCENT)
        .borderRadius(Theme.CARD_RADIUS)
        .onClick(() => { this.onReplayOnboarding(); })
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  credits() {
    Text('设计思路参考 Loupe，为 HarmonyOS 重新实现')
      .fontSize(Theme.FONT_FOOTNOTE)
      .fontColor(Theme.TEXT_TERTIARY)
      .width('100%')
      .textAlign(TextAlign.Center)
      .margin({ top: 12 })
  }
}

/**
 * 边界说明的一行条目。
 */
@ComponentV2
struct BoundaryLine {
  @Param
  text: string = '';

  build() {
    Row({ space: 6 }) {
      Text('\u00B7')
        .fontSize(Theme.FONT_BODY)
        .fontColor(Theme.PASSIVE)
      Text(this.text)
        .fontSize(Theme.FONT_FOOTNOTE)
        .fontColor(Theme.TEXT_SECONDARY)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }
}
