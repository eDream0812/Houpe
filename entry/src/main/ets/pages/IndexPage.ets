/*
 * IndexPage.ets
 * Houpe
 *
 * 应用入口页。首次启动展示引导，之后直接进首页。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { HomePage } from '../views/HomePage';
import { OnboardingView } from '../views/OnboardingView';
import { store } from '../models/CategoryStore';
import { setReplayOnboardingCallback } from '../common/OnboardingCoordinator';
import { Theme } from '../common/Theme';

const PREF_NAME: string = 'houpe_settings';
const KEY_ONBOARDING_DONE: string = 'onboardingDone';

@Entry
@ComponentV2
struct IndexPage {
  @Local showOnboarding: boolean = false;
  @Local ready: boolean = false;

  async aboutToAppear(): Promise<void> {
    // 先把被动数据采上来，引导页的洞察卡片才能有内容
    await store.refreshPassive();
    this.showOnboarding = !(await this.onboardingDone());
    this.ready = true;
    // 把「重看引导」的能力交给关于页调用（AppStorage 不支持函数，用模块引用中转）
    setReplayOnboardingCallback(() => this.replayOnboarding());
  }

  // 应用退到后台时停止全部实时采样，兑现「不后台运行、不静默持续采样」的承诺
  onPageHide(): void {
    store.stopAllLive();
  }

  build() {
    Column() {
      if (this.ready) {
        if (this.showOnboarding) {
          OnboardingView({
            onFinish: () => {
              this.showOnboarding = false;
              this.markOnboardingDone();
            }
          })
        } else {
          HomePage()
        }
      } else {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(Theme.PAGE_BG)
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 重新走一遍引导流程。
   */
  replayOnboarding(): void {
    this.showOnboarding = true;
  }

  private async onboardingDone(): Promise<boolean> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.BaseContext;
      const pref = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
      const value: preferences.ValueType = pref.getSync(KEY_ONBOARDING_DONE, false);
      return value === true;
    } catch (e) {
      return false;
    }
  }

  private async markOnboardingDone(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.BaseContext;
      const pref = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
      await pref.put(KEY_ONBOARDING_DONE, true);
      await pref.flush();
    } catch (e) {
    }
  }
}
