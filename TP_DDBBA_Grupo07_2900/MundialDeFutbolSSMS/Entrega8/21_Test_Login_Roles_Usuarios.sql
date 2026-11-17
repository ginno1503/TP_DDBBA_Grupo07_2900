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
    SELECT TOP 1 * FROM torneo.Seleccion;
    SELECT TOP 1 * FROM torneo.Sede;
    SELECT TOP 1 * FROM torneo.Partido;
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

---------------------------------------------------------
---------------------------------------------------------
PRINT '';

PRINT 'Planteles';
EXECUTE AS USER = 'planteles';
PRINT 'Usuario actual: ' + USER_NAME();

DECLARE @id_club INT;

-- 1. SI puede agregar, modificar y eliminar en personas a traves de los SP
PRINT '--- 1. ABM de personas mediante stored procedures ---';

BEGIN TRY
    EXEC personas.Club_Insertar @nombre = 'ClubTest', @id_club = @id_club OUTPUT;
    PRINT 'OK: Club_Insertar permitido (id_club = ' + CAST(@id_club AS VARCHAR(10)) + ')';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC personas.Club_Modificar @id_club = @id_club, @nombre = 'ClubTest2';
    PRINT 'OK: Club_Modificar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC personas.Club_Eliminar @id_club = @id_club;
    PRINT 'OK: Club_Eliminar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

-- 2. SI puede consultar las tablas de personas, torneo y geo con SELECT
PRINT '';
PRINT '--- 2. SELECT sobre personas, torneo y geo ---';

BEGIN TRY
    SELECT TOP 1 * FROM personas.Participante;
    SELECT TOP 1 * FROM torneo.Seleccion;
    SELECT TOP 1 * FROM geo.Pais;
    PRINT 'OK: SELECT sobre personas, torneo y geo permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

-- 3. SI puede ejecutar los SP de torneo que tiene asignados (convocatorias, reemplazos y alineaciones)
-- Se prueba con datos que no existen: si el SP se ejecuta y rechaza los datos, el permiso esta bien.
PRINT '';
PRINT '--- 3. EXECUTE de SP de torneo asignados ---';

BEGIN TRY
    EXEC torneo.Convocatoria_Registrar @id_seleccion = -1;
    PRINT 'OK: Convocatoria_Registrar permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Convocatoria_Registrar permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar @id_jugador_sale = -1, @id_jugador_entra = -2, @fecha = '2026-01-01', @motivo = 'Prueba';
    PRINT 'OK: ReemplazoConvocatoria_Insertar permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: ReemplazoConvocatoria_Insertar permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC torneo.Alineacion_Registrar @id_partido = -1, @id_seleccion = -1, @esquema_tactico = '4-4-2';
    PRINT 'OK: Alineacion_Registrar permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Alineacion_Registrar permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

-- 4. NO puede trabajar directamente con las tablas de personas
-- Solo tiene SELECT y EXECUTE; las tablas se modifican unicamente por SP.
PRINT '';
PRINT '--- 4. Escritura directa sobre personas (debe ser denegada) ---';

BEGIN TRY
    INSERT INTO personas.Club (nombre) VALUES ('ClubDirecto');
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    UPDATE personas.Participante SET nombre = 'Directo' WHERE id_participante = -1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: UPDATE denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    DELETE FROM personas.Jugador WHERE id_participante = -1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: DELETE denegado. ' + ERROR_MESSAGE();
END CATCH;

-- 5. NO puede ejecutar los SP de torneo y geo que no tiene asignados
PRINT '';
PRINT '--- 5. EXECUTE de SP no asignados (debe ser denegado) ---';

BEGIN TRY
    EXEC torneo.Sede_Insertar @id_ciudad = 1, @nombre_estadio = 'EstadioTest', @capacidad = 1000;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de torneo.Sede_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC torneo.Gol_Registrar @id_partido = -1, @id_jugador_autor = -1, @minuto = 1, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de torneo.Gol_Registrar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'PaisPorSP';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de geo.Pais_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

-- 6. NO puede consultar las tablas de publicidad ni de importacion
PRINT '';
PRINT '--- 6. SELECT sobre otros esquemas (debe ser denegado) ---';

BEGIN TRY
    SELECT TOP 1 * FROM publicidad.Tarifa;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre publicidad denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT TOP 1 * FROM importacion.Importacion;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre importacion denegado. ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '';
PRINT 'Usuario actual tras REVERT: ' + USER_NAME();
GO

---------------------------------------------------------
---------------------------------------------------------
PRINT '';

PRINT 'Operador';
EXECUTE AS USER = 'operador';
PRINT 'Usuario actual: ' + USER_NAME();

