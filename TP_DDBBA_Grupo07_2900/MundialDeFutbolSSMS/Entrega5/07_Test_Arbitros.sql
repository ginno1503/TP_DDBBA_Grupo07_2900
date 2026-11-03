/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 26/10/2026
   Objetivo     : Script de testing para 07_SP_ABM_Arbitros.sql
                  Prueba altas, modificaciones y bajas de ArbitroSecundario,
                  incluyendo casos de error (rol inválido, duplicados, conflicto
                  con principal/VAR, conflicto de nacionalidad y límites de
                  asistentes/cuarto árbitro).
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

-------------------------------------- SETUP
PRINT '=== SETUP: datos base ===';

DECLARE @id_pais_arg INT, @id_pais_bra INT, @id_pais_uru INT, @id_pais_chi INT;
DECLARE @id_pais_par INT, @id_pais_per INT, @id_pais_col INT;
DECLARE @id_ciudad_ba INT, @id_ciudad_rio INT;
DECLARE @id_sede_monumental INT, @id_sede_maracana INT;
DECLARE @id_sel_arg INT, @id_sel_bra INT, @id_sel_uru INT, @id_sel_chi INT;
DECLARE @id_arb_arg INT, @id_arb_bra INT, @id_arb_uru INT, @id_arb_chi INT;
DECLARE @id_arb_par INT, @id_arb_per INT, @id_arb_col INT;
DECLARE @id_part1 INT, @id_part2 INT;

-- Países
EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @pbi_per_capita = 14000.00, @id_pais = @id_pais_arg OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil', @huso_horario = -3.00, @pbi_per_capita = 10000.00, @id_pais = @id_pais_bra OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Uruguay', @huso_horario = -3.00, @pbi_per_capita = 17000.00, @id_pais = @id_pais_uru OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Chile', @huso_horario = -4.00, @pbi_per_capita = 15000.00, @id_pais = @id_pais_chi OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Paraguay', @huso_horario = -4.00, @pbi_per_capita = 6000.00, @id_pais = @id_pais_par OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Perú', @huso_horario = -5.00, @pbi_per_capita = 7000.00, @id_pais = @id_pais_per OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Colombia', @huso_horario = -5.00, @pbi_per_capita = 8000.00, @id_pais = @id_pais_col OUTPUT;

-- Ciudades
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00, @id_ciudad = @id_ciudad_ba OUTPUT;
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_bra, @nombre = 'Río de Janeiro', @huso_horario = -3.00, @id_ciudad = @id_ciudad_rio OUTPUT;

-- Sedes
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede_monumental OUTPUT;
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_rio, @nombre_estadio = 'Maracaná', @capacidad = 78000, @id_sede = @id_sede_maracana OUTPUT;

-- Selecciones (grupo A)
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_arg OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_bra, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_bra OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_uru, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_uru OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_chi, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_chi OUTPUT;

-- Árbitros (uno por país, todos FIFA)
EXEC personas.Arbitro_Insertar @dni = '40110001', @nombre = 'Arbitro Argentino', @id_pais = @id_pais_arg, @categoria = 'FIFA', @id_participante = @id_arb_arg OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40110002', @nombre = 'Arbitro Brasilero', @id_pais = @id_pais_bra, @categoria = 'FIFA', @id_participante = @id_arb_bra OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40110003', @nombre = 'Arbitro Uruguayo', @id_pais = @id_pais_uru, @categoria = 'FIFA', @id_participante = @id_arb_uru OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40110004', @nombre = 'Arbitro Chileno', @id_pais = @id_pais_chi, @categoria = 'FIFA', @id_participante = @id_arb_chi OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40110005', @nombre = 'Arbitro Paraguayo', @id_pais = @id_pais_par, @categoria = 'CONFEDERACION', @id_participante = @id_arb_par OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40110006', @nombre = 'Arbitro Peruano', @id_pais = @id_pais_per, @categoria = 'CONFEDERACION', @id_participante = @id_arb_per OUTPUT;
EXEC personas.Arbitro_Insertar @dni = '40110007', @nombre = 'Arbitro Colombiano', @id_pais = @id_pais_col, @categoria = 'CONFEDERACION', @id_participante = @id_arb_col OUTPUT;

