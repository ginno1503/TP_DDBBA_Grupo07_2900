/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 07/11/2026
   Objetivo     : Cifrado del DNI de los participantes con EncryptByPassPhrase.
                  Ejecutar UNA VEZ que todos los datos ya están cargados (scripts 00 a 21).
                  El script es re-ejecutable: solo cifra las filas que todavía no tienen DNI cifrado.
   ============================================================================= */

USE MundialFutbol;
GO

-- 1. CIFRADO

-- 1.1 Columna para el DNI cifrado
IF COL_LENGTH('personas.Participante', 'dni_cifrado') IS NULL
BEGIN
    ALTER TABLE personas.Participante
    ADD dni_cifrado VARBINARY(256) NULL;
END;
GO

-- 1.2 Cifrar el DNI solo de las filas que todavía no están cifradas.
DECLARE @FraseClaveCargadaPorUsuario NVARCHAR(128);
SET @FraseClaveCargadaPorUsuario = 'ClaveDeCifrado2026';

UPDATE personas.Participante
SET dni_cifrado = EncryptByPassPhrase(
        @FraseClaveCargadaPorUsuario, dni, 1,
        CONVERT(VARBINARY(20), id_participante))
WHERE dni_cifrado IS NULL
  AND dni <> CAST(id_participante AS VARCHAR(20));
GO

-- 1.3 DNI = ID: solo en las filas ya cifradas
UPDATE personas.Participante
SET dni = CAST(id_participante AS VARCHAR(20))
WHERE dni_cifrado IS NOT NULL
  AND dni <> CAST(id_participante AS VARCHAR(20));
GO


-- 2. FUNCIONES

-- Frase clave en un único lugar (usada por todas las funciones de cifrado).
CREATE OR ALTER FUNCTION personas.fn_FraseClave ()
RETURNS NVARCHAR(128)
AS
BEGIN
    RETURN 'ClaveDeCifrado2026';
END;
GO

-- Cifra un DNI con el mismo método de la sección 1 (authenticator = id_participante).
-- Lo usan los SP de alta y modificación.
CREATE OR ALTER FUNCTION personas.fn_CifrarDni (@dni VARCHAR(20), @id_participante INT)
RETURNS VARBINARY(256)
AS
BEGIN
    RETURN EncryptByPassPhrase(personas.fn_FraseClave(), @dni, 1, CONVERT(VARBINARY(20), @id_participante));
END;
GO

-- Devuelve el DNI real de un participante (NULL si no existe).
-- Si la fila todavía no está cifrada devuelve el valor de la columna dni.
CREATE OR ALTER FUNCTION personas.fn_DescifrarDni (@id_participante INT)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @dni VARCHAR(20);

    SELECT @dni = CASE WHEN dni_cifrado IS NULL THEN dni
                       ELSE CONVERT(VARCHAR(20),
                                    DecryptByPassPhrase(personas.fn_FraseClave(), dni_cifrado, 1,
                                                        CONVERT(VARBINARY(20), id_participante))) END
    FROM personas.Participante
    WHERE id_participante = @id_participante;

    RETURN @dni;
END;
GO

-- Id del participante que tiene ese DNI real (NULL si no hay ninguno).
CREATE OR ALTER FUNCTION personas.fn_IdPorDni (@dni VARCHAR(20))
RETURNS INT
AS
BEGIN
    DECLARE @id INT;
    SET @dni = LTRIM(RTRIM(@dni));

    SELECT TOP 1 @id = id_participante
    FROM personas.Participante
    WHERE CASE WHEN dni_cifrado IS NULL THEN dni
               ELSE CONVERT(VARCHAR(20),
                            DecryptByPassPhrase(personas.fn_FraseClave(), dni_cifrado, 1,
                                                CONVERT(VARBINARY(20), id_participante))) END = @dni
    ORDER BY id_participante;

    RETURN @id;
END;
GO


