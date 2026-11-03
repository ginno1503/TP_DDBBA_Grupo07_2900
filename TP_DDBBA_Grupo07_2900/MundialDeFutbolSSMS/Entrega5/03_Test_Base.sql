/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 25/10/2026
   Objetivo     : Script de testing para 03_SP_ABM_Base.sql
                  Prueba altas, modificaciones y bajas de: Idioma, Pais, Ciudad, Seleccion,
                  Sede, Club y Parametro, incluyendo casos de error.
   ============================================================================= */

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

-- LIMPIEZA PREVIA
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.ContenidoPais;
DELETE FROM publicidad.Contenido;
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;

DELETE FROM torneo.Parametro;
DELETE FROM torneo.Suspension;
DELETE FROM torneo.Expulsion;
DELETE FROM torneo.Sancion;
DELETE FROM torneo.Gol;
DELETE FROM torneo.Sustitucion;
DELETE FROM torneo.FormacionSuplente;
DELETE FROM torneo.FormacionTitular;
DELETE FROM torneo.PartidoFormacion;
DELETE FROM torneo.Formacion;
DELETE FROM torneo.ArbitroSecundario;
DELETE FROM torneo.Partido;
DELETE FROM torneo.Sede;
DELETE FROM torneo.ReemplazoConvocatoria;
DELETE FROM personas.Ayudante;
DELETE FROM personas.DirectorTecnico;
DELETE FROM personas.ArbitroIdioma;
DELETE FROM personas.Arbitro;
DELETE FROM personas.Jugador;
DELETE FROM personas.Club;
DELETE FROM personas.Participante;
DELETE FROM torneo.Seleccion;
DELETE FROM geo.Ciudad;
DELETE FROM geo.Pais;
DELETE FROM geo.Idioma;
GO

-------------------------------------- 1. IDIOMA
PRINT '=== 1. IDIOMA ===';

DECLARE @id_idioma1 INT, @id_idioma2 INT, @id_idioma3 INT;

-- 1.1 Alta válida
EXEC geo.Idioma_Insertar @nombre = 'Español', @id_idioma = @id_idioma1 OUTPUT;
IF @id_idioma1 IS NOT NULL PRINT 'OK 1.1 - Idioma insertado con id=' + CAST(@id_idioma1 AS VARCHAR);
ELSE PRINT 'FALLO 1.1 - No se obtuvo id de idioma';

-- 1.2 Alta válida con espacios (se trimea)
EXEC geo.Idioma_Insertar @nombre = '  Inglés  ', @id_idioma = @id_idioma2 OUTPUT;
IF @id_idioma2 IS NOT NULL PRINT 'OK 1.2 - Idioma con trim insertado';

-- 1.3 ERROR: nombre nulo
BEGIN TRY
    EXEC geo.Idioma_Insertar @nombre = NULL;
    PRINT 'FALLO 1.3 - Debio fallar por nombre nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.4 ERROR: nombre vacío
BEGIN TRY
    EXEC geo.Idioma_Insertar @nombre = '   ';
    PRINT 'FALLO 1.4 - Debio fallar por nombre vacio';
END TRY
BEGIN CATCH
    PRINT 'OK 1.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.5 ERROR: nombre duplicado
BEGIN TRY
    EXEC geo.Idioma_Insertar @nombre = 'Español';
    PRINT 'FALLO 1.5 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 Modificación válida
EXEC geo.Idioma_Modificar @id_idioma = @id_idioma2, @nombre = 'Inglés';
PRINT 'OK 1.6 - Idioma modificado';

-- 1.7 ERROR: modificar idioma inexistente
BEGIN TRY
    EXEC geo.Idioma_Modificar @id_idioma = 99999, @nombre = 'X';
    PRINT 'FALLO 1.7 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.8 ERROR: modificar a nombre de otro idioma
BEGIN TRY
    EXEC geo.Idioma_Modificar @id_idioma = @id_idioma2, @nombre = 'Español';
    PRINT 'FALLO 1.8 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.9 Alta de un tercer idioma (para probar borrado)
EXEC geo.Idioma_Insertar @nombre = 'Portugués', @id_idioma = @id_idioma3 OUTPUT;

-- 1.10 Eliminación válida (sin referencias)
EXEC geo.Idioma_Eliminar @id_idioma = @id_idioma3;
IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE id_idioma = @id_idioma3)
    PRINT 'OK 1.10 - Idioma eliminado';
ELSE PRINT 'FALLO 1.10 - Idioma sigue existiendo';