-- 1. SI puede ejecutar los SP de carga en vivo que tiene asignados
-- Se prueba con un partido que no existe: si el SP se ejecuta y lo rechaza, el permiso esta bien
-- y no se modifica ningun dato.
PRINT '--- 1. EXECUTE de SP de carga de partido ---';

BEGIN TRY
    EXEC torneo.Gol_Registrar @id_partido = -1, @id_jugador_autor = -1, @minuto = 1, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'OK: Gol_Registrar permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Gol_Registrar permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC torneo.Cambio_Registrar @id_partido = -1, @id_jugador_sale = -1, @id_jugador_entra = -2, @minuto = 1, @periodo = 'PRIMER_TIEMPO', @motivo = 'TACTICO';
    PRINT 'OK: Cambio_Registrar permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Cambio_Registrar permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC torneo.Tarjeta_Registrar @id_partido = -1, @id_jugador = -1, @color = 'AMARILLA', @minuto = 1;
    PRINT 'OK: Tarjeta_Registrar permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Tarjeta_Registrar permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC torneo.Partido_RegistrarResultado @id_partido = -1, @goles_1 = 0, @goles_2 = 0;
    PRINT 'OK: Partido_RegistrarResultado permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Partido_RegistrarResultado permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC torneo.Partido_DesignarArbitros @id_partido = -1, @id_principal = -1, @id_var = -2, @id_asistente_1 = -3, @id_asistente_2 = -4, @id_cuarto = -5;
    PRINT 'OK: Partido_DesignarArbitros permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: Partido_DesignarArbitros permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

-- 2. SI puede consultar las tablas de torneo y personas con SELECT
PRINT '';
PRINT '--- 2. SELECT sobre torneo y personas ---';

BEGIN TRY
    SELECT TOP 1 * FROM torneo.Partido;
    SELECT TOP 1 * FROM torneo.Gol;
    SELECT TOP 1 * FROM personas.Participante;
    PRINT 'OK: SELECT sobre torneo y personas permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

-- 3. NO puede trabajar directamente con las tablas de torneo
-- Los eventos del partido se cargan unicamente por SP.
PRINT '';
PRINT '--- 3. Escritura directa sobre torneo (debe ser denegada) ---';

BEGIN TRY
    INSERT INTO torneo.Gol (id_partido, nro, id_jugador_autor, minuto, tipo, periodo) VALUES (-1, 1, -1, 1, 'JUGADA', 'PRIMER_TIEMPO');
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    UPDATE torneo.Partido SET goles_1 = 0 WHERE id_partido = -1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: UPDATE denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    DELETE FROM torneo.Sancion WHERE id_partido = -1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: DELETE denegado. ' + ERROR_MESSAGE();
END CATCH;

-- 4. NO puede ejecutar SP que no tiene asignados, ni siquiera de torneo
-- Solo tiene los 5 SP de carga en vivo; Gol_Insertar (el que usa Gol_Registrar por dentro) no esta asignado.
PRINT '';
PRINT '--- 4. EXECUTE de SP no asignados (debe ser denegado) ---';

BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = -1, @nro = 1, @id_jugador_autor = -1, @minuto = 1, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de torneo.Gol_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC torneo.Sede_Insertar @id_ciudad = 1, @nombre_estadio = 'EstadioTest', @capacidad = 1000;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de torneo.Sede_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC personas.Club_Insertar @nombre = 'ClubPorSP';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de personas.Club_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'PaisPorSP';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de geo.Pais_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

-- 5. NO puede consultar las tablas de geo, publicidad ni importacion
PRINT '';
PRINT '--- 5. SELECT sobre otros esquemas (debe ser denegado) ---';

BEGIN TRY
    SELECT TOP 1 * FROM geo.Pais;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre geo denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT TOP 1 * FROM publicidad.Tarifa;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre publicidad denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT TOP 1 * FROM importacion.Importacion;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre importacion denegado. ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '';
PRINT 'Usuario actual tras REVERT: ' + USER_NAME();
GO

---------------------------------------------------------
---------------------------------------------------------
PRINT '';

PRINT 'Comercial';
EXECUTE AS USER = 'comercial';
PRINT 'Usuario actual: ' + USER_NAME();

DECLARE @id_anunciante INT;

-- 1. SI puede agregar, modificar y eliminar en publicidad a traves de los SP
PRINT '--- 1. ABM de publicidad mediante stored procedures ---';

