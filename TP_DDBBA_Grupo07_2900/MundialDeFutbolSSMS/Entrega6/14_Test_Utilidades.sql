/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Script de testing para 14_SP_Utilidades.sql. Las funciones de texto se prueban sin Internet;
                  Http_Obtener se prueba con una dirección que no existe (debe fallar con THROW) y la
                  bitácora con una importación de prueba. Cada prueba muestra OK o FALLO.
                  Requisito: haber ejecutado los scripts 00 a 14_SP_Utilidades.sql.
   ============================================================================= */

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

DECLARE @r VARCHAR(MAX), @id INT;

PRINT '=== fn_PaisLocal ===';
-- 1.1 Nombre en inglés, código FIFA y alias histórico se traducen; un país desconocido queda igual
IF importacion.fn_PaisLocal('Germany') = 'Alemania' AND importacion.fn_PaisLocal('GER') = 'Alemania'
   AND importacion.fn_PaisLocal('West Germany') = 'Alemania' AND importacion.fn_PaisLocal('Narnia') = 'Narnia' PRINT 'OK 1.1 - Equivalencias y fallback';
ELSE PRINT 'FALLO 1.1';

PRINT '=== fn_QuitarHtml / fn_CeldaHtml ===';
-- 2.1 Etiquetas, notas al pie y entidades
SET @r = importacion.fn_QuitarHtml('<a href="/wiki/X" title="X">John&#160;Langenus</a> (<a href="/b">BEL</a>)<sup>[1]</sup> &amp; Co');
IF @r = 'John Langenus (BEL) & Co' PRINT 'OK 2.1 - Texto limpio: ' + @r;
ELSE PRINT 'FALLO 2.1 - ' + ISNULL(@r, 'NULL');
-- 2.2 Celdas de una fila (th + td con atributos)
SET @r = '<th scope="row">1930</th><td style="x"><span><a href="/w">Ivan Eklind</a></span> (SWE)</td><td></td>';
IF importacion.fn_CeldaHtml(@r, 1) = '1930' AND importacion.fn_CeldaHtml(@r, 2) = 'Ivan Eklind (SWE)' AND importacion.fn_CeldaHtml(@r, 3) = '' AND importacion.fn_CeldaHtml(@r, 4) IS NULL PRINT 'OK 2.2 - Celdas por posicion';
ELSE PRINT 'FALLO 2.2';

PRINT '=== Http_Obtener ===';
-- 3.1 ERROR: el sitio no existe (el mensaje depende de si hay Internet o no, pero debe fallar con THROW)
BEGIN TRY
    EXEC importacion.Http_Obtener @url = 'https://sitio-que-no-existe.invalid/', @respuesta = @r OUTPUT;
    PRINT 'FALLO 3.1 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%No se pudo%' OR ERROR_MESSAGE() LIKE '%HTTP%' OR ERROR_MESSAGE() LIKE '%inv_lida%' PRINT 'OK 3.1 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.1 - ' + ERROR_MESSAGE();
END CATCH;

PRINT '=== Bitácora ===';
-- 4.1 Iniciar, registrar y cerrar: 1 nuevo, 1 sin cambios y 1 error
EXEC importacion.Importacion_Iniciar @archivo = 'prueba', @formato = 'API', @id_importacion = @id OUTPUT;
INSERT INTO importacion.Registro (id_importacion, clave, estado, mensaje) VALUES
    (@id, 'a', 'NUEVO', NULL), (@id, 'b', 'SIN_CAMBIOS', NULL), (@id, 'c', 'ERROR', 'motivo');
EXEC importacion.Importacion_Cerrar @id_importacion = @id;
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id AND estado = 'CON_ERRORES' AND filas_leidas = 3
           AND filas_nuevas = 1 AND filas_sin_cambios = 1 AND filas_error = 1 AND fecha_fin IS NOT NULL) PRINT 'OK 4.1 - Totales y estado CON_ERRORES';
ELSE PRINT 'FALLO 4.1';
-- 4.2 Importación fallida: se guarda el mensaje
EXEC importacion.Importacion_Iniciar @archivo = 'prueba 2', @formato = 'API', @id_importacion = @id OUTPUT;
BEGIN TRY
    THROW 50001, 'Motivo de la falla. ', 1;
END TRY
BEGIN CATCH
    EXEC importacion.Importacion_Fallar @id_importacion = @id;
END CATCH;
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id AND estado = 'FALLIDA' AND mensaje LIKE 'Motivo%') PRINT 'OK 4.2 - Importacion FALLIDA con mensaje';
ELSE PRINT 'FALLO 4.2';
-- 4.3 Registro_Agregar: con motivo termina en ERROR; sin motivo se guarda con el estado indicado
EXEC importacion.Importacion_Iniciar @archivo = 'prueba 3', @formato = 'API', @id_importacion = @id OUTPUT;
EXEC importacion.Registro_Agregar @id_importacion = @id, @clave = 'x', @estado = 'NUEVO';
EXEC importacion.Registro_Agregar @id_importacion = @id, @clave = 'y', @estado = 'NUEVO', @errores = 'Falta un dato. ';
IF EXISTS (SELECT 1 FROM importacion.Registro WHERE id_importacion = @id AND clave = 'x' AND estado = 'NUEVO' AND mensaje IS NULL)
   AND EXISTS (SELECT 1 FROM importacion.Registro WHERE id_importacion = @id AND clave = 'y' AND estado = 'ERROR' AND mensaje = 'Falta un dato. ') PRINT 'OK 4.3 - Registro_Agregar';
ELSE PRINT 'FALLO 4.3';
EXEC importacion.Resultado_Mostrar @id_importacion = @id;
GO
