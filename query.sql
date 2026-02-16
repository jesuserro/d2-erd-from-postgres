WITH
-- Ajusta aquí los schemas a exportar
target_schemas AS (
  SELECT unnest(ARRAY[
    'control_plane',
    'frontier',
    'mdm',
	'books',
	'knowledge',	
	'taxonomy',
	'metrics',
	'utils'
  ]) AS table_schema
),

primary_keys AS (
  SELECT
    kcu.table_schema,
    kcu.table_name,
    kcu.column_name AS key_column
  FROM information_schema.table_constraints tco
  JOIN information_schema.key_column_usage kcu
    ON kcu.constraint_name = tco.constraint_name
   AND kcu.constraint_schema = tco.constraint_schema
  WHERE tco.constraint_type = 'PRIMARY KEY'
),

foreign_key_relationships AS (
  SELECT
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name   AS foreign_table_name,
    ccu.column_name  AS foreign_column_name
  FROM information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
   AND tc.table_schema    = kcu.table_schema
  JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
   AND ccu.table_schema    = tc.table_schema
  WHERE tc.constraint_type = 'FOREIGN KEY'
),

cols AS (
  SELECT
    c.table_schema,
    c.table_name,
    c.column_name,
    c.data_type,
    (c.is_nullable = 'YES') AS is_nullable,
    (COUNT(fkr.*) >= 1) AS is_fk
  FROM information_schema.columns c
  LEFT JOIN foreign_key_relationships fkr
    ON c.table_schema  = fkr.table_schema
   AND c.table_name    = fkr.table_name
   AND c.column_name   = fkr.column_name
  GROUP BY
    c.table_schema, c.table_name, c.column_name, c.data_type, c.is_nullable
)

SELECT
  c.table_schema,
  c.table_name,
  pk.key_column AS primary_key,
  JSON_AGG(DISTINCT cols) AS columns,
  JSON_AGG(DISTINCT fkr)  AS foreign_relations
FROM information_schema.columns c
JOIN target_schemas ts
  ON ts.table_schema = c.table_schema
JOIN primary_keys pk
  ON pk.table_schema = c.table_schema
 AND pk.table_name   = c.table_name
LEFT JOIN foreign_key_relationships fkr
  ON fkr.table_schema = c.table_schema
 AND fkr.table_name   = c.table_name
LEFT JOIN cols
  ON cols.table_schema = c.table_schema
 AND cols.table_name   = c.table_name
GROUP BY
  c.table_schema, c.table_name, pk.key_column
ORDER BY
  c.table_schema, c.table_name;
