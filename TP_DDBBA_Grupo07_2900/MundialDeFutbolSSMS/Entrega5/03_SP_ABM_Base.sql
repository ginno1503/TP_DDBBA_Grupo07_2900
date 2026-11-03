/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Alta, modificación y baja de idioma, país, ciudad, selección, sede, club y parámetro.
                  Nombres: <esquema>.<Entidad>_Insertar / _Modificar / _Eliminar. Cada procedimiento junta
                  todas las validaciones que fallan en un único mensaje.
   ============================================================================= */

USE MundialFutbol;
GO
-------------------------------------- IDIOMA
CREATE OR ALTER PROCEDURE geo.Idioma_Insertar
    @nombre VARCHAR(50),
    @id_idioma INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del idioma. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Idioma WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @errores += 'Ya existe un idioma con ese nombre. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO geo.Idioma (nombre) VALUES (LTRIM(RTRIM(@nombre)));
    SET @id_idioma = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE geo.Idioma_Modificar
    @id_idioma INT,
    @nombre VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE id_idioma = @id_idioma)
        SET @errores += 'El idioma no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del idioma. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Idioma WHERE nombre = LTRIM(RTRIM(@nombre)) AND id_idioma <> @id_idioma)
        SET @errores += 'Ya existe otro idioma con ese nombre. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE geo.Idioma SET nombre = LTRIM(RTRIM(@nombre)) WHERE id_idioma = @id_idioma;
END;
GO

CREATE OR ALTER PROCEDURE geo.Idioma_Eliminar
    @id_idioma INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE id_idioma = @id_idioma)
        SET @errores += 'El idioma no existe. ';
    IF EXISTS (SELECT 1 FROM personas.ArbitroIdioma WHERE id_idioma = @id_idioma)
        SET @errores += 'Hay árbitros que hablan ese idioma. ';
    IF EXISTS (SELECT 1 FROM publicidad.Contenido WHERE id_idioma = @id_idioma)
        SET @errores += 'Hay contenidos publicitarios en ese idioma. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM geo.Idioma WHERE id_idioma = @id_idioma;
END;
GO

-- --------------------------------------------------------PAIS
CREATE OR ALTER PROCEDURE geo.Pais_Insertar
    @nombre VARCHAR(80),
    @huso_horario DECIMAL(4,2) = NULL,
    @pbi_per_capita DECIMAL(12,2) = NULL,
    @id_pais INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del país. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @errores += 'Ya existe un país con ese nombre. ';
    IF @huso_horario < -12 OR @huso_horario > 14
        SET @errores += 'El huso horario debe estar entre -12 y 14. ';
    IF @pbi_per_capita < 0
        SET @errores += 'El PBI per cápita no puede ser negativo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO geo.Pais (nombre, huso_horario, pbi_per_capita)
    VALUES (LTRIM(RTRIM(@nombre)), @huso_horario, @pbi_per_capita);
    SET @id_pais = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE geo.Pais_Modificar
    @id_pais INT,
    @nombre VARCHAR(80),
    @huso_horario DECIMAL(4,2) = NULL,
    @pbi_per_capita DECIMAL(12,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del país. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = LTRIM(RTRIM(@nombre)) AND id_pais <> @id_pais)
        SET @errores += 'Ya existe otro país con ese nombre. ';
    IF @huso_horario < -12 OR @huso_horario > 14
        SET @errores += 'El huso horario debe estar entre -12 y 14. ';
    IF @pbi_per_capita < 0
        SET @errores += 'El PBI per cápita no puede ser negativo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE geo.Pais
    SET nombre = LTRIM(RTRIM(@nombre)), huso_horario = @huso_horario, pbi_per_capita = @pbi_per_capita
    WHERE id_pais = @id_pais;
END;
GO

