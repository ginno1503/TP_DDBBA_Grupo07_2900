/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Consumir dos APIs públicas, sin clave, y guardar sus datos. Cada API tiene dos SP:
                    *_Procesar   recibe el JSON ya descargado y hace el upsert
                    *_Importar   arma la URL, descarga con importacion.Http_Obtener y llama al anterior

                  1) FRANKFURTER - tipo de cambio (para facturar publicidad en otra moneda)
                       importacion.TipoCambio_ImportarFrankfurter [@base]
                       GET https://api.frankfurter.dev/v1/latest?base=USD
                       Respuesta: {"base":"USD","date":"2026-11-03","rates":{"EUR":0.86,...}}
                       Destino: publicidad.TipoCambio, una fila por moneda y fecha (queda el historial de
                       cotizaciones). Datos del Banco Central Europeo: no incluye ARS. Sin clave ni límite
                       fijo (uso razonable); publica una vez por día hábil.
                  2) NAGER.DATE - feriados públicos por país
                       importacion.Feriado_ImportarNager [@anio]
                       GET https://date.nager.at/api/v3/PublicHolidays/{año}/{ISO2}
                       Respuesta: [ {"date":"2026-07-09","localName":"...","name":"..."}, ... ]
                       Destino: publicidad.Feriado. Una llamada por país del sistema (código ISO2 de
                       EquivalenciaPais); si un país falla se informa y se sigue con los demás. Sin clave ni
                       límite fijo. Países que la API no cubre responden 404 y quedan como ERROR de ese país.

                  Reglas comunes: upsert con las claves moneda+fecha (cotización) y país+fecha (feriado),
                  sin duplicados al repetir; errores de la API o del JSON con THROW (importación FALLIDA);
                  errores de un registro se informan en importacion.Registro y se sigue con los demás.

                  El poder adquisitivo (PBI per cápita) NO se pide a una API: se obtiene por scraping
                  (script 17). No se consumen APIs de huso horario ni de fixtures en vivo: el huso ya está en
                  geo.Pais, geo.Ciudad y EquivalenciaPais, y football-data.org / API-Football exigen clave y
                  limitan el plan gratuito (10 pedidos por minuto).

                  Además dos funciones que usan lo importado:
                    publicidad.fn_ConvertirDesdeUsd   convierte un monto en USD a otra moneda con la
                                                      última cotización disponible a esa fecha
                    publicidad.fn_EsFeriado           indica si una fecha es feriado en un país
                  Requisitos: scripts 00 a 14 ejecutados, 'Ole Automation Procedures' activado (script 10) y
                  salida a Internet desde el servidor.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ 1. FRANKFURTER
