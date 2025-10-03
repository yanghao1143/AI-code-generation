import React, { useEffect, useState, useCallback } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  getArticle,
  updateArticle,
  deleteArticle,
  type Article,
} from "../api/client";
import { Loading } from "../components/Loading";
import { ErrorBox } from "../components/Error";
import { Empty } from "../components/Empty";
import { emitToast } from "../utils/toast";
import { UiButton } from "../components/UiButton";
import "../components/ui-input.css";
import "../components/ui-helpers.css";

export function Detail() {
  const { id = "" } = useParams();
  const nav = useNavigate();
  const [item, setItem] = useState<Article | null>(null);
  const [title, setTitle] = useState("");
  const [content, setContent] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const permsStr = (localStorage.getItem("userPerms") || "").trim();
  const permsSet = new Set(permsStr.split(/[\s,]+/).filter(Boolean));
  const hasAll = permsSet.has("articles");
  const canRead = hasAll || permsSet.has("articles:read");
  const canEdit = hasAll || permsSet.has("articles:update");
  const canDelete = hasAll || permsSet.has("articles:delete");

  const getErr = (e: unknown): string =>
    e instanceof Error ? e.message : String(e);

  const load = useCallback(async () => {
    if (!canRead) {
      setLoading(false);
      setError("权限不足：需要 articles 或 articles:read 才能查看文章详情");
      emitToast("warning", "权限不足：无法读取文章详情");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const a = await getArticle(id);
      setItem(a);
      setTitle(a.title);
      setContent(a.content);
    } catch (e: unknown) {
      setError(getErr(e));
    } finally {
      setLoading(false);
    }
  }, [id, canRead]);

  useEffect(() => {
    load();
  }, [load]);

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canEdit) {
      emitToast("warning", "无编辑权限（需要 articles 或 articles:update）");
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const a = await updateArticle(id, { title, content });
      setItem(a);
    } catch (e: unknown) {
      setError(getErr(e));
    } finally {
      setLoading(false);
    }
  };

  const remove = async () => {
    if (!canDelete) {
      emitToast("warning", "无删除权限（需要 articles 或 articles:delete）");
      return;
    }
    if (!confirm("确认删除该文章？")) return;
    setLoading(true);
    setError(null);
    try {
      await deleteArticle(id);
      nav("/");
    } catch (e: unknown) {
      setError(getErr(e));
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <Loading />;
  if (error) return <ErrorBox message={error} />;
  if (!item) return <Empty />;

  return (
    <div className="ui-density--compact">
      <h2 className="ui-title">Article Detail</h2>
      <div className="ui-panel ui-mb-md">
        <form onSubmit={save}>
          <div className="ui-row ui-row--gap-md">
            <input
              className="ui-input"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="title"
              disabled={!canEdit}
            />
            <input
              className="ui-input"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              placeholder="content"
              disabled={!canEdit}
            />
          </div>
          <div className="ui-actions ui-mt-sm">
            <UiButton type="submit" disabled={!canEdit}>Save</UiButton>
            <UiButton type="button" variant="danger" onClick={remove} disabled={!canDelete}>
              Delete
            </UiButton>
          </div>
        </form>
      </div>
      {(!canRead || !canEdit || !canDelete) && (
        <small className="ui-status ui-status--small ui-mb-sm">
          权限提示：查看需要 <code className="ui-inline-gap">articles</code> 或 <code className="ui-inline-gap">articles:read</code>；编辑需要 <code className="ui-inline-gap">articles</code> 或 <code className="ui-inline-gap">articles:update</code>；删除需要 <code className="ui-inline-gap">articles</code> 或 <code className="ui-inline-gap">articles:delete</code>。
        </small>
      )}
      <div className="ui-panel">
        <strong>ID:</strong> {item.id}
      </div>
    </div>
  );
}