CREATE OR ALTER PROCEDURE geo.Pais_Eliminar
    @id_pais INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF EXISTS (SELECT 1 FROM geo.Ciudad WHERE id_pais = @id_pais)
        SET @errores += 'El país tiene ciudades cargadas. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @id_pais)
        SET @errores += 'El país tiene una selección. ';
    IF EXISTS (SELECT 1 FROM personas.Arbitro WHERE id_pais = @id_pais)
        SET @errores += 'Hay árbitros de ese país. ';
    IF EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE id_pais = @id_pais)
        SET @errores += 'Hay contenidos publicitarios dirigidos a ese país. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM geo.Pais WHERE id_pais = @id_pais;
END;
GO

-- ---------------------------------------------------------CIUDAD
CREATE OR ALTER PROCEDURE geo.Ciudad_Insertar
    @id_pais INT,
    @nombre VARCHAR(80),
    @huso_horario DECIMAL(4,2),
    @id_ciudad INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre de la ciudad. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Ciudad WHERE id_pais = @id_pais AND nombre = LTRIM(RTRIM(@nombre)))
        SET @errores += 'Ese país ya tiene una ciudad con ese nombre. ';
    IF @huso_horario IS NULL OR @huso_horario < -12 OR @huso_horario > 14
        SET @errores += 'El huso horario es obligatorio y debe estar entre -12 y 14. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO geo.Ciudad (id_pais, nombre, huso_horario)
    VALUES (@id_pais, LTRIM(RTRIM(@nombre)), @huso_horario);
    SET @id_ciudad = SCOPE_IDENTITY();
END;
GO

-- Si cambia el huso hay que recalcular la hora UTC de los partidos que se juegan en esa ciudad.
CREATE OR ALTER PROCEDURE geo.Ciudad_Modificar
    @id_ciudad INT,
    @id_pais INT,
    @nombre VARCHAR(80),
    @huso_horario DECIMAL(4,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Ciudad WHERE id_ciudad = @id_ciudad)
        SET @errores += 'La ciudad no existe. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre de la ciudad. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Ciudad
                                       WHERE id_pais = @id_pais AND nombre = LTRIM(RTRIM(@nombre)) AND id_ciudad <> @id_ciudad)
        SET @errores += 'Ese país ya tiene otra ciudad con ese nombre. ';
    IF @huso_horario IS NULL OR @huso_horario < -12 OR @huso_horario > 14
        SET @errores += 'El huso horario es obligatorio y debe estar entre -12 y 14. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE geo.Ciudad
        SET id_pais = @id_pais, nombre = LTRIM(RTRIM(@nombre)), huso_horario = @huso_horario
        WHERE id_ciudad = @id_ciudad;

        UPDATE p
        SET fecha_hora_utc = torneo.fn_UtcPartido(p.fecha, p.horario, p.id_sede)
        FROM torneo.Partido p
        JOIN torneo.Sede s ON s.id_sede = p.id_sede
        WHERE s.id_ciudad = @id_ciudad;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE geo.Ciudad_Eliminar
    @id_ciudad INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Ciudad WHERE id_ciudad = @id_ciudad)
        SET @errores += 'La ciudad no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.Sede WHERE id_ciudad = @id_ciudad)
        SET @errores += 'La ciudad tiene sedes cargadas. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM geo.Ciudad WHERE id_ciudad = @id_ciudad;
END;
GO

