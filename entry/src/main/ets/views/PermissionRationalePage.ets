/*
 * PermissionRationalePage.ets
 * Houpe
 *
 * 权限说明页。用 SegmentButton 做三档切换（申请 / 不需要 / 拒绝申请），
 * 切换后展示该档下的全部权限条目与原因。
 *
 * 这页想传达的是：在 HarmonyOS 上，「没申请」本身就是最强的保护。
 */

import { HdsNavDestination, hdsMaterial, HdsNavigationTitleBarOptions, TitleBarContentOptions, HdsNavigationTitle, HdsNavDestinationTitleMode, ScrollEffectType } from '@kit.UIDesignKit';
import { Theme } from '../common/Theme';
import { AppSymbols } from '../common/AppSymbols';
import { GlassCardModifier } from '../common/CardStyles';
import {
  PermissionDecision,
  PermissionRecord,
  PermissionRationale,
  DecisionInfo,
  decisionInfo,
  DECISION_ORDER
} from '../support/PermissionRationale';
import { CapsuleSegmentButtonV2, SegmentButtonV2Items,
  SegmentButtonV2ItemOptions, LengthMetrics, ColorMetrics } from '@kit.ArkUI';

/** 分段按钮的档位文案，长度即档数（拖动落点换算依赖它）。 */
const DECISION_SEGMENT_LABELS: string[] = ['已申请', '不需要', '拒绝申请'];

/**
 * 决策分档筛选器。与首页 TierFilter 完全一致：
 * 品牌橙胶囊 + 支持手指拖动（iOS 风格 scrub）。
 */
@ComponentV2
struct DecisionSegment {
  /** 当前选中的档位下标 */
  @Param
  selectedIndex: number = 0;
  /** 切换回调 */
  @Param
  onSwitch: (index: number) => void = () => {};
  /** 胶囊实测宽度（px），用于把触摸 x 坐标换算成档位下标 */
  @Local
  segWidthPx: number = 0;

  private items: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '已申请' },
    { text: '不需要' },
    { text: '拒绝申请' }
  ]);

  build() {
    CapsuleSegmentButtonV2({
      items: this.items,
      selectedIndex: this.selectedIndex,
      // 与首页分档筛选器同一套配色：选中项橙底白字，未选中项次要色文字
      itemSelectedBackgroundColor: ColorMetrics.resourceColor(Theme.ACCENT),
      itemSelectedFontColor: ColorMetrics.resourceColor('#FFFFFF'),
      itemSelectedFontWeight: FontWeight.Medium,
      itemFontColor: ColorMetrics.resourceColor(Theme.TEXT_SECONDARY),
      onItemClicked: (index: number) => {
        this.onSwitch(index);
      }
    })
    .width('100%')
    // 测量胶囊实际宽度，供拖动落点换算使用
    .onAreaChange((_oldSize, newSize) => {
      const w = newSize.width;
      if (typeof w === 'number') {
        this.segWidthPx = w;
      }
    })
    // 手指按下/滑动时根据水平落点实时切换档位
    .onTouch((event: TouchEvent) => {
      this.scrubTo(event);
    })
  }

  /**
   * 把触摸事件的水平落点换算成档位下标。
   * 胶囊内各档等宽，因此用 x / (宽度 / 档数) 取整即可。
   */
  private scrubTo(event: TouchEvent): void {
    if (this.segWidthPx <= 0) {
      return;
    }
    const touch = event.touches[0];
    if (touch === undefined) {
      return;
    }
    const count = DECISION_SEGMENT_LABELS.length;
    const step = this.segWidthPx / count;
    let idx = Math.floor(touch.x / step);
    idx = Math.max(0, Math.min(count - 1, idx));
    if (idx !== this.selectedIndex) {
      this.onSwitch(idx);
    }
  }
}

/**
 * 单条权限记录行卡。
 */
@ComponentV2
struct RecordCard {
  @Param
  record: PermissionRecord | null = null;