-- Parámetros básicos
EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 26, @descripcion = 'Máximo de convocados';
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11, @descripcion = 'Titulares';
EXEC torneo.Parametro_Insertar @clave = 'MAX_SUPLENTES', @valor = 15, @descripcion = 'Suplentes';
EXEC torneo.Parametro_Insertar @clave = 'AMARILLAS_PARA_SUSPENSION', @valor = 2, @descripcion = 'Amarillas para suspender';

-- Partido 1: Argentina vs Brasil, principal Uruguayo, VAR Chileno (ningún conflicto de nacionalidad)
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
    @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra,
    @id_arbitro_principal = @id_arb_uru, @id_arbitro_var = @id_arb_chi,
    @id_partido = @id_part1 OUTPUT;

-- Partido 2: Argentina vs Uruguay, principal Brasilero, sin VAR
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_maracana, @fase = 'OCTAVOS', @fecha = '2026-06-20', @horario = '18:00',
    @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_uru,
    @id_arbitro_principal = @id_arb_bra, @id_arbitro_var = NULL,
    @id_partido = @id_part2 OUTPUT;

IF @id_part1 IS NOT NULL AND @id_part2 IS NOT NULL
    PRINT 'OK SETUP - Datos base cargados (7 árbitros, 2 partidos)';
ELSE PRINT 'FALLO SETUP - Revisar los datos base';
GO

-------------------------------------- 1. ARBITRO SECUNDARIO - INSERTAR
PRINT '=== 1. ARBITRO SECUNDARIO - INSERTAR ===';

DECLARE @id_part1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @id_part2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @id_arb_arg INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Argentino');
DECLARE @id_arb_bra INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Brasilero');
DECLARE @id_arb_uru INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Uruguayo');
DECLARE @id_arb_chi INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Chileno');
DECLARE @id_arb_par INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Paraguayo');
DECLARE @id_arb_per INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Peruano');
DECLARE @id_arb_col INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Colombiano');

-- 1.1 Alta válida: primer asistente (Paraguayo, sin conflicto en Arg-Bra)
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'ASISTENTE';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_par AND rol = 'ASISTENTE')
    PRINT 'OK 1.1 - Primer asistente insertado';
ELSE PRINT 'FALLO 1.1';

-- 1.2 Alta válida: segundo asistente (Peruano)
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_per, @rol = 'ASISTENTE';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_per AND rol = 'ASISTENTE')
    PRINT 'OK 1.2 - Segundo asistente insertado';
ELSE PRINT 'FALLO 1.2';

-- 1.3 Alta válida: cuarto árbitro (Colombiano)
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_col, @rol = 'CUARTO';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_col AND rol = 'CUARTO')
    PRINT 'OK 1.3 - Cuarto árbitro insertado';
ELSE PRINT 'FALLO 1.3';

-- 1.4 ERROR: partido inexistente
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = 99999, @id_arbitro = @id_arb_par, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.4 - Debio fallar por partido inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.5 ERROR: árbitro inexistente
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = 99999, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.5 - Debio fallar por arbitro inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 ERROR: rol inválido
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'INVALIDO';
    PRINT 'FALLO 1.6 - Debio fallar por rol invalido';
END TRY
BEGIN CATCH
    PRINT 'OK 1.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.7 ERROR: rol nulo
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = NULL;
    PRINT 'FALLO 1.7 - Debio fallar por rol nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.8 ERROR: árbitro ya designado como secundario en el partido
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'CUARTO';
    PRINT 'FALLO 1.8 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.9 ERROR: árbitro es el principal del partido (Uruguayo en partido 1)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_uru, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.9 - Debio fallar por ser principal';
END TRY
BEGIN CATCH
    PRINT 'OK 1.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.10 ERROR: árbitro es el VAR del partido (Chileno en partido 1)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_chi, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.10 - Debio fallar por ser VAR';
END TRY
BEGIN CATCH
    PRINT 'OK 1.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.11 ERROR: conflicto de nacionalidad (Argentino en partido Argentina vs Brasil)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_arg, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.11 - Debio fallar por conflicto de nacionalidad';
