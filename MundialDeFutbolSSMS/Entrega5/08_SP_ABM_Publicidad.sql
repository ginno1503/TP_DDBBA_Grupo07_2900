/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Alta, modificación y baja de anunciante, campaña, contenido, países objetivo del
                  contenido, tarifa y espacio publicitario de un partido.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ ANUNCIANTE
CREATE OR ALTER PROCEDURE publicidad.Anunciante_Insertar
    @nombre VARCHAR(100),
    @razon_social VARCHAR(150),
    @id_anunciante INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del anunciante. ';
    IF @razon_social IS NULL OR LTRIM(RTRIM(@razon_social)) = ''
        SET @errores += 'Falta la razón social. ';
    IF @razon_social IS NOT NULL AND EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = LTRIM(RTRIM(@razon_social)))
        SET @errores += 'Ya existe un anunciante con esa razón social. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.Anunciante (nombre, razon_social) VALUES (LTRIM(RTRIM(@nombre)), LTRIM(RTRIM(@razon_social)));
    SET @id_anunciante = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Anunciante_Modificar
    @id_anunciante INT,
    @nombre VARCHAR(100),
    @razon_social VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE id_anunciante = @id_anunciante)
        SET @errores += 'El anunciante no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del anunciante. ';
    IF @razon_social IS NULL OR LTRIM(RTRIM(@razon_social)) = ''
        SET @errores += 'Falta la razón social. ';
    IF @razon_social IS NOT NULL AND EXISTS (SELECT 1 FROM publicidad.Anunciante
                                             WHERE razon_social = LTRIM(RTRIM(@razon_social)) AND id_anunciante <> @id_anunciante)
        SET @errores += 'Ya existe otro anunciante con esa razón social. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.Anunciante
    SET nombre = LTRIM(RTRIM(@nombre)), razon_social = LTRIM(RTRIM(@razon_social))
    WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Anunciante_Eliminar
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE id_anunciante = @id_anunciante)
        SET @errores += 'El anunciante no existe. ';
    IF EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anunciante)
        SET @errores += 'El anunciante tiene campañas cargadas. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM publicidad.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

-- ------------------------------------------------------------------ CAMPANIA
CREATE OR ALTER PROCEDURE publicidad.Campania_Insertar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE id_anunciante = @id_anunciante)
        SET @errores += 'El anunciante no existe. ';
    IF @cod_campania IS NULL OR LTRIM(RTRIM(@cod_campania)) = ''
        SET @errores += 'Falta el código de la campaña. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre de la campaña. ';
    IF EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anunciante AND cod_campania = LTRIM(RTRIM(@cod_campania)))
        SET @errores += 'El anunciante ya tiene una campaña con ese código. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.Campania (id_anunciante, cod_campania, nombre)
    VALUES (@id_anunciante, LTRIM(RTRIM(@cod_campania)), LTRIM(RTRIM(@nombre)));
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Campania_Modificar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania)
        SET @errores += 'La campaña no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre de la campaña. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.Campania SET nombre = LTRIM(RTRIM(@nombre))
    WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Campania_Eliminar
    @id_anunciante INT,
    @cod_campania VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania)
        SET @errores += 'La campaña no existe. ';
    IF EXISTS (SELECT 1 FROM publicidad.Contenido WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania)
        SET @errores += 'La campaña tiene contenidos cargados. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM publicidad.Campania WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania;
END;
GO

-- ------------------------------------------------------------------ CONTENIDO
CREATE OR ALTER PROCEDURE publicidad.Contenido_Insertar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @cod_contenido VARCHAR(20),
    @nombre VARCHAR(100),
    @id_idioma INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania)
        SET @errores += 'La campaña no existe. ';
    IF @cod_contenido IS NULL OR LTRIM(RTRIM(@cod_contenido)) = ''
        SET @errores += 'Falta el código del contenido. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del contenido. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE id_idioma = @id_idioma)
        SET @errores += 'El idioma no existe. ';
    IF EXISTS (SELECT 1 FROM publicidad.Contenido
               WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = LTRIM(RTRIM(@cod_contenido)))
        SET @errores += 'La campaña ya tiene un contenido con ese código. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.Contenido (id_anunciante, cod_campania, cod_contenido, nombre, id_idioma)
    VALUES (@id_anunciante, @cod_campania, LTRIM(RTRIM(@cod_contenido)), LTRIM(RTRIM(@nombre)), @id_idioma);
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Contenido_Modificar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @cod_contenido VARCHAR(20),
    @nombre VARCHAR(100),
    @id_idioma INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido
                   WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del contenido. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE id_idioma = @id_idioma)
        SET @errores += 'El idioma no existe. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.Contenido SET nombre = LTRIM(RTRIM(@nombre)), id_idioma = @id_idioma
    WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido;