-- 1.11 ERROR: eliminar inexistente
BEGIN TRY
    EXEC geo.Idioma_Eliminar @id_idioma = 99999;
    PRINT 'FALLO 1.11 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 2. PAIS
PRINT '=== 2. PAIS ===';

DECLARE @id_pais_arg INT, @id_pais_bra INT, @id_pais_uru INT;

-- 2.1 Alta válida
EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @pbi_per_capita = 13000.50, @id_pais = @id_pais_arg OUTPUT;
IF @id_pais_arg IS NOT NULL PRINT 'OK 2.1 - Argentina insertada con id=' + CAST(@id_pais_arg AS VARCHAR);
ELSE PRINT 'FALLO 2.1';

-- 2.2 Alta válida con datos opcionales nulos
EXEC geo.Pais_Insertar @nombre = 'Brasil', @id_pais = @id_pais_bra OUTPUT;
IF @id_pais_bra IS NOT NULL PRINT 'OK 2.2 - Brasil insertado sin huso ni PBI';

-- 2.3 ERROR: huso fuera de rango
BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'Uruguay', @huso_horario = 20;
    PRINT 'FALLO 2.3 - Debio fallar por huso';
END TRY
BEGIN CATCH
    PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 ERROR: PBI negativo
BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'Chile', @pbi_per_capita = -1;
    PRINT 'FALLO 2.4 - Debio fallar por PBI';
END TRY
BEGIN CATCH
    PRINT 'OK 2.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.5 ERROR: nombre duplicado
BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'Argentina';
    PRINT 'FALLO 2.5 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.6 Modificación válida
EXEC geo.Pais_Modificar @id_pais = @id_pais_arg, @nombre = 'Argentina', @huso_horario = -3.00, @pbi_per_capita = 14000.00;
PRINT 'OK 2.6 - Argentina modificada';

-- 2.7 ERROR: modificar país inexistente
BEGIN TRY
    EXEC geo.Pais_Modificar @id_pais = 99999, @nombre = 'X';
    PRINT 'FALLO 2.7 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.8 Alta de Uruguay para probar eliminación
EXEC geo.Pais_Insertar @nombre = 'Uruguay', @huso_horario = -3.00, @id_pais = @id_pais_uru OUTPUT;

-- 2.9 Eliminación válida (sin dependencias)
EXEC geo.Pais_Eliminar @id_pais = @id_pais_uru;
IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE id_pais = @id_pais_uru)
    PRINT 'OK 2.9 - Uruguay eliminado';
ELSE PRINT 'FALLO 2.9';
GO

-------------------------------------- 3. CIUDAD
PRINT '=== 3. CIUDAD ===';

DECLARE @id_pais_arg INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');
DECLARE @id_pais_bra INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Brasil');
DECLARE @id_ciudad_ba INT, @id_ciudad_rio INT;

-- 3.1 Alta válida
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00, @id_ciudad = @id_ciudad_ba OUTPUT;
IF @id_ciudad_ba IS NOT NULL PRINT 'OK 3.1 - Buenos Aires insertada';
ELSE PRINT 'FALLO 3.1';

-- 3.2 Alta válida
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_bra, @nombre = 'Río de Janeiro', @huso_horario = -3.00, @id_ciudad = @id_ciudad_rio OUTPUT;
IF @id_ciudad_rio IS NOT NULL PRINT 'OK 3.2 - Río de Janeiro insertada';

-- 3.3 ERROR: país inexistente
BEGIN TRY
    EXEC geo.Ciudad_Insertar @id_pais = 99999, @nombre = 'X', @huso_horario = 0;
    PRINT 'FALLO 3.3 - Debio fallar por pais';
END TRY
BEGIN CATCH
    PRINT 'OK 3.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.4 ERROR: huso nulo
BEGIN TRY
    EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Córdoba', @huso_horario = NULL;
    PRINT 'FALLO 3.4 - Debio fallar por huso nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 3.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.5 ERROR: huso fuera de rango
BEGIN TRY
    EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Córdoba', @huso_horario = 99;
    PRINT 'FALLO 3.5 - Debio fallar por huso';
END TRY
BEGIN CATCH
    PRINT 'OK 3.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.6 ERROR: ciudad duplicada en el mismo país
BEGIN TRY
    EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00;
    PRINT 'FALLO 3.6 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 3.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.7 ERROR: eliminar país con ciudades (usa el SP de Pais)
BEGIN TRY
    EXEC geo.Pais_Eliminar @id_pais = @id_pais_arg;
    PRINT 'FALLO 3.7 - Debio fallar por ciudades';
END TRY
BEGIN CATCH
    PRINT 'OK 3.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.8 Modificación válida
