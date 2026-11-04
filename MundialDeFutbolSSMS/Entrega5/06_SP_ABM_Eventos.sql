/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Alta, modificación y baja de los eventos de un partido: cambios, goles, tarjetas,
                  expulsiones y suspensiones. Valida máximos de cambios y ventanas, que los jugadores
                  figuren en las formaciones del partido y la coherencia entre tarjetas y expulsiones.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ SUSTITUCION
CREATE OR ALTER PROCEDURE torneo.Sustitucion_Insertar
    @id_partido INT,
    @nro TINYINT,
    @id_jugador_sale INT,
    @id_jugador_entra INT,
    @minuto TINYINT,
    @periodo VARCHAR(20),
    @motivo VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel_sale INT, @sel_entra INT, @cambios INT, @cambios_alargue INT, @ventanas INT;

    SELECT @sel_sale = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_sale;
    SELECT @sel_entra = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_entra;

    -- cambios ya hechos por el equipo; las ventanas son los minutos distintos (sin contar el de este cambio)
    SELECT @cambios = COUNT(CASE WHEN s.periodo <> 'ALARGUE' THEN 1 END),
           @cambios_alargue = COUNT(CASE WHEN s.periodo = 'ALARGUE' THEN 1 END),
           @ventanas = COUNT(DISTINCT CASE WHEN s.periodo <> 'ALARGUE' AND s.minuto <> @minuto THEN s.minuto END)
    FROM torneo.Sustitucion s
    JOIN personas.Jugador j ON j.id_participante = s.id_jugador_sale
    WHERE s.id_partido = @id_partido AND j.id_seleccion = @sel_sale;

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF @sel_sale IS NULL
        SET @errores += 'El jugador que sale no existe. ';
    IF @sel_entra IS NULL
        SET @errores += 'El jugador que entra no existe. ';
    IF @nro IS NULL OR EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El número de cambio es obligatorio y no puede repetirse en el partido. ';
    IF @id_jugador_sale = @id_jugador_entra
        SET @errores += 'El jugador que entra no puede ser el que sale. ';
    IF @sel_sale <> @sel_entra
        SET @errores += 'Los dos jugadores deben ser de la misma selección. ';
    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += 'El minuto debe estar entre 1 y 135. ';
    IF @periodo IS NULL OR @periodo NOT IN ('PRIMER_TIEMPO', 'SEGUNDO_TIEMPO', 'ADICIONALES', 'ALARGUE')
        SET @errores += 'El período no es válido para un cambio. ';
    IF @motivo IS NULL OR @motivo NOT IN ('TACTICO', 'LESION', 'PRECAUCION')
        SET @errores += 'El motivo debe ser TACTICO, LESION o PRECAUCION. ';

    -- el que sale tiene que estar en cancha: titular o suplente que ya entró, y no haber salido ni estar expulsado
    IF @sel_sale IS NOT NULL AND NOT EXISTS (
           SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido) j
           WHERE j.id_jugador = @id_jugador_sale
             AND (j.condicion = 'TITULAR'
                  OR EXISTS (SELECT 1 FROM torneo.Sustitucion s
                             WHERE s.id_partido = @id_partido AND s.id_jugador_entra = @id_jugador_sale)))
        SET @errores += 'El jugador que sale no está en cancha. ';
    IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @id_partido AND id_jugador_sale = @id_jugador_sale)
        SET @errores += 'El jugador que sale ya había sido sustituido. ';
    IF EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @id_jugador_sale)
        SET @errores += 'El jugador que sale está expulsado. ';

    -- el que entra tiene que estar en el banco y no haber participado de otro cambio
    IF @sel_entra IS NOT NULL AND NOT EXISTS (
           SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido)
           WHERE id_jugador = @id_jugador_entra AND condicion = 'SUPLENTE')
        SET @errores += 'El jugador que entra no está en el banco de suplentes del partido. ';
    IF EXISTS (SELECT 1 FROM torneo.Sustitucion
               WHERE id_partido = @id_partido AND (id_jugador_entra = @id_jugador_entra OR id_jugador_sale = @id_jugador_entra))
        SET @errores += 'El jugador que entra ya participó de otro cambio. ';

    -- reglamento
    IF @periodo = 'ALARGUE' AND @cambios_alargue >= torneo.fn_Parametro('CAMBIOS_EXTRA_ALARGUE', 1)
        SET @errores += 'El equipo ya usó el cambio adicional del alargue. ';
    IF @periodo <> 'ALARGUE' AND @cambios >= torneo.fn_Parametro('MAX_CAMBIOS', 5)
        SET @errores += 'El equipo ya hizo el máximo de cambios permitidos. ';
    IF @periodo <> 'ALARGUE' AND @ventanas + 1 > torneo.fn_Parametro('MAX_VENTANAS', 3)
        SET @errores += 'El equipo superaría el máximo de ventanas de cambios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Sustitucion (id_partido, nro, id_jugador_sale, id_jugador_entra, minuto, periodo, motivo)
    VALUES (@id_partido, @nro, @id_jugador_sale, @id_jugador_entra, @minuto, @periodo, @motivo);
