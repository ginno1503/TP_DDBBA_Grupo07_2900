/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Script de testing para 13_SP_ABM_Externos.sql. Cada prueba indica el resultado esperado y
                  muestra OK o FALLO. Requisito: haber ejecutado los scripts 00 a 13_SP_ABM_Externos.sql.
   ============================================================================= */

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

DELETE FROM publicidad.Feriado;
DELETE FROM publicidad.TipoCambio;
GO

DECLARE @id_tc INT, @id_f INT, @id_pais INT;

IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Argentina')
    EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00;
SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');

PRINT '=== TIPO DE CAMBIO ===';
-- 1.1 Alta válida
EXEC publicidad.TipoCambio_Insertar @moneda_base = 'USD', @moneda = 'eur', @fecha = '2026-11-03', @cotizacion = 0.86, @id_tipo_cambio = @id_tc OUTPUT;
IF EXISTS (SELECT 1 FROM publicidad.TipoCambio WHERE id_tipo_cambio = @id_tc AND moneda = 'EUR') PRINT 'OK 1.1 - Cotizacion insertada (moneda en mayusculas)';
ELSE PRINT 'FALLO 1.1';

-- 1.2 ERROR: misma moneda y fecha
BEGIN TRY
    EXEC publicidad.TipoCambio_Insertar @moneda_base = 'USD', @moneda = 'EUR', @fecha = '2026-11-03', @cotizacion = 0.9;
    PRINT 'FALLO 1.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%Ya existe%' PRINT 'OK 1.2 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.2 - ' + ERROR_MESSAGE();
END CATCH;

-- 1.3 ERROR: cotización cero y moneda inválida (se informan juntos)
BEGIN TRY
    EXEC publicidad.TipoCambio_Insertar @moneda_base = 'USD', @moneda = 'EU', @fecha = '2026-11-03', @cotizacion = 0;
    PRINT 'FALLO 1.3 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%3 letras%' AND ERROR_MESSAGE() LIKE '%mayor a cero%' PRINT 'OK 1.3 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.3 - ' + ERROR_MESSAGE();
END CATCH;

-- 1.4 Modificación válida
EXEC publicidad.TipoCambio_Modificar @id_tipo_cambio = @id_tc, @cotizacion = 0.87;
IF EXISTS (SELECT 1 FROM publicidad.TipoCambio WHERE id_tipo_cambio = @id_tc AND cotizacion = 0.87) PRINT 'OK 1.4 - Cotizacion modificada';
ELSE PRINT 'FALLO 1.4';

-- 1.5 ERROR: modificar una cotización inexistente
BEGIN TRY
    EXEC publicidad.TipoCambio_Modificar @id_tipo_cambio = -1, @cotizacion = 1;
    PRINT 'FALLO 1.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%no existe%' PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.5 - ' + ERROR_MESSAGE();
END CATCH;

PRINT '=== FERIADO ===';
-- 2.1 Alta válida
EXEC publicidad.Feriado_Insertar @id_pais = @id_pais, @fecha = '2026-07-09', @nombre = '  Día de la Independencia ', @id_feriado = @id_f OUTPUT;
IF EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_feriado = @id_f AND nombre = 'Día de la Independencia') PRINT 'OK 2.1 - Feriado insertado (con trim)';
ELSE PRINT 'FALLO 2.1';

-- 2.2 ERROR: mismo país y fecha
BEGIN TRY
    EXEC publicidad.Feriado_Insertar @id_pais = @id_pais, @fecha = '2026-07-09', @nombre = 'Otro';
    PRINT 'FALLO 2.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya tiene un feriado%' PRINT 'OK 2.2 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2.2 - ' + ERROR_MESSAGE();
END CATCH;

-- 2.3 ERROR: país inexistente y nombre vacío
BEGIN TRY
    EXEC publicidad.Feriado_Insertar @id_pais = -1, @fecha = '2026-01-01', @nombre = ' ';
    PRINT 'FALLO 2.3 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%país no existe%' AND ERROR_MESSAGE() LIKE '%Falta el nombre%' PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2.3 - ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 Modificación válida
EXEC publicidad.Feriado_Modificar @id_feriado = @id_f, @nombre = 'Independencia';
IF EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_feriado = @id_f AND nombre = 'Independencia') PRINT 'OK 2.4 - Feriado modificado';
ELSE PRINT 'FALLO 2.4';

-- 2.5 ERROR: modificar un feriado inexistente
BEGIN TRY
    EXEC publicidad.Feriado_Modificar @id_feriado = -1, @nombre = 'X';
    PRINT 'FALLO 2.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%no existe%' PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2.5 - ' + ERROR_MESSAGE();
END CATCH;
GO