END TRY
BEGIN CATCH
    PRINT 'OK 1.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.12 ERROR: conflicto de nacionalidad (Brasilero en partido Argentina vs Brasil)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_bra, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.12 - Debio fallar por conflicto de nacionalidad';
END TRY
BEGIN CATCH
    PRINT 'OK 1.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.13 ERROR: tercer asistente (ya hay dos)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_chi, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.13 - Debio fallar por maximo de asistentes';
END TRY
BEGIN CATCH
    PRINT 'OK 1.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.14 ERROR: segundo cuarto árbitro (ya hay uno)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_chi, @rol = 'CUARTO';
    PRINT 'FALLO 1.14 - Debio fallar por cuarto ya designado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.15 Alta válida en el partido 2 (sin VAR): asistente Argentino con partido Arg-Uru
--      (Argentina juega, así que el Argentino NO puede; probamos con Colombiano)
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part2, @id_arbitro = @id_arb_col, @rol = 'ASISTENTE';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part2 AND id_arbitro = @id_arb_col AND rol = 'ASISTENTE')
    PRINT 'OK 1.15 - Asistente insertado en partido 2';
ELSE PRINT 'FALLO 1.15';

-- 1.16 ERROR: conflicto de nacionalidad en partido 2 (Uruguayo en Arg-Uru)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part2, @id_arbitro = @id_arb_uru, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.16 - Debio fallar por conflicto de nacionalidad (Uruguay juega)';
END TRY
BEGIN CATCH
    PRINT 'OK 1.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.17 ERROR: conflicto de nacionalidad en partido 2 (Argentino en Arg-Uru)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part2, @id_arbitro = @id_arb_arg, @rol = 'ASISTENTE';
    PRINT 'FALLO 1.17 - Debio fallar por conflicto de nacionalidad (Argentina juega)';
END TRY
BEGIN CATCH
    PRINT 'OK 1.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.18 ERROR: árbitro es el principal del partido 2 (Brasilero)
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part2, @id_arbitro = @id_arb_bra, @rol = 'CUARTO';
    PRINT 'FALLO 1.18 - Debio fallar por ser principal';
END TRY
BEGIN CATCH
    PRINT 'OK 1.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.19 Alta válida: cuarto árbitro en partido 2 (Paraguayo)
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part2, @id_arbitro = @id_arb_par, @rol = 'CUARTO';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part2 AND id_arbitro = @id_arb_par AND rol = 'CUARTO')
    PRINT 'OK 1.19 - Cuarto árbitro insertado en partido 2';
ELSE PRINT 'FALLO 1.19';
GO

-------------------------------------- 2. ARBITRO SECUNDARIO - MODIFICAR
PRINT '=== 2. ARBITRO SECUNDARIO - MODIFICAR ===';

DECLARE @id_part1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @id_arb_par INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Paraguayo');
DECLARE @id_arb_col INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Colombiano');
DECLARE @id_arb_per INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Peruano');
DECLARE @id_arb_inexistente INT = @id_arb_col + 1000;

-- 2.1 Modificación válida: cambiar de ASISTENTE a CUARTO (Paraguayo)
--     Pero ya hay un CUARTO (Colombiano), así que debe fallar.
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'CUARTO';
    PRINT 'FALLO 2.1 - Debio fallar por cuarto ya designado';
END TRY
BEGIN CATCH
    PRINT 'OK 2.1 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.2 Modificación válida: cambiar de CUARTO a ASISTENTE al Colombiano
--     Pero ya hay dos asistentes (Paraguayo y Peruano), así que debe fallar.
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_col, @rol = 'ASISTENTE';
    PRINT 'FALLO 2.2 - Debio fallar por maximo de asistentes';
END TRY
BEGIN CATCH
    PRINT 'OK 2.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.3 ERROR: árbitro no es secundario del partido
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = 99999, @rol = 'ASISTENTE';
    PRINT 'FALLO 2.3 - Debio fallar por no ser secundario';
END TRY
BEGIN CATCH
    PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 ERROR: rol inválido
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'INVALIDO';
    PRINT 'FALLO 2.4 - Debio fallar por rol invalido';