END;
GO

-- Solo se corrige el momento y el motivo; para cambiar jugadores se elimina y se carga de nuevo.
CREATE OR ALTER PROCEDURE torneo.Sustitucion_Modificar
    @id_partido INT,
    @nro TINYINT,
    @minuto TINYINT,
    @periodo VARCHAR(20),
    @motivo VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El cambio no existe. ';
    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += 'El minuto debe estar entre 1 y 135. ';
    IF @periodo IS NULL OR @periodo NOT IN ('PRIMER_TIEMPO', 'SEGUNDO_TIEMPO', 'ADICIONALES', 'ALARGUE')
        SET @errores += 'El período no es válido para un cambio. ';
    IF @motivo IS NULL OR @motivo NOT IN ('TACTICO', 'LESION', 'PRECAUCION')
        SET @errores += 'El motivo debe ser TACTICO, LESION o PRECAUCION. ';
    -- el que entra no puede haber salido antes de entrar
    IF EXISTS (SELECT 1 FROM torneo.Sustitucion a
               JOIN torneo.Sustitucion b ON b.id_partido = a.id_partido AND b.id_jugador_sale = a.id_jugador_entra
               WHERE a.id_partido = @id_partido AND a.nro = @nro AND b.minuto < @minuto)
        SET @errores += 'El jugador que entra ya había salido antes de ese minuto. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Sustitucion SET minuto = @minuto, periodo = @periodo, motivo = @motivo
    WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Sustitucion_Eliminar
    @id_partido INT,
    @nro TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El cambio no existe. ';
    -- si el que entró fue sustituido después, ese cambio depende de este
    IF EXISTS (SELECT 1 FROM torneo.Sustitucion a
               JOIN torneo.Sustitucion b ON b.id_partido = a.id_partido AND b.id_jugador_sale = a.id_jugador_entra
               WHERE a.id_partido = @id_partido AND a.nro = @nro)
        SET @errores += 'El jugador que entró en este cambio fue sustituido después. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Sustitucion WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

