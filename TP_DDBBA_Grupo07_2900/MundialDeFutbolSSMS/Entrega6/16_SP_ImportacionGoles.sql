/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : IMPORTACIÓN DIRECTA del archivo goals.csv (base de datos de Joshua Fjelstul,
                  github.com/jfjelstul/worldcup, formato CSV, una fila por gol de todos los Mundiales).
                  Se importa un torneo por vez (parámetro @id_torneo, por defecto 'WC-2022').

                  importacion.Goles_Importar @ruta [, @id_torneo]
                    1. Gol_CargarCsv   BULK INSERT (FORMAT = 'CSV', desde la fila 2, comillas dobles) en
                                       importacion.GolCarga, que tiene las mismas 27 columnas del archivo.
                    2. Gol_Procesar    recorre con un WHILE (sin cursores) los goles del torneo, en el orden
                                       del archivo, y hace el UPSERT con los SP de la Entrega 5.

                  Cómo se encuentra cada cosa en la base (el CSV usa identificadores propios que el modelo no tiene):
                    * Jugador : player_id es el DNI cargado por importacion.Mundial_Importar (script 15).
                    * Partido : fecha del partido + selección del autor. Una selección juega una sola vez por
                                fecha, así que alcanza para identificar el partido (también en los goles en contra,
                                donde el autor es de la selección que lo sufre).
                    * Gol     : clave natural partido + autor + minuto. Si existe y cambió el tipo o el período
                                se corrige con torneo.Gol_Modificar (ACTUALIZADO); si no existe se agrega con
                                torneo.Gol_Registrar, que numera (NUEVO); si es igual, SIN_CAMBIOS.

                  Conversiones:
                    * minuto  = minute_regulation + minute_stoppage (45' + 2' -> 47)
                    * tipo    = own_goal 1 -> EN_CONTRA; penalty 1 -> PENAL; si no, JUGADA
                    * período = 'first half' -> PRIMER_TIEMPO, 'second half' -> SEGUNDO_TIEMPO,
                                '... stoppage time' -> ADICIONALES, 'extra time ...' -> ALARGUE

                  Un gol falla (y se informa con su motivo) si el jugador o el partido no están en la base o si
                  Gol_Insertar lo rechaza (por ejemplo, el autor no figura en las alineaciones del partido):
                  por eso primero se ejecuta Mundial_Importar. Los demás goles se importan igual.
                  Si el archivo no existe o no trae goles del torneo pedido, falla todo con THROW.

                  SQL dinámico: BULK INSERT exige el nombre del archivo como literal (no admite variable).
                  Requisitos: scripts 00 a 15 ejecutados y el torneo ya importado con Mundial_Importar.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ CARGADOR
