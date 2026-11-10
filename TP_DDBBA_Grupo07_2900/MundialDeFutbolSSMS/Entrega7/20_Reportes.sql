/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 06/11/2026
   Objetivo     : Generación de Reportes de los siguientes grupos de datos: 
                    1. Goleadores por selección, fase y torneo. -> XML
                        1.1 Goleadores Por Selección.
                        1.2 Goleadores Por Fase. 
                        1.3 Goleador del Torneo
                    2. Tarjetas (amarillas y rojas) por selección y jugador, con detalle de suspensiones activas por acumulación. -> XML
                        2.1 Tarjetas Por  Jugador
                        2.2 Tarjetas Por Selección y Jugador
                    3. Designaciones arbitrales: partidos dirigidos por cada árbitro, con las amonestaciones/expulsiones que señaló. -> XML
                    4. Ocupación publicitaria por sede y partido: anunciantes exhibidos en los cuatro espacios, e ingresos generados. -> XML
                    5. Matriz de prime time: tabla cruzada (pivot) que muestre, para cada partido, en qué mercados/países su horario
                        cae en prime time. 
                    6. Selecciones y plantillas: listado de selecciones con un vector anidado de convocados (nombre, posición, club, 
                        dorsal). -> XML
                    7. Resultados de los encuentros 

                 
  ============================================================================= */

USE MundialFutbol;
GO

IF SCHEMA_ID('reportes') IS NULL
    EXEC ('CREATE SCHEMA reportes');
GO

-- =====================================================================
-- 1. Reporte de Goleadores por Selección Fase y torneo. 
-- =====================================================================

-- 1.1 Goleadores Por Seleccion

CREATE OR ALTER PROCEDURE reportes.GoleadoresPorSeleccion
AS 
BEGIN 
    

    WITH GoleadoresPorSeleccion AS
    (
        SELECT g.id_jugador_autor,
               pais.nombre as Seleccion, 
                COUNT(*) as Goles               
        FROM torneo.Gol g
        JOIN personas.Jugador j ON g.id_jugador_autor = j.id_participante
        JOIN torneo.Seleccion s ON j.id_seleccion = s.id_seleccion
        JOIN geo.Pais pais ON s.id_pais = pais.id_pais
        GROUP BY g.id_jugador_autor, pais.nombre
    ), 
    RankingGoleadores AS 
    (
        SELECT id_jugador_autor, 
                Seleccion, Goles,
                DENSE_RANK()OVER (PARTITION BY Seleccion ORDER BY Goles DESC) AS Puesto
        FROM GoleadoresPorSeleccion
    )
    SELECT 
        r.Seleccion,
        info.nombre as Jugador,
        r.Goles 
    FROM RankingGoleadores r
    JOIN personas.Participante info ON r.id_jugador_autor = info.id_participante
    WHERE r.Puesto = 1
    FOR XML AUTO, ROOT ('GoleadoresPorSeleccion'), ELEMENTS;

END;
GO

/*


EXEC reportes.GoleadoresPorSeleccion;


*/

-- 1.2 Goleadores Por Fase


CREATE OR ALTER PROCEDURE reportes.GoleadoresPorFase
AS 
BEGIN 
     --  
    WITH GoleadoresPorFase AS
    (
        SELECT g.id_jugador_autor,
                fase.fase as NombreFase,
                COUNT(*) as Goles               
        FROM torneo.Gol g
        JOIN torneo.Partido fase ON g.id_partido = fase.id_partido
        GROUP BY g.id_jugador_autor, fase.fase
    ), 
    RankingGoleadores AS 
    (
        SELECT id_jugador_autor, 
                NombreFase, Goles,
                DENSE_RANK()OVER (PARTITION BY NombreFase ORDER BY Goles DESC) AS Puesto
        FROM GoleadoresPorFase
    )
    SELECT 
        r.NombreFase,
        info.Nombre as Jugador,
        r.Goles 
    FROM RankingGoleadores r 
    JOIN personas.Participante info ON r.id_jugador_autor = info.id_participante
    WHERE r.Puesto = 1
    FOR XML AUTO, ROOT('GoleadoresPorFase'), ELEMENTS;