-- ------------------------------------------------------------------ GOL
CREATE OR ALTER PROCEDURE torneo.Gol_Insertar
    @id_partido INT,
    @nro TINYINT,
    @id_jugador_autor INT,
    @id_jugador_asistente INT = NULL,
    @minuto TINYINT,
    @tipo VARCHAR(10),
    @periodo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel_autor INT, @sel_asistente INT;

    SELECT @sel_autor = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_autor;
    SELECT @sel_asistente = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_asistente;

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF @nro IS NULL OR EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El número de gol es obligatorio y no puede repetirse en el partido. ';
    IF @sel_autor IS NULL
        SET @errores += 'El autor del gol no existe. ';
    IF @id_jugador_asistente IS NOT NULL AND @sel_asistente IS NULL
        SET @errores += 'El asistente no existe. ';
    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += 'El minuto debe estar entre 1 y 135. ';
    IF @tipo IS NULL OR @tipo NOT IN ('JUGADA', 'PENAL', 'TIRO_LIBRE', 'EN_CONTRA', 'CABEZAZO', 'OTRO')
        SET @errores += 'El tipo de gol no es válido. ';
    IF @periodo IS NULL OR @periodo NOT IN ('PRIMER_TIEMPO', 'SEGUNDO_TIEMPO', 'ADICIONALES', 'ALARGUE', 'DEFINICION_PENALES')
        SET @errores += 'El período no es válido. ';
    IF @sel_autor IS NOT NULL AND NOT EXISTS (SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido) WHERE id_jugador = @id_jugador_autor)
        SET @errores += 'El autor no figura en las formaciones del partido. ';
    IF @id_jugador_asistente = @id_jugador_autor
        SET @errores += 'El asistente no puede ser el autor. ';
    IF @tipo = 'EN_CONTRA' AND @id_jugador_asistente IS NOT NULL
        SET @errores += 'Un gol en contra no tiene asistencia. ';
    IF @tipo <> 'EN_CONTRA' AND @sel_asistente <> @sel_autor
        SET @errores += 'El asistente debe ser de la misma selección que el autor. ';
    IF @sel_asistente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido) WHERE id_jugador = @id_jugador_asistente)
        SET @errores += 'El asistente no figura en las formaciones del partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Gol (id_partido, nro, id_jugador_autor, id_jugador_asistente, minuto, tipo, periodo)
    VALUES (@id_partido, @nro, @id_jugador_autor, @id_jugador_asistente, @minuto, @tipo, @periodo);
END;
GO

CREATE OR ALTER PROCEDURE torneo.Gol_Modificar
    @id_partido INT,
    @nro TINYINT,
    @id_jugador_asistente INT = NULL,
    @minuto TINYINT,
    @tipo VARCHAR(10),
    @periodo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @autor INT, @sel_autor INT, @sel_asistente INT;

    SELECT @autor = id_jugador_autor FROM torneo.Gol WHERE id_partido = @id_partido AND nro = @nro;
    SELECT @sel_autor = id_seleccion FROM personas.Jugador WHERE id_participante = @autor;
    SELECT @sel_asistente = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_asistente;

    IF @autor IS NULL
        SET @errores += 'El gol no existe. ';
    IF @id_jugador_asistente IS NOT NULL AND @sel_asistente IS NULL
        SET @errores += 'El asistente no existe. ';
    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += 'El minuto debe estar entre 1 y 135. ';
    IF @tipo IS NULL OR @tipo NOT IN ('JUGADA', 'PENAL', 'TIRO_LIBRE', 'EN_CONTRA', 'CABEZAZO', 'OTRO')
        SET @errores += 'El tipo de gol no es válido. ';
    IF @periodo IS NULL OR @periodo NOT IN ('PRIMER_TIEMPO', 'SEGUNDO_TIEMPO', 'ADICIONALES', 'ALARGUE', 'DEFINICION_PENALES')
        SET @errores += 'El período no es válido. ';
    IF @id_jugador_asistente = @autor
        SET @errores += 'El asistente no puede ser el autor. ';
    IF @tipo = 'EN_CONTRA' AND @id_jugador_asistente IS NOT NULL
        SET @errores += 'Un gol en contra no tiene asistencia. ';
    IF @tipo <> 'EN_CONTRA' AND @sel_asistente <> @sel_autor
        SET @errores += 'El asistente debe ser de la misma selección que el autor. ';
    IF @sel_asistente IS NOT NULL AND NOT EXISTS (SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido) WHERE id_jugador = @id_jugador_asistente)
        SET @errores += 'El asistente no figura en las formaciones del partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Gol
    SET id_jugador_asistente = @id_jugador_asistente, minuto = @minuto, tipo = @tipo, periodo = @periodo
    WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Gol_Eliminar
    @id_partido INT,
    @nro TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @id_partido AND nro = @nro)
        THROW 50001, 'El gol no existe. ', 1;

    DELETE FROM torneo.Gol WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

