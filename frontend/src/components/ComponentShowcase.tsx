import React from "react";
import { UiButton } from "./UiButton";
import "./ui-input.css";
import "./ui-link.css";
import "./ui-helpers.css";

export function ComponentShowcase() {
  return (
    <div className="ui-panel" style={{ marginTop: 'var(--space-md)' }}>
      <h3 className="ui-title">组件演示区</h3>
      <p className="ui-status ui-mb-md">覆盖 4 风格 + 明暗模式的基础交互态（hover/active/disabled/focus）。</p>

      {/* Buttons */}
      <div className="ui-row ui-row--gap-md ui-mb-md">
        <UiButton>Primary</UiButton>
        <UiButton variant="ghost">Ghost</UiButton>
        <UiButton variant="danger">Danger</UiButton>
        <UiButton disabled>Disabled</UiButton>
        <UiButton variant="ghost" disabled>Ghost Disabled</UiButton>
      </div>

      {/* Inputs */}
      <div className="ui-row ui-row--gap-md ui-mb-md" style={{ alignItems: 'flex-start' }}>
        <div>
          <label className="ui-status ui-status--small">默认</label>
          <input className="ui-input" placeholder="占位符示例" />
        </div>
        <div>
          <label className="ui-status ui-status--small">错误</label>
          <input className="ui-input" aria-invalid="true" placeholder="输入存在错误" />
        </div>
        <div>
          <label className="ui-status ui-status--small">成功</label>
          <input className="ui-input ui-input--success" placeholder="校验通过" />
        </div>
        <div>
          <label className="ui-status ui-status--small">警告</label>
          <input className="ui-input ui-input--warning" placeholder="需要注意" />
        </div>
        <div>
          <label className="ui-status ui-status--small">禁用</label>
          <input className="ui-input" disabled placeholder="禁用不可编辑" />
        </div>
      </div>

      {/* Links */}
      <div className="ui-row ui-row--gap-md ui-mb-md">
        <a href="#" className="ui-link">标准链接</a>
        <a href="#" className="ui-link" aria-current="page">当前页面</a>
        <a href="#" className="ui-link ui-link--active">激活链接</a>
        <a href="#" className="ui-link ui-link--muted">弱化链接</a>
        <span className="ui-status ui-status--small">在不同风格与明暗模式下，悬浮与焦点会展示不同色与可访问态。</span>
      </div>

  {/* Card / Panel */}
  <div className="ui-panel" style={{ boxShadow: 'var(--shadow-sm)', marginTop: 'var(--space-sm)' }}>
    <h4 className="ui-title">卡片 / Panel 示例</h4>
    <p className="ui-status">此处使用 panel-bg/panel-border/radius-md/space 变量。</p>
    <div className="ui-actions">
      <UiButton variant="ghost">查看</UiButton>
      <UiButton variant="ghost">更多</UiButton>
    </div>
  </div>

  {/* Card / Panel - Selected */}
  <div
    className="ui-panel is-selected"
    aria-selected="true"
    style={{ marginTop: 'var(--space-sm)' }}
  >
    <h4 className="ui-title">选中态 Panel 示例</h4>
    <p className="ui-status">使用 panel-selected-* 与 link-active-color（作为回退）驱动选中态边框与阴影。</p>
    <div className="ui-actions">
      <UiButton variant="ghost">设为活动</UiButton>
      <UiButton variant="ghost">取消</UiButton>
    </div>
  </div>
    </div>
  );
}