import React, { useEffect, useState, useCallback } from "react";
import { Link } from "react-router-dom";
import { createArticle, listArticlesPaged, type Article, type ArticlesPage } from "../api/client";
import { Loading } from "../components/Loading";
import { ErrorBox } from "../components/Error";
import { Empty } from "../components/Empty";
import { ProgressBar } from "../components/ProgressBar";
import { Paginator } from "../components/Paginator";
import { emitToast } from "../utils/toast";
import { hasArticlesPerm, ensureArticlesPerm } from "../utils/permissions";
import { VirtualList } from "../components/VirtualList";
import { UiButton } from "../components/UiButton";
import { FormHint } from "../components/FormHint";
import "../components/ui-input.css";
import "../components/ui-helpers.css";

export function Articles() {
  const [items, setItems] = useState<Article[]>([]);
  const [title, setTitle] = useState("Hello");
  const [content, setContent] = useState("World");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [pageSize] = useState(10);
  const [afterId, setAfterId] = useState<string | undefined>(undefined);
  const [hasMore, setHasMore] = useState(false);
  const [pageMeta, setPageMeta] = useState<ArticlesPage["page"] | undefined>(undefined);
  const [pageIndex, setPageIndex] = useState(0); // 0-based

  // 统一使用权限工具
  const canRead = hasArticlesPerm("read");
  const canCreate = hasArticlesPerm("create");

  // 简单的页缓存用于预取
  const prefetchCacheRef = React.useRef<Map<number, { items: Article[]; page?: ArticlesPage["page"] }>>(new Map());

  const getErr = (e: unknown): string =>
    e instanceof Error ? e.message : String(e);

  const load = useCallback(async () => {
    if (!ensureArticlesPerm("read", "权限不足：无法读取文章列表")) {
      setLoading(false);
      setItems([]);
      setPageMeta(undefined);
      setAfterId(undefined);
      setHasMore(false);
      setError("权限不足：需要 articles 或 articles:read 才能查看文章列表");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      // 命中预取缓存则先行展示
      const cached = prefetchCacheRef.current.get(pageIndex);
      if (cached) {
        setItems(cached.items);
        setPageMeta(cached.page);
        setHasMore(Boolean(cached.page?.hasMore));
        setAfterId(cached.page?.nextAfterId);
      }
      // 使用 limit/offset 进行页码导航，同时传递 pageSize 便于后端返回 page 元信息
      const res = await listArticlesPaged({ limit: pageSize, offset: pageIndex * pageSize, pageSize });
      setItems(res.items);
      setAfterId(res.page?.nextAfterId);
      setHasMore(Boolean(res.page?.hasMore));
      setPageMeta(res.page);
      // 更新缓存
      prefetchCacheRef.current.set(pageIndex, { items: res.items, page: res.page });
    } catch (e: unknown) {
      setError(getErr(e));
    } finally {
      setLoading(false);
    }
  }, [pageIndex, pageSize]);

  useEffect(() => {
    load();
  }, [load]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!ensureArticlesPerm("create", "权限不足：无法创建文章")) {
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const userId = localStorage.getItem("userId") || "u1";
      await createArticle({ title, content, authorId: userId });
      setTitle("");
      setContent("");
      setAfterId(undefined);
      setPageIndex(0);
      await load();
    } catch (e: unknown) {
      setError(getErr(e));
    } finally {
      setLoading(false);
    }
  };

  const loadMore = async () => {
    if (!hasMore || !afterId) return;
    setLoading(true);
    setError(null);
    try {
      const res = await listArticlesPaged({ pageSize, afterId });
      setItems((prev) => [...prev, ...res.items]);
      setAfterId(res.page?.nextAfterId);
      setHasMore(Boolean(res.page?.hasMore));
      setPageMeta(res.page);
    } catch (e: unknown) {
      setError(getErr(e));
    } finally {
      setLoading(false);
    }
  };

  const onPageChange = async (idx: number) => {
    setPageIndex(idx);
  };

  const onPrefetch = async (nextIdx: number) => {
    // 预取下一页数据并写入缓存
    if (!hasArticlesPerm("read")) return;
    if (prefetchCacheRef.current.has(nextIdx)) return;
    try {
      const res = await listArticlesPaged({ limit: pageSize, offset: nextIdx * pageSize, pageSize });
      prefetchCacheRef.current.set(nextIdx, { items: res.items, page: res.page });
    } catch {
      // ignore prefetch errors
    }
  };

  return (
    <div className="ui-density--compact">
      <h2 className="ui-title">Articles</h2>
      <div className="ui-panel ui-mb-md">
        <form onSubmit={submit}>
          <div className="ui-row ui-row--gap-md">
            <input
              className="ui-input"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="title"
            />
            <input
              className="ui-input"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="content"
            />
          </div>
          <div className="ui-actions ui-mt-sm">
            <UiButton type="submit" disabled={loading || !canCreate}>
              Create
            </UiButton>
            <UiButton type="button" onClick={load} disabled={loading || !canRead}>
              Refresh
            </UiButton>
          </div>
        </form>
      </div>
      {!canCreate && (
        <FormHint variant="warning">
          当前权限不足，需具备 <code className="ui-inline-gap">articles</code> 或 <code className="ui-inline-gap">articles:create</code> 才能创建文章。
        </FormHint>
      )}
      {!canRead && (
        <FormHint variant="warning">
          无查看权限，需具备 <code className="ui-inline-gap">articles</code> 或 <code className="ui-inline-gap">articles:read</code> 才能查看文章列表。
        </FormHint>
      )}
      {error && <ErrorBox message={error} />}
      {loading && <Loading />}
      {!loading && items.length === 0 && canRead && <Empty />}
      {pageMeta && (
        <small className="ui-status ui-mb-sm">
          分页信息：pageSize={pageMeta.pageSize ?? "-"}, nextAfterId={pageMeta.nextAfterId ?? "-"}, hasMore={String(pageMeta.hasMore ?? false)}, total={pageMeta.total ?? "-"}
        </small>
      )}
      {pageMeta?.total != null && (
        <div className="ui-mb-md">
          <ProgressBar loaded={items.length} total={pageMeta.total ?? 0} height={10} />
        </div>
      )}
      {pageMeta?.total != null && (
        <div className="ui-mb-md">
          <Paginator
            pageIndex={pageIndex}
            pageCount={Math.max(1, Math.ceil((pageMeta?.total ?? 0) / (pageMeta?.pageSize ?? pageSize)))}
            disabled={loading}
            onChange={onPageChange}
            variant="compact"
            responsive
            onPrefetch={onPrefetch}
          />
        </div>
      )}
      <div className="ui-panel ui-mb-md">
        <VirtualList
          items={items}
          height={420}
          itemHeight={44}
          overscan={4}
          getKey={(a) => a.id}
          renderItem={(a) => (
            <div className="ui-row">
              <strong>{a.title}</strong> - {a.content} —{" "}
              <Link to={`/articles/${a.id}`} className="ui-link">
                详情
              </Link>
            </div>
          )}
        />
      </div>
      {/* 当总数可用时，优先使用页码导航，不再显示“加载更多” */}
      {hasMore && pageMeta?.total == null && canRead && (
        <UiButton type="button" onClick={loadMore} disabled={loading}>
          加载更多
        </UiButton>
      )}
    </div>
  );
}