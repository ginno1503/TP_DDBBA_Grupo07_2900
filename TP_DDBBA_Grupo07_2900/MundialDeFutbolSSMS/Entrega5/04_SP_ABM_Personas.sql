/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Alta, modificación y baja de jugador, árbitro, director técnico, ayudante, idiomas del
                  árbitro y reemplazos de convocatoria. Los subtipos de Participante se manejan dentro
                  de una transacción que escribe en Participante y en la tabla del subtipo.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ JUGADOR
CREATE OR ALTER PROCEDURE personas.Jugador_Insertar
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_seleccion INT,
    @id_club INT,
    @nro_dorsal TINYINT,
    @posicion VARCHAR(15),
    @id_participante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @maximo INT = torneo.fn_Parametro('MAX_CONVOCADOS', 26);

    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante WHERE dni = LTRIM(RTRIM(@dni)))
        SET @errores += 'Ya existe una persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF NOT EXISTS (SELECT 1 FROM personas.Club WHERE id_club = @id_club)
        SET @errores += 'El club no existe. ';
    IF @nro_dorsal IS NULL OR @nro_dorsal NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal debe estar entre 1 y 99. ';
    IF @posicion IS NULL OR @posicion NOT IN ('ARQUERO', 'DEFENSOR', 'MEDIOCAMPISTA', 'DELANTERO')
        SET @errores += 'La posición no es válida. ';
    IF EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@id_seleccion) WHERE nro_dorsal = @nro_dorsal)
        SET @errores += 'Ese dorsal ya lo tiene otro convocado de la selección. ';
    IF (SELECT COUNT(*) FROM personas.fn_ConvocadosActivos(@id_seleccion)) >= @maximo
        SET @errores += 'La selección ya tiene el máximo de jugadores convocados. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personas.Participante (dni, nombre, fecha_nacimiento, tipo)
        VALUES (LTRIM(RTRIM(@dni)), LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'J');
        SET @id_participante = SCOPE_IDENTITY();

        INSERT INTO personas.Jugador (id_participante, id_seleccion, id_club, nro_dorsal, posicion)
        VALUES (@id_participante, @id_seleccion, @id_club, @nro_dorsal, @posicion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.Jugador_Modificar
    @id_participante INT,
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_seleccion INT,
    @id_club INT,
    @nro_dorsal TINYINT,
    @posicion VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_participante)
        SET @errores += 'El jugador no existe. ';
    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante
                                    WHERE dni = LTRIM(RTRIM(@dni)) AND id_participante <> @id_participante)
        SET @errores += 'Ya existe otra persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF NOT EXISTS (SELECT 1 FROM personas.Club WHERE id_club = @id_club)
        SET @errores += 'El club no existe. ';
    IF @nro_dorsal IS NULL OR @nro_dorsal NOT BETWEEN 1 AND 99
        SET @errores += 'El dorsal debe estar entre 1 y 99. ';
    IF @posicion IS NULL OR @posicion NOT IN ('ARQUERO', 'DEFENSOR', 'MEDIOCAMPISTA', 'DELANTERO')
        SET @errores += 'La posición no es válida. ';
    IF EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@id_seleccion)
               WHERE nro_dorsal = @nro_dorsal AND id_participante <> @id_participante)
        SET @errores += 'Ese dorsal ya lo tiene otro convocado de la selección. ';
    -- si se cambia de selección no puede figurar en formaciones armadas con la anterior
    IF EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_participante AND id_seleccion <> @id_seleccion)
       AND (EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_jugador = @id_participante)
         OR EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_jugador = @id_participante))
        SET @errores += 'No se puede cambiar de selección a un jugador que figura en formaciones. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE personas.Participante
        SET dni = LTRIM(RTRIM(@dni)), nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
        WHERE id_participante = @id_participante;

        UPDATE personas.Jugador
        SET id_seleccion = @id_seleccion, id_club = @id_club, nro_dorsal = @nro_dorsal, posicion = @posicion
        WHERE id_participante = @id_participante;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.Jugador_Eliminar
    @id_participante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_participante)
        SET @errores += 'El jugador no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.FormacionTitular WHERE id_jugador = @id_participante)
       OR EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_jugador = @id_participante)
        SET @errores += 'El jugador figura en formaciones. ';
    IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_jugador_sale = @id_participante OR id_jugador_entra = @id_participante)
       OR EXISTS (SELECT 1 FROM torneo.Gol WHERE id_jugador_autor = @id_participante OR id_jugador_asistente = @id_participante)
        SET @errores += 'El jugador tiene cambios o goles registrados. ';
    IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_jugador = @id_participante)
       OR EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_jugador = @id_participante)
       OR EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_jugador = @id_participante)
        SET @errores += 'El jugador tiene tarjetas, expulsiones o suspensiones. ';
    IF EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria
               WHERE id_jugador_entra = @id_participante OR id_jugador_sale = @id_participante)
        SET @errores += 'El jugador figura en un reemplazo de convocatoria. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM personas.Jugador WHERE id_participante = @id_participante;
        DELETE FROM personas.Participante WHERE id_participante = @id_participante;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ ARBITRO