END;
GO

-- Los países objetivo se borran con el contenido, pero si ya se exhibió en un partido no se puede eliminar.
CREATE OR ALTER PROCEDURE publicidad.Contenido_Eliminar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @cod_contenido VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido
                   WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido no existe. ';
    IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario
               WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido está asignado a espacios publicitarios de partidos. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DELETE FROM publicidad.ContenidoPais
        WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido;
        DELETE FROM publicidad.Contenido
        WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ PAISES OBJETIVO DEL CONTENIDO
CREATE OR ALTER PROCEDURE publicidad.ContenidoPais_Insertar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @cod_contenido VARCHAR(20),
    @id_pais INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido
                   WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido no existe. ';
    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF EXISTS (SELECT 1 FROM publicidad.ContenidoPais
               WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania
                 AND cod_contenido = @cod_contenido AND id_pais = @id_pais)
        SET @errores += 'El contenido ya está dirigido a ese país. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.ContenidoPais (id_anunciante, cod_campania, cod_contenido, id_pais)
    VALUES (@id_anunciante, @cod_campania, @cod_contenido, @id_pais);
END;
GO

CREATE OR ALTER PROCEDURE publicidad.ContenidoPais_Eliminar
    @id_anunciante INT,
    @cod_campania VARCHAR(20),
    @cod_contenido VARCHAR(20),
    @id_pais INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais
                   WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania
                     AND cod_contenido = @cod_contenido AND id_pais = @id_pais)
        THROW 50001, 'El contenido no está dirigido a ese país. ', 1;

    DELETE FROM publicidad.ContenidoPais
    WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania
      AND cod_contenido = @cod_contenido AND id_pais = @id_pais;
END;
GO

-- ------------------------------------------------------------------ TARIFA
CREATE OR ALTER PROCEDURE publicidad.Tarifa_Insertar
    @franja VARCHAR(40),
    @costo DECIMAL(12,2),
    @id_tarifa INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @franja IS NULL OR LTRIM(RTRIM(@franja)) = ''
        SET @errores += 'Falta la franja. ';
    IF @franja IS NOT NULL AND EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE franja = LTRIM(RTRIM(@franja)))
        SET @errores += 'Ya existe una tarifa para esa franja. ';
    IF @costo IS NULL OR @costo < 0
        SET @errores += 'El costo es obligatorio y no puede ser negativo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.Tarifa (franja, costo) VALUES (LTRIM(RTRIM(@franja)), @costo);
    SET @id_tarifa = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Tarifa_Modificar
    @id_tarifa INT,
    @franja VARCHAR(40),
    @costo DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa)
        SET @errores += 'La tarifa no existe. ';
    IF @franja IS NULL OR LTRIM(RTRIM(@franja)) = ''
        SET @errores += 'Falta la franja. ';
    IF @franja IS NOT NULL AND EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE franja = LTRIM(RTRIM(@franja)) AND id_tarifa <> @id_tarifa)
        SET @errores += 'Ya existe otra tarifa para esa franja. ';
    IF @costo IS NULL OR @costo < 0
        SET @errores += 'El costo es obligatorio y no puede ser negativo. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.Tarifa SET franja = LTRIM(RTRIM(@franja)), costo = @costo WHERE id_tarifa = @id_tarifa;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Tarifa_Eliminar
    @id_tarifa INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa)
        SET @errores += 'La tarifa no existe. ';
    IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_tarifa = @id_tarifa)
        SET @errores += 'La tarifa está usada en espacios publicitarios. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    DELETE FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa;