-- ------------------------------------------------------------------ SANCION (tarjetas)
CREATE OR ALTER PROCEDURE torneo.Sancion_Insertar
    @id_partido INT,
    @nro TINYINT,
    @id_jugador INT,
    @color VARCHAR(8),
    @minuto TINYINT,
    @motivo VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF @nro IS NULL OR EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El número de tarjeta es obligatorio y no puede repetirse en el partido. ';
    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no existe. ';
    IF @color IS NULL OR @color NOT IN ('AMARILLA', 'ROJA')
        SET @errores += 'El color debe ser AMARILLA o ROJA. ';
    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += 'El minuto debe estar entre 1 y 135. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido) WHERE id_jugador = @id_jugador)
        SET @errores += 'El jugador no figura en las formaciones del partido. ';
    IF EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @id_jugador)
        SET @errores += 'El jugador ya fue expulsado en este partido. ';
    IF @color = 'AMARILLA' AND (SELECT COUNT(*) FROM torneo.Sancion
                                WHERE id_partido = @id_partido AND id_jugador = @id_jugador AND color = 'AMARILLA') >= 2
        SET @errores += 'El jugador ya tiene dos amarillas en este partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Sancion (id_partido, nro, id_jugador, color, minuto, motivo)
    VALUES (@id_partido, @nro, @id_jugador, @color, @minuto, @motivo);
END;
GO

CREATE OR ALTER PROCEDURE torneo.Sancion_Modificar
    @id_partido INT,
    @nro TINYINT,
    @color VARCHAR(8),
    @minuto TINYINT,
    @motivo VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @jugador INT, @amarillas_otras INT, @rojas_otras INT;

    SELECT @jugador = id_jugador FROM torneo.Sancion WHERE id_partido = @id_partido AND nro = @nro;
    SELECT @amarillas_otras = COUNT(CASE WHEN color = 'AMARILLA' THEN 1 END),
           @rojas_otras = COUNT(CASE WHEN color = 'ROJA' THEN 1 END)
    FROM torneo.Sancion WHERE id_partido = @id_partido AND id_jugador = @jugador AND nro <> @nro;

    IF @jugador IS NULL
        SET @errores += 'La tarjeta no existe. ';
    IF @color IS NULL OR @color NOT IN ('AMARILLA', 'ROJA')
        SET @errores += 'El color debe ser AMARILLA o ROJA. ';
    IF @minuto IS NULL OR @minuto NOT BETWEEN 1 AND 135
        SET @errores += 'El minuto debe estar entre 1 y 135. ';
    IF @color <> 'ROJA' AND @rojas_otras = 0
       AND EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @jugador AND causa = 'ROJA_DIRECTA')
        SET @errores += 'El jugador fue expulsado por roja directa: tiene que quedar una tarjeta roja. ';
    IF @color <> 'AMARILLA' AND @amarillas_otras < 2
       AND EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @jugador AND causa = 'DOBLE_AMARILLA')
        SET @errores += 'El jugador fue expulsado por doble amarilla: tienen que quedar dos amarillas. ';
    IF @color = 'AMARILLA' AND @amarillas_otras >= 2
        SET @errores += 'El jugador ya tiene dos amarillas en este partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Sancion SET color = @color, minuto = @minuto, motivo = @motivo
    WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Sancion_Eliminar
    @id_partido INT,
    @nro TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @jugador INT, @color VARCHAR(8), @amarillas_otras INT, @rojas_otras INT;

    SELECT @jugador = id_jugador, @color = color FROM torneo.Sancion WHERE id_partido = @id_partido AND nro = @nro;
    SELECT @amarillas_otras = COUNT(CASE WHEN color = 'AMARILLA' THEN 1 END),
           @rojas_otras = COUNT(CASE WHEN color = 'ROJA' THEN 1 END)
    FROM torneo.Sancion WHERE id_partido = @id_partido AND id_jugador = @jugador AND nro <> @nro;

    IF @jugador IS NULL
        SET @errores += 'La tarjeta no existe. ';
    IF @color = 'ROJA' AND @rojas_otras = 0
       AND EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @jugador AND causa = 'ROJA_DIRECTA')
        SET @errores += 'Es la tarjeta roja de una expulsión por roja directa: primero hay que eliminar la expulsión. ';
    IF @color = 'AMARILLA' AND @amarillas_otras < 2
       AND EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @jugador AND causa = 'DOBLE_AMARILLA')
        SET @errores += 'Es una de las amarillas de una expulsión por doble amarilla: primero hay que eliminar la expulsión. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Sancion WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

