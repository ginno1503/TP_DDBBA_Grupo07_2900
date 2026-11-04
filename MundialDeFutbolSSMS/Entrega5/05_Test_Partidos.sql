/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 25/10/2026
   Objetivo     : Script de testing para 05_SP_ABM_Partidos.sql
                  Prueba altas, modificaciones y bajas de Partido, Formacion,
                  FormacionTitular, FormacionSuplente y PartidoFormacion,
                  incluyendo cálculo de hora UTC, validación de árbitros por
                  nacionalidad y jugadores suspendidos.
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

-- SETUP: datos base
PRINT '=== SETUP: datos base ===';

DECLARE @id_pais_arg INT, @id_pais_bra INT, @id_pais_uru INT, @id_pais_chi INT;
DECLARE @id_ciudad_ba INT, @id_ciudad_rio INT;
DECLARE @id_sede_monumental INT, @id_sede_maracana INT;
DECLARE @id_sel_arg INT, @id_sel_bra INT, @id_sel_uru INT, @id_sel_chi INT;
DECLARE @id_club_river INT;
DECLARE @id_arb_arg INT, @id_arb_bra INT, @id_arb_uru INT;

-- Países
EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @pbi_per_capita = 14000.00, @id_pais = @id_pais_arg OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil', @huso_horario = -3.00, @pbi_per_capita = 10000.00, @id_pais = @id_pais_bra OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Uruguay', @huso_horario = -3.00, @pbi_per_capita = 17000.00, @id_pais = @id_pais_uru OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Chile', @huso_horario = -4.00, @pbi_per_capita = 15000.00, @id_pais = @id_pais_chi OUTPUT;

-- Ciudades (Buenos Aires UTC-3, Río UTC-3)
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00, @id_ciudad = @id_ciudad_ba OUTPUT;
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_bra, @nombre = 'Río de Janeiro', @huso_horario = -3.00, @id_ciudad = @id_ciudad_rio OUTPUT;

-- Sedes
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede_monumental OUTPUT;
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_rio, @nombre_estadio = 'Maracaná', @capacidad = 78000, @id_sede = @id_sede_maracana OUTPUT;

-- Selecciones (todas en grupo A para poder enfrentarse)
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_arg OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_bra, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_bra OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_uru, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_uru OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_chi, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_chi OUTPUT;

-- Club
EXEC personas.Club_Insertar @nombre = 'River Plate', @id_club = @id_club_river OUTPUT;

-- Árbitros (uno por país, para probar conflicto de nacionalidad)
EXEC personas.Arbitro_Insertar @dni = '40111222', @nombre = 'Arbitro Argentino', @id_pais = @id_pais_arg, @categoria = 'FIFA', @id_participante = @id_arb_arg OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40222333', @nombre = 'Arbitro Brasilero', @id_pais = @id_pais_bra, @categoria = 'FIFA', @id_participante = @id_arb_bra OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40333444', @nombre = 'Arbitro Uruguayo', @id_pais = @id_pais_uru, @categoria = 'FIFA', @id_participante = @id_arb_uru OUTPUT;

-- Parámetros
EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 26, @descripcion = 'Máximo de convocados';
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11, @descripcion = 'Titulares por partido';
EXEC torneo.Parametro_Insertar @clave = 'MAX_SUPLENTES', @valor = 15, @descripcion = 'Suplentes por partido';
EXEC torneo.Parametro_Insertar @clave = 'AMARILLAS_PARA_SUSPENSION', @valor = 2, @descripcion = 'Amarillas para suspender';

PRINT 'OK SETUP - Datos base cargados';
GO

-------------------------------------- 1. PARTIDO
PRINT '=== 1. PARTIDO ===';

