/*
 * HdsFeedback.ets
 * Houpe
 *
 * 轻提示统一入口：优先用 HDS SnackBar，
 * 设备不支持 HDS 图形能力时回退到系统 Toast。
 */

import { HdsSnackBar, SnackBarIconOptions, SnackBarMessageOptions, SnackBarOperationOptions, SnackBarOperationType } from '@kit.UIDesignKit';

export function showHdsToast(ui: UIContext, message: string, symbol: Resource | null = null): void {
  try {
    const icon: SnackBarIconOptions = symbol !== null ? { icon: symbol } : {};
    const msg: SnackBarMessageOptions = { content: message };
    const operation: SnackBarOperationOptions = { operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY };
    const bar: HdsSnackBar = new HdsSnackBar(ui);
    bar.show(icon, msg, operation);
  } catch (e) {
    ui.getPromptAction().showToast({ message: message });
  }
}