-- ------------------------------------------------------------------ EXPULSION
CREATE OR ALTER PROCEDURE torneo.Expulsion_Insertar
    @id_partido INT,
    @nro TINYINT,
    @id_jugador INT,
    @causa VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF @nro IS NULL OR EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El número de expulsión es obligatorio y no puede repetirse en el partido. ';
    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no existe. ';
    IF @causa IS NULL OR @causa NOT IN ('DOBLE_AMARILLA', 'ROJA_DIRECTA')
        SET @errores += 'La causa debe ser DOBLE_AMARILLA o ROJA_DIRECTA. ';
    IF EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @id_partido AND id_jugador = @id_jugador)
        SET @errores += 'El jugador ya fue expulsado en este partido. ';
    IF @causa = 'ROJA_DIRECTA' AND NOT EXISTS (SELECT 1 FROM torneo.Sancion
                                               WHERE id_partido = @id_partido AND id_jugador = @id_jugador AND color = 'ROJA')
        SET @errores += 'Para una roja directa el jugador debe tener una tarjeta roja en el partido. ';
    IF @causa = 'DOBLE_AMARILLA' AND (SELECT COUNT(*) FROM torneo.Sancion
                                      WHERE id_partido = @id_partido AND id_jugador = @id_jugador AND color = 'AMARILLA') < 2
        SET @errores += 'Para una doble amarilla el jugador debe tener dos amarillas en el partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Expulsion (id_partido, nro, id_jugador, causa) VALUES (@id_partido, @nro, @id_jugador, @causa);
END;
GO