DECLARE @id_part1 INT, @id_part2 INT, @id_part3 INT, @id_part4 INT;
DECLARE @id_sede_monumental INT = (SELECT id_sede FROM torneo.Sede WHERE nombre_estadio = 'Monumental');
DECLARE @id_sede_maracana INT = (SELECT id_sede FROM torneo.Sede WHERE nombre_estadio = 'Maracaná');
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @id_sel_uru INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Uruguay');
DECLARE @id_sel_chi INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Chile');
DECLARE @id_arb_arg INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Argentino');
DECLARE @id_arb_bra INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Brasilero');
DECLARE @id_arb_uru INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Uruguayo');

-- 1.1 Alta válida (fase de grupos, mismo grupo, sin conflicto de nacionalidad)
--      Buenos Aires UTC-3, horario local 16:00 -> UTC 19:00
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
    @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra,
    @asistencia = 60000, @id_arbitro_principal = @id_arb_uru, @id_arbitro_var = NULL,
    @id_partido = @id_part1 OUTPUT;
IF @id_part1 IS NOT NULL PRINT 'OK 1.1 - Partido insertado con id=' + CAST(@id_part1 AS VARCHAR);
ELSE PRINT 'FALLO 1.1';

-- Verificar cálculo UTC (16:00 local -3 = 19:00 UTC)
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_part1 AND fecha_hora_utc = '2026-06-10 19:00:00')
    PRINT 'OK 1.1b - Hora UTC calculada correctamente (19:00)';
ELSE
BEGIN
    DECLARE @utc1 DATETIME2(0) = (SELECT fecha_hora_utc FROM torneo.Partido WHERE id_partido = @id_part1);
    PRINT 'FALLO 1.1b - Hora UTC incorrecta: ' + ISNULL(CAST(@utc1 AS VARCHAR), 'NULL');
END

-- 1.2 Alta válida con árbitro VAR
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_maracana, @fase = 'GRUPOS', @fecha = '2026-06-11', @horario = '18:00',
    @id_seleccion_1 = @id_sel_uru, @id_seleccion_2 = @id_sel_chi,
    @asistencia = 50000, @id_arbitro_principal = @id_arb_bra, @id_arbitro_var = @id_arb_arg,
    @id_partido = @id_part2 OUTPUT;
IF @id_part2 IS NOT NULL PRINT 'OK 1.2 - Partido con VAR insertado';
ELSE PRINT 'FALLO 1.2';

-- 1.3 ERROR: sede inexistente
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = 99999, @fase = 'GRUPOS', @fecha = '2026-06-12', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra;
    PRINT 'FALLO 1.3 - Debio fallar por sede';
END TRY
BEGIN CATCH
    PRINT 'OK 1.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.4 ERROR: fase inválida
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'INVALIDA', @fecha = '2026-06-12', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra;
    PRINT 'FALLO 1.4 - Debio fallar por fase';
END TRY
BEGIN CATCH
    PRINT 'OK 1.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.5 ERROR: fecha/horario nulos
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = NULL, @horario = NULL,
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra;
    PRINT 'FALLO 1.5 - Debio fallar por fecha/horario';
END TRY
BEGIN CATCH
    PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 ERROR: selección inexistente
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-12', @horario = '16:00',
        @id_seleccion_1 = 99999, @id_seleccion_2 = @id_sel_bra;
    PRINT 'FALLO 1.6 - Debio fallar por seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 1.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.7 ERROR: mismas selecciones
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-12', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_arg;
    PRINT 'FALLO 1.7 - Debio fallar por selecciones iguales';
END TRY
BEGIN CATCH
    PRINT 'OK 1.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.8 ERROR: fase grupos sin definir selecciones
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-12', @horario = '16:00',
        @id_seleccion_1 = NULL, @id_seleccion_2 = NULL;
    PRINT 'FALLO 1.8 - Debio fallar por selecciones nulas en grupos';
END TRY
BEGIN CATCH
    PRINT 'OK 1.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.9 ERROR: selecciones de distinto grupo en fase de grupos
