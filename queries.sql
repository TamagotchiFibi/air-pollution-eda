-- =====================================================================
--  Аналитические SQL-запросы к таблице air_pollution (SQLite)
--  Таблица создаётся из air_pollution.csv в ноутбуке (data.to_sql).
--  Колонки с пробелами берутся в квадратные скобки: [AQI Value].
-- =====================================================================


-- 1. Покрытие данных: сколько всего стран и городов
SELECT COUNT(DISTINCT Country) AS countries,
       COUNT(DISTINCT City)    AS cities
FROM air_pollution;


-- 2. Распределение по категориям AQI с долей от всех записей.
--    Оконная функция SUM(...) OVER () даёт общий итог без отдельного запроса.
SELECT [AQI Category],
       COUNT(*)                                              AS cities,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)    AS pct_of_total
FROM air_pollution
GROUP BY [AQI Category]
ORDER BY cities DESC;


-- 3. Топ-10 стран по доле «нездоровых» городов (AQI > 150),
--    только среди репрезентативных стран (>= 10 городов).
--    CTE отделяет расчёт агрегатов от фильтрации и сортировки.
WITH country_stats AS (
    SELECT Country,
           COUNT(*)                                          AS cities,
           SUM(CASE WHEN [AQI Value] > 150 THEN 1 ELSE 0 END) AS unhealthy_cities
    FROM air_pollution
    GROUP BY Country
)
SELECT Country,
       cities,
       ROUND(100.0 * unhealthy_cities / cities, 1) AS pct_unhealthy
FROM country_stats
WHERE cities >= 10
ORDER BY pct_unhealthy DESC
LIMIT 10;


-- 4. Самый загрязнённый город каждой страны (топ-10 худших из них).
--    ROW_NUMBER() с PARTITION BY нумерует города внутри каждой страны
--    по убыванию AQI; берём первый (rn = 1).
WITH ranked AS (
    SELECT Country,
           City,
           [AQI Value] AS aqi,
           ROW_NUMBER() OVER (PARTITION BY Country ORDER BY [AQI Value] DESC) AS rn
    FROM air_pollution
)
SELECT Country, City, aqi
FROM ranked
WHERE rn = 1
ORDER BY aqi DESC
LIMIT 10;


-- 5. Топ-5 самых загрязнённых городов мира и разбивка по загрязнителям.
SELECT Country,
       City,
       [AQI Value]       AS aqi,
       [PM2.5 AQI Value] AS pm25,
       [Ozone AQI Value] AS ozone,
       [NO2 AQI Value]   AS no2,
       [CO AQI Value]    AS co
FROM air_pollution
ORDER BY [AQI Value] DESC
LIMIT 5;


-- 6. Как часто именно PM2.5 «задаёт» итоговый AQI города
--    (значение PM2.5 совпадает с общим AQI) — проверка гипотезы
--    о доминирующем загрязнителе на всём датасете.
SELECT SUM(CASE WHEN [PM2.5 AQI Value] = [AQI Value] THEN 1 ELSE 0 END)         AS pm25_driven,
       COUNT(*)                                                                AS total,
       ROUND(100.0 * SUM(CASE WHEN [PM2.5 AQI Value] = [AQI Value] THEN 1 ELSE 0 END)
             / COUNT(*), 1)                                                     AS pct
FROM air_pollution;
