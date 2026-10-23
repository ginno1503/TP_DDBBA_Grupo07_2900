/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  : Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Funciones auxiliares que reutilizan los stored procedures (parámetros, hora UTC,
                  convocados activos, jugadores de un partido, suspensiones y país en competencia).
   ============================================================================= */

USE MundialFutbol;
GO

-- Devuelve el valor de un parámetro; si no está cargado devuelve el valor por defecto.
CREATE OR ALTER FUNCTION torneo.fn_Parametro (@clave VARCHAR(40), @por_defecto INT)
RETURNS INT
AS
BEGIN
    RETURN ISNULL((SELECT valor FROM torneo.Parametro WHERE clave = @clave), @por_defecto);
END;
GO

-- Pasa fecha y horario locales de la sede a UTC usando el huso de la ciudad.
CREATE OR ALTER FUNCTION torneo.fn_UtcPartido (@fecha DATE, @horario TIME(0), @id_sede INT)
RETURNS DATETIME2(0)
AS
BEGIN
    DECLARE @huso DECIMAL(4,2);

    SELECT @huso = c.huso_horario
    FROM torneo.Sede s
    JOIN geo.Ciudad c ON c.id_ciudad = s.id_ciudad
    WHERE s.id_sede = @id_sede;

    RETURN DATEADD(MINUTE, -CAST(@huso * 60 AS INT),
           DATEADD(SECOND, DATEDIFF(SECOND, CAST('00:00:00' AS TIME(0)), @horario),
                   CAST(@fecha AS DATETIME2(0))));
END;
GO

-- Jugadores convocados que siguen en la lista (los que fueron reemplazados no cuentan).
CREATE OR ALTER FUNCTION personas.fn_ConvocadosActivos (@id_seleccion INT)
RETURNS TABLE
AS
RETURN
(
    SELECT j.id_participante, j.nro_dorsal, j.posicion
    FROM personas.Jugador j
    WHERE j.id_seleccion = @id_seleccion
      AND NOT EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria r
                      WHERE r.id_jugador_sale = j.id_participante)
);
GO

-- Titulares y suplentes de las formaciones que juegan un partido.
CREATE OR ALTER FUNCTION torneo.fn_JugadoresEnPartido (@id_partido INT)
RETURNS TABLE
AS
RETURN
(
    SELECT pf.id_seleccion, ft.id_jugador, 'TITULAR' AS condicion
    FROM torneo.PartidoFormacion pf
    JOIN torneo.FormacionTitular ft ON ft.id_formacion = pf.id_formacion
    WHERE pf.id_partido = @id_partido
    UNION ALL
    SELECT pf.id_seleccion, fs.id_jugador, 'SUPLENTE'
    FROM torneo.PartidoFormacion pf
    JOIN torneo.FormacionSuplente fs ON fs.id_formacion = pf.id_formacion
    WHERE pf.id_partido = @id_partido
);
GO

-- 1 si el jugador tiene una suspensión que le impide jugar ese partido.
-- Está suspendido si el partido es posterior al de origen y los partidos de su selección
-- que hay en el medio todavía no alcanzan para cumplir la sanción.
CREATE OR ALTER FUNCTION torneo.fn_JugadorSuspendido (@id_jugador INT, @id_partido INT)
RETURNS BIT
AS
BEGIN
    DECLARE @utc DATETIME2(0), @sel INT, @resultado BIT = 0;

    SELECT @utc = fecha_hora_utc FROM torneo.Partido WHERE id_partido = @id_partido;
    SELECT @sel = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador;

    IF EXISTS (
        SELECT 1
        FROM torneo.Suspension s
        JOIN torneo.Partido po ON po.id_partido = s.id_partido_origen
        WHERE s.id_jugador = @id_jugador
          AND po.fecha_hora_utc < @utc
          AND (SELECT COUNT(*) FROM torneo.Partido x
               WHERE (x.id_seleccion_1 = @sel OR x.id_seleccion_2 = @sel)
                 AND x.fecha_hora_utc > po.fecha_hora_utc
                 AND x.fecha_hora_utc < @utc) < s.partidos_a_cumplir
    )
        SET @resultado = 1;

    RETURN @resultado;
END;
GO

-- 1 si el país tiene una selección que todavía no perdió ningún partido de eliminación directa.
-- (Los empates definidos por penales no se contemplan: en la tabla solo hay goles de juego.)
CREATE OR ALTER FUNCTION torneo.fn_PaisSigueEnCompetencia (@id_pais INT)
RETURNS BIT
AS
BEGIN
    DECLARE @sigue BIT = 0;

    IF EXISTS (
        SELECT 1
        FROM torneo.Seleccion s
        WHERE s.id_pais = @id_pais
          AND NOT EXISTS (SELECT 1 FROM torneo.Partido p
                          WHERE p.fase <> 'GRUPOS' AND p.goles_1 IS NOT NULL
                            AND ((p.id_seleccion_1 = s.id_seleccion AND p.goles_1 < p.goles_2)
                              OR (p.id_seleccion_2 = s.id_seleccion AND p.goles_2 < p.goles_1)))
    )
        SET @sigue = 1;

    RETURN @sigue;
END;
GO