-- Chile está en A; cambiamos Chile a otro grupo para probar
DECLARE @id_sel_chi_grupo INT = @id_sel_chi;
BEGIN TRY
    UPDATE torneo.Seleccion SET grupo = 'B' WHERE id_seleccion = @id_sel_chi_grupo;
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-12', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_chi_grupo;
    PRINT 'FALLO 1.9 - Debio fallar por distinto grupo';
    UPDATE torneo.Seleccion SET grupo = 'A' WHERE id_seleccion = @id_sel_chi_grupo;
END TRY
BEGIN CATCH
    UPDATE torneo.Seleccion SET grupo = 'A' WHERE id_seleccion = @id_sel_chi_grupo;
    PRINT 'OK 1.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.10 ERROR: duplicado (mismas selecciones en misma fase)
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-15', @horario = '10:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra;
    PRINT 'FALLO 1.10 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.11 ERROR: sede con partido en misma fecha/horario
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
        @id_seleccion_1 = @id_sel_uru, @id_seleccion_2 = @id_sel_chi;
    PRINT 'FALLO 1.11 - Debio fallar por sede ocupada';
END TRY
BEGIN CATCH
    PRINT 'OK 1.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.12 ERROR: asistencia mayor a capacidad
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-20', @horario = '16:00',
        @id_seleccion_1 = @id_sel_uru, @id_seleccion_2 = @id_sel_chi, @asistencia = 99999;
    PRINT 'FALLO 1.12 - Debio fallar por asistencia';
END TRY
BEGIN CATCH
    PRINT 'OK 1.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.13 ERROR: árbitro principal inexistente
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-20', @horario = '16:00',
        @id_seleccion_1 = @id_sel_uru, @id_seleccion_2 = @id_sel_chi, @id_arbitro_principal = 99999;
    PRINT 'FALLO 1.13 - Debio fallar por arbitro';
END TRY
BEGIN CATCH
    PRINT 'OK 1.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.14 ERROR: principal y VAR iguales
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-20', @horario = '16:00',
        @id_seleccion_1 = @id_sel_uru, @id_seleccion_2 = @id_sel_chi, @id_arbitro_principal = @id_arb_bra, @id_arbitro_var = @id_arb_bra;
    PRINT 'FALLO 1.14 - Debio fallar por arbitro igual';
END TRY
BEGIN CATCH
    PRINT 'OK 1.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.15 ERROR: conflicto de nacionalidad (árbitro argentino en partido de Argentina)
BEGIN TRY
    EXEC torneo.Partido_Insertar @id_sede = @id_sede_maracana, @fase = 'GRUPOS', @fecha = '2026-06-21', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_uru, @id_arbitro_principal = @id_arb_arg;
    PRINT 'FALLO 1.15 - Debio fallar por conflicto de nacionalidad';
END TRY
BEGIN CATCH
    PRINT 'OK 1.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.16 Modificación válida (cargar resultado)
EXEC torneo.Partido_Modificar
    @id_partido = @id_part1, @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
    @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra,
    @goles_1 = 2, @goles_2 = 1, @asistencia = 65000,
    @id_arbitro_principal = @id_arb_uru, @id_arbitro_var = NULL;
PRINT 'OK 1.16 - Partido modificado (resultado 2-1)';

-- 1.17 ERROR: modificar inexistente
BEGIN TRY
    EXEC torneo.Partido_Modificar @id_partido = 99999, @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra;
    PRINT 'FALLO 1.17 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.18 ERROR: resultado incompleto (solo goles_1)
BEGIN TRY
    EXEC torneo.Partido_Modificar @id_partido = @id_part1, @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
        @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra, @goles_1 = 3, @goles_2 = NULL;
    PRINT 'FALLO 1.18 - Debio fallar por resultado incompleto';
END TRY
BEGIN CATCH
    PRINT 'OK 1.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.19 Alta de partido para probar eliminación
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_maracana, @fase = 'OCTAVOS', @fecha = '2026-06-25', @horario = '20:00',
    @id_seleccion_1 = @id_sel_uru, @id_seleccion_2 = @id_sel_chi,
    @id_partido = @id_part3 OUTPUT;

