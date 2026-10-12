/*
 * CategoryDetailPage.ets
 * Houpe
 *
 * 分类详情页：敏感度徽章 + 副标题 + 信号列表 + 分档说明。
 * 结构与 iOS 版 CategoryDetailView 一致。
 */

import { HdsNavDestination, hdsMaterial, HdsNavigationTitleBarOptions, TitleBarContentOptions, HdsNavigationTitle, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { LengthMetrics } from '@kit.ArkUI';
import { BP_SM, contentMaxWidthFor, sidePaddingFor, getBreakpoint, subscribeBreakpoint, unsubscribeBreakpoint } from '../common/LayoutUtil';
import { Theme } from '../common/Theme';
import { AppSymbols } from '../common/AppSymbols';
import { GlassCardModifier } from '../common/CardStyles';
import { showHdsToast } from '../common/HdsFeedback';
import { SignalRow, SensitivityBadge, EmptyHint } from '../common/CommonComponents';
import { SignalCategory, categoryInfo } from '../models/SignalCategory';
import { sensitivityInfo, Sensitivity } from '../models/Sensitivity';
import { store } from '../models/CategoryStore';
import { LoadState } from '../models/LoadState';
import { FingerprintSignal } from '../models/FingerprintSignal';
import { pasteboard } from '@kit.BasicServicesKit';

/**
 * 首页分类行与本页表头之间共享的元素 id。
 * 两侧绑定同一个 id 后，跳转时首页那一行会连续过渡到本页表头的位置。
 */
export function categoryShareId(id: SignalCategory): string {
  return `houpe-category-${id}`;
}

@ComponentV2
export struct CategoryDetailPage {
  /** 要展示的分类 */
  @Param
  category: SignalCategory = SignalCategory.DEVICE_IDENTITY;
  @Local isLive: boolean = false;
  /** 是否需要通过系统 Picker 让用户亲手选择才能采集（如媒体选择器） */
  @Local needsPicker: boolean = false;
  /** 信号列表错位入场标记：读取完成后逐行淡入上移 */
  @Local entered: boolean = false;
  /** 多端断点：sm / md / lg，由 EntryAbility 从窗口宽度实时写入 */
  @Local bp: string = getBreakpoint();
  /** 断点订阅回调，窗口尺寸变化时刷新 bp 并重绘 */
  private onBpChange: (bp: string) => void = (bp: string) => {
    this.bp = bp;
  };
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();
  /** 滚动器，绑定给标题栏做滚动模糊效果（与首页一致） */
  scroller: Scroller = new Scroller();

  async aboutToAppear(): Promise<void> {
    // 订阅断点变化，折叠屏开合 / 2in1·PC 自由窗口缩放都能实时重绘
    subscribeBreakpoint(this.onBpChange);
    await this.loadIfNeeded();
    this.isLive = store.supportsLive(this.category);
    this.needsPicker = store.supportsPicker(this.category);
    if (this.isLive) {
      store.startLive(this.category);
    }
    // 信号列表逐行淡入（首帧后触发，读取完成再播放）
    setTimeout(() => {
      this.getUIContext()?.animateTo({ duration: 280, curve: Curve.EaseOut }, () => {
        this.entered = true;
      });
    }, 30);
  }

  onPageHide(): void {
    store.stopLive(this.category);
  }

  aboutToDisappear(): void {
    store.stopLive(this.category);
    unsubscribeBreakpoint(this.onBpChange);
  }

  private async loadIfNeeded(): Promise<void> {
    const state: LoadState = store.loadStateFor(this.category);
    if (state === LoadState.IDLE || state === LoadState.FAILED) {
      await store.refresh(this.category);
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        // 读取 revision 建立依赖，采集完成后信号列表自动刷新
        Text(store.revision.toString()).visibility(Visibility.None)
        this.body()
      }
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
   * 原生标题栏：分类名 + 默认返回键。
   */
  private titleBarOptions(): HdsNavigationTitleBarOptions {
    const title: HdsNavigationTitle = { mainTitle: categoryInfo(this.category)?.title ?? '' };
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
  body() {
    Scroll(this.scroller) {
      // 居中容器：宽屏（尤其是分栏后的详情 pane）下限宽居中，避免被拉伸
      Row() {
        Column({ space: 0 }) {
          this.header()
          this.signalList()
          TierFooterBlock({ text: sensitivityInfo(categoryInfo(this.category)?.sensitivity ?? SensitivityFallback).blurb })
          Column()
            .height(32)
            .width('100%')
        }
        .width('100%')
        .constraintSize({ maxWidth: contentMaxWidthFor(this.bp) })
        .padding({ left: sidePaddingFor(this.bp), right: sidePaddingFor(this.bp), top: 96 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.TopStart)
    .width('100%')
    .height('100%')
  }

  @Builder
  header() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        // 图标方块
        Stack() {
          SymbolGlyph(categoryInfo(this.category)?.symbol ?? AppSymbols.DEVICE)
            .fontSize(22)
            .fontColor([this.tint()])
        }
        .width(52)
        .height(52)
        .backgroundColor(Theme.alpha(this.tint(), Theme.ICON_TINT_ALPHA))
        .borderRadius(14)

        Column({ space: 4 }) {
          Text(categoryInfo(this.category)?.title ?? '')
            .fontSize(Theme.FONT_LARGE - 8)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          SensitivityBadge({
            symbol: sensitivityInfo(categoryInfo(this.category)?.sensitivity ?? SensitivityFallback).symbol,
            title: sensitivityInfo(categoryInfo(this.category)?.sensitivity ?? SensitivityFallback).title,
            tint: this.tint()
          })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      // 共享元素转场：与首页 CategoryRow 绑定同一个 id（见 categoryShareId）。
      // 配合首页在 animateTo 里执行 pushPath，形成"列表行长成详情页表头"的位移过渡。
      .geometryTransition(categoryShareId(this.category))

      Text(categoryInfo(this.category)?.subtitle ?? '')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontColor(Theme.TEXT_SECONDARY)
        .width('100%')

      // 信号数量与刷新
      Row({ space: 10 }) {
        Text(`${store.countFor(this.category)} 项读数`)
          .fontSize(Theme.FONT_CAPTION)
          .fontColor(Theme.TEXT_TERTIARY)

        if (this.isLive) {
          Row({ space: 4 }) {
            Circle({ width: 6, height: 6 })
              .fill('#FF3B30')
            Text('实时')
              .fontSize(Theme.FONT_CAPTION2)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF3B30')
          }
        }

        Blank()

        Row({ space: 4 }) {
          SymbolGlyph(AppSymbols.REFRESH)
            .fontSize(13)
            .fontColor([Theme.ACCENT])
          Text('刷新')
            .fontSize(Theme.FONT_CAPTION)
            .fontColor(Theme.ACCENT)
        }
        .onClick(() => {
          store.refresh(this.category);
        })
      }
      .width('100%')

      // 需要用户亲手选择的分类：给两个入口唤起系统 Picker。
      // 这类采集不申请任何权限——选择器出面，用户选中哪几项才看得到哪几项。
      if (this.needsPicker) {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            SymbolGlyph(AppSymbols.MEDIA)
              .fontSize(14)
              .fontColor([Color.White])
            Text('选择照片 / 视频')
              .fontSize(Theme.FONT_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
          }
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .borderRadius(18)
          .backgroundColor(Theme.ACCENT)
          .onClick(() => {
            store.pickPhotos(this.category);
          })

          Row({ space: 6 }) {
            SymbolGlyph(AppSymbols.AUDIO)
              .fontSize(14)
              .fontColor([Theme.ACCENT])
            Text('选择音频')
              .fontSize(Theme.FONT_CAPTION)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.ACCENT)
          }
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .borderRadius(18)
          // alpha() 只吃 hex 字符串，因此用 ACCENT_HEX 而非资源色 ACCENT
          .backgroundColor(Theme.alpha(Theme.ACCENT_HEX, 0.15))
          .onClick(() => {
            store.pickAudio(this.category);
          })
        }
        .width('100%')
        .margin({ top: 2 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ bottom: 16 })
  }

  @Builder
  signalList() {
    Column() {
      if (store.countFor(this.category) === 0) {
        EmptyHint({ text: this.emptyText() })
      } else {
        ForEach(store.signalsFor(this.category), (s: FingerprintSignal, index: number) => {
          Column() {
            if (index > 0) {
              Divider()
                .color(Theme.DIVIDER)
                .margin({ top: 2, bottom: 2 })
            }
            SignalRow({ signal: s, onCopy: (item: FingerprintSignal) => { this.copy(item); } })
          }
          .width('100%')
          // 逐行错位淡入：从透明 + 下移 10vp 落到原位
          .opacity(this.entered ? 1 : 0)
          .translate({ y: this.entered ? 0 : 10 })
          .animation({ duration: 240, delay: index * 40, curve: Curve.EaseOut })
        }, (s: FingerprintSignal) => s.id)
      }
    }
    .width('100%')
    .attributeModifier(this.cardModifier)
    .padding({ left: 14, right: 14, top: 4, bottom: 4 })
  }

  private tint(): string {
    return Theme.tintOf(categoryInfo(this.category)?.sensitivity ?? 'passive');
  }

  private emptyText(): string {
    const state: LoadState = store.loadStateFor(this.category);
    if (state === LoadState.DENIED) {
      return '尚未获得授权，无法读取这一类数据';
    }
    if (state === LoadState.LOADING) {
      return '正在读取…';
    }
    return '这一类在本机没有可读取的数据';
  }

  private copy(item: FingerprintSignal): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, item.value);
      pasteboard.getSystemPasteboard().setData(data);
      showHdsToast(this.getUIContext(), '已复制到剪贴板', AppSymbols.DONE);
    } catch (e) {
      showHdsToast(this.getUIContext(), '复制失败');
    }
  }
}

const SensitivityFallback: Sensitivity = Sensitivity.PASSIVE;

/**
 * 分档说明文字块。抽成组件是为了在 build 里保持简洁。
 */
@ComponentV2
struct TierFooterBlock {
  @Param
  text: string = '';

  build() {
    Text(this.text)
      .fontSize(Theme.FONT_CAPTION)
      .fontColor(Theme.TEXT_TERTIARY)
      .width('100%')
      .padding({ left: 4, top: 10 })
  }
}
