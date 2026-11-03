/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : ABM de las tablas que cargan las APIs: publicidad.TipoCambio y publicidad.Feriado. Igual que
                  en la Entrega 5, todo el DML de una tabla vive en sus SP; los SP de importación solo
                  los llaman. Los errores se acumulan en un único mensaje y se lanzan con THROW.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ TIPO DE CAMBIO
CREATE OR ALTER PROCEDURE publicidad.TipoCambio_Insertar
    @moneda_base CHAR(3),
    @moneda CHAR(3),
    @fecha DATE,
    @cotizacion DECIMAL(18,6),
    @id_tipo_cambio INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF @moneda_base IS NULL OR LEN(LTRIM(RTRIM(@moneda_base))) <> 3 OR @moneda IS NULL OR LEN(LTRIM(RTRIM(@moneda))) <> 3
        SET @errores += 'Las monedas se indican con su código de 3 letras. ';
    IF @fecha IS NULL
        SET @errores += 'Falta la fecha. ';
    IF @cotizacion IS NULL OR @cotizacion <= 0
        SET @errores += 'La cotización tiene que ser mayor a cero. ';
    IF EXISTS (SELECT 1 FROM publicidad.TipoCambio WHERE moneda_base = @moneda_base AND moneda = @moneda AND fecha = @fecha)
        SET @errores += 'Ya existe esa cotización para esa fecha. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.TipoCambio (moneda_base, moneda, fecha, cotizacion)
    VALUES (UPPER(LTRIM(RTRIM(@moneda_base))), UPPER(LTRIM(RTRIM(@moneda))), @fecha, @cotizacion);
    SET @id_tipo_cambio = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE publicidad.TipoCambio_Modificar
    @id_tipo_cambio INT,
    @cotizacion DECIMAL(18,6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.TipoCambio WHERE id_tipo_cambio = @id_tipo_cambio)
        SET @errores += 'La cotización no existe. ';
    IF @cotizacion IS NULL OR @cotizacion <= 0
        SET @errores += 'La cotización tiene que ser mayor a cero. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.TipoCambio SET cotizacion = @cotizacion WHERE id_tipo_cambio = @id_tipo_cambio;
END;
GO

-- ------------------------------------------------------------------ FERIADO
CREATE OR ALTER PROCEDURE publicidad.Feriado_Insertar
    @id_pais INT,
    @fecha DATE,
    @nombre VARCHAR(150),
    @id_feriado INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais)
        SET @errores += 'El país no existe. ';
    IF @fecha IS NULL
        SET @errores += 'Falta la fecha. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del feriado. ';
    IF EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_pais = @id_pais AND fecha = @fecha)
        SET @errores += 'Ese país ya tiene un feriado en esa fecha. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    INSERT INTO publicidad.Feriado (id_pais, fecha, nombre) VALUES (@id_pais, @fecha, LTRIM(RTRIM(@nombre)));
    SET @id_feriado = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE publicidad.Feriado_Modificar
    @id_feriado INT,
    @nombre VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_feriado = @id_feriado)
        SET @errores += 'El feriado no existe. ';
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @errores += 'Falta el nombre del feriado. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE publicidad.Feriado SET nombre = LTRIM(RTRIM(@nombre)) WHERE id_feriado = @id_feriado;
END;
GO
