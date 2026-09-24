import { useCallback, useEffect, useState } from 'react';
import {
  getDatasets, getFieldStats, getSchema, getStatsSummary,
} from '../api/client';
import type { Dataset, SchemaInfo } from '../api/types';

/** Database / Map で共用する筛选肢の元データ
    （schema の言語 enum・実在の地区/採集者・dataset 一覧・字段の非空数）。 */
export default function useFilterOptions() {
  const [schema, setSchema] = useState<SchemaInfo | null>(null);
  const [datasets, setDatasets] = useState<Dataset[]>([]);
  const [areas, setAreas] = useState<string[]>([]);
  const [collectors, setCollectors] = useState<string[]>([]);
  const [fieldStats, setFieldStats] =
    useState<Record<string, number> | null>(null);

  const refresh = useCallback(() => {
    getSchema().then(setSchema).catch(() => {});
    getDatasets().then(setDatasets).catch(() => {});
    getFieldStats().then(setFieldStats).catch(() => {});
    getStatsSummary()
      .then((s) => {
        setAreas(Object.keys(s.areaCounts).filter((k) => k !== 'unknown'));
        setCollectors(Object.keys(s.collectorCounts).filter((k) => k !== 'unknown'));
      })
      .catch(() => {});
  }, []);
  useEffect(refresh, [refresh]);

  return { schema, datasets, areas, collectors, fieldStats, refresh };
}
