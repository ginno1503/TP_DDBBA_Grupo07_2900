/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 06/11/2026
   Objetivo     : Procedimientos de lógica de negocio. A diferencia de los ABM (un SP por operación y
                  por tabla), cada SP de este script resuelve una operación completa del torneo y
                  escribe en varias tablas dentro de una misma transacción: si algo falla, no queda
                  nada a medias. Se apoyan en los SP ABM de los scripts 03 a 08, que ya hacen las
                  validaciones de cada tabla; acá solo se controla lo que ningún ABM controla.

                    Sedes y partidos
                      torneo.Sede_Registrar                      país + ciudad + estadio (crea lo que falte)
                      torneo.Partido_RegistrarResultado          marcador, asistencia y suspensiones cumplidas
                    Convocatoria
                      torneo.Convocatoria_Registrar              lista completa de convocados (mínimo del reglamento)
                      torneo.Convocatoria_ReemplazarJugador      baja de último momento + alta del reemplazo
                    Formaciones y cambios
                      torneo.Alineacion_Registrar                formación + titulares + banco + vínculo al partido
                      torneo.Cambio_Registrar                    sustitución con numeración automática
                    Goles, tarjetas y suspensiones
                      torneo.Gol_Registrar                       gol con numeración automática
                      torneo.Tarjeta_Registrar                   tarjeta + expulsión + suspensión (incluye acumulación)
                    Árbitros
                      torneo.Partido_DesignarArbitros            equipo arbitral completo de un partido
                    Publicidad
                      publicidad.SimularPrimeTime                mercados en prime time para un partido
                      publicidad.AsignarAutomaticamenteAPartido  las cuatro piezas de un partido según la sección H

                  Listas: Convocatoria_Registrar y Alineacion_Registrar leen tablas temporales que arma quien
                  llama, con una columna id autonumérica:
                    #Convocados (id INT IDENTITY, dni, nombre, fecha_nacimiento, id_club, nro_dorsal, posicion)
                    #Titulares  (id INT IDENTITY, id_jugador, posicion_cancha, dorsal_cancha)
                    #Suplentes  (id INT IDENTITY, id_jugador)
                  Se recorren con un WHILE (sin cursores).

                  Parámetros (torneo.Parametro, con valor por defecto si no están cargados):
                    MIN_CONVOCADOS (23), AMARILLAS_PARA_SUSPENSION (2) y PARTIDOS_SUSPENSION (1).
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ SEDE
-- Registra una sede completa. Si el país o la ciudad no existen, los crea en la misma transacción.
-- Las validaciones las hacen Pais_Insertar, Ciudad_Insertar y Sede_Insertar.
CREATE OR ALTER PROCEDURE torneo.Sede_Registrar
    @pais VARCHAR(80),
    @huso_pais DECIMAL(4,2) = NULL,
    @ciudad VARCHAR(80),
    @huso_ciudad DECIMAL(4,2),
    @nombre_estadio VARCHAR(100),
    @capacidad INT,
    @id_sede INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_pais INT, @id_ciudad INT;

    -- si el país es nuevo y no se informó su huso, se usa el de la ciudad
    SET @huso_pais = ISNULL(@huso_pais, @huso_ciudad);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @id_pais = id_pais FROM geo.Pais WHERE nombre = @pais;
        IF @id_pais IS NULL
            EXEC geo.Pais_Insertar @nombre = @pais, @huso_horario = @huso_pais, @id_pais = @id_pais OUTPUT;

        SELECT @id_ciudad = id_ciudad FROM geo.Ciudad WHERE id_pais = @id_pais AND nombre = @ciudad;
        IF @id_ciudad IS NULL
            EXEC geo.Ciudad_Insertar @id_pais = @id_pais, @nombre = @ciudad, @huso_horario = @huso_ciudad,
                                     @id_ciudad = @id_ciudad OUTPUT;

        EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad, @nombre_estadio = @nombre_estadio,
                                  @capacidad = @capacidad, @id_sede = @id_sede OUTPUT;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @id_sede = NULL;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ CONVOCATORIA