BEGIN TRY
    EXEC publicidad.Anunciante_Insertar @nombre = 'AnuncianteTest', @razon_social = 'Razon Social Test SA', @id_anunciante = @id_anunciante OUTPUT;
    PRINT 'OK: Anunciante_Insertar permitido (id_anunciante = ' + CAST(@id_anunciante AS VARCHAR(10)) + ')';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC publicidad.Anunciante_Modificar @id_anunciante = @id_anunciante, @nombre = 'AnuncianteTest2', @razon_social = 'Razon Social Test SA';
    PRINT 'OK: Anunciante_Modificar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC publicidad.Campania_Insertar @id_anunciante = @id_anunciante, @cod_campania = 'CAMP-TEST', @nombre = 'CampaniaTest';
    PRINT 'OK: Campania_Insertar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC publicidad.Campania_Eliminar @id_anunciante = @id_anunciante, @cod_campania = 'CAMP-TEST';
    PRINT 'OK: Campania_Eliminar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC publicidad.Anunciante_Eliminar @id_anunciante = @id_anunciante;
    PRINT 'OK: Anunciante_Eliminar permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

-- 2. SI puede consultar publicidad, geo y las tablas Partido y Seleccion de torneo con SELECT
PRINT '';
PRINT '--- 2. SELECT sobre publicidad, geo y torneo (Partido y Seleccion) ---';

BEGIN TRY
    SELECT TOP 1 * FROM publicidad.Tarifa;
    SELECT TOP 1 * FROM geo.Pais;
    SELECT TOP 1 * FROM torneo.Partido;
    SELECT TOP 1 * FROM torneo.Seleccion;
    PRINT 'OK: SELECT sobre publicidad, geo, torneo.Partido y torneo.Seleccion permitido';
END TRY
BEGIN CATCH
    PRINT 'FALLO: ' + ERROR_MESSAGE();
END CATCH;

-- 3. SI puede ejecutar los SP de publicidad que leen datos de torneo y geo
-- Se prueba con un partido que no existe: si el SP se ejecuta y lo rechaza, el permiso esta bien.
PRINT '';
PRINT '--- 3. EXECUTE de SP de simulacion y asignacion automatica ---';

BEGIN TRY
    EXEC publicidad.SimularPrimeTime @id_partido = -1;
    PRINT 'OK: SimularPrimeTime permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: SimularPrimeTime permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

BEGIN TRY
    EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido = -1;
    PRINT 'OK: AsignarAutomaticamenteAPartido permitido';
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 229
        PRINT 'FALLO: ' + ERROR_MESSAGE();
    ELSE
        PRINT 'OK: AsignarAutomaticamenteAPartido permitido (el SP rechazo los datos de prueba: ' + ERROR_MESSAGE() + ')';
END CATCH;

-- 4. NO puede trabajar directamente con las tablas de publicidad
-- Solo tiene SELECT y EXECUTE; las tablas se modifican unicamente por SP.
PRINT '';
PRINT '--- 4. Escritura directa sobre publicidad (debe ser denegada) ---';

BEGIN TRY
    INSERT INTO publicidad.Anunciante (nombre, razon_social) VALUES ('AnuncianteDirecto', 'Razon Directa SA');
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: INSERT denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    UPDATE publicidad.Tarifa SET costo = 0 WHERE id_tarifa = -1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: UPDATE denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    DELETE FROM publicidad.Campania WHERE id_anunciante = -1;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: DELETE denegado. ' + ERROR_MESSAGE();
END CATCH;

-- 5. NO puede consultar el resto de las tablas de torneo, ni personas ni importacion
PRINT '';
PRINT '--- 5. SELECT sobre tablas no asignadas (debe ser denegado) ---';

BEGIN TRY
    SELECT TOP 1 * FROM torneo.Sede;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre torneo.Sede denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT TOP 1 * FROM torneo.Gol;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre torneo.Gol denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT TOP 1 * FROM personas.Club;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre personas denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    SELECT TOP 1 * FROM importacion.Importacion;
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: SELECT sobre importacion denegado. ' + ERROR_MESSAGE();
END CATCH;

-- 6. NO puede ejecutar SP de otros esquemas
PRINT '';
PRINT '--- 6. EXECUTE de SP de otros esquemas (debe ser denegado) ---';

BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'PaisPorSP';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de geo.Pais_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC torneo.Gol_Registrar @id_partido = -1, @id_jugador_autor = -1, @minuto = 1, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de torneo.Gol_Registrar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC personas.Club_Insertar @nombre = 'ClubPorSP';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de personas.Club_Insertar denegado. ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC importacion.Goles_Importar @ruta = 'goals.csv';
    PRINT 'FALLO: ';
END TRY
BEGIN CATCH
    PRINT 'OK: EXECUTE de importacion.Goles_Importar denegado. ' + ERROR_MESSAGE();
END CATCH;

REVERT;
PRINT '';
PRINT 'Usuario actual tras REVERT: ' + USER_NAME();
GO

---------------------------------------------------------
---------------------------------------------------------
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