CREATE OR ALTER PROCEDURE importacion.Gol_CargarCsv
    @ruta VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX);

    DELETE FROM importacion.GolCarga;

    SET @sql = 'BULK INSERT importacion.GolCarga FROM ''' + @ruta + '''
                WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', CODEPAGE = ''65001'', ROWTERMINATOR = ''0x0a'')';
    EXEC sp_executesql @sql;

    -- si el archivo viene con saltos de línea de Windows (CR + LF) la última columna trae el CR
    UPDATE importacion.GolCarga SET penalty = REPLACE(penalty, CHAR(13), '');
END;
GO

-- ------------------------------------------------------------------ PROCESADOR
CREATE OR ALTER PROCEDURE importacion.Gol_Procesar
    @id_importacion INT,
    @id_torneo VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @goal VARCHAR(20), @match VARCHAR(20), @dni VARCHAR(20), @fecha DATE, @minuto INT;
    DECLARE @tipo VARCHAR(10), @periodo VARCHAR(20), @id_autor INT, @id_seleccion INT, @id_partido INT;
    DECLARE @nro TINYINT, @tipo_actual VARCHAR(10), @periodo_actual VARCHAR(20), @asistente INT, @minuto_tinyint TINYINT;
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    CREATE TABLE #gol (id INT IDENTITY(1,1), goal_id VARCHAR(20), match_id VARCHAR(20), match_date VARCHAR(20),
                       player_id VARCHAR(20), minute_regulation VARCHAR(10), minute_stoppage VARCHAR(10),
                       match_period VARCHAR(60), own_goal VARCHAR(5), penalty VARCHAR(5));

    INSERT INTO #gol (goal_id, match_id, match_date, player_id, minute_regulation, minute_stoppage, match_period,
                      own_goal, penalty)
    SELECT goal_id, match_id, match_date, player_id, minute_regulation, minute_stoppage, match_period, own_goal, penalty
    FROM importacion.GolCarga
    WHERE tournament_id = @id_torneo
    ORDER BY TRY_CAST(key_id AS INT);

    IF NOT EXISTS (SELECT 1 FROM #gol)
        THROW 50001, 'El archivo no trae goles del torneo pedido (o no tiene el formato de goals.csv). ', 1;

    SELECT @id = MIN(id) FROM #gol;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @goal = goal_id, @match = match_id, @dni = player_id,
               @fecha = TRY_CAST(match_date AS DATE),
               @minuto = TRY_CAST(minute_regulation AS INT) + TRY_CAST(minute_stoppage AS INT),
               @tipo = CASE WHEN own_goal = '1' THEN 'EN_CONTRA' WHEN penalty = '1' THEN 'PENAL' ELSE 'JUGADA' END,
               @periodo = CASE WHEN match_period LIKE 'extra time%' THEN 'ALARGUE'
                               WHEN match_period LIKE '%stoppage time' THEN 'ADICIONALES'
                               WHEN match_period = 'first half' THEN 'PRIMER_TIEMPO'
                               WHEN match_period = 'second half' THEN 'SEGUNDO_TIEMPO'
                               WHEN match_period = 'penalty shootout' THEN 'DEFINICION_PENALES' END
        FROM #gol WHERE id = @id;

        SET @clave = 'GOL ' + @goal + ' (' + @match + ')';
        SET @errores = '';
        SET @estado = NULL;
        SET @id_autor = NULL;
        SET @id_seleccion = NULL;
        SET @id_partido = NULL;
        SET @nro = NULL;

        SELECT @id_autor = p.id_participante, @id_seleccion = j.id_seleccion
        FROM personas.Participante p
        JOIN personas.Jugador j ON j.id_participante = p.id_participante
        WHERE p.dni = @dni;

        SELECT @id_partido = id_partido FROM torneo.Partido
        WHERE fecha = @fecha AND @id_seleccion IN (id_seleccion_1, id_seleccion_2);

        IF @id_autor IS NULL
            SET @errores += 'El jugador ' + @dni + ' no está en la base. ';
        IF @id_autor IS NOT NULL AND @id_partido IS NULL
            SET @errores += 'No hay un partido de la selección del jugador en esa fecha. ';
        IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
            SET @errores += 'El minuto no es válido. ';
        IF @periodo IS NULL
            SET @errores += 'El período del gol no es reconocido. ';

        IF @errores = ''
        BEGIN
            SET @minuto_tinyint = @minuto;

            SELECT @nro = nro, @tipo_actual = tipo, @periodo_actual = periodo, @asistente = id_jugador_asistente
            FROM torneo.Gol WHERE id_partido = @id_partido AND id_jugador_autor = @id_autor AND minuto = @minuto_tinyint;

            BEGIN TRY
                IF @nro IS NULL
                BEGIN
                    EXEC torneo.Gol_Registrar @id_partido = @id_partido, @id_jugador_autor = @id_autor,
                                              @minuto = @minuto_tinyint, @tipo = @tipo, @periodo = @periodo;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @tipo_actual <> @tipo OR @periodo_actual <> @periodo
                BEGIN
                    EXEC torneo.Gol_Modificar @id_partido = @id_partido, @nro = @nro, @id_jugador_asistente = @asistente,
                                              @minuto = @minuto_tinyint, @tipo = @tipo, @periodo = @periodo;
                    SET @estado = 'ACTUALIZADO';
                END
                ELSE
                    SET @estado = 'SIN_CAMBIOS';
            END TRY
            BEGIN CATCH
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM #gol WHERE id > @id;
    END;
END;
GO

-- ------------------------------------------------------------------ PUNTO DE ENTRADA
-- Importa los goles de un torneo de goals.csv. @ruta es el nombre del archivo (ruta que lee el servidor).
CREATE OR ALTER PROCEDURE importacion.Goles_Importar
    @ruta VARCHAR(260),
    @id_torneo VARCHAR(10) = 'WC-2022'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_importacion INT;

    IF @ruta IS NULL OR LTRIM(RTRIM(@ruta)) = ''
        THROW 50001, 'Falta la ruta del archivo a importar. ', 1;

    EXEC importacion.Importacion_Iniciar @archivo = @ruta, @formato = 'CSV', @id_importacion = @id_importacion OUTPUT;

    BEGIN TRY
        EXEC importacion.Gol_CargarCsv @ruta = @ruta;
        EXEC importacion.Gol_Procesar @id_importacion = @id_importacion, @id_torneo = @id_torneo;
        EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    END TRY
    BEGIN CATCH
        EXEC importacion.Importacion_Fallar @id_importacion = @id_importacion;
        THROW;
    END CATCH;

    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
END;
GO
