/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Alta, modificación y baja de partido, formación, titulares, suplentes y del vínculo
                  entre un partido y las formaciones que lo juegan. Incluye el cálculo de la hora UTC,
                  la validación de árbitros por nacionalidad y la de jugadores suspendidos.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ PARTIDO
CREATE OR ALTER PROCEDURE torneo.Partido_Insertar
    @id_sede INT,
    @fase VARCHAR(15),
    @fecha DATE,
    @horario TIME(0),
    @id_seleccion_1 INT = NULL,
    @id_seleccion_2 INT = NULL,
    @asistencia INT = NULL,
    @id_arbitro_principal INT = NULL,
    @id_arbitro_var INT = NULL,
    @id_partido INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @capacidad INT, @grupo_1 CHAR(1), @grupo_2 CHAR(1), @pais_principal INT, @pais_var INT;

    SELECT @capacidad = capacidad FROM torneo.Sede WHERE id_sede = @id_sede;
    SELECT @grupo_1 = grupo FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_1;
    SELECT @grupo_2 = grupo FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_2;
    SELECT @pais_principal = id_pais FROM personas.Arbitro WHERE id_participante = @id_arbitro_principal;
    SELECT @pais_var = id_pais FROM personas.Arbitro WHERE id_participante = @id_arbitro_var;

    IF @capacidad IS NULL
        SET @errores += 'La sede no existe. ';
    IF @fase IS NULL OR @fase NOT IN ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER_PUESTO', 'FINAL')
        SET @errores += 'La fase no es válida. ';
    IF @fecha IS NULL OR @horario IS NULL
        SET @errores += 'La fecha y el horario locales son obligatorios. ';
    IF @id_seleccion_1 IS NOT NULL AND @grupo_1 IS NULL AND NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_1)
        SET @errores += 'La selección 1 no existe. ';
    IF @id_seleccion_2 IS NOT NULL AND @grupo_2 IS NULL AND NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_2)
        SET @errores += 'La selección 2 no existe. ';
    IF @id_seleccion_1 = @id_seleccion_2
        SET @errores += 'Las dos selecciones deben ser distintas. ';
    IF @fase = 'GRUPOS' AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL)
        SET @errores += 'En fase de grupos tienen que estar definidas las dos selecciones. ';
    IF @fase = 'GRUPOS' AND @grupo_1 <> @grupo_2
        SET @errores += 'En fase de grupos las dos selecciones deben ser del mismo grupo. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido
               WHERE fase = @fase
                 AND ((id_seleccion_1 = @id_seleccion_1 AND id_seleccion_2 = @id_seleccion_2)
                   OR (id_seleccion_1 = @id_seleccion_2 AND id_seleccion_2 = @id_seleccion_1)))
        SET @errores += 'Esas selecciones ya juegan entre sí en esa fase. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_sede = @id_sede AND fecha = @fecha AND horario = @horario)
        SET @errores += 'La sede ya tiene un partido en esa fecha y horario. ';
    IF @asistencia < 0 OR @asistencia > @capacidad
        SET @errores += 'La asistencia no puede ser negativa ni superar la capacidad de la sede. ';
    IF @id_arbitro_principal IS NOT NULL AND @pais_principal IS NULL
        SET @errores += 'El árbitro principal no existe. ';
    IF @id_arbitro_var IS NOT NULL AND @pais_var IS NULL
        SET @errores += 'El árbitro de VAR no existe. ';
    IF @id_arbitro_principal = @id_arbitro_var
        SET @errores += 'El árbitro principal y el de VAR deben ser distintos. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @pais_principal AND id_seleccion IN (@id_seleccion_1, @id_seleccion_2))
        SET @errores += 'Conflicto de nacionalidad: el árbitro principal es de una de las selecciones. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @pais_var AND id_seleccion IN (@id_seleccion_1, @id_seleccion_2))
        SET @errores += 'Conflicto de nacionalidad: el árbitro de VAR es de una de las selecciones. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    -- advertencia (no impide cargar el partido): desde dieciseisavos el país del árbitro puede cruzarse con los equipos
    IF @fase <> 'GRUPOS' AND @pais_principal IS NOT NULL AND torneo.fn_PaisSigueEnCompetencia(@pais_principal) = 1
        PRINT 'ADVERTENCIA: el país del árbitro principal todavía tiene una selección en competencia.';
    IF @fase <> 'GRUPOS' AND @pais_var IS NOT NULL AND torneo.fn_PaisSigueEnCompetencia(@pais_var) = 1
        PRINT 'ADVERTENCIA: el país del árbitro de VAR todavía tiene una selección en competencia.';

    INSERT INTO torneo.Partido (id_sede, id_seleccion_1, id_seleccion_2, fase, fecha, horario, fecha_hora_utc,
                                asistencia, id_arbitro_principal, id_arbitro_var)
    VALUES (@id_sede, @id_seleccion_1, @id_seleccion_2, @fase, @fecha, @horario,
            torneo.fn_UtcPartido(@fecha, @horario, @id_sede), @asistencia, @id_arbitro_principal, @id_arbitro_var);
    SET @id_partido = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE torneo.Partido_Modificar
    @id_partido INT,
    @id_sede INT,
    @fase VARCHAR(15),
    @fecha DATE,
    @horario TIME(0),
    @id_seleccion_1 INT = NULL,
    @id_seleccion_2 INT = NULL,
    @goles_1 TINYINT = NULL,
    @goles_2 TINYINT = NULL,
    @asistencia INT = NULL,
    @id_arbitro_principal INT = NULL,
    @id_arbitro_var INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @capacidad INT, @grupo_1 CHAR(1), @grupo_2 CHAR(1), @pais_principal INT, @pais_var INT;

    SELECT @capacidad = capacidad FROM torneo.Sede WHERE id_sede = @id_sede;
    SELECT @grupo_1 = grupo FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_1;
    SELECT @grupo_2 = grupo FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_2;
    SELECT @pais_principal = id_pais FROM personas.Arbitro WHERE id_participante = @id_arbitro_principal;
    SELECT @pais_var = id_pais FROM personas.Arbitro WHERE id_participante = @id_arbitro_var;

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF @capacidad IS NULL
        SET @errores += 'La sede no existe. ';
    IF @fase IS NULL OR @fase NOT IN ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER_PUESTO', 'FINAL')
        SET @errores += 'La fase no es válida. ';
    IF @fecha IS NULL OR @horario IS NULL
        SET @errores += 'La fecha y el horario locales son obligatorios. ';
    IF @id_seleccion_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_1)
        SET @errores += 'La selección 1 no existe. ';
    IF @id_seleccion_2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion_2)
        SET @errores += 'La selección 2 no existe. ';
    IF @id_seleccion_1 = @id_seleccion_2
        SET @errores += 'Las dos selecciones deben ser distintas. ';
    IF @fase = 'GRUPOS' AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL)
        SET @errores += 'En fase de grupos tienen que estar definidas las dos selecciones. ';
    IF @fase = 'GRUPOS' AND @grupo_1 <> @grupo_2
        SET @errores += 'En fase de grupos las dos selecciones deben ser del mismo grupo. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido
               WHERE id_partido <> @id_partido AND fase = @fase
                 AND ((id_seleccion_1 = @id_seleccion_1 AND id_seleccion_2 = @id_seleccion_2)
                   OR (id_seleccion_1 = @id_seleccion_2 AND id_seleccion_2 = @id_seleccion_1)))
        SET @errores += 'Esas selecciones ya juegan entre sí en esa fase. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido
               WHERE id_partido <> @id_partido AND id_sede = @id_sede AND fecha = @fecha AND horario = @horario)
        SET @errores += 'La sede ya tiene otro partido en esa fecha y horario. ';
    IF (@goles_1 IS NULL AND @goles_2 IS NOT NULL) OR (@goles_1 IS NOT NULL AND @goles_2 IS NULL)
        SET @errores += 'El resultado debe tener los goles de las dos selecciones. ';
    IF @goles_1 IS NOT NULL AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL)
        SET @errores += 'No se puede cargar resultado si no están definidas las dos selecciones. ';
    IF @asistencia < 0 OR @asistencia > @capacidad
        SET @errores += 'La asistencia no puede ser negativa ni superar la capacidad de la sede. ';
    IF @id_arbitro_principal IS NOT NULL AND @pais_principal IS NULL
        SET @errores += 'El árbitro principal no existe. ';
    IF @id_arbitro_var IS NOT NULL AND @pais_var IS NULL
        SET @errores += 'El árbitro de VAR no existe. ';
    IF @id_arbitro_principal = @id_arbitro_var
        SET @errores += 'El árbitro principal y el de VAR deben ser distintos. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @pais_principal AND id_seleccion IN (@id_seleccion_1, @id_seleccion_2))
        SET @errores += 'Conflicto de nacionalidad: el árbitro principal es de una de las selecciones. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @pais_var AND id_seleccion IN (@id_seleccion_1, @id_seleccion_2))
        SET @errores += 'Conflicto de nacionalidad: el árbitro de VAR es de una de las selecciones. ';
    IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario
               WHERE id_partido = @id_partido AND id_arbitro IN (@id_arbitro_principal, @id_arbitro_var))
        SET @errores += 'El árbitro principal o el de VAR ya está designado como árbitro secundario. ';
    -- las formaciones ya vinculadas tienen que seguir siendo de las selecciones del partido
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion
               WHERE id_partido = @id_partido AND id_seleccion NOT IN (ISNULL(@id_seleccion_1, 0), ISNULL(@id_seleccion_2, 0)))
        SET @errores += 'El partido tiene formaciones de una selección que se quiere reemplazar. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @fase <> 'GRUPOS' AND @pais_principal IS NOT NULL AND torneo.fn_PaisSigueEnCompetencia(@pais_principal) = 1
        PRINT 'ADVERTENCIA: el país del árbitro principal todavía tiene una selección en competencia.';
    IF @fase <> 'GRUPOS' AND @pais_var IS NOT NULL AND torneo.fn_PaisSigueEnCompetencia(@pais_var) = 1
        PRINT 'ADVERTENCIA: el país del árbitro de VAR todavía tiene una selección en competencia.';

    UPDATE torneo.Partido
    SET id_sede = @id_sede, id_seleccion_1 = @id_seleccion_1, id_seleccion_2 = @id_seleccion_2, fase = @fase,
        fecha = @fecha, horario = @horario, fecha_hora_utc = torneo.fn_UtcPartido(@fecha, @horario, @id_sede),
        goles_1 = @goles_1, goles_2 = @goles_2, asistencia = @asistencia,
        id_arbitro_principal = @id_arbitro_principal, id_arbitro_var = @id_arbitro_var
    WHERE id_partido = @id_partido;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Partido_Eliminar
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_partido)
        SET @errores += 'El partido tiene formaciones vinculadas. ';
    IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @id_partido)
       OR EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @id_partido)
       OR EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @id_partido)
       OR EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido)
        SET @errores += 'El partido tiene cambios, goles, tarjetas o expulsiones. ';
    IF EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_partido_origen = @id_partido)
        SET @errores += 'Hay suspensiones originadas en ese partido. ';
    IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido)
        SET @errores += 'El partido tiene árbitros secundarios designados. ';
    IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido)
        SET @errores += 'El partido tiene espacios publicitarios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Partido WHERE id_partido = @id_partido;
