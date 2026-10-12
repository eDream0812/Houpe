import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';
import { common, Configuration } from '@kit.AbilityKit';
import { PlatformContext } from '../support/PlatformShim';
import { setBreakpointForWidth } from '../common/LayoutUtil';

const DOMAIN: number = 0x0201;
const TAG: string = 'Houpe';

export default class EntryAbility extends UIAbility {
  /** 主窗口引用，用于注册尺寸变化监听 */
  private mainWin?: window.Window;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'onCreate');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    if (newConfig.colorMode !== undefined) {
      AppStorage.setOrCreate<string>('colorMode', PlatformContext.colorModeText(newConfig.colorMode));
    }
    if (newConfig.fontSizeScale !== undefined) {
      AppStorage.setOrCreate<number>('fontSizeScale', newConfig.fontSizeScale);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 把上下文与沙箱路径写入 AppStorage，供 Provider 读取
    const ctx: common.UIAbilityContext = this.context;
    AppStorage.setOrCreate<common.UIAbilityContext>('abilityContext', ctx);
    AppStorage.setOrCreate<string>('filesDir', ctx.filesDir);
    const config: Configuration = this.context.config;
    AppStorage.setOrCreate<string>('colorMode', PlatformContext.colorModeText(config.colorMode));
    const scale: number = config.fontSizeScale === undefined ? 1.0 : config.fontSizeScale;
    AppStorage.setOrCreate<number>('fontSizeScale', scale);

    // 取主窗口，计算初始窗口宽度（vp）并写入断点；注册尺寸/显示变化监听，
    // 让折叠屏开合、2in1/PC 自由窗口缩放都能实时驱动多端布局。
    const win: window.Window = windowStage.getMainWindowSync();
    this.mainWin = win;
    this.updateLayout();
    win.on('windowSizeChange', this.onWindowSizeChange);
    display.on('change', this.onDisplayChange);

    windowStage.loadContent('pages/IndexPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Content loaded');
    });
  }

  onWindowStageDestroy(): void {
    if (this.mainWin !== undefined) {
      this.mainWin.off('windowSizeChange', this.onWindowSizeChange);
      display.off('change', this.onDisplayChange);
      this.mainWin = undefined;
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'onDestroy');
  }

  /**
   * 依据主窗口实际宽度（px）换算 vp，刷新 AppStorage 里的窗口宽度与断点。
   * 监听回调里直接重新查询窗口属性，避免依赖回调参数形态的差异。
   */
  private updateLayout(): void {
    if (this.mainWin === undefined) {
      return;
    }
    const density: number = display.getDefaultDisplaySync().densityPixels;
    if (density <= 0) {
      return;
    }
    const rect = this.mainWin.getWindowProperties().windowRect;
    const widthVp: number = rect.width / density;
    setBreakpointForWidth(widthVp);
  }

  private onWindowSizeChange: () => void = (): void => {
    this.updateLayout();
  };

  private onDisplayChange: (id: number) => void = (_id: number): void => {
    this.updateLayout();
  };
}