-- 1.20 Eliminación válida (sin dependencias)
EXEC torneo.Partido_Eliminar @id_partido = @id_part3;
IF NOT EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @id_part3)
    PRINT 'OK 1.20 - Partido eliminado';
ELSE PRINT 'FALLO 1.20';

-- 1.21 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Partido_Eliminar @id_partido = 99999;
    PRINT 'FALLO 1.21 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.21 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 2. FORMACION
PRINT '=== 2. FORMACION ===';

DECLARE @id_form_arg INT, @id_form_bra INT, @id_form_temp INT;
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');

-- 2.1 Alta válida
EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_arg, @esquema_tactico = '4-3-3', @id_formacion = @id_form_arg OUTPUT;
IF @id_form_arg IS NOT NULL PRINT 'OK 2.1 - Formacion Argentina 4-3-3 insertada';
ELSE PRINT 'FALLO 2.1';

-- 2.2 Alta válida
EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_bra, @esquema_tactico = '4-4-2', @id_formacion = @id_form_bra OUTPUT;
IF @id_form_bra IS NOT NULL PRINT 'OK 2.2 - Formacion Brasil 4-4-2 insertada';
ELSE PRINT 'FALLO 2.2';

-- 2.3 ERROR: selección inexistente
BEGIN TRY
    EXEC torneo.Formacion_Insertar @id_seleccion = 99999, @esquema_tactico = '4-3-3';
    PRINT 'FALLO 2.3 - Debio fallar por seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 ERROR: esquema inválido
BEGIN TRY
    EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_arg, @esquema_tactico = 'INVALIDO';
    PRINT 'FALLO 2.4 - Debio fallar por esquema';
END TRY
BEGIN CATCH
    PRINT 'OK 2.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.5 ERROR: esquema nulo
BEGIN TRY
    EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_arg, @esquema_tactico = NULL;
    PRINT 'FALLO 2.5 - Debio fallar por esquema nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.6 Modificación válida
EXEC torneo.Formacion_Modificar @id_formacion = @id_form_arg, @esquema_tactico = '4-2-3-1';
PRINT 'OK 2.6 - Formacion modificada a 4-2-3-1';

-- 2.7 ERROR: modificar inexistente
BEGIN TRY
    EXEC torneo.Formacion_Modificar @id_formacion = 99999, @esquema_tactico = '4-3-3';
    PRINT 'FALLO 2.7 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.8 Alta de formación sin dependencias para probar baja
EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_arg, @esquema_tactico = '5-3-2', @id_formacion = @id_form_temp OUTPUT;

-- 2.9 Eliminación válida (sin titulares ni suplentes ni partidos)
EXEC torneo.Formacion_Eliminar @id_formacion = @id_form_temp;
IF NOT EXISTS (SELECT 1 FROM torneo.Formacion WHERE id_formacion = @id_form_temp)
    PRINT 'OK 2.9 - Formacion eliminada';
ELSE PRINT 'FALLO 2.9';

-- 2.10 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Formacion_Eliminar @id_formacion = 99999;
    PRINT 'FALLO 2.10 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 3. JUGADORES Y TITULARES / SUPLENTES
PRINT '=== 3. JUGADORES + TITULARES / SUPLENTES ===';

DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_club_river INT = (SELECT id_club FROM personas.Club WHERE nombre = 'River Plate');
DECLARE @id_form_arg INT = (SELECT f.id_formacion FROM torneo.Formacion f
                            JOIN torneo.Seleccion s ON s.id_seleccion = f.id_seleccion
                            JOIN geo.Pais p ON p.id_pais = s.id_pais
                            WHERE p.nombre = 'Argentina' AND f.esquema_tactico = '4-2-3-1');