END;
GO

-- ------------------------------------------------------------------ ESPACIO PUBLICITARIO
-- Cada partido tiene 4 espacios (nro 1 a 4). El contenido puede quedar sin asignar.
CREATE OR ALTER PROCEDURE publicidad.EspacioPublicitario_Insertar
    @id_partido INT,
    @nro TINYINT,
    @id_tarifa INT,
    @horario DATETIME2(0),
    @id_anunciante INT = NULL,
    @cod_campania VARCHAR(20) = NULL,
    @cod_contenido VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_partido)
        SET @errores += 'El partido no existe. ';
    IF @nro IS NULL OR @nro NOT BETWEEN 1 AND 4
        SET @errores += 'El número de espacio debe estar entre 1 y 4. ';
    IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'Ese espacio ya existe en el partido. ';
    IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa)
        SET @errores += 'La tarifa no existe. ';
    IF @horario IS NULL
        SET @errores += 'Falta el horario de emisión. ';
    IF (@id_anunciante IS NULL OR @cod_campania IS NULL OR @cod_contenido IS NULL)
       AND (@id_anunciante IS NOT NULL OR @cod_campania IS NOT NULL OR @cod_contenido IS NOT NULL)
        SET @errores += 'El contenido se identifica con anunciante, campaña y código: faltan datos. ';
    IF @id_anunciante IS NOT NULL AND @cod_campania IS NOT NULL AND @cod_contenido IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM publicidad.Contenido
                       WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido no existe. ';
    IF @id_anunciante IS NOT NULL AND EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario
                                              WHERE id_partido = @id_partido AND id_anunciante = @id_anunciante
                                                AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido ya está en otro espacio de ese partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.EspacioPublicitario (id_partido, nro, id_tarifa, horario, id_anunciante, cod_campania, cod_contenido)
    VALUES (@id_partido, @nro, @id_tarifa, @horario, @id_anunciante, @cod_campania, @cod_contenido);
END;
GO

CREATE OR ALTER PROCEDURE publicidad.EspacioPublicitario_Modificar
    @id_partido INT,
    @nro TINYINT,
    @id_tarifa INT,
    @horario DATETIME2(0),
    @id_anunciante INT = NULL,
    @cod_campania VARCHAR(20) = NULL,
    @cod_contenido VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = @nro)
        SET @errores += 'El espacio no existe. ';
    IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa)
        SET @errores += 'La tarifa no existe. ';
    IF @horario IS NULL
        SET @errores += 'Falta el horario de emisión. ';
    IF (@id_anunciante IS NULL OR @cod_campania IS NULL OR @cod_contenido IS NULL)
       AND (@id_anunciante IS NOT NULL OR @cod_campania IS NOT NULL OR @cod_contenido IS NOT NULL)
        SET @errores += 'El contenido se identifica con anunciante, campaña y código: faltan datos. ';
    IF @id_anunciante IS NOT NULL AND @cod_campania IS NOT NULL AND @cod_contenido IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM publicidad.Contenido
                       WHERE id_anunciante = @id_anunciante AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido no existe. ';
    IF @id_anunciante IS NOT NULL AND EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario
                                              WHERE id_partido = @id_partido AND nro <> @nro AND id_anunciante = @id_anunciante
                                                AND cod_campania = @cod_campania AND cod_contenido = @cod_contenido)
        SET @errores += 'El contenido ya está en otro espacio de ese partido. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.EspacioPublicitario
    SET id_tarifa = @id_tarifa, horario = @horario,
        id_anunciante = @id_anunciante, cod_campania = @cod_campania, cod_contenido = @cod_contenido
    WHERE id_partido = @id_partido AND nro = @nro;
END;
GO

CREATE OR ALTER PROCEDURE publicidad.EspacioPublicitario_Eliminar
    @id_partido INT,
    @nro TINYINT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = @nro)
        THROW 50001, 'El espacio no existe. ', 1;

    DELETE FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = @nro;
END;
GO