-- 3. STORED PROCEDURES MODIFICADOS

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (Jugador_Insertar): duplicado de DNI con fn_IdPorDni; el INSERT en Participante usa DNI
--         provisorio y luego guarda dni_cifrado (fn_CifrarDni) y dni = id.

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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) IS NOT NULL
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
        VALUES (LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 20),
                LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'J');
        SET @id_participante = SCOPE_IDENTITY();

        UPDATE personas.Participante
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20))
        WHERE id_participante = @id_participante;

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

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (Jugador_Modificar):el UPDATE ya no escribe el DNI en dni: guarda dni_cifrado y mantiene dni = id.

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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) <> @id_participante
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
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20)),
            nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
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

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (Arbitro_Insertar): igual que Jugador_Insertar.
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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) IS NOT NULL
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
        VALUES (LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 20),
                LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'A');
        SET @id_participante = SCOPE_IDENTITY();

        UPDATE personas.Participante
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20))
        WHERE id_participante = @id_participante;

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

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (Arbitro_Modificar): igual que Jugador_Modificar.
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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) <> @id_participante
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
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20)),
            nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
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

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (DirectorTecnico_Insertar): igual que Jugador_Insertar.
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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) IS NOT NULL
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
        VALUES (LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 20),
                LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'D');
        SET @id_participante = SCOPE_IDENTITY();

        UPDATE personas.Participante
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20))
        WHERE id_participante = @id_participante;

        INSERT INTO personas.DirectorTecnico (id_participante, id_seleccion) VALUES (@id_participante, @id_seleccion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (DirectorTecnico_Modificar): igual que Jugador_Modificar.
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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) <> @id_participante
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
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20)),
            nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
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

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (Ayudante_Insertar): igual que Jugador_Insertar.
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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) IS NOT NULL
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
        VALUES (LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 20),
                LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'Y');
        SET @id_participante = SCOPE_IDENTITY();

        UPDATE personas.Participante
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20))
        WHERE id_participante = @id_participante;

        INSERT INTO personas.Ayudante (id_participante, id_seleccion) VALUES (@id_participante, @id_seleccion);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ORIGEN: 04_SP_ABM_Personas.sql
-- CAMBIOS (Ayudante_Modificar): igual que Jugador_Modificar.
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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) <> @id_participante
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
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_participante),
            dni = CAST(@id_participante AS VARCHAR(20)),
            nombre = LTRIM(RTRIM(@nombre)), fecha_nacimiento = @fecha_nacimiento
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

-- ORIGEN: 09_SP_Negocio.sql
-- CAMBIOS (Convocatoria_ReemplazarJugador): la validación de DNI repetido usa fn_IdPorDni y el alta del
--         reemplazo en Participante usa DNI provisorio + dni_cifrado + dni = id.

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
    IF @dni IS NOT NULL AND personas.fn_IdPorDni(@dni) IS NOT NULL
        SET @errores += 'Ya existe una persona con ese DNI. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personas.Participante (dni, nombre, fecha_nacimiento, tipo)
        VALUES (LEFT(REPLACE(CAST(NEWID() AS VARCHAR(36)), '-', ''), 20),
                LTRIM(RTRIM(@nombre)), @fecha_nacimiento, 'J');
        SET @id_jugador_entra = SCOPE_IDENTITY();

        UPDATE personas.Participante
        SET dni_cifrado = personas.fn_CifrarDni(LTRIM(RTRIM(@dni)), @id_jugador_entra),
            dni = CAST(@id_jugador_entra AS VARCHAR(20))
        WHERE id_participante = @id_jugador_entra;

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


-- ORIGEN: 15_SP_ImportacionMundial.sql
-- CAMBIOS (importacion.Jugador_Procesar): el jugador existente ya no se busca con "WHERE p.dni = @dni"
--         sino con "WHERE p.id_participante = personas.fn_IdPorDni(@dni)".

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

        -- CAMBIO: la búsqueda por DNI pasa por la función que descifra
        SELECT @id_jugador = p.id_participante, @nombre_actual = p.nombre, @nacimiento_actual = p.fecha_nacimiento,
               @seleccion_actual = j.id_seleccion, @dorsal_actual = j.nro_dorsal, @posicion_actual = j.posicion,
               @club_actual = j.id_club
        FROM personas.Participante p
        JOIN personas.Jugador j ON j.id_participante = p.id_participante
        WHERE p.id_participante = personas.fn_IdPorDni(@dni);

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


