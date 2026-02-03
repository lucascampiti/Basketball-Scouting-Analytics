CREATE TABLE [dbo].[partidos] (
    [id_partido]  INT            NULL,
    [fecha]       DATE           NULL,
    [rival]       NVARCHAR (100) NULL,
    [competencia] NVARCHAR (100) NULL,
    [categoria]   NVARCHAR (50)  NULL,
    [resultado]   NVARCHAR (50)  NULL,
    [condicion]   VARCHAR (50)   NULL,
    [publico]     VARCHAR (50)   NULL,
    [temperatura] FLOAT (53)     NULL,
    [humedad]     FLOAT (53)     NULL
);

CREATE TABLE [dbo].[jugadoras] (
    [id_jugadora]         TINYINT       NOT NULL,
    [nombre]              NVARCHAR (50) NULL,
    [apellido]            NVARCHAR (50) NULL,
    [fecha_de_nacimiento] DATE          NULL,
    [equipo]              NVARCHAR (50) NULL,
    CONSTRAINT [PK_jugadoras] PRIMARY KEY CLUSTERED ([id_jugadora] ASC)
);

CREATE TABLE [dbo].[estadisticas] (
    [id_jugadora]         TINYINT       NULL,
    [id_partido]          TINYINT       NULL,
    [minutos_jugados]     FLOAT (53)    NULL,
    [puntos]              TINYINT       NULL,
    [triples_intentados]  TINYINT       NULL,
    [triples_convertidos] TINYINT       NULL,
    [porcentaje_3]        NVARCHAR (50) NULL,
    [dobles_intentados]   TINYINT       NULL,
    [dobles_convertidos]  TINYINT       NULL,
    [porcentaje_2p]       NVARCHAR (50) NULL,
    [libres_intentados]   TINYINT       NULL,
    [libres_convertidos]  TINYINT       NULL,
    [porcentaje_tl]       NVARCHAR (50) NULL,
    [reb_def]             TINYINT       NULL,
    [reb_ofe]             TINYINT       NULL,
    [reb_tot]             TINYINT       NULL,
    [tap]                 TINYINT       NULL,
    [asist]               TINYINT       NULL,
    [perd]                TINYINT       NULL,
    [rec]                 TINYINT       NULL,
    [faltas_prop]         TINYINT       NULL,
    [faltas_Rec]          TINYINT       NULL
);

CREATE OR ALTER PROCEDURE Cargar_Datos_Nuevos
AS
BEGIN
    SET NOCOUNT ON;
    SET DATEFORMAT dmy;

    TRUNCATE TABLE estadisticas;
    DELETE FROM partidos;
    DELETE FROM jugadoras;

    INSERT INTO jugadoras (id_jugadora, nombre, apellido)
    SELECT id_jugadora, nombre, apellido FROM jugadoras_temp;

    INSERT INTO partidos (id_partido, fecha, rival, competencia, categoria, resultado,condicion,publico,temperatura,humedad)
    SELECT id_partido, TRY_CAST(fecha AS DATE), rival, competencia, categoria, resultado,condicion,publico,temperatura,humedad
    FROM partidos_temp;

    -- Corregimos la sintaxis del INSERT con su lista de columnas
    INSERT INTO estadisticas (
        id_jugadora, id_partido, minutos_jugados, puntos, triples_intentados, 
        triples_convertidos, porcentaje_3, dobles_intentados, dobles_convertidos, 
        porcentaje_2p, libres_intentados, libres_convertidos, porcentaje_tl, 
        reb_def, reb_ofe, reb_tot, tap, asist, perd, rec, faltas_prop, faltas_Rec
    )
    SELECT 
        id_jugadora, id_partido, 
        CAST(REPLACE(minutos_jugados, ',', '.') AS DECIMAL(10,2)),
        puntos, triples_intentados, triples_convertidos, porcentaje_3,
        dobles_intentados, dobles_convertidos, porcentaje_2p, libres_intentados,
        libres_convertidos, porcentaje_tl, reb_def, reb_ofe, reb_tot, tap,
        asist, perd, rec, faltas_prop, faltas_Rec
    FROM estadisticas_temp;
END;

GO