-- 3.1 Crear 13 jugadores argentinos (11 titulares + 2 suplentes)
DECLARE @id_jug_t1 INT, @id_jug_t2 INT, @id_jug_t3 INT, @id_jug_t4 INT, @id_jug_t5 INT;
DECLARE @id_jug_t6 INT, @id_jug_t7 INT, @id_jug_t8 INT, @id_jug_t9 INT, @id_jug_t10 INT;
DECLARE @id_jug_t11 INT, @id_jug_s1 INT, @id_jug_s2 INT;

EXEC personas.Jugador_Insertar @dni = '80111001', @nombre = 'Titular 1', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 1, @posicion = 'ARQUERO', @id_participante = @id_jug_t1 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111002', @nombre = 'Titular 2', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 2, @posicion = 'DEFENSOR', @id_participante = @id_jug_t2 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111003', @nombre = 'Titular 3', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 3, @posicion = 'DEFENSOR', @id_participante = @id_jug_t3 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111004', @nombre = 'Titular 4', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 4, @posicion = 'DEFENSOR', @id_participante = @id_jug_t4 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111005', @nombre = 'Titular 5', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'DEFENSOR', @id_participante = @id_jug_t5 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111006', @nombre = 'Titular 6', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 6, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_t6 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111007', @nombre = 'Titular 7', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 7, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_t7 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111008', @nombre = 'Titular 8', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 8, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_t8 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111009', @nombre = 'Titular 9', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 9, @posicion = 'DELANTERO', @id_participante = @id_jug_t9 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111010', @nombre = 'Titular 10', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 10, @posicion = 'DELANTERO', @id_participante = @id_jug_t10 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111011', @nombre = 'Titular 11', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 11, @posicion = 'DELANTERO', @id_participante = @id_jug_t11 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111012', @nombre = 'Suplente 1', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 12, @posicion = 'ARQUERO', @id_participante = @id_jug_s1 OUTPUT;
EXEC personas.Jugador_Insertar @dni = '80111013', @nombre = 'Suplente 2', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 13, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_s2 OUTPUT;

PRINT 'OK 3.1 - 13 jugadores creados';

-- 3.2 Insertar 11 titulares
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t1, @posicion_cancha = 'ARQ', @dorsal_cancha = 1;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t2, @posicion_cancha = 'LD', @dorsal_cancha = 2;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t3, @posicion_cancha = 'DFC', @dorsal_cancha = 3;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t4, @posicion_cancha = 'DFC', @dorsal_cancha = 4;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t5, @posicion_cancha = 'LI', @dorsal_cancha = 5;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t6, @posicion_cancha = 'MCD', @dorsal_cancha = 6;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t7, @posicion_cancha = 'MC', @dorsal_cancha = 7;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t8, @posicion_cancha = 'MCO', @dorsal_cancha = 8;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t9, @posicion_cancha = 'EI', @dorsal_cancha = 9;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t10, @posicion_cancha = 'DC', @dorsal_cancha = 10;
EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t11, @posicion_cancha = 'ED', @dorsal_cancha = 11;
PRINT 'OK 3.2 - 11 titulares insertados';

-- 3.3 Insertar 2 suplentes
EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s1;
EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s2;
PRINT 'OK 3.3 - 2 suplentes insertados';

-- 3.4 ERROR: 12vo titular (supera MAX_TITULARES)
DECLARE @id_jug_extra INT;
EXEC personas.Jugador_Insertar @dni = '80111014', @nombre = 'Extra', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 14, @posicion = 'DELANTERO', @id_participante = @id_jug_extra OUTPUT;
BEGIN TRY
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_extra, @posicion_cancha = 'DC', @dorsal_cancha = 14;
    PRINT 'FALLO 3.4 - Debio fallar por max titulares';
END TRY
BEGIN CATCH
    PRINT 'OK 3.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.5 ERROR: jugador ya titular
BEGIN TRY
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t1, @posicion_cancha = 'ARQ', @dorsal_cancha = 20;
    PRINT 'FALLO 3.5 - Debio fallar por ya titular';
END TRY
BEGIN CATCH
    PRINT 'OK 3.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.6 ERROR: jugador ya en banco
