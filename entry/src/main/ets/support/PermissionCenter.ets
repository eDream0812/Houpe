/*
 * PermissionCenter.ets
 * Houpe
 *
 * 统一的权限请求入口。所有框架各异的授权 API 在这里被归一化成
 * 同一个 AuthStatus，Provider 与 UI 都不需要关心细节。
 */

import { abilityAccessCtrl, common, Permissions, PermissionRequestResult } from '@kit.AbilityKit';
import { PlatformContext } from './PlatformShim';

/**
 * 归一化后的授权状态。
 */
export enum AuthStatus {
  /** 已授权 */
  GRANTED = 'granted',
  /** 被拒绝 */
  DENIED = 'denied',
  /** 尚未询问 */
  NOT_DETERMINED = 'notDetermined',
  /** 受系统策略限制 */
  RESTRICTED = 'restricted',
  /** 不支持该权限 */
  UNAVAILABLE = 'unavailable'
}

/**
 * 权限请求结果。
 */
export class AuthResult {
  status: AuthStatus;
  /** 失败时的原因说明 */
  message: string;

  constructor(status: AuthStatus, message: string = '') {
    this.status = status;
    this.message = message;
  }
}

/**
 * 权限中心。
 */
export class PermissionCenter {
  /**
   * 检查权限当前是否已授权，不触发弹窗。
   */
  static async check(permission: string): Promise<AuthStatus> {
    const ctx: common.UIAbilityContext | undefined = PlatformContext.abilityContext();
    if (ctx === undefined) {
      return AuthStatus.UNAVAILABLE;
    }
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const tokenId: number = ctx.applicationInfo.accessTokenId;
      const status: abilityAccessCtrl.GrantStatus =
        await atManager.checkAccessToken(tokenId, permission as Permissions);
      return PermissionCenter.fromGrantStatus(status);
    } catch (e) {
      return AuthStatus.UNAVAILABLE;
    }
  }

  /**
   * 检查一组权限是否全部授权，不触发弹窗。
   * 任一权限未授权即返回该权限的状态。
   */
  static async checkAll(permissions: string[]): Promise<AuthStatus> {
    for (const permission of permissions) {
      const status: AuthStatus = await PermissionCenter.check(permission);
      if (status !== AuthStatus.GRANTED) {
        return status;
      }
    }
    return AuthStatus.GRANTED;
  }

  /**
   * 请求权限。会触发系统弹窗。
   */
  static async request(permissions: string[]): Promise<AuthResult> {
    const ctx: common.UIAbilityContext | undefined = PlatformContext.abilityContext();
    if (ctx === undefined) {
      return new AuthResult(AuthStatus.UNAVAILABLE, '无法获取应用上下文');
    }
    if (permissions.length === 0) {
      return new AuthResult(AuthStatus.GRANTED);
    }
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult =
        await atManager.requestPermissionsFromUser(ctx, permissions as Permissions[]);

      // 只要有一个被拒绝，就整体判为未授权
      const results: number[] = result.authResults;
      for (let i = 0; i < results.length; i++) {
        if (results[i] !== 0) {
          const deniedName: string = i < result.permissions.length ? result.permissions[i] : '未知权限';
          const reason: string = results[i] === 2 ? '该权限未在配置中声明' : '未获授权';
          return new AuthResult(AuthStatus.DENIED, `${deniedName} ${reason}`);
        }
      }
      return new AuthResult(AuthStatus.GRANTED);
    } catch (e) {
      return new AuthResult(AuthStatus.UNAVAILABLE, '权限请求失败');
    }
  }

  /**
   * 把系统 GrantStatus 转成归一化状态。
   */
  private static fromGrantStatus(s: number): AuthStatus {
    if (s === 0) {
      return AuthStatus.GRANTED;
    }
    if (s === -1) {
      return AuthStatus.DENIED;
    }
    if (s === 2) {
      return AuthStatus.NOT_DETERMINED;
    }
    return AuthStatus.RESTRICTED;
  }

  /**
   * 取授权状态的中文文案。
   */
  static statusText(s: AuthStatus): string {
    switch (s) {
      case AuthStatus.GRANTED:
        return '已授权';
      case AuthStatus.DENIED:
        return '已拒绝';
      case AuthStatus.NOT_DETERMINED:
        return '尚未询问';
      case AuthStatus.RESTRICTED:
        return '受系统限制';
      default:
        return '不可用';
    }
  }
}
