/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Piezas comunes de las importaciones de la Entrega 6:

                  Pedido HTTP
                    importacion.Http_Obtener       GET de una URL; devuelve el texto de la respuesta
                  Bitácora (importacion.Importacion y importacion.Registro)
                    importacion.Importacion_Iniciar / _Cerrar / _Fallar / Registro_Agregar / Resultado_Mostrar
                  Países
                    importacion.fn_PaisLocal       traduce un país de una fuente externa al nombre del sistema
                  Scraping de tablas HTML
                    importacion.fn_QuitarHtml      deja solo el texto de un fragmento HTML
                    importacion.fn_CeldaHtml       texto de la n-ésima celda (td/th) de una fila <tr>

                  Pedido HTTP: T-SQL no trae un cliente HTTP, la forma estándar es crear el objeto COM
                  MSXML2.ServerXMLHTTP.6.0 con sp_OACreate (requiere 'Ole Automation Procedures', script 10).
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ PAÍSES
-- Nombre que tiene en el sistema un país de una fuente externa (nombre en inglés o código FIFA), según
-- importacion.EquivalenciaPais. Si la tabla no lo conoce se devuelve el mismo texto: el país se crea
-- con el nombre en inglés en lugar de perder el registro.
CREATE OR ALTER FUNCTION importacion.fn_PaisLocal (@texto VARCHAR(100))
RETURNS VARCHAR(80)
AS
BEGIN
    DECLARE @pais VARCHAR(80);

    SELECT TOP 1 @pais = nombre_pais
    FROM importacion.EquivalenciaPais
    WHERE nombre_ingles = @texto OR codigo_fifa = @texto
    ORDER BY id_equivalencia;

    RETURN ISNULL(@pais, @texto);
END;
GO