BEGIN TRY
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s1, @posicion_cancha = 'ARQ', @dorsal_cancha = 20;
    PRINT 'FALLO 3.6 - Debio fallar por ya suplente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.7 ERROR: dorsal en cancha duplicado
BEGIN TRY
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_extra, @posicion_cancha = 'DC', @dorsal_cancha = 10;
    PRINT 'FALLO 3.7 - Debio fallar por dorsal duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 3.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.8 ERROR: jugador no convocado activo (no pertenece a la selección)
DECLARE @id_jug_ajeno INT;
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
EXEC personas.Jugador_Insertar @dni = '80111015', @nombre = 'Ajeno', @id_seleccion = @id_sel_bra, @id_club = @id_club_river, @nro_dorsal = 15, @posicion = 'DELANTERO', @id_participante = @id_jug_ajeno OUTPUT;
BEGIN TRY
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_ajeno, @posicion_cancha = 'DC', @dorsal_cancha = 15;
    PRINT 'FALLO 3.8 - Debio fallar por jugador ajeno';
END TRY
BEGIN CATCH
    PRINT 'OK 3.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.9 ERROR: jugador ya suplente en esa formación
BEGIN TRY
    EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s1;
    PRINT 'FALLO 3.9 - Debio fallar por ya suplente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.10 ERROR: suplente que ya es titular
BEGIN TRY
    EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t1;
    PRINT 'FALLO 3.10 - Debio fallar por ya titular';
END TRY
BEGIN CATCH
    PRINT 'OK 3.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.11 Modificación válida de titular
EXEC torneo.FormacionTitular_Modificar @id_formacion = @id_form_arg, @id_jugador = @id_jug_t9, @posicion_cancha = 'SD', @dorsal_cancha = 9;
PRINT 'OK 3.11 - Titular modificado';

-- 3.12 ERROR: modificar titular inexistente
BEGIN TRY
    EXEC torneo.FormacionTitular_Modificar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s1, @posicion_cancha = 'X', @dorsal_cancha = 50;
    PRINT 'FALLO 3.12 - Debio fallar por no titular';
END TRY
BEGIN CATCH
    PRINT 'OK 3.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.13 Eliminación válida de suplente (sin eventos)
EXEC torneo.FormacionSuplente_Eliminar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s2;
IF NOT EXISTS (SELECT 1 FROM torneo.FormacionSuplente WHERE id_formacion = @id_form_arg AND id_jugador = @id_jug_s2)
    PRINT 'OK 3.13 - Suplente eliminado';
ELSE PRINT 'FALLO 3.13';

-- 3.14 ERROR: eliminar suplente inexistente
BEGIN TRY
    EXEC torneo.FormacionSuplente_Eliminar @id_formacion = @id_form_arg, @id_jugador = @id_jug_s2;
    PRINT 'FALLO 3.14 - Debio fallar por no suplente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 4. PARTIDO FORMACION
PRINT '=== 4. PARTIDO FORMACION ===';

DECLARE @id_part1 INT = (SELECT TOP 1 id_partido FROM torneo.Partido p WHERE p.fase = 'GRUPOS' ORDER BY id_partido ASC);
DECLARE @id_part_bra_uru INT = (SELECT TOP 1 p.id_partido FROM torneo.Partido p
                               JOIN torneo.Seleccion s1 ON s1.id_seleccion = p.id_seleccion_1
                               JOIN torneo.Seleccion s2 ON s2.id_seleccion = p.id_seleccion_2
                               WHERE p.fase = 'GRUPOS' AND p.id_partido <> @id_part1
                               ORDER BY p.id_partido ASC);
DECLARE @id_form_arg INT = (SELECT f.id_formacion FROM torneo.Formacion f
                            JOIN torneo.Seleccion s ON s.id_seleccion = f.id_seleccion
                            JOIN geo.Pais p ON p.id_pais = s.id_pais
                            WHERE p.nombre = 'Argentina' AND f.esquema_tactico = '4-2-3-1');

