import Link from "next/link";

type Props = {
  page: number;
  total: number;
  perPage: number;
  basePath: string;
  extraParams?: Record<string, string>;
};

// Windowed Link-based pager (10 rows per page everywhere in this app).
export default function Pager({ page, total, perPage, basePath, extraParams }: Props) {
  const pages = Math.max(1, Math.ceil(total / perPage));
  if (total === 0) return null;

  const href = (p: number) => {
    const params = new URLSearchParams(extraParams || {});
    params.set("page", String(p));
    return basePath + "?" + params.toString();
  };

  const window: number[] = [];
  const start = Math.max(1, Math.min(page - 2, pages - 4));
  const end = Math.min(pages, start + 4);
  for (let p = start; p <= end; p++) window.push(p);

  return (
    <div className="pager">
      <span className="pager-info">
        Showing {(page - 1) * perPage + 1}-{Math.min(page * perPage, total)} of {total}
      </span>
      <span className="pager-links">
        <Link href={href(Math.max(1, page - 1))} className={"pager-btn" + (page <= 1 ? " disabled" : "")}>
          Prev
        </Link>
        {start > 1 ? <Link href={href(1)} className="pager-btn">1</Link> : null}
        {start > 2 ? <span className="pager-btn disabled">...</span> : null}
        {window.map((p) => (
          <Link key={p} href={href(p)} className={"pager-btn" + (p === page ? " current" : "")}>
            {p}
          </Link>
        ))}
        {end < pages - 1 ? <span className="pager-btn disabled">...</span> : null}
        {end < pages ? <Link href={href(pages)} className="pager-btn">{pages}</Link> : null}
        <Link href={href(Math.min(pages, page + 1))} className={"pager-btn" + (page >= pages ? " disabled" : "")}>
          Next
        </Link>
      </span>
    </div>
  );
}
