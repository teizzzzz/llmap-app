/** 未実装ページの共通占位。タイトル＋説明＋実装予定 Step を明示する。 */
export default function Placeholder({
  title,
  description,
  step,
}: {
  title: string;
  description: string;
  step: string;
}) {
  return (
    <>
      <div className="page-header">
        <h1>{title}</h1>
        <p>{description}</p>
      </div>
      <div className="placeholder">
        <div className="step">{step}</div>
        <p>This page is a placeholder — the feature is planned but not built yet.</p>
      </div>
    </>
  );
}