END TRY
BEGIN CATCH
    PRINT 'OK 2.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.5 ERROR: rol nulo
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = NULL;
    PRINT 'FALLO 2.5 - Debio fallar por rol nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.6 Modificación válida: eliminar un asistente y luego cambiar el cuarto a asistente
EXEC torneo.ArbitroSecundario_Eliminar @id_partido = @id_part1, @id_arbitro = @id_arb_per;
EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_col, @rol = 'ASISTENTE';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_col AND rol = 'ASISTENTE')
    PRINT 'OK 2.6 - Rol modificado de CUARTO a ASISTENTE';
ELSE PRINT 'FALLO 2.6';

-- 2.7 Ahora que el Colombiano es ASISTENTE, verificar que el Paraguayo puede ser CUARTO
EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'CUARTO';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_par AND rol = 'CUARTO')
    PRINT 'OK 2.7 - Rol modificado de ASISTENTE a CUARTO';
ELSE PRINT 'FALLO 2.7';

-- 2.8 ERROR: intentar modificar un árbitro que no existe como secundario
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Modificar @id_partido = @id_part1, @id_arbitro = @id_arb_inexistente, @rol = 'ASISTENTE';
    PRINT 'FALLO 2.8 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 3. ARBITRO SECUNDARIO - ELIMINAR
PRINT '=== 3. ARBITRO SECUNDARIO - ELIMINAR ===';

DECLARE @id_part1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @id_part2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @id_arb_par INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Paraguayo');
DECLARE @id_arb_col INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Colombiano');

-- 3.1 Eliminación válida (Paraguayo, que ahora es CUARTO del partido 1)
EXEC torneo.ArbitroSecundario_Eliminar @id_partido = @id_part1, @id_arbitro = @id_arb_par;
IF NOT EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_par)
    PRINT 'OK 3.1 - Cuarto árbitro eliminado';
ELSE PRINT 'FALLO 3.1';

-- 3.2 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Eliminar @id_partido = @id_part1, @id_arbitro = @id_arb_par;
    PRINT 'FALLO 3.2 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.3 Eliminación válida (Colombiano, ASISTENTE del partido 1)
EXEC torneo.ArbitroSecundario_Eliminar @id_partido = @id_part1, @id_arbitro = @id_arb_col;
IF NOT EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_col)
    PRINT 'OK 3.3 - Asistente eliminado';
ELSE PRINT 'FALLO 3.3';

-- 3.4 ERROR: eliminar secundario de partido inexistente
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Eliminar @id_partido = 99999, @id_arbitro = @id_arb_col;
    PRINT 'FALLO 3.4 - Debio fallar por partido inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.5 Verificar que al eliminar un árbitro secundario, el partido queda sin ese rol
IF NOT EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1)
    PRINT 'OK 3.5 - Partido 1 sin árbitros secundarios';
ELSE PRINT 'FALLO 3.5';
GO

-------------------------------------- 4. CASOS ADICIONALES DE COHERENCIA
PRINT '=== 4. CASOS ADICIONALES DE COHERENCIA ===';

DECLARE @id_part1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @id_part2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @id_arb_par INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Paraguayo');
DECLARE @id_arb_per INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Peruano');
DECLARE @id_arb_col INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Colombiano');
DECLARE @id_arb_chi INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Chileno');

-- 4.1 Insertar asistentes y cuarto en partido 1 de nuevo
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'ASISTENTE';
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_per, @rol = 'ASISTENTE';
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_col, @rol = 'CUARTO';

-- 4.2 Verificar que hay exactamente 2 asistentes y 1 cuarto
IF (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND rol = 'ASISTENTE') = 2
    PRINT 'OK 4.2a - Dos asistentes designados';
ELSE PRINT 'FALLO 4.2a';
IF (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND rol = 'CUARTO') = 1
    PRINT 'OK 4.2b - Un cuarto árbitro designado';
ELSE PRINT 'FALLO 4.2b';

-- 4.3 ERROR: el mismo árbitro no puede ser asistente y cuarto a la vez en el mismo partido
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_par, @rol = 'CUARTO';
    PRINT 'FALLO 4.3 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 4.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.4 Eliminar un asistente y verificar que se puede insertar otro