CREATE OR ALTER PROCEDURE personas.Arbitro_Insertar
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_pais INT,
    @categoria VARCHAR(15),
    @id_participante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante WHERE dni = LTRIM(RTRIM(@dni)))
        SET @errores += 'Ya existe una persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF @categoria IS NULL OR @categoria NOT IN ('FIFA', 'CONFEDERACION')
        SET @errores += 'La categoría debe ser FIFA o CONFEDERACION. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personas.Participante (dni, nombre, fecha_nacimiento, tipo)
        VALUES (LTRIM(RTRIM(@dni)), LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'A');
        SET @id_participante = SCOPE_IDENTITY();

        INSERT INTO personas.Arbitro (id_participante, id_pais, categoria)
        VALUES (@id_participante, @id_pais, @categoria);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.Arbitro_Modificar
    @id_participante INT,
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_pais INT,
    @categoria VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Arbitro WHERE id_participante = @id_participante)
        SET @errores += 'El árbitro no existe. ';
    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante
                                    WHERE dni = LTRIM(RTRIM(@dni)) AND id_participante <> @id_participante)
        SET @errores += 'Ya existe otra persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF @categoria IS NULL OR @categoria NOT IN ('FIFA', 'CONFEDERACION')
        SET @errores += 'La categoría debe ser FIFA o CONFEDERACION. ';
    -- si cambia de país no puede ser de una de las selecciones de un partido que ya tiene asignado
    IF EXISTS (SELECT 1 FROM torneo.Seleccion s
               JOIN torneo.Partido p ON s.id_seleccion IN (p.id_seleccion_1, p.id_seleccion_2)
               WHERE s.id_pais = @id_pais
                 AND (p.id_arbitro_principal = @id_participante OR p.id_arbitro_var = @id_participante
                      OR EXISTS (SELECT 1 FROM torneo.ArbitroSecundario a
                                 WHERE a.id_partido = p.id_partido AND a.id_arbitro = @id_participante)))
        SET @errores += 'Con ese país el árbitro tendría conflicto de nacionalidad en partidos ya asignados. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE personas.Participante
        SET dni = LTRIM(RTRIM(@dni)), nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
        WHERE id_participante = @id_participante;

        UPDATE personas.Arbitro SET id_pais = @id_pais, categoria = @categoria WHERE id_participante = @id_participante;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Sus idiomas se borran junto con él, pero si ya fue designado en un partido no se puede eliminar.
CREATE OR ALTER PROCEDURE personas.Arbitro_Eliminar
    @id_participante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Arbitro WHERE id_participante = @id_participante)
        SET @errores += 'El árbitro no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_arbitro_principal = @id_participante OR id_arbitro_var = @id_participante)
       OR EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_arbitro = @id_participante)
        SET @errores += 'El árbitro está designado en partidos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM personas.ArbitroIdioma WHERE id_arbitro = @id_participante;
        DELETE FROM personas.Arbitro WHERE id_participante = @id_participante;
        DELETE FROM personas.Participante WHERE id_participante = @id_participante;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ IDIOMAS DEL ARBITRO