-- 4.1 Alta válida
EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_part1, @id_formacion = @id_form_arg;
IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_part1 AND id_formacion = @id_form_arg)
    PRINT 'OK 4.1 - Formacion Argentina vinculada al partido';
ELSE PRINT 'FALLO 4.1';

-- 4.2 ERROR: partido inexistente
BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar @id_partido = 99999, @id_formacion = @id_form_arg;
    PRINT 'FALLO 4.2 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.3 ERROR: formación inexistente
BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_part1, @id_formacion = 99999;
    PRINT 'FALLO 4.3 - Debio fallar por formacion';
END TRY
BEGIN CATCH
    PRINT 'OK 4.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.4 ERROR: formación de selección que no juega el partido
DECLARE @id_sel_uru INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Uruguay');
DECLARE @id_form_uru INT;
EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_uru, @esquema_tactico = '4-4-2', @id_formacion = @id_form_uru OUTPUT;
BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_part1, @id_formacion = @id_form_uru;
    PRINT 'FALLO 4.4 - Debio fallar por seleccion ajena';
END TRY
BEGIN CATCH
    PRINT 'OK 4.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.5 ERROR: partido ya tiene formación de esa selección
BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_part1, @id_formacion = @id_form_arg;
    PRINT 'FALLO 4.5 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 4.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.6 ERROR: formación con menos de 11 titulares
DECLARE @id_form_incompleta INT;
DECLARE @id_sel_bra_46 INT;
DECLARE @id_club_river_46 INT;
DECLARE @id_jug_br INT;

SELECT @id_sel_bra_46 = s.id_seleccion
FROM torneo.Seleccion s
JOIN geo.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Brasil';

SELECT @id_club_river_46 = id_club FROM personas.Club WHERE nombre = 'River Plate';

EXEC torneo.Formacion_Insertar
    @id_seleccion = @id_sel_bra_46,
    @esquema_tactico = '4-3-3',
    @id_formacion = @id_form_incompleta OUTPUT;

EXEC personas.Jugador_Insertar
    @dni = '80111999',
    @nombre = 'Brasil 1',
    @id_seleccion = @id_sel_bra_46,
    @id_club = @id_club_river_46,
    @nro_dorsal = 1,
    @posicion = 'ARQUERO',
    @id_participante = @id_jug_br OUTPUT;

EXEC torneo.FormacionTitular_Insertar
    @id_formacion = @id_form_incompleta,
    @id_jugador = @id_jug_br,
    @posicion_cancha = 'ARQ',
    @dorsal_cancha = 1;

BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar
        @id_partido = @id_part1,
        @id_formacion = @id_form_incompleta;
    PRINT 'FALLO 4.6 - Debio fallar por formacion incompleta';
END TRY
BEGIN CATCH
    PRINT 'OK 4.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.7 Eliminación válida (sin eventos registrados)
EXEC torneo.PartidoFormacion_Eliminar @id_partido = @id_part1, @id_formacion = @id_form_arg;
IF NOT EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_part1 AND id_formacion = @id_form_arg)
    PRINT 'OK 4.7 - Vinculacion eliminada';
ELSE PRINT 'FALLO 4.7';

-- 4.8 ERROR: eliminar vinculación inexistente
BEGIN TRY
    EXEC torneo.PartidoFormacion_Eliminar @id_partido = @id_part1, @id_formacion = @id_form_arg;
    PRINT 'FALLO 4.8 - Debio fallar por no vinculada';
END TRY
BEGIN CATCH
    PRINT 'OK 4.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 5. JUGADOR SUSPENDIDO EN FORMACION
PRINT '=== 5. JUGADOR SUSPENDIDO ===';