-- Registra la lista de convocados de una selección (tabla temporal #Convocados). Cada jugador pasa por
-- personas.Jugador_Insertar, que valida DNI, dorsal, club, posición y el máximo de convocados. Lo único
-- que se controla acá es el mínimo del reglamento; si algo falla no se carga ninguno.
CREATE OR ALTER PROCEDURE torneo.Convocatoria_Registrar
    @id_seleccion INT,
    @cantidad_registrada INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @minimo INT = torneo.fn_Parametro('MIN_CONVOCADOS', 23);
    DECLARE @id INT, @dni VARCHAR(20), @nombre VARCHAR(100), @nacimiento DATE;
    DECLARE @club INT, @dorsal TINYINT, @posicion VARCHAR(15);

    IF OBJECT_ID('tempdb..#Convocados') IS NULL
        THROW 50001, 'Antes hay que crear y cargar la tabla temporal #Convocados. ', 1;

    SET @cantidad_registrada = 0;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @id = MIN(id) FROM #Convocados;
        WHILE @id IS NOT NULL
        BEGIN
            SELECT @dni = dni, @nombre = nombre, @nacimiento = fecha_nacimiento,
                   @club = id_club, @dorsal = nro_dorsal, @posicion = posicion
            FROM #Convocados WHERE id = @id;

            EXEC personas.Jugador_Insertar @dni = @dni, @nombre = @nombre, @fecha_nacimiento = @nacimiento,
                                           @id_seleccion = @id_seleccion, @id_club = @club,
                                           @nro_dorsal = @dorsal, @posicion = @posicion;
            SET @cantidad_registrada += 1;

            SELECT @id = MIN(id) FROM #Convocados WHERE id > @id;
        END;

        IF (SELECT COUNT(*) FROM personas.fn_ConvocadosActivos(@id_seleccion)) < @minimo
            THROW 50001, 'La convocatoria tiene menos jugadores que el mínimo del reglamento. ', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @cantidad_registrada = 0;
        THROW;
    END CATCH;
END;
GO

-- Baja de último momento y alta del reemplazo en la misma selección. El reemplazo toma el dorsal del
-- jugador que sale, así que la cantidad de convocados no cambia. Fecha y motivo los valida
-- ReemplazoConvocatoria_Insertar; club y posición, las restricciones de la tabla.
CREATE OR ALTER PROCEDURE torneo.Convocatoria_ReemplazarJugador
    @id_jugador_sale INT,
    @fecha DATE,
    @motivo VARCHAR(100),
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_club INT,
    @posicion VARCHAR(15),
    @id_jugador_entra INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel INT, @dorsal TINYINT;

    SELECT @sel = id_seleccion, @dorsal = nro_dorsal FROM personas.Jugador WHERE id_participante = @id_jugador_sale;

    IF @sel IS NULL
        SET @errores += 'El jugador que sale no existe. ';
    IF EXISTS (SELECT 1 FROM personas.Participante WHERE dni = @dni)
        SET @errores += 'Ya existe una persona con ese DNI. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personas.Participante (dni, nombre, fecha_nacimiento, tipo)
        VALUES (LTRIM(RTRIM(@dni)), LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'J');
        SET @id_jugador_entra = SCOPE_IDENTITY();

        INSERT INTO personas.Jugador (id_participante, id_seleccion, id_club, nro_dorsal, posicion)
        VALUES (@id_jugador_entra, @sel, @id_club, @dorsal, @posicion);

        EXEC torneo.ReemplazoConvocatoria_Insertar @id_jugador_sale = @id_jugador_sale,
                                                   @id_jugador_entra = @id_jugador_entra,
                                                   @fecha = @fecha, @motivo = @motivo;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @id_jugador_entra = NULL;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ FORMACIONES Y CAMBIOS
-- Registra la alineación de una selección en un partido: crea la formación, carga los titulares
-- (#Titulares) y el banco (#Suplentes) y la vincula al partido. Todo lo valida cada SP ABM:
-- convocados activos, cantidad de titulares y suplentes, dorsales y jugadores suspendidos.
CREATE OR ALTER PROCEDURE torneo.Alineacion_Registrar
    @id_partido INT,
    @id_seleccion INT,
    @esquema_tactico VARCHAR(10),
    @id_formacion INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @id_jugador INT, @posicion_cancha VARCHAR(20), @dorsal_cancha TINYINT;

    IF OBJECT_ID('tempdb..#Titulares') IS NULL OR OBJECT_ID('tempdb..#Suplentes') IS NULL
        THROW 50001, 'Antes hay que crear y cargar las tablas temporales #Titulares y #Suplentes. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC torneo.Formacion_Insertar @id_seleccion = @id_seleccion, @esquema_tactico = @esquema_tactico,
                                       @id_formacion = @id_formacion OUTPUT;

        SELECT @id = MIN(id) FROM #Titulares;
        WHILE @id IS NOT NULL
        BEGIN
            SELECT @id_jugador = id_jugador, @posicion_cancha = posicion_cancha, @dorsal_cancha = dorsal_cancha
            FROM #Titulares WHERE id = @id;

            EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_formacion, @id_jugador = @id_jugador,
                                                  @posicion_cancha = @posicion_cancha, @dorsal_cancha = @dorsal_cancha;

            SELECT @id = MIN(id) FROM #Titulares WHERE id > @id;
        END;

        SELECT @id = MIN(id) FROM #Suplentes;
        WHILE @id IS NOT NULL
        BEGIN
            SELECT @id_jugador = id_jugador FROM #Suplentes WHERE id = @id;

            EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_formacion, @id_jugador = @id_jugador;

            SELECT @id = MIN(id) FROM #Suplentes WHERE id > @id;
        END;

        EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_partido, @id_formacion = @id_formacion;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @id_formacion = NULL;
        THROW;
    END CATCH;
END;
GO

-- Registra una sustitución numerándola automáticamente. Las validaciones las hace Sustitucion_Insertar.
CREATE OR ALTER PROCEDURE torneo.Cambio_Registrar
    @id_partido INT,
    @id_jugador_sale INT,
    @id_jugador_entra INT,
    @minuto TINYINT,
    @periodo VARCHAR(20),
    @motivo VARCHAR(10),
    @nro TINYINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @nro = ISNULL(MAX(nro), 0) + 1 FROM torneo.Sustitucion WHERE id_partido = @id_partido;

    EXEC torneo.Sustitucion_Insertar @id_partido = @id_partido, @nro = @nro,
                                     @id_jugador_sale = @id_jugador_sale, @id_jugador_entra = @id_jugador_entra,
                                     @minuto = @minuto, @periodo = @periodo, @motivo = @motivo;
END;
GO

-- ------------------------------------------------------------------ GOLES, TARJETAS Y SUSPENSIONES
-- Registra un gol numerándolo automáticamente. Las validaciones las hace Gol_Insertar.
CREATE OR ALTER PROCEDURE torneo.Gol_Registrar
    @id_partido INT,
    @id_jugador_autor INT,
    @id_jugador_asistente INT = NULL,
    @minuto TINYINT,
    @tipo VARCHAR(10),
    @periodo VARCHAR(20),
    @nro TINYINT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @nro = ISNULL(MAX(nro), 0) + 1 FROM torneo.Gol WHERE id_partido = @id_partido;

    EXEC torneo.Gol_Insertar @id_partido = @id_partido, @nro = @nro, @id_jugador_autor = @id_jugador_autor,
                             @id_jugador_asistente = @id_jugador_asistente, @minuto = @minuto,
                             @tipo = @tipo, @periodo = @periodo;
END;
GO

-- Registra una tarjeta y, según corresponda, la expulsión y la suspensión:
--   * roja                         -> expulsión ROJA_DIRECTA y suspensión
--   * segunda amarilla del partido -> expulsión DOBLE_AMARILLA y suspensión
--   * amarilla simple              -> si la cantidad de partidos distintos con amarilla del jugador es
--                                     múltiplo de AMARILLAS_PARA_SUSPENSION, suspensión ACUMULACION_AMARILLAS
-- Cada suspensión es de PARTIDOS_SUSPENSION partidos. Las tarjetas las valida Sancion_Insertar.
CREATE OR ALTER PROCEDURE torneo.Tarjeta_Registrar
    @id_partido INT,
    @id_jugador INT,
    @color VARCHAR(8),
    @minuto TINYINT,
    @motivo VARCHAR(100) = NULL,
    @nro TINYINT = NULL OUTPUT,
    @motivo_suspension VARCHAR(25) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @umbral INT = torneo.fn_Parametro('AMARILLAS_PARA_SUSPENSION', 2);
    DECLARE @partidos TINYINT = torneo.fn_Parametro('PARTIDOS_SUSPENSION', 1);
    DECLARE @causa VARCHAR(15), @nro_expulsion TINYINT, @partidos_con_amarilla INT;

    SET @motivo_suspension = NULL;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @nro = ISNULL(MAX(nro), 0) + 1 FROM torneo.Sancion WHERE id_partido = @id_partido;

        EXEC torneo.Sancion_Insertar @id_partido = @id_partido, @nro = @nro, @id_jugador = @id_jugador,
                                     @color = @color, @minuto = @minuto, @motivo = @motivo;

        IF @color = 'ROJA'
            SET @causa = 'ROJA_DIRECTA';
        ELSE IF (SELECT COUNT(*) FROM torneo.Sancion
                 WHERE id_partido = @id_partido AND id_jugador = @id_jugador AND color = 'AMARILLA') = 2
            SET @causa = 'DOBLE_AMARILLA';

        IF @causa IS NOT NULL
        BEGIN
            SELECT @nro_expulsion = ISNULL(MAX(nro), 0) + 1 FROM torneo.Expulsion WHERE id_partido = @id_partido;

            EXEC torneo.Expulsion_Insertar @id_partido = @id_partido, @nro = @nro_expulsion,
                                           @id_jugador = @id_jugador, @causa = @causa;

            -- la primera amarilla de este partido pudo haber generado una acumulación que ya no corresponde
            DELETE FROM torneo.Suspension
            WHERE id_jugador = @id_jugador AND id_partido_origen = @id_partido AND motivo = 'ACUMULACION_AMARILLAS';

            EXEC torneo.Suspension_Insertar @id_jugador = @id_jugador, @id_partido_origen = @id_partido,
                                            @motivo = @causa, @partidos_a_cumplir = @partidos;
            SET @motivo_suspension = @causa;
        END
        ELSE
        BEGIN
            SELECT @partidos_con_amarilla = COUNT(DISTINCT id_partido)
            FROM torneo.Sancion
            WHERE id_jugador = @id_jugador AND color = 'AMARILLA';

            IF @umbral > 0 AND @partidos_con_amarilla % @umbral = 0
            BEGIN
                EXEC torneo.Suspension_Insertar @id_jugador = @id_jugador, @id_partido_origen = @id_partido,
                                                @motivo = 'ACUMULACION_AMARILLAS', @partidos_a_cumplir = @partidos;
                SET @motivo_suspension = 'ACUMULACION_AMARILLAS';
            END;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @nro = NULL;
        SET @motivo_suspension = NULL;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ RESULTADOS
-- Carga el resultado final de un partido (goles y asistencia) y suma un partido cumplido a las
-- suspensiones pendientes de los jugadores de las dos selecciones cuyo origen es un partido anterior.
-- Las validaciones del resultado las hace Partido_Modificar. Un partido solo se cierra una vez.
CREATE OR ALTER PROCEDURE torneo.Partido_RegistrarResultado
    @id_partido INT,
    @goles_1 TINYINT,
    @goles_2 TINYINT,
    @asistencia INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_sede INT, @fase VARCHAR(15), @fecha DATE, @horario TIME(0), @utc DATETIME2(0);
    DECLARE @sel_1 INT, @sel_2 INT, @arbitro_principal INT, @arbitro_var INT, @goles_actual TINYINT;

    SELECT @id_sede = id_sede, @fase = fase, @fecha = fecha, @horario = horario, @utc = fecha_hora_utc,
           @sel_1 = id_seleccion_1, @sel_2 = id_seleccion_2,
           @arbitro_principal = id_arbitro_principal, @arbitro_var = id_arbitro_var, @goles_actual = goles_1
    FROM torneo.Partido WHERE id_partido = @id_partido;

    IF @id_sede IS NULL
        THROW 50001, 'El partido no existe. ', 1;
    IF @goles_actual IS NOT NULL
        THROW 50001, 'El partido ya tiene resultado. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        EXEC torneo.Partido_Modificar @id_partido = @id_partido, @id_sede = @id_sede, @fase = @fase,
                                      @fecha = @fecha, @horario = @horario,
                                      @id_seleccion_1 = @sel_1, @id_seleccion_2 = @sel_2,
                                      @goles_1 = @goles_1, @goles_2 = @goles_2, @asistencia = @asistencia,
                                      @id_arbitro_principal = @arbitro_principal, @id_arbitro_var = @arbitro_var;

        UPDATE torneo.Suspension
        SET partidos_cumplidos = partidos_cumplidos + 1
        WHERE partidos_cumplidos < partidos_a_cumplir
          AND id_partido_origen IN (SELECT id_partido FROM torneo.Partido WHERE fecha_hora_utc < @utc)
          AND id_jugador IN (SELECT id_participante FROM personas.Jugador WHERE id_seleccion IN (@sel_1, @sel_2));

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ ÁRBITROS
-- Designa el equipo arbitral completo de un partido (principal, VAR, dos asistentes y cuarto árbitro),
-- reemplazando el que tuviera. El conflicto de nacionalidad, los roles repetidos y las advertencias
-- desde dieciseisavos los controlan Partido_Modificar y ArbitroSecundario_Insertar.
CREATE OR ALTER PROCEDURE torneo.Partido_DesignarArbitros
    @id_partido INT,
    @id_principal INT,
    @id_var INT,
    @id_asistente_1 INT,
    @id_asistente_2 INT,
    @id_cuarto INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_sede INT, @fase VARCHAR(15), @fecha DATE, @horario TIME(0), @sel_1 INT, @sel_2 INT;
    DECLARE @goles_1 TINYINT, @goles_2 TINYINT, @asistencia INT;

    IF @id_principal IS NULL OR @id_var IS NULL OR @id_asistente_1 IS NULL OR @id_asistente_2 IS NULL OR @id_cuarto IS NULL
        THROW 50001, 'Hay que indicar los cinco árbitros del equipo arbitral. ', 1;

    SELECT @id_sede = id_sede, @fase = fase, @fecha = fecha, @horario = horario,
           @sel_1 = id_seleccion_1, @sel_2 = id_seleccion_2,
           @goles_1 = goles_1, @goles_2 = goles_2, @asistencia = asistencia
    FROM torneo.Partido WHERE id_partido = @id_partido;

    IF @id_sede IS NULL
        THROW 50001, 'El partido no existe. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido;

        EXEC torneo.Partido_Modificar @id_partido = @id_partido, @id_sede = @id_sede, @fase = @fase,
                                      @fecha = @fecha, @horario = @horario,
                                      @id_seleccion_1 = @sel_1, @id_seleccion_2 = @sel_2,
                                      @goles_1 = @goles_1, @goles_2 = @goles_2, @asistencia = @asistencia,
                                      @id_arbitro_principal = @id_principal, @id_arbitro_var = @id_var;

        EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_partido, @id_arbitro = @id_asistente_1, @rol = 'ASISTENTE';
        EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_partido, @id_arbitro = @id_asistente_2, @rol = 'ASISTENTE';
        EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_partido, @id_arbitro = @id_cuarto, @rol = 'CUARTO';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ PUBLICIDAD
-- (SimularPrimeTime y AsignarAutomaticamenteAPartido, trasladados desde 08_SP_ABM_Publicidad.sql)

-- -------- PRIME TIME Simulacion --------------------------------------------------

CREATE OR ALTER PROCEDURE publicidad.SimularPrimeTime
    @id_partido int
AS
BEGIN 
    
    SET NOCOUNT ON 

    DECLARE @utc DATETIME2(0); 

    SELECT @utc = fecha_hora_utc
    FROM torneo.Partido
    WHERE id_partido = @id_partido; 

    IF @utc IS NULL 
        THROW 50001, 'El partido no existe', 1;

    SELECT  nombre,
            DATEADD(MINUTE,
                CAST(huso_horario * 60 AS INT),
                @utc) AS [Hora Local], 
            CASE 
                WHEN DATEPART(
                        HOUR, 
                        DATEADD(MINUTE,
                                CAST(huso_horario * 60 AS INT),
                                @utc)
                    ) BETWEEN 19 AND 23
                THEN 'SI'
                ELSE 'NO'
            END AS [Prime Time]
    FROM geo.Pais
    ORDER BY nombre

END
GO

-- ASIGNACIÓN AUTOMÁTICA----------------------------------------------------------

---------------------------------------------------------------------------------------------
-- Para cada contenido se calcula un puntaje. 
-- Se priorizan mercados correspondientes a las selecciones participantes (+1000), 
-- luego mercados cuyo horario local coincide con prime time (+500) 
-- y finalmente mercados con mayor PBI per cápita. 
-- Los cuatro contenidos con mayor puntaje son asignados automáticamente a 
-- los cuatro espacios publicitarios del partido.
------------------------------------------------------------------------------------

CREATE OR ALTER PROCEDURE publicidad.AsignarAutomaticamenteAPartido
    @id_partido int
AS
BEGIN 
    SET NOCOUNT ON 

    DECLARE @pais1 INT,
            @pais2 INT,
            @utc DATETIME2(0),
            @id_tarifa int,

            @sede INT;
    
    SELECT
        @utc = p.fecha_hora_utc,
        @pais1 = s1.id_pais,
        @pais2 = s2.id_pais,

        @sede = p.id_sede

    FROM torneo.Partido p
    JOIN torneo.Seleccion s1  ON s1.id_seleccion = p.id_seleccion_1
    JOIN torneo.Seleccion s2  ON s2.id_seleccion = p.id_seleccion_2
    WHERE p.id_partido = @id_partido;

    IF @utc IS NULL
        THROW 50001,'Partido inexistente',1;

    IF EXISTS
    (
        SELECT 1
        FROM publicidad.EspacioPublicitario
        WHERE id_partido = @id_partido
    )
        THROW 50001, 'El partido ya tiene publicidad asignada.', 1;
    
    -- RANKING
    WITH Ranking AS
    (
        SELECT
            cp.id_anunciante,
            cp.cod_campania,
            cp.cod_contenido,
            SUM(
                CASE
                    WHEN cp.id_pais IN (@pais1,@pais2)
                    THEN 1000
                    ELSE 0
                END
                +
                CASE
                    WHEN DATEPART(
                         HOUR,
                         DATEADD(
                           MINUTE,
                           CAST(p.huso_horario * 60 AS INT),
                           @utc
                         )
                         ) BETWEEN 19 AND 23
                    THEN 500
                    ELSE 0
                END
                +
                ISNULL(p.pbi_per_capita,0)/1000
            ) AS puntaje

        FROM publicidad.ContenidoPais cp
        JOIN geo.Pais p
          ON p.id_pais = cp.id_pais

        GROUP BY
            cp.id_anunciante,
            cp.cod_campania,
            cp.cod_contenido
    )

    SELECT TOP 4 *
    INTO #Top4 
    FROM Ranking
    ORDER BY puntaje DESC,
            id_anunciante,
            cod_campania,
            cod_contenido;

    -- Validación de exactamente 4 espacios publicitarios --
    IF (SELECT COUNT(*) FROM #Top4) < 4
        THROW 50001, 'No existen cuatro contenidos candidatos.', 1;

    SELECT TOP 1
        @id_tarifa = id_tarifa
    FROM torneo.Sede s
    JOIN geo.Ciudad c ON s.id_ciudad = c.id_ciudad
    JOIN geo.Pais p ON c.id_pais = p.id_pais
    CROSS APPLY (
        SELECT 
            CASE 
                WHEN DATEPART(HOUR, DATEADD(MINUTE, CAST(p.huso_horario * 60 AS INT), @utc)) BETWEEN 19 AND 23 THEN 'Prime Time Mundial'
                WHEN DATEPART(HOUR, DATEADD(MINUTE, CAST(p.huso_horario * 60 AS INT), @utc)) BETWEEN 13 AND 18 THEN 'Tarde'
                WHEN DATEPART(HOUR, DATEADD(MINUTE, CAST(p.huso_horario * 60 AS INT), @utc)) BETWEEN 11 AND 12 THEN 'Mediodia'
                WHEN DATEPART(HOUR, DATEADD(MINUTE, CAST(p.huso_horario * 60 AS INT), @utc)) BETWEEN 0 AND 10 THEN  'Mañana'
            END AS nombre_franja
                ) franja
    JOIN publicidad.Tarifa t ON t.franja = franja.nombre_franja

    IF @id_tarifa IS NULL
    THROW 50001, 'No existe ninguna tarifa cargada.', 1;

    -- Asignación final --
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO publicidad.EspacioPublicitario
        (
            id_partido,
            nro,
            id_tarifa,
            horario,
            id_anunciante,
            cod_campania,
            cod_contenido
        )
        SELECT
            @id_partido,
            ROW_NUMBER() OVER
            (
                ORDER BY
                    puntaje DESC,
                    id_anunciante,
                    cod_campania,
                    cod_contenido
            ),
            @id_tarifa,
            @utc,
            id_anunciante,
            cod_campania,
            cod_contenido
        FROM #Top4;

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    DROP TABLE #Top4;
END
GO