END;
GO

-- ------------------------------------------------------------------ FORMACION
CREATE OR ALTER PROCEDURE torneo.Formacion_Insertar
    @id_seleccion INT,
    @esquema_tactico VARCHAR(10),
    @id_formacion INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF @esquema_tactico IS NULL OR @esquema_tactico NOT LIKE '[0-9]-[0-9]%'
        SET @errores += 'El esquema táctico debe tener el formato 4-3-3. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Formacion (id_seleccion, esquema_tactico) VALUES (@id_seleccion, @esquema_tactico);
    SET @id_formacion = SCOPE_IDENTITY();
END;
GO

-- La selección de una formación no se cambia: sus jugadores son de esa selección.
CREATE OR ALTER PROCEDURE torneo.Formacion_Modificar
    @id_formacion INT,
    @esquema_tactico VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += 'La formación no existe. ';
    IF @esquema_tactico IS NULL OR @esquema_tactico NOT LIKE '[0-9]-[0-9]%'
        SET @errores += 'El esquema táctico debe tener el formato 4-3-3. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Formacion SET esquema_tactico = @esquema_tactico WHERE id_formacion = @id_formacion;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Formacion_Eliminar
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += 'La formación no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_formacion = @id_formacion)
        SET @errores += 'La formación está vinculada a partidos. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion)
       OR EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion)
        SET @errores += 'La formación tiene titulares o suplentes cargados. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Formacion WHERE id_formacion = @id_formacion;