END;
GO

/*

EXEC reportes.GoleadoresPorFase;


*/

-- 1.3 Goleadores Por Torneo

CREATE OR ALTER PROCEDURE reportes.GoleadorDelTorneo
AS 
BEGIN 
     --  
    WITH GoleadoresTorneo AS
    (
        SELECT p.Nombre, COUNT(*) Goles
        FROM torneo.Gol g
        JOIN personas.Participante p ON g.id_jugador_autor = p.id_participante
        GROUP BY p.nombre
    ),
    RankingGoleadores AS 
    (
        SELECT  Nombre, 
                Goles,
                DENSE_RANK()OVER (ORDER BY Goles DESC) AS Puesto
        FROM GoleadoresTorneo
    )
    SELECT Nombre, Goles, Puesto
    FROM RankingGoleadores
    WHERE Puesto = 1
    FOR XML AUTO, ROOT('GoleadorDelTorneo'), ELEMENTS; 

END;
GO

/*

EXEC reportes.GoleadorDelTorneo;


*/

-- ============================================================================
-- 2. Tarjetas (Amarillas y Rojas)
-- ============================================================================

-- 2.1 Tarjetas por Jugador

CREATE OR ALTER PROCEDURE reportes.TarjetasPorJugador
AS
BEGIN
    
    SELECT jugador.nombre, sancion.color, sancion.motivo, 
            ISNULL(sus.motivo, 'Sin Suspension') AS [Suspensiones],
            CASE 
                WHEN sus.partidos_a_cumplir > sus.partidos_cumplidos THEN 'Activa'
                WHEN sus.partidos_a_cumplir <= sus.partidos_a_cumplir THEN 'Cumplida'
                ELSE 'No Aplica'
            END AS [Suspensión]
    FROM torneo.Sancion sancion
    JOIN personas.Participante jugador ON sancion.id_jugador = jugador.id_participante
    LEFT JOIN torneo.Suspension sus ON jugador.id_participante = sus.id_jugador
    ORDER BY jugador.nombre
    FOR XML AUTO, ROOT('TarjetasPorJugador'), ELEMENTS; 

END;
GO

/*


EXEC reportes.TarjetasPorJugador;


*/

-- 2.2 Tarjetas Por Seleccion

CREATE OR ALTER PROCEDURE reportes.TarjetasPorSeleccion
AS 
BEGIN 
    
    SELECT pais.nombre as Seleccion, part.nombre as Jugador, 
            sancion.id_partido, sancion.color, sancion.motivo,
            CASE 
                WHEN sus.partidos_a_cumplir > sus.partidos_cumplidos THEN 'SI'
                ELSE 'NO'
            END AS [Suspensiones Activas],
            ISNULL(sus.motivo, 'Sin Suspensiones') AS [Motivo Suspension]
    FROM torneo.Sancion sancion
    JOIN personas.Jugador j ON sancion.id_jugador = j.id_participante
    JOIN personas.Participante part ON j.id_participante = part.id_participante
    JOIN torneo.Seleccion sel ON j.id_seleccion = sel.id_seleccion 
    JOIN geo.Pais pais ON sel.id_pais = pais.id_pais
    LEFT JOIN torneo.Suspension sus ON  sancion.id_jugador = sus.id_jugador
                                    AND sancion.id_partido = sus.id_partido_origen
    ORDER BY pais.nombre
    FOR XML AUTO, ROOT('TarjetasPorSeleccion'), ELEMENTS; 

END;
GO

/*


EXEC reportes.TarjetasPorSeleccion;


*/

-- ==========================================================================
-- 3. Designaciones Arbitrales
-- ==========================================================================