CREATE OR ALTER VIEW vista_efectividad_equipo AS
SELECT 
    j.nombre AS 'Nombre', 
    j.apellido AS 'Apellido', 
    p.categoria, 
    p.competencia AS 'Competencia',
    ROUND(SUM(e.minutos_jugados), 2) AS 'Total_minutos_Jugados',
    ROUND(AVG(e.minutos_jugados), 2) AS 'promedio_minutos_jugados',
    COUNT(p.id_partido) AS 'Partidos_jugados',
    CAST(SUM(e.triples_convertidos) * 1.0 / NULLIF(SUM(e.triples_intentados), 0) AS DECIMAL(10,2)) AS 'Efectividad_Triples',
    CAST(SUM(e.dobles_convertidos) * 1.0 / NULLIF(SUM(e.dobles_intentados), 0) AS DECIMAL(10,2)) AS 'Efectividad_Dobles',
    CAST(SUM(e.puntos) * 1.0 / NULLIF(SUM(e.minutos_jugados), 0) AS DECIMAL(10,2)) AS 'Puntos_por_Minuto'
FROM estadisticas AS e
JOIN jugadoras AS j ON e.id_jugadora = j.id_jugadora
JOIN partidos AS p ON e.id_partido = p.id_partido
GROUP BY j.nombre, j.apellido, p.competencia, p.categoria
HAVING SUM(e.minutos_jugados) > 1;

GO 

CREATE OR ALTER VIEW vista_analisis_categoria AS 
SELECT 
    j.id_jugadora, 
    j.nombre, 
    j.apellido, 
    p.categoria,
    SUM(e.puntos) AS 'puntos_totales',
    COUNT(e.id_partido) AS 'partidos_jugados',
    CAST(AVG(CAST(e.puntos AS FLOAT)) AS DECIMAL(10,2)) AS 'promedio_puntos'
FROM estadisticas AS e
JOIN jugadoras AS j ON e.id_jugadora = j.id_jugadora
JOIN partidos AS p ON e.id_partido = p.id_partido
GROUP BY j.id_jugadora, j.nombre, j.apellido, p.categoria;

GO

CREATE OR ALTER VIEW vista_comparativa_progreso AS 
SELECT 
    id_jugadora, 
    nombre, 
    apellido,
    SUM(CASE WHEN categoria = 'u14' THEN promedio_puntos ELSE 0 END) AS 'promedio_u14',
    SUM(CASE WHEN categoria = 'u15' THEN promedio_puntos ELSE 0 END) AS 'promedio_u15',
    CAST(
        ((SUM(CASE WHEN categoria = 'u15' THEN promedio_puntos ELSE 0 END) - 
          SUM(CASE WHEN categoria = 'u14' THEN promedio_puntos ELSE 0 END)) 
        / NULLIF(SUM(CASE WHEN categoria = 'u14' THEN promedio_puntos ELSE 0 END), 0)) * 100 
    AS DECIMAL(10,2)) AS 'porcentaje_mejora'
FROM vista_analisis_categoria
GROUP BY id_jugadora, nombre, apellido;

GO 

CREATE OR ALTER VIEW rendimiento_clima AS (
SELECT j.id_jugadora, 
j.nombre AS [Nombre],
j.apellido AS [Apellido],
p.id_partido,
p.rival AS [Rival],
p.resultado AS [Resultado],
p.condicion AS [Condicion],
p.publico AS [Publico],
p.humedad AS [Humedad],
p.temperatura AS [Temperatura],
e.puntos AS [puntos convertidos]
FROM estadisticas AS e 
INNER JOIN partidos AS p ON p.id_partido = e.id_partido
JOIN jugadoras AS j ON j.id_jugadora = e.id_jugadora

);

-- Data Enrichment: Generating synthetic climate data for analysis.

UPDATE partidos 
SET temperatura = (id_partido % 15) + 18
WHERE temperatura IS NULL;


UPDATE partidos 
SET humedad = (id_partido % 51) + 40
WHERE humedad IS NULL;

UPDATE partidos 
SET publico = CAST(((id_partido * 13) % 201 + 50) AS VARCHAR(50))
WHERE publico IS NULL;

UPDATE partidos 
SET condicion = CASE 
    WHEN id_partido % 2 = 0 THEN 'Local'
    ELSE 'Visitante' 
END
WHERE condicion IS NULL;