/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : IMPORTACIÓN DIRECTA del archivo worldcup.json (base de datos de Joshua Fjelstul,
                  github.com/jfjelstul/worldcup, formato JSON). Un solo archivo trae las sedes, las
                  selecciones, las plantillas, los partidos con su resultado y las alineaciones.
                  Se importa un torneo por vez (parámetro @id_torneo, por defecto 'WC-2022').

                  Importacion.Mundial_Importar @ruta [, @id_torneo]
                    1. Mundial_CargarJson   BULK INSERT del archivo completo en importacion.JsonCarga
                                            (una fila) y control de que sea un JSON válido.
                    2. Extracción           OPENJSON lee cada arreglo del JSON ($.matches, $.stadiums,
                                            $.teams, $.squads, $.players, $.player_appearances) y deja
                                            sólo lo del torneo en tablas temporales (#partido, #sede,
                                            #seleccion, #jugador, #alineacion), todo como texto.
                    3. Procesadores         recorren cada tabla temporal con un WHILE, en
                                            el orden que exigen las claves foráneas, y para cada registro
                                            hacen el UPSERT llamando a los SP de la Entrega 5:

                    Procesador          Clave natural            Alta                    Modificación
                    Sede_Procesar       país + ciudad + estadio  torneo.Sede_Registrar   torneo.Sede_Modificar
                    Seleccion_Procesar  país                     torneo.Seleccion_Insertar  Seleccion_Modificar
                    Jugador_Procesar    DNI (= player_id)        personas.Jugador_Insertar  Jugador_Modificar
                    Partido_Procesar    sede + fecha + horario   Partido_Insertar +      torneo.Partido_Modificar
                                                                 Partido_RegistrarResultado
                    Alineacion_Procesar partido + selección      torneo.Alineacion_Registrar (no se modifica
                                                                 una alineación ya cargada)

                  Cada registro se resuelve solo: ERROR (con el motivo), NUEVO, ACTUALIZADO o SIN_CAMBIOS, y
                  queda en importacion.Registro. Si un registro falla se informa y se sigue con los demás
                  (importación parcial); los que dependen de él fallan con el motivo "no se pudo importar".
                  Importar dos veces el mismo archivo no duplica nada. Si el archivo no existe, no es un JSON
                  o no trae el torneo pedido, la importación completa falla con THROW (queda FALLIDA).

                  Decisiones de mapeo (el JSON no tiene todo lo que pide el modelo):
                    * Huso horario: el JSON no lo trae; se toma de importacion.EquivalenciaPais.huso_horario
                      (países anfitriones). Si el país de la sede no tiene huso, esa sede es un ERROR.
                    * Club: el JSON no trae clubes; todos los jugadores se cargan en el club 'Sin club
                      informado' (la tabla personas.Jugador exige uno).
                    * DNI: se usa el player_id del JSON (P-14758), que es único por jugador.
                    * Grupo: 'Group C' -> 'C'. Confederación: confederation_code de $.teams.
                    * Fase: group stage -> GRUPOS, round of 16 -> OCTAVOS, quarter-final(s) -> CUARTOS,
                      semi-final(s) -> SEMIFINAL, third-place match -> TERCER_PUESTO, final -> FINAL.
                      Las rondas que el modelo no tiene (segunda fase de grupos, ronda final) son ERROR.
                    * Resultado: goles del tiempo reglamentario y alargue (home/away_team_score). Los
                      penales de la definición no se guardan en torneo.Partido.
                    * Alineación: titulares y suplentes según player_appearances. El esquema táctico no está
                      en el JSON; se calcula contando defensores, mediocampistas y delanteros titulares
                      (ej: 4-3-3) a partir del código de posición (CB, LB, RB, LWB, RWB = defensor;
                      CF, LW, RW, LF, RF, SS = delantero; el resto de los no arqueros = mediocampista).
                    * Nombre: 'Nombre Apellido'; si el JSON dice 'not applicable' en el nombre, sólo el apellido.

                  SQL dinámico: BULK INSERT exige el nombre del archivo como literal (no admite variable).
                  Requisitos: scripts 00 a 14 ejecutados. Caracteres: los nombres viajan como VARCHAR (los
                  parámetros de la Entrega 5 lo son), por lo que los caracteres fuera de Latin-1 pasan a '?'.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ CARGADOR
-- Lee el archivo completo en una sola fila de importacion.JsonCarga. El archivo es UTF-8 (CODEPAGE 65001).
-- Se usan terminadores que nunca aparecen en un JSON (0x1F y 0x1E) para que BULK INSERT no corte el
-- texto en los saltos de línea ni en las comas.
CREATE OR ALTER PROCEDURE importacion.Mundial_CargarJson
    @ruta VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @sql NVARCHAR(MAX);

    DELETE FROM importacion.JsonCarga;

    SET @sql = 'BULK INSERT importacion.JsonCarga FROM ''' + @ruta + '''
                WITH (CODEPAGE = ''65001'', FIELDTERMINATOR = ''0x1F'', ROWTERMINATOR = ''0x1E'')';
    EXEC sp_executesql @sql;

    IF (SELECT COUNT(*) FROM importacion.JsonCarga) <> 1
       OR ISJSON((SELECT contenido FROM importacion.JsonCarga)) = 0
        THROW 50001, 'El archivo no es un JSON válido. ', 1;
END;
GO

-- ------------------------------------------------------------------ 1. SEDES
CREATE OR ALTER PROCEDURE importacion.Sede_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @estadio VARCHAR(100), @ciudad VARCHAR(80), @pais VARCHAR(80), @capacidad INT;
    DECLARE @huso DECIMAL(4,2), @id_pais INT, @id_ciudad INT, @id_sede INT, @capacidad_actual INT;
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    SELECT @id = MIN(id) FROM #sede;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @estadio = estadio, @ciudad = ciudad, @pais = importacion.fn_PaisLocal(pais),
               @capacidad = TRY_CAST(capacidad AS INT)
        FROM #sede WHERE id = @id;

        SET @clave = 'SEDE ' + @estadio + ' (' + @ciudad + ', ' + @pais + ')';
        SET @errores = '';
        SET @estado = NULL;
        SET @huso = NULL;
        SET @id_pais = NULL;
        SET @id_ciudad = NULL;
        SET @id_sede = NULL;

        SELECT @id_pais = id_pais FROM geo.Pais WHERE nombre = @pais;
        SELECT @id_ciudad = id_ciudad FROM geo.Ciudad WHERE id_pais = @id_pais AND nombre = @ciudad;
        SELECT @id_sede = id_sede, @capacidad_actual = capacidad
        FROM torneo.Sede WHERE id_ciudad = @id_ciudad AND nombre_estadio = @estadio;
        SELECT TOP 1 @huso = huso_horario FROM importacion.EquivalenciaPais
        WHERE nombre_pais = @pais AND huso_horario IS NOT NULL;

        IF @capacidad IS NULL
            SET @errores += 'La capacidad no es un número. ';
        IF @id_ciudad IS NULL AND @huso IS NULL
            SET @errores += 'No se conoce el huso horario de ' + @pais + ' (completar importacion.EquivalenciaPais). ';

        IF @errores = ''
        BEGIN
            BEGIN TRY
                IF @id_sede IS NULL
                BEGIN
                    EXEC torneo.Sede_Registrar @pais = @pais, @huso_pais = @huso, @ciudad = @ciudad,
                                               @huso_ciudad = @huso, @nombre_estadio = @estadio,
                                               @capacidad = @capacidad, @id_sede = @id_sede OUTPUT;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @capacidad_actual <> @capacidad
                BEGIN
                    EXEC torneo.Sede_Modificar @id_sede = @id_sede, @id_ciudad = @id_ciudad,
                                               @nombre_estadio = @estadio, @capacidad = @capacidad;
                    SET @estado = 'ACTUALIZADO';
                END
                ELSE
                    SET @estado = 'SIN_CAMBIOS';

                UPDATE #sede SET id_sede = @id_sede WHERE id = @id;
            END TRY
            BEGIN CATCH
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM #sede WHERE id > @id;
    END;
END;
GO

-- ------------------------------------------------------------------ 2. SELECCIONES
CREATE OR ALTER PROCEDURE importacion.Seleccion_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @pais VARCHAR(80), @confederacion VARCHAR(10), @grupo CHAR(1);
    DECLARE @id_pais INT, @id_seleccion INT, @confederacion_actual VARCHAR(10), @grupo_actual CHAR(1);
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    SELECT @id = MIN(id) FROM #seleccion;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @pais = importacion.fn_PaisLocal(pais), @confederacion = confederacion, @grupo = grupo
        FROM #seleccion WHERE id = @id;

        SET @clave = 'SELECCION ' + @pais;
        SET @errores = '';
        SET @estado = NULL;
        SET @id_pais = NULL;
        SET @id_seleccion = NULL;

        SELECT @id_pais = id_pais FROM geo.Pais WHERE nombre = @pais;
        SELECT @id_seleccion = id_seleccion, @confederacion_actual = confederacion, @grupo_actual = grupo
        FROM torneo.Seleccion WHERE id_pais = @id_pais;

        BEGIN TRY
            BEGIN TRANSACTION;

            IF @id_pais IS NULL
                EXEC geo.Pais_Insertar @nombre = @pais, @id_pais = @id_pais OUTPUT;

            IF @id_seleccion IS NULL
            BEGIN
                EXEC torneo.Seleccion_Insertar @id_pais = @id_pais, @confederacion = @confederacion,
                                               @grupo = @grupo, @id_seleccion = @id_seleccion OUTPUT;
                SET @estado = 'NUEVO';
            END
            ELSE IF @confederacion_actual <> @confederacion OR ISNULL(@grupo_actual, '') <> ISNULL(@grupo, '')
            BEGIN
                EXEC torneo.Seleccion_Modificar @id_seleccion = @id_seleccion, @id_pais = @id_pais,
                                                @confederacion = @confederacion, @grupo = @grupo;
                SET @estado = 'ACTUALIZADO';
            END
            ELSE
                SET @estado = 'SIN_CAMBIOS';

            COMMIT TRANSACTION;
            UPDATE #seleccion SET id_seleccion = @id_seleccion WHERE id = @id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @errores = ERROR_MESSAGE();
        END CATCH;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM #seleccion WHERE id > @id;
    END;
END;
GO

-- ------------------------------------------------------------------ 3. JUGADORES
CREATE OR ALTER PROCEDURE importacion.Jugador_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @dni VARCHAR(20), @nombre VARCHAR(100), @nacimiento DATE, @id_seleccion INT;
    DECLARE @dorsal TINYINT, @posicion VARCHAR(15), @id_club INT, @id_jugador INT;
    DECLARE @nombre_actual VARCHAR(100), @nacimiento_actual DATE, @seleccion_actual INT;
    DECLARE @dorsal_actual TINYINT, @posicion_actual VARCHAR(15), @club_actual INT;
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    -- el JSON no trae clubes y la tabla de jugadores exige uno
    SELECT @id_club = id_club FROM personas.Club WHERE nombre = 'Sin club informado';
    IF @id_club IS NULL
        EXEC personas.Club_Insertar @nombre = 'Sin club informado', @id_club = @id_club OUTPUT;

    SELECT @id = MIN(id) FROM #jugador;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @dni = player_id,
               @nombre = LTRIM(RTRIM(CASE WHEN given_name IN ('', 'not applicable') THEN '' ELSE given_name + ' ' END + family_name)),
               @nacimiento = TRY_CAST(birth_date AS DATE),
               @dorsal = TRY_CAST(shirt AS TINYINT),
               @posicion = CASE position_name WHEN 'goal keeper' THEN 'ARQUERO' WHEN 'defender' THEN 'DEFENSOR'
                                              WHEN 'midfielder' THEN 'MEDIOCAMPISTA' WHEN 'forward' THEN 'DELANTERO' END,
               @id_seleccion = (SELECT s.id_seleccion FROM #seleccion s WHERE s.team_id = j.team_id)
        FROM #jugador j WHERE id = @id;

        SET @clave = 'JUGADOR ' + @dni + ' ' + @nombre;
        SET @errores = '';
        SET @estado = NULL;
        SET @id_jugador = NULL;

        SELECT @id_jugador = p.id_participante, @nombre_actual = p.nombre, @nacimiento_actual = p.fecha_nacimiento,
               @seleccion_actual = j.id_seleccion, @dorsal_actual = j.nro_dorsal, @posicion_actual = j.posicion,
               @club_actual = j.id_club
        FROM personas.Participante p
        JOIN personas.Jugador j ON j.id_participante = p.id_participante
        WHERE p.dni = @dni;

        IF @id_seleccion IS NULL
            SET @errores += 'La selección del jugador no se pudo importar. ';
        IF @dorsal IS NULL
            SET @errores += 'El dorsal no es un número. ';
        IF @posicion IS NULL
            SET @errores += 'La posición no es reconocida. ';

        IF @errores = ''
        BEGIN
            BEGIN TRY
                IF @id_jugador IS NULL
                BEGIN
                    EXEC personas.Jugador_Insertar @dni = @dni, @nombre = @nombre, @fecha_nacimiento = @nacimiento,
                                                   @id_seleccion = @id_seleccion, @id_club = @id_club,
                                                   @nro_dorsal = @dorsal, @posicion = @posicion,
                                                   @id_participante = @id_jugador OUTPUT;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @nombre_actual <> @nombre OR ISNULL(@nacimiento_actual, '1900-01-01') <> ISNULL(@nacimiento, '1900-01-01')
                     OR @seleccion_actual <> @id_seleccion OR @dorsal_actual <> @dorsal OR @posicion_actual <> @posicion
                BEGIN
                    EXEC personas.Jugador_Modificar @id_participante = @id_jugador, @dni = @dni, @nombre = @nombre,
                                                    @fecha_nacimiento = @nacimiento, @id_seleccion = @id_seleccion,
                                                    @id_club = @club_actual, @nro_dorsal = @dorsal, @posicion = @posicion;
                    SET @estado = 'ACTUALIZADO';
                END
                ELSE
                    SET @estado = 'SIN_CAMBIOS';

                UPDATE #jugador SET id_jugador = @id_jugador WHERE id = @id;
            END TRY
            BEGIN CATCH
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM #jugador WHERE id > @id;
    END;
END;
GO

-- ------------------------------------------------------------------ 4. PARTIDOS
CREATE OR ALTER PROCEDURE importacion.Partido_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @match VARCHAR(20), @fase VARCHAR(15), @fecha DATE, @horario TIME(0), @id_sede INT;
    DECLARE @sel_1 INT, @sel_2 INT, @goles_1 TINYINT, @goles_2 TINYINT, @id_partido INT;
    DECLARE @fase_actual VARCHAR(15), @sel_1_actual INT, @sel_2_actual INT, @goles_1_actual TINYINT, @goles_2_actual TINYINT;
    DECLARE @asistencia INT, @arbitro_principal INT, @arbitro_var INT;
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    SELECT @id = MIN(id) FROM #partido;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @match = match_id,
               @fase = CASE stage_name WHEN 'group stage' THEN 'GRUPOS' WHEN 'round of 16' THEN 'OCTAVOS'
                                       WHEN 'quarter-final' THEN 'CUARTOS' WHEN 'quarter-finals' THEN 'CUARTOS'
                                       WHEN 'semi-final' THEN 'SEMIFINAL' WHEN 'semi-finals' THEN 'SEMIFINAL'
                                       WHEN 'third-place match' THEN 'TERCER_PUESTO' WHEN 'final' THEN 'FINAL' END,
               @fecha = TRY_CAST(match_date AS DATE),
               @horario = TRY_CAST(match_time AS TIME(0)),
               @id_sede = (SELECT s.id_sede FROM #sede s WHERE s.stadium_id = p.stadium_id),
               @sel_1 = (SELECT s.id_seleccion FROM #seleccion s WHERE s.team_id = p.home_team_id),
               @sel_2 = (SELECT s.id_seleccion FROM #seleccion s WHERE s.team_id = p.away_team_id),
               @goles_1 = TRY_CAST(home_score AS TINYINT),
               @goles_2 = TRY_CAST(away_score AS TINYINT)
        FROM #partido p WHERE id = @id;

        SET @clave = 'PARTIDO ' + @match;
        SET @errores = '';
        SET @estado = NULL;
        SET @id_partido = NULL;

        IF @fase IS NULL
            SET @errores += 'La fase del torneo no existe en el modelo. ';
        IF @fecha IS NULL OR @horario IS NULL
            SET @errores += 'La fecha o la hora no son válidas. ';
        IF @id_sede IS NULL
            SET @errores += 'La sede del partido no se pudo importar. ';
        IF @sel_1 IS NULL OR @sel_2 IS NULL
            SET @errores += 'Una de las selecciones no se pudo importar. ';

        IF @errores = ''
        BEGIN
            SELECT @id_partido = id_partido, @fase_actual = fase, @sel_1_actual = id_seleccion_1,
                   @sel_2_actual = id_seleccion_2, @goles_1_actual = goles_1, @goles_2_actual = goles_2,
                   @asistencia = asistencia, @arbitro_principal = id_arbitro_principal, @arbitro_var = id_arbitro_var
            FROM torneo.Partido WHERE id_sede = @id_sede AND fecha = @fecha AND horario = @horario;

            BEGIN TRY
                BEGIN TRANSACTION;

                IF @id_partido IS NULL
                BEGIN
                    EXEC torneo.Partido_Insertar @id_sede = @id_sede, @fase = @fase, @fecha = @fecha, @horario = @horario,
                                                 @id_seleccion_1 = @sel_1, @id_seleccion_2 = @sel_2,
                                                 @id_partido = @id_partido OUTPUT;
                    IF @goles_1 IS NOT NULL AND @goles_2 IS NOT NULL
                        EXEC torneo.Partido_RegistrarResultado @id_partido = @id_partido, @goles_1 = @goles_1, @goles_2 = @goles_2;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @fase_actual <> @fase OR @sel_1_actual <> @sel_1 OR @sel_2_actual <> @sel_2
                     OR ISNULL(@goles_1_actual, 255) <> ISNULL(@goles_1, 255) OR ISNULL(@goles_2_actual, 255) <> ISNULL(@goles_2, 255)
                BEGIN
                    EXEC torneo.Partido_Modificar @id_partido = @id_partido, @id_sede = @id_sede, @fase = @fase,
                                                  @fecha = @fecha, @horario = @horario,
                                                  @id_seleccion_1 = @sel_1, @id_seleccion_2 = @sel_2,
                                                  @goles_1 = @goles_1, @goles_2 = @goles_2, @asistencia = @asistencia,
                                                  @id_arbitro_principal = @arbitro_principal, @id_arbitro_var = @arbitro_var;
                    SET @estado = 'ACTUALIZADO';
                END
                ELSE
                    SET @estado = 'SIN_CAMBIOS';

                COMMIT TRANSACTION;
                UPDATE #partido SET id_partido = @id_partido WHERE id = @id;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM #partido WHERE id > @id;
    END;
END;
GO

-- ------------------------------------------------------------------ 5. ALINEACIONES
-- Una alineación por partido y selección. Alineacion_Registrar lee #Titulares y #Suplentes, que se
-- vacían y se vuelven a llenar para cada alineación.
CREATE OR ALTER PROCEDURE importacion.Alineacion_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @match VARCHAR(20), @team VARCHAR(10), @id_partido INT, @id_seleccion INT, @id_formacion INT;
    DECLARE @defensores INT, @delanteros INT, @titulares INT, @esquema VARCHAR(10);
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    CREATE TABLE #Titulares (id INT IDENTITY(1,1), id_jugador INT, posicion_cancha VARCHAR(20), dorsal_cancha TINYINT);
    CREATE TABLE #Suplentes (id INT IDENTITY(1,1), id_jugador INT);
    CREATE TABLE #equipo (id INT IDENTITY(1,1), match_id VARCHAR(20), team_id VARCHAR(10));

    INSERT INTO #equipo (match_id, team_id)
    SELECT DISTINCT match_id, team_id FROM #alineacion ORDER BY match_id, team_id;

    SELECT @id = MIN(id) FROM #equipo;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @match = match_id, @team = team_id FROM #equipo WHERE id = @id;

        SET @id_partido = (SELECT id_partido FROM #partido WHERE match_id = @match);
        SET @id_seleccion = (SELECT id_seleccion FROM #seleccion WHERE team_id = @team);

        SET @clave = 'ALINEACION ' + @match + ' ' + @team;
        SET @errores = '';
        SET @estado = NULL;

        IF @id_partido IS NULL
            SET @errores += 'El partido no se pudo importar. ';
        IF @id_seleccion IS NULL
            SET @errores += 'La selección no se pudo importar. ';

        IF @errores = ''
        BEGIN
            IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
                SET @estado = 'SIN_CAMBIOS';
            ELSE
            BEGIN
                TRUNCATE TABLE #Titulares;
                TRUNCATE TABLE #Suplentes;

                INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha)
                SELECT j.id_jugador, a.position_name, TRY_CAST(a.shirt_number AS TINYINT)
                FROM #alineacion a JOIN #jugador j ON j.player_id = a.player_id
                WHERE a.match_id = @match AND a.team_id = @team AND a.starter = '1' AND j.id_jugador IS NOT NULL
                ORDER BY a.id;

                INSERT INTO #Suplentes (id_jugador)
                SELECT j.id_jugador
                FROM #alineacion a JOIN #jugador j ON j.player_id = a.player_id
                WHERE a.match_id = @match AND a.team_id = @team AND a.starter = '0' AND j.id_jugador IS NOT NULL
                ORDER BY a.id;

                -- esquema táctico: defensores-mediocampistas-delanteros entre los titulares que no son arqueros
                SELECT @titulares = COUNT(*),
                       @defensores = SUM(CASE WHEN position_code IN ('CB', 'LB', 'RB', 'LWB', 'RWB') THEN 1 ELSE 0 END),
                       @delanteros = SUM(CASE WHEN position_code IN ('CF', 'LW', 'RW', 'LF', 'RF', 'SS') THEN 1 ELSE 0 END)
                FROM #alineacion
                WHERE match_id = @match AND team_id = @team AND starter = '1' AND position_code <> 'GK';
                SET @esquema = CAST(@defensores AS VARCHAR(2)) + '-' + CAST(@titulares - @defensores - @delanteros AS VARCHAR(2))
                             + '-' + CAST(@delanteros AS VARCHAR(2));

                BEGIN TRY
                    EXEC torneo.Alineacion_Registrar @id_partido = @id_partido, @id_seleccion = @id_seleccion,
                                                     @esquema_tactico = @esquema, @id_formacion = @id_formacion OUTPUT;
                    SET @estado = 'NUEVO';
                END TRY
                BEGIN CATCH
                    SET @errores = ERROR_MESSAGE();
                END CATCH;
            END;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM #equipo WHERE id > @id;
    END;
END;
GO

-- ------------------------------------------------------------------ PUNTO DE ENTRADA
-- Importa un torneo de worldcup.json. @ruta es el nombre del archivo (ruta que lee el servidor).
CREATE OR ALTER PROCEDURE importacion.Mundial_Importar
    @ruta VARCHAR(260),
    @id_torneo VARCHAR(10) = 'WC-2022'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_importacion INT, @json NVARCHAR(MAX);

    IF @ruta IS NULL OR LTRIM(RTRIM(@ruta)) = ''
        THROW 50001, 'Falta la ruta del archivo a importar. ', 1;

    EXEC importacion.Importacion_Iniciar @archivo = @ruta, @formato = 'JSON', @id_importacion = @id_importacion OUTPUT;

    BEGIN TRY
        EXEC importacion.Mundial_CargarJson @ruta = @ruta;
        SELECT @json = contenido FROM importacion.JsonCarga;

        -- Todo llega como texto; cada procesador convierte y valida registro por registro. Los COLLATE
        -- DATABASE_DEFAULT evitan conflictos si la intercalación de tempdb difiere de la de la base.
        -- id_sede / id_seleccion / id_jugador / id_partido los completa cada procesador y los usan los siguientes.
        CREATE TABLE #partido (id INT IDENTITY(1,1), match_id VARCHAR(20), stage_name VARCHAR(30), group_name VARCHAR(30),
                               match_date VARCHAR(20), match_time VARCHAR(20), stadium_id VARCHAR(10),
                               home_team_id VARCHAR(10), away_team_id VARCHAR(10), home_score VARCHAR(10),
                               away_score VARCHAR(10), id_partido INT NULL);
        CREATE TABLE #sede (id INT IDENTITY(1,1), stadium_id VARCHAR(10), estadio VARCHAR(100), ciudad VARCHAR(80),
                            pais VARCHAR(80), capacidad VARCHAR(20), id_sede INT NULL);
        CREATE TABLE #seleccion (id INT IDENTITY(1,1), team_id VARCHAR(10), pais VARCHAR(80), confederacion VARCHAR(10),
                                 grupo CHAR(1) NULL, id_seleccion INT NULL);
        CREATE TABLE #jugador (id INT IDENTITY(1,1), player_id VARCHAR(20), family_name VARCHAR(100), given_name VARCHAR(100),
                               team_id VARCHAR(10), shirt VARCHAR(10), position_name VARCHAR(30), birth_date VARCHAR(20),
                               id_jugador INT NULL);
        CREATE TABLE #alineacion (id INT IDENTITY(1,1), match_id VARCHAR(20), team_id VARCHAR(10), player_id VARCHAR(20),
                                  shirt_number VARCHAR(10), position_name VARCHAR(30), position_code VARCHAR(10), starter VARCHAR(5));

        INSERT INTO #partido (match_id, stage_name, group_name, match_date, match_time, stadium_id, home_team_id,
                              away_team_id, home_score, away_score)
        SELECT match_id, stage_name, group_name, match_date, match_time, stadium_id, home_team_id, away_team_id,
               home_score, away_score
        FROM OPENJSON(@json, '$.matches')
             WITH (tournament_id VARCHAR(10), match_id VARCHAR(20), stage_name VARCHAR(30), group_name VARCHAR(30),
                   match_date VARCHAR(20), match_time VARCHAR(20), stadium_id VARCHAR(10), home_team_id VARCHAR(10),
                   away_team_id VARCHAR(10), home_score VARCHAR(10) '$.home_team_score', away_score VARCHAR(10) '$.away_team_score')
        WHERE tournament_id = @id_torneo
        ORDER BY match_date, match_time, match_id;

        IF NOT EXISTS (SELECT 1 FROM #partido)
            THROW 50001, 'El torneo pedido no figura en el archivo. ', 1;

        INSERT INTO #sede (stadium_id, estadio, ciudad, pais, capacidad)
        SELECT stadium_id, stadium_name, city_name, country_name, stadium_capacity
        FROM OPENJSON(@json, '$.stadiums')
             WITH (stadium_id VARCHAR(10), stadium_name VARCHAR(100), city_name VARCHAR(80), country_name VARCHAR(80),
                   stadium_capacity VARCHAR(20))
        WHERE stadium_id IN (SELECT stadium_id COLLATE DATABASE_DEFAULT FROM #partido);

        INSERT INTO #seleccion (team_id, pais, confederacion)
        SELECT team_id, team_name, confederation_code
        FROM OPENJSON(@json, '$.teams')
             WITH (team_id VARCHAR(10), team_name VARCHAR(80), confederation_code VARCHAR(10))
        WHERE team_id IN (SELECT home_team_id COLLATE DATABASE_DEFAULT FROM #partido
                          UNION SELECT away_team_id COLLATE DATABASE_DEFAULT FROM #partido);

        -- grupo: 'Group C' -> 'C' (los torneos viejos usan 'Group 1', que el modelo no admite: queda sin grupo)
        UPDATE s SET grupo = RIGHT(p.group_name, 1)
        FROM #seleccion s JOIN #partido p ON p.group_name LIKE 'Group [A-L]' AND s.team_id IN (p.home_team_id, p.away_team_id);

        INSERT INTO #jugador (player_id, family_name, given_name, team_id, shirt, position_name)
        SELECT player_id, family_name, given_name, team_id, shirt_number, position_name
        FROM OPENJSON(@json, '$.squads')
             WITH (tournament_id VARCHAR(10), player_id VARCHAR(20), family_name VARCHAR(100), given_name VARCHAR(100),
                   team_id VARCHAR(10), shirt_number VARCHAR(10), position_name VARCHAR(30))
        WHERE tournament_id = @id_torneo
        ORDER BY team_id, shirt_number;

        UPDATE j SET birth_date = p.birth_date
        FROM #jugador j
        JOIN OPENJSON(@json, '$.players') WITH (player_id VARCHAR(20), birth_date VARCHAR(20)) p ON p.player_id = j.player_id COLLATE DATABASE_DEFAULT;

        INSERT INTO #alineacion (match_id, team_id, player_id, shirt_number, position_name, position_code, starter)
        SELECT match_id, team_id, player_id, shirt_number, position_name, position_code, starter
        FROM OPENJSON(@json, '$.player_appearances')
             WITH (tournament_id VARCHAR(10), match_id VARCHAR(20), team_id VARCHAR(10), player_id VARCHAR(20),
                   shirt_number VARCHAR(10), position_name VARCHAR(30), position_code VARCHAR(10), starter VARCHAR(5))
        WHERE tournament_id = @id_torneo
        ORDER BY match_id, team_id, starter DESC, shirt_number;

        EXEC importacion.Sede_Procesar @id_importacion = @id_importacion;
        EXEC importacion.Seleccion_Procesar @id_importacion = @id_importacion;
        EXEC importacion.Jugador_Procesar @id_importacion = @id_importacion;
        EXEC importacion.Partido_Procesar @id_importacion = @id_importacion;
        EXEC importacion.Alineacion_Procesar @id_importacion = @id_importacion;

        EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    END TRY
    BEGIN CATCH
        EXEC importacion.Importacion_Fallar @id_importacion = @id_importacion;
        THROW;
    END CATCH;

    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
END;
GO