CREATE OR ALTER PROCEDURE reportes.PartidosDirigidosPorArbitro
AS
BEGIN 

    SELECT partido.id_partido, a.nombre as [Arbitro], p1.nombre as [Local], p2.nombre as [Visitante], partido.fase,
            sancion.color as [Sanciones], sancion.motivo, sancion.nro
    FROM torneo.Partido partido 
    JOIN personas.Participante a ON partido.id_arbitro_principal = a.id_participante
    JOIN torneo.Seleccion s1 ON partido.id_seleccion_1 = s1.id_seleccion 
    JOIN torneo.Seleccion s2 ON partido.id_seleccion_2 = s2.id_seleccion 
    JOIN geo.Pais p1 ON s1.id_pais = p1.id_pais 
    JOIN geo.Pais p2 ON s2.id_pais = p2.id_pais 
    JOIN torneo.Sancion sancion ON partido.id_partido = sancion.id_partido 
    FOR XML AUTO, ROOT('PartidosDirigidosPorArbitro'), ELEMENTS;


END;
GO

/*


EXEC reportes.PartidosDirigidosPorArbitro;


*/

-- ==========================================================================
-- 4. Ocupacion Publicitaria
-- ==========================================================================

CREATE OR ALTER PROCEDURE reportes.OcupacionPublicitariaPorSedeYPartido
AS
BEGIN
    
    SELECT sede.nombre_estadio AS NombreEstadio, p1.nombre AS [Local], p2.nombre AS [Visitante],
            p.fase, a.nombre, ep.cod_campania, ep.cod_contenido, t.costo Precio,
            SUM(t.costo) OVER (PARTITION BY sede.nombre_estadio) as [Ganancia Total]
    FROM publicidad.EspacioPublicitario ep 
    JOIN torneo.Partido p ON ep.id_partido = p.id_partido 
    JOIN torneo.Sede sede ON p.id_sede = sede.id_sede
    JOIN torneo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion 
    JOIN torneo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion 
    JOIN geo.Pais p1 ON s1.id_pais = p1.id_pais 
    JOIN geo.Pais p2 ON s2.id_pais = p2.id_pais 
    JOIN publicidad.Anunciante a ON ep.id_anunciante = a.id_anunciante
    JOIN publicidad.Tarifa t ON ep.id_tarifa = t.id_tarifa
    FOR XML AUTO, ROOT('PublicidadPorSedeYPartido'), ELEMENTS;

    -- Falta cambiar la tarifa

END;
GO


/*


EXEC reportes.OcupacionPublicitariaPorSedeYPartido;


*/

-- ==========================================================================
-- 5. Matriz de Prime Time
-- ==========================================================================