END;
GO

-- ------------------------------------------------------------------ TITULARES
CREATE OR ALTER PROCEDURE torneo.FormacionTitular_Insertar
    @id_formacion INT,
    @id_jugador INT,
    @posicion_cancha VARCHAR(20),
    @dorsal_cancha TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel INT;

    SELECT @sel = id_seleccion FROM torneo.Formacion WHERE id_formacion = @id_formacion;

    IF @sel IS NULL
        SET @errores += 'La formación no existe. ';
    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no existe. ';
    IF @sel IS NOT NULL AND NOT EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@sel) WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no es un convocado activo de la selección de la formación. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador ya es titular de esa formación. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador ya está en el banco de esa formación. ';
    IF (SELECT COUNT(*) FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion) >= torneo.fn_Parametro('MAX_TITULARES', 11)
        SET @errores += 'La formación ya tiene todos los titulares. ';
    IF @posicion_cancha IS NULL OR LTRIM(RTRIM(@posicion_cancha)) = ''
        SET @errores += 'Falta la posición en cancha. ';
    IF @dorsal_cancha IS NULL OR @dorsal_cancha NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal en cancha debe estar entre 1 y 99. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion AND dorsal_cancha = @dorsal_cancha)
        SET @errores += 'Ese dorsal ya lo usa otro titular de la formación. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.FormacionTitular (id_formacion, id_jugador, posicion_cancha, dorsal_cancha)
    VALUES (@id_formacion, @id_jugador, LTRIM(RTRIM(@posicion_cancha)), @dorsal_cancha);