EXEC geo.Ciudad_Modificar @id_ciudad = @id_ciudad_ba, @id_pais = @id_pais_arg, @nombre = 'CABA', @huso_horario = -3.00;
PRINT 'OK 3.8 - Ciudad modificada';

-- 3.9 ERROR: modificar ciudad inexistente
BEGIN TRY
    EXEC geo.Ciudad_Modificar @id_ciudad = 99999, @id_pais = @id_pais_arg, @nombre = 'X', @huso_horario = 0;
    PRINT 'FALLO 3.9 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.10 ERROR: modificar a nombre duplicado en el mismo país
BEGIN TRY
    EXEC geo.Ciudad_Modificar @id_ciudad = @id_ciudad_rio, @id_pais = @id_pais_arg, @nombre = 'CABA', @huso_horario = -3.00;
    PRINT 'FALLO 3.10 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 3.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 4. SELECCION
PRINT '=== 4. SELECCION ===';

DECLARE @id_pais_arg INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');
DECLARE @id_pais_bra INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Brasil');
DECLARE @id_chile    INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Chile');
DECLARE @id_sel_arg INT, @id_sel_bra INT, @id_pais_uru INT;

-- 4.1 Alta válida sin grupo
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @id_seleccion = @id_sel_arg OUTPUT;
IF @id_sel_arg IS NOT NULL PRINT 'OK 4.1 - Selección Argentina insertada';

-- 4.2 Alta válida con grupo
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_bra, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_bra OUTPUT;
IF @id_sel_bra IS NOT NULL PRINT 'OK 4.2 - Selección Brasil insertada en grupo A';

-- 4.3 ERROR: país inexistente
BEGIN TRY
    EXEC torneo.Seleccion_Insertar @id_pais = 99999, @confederacion = 'UEFA';
    PRINT 'FALLO 4.3 - Debio fallar por pais';
END TRY
BEGIN CATCH
    PRINT 'OK 4.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.4 ERROR: país ya tiene selección
BEGIN TRY
    EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL';
    PRINT 'FALLO 4.4 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 4.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.5 ERROR: confederación inválida
BEGIN TRY
    EXEC geo.Pais_Insertar @nombre = 'Chile', @id_pais = @id_pais_uru OUTPUT; -- (variable reutilizada)
END TRY
BEGIN CATCH END CATCH;
GO
DECLARE @id_chile INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Chile');
BEGIN TRY
    EXEC torneo.Seleccion_Insertar @id_pais = @id_chile, @confederacion = 'INVALIDO';
    PRINT 'FALLO 4.5 - Debio fallar por confederacion';
END TRY
BEGIN CATCH
    PRINT 'OK 4.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.6 ERROR: grupo inválido
BEGIN TRY
    EXEC torneo.Seleccion_Insertar @id_pais = @id_chile, @confederacion = 'CONMEBOL', @grupo = 'Z';
    PRINT 'FALLO 4.6 - Debio fallar por grupo';
END TRY
BEGIN CATCH
    PRINT 'OK 4.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.7 ERROR: grupo ya completo (4 selecciones)
-- Insertar 3 selecciones más en grupo A y probar la quinta
DECLARE @p1 INT, @p2 INT, @p3 INT, @p4 INT;
EXEC geo.Pais_Insertar @nombre = 'Perú', @id_pais = @p1 OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Colombia', @id_pais = @p2 OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Ecuador', @id_pais = @p3 OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Paraguay', @id_pais = @p4 OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @p1, @confederacion = 'CONMEBOL', @grupo = 'A';
EXEC torneo.Seleccion_Insertar @id_pais = @p2, @confederacion = 'CONMEBOL', @grupo = 'A';
EXEC torneo.Seleccion_Insertar @id_pais = @p3, @confederacion = 'CONMEBOL', @grupo = 'A';
BEGIN TRY
    EXEC torneo.Seleccion_Insertar @id_pais = @p4, @confederacion = 'CONMEBOL', @grupo = 'A';
    PRINT 'FALLO 4.7 - Falla por grupo lleno';
END TRY
BEGIN CATCH
    PRINT 'OK 4.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.8 Modificación válida
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais=s.id_pais WHERE p.nombre='Argentina');
DECLARE @id_pais_arg INT = (SELECT id_pais FROM geo.Pais WHERE nombre='Argentina');
EXEC torneo.Seleccion_Modificar @id_seleccion = @id_sel_arg, @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @grupo = 'B';
PRINT 'OK 4.8 - Selección Argentina modificada';