  build() {
    // 与首页分类行同一套自绘卡片：HdsListItemCard 自带不可关闭的内置外边距，
    // 会让行比分段按钮窄一截；改用实心底卡片容器并铺满父容器，左右边缘严格对齐。
    Row({ space: 12 }) {
      // 图标块：按本条决策的配色着色
      Column() {
        SymbolGlyph(this.symbol())
          .fontSize(20)
          .fontColor([this.tint()])
      }
      .width(38)
      .height(38)
      .borderRadius(10)
      .backgroundColor(Theme.alpha(this.tint(), 0.15))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 权限名 + 原因 + 系统权限名
      Column({ space: 2 }) {
        Text(this.record !== null ? this.record.name : '')
          .fontSize(Theme.FONT_SUBHEAD)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.record !== null ? this.record.reason : '')
          .fontSize(Theme.FONT_CAPTION)
          .fontColor(Theme.TEXT_SECONDARY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (this.record !== null && this.record.systemName.length > 0) {
          Text(this.record.systemName)
            .fontSize(Theme.FONT_CAPTION)
            .fontColor(Theme.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧状态：已申请 / 未申请，用本条决策的配色
      Text(this.statusText())
        .fontSize(Theme.FONT_CAPTION)
        .fontColor(this.tint())
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(Theme.CARD_BG)
    .borderRadius(Theme.CARD_RADIUS)
    .alignItems(VerticalAlign.Center)
  }

  /** 本条记录的决策，缺省按「已申请」处理。 */
  private decision(): PermissionDecision {
    return this.record !== null ? this.record.decision : PermissionDecision.REQUESTED;
  }

  /** 该决策档位的配色。 */
  private tint(): string {
    return decisionInfo(this.decision()).tint;
  }

  private statusText(): string {
    return this.decision() === PermissionDecision.REQUESTED ? '已申请' : '未申请';
  }

  private symbol(): Resource {
    if (this.decision() === PermissionDecision.REQUESTED) {
      return AppSymbols.UNLOCKED;
    }
    if (this.decision() === PermissionDecision.REFUSED) {
      return AppSymbols.CROSS;
    }
    return AppSymbols.LOCKED;
  }
}

/**
 * 权限说明页主体。
 */
@ComponentV2
export struct PermissionRationalePage {
  @Local selectedIndex: number = 0;
  private readonly cardModifier: GlassCardModifier = new GlassCardModifier();
  /** 滚动器，绑定给标题栏做滚动模糊效果（与首页一致） */
  scroller: Scroller = new Scroller();

  private decisionAt(index: number): PermissionDecision {
    if (index >= 0 && index < DECISION_ORDER.length) {
      return DECISION_ORDER[index];
    }
    return DECISION_ORDER[0];
  }

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          this.intro()
          this.segment()
          this.sectionHeader()
          this.records()

          Column()
            .height(32)
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
    const title: HdsNavigationTitle = { mainTitle: '权限说明' };
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
  intro() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph(AppSymbols.PERMISSIONED)
          .fontSize(20)
          .fontColor([Theme.ACCENT])
        Text('为什么有些权限我们不申请')
          .fontSize(Theme.FONT_HEADLINE)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
        Blank()
      }
      .width('100%')

      Text('在 HarmonyOS 上，权限是默认关闭的：应用不主动申请，系统就不给。' +
        '这不是需要绕过的东西，而是系统的默认立场。' +
        '所以「我们没有申请某个权限」意味着——你手机上就真的没有这条数据流向 Houpe。')
        .fontSize(Theme.FONT_SUBHEAD)
        .fontColor(Theme.TEXT_SECONDARY)
        .lineHeight(21)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(Theme.CARD_PADDING)
    .attributeModifier(this.cardModifier)
  }

  @Builder
  segment() {
    DecisionSegment({
      selectedIndex: this.selectedIndex,
      onSwitch: (index: number) => {
        this.selectedIndex = index;
      }
    })
  }

  @Builder
  sectionHeader() {
    Row({ space: 8 }) {
      SymbolGlyph(AppSymbols.LOCKED)
        .fontSize(15)
        .fontColor([decisionInfo(this.decisionAt(this.selectedIndex)).tint])
      Text(decisionInfo(this.decisionAt(this.selectedIndex)).title)
        .fontSize(Theme.FONT_SUBHEAD)
        .fontWeight(FontWeight.Medium)
        .fontColor(decisionInfo(this.decisionAt(this.selectedIndex)).tint)
      Blank()
      Text(`${PermissionRationale.countOf(this.decisionAt(this.selectedIndex))} 项`)
        .fontSize(Theme.FONT_CAPTION)
        .fontColor(Theme.TEXT_TERTIARY)
    }
    .width('100%')
    .padding({ left: 4, top: 4 })

    Text(decisionInfo(this.decisionAt(this.selectedIndex)).subtitle)
      .fontSize(Theme.FONT_CAPTION)
      .fontColor(Theme.TEXT_TERTIARY)
      .width('100%')
      .padding({ left: 4 })
  }

  @Builder
  records() {
    Column({ space: 10 }) {
      ForEach(PermissionRationale.recordsOf(this.decisionAt(this.selectedIndex)),
        (record: PermissionRecord) => {
          RecordCard({ record: record })
        }, (record: PermissionRecord) => record.systemName)
    }
    .width('100%')
  }
}