END;
GO

CREATE OR ALTER PROCEDURE torneo.FormacionTitular_Modificar
    @id_formacion INT,
    @id_jugador INT,
    @posicion_cancha VARCHAR(20),
    @dorsal_cancha TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador no es titular de esa formación. ';
    IF @posicion_cancha IS NULL OR LTRIM(RTRIM(@posicion_cancha)) = ''
        SET @errores += 'Falta la posición en cancha. ';
    IF @dorsal_cancha IS NULL OR @dorsal_cancha NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal en cancha debe estar entre 1 y 99. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionTitular
               WHERE id_formacion = @id_formacion AND dorsal_cancha = @dorsal_cancha AND id_jugador <> @id_jugador)
        SET @errores += 'Ese dorsal ya lo usa otro titular de la formación. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.FormacionTitular
    SET posicion_cancha = LTRIM(RTRIM(@posicion_cancha)), dorsal_cancha = @dorsal_cancha
    WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;
END;
GO

-- No se saca a un jugador de una formación si en un partido de esa formación ya tiene cambios, goles o tarjetas.
CREATE OR ALTER PROCEDURE torneo.FormacionTitular_Eliminar
    @id_formacion INT,
    @id_jugador INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador no es titular de esa formación. ';
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion pf
               WHERE pf.id_formacion = @id_formacion
                 AND (EXISTS (SELECT 1 FROM torneo.Sustitucion s WHERE s.id_partido = pf.id_partido
                              AND (s.id_jugador_sale = @id_jugador OR s.id_jugador_entra = @id_jugador))
                   OR EXISTS (SELECT 1 FROM torneo.Gol g WHERE g.id_partido = pf.id_partido
                              AND (g.id_jugador_autor = @id_jugador OR g.id_jugador_asistente = @id_jugador))
                   OR EXISTS (SELECT 1 FROM torneo.Sancion n WHERE n.id_partido = pf.id_partido AND n.id_jugador = @id_jugador)))
        SET @errores += 'El jugador tiene cambios, goles o tarjetas en partidos de esa formación. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;
END;
GO

-- ------------------------------------------------------------------ SUPLENTES
CREATE OR ALTER PROCEDURE torneo.FormacionSuplente_Insertar
    @id_formacion INT,
    @id_jugador INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel INT;

    SELECT @sel = id_seleccion FROM torneo.Formacion WHERE id_formacion = @id_formacion;

    IF @sel IS NULL
        SET @errores += 'La formación no existe. ';
    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no existe. ';
    IF @sel IS NOT NULL AND NOT EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@sel) WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no es un convocado activo de la selección de la formación. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador ya está en el banco de esa formación. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador ya es titular de esa formación. ';
    IF (SELECT COUNT(*) FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion) >= torneo.fn_Parametro('MAX_SUPLENTES', 15)
        SET @errores += 'El banco de suplentes ya está completo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.FormacionSuplente (id_formacion, id_jugador) VALUES (@id_formacion, @id_jugador);