-- ------------------------------------------------------------------ FUNCIONES DE TEXTO (SCRAPING)
-- Saca las etiquetas HTML (<...>), las notas al pie ([1]) y las entidades más comunes
CREATE OR ALTER FUNCTION importacion.fn_QuitarHtml (@html VARCHAR(MAX))
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @ini INT = CHARINDEX('<', @html), @fin INT;

    WHILE @ini > 0
    BEGIN
        SET @fin = CHARINDEX('>', @html, @ini);
        IF @fin = 0
            SET @ini = 0;
        ELSE
        BEGIN
            SET @html = STUFF(@html, @ini, @fin - @ini + 1, '');
            SET @ini = CHARINDEX('<', @html);
        END;
    END;

    SET @ini = CHARINDEX('[', @html);
    WHILE @ini > 0
    BEGIN
        SET @fin = CHARINDEX(']', @html, @ini);
        IF @fin = 0
            SET @ini = 0;
        ELSE
        BEGIN
            SET @html = STUFF(@html, @ini, @fin - @ini + 1, '');
            SET @ini = CHARINDEX('[', @html);
        END;
    END;

    SET @html = REPLACE(REPLACE(REPLACE(REPLACE(@html, '&nbsp;', ' '), '&#160;', ' '), CHAR(160), ' '), '&amp;', '&');
    SET @html = REPLACE(REPLACE(@html, '&#39;', ''''), '&quot;', '"');
    SET @html = REPLACE(REPLACE(@html, CHAR(13), ' '), CHAR(10), ' ');
    RETURN LTRIM(RTRIM(@html));
END;
GO

-- Texto de la celda número @n (desde 1) de una fila HTML (<td> o <th>); NULL si la fila tiene menos celdas
CREATE OR ALTER FUNCTION importacion.fn_CeldaHtml (@fila VARCHAR(MAX), @n INT)
RETURNS VARCHAR(MAX)
AS
BEGIN
    DECLARE @k INT = 1, @td INT, @th INT, @ini INT, @inicio_texto INT, @fin INT, @cierre VARCHAR(5);

    WHILE 1 = 1
    BEGIN
        SET @td = CHARINDEX('<td', @fila);
        SET @th = CHARINDEX('<th', @fila);
        SET @ini = CASE WHEN @td = 0 THEN @th WHEN @th = 0 THEN @td WHEN @td < @th THEN @td ELSE @th END;
        IF @ini = 0 RETURN NULL;

        SET @cierre = CASE WHEN SUBSTRING(@fila, @ini, 3) = '<td' THEN '</td>' ELSE '</th>' END;
        SET @inicio_texto = CHARINDEX('>', @fila, @ini) + 1;
        SET @fin = CHARINDEX(@cierre, @fila, @inicio_texto);
        IF @inicio_texto = 1 OR @fin = 0 RETURN NULL;

        IF @k = @n
            RETURN importacion.fn_QuitarHtml(SUBSTRING(@fila, @inicio_texto, @fin - @inicio_texto));

        SET @fila = SUBSTRING(@fila, @fin + 5, LEN(@fila));
        SET @k += 1;
    END;

    RETURN NULL;
END;
GO

-- ------------------------------------------------------------------ PEDIDO HTTP
-- GET de @url. Devuelve el cuerpo de la respuesta en @respuesta. Cualquier problema (sin conexión,
-- sitio caído, código distinto de 200) se informa con THROW. Los sitios exigen identificarse con
-- un User-Agent (Wikipedia rechaza los pedidos anónimos).
CREATE OR ALTER PROCEDURE importacion.Http_Obtener
    @url VARCHAR(1000),
    @respuesta VARCHAR(MAX) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @obj INT, @hr INT, @estado INT;
    CREATE TABLE #respuesta (texto VARCHAR(MAX));

    EXEC @hr = sp_OACreate 'MSXML2.ServerXMLHTTP.6.0', @obj OUTPUT;
    IF @hr <> 0
        THROW 50001, 'No se pudo crear el cliente HTTP: habilitar Ole Automation Procedures (script 10). ', 1;

    BEGIN TRY
        EXEC @hr = sp_OAMethod @obj, 'open', NULL, 'GET', @url, 0;
        IF @hr <> 0 THROW 50001, 'URL inválida. ', 1;
        EXEC sp_OAMethod @obj, 'setTimeouts', NULL, 10000, 10000, 20000, 60000;
        EXEC sp_OAMethod @obj, 'setRequestHeader', NULL, 'User-Agent', 'UNLaM-BBDDA-TP-Grupo07/1.0 (trabajo practico universitario)';
        EXEC sp_OAMethod @obj, 'setRequestHeader', NULL, 'Accept', 'application/json, text/html, */*';

        EXEC @hr = sp_OAMethod @obj, 'send';
        IF @hr <> 0 THROW 50001, 'No se pudo conectar con el sitio (sin Internet, sitio caído o bloqueado por el firewall). ', 1;

        EXEC sp_OAGetProperty @obj, 'status', @estado OUTPUT;
        IF @estado <> 200
        BEGIN
            DECLARE @mensaje VARCHAR(200) = 'El sitio respondió con el código HTTP ' + CAST(@estado AS VARCHAR(10)) + '. ';
            THROW 50001, @mensaje, 1;
        END;

        INSERT INTO #respuesta EXEC sp_OAGetProperty @obj, 'responseText';
        SELECT @respuesta = texto FROM #respuesta;
        EXEC sp_OADestroy @obj;
    END TRY
    BEGIN CATCH
        EXEC sp_OADestroy @obj;
        THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------------ BITÁCORA
CREATE OR ALTER PROCEDURE importacion.Importacion_Iniciar
    @archivo VARCHAR(500),
    @formato VARCHAR(10),
    @id_importacion INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO importacion.Importacion (archivo, formato) VALUES (@archivo, @formato);
    SET @id_importacion = SCOPE_IDENTITY();
END;
GO

-- Completa los totales a partir de importacion.Registro y deja la importación OK o CON_ERRORES
CREATE OR ALTER PROCEDURE importacion.Importacion_Cerrar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE importacion.Importacion
    SET filas_leidas = (SELECT COUNT(*) FROM importacion.Registro WHERE id_importacion = @id_importacion),
        filas_nuevas = (SELECT COUNT(*) FROM importacion.Registro WHERE id_importacion = @id_importacion AND estado = 'NUEVO'),
        filas_actualizadas = (SELECT COUNT(*) FROM importacion.Registro WHERE id_importacion = @id_importacion AND estado = 'ACTUALIZADO'),
        filas_sin_cambios = (SELECT COUNT(*) FROM importacion.Registro WHERE id_importacion = @id_importacion AND estado = 'SIN_CAMBIOS'),
        filas_error = (SELECT COUNT(*) FROM importacion.Registro WHERE id_importacion = @id_importacion AND estado = 'ERROR'),
        fecha_fin = SYSDATETIME()
    WHERE id_importacion = @id_importacion;

    UPDATE importacion.Importacion
    SET estado = CASE WHEN filas_error > 0 THEN 'CON_ERRORES' ELSE 'OK' END
    WHERE id_importacion = @id_importacion;
END;
GO

-- Se llama desde un CATCH: guarda el mensaje del error en curso y deja la importación FALLIDA
CREATE OR ALTER PROCEDURE importacion.Importacion_Fallar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE importacion.Importacion
    SET estado = 'FALLIDA', fecha_fin = SYSDATETIME(), mensaje = LEFT(ERROR_MESSAGE(), 500)
    WHERE id_importacion = @id_importacion;
END;
GO

-- Agrega un registro a la bitácora. Si @errores trae texto el registro termina en ERROR con ese motivo;
-- si no, se guarda con el @estado informado (NUEVO, ACTUALIZADO o SIN_CAMBIOS)
CREATE OR ALTER PROCEDURE importacion.Registro_Agregar
    @id_importacion INT,
    @clave VARCHAR(200),
    @estado VARCHAR(12),
    @errores VARCHAR(2000) = ''
AS
BEGIN
    SET NOCOUNT ON;

    IF @errores <> ''
        INSERT INTO importacion.Registro (id_importacion, clave, estado, mensaje) VALUES (@id_importacion, @clave, 'ERROR', @errores);
    ELSE
        INSERT INTO importacion.Registro (id_importacion, clave, estado) VALUES (@id_importacion, @clave, @estado);
END;
GO

-- Muestra el resultado de una importación: la bitácora y los registros que terminaron en ERROR
CREATE OR ALTER PROCEDURE importacion.Resultado_Mostrar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT id_importacion, archivo, formato, estado, filas_leidas, filas_nuevas, filas_actualizadas,
           filas_sin_cambios, filas_error, fecha_inicio, fecha_fin
    FROM importacion.Importacion WHERE id_importacion = @id_importacion;

    SELECT clave, mensaje
    FROM importacion.Registro
    WHERE id_importacion = @id_importacion AND estado = 'ERROR'
    ORDER BY id_registro;
END;
GO