CREATE OR ALTER PROCEDURE personas.ArbitroIdioma_Insertar
    @id_arbitro INT,
    @id_idioma INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Arbitro WHERE id_participante = @id_arbitro)
        SET @errores += 'El árbitro no existe. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE id_idioma = @id_idioma)
        SET @errores += 'El idioma no existe. ';
    IF EXISTS (SELECT 1 FROM personas.ArbitroIdioma WHERE id_arbitro = @id_arbitro AND id_idioma = @id_idioma)
        SET @errores += 'El árbitro ya tiene cargado ese idioma. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO personas.ArbitroIdioma (id_arbitro, id_idioma) VALUES (@id_arbitro, @id_idioma);
END;
GO

CREATE OR ALTER PROCEDURE personas.ArbitroIdioma_Eliminar
    @id_arbitro INT,
    @id_idioma INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM personas.ArbitroIdioma WHERE id_arbitro = @id_arbitro AND id_idioma = @id_idioma)
        THROW 50001, 'El árbitro no tiene cargado ese idioma. ', 1;

    DELETE FROM personas.ArbitroIdioma WHERE id_arbitro = @id_arbitro AND id_idioma = @id_idioma;
END;
GO

-- ------------------------------------------------------------------ DIRECTOR TECNICO
CREATE OR ALTER PROCEDURE personas.DirectorTecnico_Insertar
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_seleccion INT,
    @id_participante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante WHERE dni = LTRIM(RTRIM(@dni)))
        SET @errores += 'Ya existe una persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF EXISTS (SELECT 1 FROM personas.DirectorTecnico WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección ya tiene director técnico. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personas.Participante (dni, nombre, fecha_nacimiento, tipo)
        VALUES (LTRIM(RTRIM(@dni)), LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'D');
        SET @id_participante = SCOPE_IDENTITY();

        INSERT INTO personas.DirectorTecnico (id_participante, id_seleccion) VALUES (@id_participante, @id_seleccion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.DirectorTecnico_Modificar
    @id_participante INT,
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.DirectorTecnico WHERE id_participante = @id_participante)
        SET @errores += 'El director técnico no existe. ';
    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante
                                    WHERE dni = LTRIM(RTRIM(@dni)) AND id_participante <> @id_participante)
        SET @errores += 'Ya existe otra persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF EXISTS (SELECT 1 FROM personas.DirectorTecnico WHERE id_seleccion = @id_seleccion AND id_participante <> @id_participante)
        SET @errores += 'La selección ya tiene otro director técnico. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE personas.Participante
        SET dni = LTRIM(RTRIM(@dni)), nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
        WHERE id_participante = @id_participante;

        UPDATE personas.DirectorTecnico SET id_seleccion = @id_seleccion WHERE id_participante = @id_participante;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.DirectorTecnico_Eliminar
    @id_participante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM personas.DirectorTecnico WHERE id_participante = @id_participante)
        THROW 50001, 'El director técnico no existe. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM personas.DirectorTecnico WHERE id_participante = @id_participante;
        DELETE FROM personas.Participante WHERE id_participante = @id_participante;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ AYUDANTE
CREATE OR ALTER PROCEDURE personas.Ayudante_Insertar
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_seleccion INT,
    @id_participante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante WHERE dni = LTRIM(RTRIM(@dni)))
        SET @errores += 'Ya existe una persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personas.Participante (dni, nombre, fecha_nacimiento, tipo)
        VALUES (LTRIM(RTRIM(@dni)), LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'Y');
        SET @id_participante = SCOPE_IDENTITY();

        INSERT INTO personas.Ayudante (id_participante, id_seleccion) VALUES (@id_participante, @id_seleccion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.Ayudante_Modificar
    @id_participante INT,
    @dni VARCHAR(20),
    @nombre VARCHAR(100),
    @fecha_nacimiento DATE = NULL,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Ayudante WHERE id_participante = @id_participante)
        SET @errores += 'El ayudante no existe. ';
    IF @dni IS NULL OR LEN(LTRIM(RTRIM(@dni))) < 6
        SET @errores += 'El DNI es obligatorio y debe tener al menos 6 caracteres. ';
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Participante
                                    WHERE dni = LTRIM(RTRIM(@dni)) AND id_participante <> @id_participante)
        SET @errores += 'Ya existe otra persona con ese DNI. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre. ';
    IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha de nacimiento no puede ser futura. ';
    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE personas.Participante
        SET dni = LTRIM(RTRIM(@dni)), nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
        WHERE id_participante = @id_participante;

        UPDATE personas.Ayudante SET id_seleccion = @id_seleccion WHERE id_participante = @id_participante;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE personas.Ayudante_Eliminar
    @id_participante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM personas.Ayudante WHERE id_participante = @id_participante)
        THROW 50001, 'El ayudante no existe. ', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM personas.Ayudante WHERE id_participante = @id_participante;
        DELETE FROM personas.Participante WHERE id_participante = @id_participante;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ REEMPLAZO DE CONVOCADOS