CREATE OR ALTER PROCEDURE importacion.TipoCambio_Procesar
    @id_importacion INT,
    @json VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @base CHAR(3), @fecha DATE, @id INT, @moneda CHAR(3), @cotizacion DECIMAL(18,6);
    DECLARE @id_tipo_cambio INT, @cotizacion_actual DECIMAL(18,6), @clave VARCHAR(200);
    DECLARE @estado VARCHAR(12), @errores VARCHAR(2000);

    IF @json IS NULL OR ISJSON(@json) = 0
        THROW 50001, 'La respuesta de Frankfurter no es un JSON válido. ', 1;

    SET @base = JSON_VALUE(@json, '$.base');
    SET @fecha = TRY_CAST(JSON_VALUE(@json, '$.date') AS DATE);
    IF @base IS NULL OR @fecha IS NULL
        THROW 50001, 'La respuesta de Frankfurter no trae la moneda base o la fecha. ', 1;

    CREATE TABLE #tc (id INT IDENTITY(1,1), moneda VARCHAR(10), cotizacion VARCHAR(50));
    INSERT INTO #tc (moneda, cotizacion) SELECT [key], [value] FROM OPENJSON(@json, '$.rates');

    IF NOT EXISTS (SELECT 1 FROM #tc)
        THROW 50001, 'La respuesta de Frankfurter no trae cotizaciones. ', 1;

    SELECT @id = MIN(id) FROM #tc;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @moneda = moneda, @cotizacion = TRY_CAST(cotizacion AS DECIMAL(18,6)) FROM #tc WHERE id = @id;

        SET @clave = @base + '/' + @moneda + ' ' + CONVERT(CHAR(10), @fecha, 23);
        SET @errores = '';
        SET @estado = NULL;
        SET @id_tipo_cambio = NULL;

        IF @cotizacion IS NULL
            SET @errores += 'La cotización no es un número. ';
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @id_tipo_cambio = id_tipo_cambio, @cotizacion_actual = cotizacion
                FROM publicidad.TipoCambio WHERE moneda_base = @base AND moneda = @moneda AND fecha = @fecha;

                IF @id_tipo_cambio IS NULL
                BEGIN
                    EXEC publicidad.TipoCambio_Insertar @moneda_base = @base, @moneda = @moneda, @fecha = @fecha,
                                                        @cotizacion = @cotizacion, @id_tipo_cambio = @id_tipo_cambio OUTPUT;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @cotizacion_actual <> @cotizacion
                BEGIN
                    EXEC publicidad.TipoCambio_Modificar @id_tipo_cambio = @id_tipo_cambio, @cotizacion = @cotizacion;
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

        SELECT @id = MIN(id) FROM #tc WHERE id > @id;
    END;
END;
GO

CREATE OR ALTER PROCEDURE importacion.TipoCambio_ImportarFrankfurter
    @base CHAR(3) = 'USD'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_importacion INT, @json VARCHAR(MAX);
    DECLARE @url VARCHAR(1000) = 'https://api.frankfurter.dev/v1/latest?base=' + @base;

    EXEC importacion.Importacion_Iniciar @archivo = @url, @formato = 'API', @id_importacion = @id_importacion OUTPUT;
    BEGIN TRY
        EXEC importacion.Http_Obtener @url = @url, @respuesta = @json OUTPUT;
        EXEC importacion.TipoCambio_Procesar @id_importacion = @id_importacion, @json = @json;
        EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    END TRY
    BEGIN CATCH
        EXEC importacion.Importacion_Fallar @id_importacion = @id_importacion;
        THROW;
    END CATCH;

    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
END;
GO

-- ------------------------------------------------------------------ 2. NAGER.DATE
-- Procesa el JSON de feriados de UN país
CREATE OR ALTER PROCEDURE importacion.Feriado_Procesar
    @id_importacion INT,
    @id_pais INT,
    @json VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @pais VARCHAR(80), @id INT, @fecha DATE, @nombre VARCHAR(150), @fecha_txt VARCHAR(20);
    DECLARE @id_feriado INT, @nombre_actual VARCHAR(150), @clave VARCHAR(200);
    DECLARE @estado VARCHAR(12), @errores VARCHAR(2000);

    IF @json IS NULL OR ISJSON(@json) = 0
        THROW 50001, 'La respuesta de Nager.Date no es un JSON válido. ', 1;

    SELECT @pais = nombre FROM geo.Pais WHERE id_pais = @id_pais;

    CREATE TABLE #feriado (id INT IDENTITY(1,1), fecha VARCHAR(20), nombre VARCHAR(150));
    INSERT INTO #feriado (fecha, nombre)
    SELECT fecha, COALESCE(NULLIF(local_name, ''), nombre_ingles)
    FROM OPENJSON(@json)
         WITH (fecha VARCHAR(20) '$.date', local_name VARCHAR(150) '$.localName', nombre_ingles VARCHAR(150) '$.name');

    SELECT @id = MIN(id) FROM #feriado;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @fecha_txt = fecha, @nombre = nombre, @fecha = TRY_CAST(fecha AS DATE) FROM #feriado WHERE id = @id;

        SET @clave = @pais + ' ' + ISNULL(@fecha_txt, '(sin fecha)');
        SET @errores = '';
        SET @estado = NULL;
        SET @id_feriado = NULL;

        IF @fecha IS NULL
            SET @errores += 'La fecha no es válida. ';
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @id_feriado = id_feriado, @nombre_actual = nombre FROM publicidad.Feriado WHERE id_pais = @id_pais AND fecha = @fecha;

                IF @id_feriado IS NULL
                BEGIN
                    EXEC publicidad.Feriado_Insertar @id_pais = @id_pais, @fecha = @fecha, @nombre = @nombre, @id_feriado = @id_feriado OUTPUT;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @nombre_actual <> @nombre
                BEGIN
                    EXEC publicidad.Feriado_Modificar @id_feriado = @id_feriado, @nombre = @nombre;
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

        SELECT @id = MIN(id) FROM #feriado WHERE id > @id;
    END;
END;
GO

-- Recorre los países del sistema y trae los feriados del año indicado (por defecto el año actual)
CREATE OR ALTER PROCEDURE importacion.Feriado_ImportarNager
    @anio INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_importacion INT, @id_pais INT, @nombre VARCHAR(80), @iso2 CHAR(2), @url VARCHAR(1000), @json VARCHAR(MAX);

    IF @anio IS NULL SET @anio = YEAR(GETDATE());

    EXEC importacion.Importacion_Iniciar @archivo = 'https://date.nager.at/api/v3/PublicHolidays', @formato = 'API', @id_importacion = @id_importacion OUTPUT;
    BEGIN TRY
        SELECT @id_pais = MIN(id_pais) FROM geo.Pais;
        WHILE @id_pais IS NOT NULL
        BEGIN
            SELECT @nombre = nombre FROM geo.Pais WHERE id_pais = @id_pais;
            SET @iso2 = NULL;
            SELECT TOP 1 @iso2 = codigo_iso2 FROM importacion.EquivalenciaPais WHERE nombre_pais = @nombre AND codigo_iso2 IS NOT NULL;

            IF @iso2 IS NULL
                INSERT INTO importacion.Registro (id_importacion, clave, estado, mensaje)
                VALUES (@id_importacion, @nombre, 'ERROR', 'El país no tiene código ISO2 en importacion.EquivalenciaPais. ');
            ELSE
            BEGIN
                BEGIN TRY
                    SET @url = 'https://date.nager.at/api/v3/PublicHolidays/' + CAST(@anio AS VARCHAR(4)) + '/' + @iso2;
                    EXEC importacion.Http_Obtener @url = @url, @respuesta = @json OUTPUT;
                    EXEC importacion.Feriado_Procesar @id_importacion = @id_importacion, @id_pais = @id_pais, @json = @json;
                END TRY
                BEGIN CATCH
                    INSERT INTO importacion.Registro (id_importacion, clave, estado, mensaje)
                    VALUES (@id_importacion, @nombre, 'ERROR', ERROR_MESSAGE());
                END CATCH;
            END;

            SELECT @id_pais = MIN(id_pais) FROM geo.Pais WHERE id_pais > @id_pais;
        END;
        EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    END TRY
    BEGIN CATCH
        EXEC importacion.Importacion_Fallar @id_importacion = @id_importacion;
        THROW;
    END CATCH;

    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
END;
GO

-- ------------------------------------------------------------------ FUNCIONES QUE USAN LO IMPORTADO
-- Convierte un monto en USD a @moneda con la última cotización disponible hasta @fecha (NULL si no hay)
CREATE OR ALTER FUNCTION publicidad.fn_ConvertirDesdeUsd (@monto DECIMAL(18,2), @moneda CHAR(3), @fecha DATE)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @cotizacion DECIMAL(18,6);

    IF @moneda = 'USD'
        RETURN @monto;

    SELECT TOP 1 @cotizacion = cotizacion
    FROM publicidad.TipoCambio
    WHERE moneda_base = 'USD' AND moneda = @moneda AND fecha <= @fecha
    ORDER BY fecha DESC;

    RETURN @monto * @cotizacion;
END;
GO

-- 1 si la fecha es feriado en el país (para saber si un partido cae en feriado del mercado destino)
CREATE OR ALTER FUNCTION publicidad.fn_EsFeriado (@id_pais INT, @fecha DATE)
RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_pais = @id_pais AND fecha = @fecha) THEN 1 ELSE 0 END;
END;
GO