CREATE OR ALTER PROCEDURE reportes.MatrizDePrimeTimeMercadosClave
AS 
BEGIN 
    
    SET NOCOUNT ON;

    SELECT 
        p.id_partido AS [ID Partido],
        p.fase AS [Fase],
        CONVERT(VARCHAR(10), p.fecha_hora_utc, 120) AS [Fecha UTC],
        CONVERT(VARCHAR(5), p.fecha_hora_utc, 108) AS [Hora UTC],
        -- Evaluamos mercados clave
        MAX(CASE WHEN pa.nombre = 'Argentina' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Argentina],
        MAX(CASE WHEN pa.nombre = 'Brasil' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Brasil],
        MAX(CASE WHEN pa.nombre = 'Arabia Saudita' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Arabia Saudita], 
        MAX(CASE WHEN pa.nombre = 'Emiratos Arabes' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Emiratos Arabes],
        MAX(CASE WHEN pa.nombre = 'Catar' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Catar],
        MAX(CASE WHEN pa.nombre = 'China' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [China],
        MAX(CASE WHEN pa.nombre = 'Indonesia' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Indonesia],
        MAX(CASE WHEN pa.nombre = 'Estados Unidos' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [Estados Unidos],
        MAX(CASE WHEN pa.nombre = 'India' AND DATEPART(HOUR, DATEADD(MINUTE, CAST(pa.huso_horario * 60 AS INT), p.fecha_hora_utc)) BETWEEN 19 AND 23 THEN 'PRIME TIME' ELSE '-' END) AS [India]
    FROM torneo.Partido p
    CROSS JOIN geo.Pais pa -- No hay manera de unir partido con pais, debemos combinar cada partido con todos los países de la tabla
    WHERE pa.nombre IN ('Argentina', 'Brasil', 'Arabia Saudita', 'Emiratos Arabes', 'Catar', 'China', 'Indonesia', 'Estados Unidos', 'India')
      AND p.fecha_hora_utc IS NOT NULL
    GROUP BY p.id_partido, p.fase, p.fecha_hora_utc
    ORDER BY p.fecha_hora_utc;

END;
GO


/*


EXEC reportes.MatrizDePrimeTimeMercadosClave;


*/

-- ==========================================================================
-- 6. Selecciones y Plantillas
-- ==========================================================================


CREATE OR ALTER PROCEDURE reportes.ListadoSeleccionesConvocados
AS 
BEGIN 

    SELECT 
        pais.nombre AS [NombreSeleccion],
        (
         SELECT 
            persona.nombre, 
            jugador.posicion, 
            jugador.nro_dorsal, 
            club.nombre
        FROM personas.Jugador jugador
        JOIN personas.Participante persona ON jugador.id_participante = persona.id_participante
        JOIN personas.Club club ON jugador.id_club = club.id_club   
        WHERE jugador.id_seleccion = seleccion.id_seleccion
        FOR XML PATH('Jugador'), TYPE
    )AS [Convocados]
    FROM torneo.Seleccion seleccion
    JOIN geo.Pais pais ON seleccion.id_pais = pais.id_pais
    ORDER BY pais.nombre
    FOR XML PATH ('Seleccion'), ROOT('SeleccionesYPlantillas'); 

END;
GO


/*


EXEC reportes.ListadoSeleccionesConvocados;


*/


-- ==========================================================================
-- 7. Selecciones y Plantillas
-- ==========================================================================

CREATE OR ALTER PROCEDURE reportes.ResultadosPartidos
AS
BEGIN 
    
    SELECT 
        partido.fase AS [Fase],  
        sede.nombre_estadio AS [Estadio],
        CONVERT(VARCHAR(10), partido.fecha_hora_utc, 120) AS [Fecha UTC],
        CONVERT(VARCHAR(5), partido.fecha_hora_utc, 108) AS [Hora UTC],
        COALESCE(pais_1.nombre, 'Por definir') AS [Local],
        ISNULL(CAST(partido.goles_1 AS VARCHAR(2)), '-') + ' - ' + ISNULL(CAST(partido.goles_2 AS VARCHAR(2)), '-') AS [Resultado],
        COALESCE(pais_2.nombre, 'Por definir') AS [Visitante],
        ISNULL(CAST(partido.asistencia AS VARCHAR(15) ), 'Sin registro')AS [Asistencia Espectadores]
    FROM torneo.Partido partido
    JOIN torneo.Seleccion seleccion_1 ON partido.id_seleccion_1 = seleccion_1.id_seleccion
    JOIN torneo.Seleccion seleccion_2 ON partido.id_seleccion_2 = seleccion_2.id_seleccion
    JOIN geo.Pais pais_1 ON seleccion_1.id_pais = pais_1.id_pais
    JOIN geo.Pais pais_2 ON seleccion_2.id_pais = pais_2.id_pais
    JOIN torneo.Sede sede ON partido.id_sede = sede.id_sede
    --FOR XML AUTO, ROOT('Encuentros'), ELEMENTS;

END;
GO

/*


EXEC reportes.ResultadosPartidos;



*/
