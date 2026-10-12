/*
 * FingerprintSignal.ets
 * Houpe
 *
 * 分类详情页里的一行：一次读数、一个可展示的值，以及一句
 * "为什么这个值会暴露身份"的教学说明。
 */

/** 值的展示形态，决定 UI 怎么渲染这一行。 */
export enum DisplayHint {
  /** 默认等宽文本 */
  PLAIN = 'plain',
  /** 纵向的标签-值对列表 */
  KEY_VALUE = 'keyValue',
  /** 横向并排的三轴/向量数据 */
  AXIS = 'axis',
  /** 自动换行的胶囊标签 */
  TAGS = 'tags',
  /** 复合值：并排的若干带标签部分 */
  COMPOUND = 'compound'
}

/**
 * 信号的组成部分，用于 KEY_VALUE / AXIS / TAGS / COMPOUND 形态。
 */
export class SignalEntry {
  label: string;
  value: string;

  constructor(label: string, value: string) {
    this.label = label;
    this.value = value;
  }
}

/**
 * 一条指纹信号。纯数据，不含任何 UI 依赖。
 */
export class FingerprintSignal {
  /** 稳定标识，同一分类下唯一 */
  id: string;
  /** 读数名称 */
  name: string;
  /** 可展示的值 */
  value: string;
  /** 解释为什么这个值能识别你 */
  rationale: string;
  /** 值的展示形态 */
  hint: DisplayHint;
  /** 组成部分 */
  entries: SignalEntry[] | null;

  constructor(id: string, name: string, value: string, rationale: string,
    hint: DisplayHint = DisplayHint.PLAIN, entries: SignalEntry[] | null = null) {
    this.id = id;
    this.name = name;
    this.value = value;
    this.rationale = rationale;
    this.hint = hint;
    this.entries = entries;
  }
}

/**
 * Provider 内部使用的便捷构造器：用分类 id 作为前缀，
 * 保证 id 在多次启动间保持稳定。
 */
export function makeSignal(key: string, categoryId: string, name: string, value: string,
  rationale: string, hint: DisplayHint = DisplayHint.PLAIN,
  entries: SignalEntry[] | null = null): FingerprintSignal {
  return new FingerprintSignal(`${categoryId}.${key}`, name, value, rationale, hint, entries);
}

/**
 * 把一组条目渲染成紧凑的单行文本，供 PLAIN 形态使用。
 */
export function entriesToPlain(entries: SignalEntry[]): string {
  return entries.map(e => `${e.label} ${e.value}`).join('  ');
}
