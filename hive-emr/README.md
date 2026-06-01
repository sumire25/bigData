# Hive EMR - Laboratorio 04

Cada subdirectorio contiene scripts de **Terraform** que levantan un clúster **EMR** en AWS para ejecutar análisis de datos sobre dos datasets distintos:

- **Documentos de texto plano** (resultados electorales fragmentados en 60 `chunk_*`)
- **Viajes de taxi amarillo de NYC** (año 2026, datos en Parquet)

---

## Estructura

```
hive-emr/
├── hive/              → Análisis con Hive puro (single-scan)
├── mapReduceJobs/     → Análisis con MapReduce (Java custom)
├── taxi/              → Análisis analítico de datos de taxi NYC 2026
└── query_results/     → Resultados de todas las ejecuciones
```

---

## 1. `hive/` — Análisis de documentos con Hive puro

**main.tf** crea un clúster EMR con Hadoop + Hive y ejecuta un **único step** que escanea una sola vez los datos (`single-scan`) para producir dos resultados simultáneamente:

### Step: `Execute_Pure_Hive_Pipeline`

- Crea la tabla externa `raw_docs` apuntando a `s3://onpe-datalake-mx/resultados_finales_csv_v5_split/` (60 fragmentos CSV de ~27 MB cada uno).
- Con `LATERAL VIEW explode(split(...))` tokeniza cada línea en palabras y cuenta ocurrencias por archivo y palabra.
- En una sola consulta con **múltiples `INSERT OVERWRITE`** produce:

| Consulta | Descripción | Output en S3 |
|---|---|---|
| **Word Count** | `word` → `SUM(count)` de todas las ocurrencias, ordenadas por frecuencia descendente. | `query_results/word_count/` |
| **Inverted Index** | `word` → lista de archivos donde aparece (`collect_set`), separada por comas. | `query_results/inverted_index/` |

---

## 2. `mapReduceJobs/` — Análisis de documentos con MapReduce

**main.tf** crea un clúster EMR **solo con Hadoop** (sin Hive) y ejecuta dos steps secuenciales, cada uno corriendo un JAR custom:

### Step 1: `Execute_Inverted_Index`
- JAR: `InvertedIndex.jar` (clase `InvertedIndex`)
- Input: `s3://.../resultados_finales_csv_v5_split/`
- Output: `s3://.../query_results/inverted_index_mr/`
- Genera el índice invertido: cada palabra → archivos donde aparece.

### Step 2: `Execute_Word_Count`
- JAR: `WordCount.jar` (clase `WordCount`)
- Input: `s3://.../resultados_finales_csv_v5_split/`
- Output: `s3://.../query_results/word_count_mr/`
- Cuenta frecuencias de cada palabra en todo el corpus.

Los fuentes Java y los scripts de compilación se incluyen en el directorio (`InvertedIndex.java`, `WordCount.java`, `compileAndUpload.sh`).

---

## 3. `taxi/` — Análisis de viajes de taxi NYC 2026

**main.tf** crea un clúster EMR con Hadoop + Hive y 3 steps que implementan un pipeline ETL + analítico:

### Step 1: `Retrieve_2026_Taxi_Data_via_HTTPS`
- Descarga vía `wget` los 12 archivos Parquet mensuales desde `https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2026-{01..12}.parquet`.
- Los sube a `s3://.../staging/yellow_taxi_2026/`.

### Step 2: `Create_And_Partition_Tables`
- Crea `staging_yellow_taxi` (tabla externa Parquet con 20 columnas).
- Crea `optimized_yellow_taxi` (tabla ORC particionada por `pickup_month` con solo 4 columnas relevantes).
- Convierte `tpep_pickup_datetime` de microsegundos a `TIMESTAMP` y particiona los datos por mes.
- Filtra solo registros del año 2026.

### Step 3: `Execute_Analytical_Queries`
Ejecuta 6 consultas analíticas sobre la tabla optimizada:

| Consulta | Descripción | Output |
|---|---|---|
| **A — metrics_summary** | Total de viajes y distancia promedio. | `query_results/metrics_summary/` |
| **B — traffic_hours** | Horas pico: cantidad de viajes por hora, ordenada de mayor a menor. | `query_results/traffic_hours/` |
| **C — payment_methods** | Conteo de viajes por tipo de pago. | `query_results/payment_methods/` |
| **D — expensive_trips** | Top 10 viajes más costosos (fecha, distancia, monto). | `query_results/expensive_trips/` |
| **E — january_metrics** | Por hora: costo promedio y distancia promedio en enero. | `query_results/january_metrics/` |
| **F — february_metrics** | Por hora: costo promedio y distancia promedio en febrero. | `query_results/february_metrics/` |

