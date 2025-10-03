import React from "react";

type VirtualListProps<T> = {
  items: T[];
  height: number; // 容器高度（px）
  itemHeight: number; // 每项固定高度（px）
  overscan?: number; // 额外渲染的条目数，用于减少滚动抖动
  renderItem: (item: T, index: number) => React.ReactNode;
  getKey?: (item: T, index: number) => React.Key;
  style?: React.CSSProperties;
};

// 简易虚拟列表：固定行高，使用绝对定位渲染可视区域 + overscan
export function VirtualList<T>({
  items,
  height,
  itemHeight,
  overscan = 3,
  renderItem,
  getKey,
  style,
}: VirtualListProps<T>) {
  const containerRef = React.useRef<HTMLDivElement | null>(null);
  const [scrollTop, setScrollTop] = React.useState(0);

  const onScroll = (e: React.UIEvent<HTMLDivElement>) => {
    setScrollTop((e.target as HTMLDivElement).scrollTop);
  };

  const totalHeight = items.length * itemHeight;
  const visibleCount = Math.ceil(height / itemHeight);
  const startIndex = Math.max(0, Math.floor(scrollTop / itemHeight) - overscan);
  const endIndex = Math.min(items.length, startIndex + visibleCount + overscan * 2);

  const topOffset = startIndex * itemHeight;

  return (
    <div
      ref={containerRef}
      className="ui-virtual"
      style={{ ["--virtual-height" as any]: `${height}px`, ...(style || {}) }}
      onScroll={onScroll}
      role="list"
      aria-label="virtual-list"
    >
      <div className="ui-virtual__spacer" style={{ ["--virtual-total-height" as any]: `${totalHeight}px` }} />
      <div className="ui-virtual__inner" style={{ ["--virtual-top-offset" as any]: `${topOffset}px` }}>
        {items.slice(startIndex, endIndex).map((item, i) => {
          const idx = startIndex + i;
          const key = getKey ? getKey(item, idx) : idx;
          return (
            <div
              key={key}
              className="ui-list-item ui-row"
              style={{ ["--list-item-height" as any]: `${itemHeight}px` }}
              role="listitem"
            >
              {renderItem(item, idx)}
            </div>
          );
        })}
      </div>
    </div>
  );
}