-- El que sale queda dado de baja; el que entra pasa a ser convocado activo de la misma selección.
CREATE OR ALTER PROCEDURE torneo.ReemplazoConvocatoria_Insertar
    @id_jugador_sale INT,
    @id_jugador_entra INT,
    @fecha DATE,
    @motivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel_sale INT, @sel_entra INT;

    SELECT @sel_sale = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_sale;
    SELECT @sel_entra = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_entra;

    IF @sel_sale IS NULL
        SET @errores += 'El jugador que sale no existe. ';
    IF @sel_entra IS NULL
        SET @errores += 'El jugador que entra no existe. ';
    IF @id_jugador_sale = @id_jugador_entra
        SET @errores += 'El jugador que entra no puede ser el mismo que sale. ';
    IF @sel_sale IS NOT NULL AND @sel_entra IS NOT NULL AND @sel_sale <> @sel_entra
        SET @errores += 'Los dos jugadores deben ser de la misma selección. ';
    IF EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_sale = @id_jugador_sale)
        SET @errores += 'El jugador que sale ya fue reemplazado. ';
    IF EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_entra = @id_jugador_entra)
        SET @errores += 'El jugador que entra ya reemplazó a otro. ';
    IF EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_sale = @id_jugador_entra)
        SET @errores += 'El jugador que entra ya había sido dado de baja. ';
    IF @fecha IS NULL OR @fecha > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha es obligatoria y no puede ser futura. ';
    IF @motivo IS NULL OR LTRIM(RTRIM(@motivo)) = ''
        SET @errores += 'Falta el motivo del reemplazo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.ReemplazoConvocatoria (id_jugador_entra, id_jugador_sale, fecha, motivo)
    VALUES (@id_jugador_entra, @id_jugador_sale, @fecha, LTRIM(RTRIM(@motivo)));
END;
GO

CREATE OR ALTER PROCEDURE torneo.ReemplazoConvocatoria_Modificar
    @id_jugador_entra INT,
    @fecha DATE,
    @motivo VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_entra = @id_jugador_entra)
        SET @errores += 'El reemplazo no existe. ';
    IF @fecha IS NULL OR @fecha > CAST(GETDATE() AS DATE)
        SET @errores += 'La fecha es obligatoria y no puede ser futura. ';
    IF @motivo IS NULL OR LTRIM(RTRIM(@motivo)) = ''
        SET @errores += 'Falta el motivo del reemplazo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.ReemplazoConvocatoria
    SET fecha = @fecha, motivo = LTRIM(RTRIM(@motivo))
    WHERE id_jugador_entra = @id_jugador_entra;
END;
GO

-- Al deshacer el reemplazo el que había salido vuelve a la lista: no debe superarse el máximo.
CREATE OR ALTER PROCEDURE torneo.ReemplazoConvocatoria_Eliminar
    @id_jugador_entra INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @sel INT;

    SELECT @sel = id_seleccion FROM personas.Jugador WHERE id_participante = @id_jugador_entra;

    IF NOT EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_entra = @id_jugador_entra)
        SET @errores += 'El reemplazo no existe. ';
    IF (SELECT COUNT(*) FROM personas.fn_ConvocadosActivos(@sel)) >= torneo.fn_Parametro('MAX_CONVOCADOS', 26)
        SET @errores += 'Al deshacer el reemplazo la selección superaría el máximo de convocados. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.ReemplazoConvocatoria WHERE id_jugador_entra = @id_jugador_entra;
END;
GO