DECLARE @id_part1 INT = (SELECT TOP 1 id_partido FROM torneo.Partido WHERE fase = 'GRUPOS' ORDER BY id_partido ASC);
DECLARE @id_form_arg INT = (SELECT f.id_formacion FROM torneo.Formacion f
                            JOIN torneo.Seleccion s ON s.id_seleccion = f.id_seleccion
                            JOIN geo.Pais p ON p.id_pais = s.id_pais
                            WHERE p.nombre = 'Argentina' AND f.esquema_tactico = '4-2-3-1');
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_sel_uru INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Uruguay');
DECLARE @id_sede_monumental INT = (SELECT id_sede FROM torneo.Sede WHERE nombre_estadio = 'Monumental');
DECLARE @id_jug_t9 INT = (SELECT jt.id_jugador FROM torneo.FormacionTitular jt WHERE jt.id_formacion = @id_form_arg AND jt.dorsal_cancha = 9);

--Crear expulsión + suspensión de un titular en el partido 1
--(Argentina vs Brasil, donde el jugador figura en la formación)
INSERT INTO torneo.Gol (id_partido, nro, id_jugador_autor, minuto, tipo, periodo)
VALUES (@id_part1, 1, @id_jug_t9, 10, 'JUGADA', 'PRIMER_TIEMPO');
INSERT INTO torneo.Sancion (id_partido, nro, id_jugador, color, minuto)
VALUES (@id_part1, 1, @id_jug_t9, 'ROJA', 20);
INSERT INTO torneo.Expulsion (id_partido, nro, id_jugador, causa)
VALUES (@id_part1, 1, @id_jug_t9, 'ROJA_DIRECTA');
INSERT INTO torneo.Suspension (id_jugador, id_partido_origen, motivo, partidos_a_cumplir)
VALUES (@id_jug_t9, @id_part1, 'ROJA_DIRECTA', 2);

--Crear un partido FUTURO de Argentina contra Uruguay (rival distinto de Brasil)
--para probar que el jugador suspendido no pueda ser alineado
DECLARE @id_part_futuro INT;
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-07-01', @horario = '16:00',
    @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_uru,
    @id_partido = @id_part_futuro OUTPUT;

-- 5.1 Verificar que fn_JugadorSuspendido devuelve 1 para el partido futuro
IF torneo.fn_JugadorSuspendido(@id_jug_t9, @id_part_futuro) = 1
    PRINT 'OK 5.1 - fn_JugadorSuspendido devuelve 1 para el proximo partido';
ELSE PRINT 'FALLO 5.1 - fn_JugadorSuspendido devolvio 0';

-- 5.2 Intentar vincular la formación (con el suspendido) al partido futuro debe fallar
BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_part_futuro, @id_formacion = @id_form_arg;
    PRINT 'FALLO 5.2 - Debio fallar por jugador suspendido';
END TRY
BEGIN CATCH
    PRINT 'OK 5.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

--Limpiar la suspensión (y sus eventos de origen) para permitir la vinculación
DELETE FROM torneo.Suspension WHERE id_jugador = @id_jug_t9;
DELETE FROM torneo.Expulsion WHERE id_partido = @id_part1 AND id_jugador = @id_jug_t9;
DELETE FROM torneo.Sancion WHERE id_partido = @id_part1 AND id_jugador = @id_jug_t9;
DELETE FROM torneo.Gol WHERE id_partido = @id_part1 AND id_jugador_autor = @id_jug_t9;

-- 5.3 Sin suspensión, la vinculación debe funcionar
BEGIN TRY
    EXEC torneo.PartidoFormacion_Insertar @id_partido = @id_part_futuro, @id_formacion = @id_form_arg;
    IF EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @id_part_futuro AND id_formacion = @id_form_arg)
        PRINT 'OK 5.3 - Sin suspension la vinculacion funciona';
    ELSE PRINT 'FALLO 5.3 - No se vinculo';
END TRY
BEGIN CATCH
    PRINT 'FALLO 5.3 - Error inesperado: ' + ERROR_MESSAGE();
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
GO

DBCC CHECKIDENT('torneo.Partido' , RESEED, 0)
DBCC CHECKIDENT('torneo.Formacion' , RESEED, 0)
DBCC CHECKIDENT('torneo.Suspension' , RESEED, 0)
GO