-- 4.9 ERROR: modificar selección inexistente
BEGIN TRY
    EXEC torneo.Seleccion_Modificar @id_seleccion = 99999, @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL';
    PRINT 'FALLO 4.9 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 4.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 5. SEDE
PRINT '=== 5. SEDE ===';

DECLARE @id_ciudad_ba INT = (SELECT id_ciudad FROM geo.Ciudad WHERE nombre = 'CABA');
DECLARE @id_ciudad_rio INT = (SELECT id_ciudad FROM geo.Ciudad WHERE nombre = 'Río de Janeiro');
DECLARE @id_sede_monumental INT, @id_sede_maracana INT;

-- 5.1 Alta válida
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede_monumental OUTPUT;
IF @id_sede_monumental IS NOT NULL PRINT 'OK 5.1 - Monumental insertada';
ELSE PRINT 'FALLO 5.1';

-- 5.2 Alta válida
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_rio, @nombre_estadio = 'Maracaná', @capacidad = 78000, @id_sede = @id_sede_maracana OUTPUT;
IF @id_sede_maracana IS NOT NULL PRINT 'OK 5.2 - Maracaná insertada';

-- 5.3 ERROR: ciudad inexistente
BEGIN TRY
    EXEC torneo.Sede_Insertar @id_ciudad = 99999, @nombre_estadio = 'X', @capacidad = 1000;
    PRINT 'FALLO 5.3 - Debio fallar por ciudad';
END TRY
BEGIN CATCH
    PRINT 'OK 5.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.4 ERROR: capacidad <= 0
BEGIN TRY
    EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'X', @capacidad = 0;
    PRINT 'FALLO 5.4 - Debio fallar por capacidad';
END TRY
BEGIN CATCH
    PRINT 'OK 5.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.5 ERROR: nombre vacío
BEGIN TRY
    EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = '   ', @capacidad = 1000;
    PRINT 'FALLO 5.5 - Debio fallar por nombre';
END TRY
BEGIN CATCH
    PRINT 'OK 5.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.6 ERROR: estadio duplicado en la misma ciudad
BEGIN TRY
    EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 50000;
    PRINT 'FALLO 5.6 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 5.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.7 Modificación válida
EXEC torneo.Sede_Modificar @id_sede = @id_sede_monumental, @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 72000;
PRINT 'OK 5.7 - Sede modificada';

-- 5.8 ERROR: modificar sede inexistente
BEGIN TRY
    EXEC torneo.Sede_Modificar @id_sede = 99999, @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'X', @capacidad = 1000;
    PRINT 'FALLO 5.8 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 5.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.9 Eliminación válida (Maracaná sin partidos)
EXEC torneo.Sede_Eliminar @id_sede = @id_sede_maracana;
IF NOT EXISTS (SELECT 1 FROM torneo.Sede WHERE id_sede = @id_sede_maracana)
    PRINT 'OK 5.9 - Maracaná eliminada';
ELSE PRINT 'FALLO 5.9';

-- 5.10 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Sede_Eliminar @id_sede = 99999;
    PRINT 'FALLO 5.10 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 5.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 6. CLUB
PRINT '=== 6. CLUB ===';

DECLARE @id_club_river INT, @id_club_boca INT;

-- 6.1 Alta válida
EXEC personas.Club_Insertar @nombre = 'River Plate', @id_club = @id_club_river OUTPUT;
IF @id_club_river IS NOT NULL PRINT 'OK 6.1 - River insertado';
ELSE PRINT 'FALLO 6.1';

-- 6.2 Alta válida
EXEC personas.Club_Insertar @nombre = 'Boca Juniors', @id_club = @id_club_boca OUTPUT;
IF @id_club_boca IS NOT NULL PRINT 'OK 6.2 - Boca insertado';

-- 6.3 ERROR: nombre nulo
BEGIN TRY
    EXEC personas.Club_Insertar @nombre = NULL;
    PRINT 'FALLO 6.3 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 6.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.4 ERROR: nombre duplicado
BEGIN TRY
    EXEC personas.Club_Insertar @nombre = 'River Plate';
    PRINT 'FALLO 6.4 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 6.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.5 Modificación válida
EXEC personas.Club_Modificar @id_club = @id_club_river, @nombre = 'River Plate FC';
PRINT 'OK 6.5 - Club modificado';

-- 6.6 ERROR: modificar inexistente
BEGIN TRY
    EXEC personas.Club_Modificar @id_club = 99999, @nombre = 'X';
    PRINT 'FALLO 6.6 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 6.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.7 ERROR: modificar a nombre duplicado