EXEC torneo.ArbitroSecundario_Eliminar @id_partido = @id_part1, @id_arbitro = @id_arb_per;
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part1, @id_arbitro = @id_arb_per, @rol = 'ASISTENTE';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part1 AND id_arbitro = @id_arb_per AND rol = 'ASISTENTE')
    PRINT 'OK 4.4 - Nuevo asistente insertado tras eliminar uno';
ELSE PRINT 'FALLO 4.4';
GO

-------------------------------------- 5. ADVERTENCIA DE PAÍS EN COMPETENCIA
PRINT '=== 5. ADVERTENCIA DE PAÍS EN COMPETENCIA ===';

DECLARE @id_part2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @id_arb_col INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Arbitro Colombiano');

-- Limpiar la designación previa del Colombiano en el partido 2 (hecha en el caso 1.15)
-- para poder probar una inserción limpia en 5.1.
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part2 AND id_arbitro = @id_arb_col)
    EXEC torneo.ArbitroSecundario_Eliminar @id_partido = @id_part2, @id_arbitro = @id_arb_col;

-- 5.1 Insertar un árbitro de un país sin selección en competencia (Colombia) -> sin advertencia
--     (Colombia no tiene selección en este setup, así que fn_PaisSigueEnCompetencia = 0)
EXEC torneo.ArbitroSecundario_Insertar @id_partido = @id_part2, @id_arbitro = @id_arb_col, @rol = 'ASISTENTE';
IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_part2 AND id_arbitro = @id_arb_col)
    PRINT 'OK 5.1 - Asistente insertado (sin advertencia esperada)';
ELSE PRINT 'FALLO 5.1';

-- 5.2 Verificar que fn_PaisSigueEnCompetencia devuelve 0 para Colombia (sin selección)
DECLARE @id_pais_col INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Colombia');
IF torneo.fn_PaisSigueEnCompetencia(@id_pais_col) = 0
    PRINT 'OK 5.2 - fn_PaisSigueEnCompetencia = 0 para país sin selección';
ELSE PRINT 'FALLO 5.2';

-- 5.3 Verificar que fn_PaisSigueEnCompetencia devuelve 1 para Argentina (tiene selección y no perdió)
DECLARE @id_pais_arg INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');
IF torneo.fn_PaisSigueEnCompetencia(@id_pais_arg) = 1
    PRINT 'OK 5.3 - fn_PaisSigueEnCompetencia = 1 para Argentina';
ELSE PRINT 'FALLO 5.3';
GO

-------------------------------------- 6. VERIFICACIÓN DE INTEGRIDAD REFERENCIAL
PRINT '=== 6. VERIFICACIÓN DE INTEGRIDAD REFERENCIAL ===';

-- 6.1 No se puede insertar un secundario con un árbitro que no existe en personas.Arbitro
BEGIN TRY
    EXEC torneo.ArbitroSecundario_Insertar @id_partido = 1, @id_arbitro = 99999, @rol = 'ASISTENTE';
    PRINT 'FALLO 6.1 - Debio fallar por árbitro inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.1 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.2 Eliminar el partido debe fallar si tiene árbitros secundarios
BEGIN TRY
    DECLARE @id_part1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
    EXEC torneo.Partido_Eliminar @id_partido = @id_part1;
    PRINT 'FALLO 6.2 - Debio fallar por tener árbitros secundarios';
END TRY
BEGIN CATCH
    PRINT 'OK 6.2 - Error esperado: ' + ERROR_MESSAGE();
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

DBCC CHECKIDENT('geo.Pais' , RESEED, 0)
DBCC CHECKIDENT('geo.Ciudad' , RESEED, 0)
DBCC CHECKIDENT('torneo.Seleccion' , RESEED, 0)
DBCC CHECKIDENT('torneo.Sede' , RESEED, 0)
DBCC CHECKIDENT('personas.Club' , RESEED, 0)
DBCC CHECKIDENT('personas.Participante' , RESEED, 0)
DBCC CHECKIDENT('torneo.Partido' , RESEED, 0)
GO