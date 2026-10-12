/*
 * OnboardingCoordinator.ets
 * Houpe
 *
 * 负责把「重看引导」的回调从 IndexPage 透传到路由中的 AboutPage。
 * AppStorage 不支持存储函数，因此用模块级引用中转。
 */

let replayCallback: (() => void) | null = null;

export function setReplayOnboardingCallback(cb: () => void): void {
  replayCallback = cb;
}

export function replayOnboarding(): void {
  if (replayCallback !== null) {
    replayCallback();
  }
}