BEGIN TRY
    EXEC personas.Club_Modificar @id_club = @id_club_boca, @nombre = 'River Plate FC';
    PRINT 'FALLO 6.7 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 6.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.8 Eliminación válida
EXEC personas.Club_Eliminar @id_club = @id_club_boca;
IF NOT EXISTS (SELECT 1 FROM personas.Club WHERE id_club = @id_club_boca)
    PRINT 'OK 6.8 - Boca eliminado';
ELSE PRINT 'FALLO 6.8';

-- 6.9 ERROR: eliminar inexistente
BEGIN TRY
    EXEC personas.Club_Eliminar @id_club = 99999;
    PRINT 'FALLO 6.9 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 6.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 7. PARAMETRO
PRINT '=== 7. PARAMETRO ===';

-- 7.1 Alta válida
EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 26, @descripcion = 'Máximo de jugadores convocados';
PRINT 'OK 7.1 - Parametro MAX_CONVOCADOS insertado';

-- 7.2 Alta válida
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11, @descripcion = 'Titulares por partido';
PRINT 'OK 7.2 - Parametro MAX_TITULARES insertado';

-- 7.3 ERROR: clave duplicada
BEGIN TRY
    EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 23;
    PRINT 'FALLO 7.3 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 7.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.4 ERROR: valor negativo
BEGIN TRY
    EXEC torneo.Parametro_Insertar @clave = 'X', @valor = -1;
    PRINT 'FALLO 7.4 - Debio fallar por valor';
END TRY
BEGIN CATCH
    PRINT 'OK 7.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.5 ERROR: clave vacía
BEGIN TRY
    EXEC torneo.Parametro_Insertar @clave = '   ', @valor = 1;
    PRINT 'FALLO 7.5 - Debio fallar por clave';
END TRY
BEGIN CATCH
    PRINT 'OK 7.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.6 Modificación válida
EXEC torneo.Parametro_Modificar @clave = 'MAX_CONVOCADOS', @valor = 23, @descripcion = 'Actualizado';
PRINT 'OK 7.6 - Parametro modificado';

-- 7.7 ERROR: modificar inexistente
BEGIN TRY
    EXEC torneo.Parametro_Modificar @clave = 'NO_EXISTE', @valor = 1;
    PRINT 'FALLO 7.7 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 7.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.8 Eliminación válida
EXEC torneo.Parametro_Eliminar @clave = 'MAX_TITULARES';
IF NOT EXISTS (SELECT 1 FROM torneo.Parametro WHERE clave = 'MAX_TITULARES')
    PRINT 'OK 7.8 - Parametro eliminado';
ELSE PRINT 'FALLO 7.8';

-- 7.9 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Parametro_Eliminar @clave = 'NO_EXISTE';
    PRINT 'FALLO 7.9 - Debio fallar';
END TRY
BEGIN CATCH
    PRINT 'OK 7.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-- LIMPIEZA FINAL
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.ContenidoPais;
DELETE FROM publicidad.Contenido;
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;

DELETE FROM torneo.Parametro;
DELETE FROM torneo.Suspension;
DELETE FROM torneo.Expulsion;
DELETE FROM torneo.Sancion;
DELETE FROM torneo.Gol;
DELETE FROM torneo.Sustitucion;
DELETE FROM torneo.FormacionSuplente;
DELETE FROM torneo.FormacionTitular;
DELETE FROM torneo.PartidoFormacion;
DELETE FROM torneo.Formacion;
DELETE FROM torneo.ArbitroSecundario;
DELETE FROM torneo.Partido;
DELETE FROM torneo.Sede;
DELETE FROM torneo.ReemplazoConvocatoria;
DELETE FROM personas.Ayudante;
DELETE FROM personas.DirectorTecnico;
DELETE FROM personas.ArbitroIdioma;
DELETE FROM personas.Arbitro;
DELETE FROM personas.Jugador;
DELETE FROM personas.Club;
DELETE FROM personas.Participante;
DELETE FROM torneo.Seleccion;
DELETE FROM geo.Ciudad;
DELETE FROM geo.Pais;
DELETE FROM geo.Idioma;
GO

DBCC CHECKIDENT('geo.Idioma' , RESEED, 0)
DBCC CHECKIDENT('geo.Pais' , RESEED, 0)
DBCC CHECKIDENT('geo.Ciudad' , RESEED, 0)
DBCC CHECKIDENT('torneo.Seleccion' , RESEED, 0)
DBCC CHECKIDENT('personas.Club' , RESEED, 0)
DBCC CHECKIDENT('torneo.Sede' , RESEED, 0)
GO