END;
GO

CREATE OR ALTER PROCEDURE torneo.FormacionSuplente_Eliminar
    @id_formacion INT,
    @id_jugador INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += 'El jugador no está en el banco de esa formación. ';
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion pf
               WHERE pf.id_formacion = @id_formacion
                 AND (EXISTS (SELECT 1 FROM torneo.Sustitucion s WHERE s.id_partido = pf.id_partido AND s.id_jugador_entra = @id_jugador)
                   OR EXISTS (SELECT 1 FROM torneo.Gol g WHERE g.id_partido = pf.id_partido
                              AND (g.id_jugador_autor = @id_jugador OR g.id_jugador_asistente = @id_jugador))
                   OR EXISTS (SELECT 1 FROM torneo.Sancion n WHERE n.id_partido = pf.id_partido AND n.id_jugador = @id_jugador)))
        SET @errores += 'El jugador tiene cambios, goles o tarjetas en partidos de esa formación. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;
END;
GO

-- ------------------------------------------------------------------ FORMACION EN UN PARTIDO
-- Es el momento de controlar que la formación esté completa y que no haya jugadores suspendidos.
CREATE OR ALTER PROCEDURE torneo.PartidoFormacion_Insertar
    @id_partido INT,
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel INT, @sel_1 INT, @sel_2 INT, @suspendidos VARCHAR(500);
    DECLARE @partido_existe BIT = 0;

    SELECT @sel = id_seleccion FROM torneo.Formacion WHERE id_formacion = @id_formacion;
    SELECT @sel_1 = id_seleccion_1, @sel_2 = id_seleccion_2, @partido_existe = 1
    FROM torneo.Partido WHERE id_partido = @id_partido;

    SELECT @suspendidos = STRING_AGG(pa.nombre, ', ')
    FROM (SELECT id_jugador FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion
          UNION
          SELECT id_jugador FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion) f
    JOIN personas.Participante pa ON pa.id_participante = f.id_jugador
    WHERE torneo.fn_JugadorSuspendido(f.id_jugador, @id_partido) = 1;

    IF @partido_existe = 0
        SET @errores += 'El partido no existe. ';
    IF @sel IS NULL
        SET @errores += 'La formación no existe. ';
    IF @sel IS NOT NULL AND @partido_existe = 1 AND @sel NOT IN (ISNULL(@sel_1, 0), ISNULL(@sel_2, 0))
        SET @errores += 'La formación es de una selección que no juega ese partido. ';
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_partido AND id_seleccion = @sel)
        SET @errores += 'Ese partido ya tiene una formación de esa selección. ';
    IF (SELECT COUNT(*) FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion) <> torneo.fn_Parametro('MAX_TITULARES', 11)
        SET @errores += 'La formación debe tener exactamente la cantidad de titulares del reglamento. ';
    IF @suspendidos IS NOT NULL
        SET @errores += 'Hay jugadores suspendidos en la formación: ' + @suspendidos + '. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.PartidoFormacion (id_partido, id_formacion, id_seleccion) VALUES (@id_partido, @id_formacion, @sel);
END;
GO

CREATE OR ALTER PROCEDURE torneo.PartidoFormacion_Eliminar
    @id_partido INT,
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_partido AND id_formacion = @id_formacion)
        SET @errores += 'Esa formación no está vinculada a ese partido. ';
    IF EXISTS (SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido) j
               WHERE j.id_seleccion = (SELECT id_seleccion FROM torneo.Formacion WHERE id_formacion = @id_formacion)
                 AND (EXISTS (SELECT 1 FROM torneo.Sustitucion s WHERE s.id_partido = @id_partido
                              AND (s.id_jugador_sale = j.id_jugador OR s.id_jugador_entra = j.id_jugador))
                   OR EXISTS (SELECT 1 FROM torneo.Gol g WHERE g.id_partido = @id_partido
                              AND (g.id_jugador_autor = j.id_jugador OR g.id_jugador_asistente = j.id_jugador))
                   OR EXISTS (SELECT 1 FROM torneo.Sancion n WHERE n.id_partido = @id_partido AND n.id_jugador = j.id_jugador)))
        SET @errores += 'Los jugadores de esa formación ya tienen cambios, goles o tarjetas en el partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.PartidoFormacion WHERE id_partido = @id_partido AND id_formacion = @id_formacion;
END;
GO