-- ORIGEN: 16_SP_ImportacionGoles.sql
-- CAMBIOS (importacion.Gol_Procesar): el autor del gol (player_id = DNI) ya no se busca con "WHERE p.dni = @dni"
--         sino con "WHERE j.id_participante = personas.fn_IdPorDni(@dni)".

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

        -- CAMBIO: la búsqueda por DNI pasa por la función que descifra
        SELECT @id_autor = j.id_participante, @id_seleccion = j.id_seleccion
        FROM personas.Jugador j
        WHERE j.id_participante = personas.fn_IdPorDni(@dni);

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

-- ORIGEN: 17_SP_Scraping.sql
-- CAMBIOS (importacion.Arbitro_Procesar):
--   1) El DNI del árbitro existente (@dni, que se pasa a Arbitro_Modificar) se obtiene con
--      personas.fn_DescifrarDni(...) en lugar de leer p.dni (que ahora guarda el id y no pasaría la
--      validación de 6 caracteres).
--   2) El correlativo se calcula sobre los DNI descifrados de los árbitros

CREATE OR ALTER PROCEDURE importacion.Arbitro_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @nombre VARCHAR(100), @pais_txt VARCHAR(100), @codigo VARCHAR(10), @pais VARCHAR(80), @id_pais INT;
    DECLARE @id_arbitro INT, @pais_actual INT, @fecha_nacimiento DATE, @dni VARCHAR(20);
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    SELECT @id = MIN(id) FROM importacion.ArbitroCarga;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @nombre = NULLIF(LTRIM(RTRIM(nombre)), ''), @pais_txt = NULLIF(LTRIM(RTRIM(pais)), ''),
               @codigo = NULLIF(LTRIM(RTRIM(codigo_pais)), '')
        FROM importacion.ArbitroCarga WHERE id = @id;

        SET @clave = 'ARBITRO ' + ISNULL(@nombre, '(sin nombre)') + ' (' + ISNULL(@pais_txt, ISNULL(@codigo, 'sin país')) + ')';
        SET @errores = '';
        SET @estado = NULL;
        SET @id_arbitro = NULL;

        IF @nombre IS NULL
            SET @errores += 'Falta el nombre del árbitro. ';
        IF @pais_txt IS NULL AND @codigo IS NULL
            SET @errores += 'Falta el país. ';

        IF @errores = ''
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                -- primero por código FIFA (EquivalenciaPais); si no lo conoce, el nombre en español que publica la FIFA
                SET @pais = importacion.fn_PaisLocal(@codigo);
                IF @pais IS NULL OR @pais = @codigo
                    SET @pais = ISNULL(@pais_txt, @codigo);
                SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = @pais);
                IF @id_pais IS NULL
                    EXEC geo.Pais_Insertar @nombre = @pais, @id_pais = @id_pais OUTPUT;

                -- CAMBIO 1: el DNI real sale de la función que descifra
                SELECT @id_arbitro = p.id_participante, @pais_actual = a.id_pais,
                       @dni = personas.fn_DescifrarDni(p.id_participante),
                       @fecha_nacimiento = p.fecha_nacimiento
                FROM personas.Participante p
                JOIN personas.Arbitro a ON a.id_participante = p.id_participante
                WHERE p.nombre = @nombre;

                IF @id_arbitro IS NULL
                BEGIN
                    -- CAMBIO 2: el correlativo se calcula con los DNI descifrados de los árbitros
                    SET @dni = 'REF' + RIGHT('000000' + CAST(ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(d.dni, 4, 10) AS INT))
                                                                     FROM (SELECT personas.fn_DescifrarDni(a.id_participante) AS dni
                                                                           FROM personas.Arbitro a) d
                                                                     WHERE d.dni LIKE 'REF%'), 0) + 1 AS VARCHAR(10)), 6);
                    EXEC personas.Arbitro_Insertar @dni = @dni, @nombre = @nombre, @id_pais = @id_pais,
                                                   @categoria = 'FIFA', @id_participante = @id_arbitro OUTPUT;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @pais_actual <> @id_pais
                BEGIN
                    EXEC personas.Arbitro_Modificar @id_participante = @id_arbitro, @dni = @dni, @nombre = @nombre,
                                                    @fecha_nacimiento = @fecha_nacimiento, @id_pais = @id_pais,
                                                    @categoria = 'FIFA';
                    SET @estado = 'ACTUALIZADO';
                END
                ELSE
                    SET @estado = 'SIN_CAMBIOS';

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM importacion.ArbitroCarga WHERE id > @id;
    END;
END;
GO