CREATE OR ALTER PROCEDURE torneo.Expulsion_Modificar
    @id_partido INT,
    @nro TINYINT,
    @causa VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @jugador INT;

    SELECT @jugador = id_jugador FROM torneo.Expulsion WHERE id_partido = @id_partido AND nro = @nro;

    IF @jugador IS NULL
        SET @errores += 'La expulsión no existe. ';
    IF @causa IS NULL OR @causa NOT IN ('DOBLE_AMARILLA', 'ROJA_DIRECTA')
        SET @errores += 'La causa debe ser DOBLE_AMARILLA o ROJA_DIRECTA. ';
    IF @causa = 'ROJA_DIRECTA' AND NOT EXISTS (SELECT 1 FROM torneo.Sancion
                                               WHERE id_partido = @id_partido AND id_jugador = @jugador AND color = 'ROJA')
        SET @errores += 'Para una roja directa el jugador debe tener una tarjeta roja en el partido. ';
    IF @causa = 'DOBLE_AMARILLA' AND (SELECT COUNT(*) FROM torneo.Sancion
                                      WHERE id_partido = @id_partido AND id_jugador = @jugador AND color = 'AMARILLA') < 2
        SET @errores += 'Para una doble amarilla el jugador debe tener dos amarillas en el partido. ';
    IF EXISTS (SELECT 1 FROM torneo.Suspension
               WHERE id_partido_origen = @id_partido AND id_jugador = @jugador AND motivo IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA'))
        SET @errores += 'El jugador ya tiene una suspensión originada en esta expulsión: hay que corregirla primero. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Expulsion SET causa = @causa WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Expulsion_Eliminar
    @id_partido INT,
    @nro TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @jugador INT;

    SELECT @jugador = id_jugador FROM torneo.Expulsion WHERE id_partido = @id_partido AND nro = @nro;

    IF @jugador IS NULL
        SET @errores += 'La expulsión no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.Suspension
               WHERE id_partido_origen = @id_partido AND id_jugador = @jugador AND motivo IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA'))
        SET @errores += 'El jugador tiene una suspensión originada en esta expulsión: hay que eliminarla primero. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Expulsion WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

-- ------------------------------------------------------------------ SUSPENSION
CREATE OR ALTER PROCEDURE torneo.Suspension_Insertar
    @id_jugador INT,
    @id_partido_origen INT,
    @motivo VARCHAR(25),
    @partidos_a_cumplir TINYINT,
    @id_suspension INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @umbral INT = torneo.fn_Parametro('AMARILLAS_PARA_SUSPENSION', 2);

    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_jugador)
        SET @errores += 'El jugador no existe. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido_origen)
        SET @errores += 'El partido de origen no existe. ';
    IF @motivo IS NULL OR @motivo NOT IN ('ACUMULACION_AMARILLAS', 'ROJA_DIRECTA', 'DOBLE_AMARILLA')
        SET @errores += 'El motivo no es válido. ';
    IF @partidos_a_cumplir IS NULL OR @partidos_a_cumplir < 1
        SET @errores += 'Los partidos a cumplir deben ser al menos 1. ';
    IF EXISTS (SELECT 1 FROM torneo.Suspension
               WHERE id_jugador = @id_jugador AND id_partido_origen = @id_partido_origen AND motivo = @motivo)
        SET @errores += 'Esa suspensión ya está registrada. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.fn_JugadoresEnPartido(@id_partido_origen) WHERE id_jugador = @id_jugador)
        SET @errores += 'El jugador no figura en las formaciones del partido de origen. ';
    IF @motivo IN ('ROJA_DIRECTA', 'DOBLE_AMARILLA')
       AND NOT EXISTS (SELECT 1 FROM torneo.Expulsion
                       WHERE id_partido = @id_partido_origen AND id_jugador = @id_jugador AND causa = @motivo)
        SET @errores += 'El jugador no tiene una expulsión con esa causa en el partido de origen. ';
    IF @motivo = 'ACUMULACION_AMARILLAS'
       AND (SELECT COUNT(DISTINCT id_partido) FROM torneo.Sancion WHERE id_jugador = @id_jugador AND color = 'AMARILLA') < @umbral
        SET @errores += 'El jugador no llegó a la cantidad de amarillas que suspende. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Suspension (id_jugador, id_partido_origen, motivo, partidos_a_cumplir)
    VALUES (@id_jugador, @id_partido_origen, @motivo, @partidos_a_cumplir);
    SET @id_suspension = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE torneo.Suspension_Modificar
    @id_suspension INT,
    @partidos_a_cumplir TINYINT,
    @partidos_cumplidos TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_suspension = @id_suspension)
        SET @errores += 'La suspensión no existe. ';
    IF @partidos_a_cumplir IS NULL OR @partidos_a_cumplir < 1
        SET @errores += 'Los partidos a cumplir deben ser al menos 1. ';
    IF @partidos_cumplidos IS NULL OR @partidos_cumplidos > @partidos_a_cumplir
        SET @errores += 'Los partidos cumplidos no pueden superar a los que debe cumplir. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Suspension
    SET partidos_a_cumplir = @partidos_a_cumplir, partidos_cumplidos = @partidos_cumplidos
    WHERE id_suspension = @id_suspension;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Suspension_Eliminar
    @id_suspension INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_suspension = @id_suspension)
        THROW 50001, 'La suspensión no existe. ', 1;

    DELETE FROM torneo.Suspension WHERE id_suspension = @id_suspension;
END;
GO