-- ------------------------------------------------------SELECCION
CREATE OR ALTER PROCEDURE torneo.Seleccion_Insertar
    @id_pais INT,
    @confederacion VARCHAR(10),
    @grupo CHAR(1) = NULL,
    @id_seleccion INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @id_pais)
        SET @errores += 'Ese país ya tiene una selección. ';
    IF @confederacion IS NULL OR @confederacion NOT IN ('UEFA', 'CONMEBOL', 'CONCACAF', 'CAF', 'AFC', 'OFC')
        SET @errores += 'La confederación no es válida. ';
    IF @grupo IS NOT NULL AND @grupo NOT LIKE '[A-L]'
        SET @errores += 'El grupo debe ser una letra de la A a la L. ';
    IF @grupo IS NOT NULL AND (SELECT COUNT(*) FROM torneo.Seleccion WHERE grupo = @grupo) >= 4
        SET @errores += 'El grupo ya tiene 4 selecciones. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Seleccion (id_pais, confederacion, grupo) VALUES (@id_pais, @confederacion, @grupo);
    SET @id_seleccion = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE torneo.Seleccion_Modificar
    @id_seleccion INT,
    @id_pais INT,
    @confederacion VARCHAR(10),
    @grupo CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @id_pais AND id_seleccion <> @id_seleccion)
        SET @errores += 'Ese país ya tiene otra selección. ';
    IF @confederacion IS NULL OR @confederacion NOT IN ('UEFA', 'CONMEBOL', 'CONCACAF', 'CAF', 'AFC', 'OFC')
        SET @errores += 'La confederación no es válida. ';
    IF @grupo IS NOT NULL AND @grupo NOT LIKE '[A-L]'
        SET @errores += 'El grupo debe ser una letra de la A a la L. ';
    IF @grupo IS NOT NULL AND (SELECT COUNT(*) FROM torneo.Seleccion WHERE grupo = @grupo AND id_seleccion <> @id_seleccion) >= 4
        SET @errores += 'El grupo ya tiene 4 selecciones. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Seleccion
    SET id_pais = @id_pais, confederacion = @confederacion, grupo = @grupo
    WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Seleccion_Eliminar
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección no existe. ';
    IF EXISTS (SELECT 1 FROM personas.Jugador WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección tiene jugadores. ';
    IF EXISTS (SELECT 1 FROM personas.DirectorTecnico WHERE id_seleccion = @id_seleccion)
       OR EXISTS (SELECT 1 FROM personas.Ayudante WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección tiene cuerpo técnico. ';
    IF EXISTS (SELECT 1 FROM torneo.Formacion WHERE id_seleccion = @id_seleccion)
        SET @errores += 'La selección tiene formaciones. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_seleccion_1 = @id_seleccion OR id_seleccion_2 = @id_seleccion)
        SET @errores += 'La selección figura en partidos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

-- ------------------------------------------------------------------ SEDE
CREATE OR ALTER PROCEDURE torneo.Sede_Insertar
    @id_ciudad INT,
    @nombre_estadio VARCHAR(100),
    @capacidad INT,
    @id_sede INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Ciudad WHERE id_ciudad = @id_ciudad)
        SET @errores += 'La ciudad no existe. ';
    IF @nombre_estadio IS NULL OR LTRIM(RTRIM(@nombre_estadio)) = ''
        SET @errores += 'Falta el nombre del estadio. ';
    IF @nombre_estadio IS NOT NULL AND EXISTS (SELECT 1 FROM torneo.Sede
                                               WHERE id_ciudad = @id_ciudad AND nombre_estadio = LTRIM(RTRIM(@nombre_estadio)))
        SET @errores += 'Esa ciudad ya tiene un estadio con ese nombre. ';
    IF @capacidad IS NULL OR @capacidad <= 0
        SET @errores += 'La capacidad debe ser mayor a cero. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Sede (id_ciudad, nombre_estadio, capacidad)
    VALUES (@id_ciudad, LTRIM(RTRIM(@nombre_estadio)), @capacidad);
    SET @id_sede = SCOPE_IDENTITY();
END;
GO

-- Si la sede cambia de ciudad cambia el huso, así que se recalcula la hora UTC de sus partidos.
CREATE OR ALTER PROCEDURE torneo.Sede_Modificar
    @id_sede INT,
    @id_ciudad INT,
    @nombre_estadio VARCHAR(100),
    @capacidad INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Sede WHERE id_sede = @id_sede)
        SET @errores += 'La sede no existe. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Ciudad WHERE id_ciudad = @id_ciudad)
        SET @errores += 'La ciudad no existe. ';
    IF @nombre_estadio IS NULL OR LTRIM(RTRIM(@nombre_estadio)) = ''
        SET @errores += 'Falta el nombre del estadio. ';
    IF @nombre_estadio IS NOT NULL AND EXISTS (SELECT 1 FROM torneo.Sede
                                               WHERE id_ciudad = @id_ciudad AND nombre_estadio = LTRIM(RTRIM(@nombre_estadio))
                                                 AND id_sede <> @id_sede)
        SET @errores += 'Esa ciudad ya tiene otro estadio con ese nombre. ';
    IF @capacidad IS NULL OR @capacidad <= 0
        SET @errores += 'La capacidad debe ser mayor a cero. ';
    IF @capacidad > 0 AND EXISTS (SELECT 1 FROM torneo.Partido WHERE id_sede = @id_sede AND asistencia > @capacidad)
        SET @errores += 'Hay partidos con una asistencia mayor a la nueva capacidad. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE torneo.Sede
        SET id_ciudad = @id_ciudad, nombre_estadio = LTRIM(RTRIM(@nombre_estadio)), capacidad = @capacidad
        WHERE id_sede = @id_sede;

        UPDATE torneo.Partido
        SET fecha_hora_utc = torneo.fn_UtcPartido(fecha, horario, id_sede)
        WHERE id_sede = @id_sede;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Sede_Eliminar
    @id_sede INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Sede WHERE id_sede = @id_sede)
        SET @errores += 'La sede no existe. ';
    IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_sede = @id_sede)
        SET @errores += 'La sede tiene partidos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Sede WHERE id_sede = @id_sede;