---

## Resultados (`query_results/`)

### Word Count (documentos)

Top 20 palabras más frecuentes en el corpus electoral:

| Palabra | Frecuencia |
|---|---|
| partido | 3,255 |
| per | 2,170 |
| 10 | 1,642 |
| 13 | 1,642 |
| 12 | 1,639 |
| 14 | 1,636 |
| 15 | 1,634 |
| tico | 1,240 |
| 0 | 1,022 |
| pol | 930 |
| popular | 775 |
| el | 620 |
| nacional | 515 |
| libertad | 465 |
| votos | 465 |
| 1 | 408 |

_Los resultados de Hive (`word_count/`) y MapReduce (`word_count_mr/`) son equivalentes; el formato difiere (CSV plano vs. particiones de Hadoop)._

### Inverted Index (documentos)

Por cada palabra, lista de fragmentos donde aparece. Ejemplo:

| Palabra | Fragmentos |
|---|---|
| `partido` | chunk_00, chunk_01, …, chunk_59 (60 fragmentos) |
| `1001` | chunk_17 |
| `1004` | chunk_05, chunk_13 |

_Los resultados de Hive (`inverted_index/`) y MapReduce (`inverted_index_mr/`) son equivalentes. La versión Hive incluye la ruta S3 completa; la versión MR solo el nombre del chunk._

### Resultados adicionales

| Carpeta | Contenido |
|---|---|
| `top_words/` | Mismo resultado que `word_count/` (generado en una ejecución alternativa). |
| `juntos_files/` | Lista de archivos con conteo de ocurrencias de la palabra "juntos". |

### Métricas de Taxi NYC 2026

#### A — Resumen general (`metrics_summary/`)

```
total_trips, avg_distance
14,877,858 , 5.96
```

14.9 millones de viajes con una distancia promedio de **5.96 millas**.

#### B — Horas pico (`traffic_hours/`)

```
hora, viajes
18, 1,061,244
17, 1,004,758
19, 941,624
...
```

Las horas pico son **17-19 (5-7 PM)**, con máximo a las **6 PM** (~1M de viajes). Las horas de menor actividad son **3-5 AM** (~120K viajes).

#### C — Métodos de pago (`payment_methods/`)

| Código | Viajes |
|---|---|
| 0 | 3,856,909 |
| 1 (tarjeta crédito) | 9,519,040 |
| 2 (efectivo) | 1,298,848 |
| 3 | 53,465 |
| 4 | 149,596 |

El **64%** de los viajes se pagan con tarjeta de crédito (código 1).

#### D — Top 10 viajes más costosos (`expensive_trips/`)

| Fecha | Distancia (mi) | Monto total ($) |
|---|---|---|
| 2026-01-25 00:43 | 48.65 | 2,560.20 |
| 2026-01-15 13:56 | 0.00 | 2,500.00 |
| 2026-02-22 19:31 | 41.62 | 2,088.85 |
| 2026-03-05 17:15 | 205.86 | 1,850.55 |
| 2026-02-22 05:47 | 221.27 | 1,580.14 |
| 2026-04-03 09:13 | 216.84 | 1,452.66 |
| 2026-03-27 15:42 | 5.61 | 1,441.35 |
| 2026-02-01 03:47 | 17.67 | 1,290.45 |
| 2026-04-01 19:01 | 195.20 | 1,278.40 |
| 2026-03-22 11:33 | 167.82 | 1,157.41 |

#### E — Enero 2026, métricas por hora (`january_metrics/`)

Las horas con mayor costo promedio son **5 AM** ($33.93) y **4 AM** ($31.21). Las distancias más largas promedio se dan a las **7 AM** (17.3 mi) y **5 AM** (15.2 mi).

#### F — Febrero 2026, métricas por hora (`february_metrics/`)

Similar a enero: los costos promedio más altos son **5 AM** ($36.13) y **4 AM** ($35.63). La mayor distancia promedio es a las **6 AM** (15.1 mi).
