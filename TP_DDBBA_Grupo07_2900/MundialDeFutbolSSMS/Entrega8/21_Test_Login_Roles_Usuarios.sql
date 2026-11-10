/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 07/11/2026
   Objetivo     : Testing de Roles.
   
   =============================================================================*/

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

PRINT 'Organizador';
EXECUTE AS USER = 'organizador';
PRINT 'Usuario actual: ' + USER_NAME();
 
DECLARE @id_pais INT;

-- 1. Puede agregar, modificar y eliminar en geo a traves de los SP
PRINT '--- 1. ABM de geo mediante stored procedures ---';
 
BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'PaisTest', @huso_horario = -3, @pbi_per_capita = 1000, @id_pais = @id_pais OUTPUT;
    PRINT 'OK: Pais_Insertar permitido (id_pais = ' + CAST(@id_pais AS VARCHAR(10)) + ')';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    EXEC geo.Pais_Modificar @id_pais = @id_pais, @nombre = 'PaisTest2', @huso_horario = -3, @pbi_per_capita = 2000;
    PRINT 'OK: Pais_Modificar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    EXEC geo.Pais_Eliminar @id_pais = @id_pais;
    PRINT 'OK: Pais_Eliminar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
 
-- 2. Puede consultar las tablas de torneo con SELECT
PRINT '';
PRINT '--- 2. SELECT sobre tablas de torneo ---';
 
BEGIN TRY
    SELECT TOP 5 * FROM torneo.Seleccion;
    SELECT TOP 5 * FROM torneo.Sede;
    SELECT TOP 5 * FROM torneo.Partido;
    PRINT 'OK: SELECT sobre torneo permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
 
-- 3. No puede trabajar directamente con las tablas de geo
PRINT '';
PRINT '--- 3. Escritura directa sobre geo (debe ser denegada) ---';
 
BEGIN TRY
    INSERT INTO geo.Pais (nombre) VALUES ('PaisDirecto');
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    UPDATE geo.Pais SET nombre = 'PaisDirecto' WHERE id_pais = 1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: UPDATE denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    DELETE FROM geo.Pais WHERE id_pais = 1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: DELETE denegado. ' + ERROR_MESSAGE();
END CATCH;
 
-- 4. NO puede trabajar con la tabla de personas que no tiene asignada (personas.Club)
-- Solo tiene SELECT sobre personas.
PRINT '';
PRINT '--- 4. Escritura sobre personas (debe ser denegada) ---';
 
BEGIN TRY
    INSERT INTO personas.Club (nombre) VALUES ('ClubDirecto');
    PRINT 'FALLO: INSERT directo en personas.Club se permitio';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT directo denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    EXEC personas.Club_Insertar @nombre = 'ClubPorSP';
    PRINT 'FALLO: personas.Club_Insertar se permitio';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de personas.Club_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;
 
REVERT;
PRINT '';
PRINT 'Usuario actual tras REVERT: ' + USER_NAME();
GO

PRINT '';
 
PRINT 'Importador';
EXECUTE AS USER = 'importador';
PRINT 'Usuario actual: ' + USER_NAME();
 
DECLARE @id_importacion INT;
 
-- 1. SI puede ejecutar los SP del esquema importacion.
PRINT '--- 1. EXECUTE de SP de importacion ---';
 
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC importacion.Importacion_Iniciar @archivo = 'test.csv', @formato = 'CSV', @id_importacion = @id_importacion OUTPUT;
    EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = 'GOL TEST', @estado = 'NUEVO';
    EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
    ROLLBACK TRANSACTION;
    PRINT 'OK: Importacion_Iniciar, Registro_Agregar, Importacion_Cerrar y Resultado_Mostrar permitidos';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

 
-- 2. SI puede consultar las tablas de importacion con SELECT
PRINT '';
PRINT '--- 2. SELECT sobre tablas de importacion ---';
 
BEGIN TRY
    SELECT TOP 1 * FROM importacion.Importacion;
    SELECT TOP 1 * FROM importacion.Registro;
    PRINT 'OK: SELECT sobre importacion permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
 
-- 3. SI puede insertar directo en las areas de paso (lo necesita BULK INSERT)
PRINT '';
PRINT '--- 3. INSERT directo en JsonCarga y GolCarga ---';
 
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO importacion.JsonCarga (contenido) VALUES ('{}');
    INSERT INTO importacion.GolCarga (key_id) VALUES ('1');
    ROLLBACK TRANSACTION;
    PRINT 'OK: INSERT en JsonCarga y GolCarga permitido';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;
 
-- 4. NO puede modificar directamente las tablas de importacion
-- Solo tiene INSERT en las areas de paso; la bitacora se escribe unicamente por SP.
PRINT '';
PRINT '--- 4. Escritura directa no asignada en importacion (debe ser denegada) ---';
 
BEGIN TRY
    DELETE FROM importacion.GolCarga;
    PRINT 'FALLO: DELETE directo en GolCarga se permitio';
END TRY
BEGIN CATCH
    PRINT 'OK: DELETE directo denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    INSERT INTO importacion.Importacion (archivo, formato) VALUES ('directo.csv', 'CSV');
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT directo en la bitacora denegado. ' + ERROR_MESSAGE();
END CATCH;
 
-- 5. NO puede consultar las tablas de otros esquemas
PRINT '';
PRINT '--- 5. SELECT sobre otros esquemas (debe ser denegado) ---';
 
BEGIN TRY
    SELECT TOP 1 * FROM torneo.Partido;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre torneo denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    SELECT TOP 1 * FROM geo.Pais;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre geo denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    SELECT TOP 1 * FROM personas.Club;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre personas denegado. ' + ERROR_MESSAGE();
END CATCH;
 
-- 6. No puede trabajar directamente con otros esquemas, ni por tabla ni por SP
PRINT '';
PRINT '--- 6. Escritura sobre otros esquemas (debe ser denegada) ---';
 
BEGIN TRY
    INSERT INTO geo.Pais (nombre) VALUES ('PaisDirecto');
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT directo en geo denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'PaisPorSP';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de geo.Pais_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;
 
BEGIN TRY
    EXEC torneo.Gol_Registrar @id_partido = 1, @id_jugador_autor = 1, @minuto = 1, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de torneo.Gol_Registrar denegado. ' + ERROR_MESSAGE();
END CATCH;
 
REVERT;
PRINT '';
PRINT 'Usuario actual tras REVERT: ' + USER_NAME();
GO