END;
GO

-- -----------------------------------------------------CLUB
CREATE OR ALTER PROCEDURE personas.Club_Insertar
    @nombre VARCHAR(100),
    @id_club INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del club. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Club WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @errores += 'Ya existe un club con ese nombre. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO personas.Club (nombre) VALUES (LTRIM(RTRIM(@nombre)));
    SET @id_club = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE personas.Club_Modificar
    @id_club INT,
    @nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Club WHERE id_club = @id_club)
        SET @errores += 'El club no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del club. ';
    IF @nombre IS NOT NULL AND EXISTS (SELECT 1 FROM personas.Club WHERE nombre = LTRIM(RTRIM(@nombre)) AND id_club <> @id_club)
        SET @errores += 'Ya existe otro club con ese nombre. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE personas.Club SET nombre = LTRIM(RTRIM(@nombre)) WHERE id_club = @id_club;
END;
GO

CREATE OR ALTER PROCEDURE personas.Club_Eliminar
    @id_club INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM personas.Club WHERE id_club = @id_club)
        SET @errores += 'El club no existe. ';
    IF EXISTS (SELECT 1 FROM personas.Jugador WHERE id_club = @id_club)
        SET @errores += 'El club tiene jugadores. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM personas.Club WHERE id_club = @id_club;
END;
GO

-- -----------------------------------------------------PARAMETRO
CREATE OR ALTER PROCEDURE torneo.Parametro_Insertar
    @clave VARCHAR(40),
    @valor INT,
    @descripcion VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @clave IS NULL OR LTRIM(RTRIM(@clave)) = ''
        SET @errores += 'Falta la clave del parámetro. ';
    IF @clave IS NOT NULL AND EXISTS (SELECT 1 FROM torneo.Parametro WHERE clave = LTRIM(RTRIM(@clave)))
        SET @errores += 'Ya existe un parámetro con esa clave. ';
    IF @valor IS NULL OR @valor < 0
        SET @errores += 'El valor es obligatorio y no puede ser negativo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO torneo.Parametro (clave, valor, descripcion) VALUES (LTRIM(RTRIM(@clave)), @valor, @descripcion);
END;
GO

CREATE OR ALTER PROCEDURE torneo.Parametro_Modificar
    @clave VARCHAR(40),
    @valor INT,
    @descripcion VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Parametro WHERE clave = @clave)
        SET @errores += 'El parámetro no existe. ';
    IF @valor IS NULL OR @valor < 0
        SET @errores += 'El valor es obligatorio y no puede ser negativo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.Parametro SET valor = @valor, descripcion = @descripcion WHERE clave = @clave;
END;
GO

CREATE OR ALTER PROCEDURE torneo.Parametro_Eliminar
    @clave VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Parametro WHERE clave = @clave)
        SET @errores += 'El parámetro no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM torneo.Parametro WHERE clave = @clave;
END;
GO
