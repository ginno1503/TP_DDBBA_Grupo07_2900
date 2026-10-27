/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 26/10/2026
   Objetivo     : Script de testing para 06_SP_ABM_Eventos.sql
                  Prueba altas, modificaciones y bajas de Sustitucion, Gol, Sancion,
                  Expulsion y Suspension, incluyendo casos de error (maximo de cambios,
                  ventanas, alargue, jugadores fuera de formacion, coherencia
                  tarjetas/expulsiones/suspensiones y fn_JugadorSuspendido).
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

DECLARE @id_pais_arg INT, @id_pais_bra INT, @id_ciudad_ba INT, @id_sede INT;
DECLARE @id_sel_arg INT, @id_sel_bra INT, @id_club INT, @id_form_arg INT, @id_form_bra INT;
DECLARE @p1 INT, @p2 INT, @i INT, @dni VARCHAR(20), @nom VARCHAR(100), @pos VARCHAR(15), @id INT;

EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 26, @descripcion = 'Maximo de convocados';
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11, @descripcion = 'Titulares por partido';
EXEC torneo.Parametro_Insertar @clave = 'MAX_SUPLENTES', @valor = 15, @descripcion = 'Suplentes por partido';
EXEC torneo.Parametro_Insertar @clave = 'AMARILLAS_PARA_SUSPENSION', @valor = 2, @descripcion = 'Amarillas para suspender';
EXEC torneo.Parametro_Insertar @clave = 'MAX_CAMBIOS', @valor = 5, @descripcion = 'Cambios por equipo';
EXEC torneo.Parametro_Insertar @clave = 'MAX_VENTANAS', @valor = 3, @descripcion = 'Ventanas de cambios por equipo';
EXEC torneo.Parametro_Insertar @clave = 'CAMBIOS_EXTRA_ALARGUE', @valor = 1, @descripcion = 'Cambios adicionales en alargue';

EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @id_pais = @id_pais_arg OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil', @huso_horario = -3.00, @id_pais = @id_pais_bra OUTPUT;
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00, @id_ciudad = @id_ciudad_ba OUTPUT;
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_arg OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_bra, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_bra OUTPUT;
EXEC personas.Club_Insertar @nombre = 'River Plate', @id_club = @id_club OUTPUT;

-- Jugadores Argentina (1 a 20)
SET @i = 1;
WHILE @i <= 20
BEGIN
    SET @dni = CONCAT('9010', RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4));
    SET @nom = CONCAT('ARG Jugador ', @i);
    SET @pos = CASE WHEN @i = 1 THEN 'ARQUERO' WHEN @i BETWEEN 2 AND 5 THEN 'DEFENSOR'
                    WHEN @i BETWEEN 6 AND 8 THEN 'MEDIOCAMPISTA' ELSE 'DELANTERO' END;
    EXEC personas.Jugador_Insertar @dni = @dni, @nombre = @nom, @id_seleccion = @id_sel_arg, @id_club = @id_club,
         @nro_dorsal = @i, @posicion = @pos, @id_participante = @id OUTPUT;
    SET @i += 1;
END;

-- Jugadores Brasil (1 a 13)
SET @i = 1;
WHILE @i <= 13
BEGIN
    SET @dni = CONCAT('9020', RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4));
    SET @nom = CONCAT('BRA Jugador ', @i);
    SET @pos = CASE WHEN @i = 1 THEN 'ARQUERO' WHEN @i BETWEEN 2 AND 5 THEN 'DEFENSOR'
                    WHEN @i BETWEEN 6 AND 8 THEN 'MEDIOCAMPISTA' ELSE 'DELANTERO' END;
    EXEC personas.Jugador_Insertar @dni = @dni, @nombre = @nom, @id_seleccion = @id_sel_bra, @id_club = @id_club,
         @nro_dorsal = @i, @posicion = @pos, @id_participante = @id OUTPUT;
    SET @i += 1;
END;

-- Formaciones
EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_arg, @esquema_tactico = '4-3-3', @id_formacion = @id_form_arg OUTPUT;
EXEC torneo.Formacion_Insertar @id_seleccion = @id_sel_bra, @esquema_tactico = '4-4-2', @id_formacion = @id_form_bra OUTPUT;

-- Titulares y suplentes Argentina
SET @i = 1;
WHILE @i <= 11
BEGIN
    SET @dni = CONCAT('9010', RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4));
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = @dni);
    SET @pos = CONCAT('POS', @i);
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_arg, @id_jugador = @id, @posicion_cancha = @pos, @dorsal_cancha = @i;
    SET @i += 1;
END;
SET @i = 12;
WHILE @i <= 19
BEGIN
    SET @dni = CONCAT('9010', RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4));
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = @dni);
    EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_form_arg, @id_jugador = @id;
    SET @i += 1;
END;

-- Titulares y suplentes Brasil
SET @i = 1;
WHILE @i <= 11
BEGIN
    SET @dni = CONCAT('9020', RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4));
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = @dni);
    SET @pos = CONCAT('POS', @i);
    EXEC torneo.FormacionTitular_Insertar @id_formacion = @id_form_bra, @id_jugador = @id, @posicion_cancha = @pos, @dorsal_cancha = @i;
    SET @i += 1;
END;
SET @i = 12;
WHILE @i <= 13
BEGIN
    SET @dni = CONCAT('9020', RIGHT('0000' + CAST(@i AS VARCHAR(4)), 4));
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = @dni);
    EXEC torneo.FormacionSuplente_Insertar @id_formacion = @id_form_bra, @id_jugador = @id;
    SET @i += 1;
END;

-- Partidos y vinculacion de formaciones
EXEC torneo.Partido_Insertar @id_sede = @id_sede, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
     @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra, @id_partido = @p1 OUTPUT;
EXEC torneo.Partido_Insertar @id_sede = @id_sede, @fase = 'OCTAVOS', @fecha = '2026-06-20', @horario = '16:00',
     @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra, @id_partido = @p2 OUTPUT;

EXEC torneo.PartidoFormacion_Insertar @id_partido = @p1, @id_formacion = @id_form_arg;
EXEC torneo.PartidoFormacion_Insertar @id_partido = @p1, @id_formacion = @id_form_bra;
EXEC torneo.PartidoFormacion_Insertar @id_partido = @p2, @id_formacion = @id_form_arg;
EXEC torneo.PartidoFormacion_Insertar @id_partido = @p2, @id_formacion = @id_form_bra;

IF (SELECT COUNT(*) FROM torneo.PartidoFormacion) = 4 AND (SELECT COUNT(*) FROM personas.Jugador) = 33
    PRINT 'OK SETUP - Datos base cargados (33 jugadores, 2 partidos, 4 formaciones vinculadas)';
ELSE PRINT 'FALLO SETUP - Revisar los datos base';
GO

-------------------------------------- 1. SUSTITUCION - INSERTAR
PRINT '=== 1. SUSTITUCION - INSERTAR ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a2  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100002');
DECLARE @a3  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100003');
DECLARE @a4  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100004');
DECLARE @a5  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100005');
DECLARE @a6  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100006');
DECLARE @a7  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100007');
DECLARE @a8  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100008');
DECLARE @a9  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100009');
DECLARE @a12 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100012');
DECLARE @a13 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100013');
DECLARE @a14 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100014');
DECLARE @a15 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100015');
DECLARE @a16 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100016');
DECLARE @a17 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100017');
DECLARE @a18 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100018');
DECLARE @a19 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100019');
DECLARE @a20 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100020');
DECLARE @b1  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200001');
DECLARE @b12 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200012');
DECLARE @b13 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200013');

-- 1.1 a 1.4 Altas validas (3 ventanas: min 60, 70 y 80)
EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 1, @id_jugador_sale = @a2, @id_jugador_entra = @a12, @minuto = 60, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 1) PRINT 'OK 1.1 - Cambio 1 insertado (ventana min 60)';
ELSE PRINT 'FALLO 1.1';

EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 2, @id_jugador_sale = @a3, @id_jugador_entra = @a13, @minuto = 60, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'LESION';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 2) PRINT 'OK 1.2 - Cambio 2 insertado (misma ventana min 60)';
ELSE PRINT 'FALLO 1.2';

EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 3, @id_jugador_sale = @a4, @id_jugador_entra = @a14, @minuto = 70, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'PRECAUCION';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 3) PRINT 'OK 1.3 - Cambio 3 insertado (ventana min 70)';
ELSE PRINT 'FALLO 1.3';

EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 4, @id_jugador_sale = @a5, @id_jugador_entra = @a15, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 4) PRINT 'OK 1.4 - Cambio 4 insertado (ventana min 80)';
ELSE PRINT 'FALLO 1.4';

-- 1.5 ERROR: cuarta ventana (min 85) -> supera MAX_VENTANAS
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 5, @id_jugador_sale = @a6, @id_jugador_entra = @a16, @minuto = 85, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.5 - Debio fallar por maximo de ventanas';
END TRY
BEGIN CATCH
    PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 Quinto cambio en una ventana ya usada (min 80): valido
EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 5, @id_jugador_sale = @a6, @id_jugador_entra = @a16, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 5) PRINT 'OK 1.6 - Cambio 5 insertado en ventana existente';
ELSE PRINT 'FALLO 1.6';

-- 1.7 ERROR: sexto cambio -> supera MAX_CAMBIOS
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 6, @id_jugador_sale = @a7, @id_jugador_entra = @a17, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.7 - Debio fallar por maximo de cambios';
END TRY
BEGIN CATCH
    PRINT 'OK 1.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.8 Cambio adicional en el alargue: valido aunque ya hizo 5
EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 7, @id_jugador_sale = @a7, @id_jugador_entra = @a17, @minuto = 100, @periodo = 'ALARGUE', @motivo = 'TACTICO';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 7) PRINT 'OK 1.8 - Cambio adicional en alargue insertado';
ELSE PRINT 'FALLO 1.8';

-- 1.9 ERROR: segundo cambio adicional en el alargue
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 8, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 110, @periodo = 'ALARGUE', @motivo = 'TACTICO';
    PRINT 'FALLO 1.9 - Debio fallar por cambio adicional ya usado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.10 Brasil: cambio valido (el banco de Brasil tiene 2 suplentes)
EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 10, @id_jugador_sale = @b1, @id_jugador_entra = @b12, @minuto = 46, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'LESION';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 10) PRINT 'OK 1.10 - Cambio de Brasil insertado';
ELSE PRINT 'FALLO 1.10';

-- 1.11 Un suplente que ya entro puede ser sustituido luego
EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 11, @id_jugador_sale = @b12, @id_jugador_entra = @b13, @minuto = 70, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'LESION';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 11) PRINT 'OK 1.11 - Suplente que habia entrado fue sustituido';
ELSE PRINT 'FALLO 1.11';

-- 1.12 ERROR: partido inexistente
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = 99999, @nro = 20, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.12 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 1.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.13 ERROR: numero de cambio repetido
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 1, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.13 - Debio fallar por nro repetido';
END TRY
BEGIN CATCH
    PRINT 'OK 1.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.14 ERROR: numero de cambio nulo
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = NULL, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.14 - Debio fallar por nro nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.15 ERROR: jugador que sale inexistente
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 21, @id_jugador_sale = 99999, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.15 - Debio fallar por jugador inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.16 ERROR: el mismo jugador sale y entra
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 22, @id_jugador_sale = @a8, @id_jugador_entra = @a8, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.16 - Debio fallar por mismo jugador';
END TRY
BEGIN CATCH
    PRINT 'OK 1.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.17 ERROR: jugadores de distinta seleccion (entra un suplente de Brasil)
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 23, @id_jugador_sale = @a8, @id_jugador_entra = @b13, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.17 - Debio fallar por distinta seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 1.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.18 ERROR: minuto fuera de rango
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 24, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 0, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.18 - Debio fallar por minuto 0';
END TRY
BEGIN CATCH
    PRINT 'OK 1.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 24, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 200, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.18b - Debio fallar por minuto 200';
END TRY
BEGIN CATCH
    PRINT 'OK 1.18b - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.19 ERROR: periodo invalido
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 25, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'INVALIDO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.19 - Debio fallar por periodo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.19 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.20 ERROR: motivo invalido
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 26, @id_jugador_sale = @a8, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'INVALIDO';
    PRINT 'FALLO 1.20 - Debio fallar por motivo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.20 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.21 ERROR: el que entra es titular (no esta en el banco)
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 27, @id_jugador_sale = @a8, @id_jugador_entra = @a9, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.21 - Debio fallar porque el que entra no es suplente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.21 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.22 ERROR: el que entra no figura en la formacion del partido
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 28, @id_jugador_sale = @a8, @id_jugador_entra = @a20, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.22 - Debio fallar porque el jugador no esta en el banco';
END TRY
BEGIN CATCH
    PRINT 'OK 1.22 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.23 ERROR: el que sale es un suplente que todavia no entro
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 29, @id_jugador_sale = @a19, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.23 - Debio fallar porque el que sale no esta en cancha';
END TRY
BEGIN CATCH
    PRINT 'OK 1.23 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.24 ERROR: el que sale ya habia sido sustituido
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 30, @id_jugador_sale = @a2, @id_jugador_entra = @a18, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.24 - Debio fallar porque ya fue sustituido';
END TRY
BEGIN CATCH
    PRINT 'OK 1.24 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.25 ERROR: el que entra ya participo de otro cambio
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 31, @id_jugador_sale = @a8, @id_jugador_entra = @a12, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 1.25 - Debio fallar porque el que entra ya participo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.25 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 2. SUSTITUCION - MODIFICAR
PRINT '=== 2. SUSTITUCION - MODIFICAR ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');

-- 2.1 Modificacion valida (cambio 3: minuto 70 -> 72)
EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 3, @minuto = 72, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'LESION';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 3 AND minuto = 72 AND motivo = 'LESION')
    PRINT 'OK 2.1 - Cambio modificado';
ELSE PRINT 'FALLO 2.1';

-- 2.2 ERROR: cambio inexistente
BEGIN TRY
    EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 99, @minuto = 50, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 2.2 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.3 ERROR: minuto invalido
BEGIN TRY
    EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 3, @minuto = 0, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 2.3 - Debio fallar por minuto';
END TRY
BEGIN CATCH
    PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 ERROR: periodo invalido
BEGIN TRY
    EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 3, @minuto = 72, @periodo = 'INVALIDO', @motivo = 'TACTICO';
    PRINT 'FALLO 2.4 - Debio fallar por periodo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.5 ERROR: motivo invalido
BEGIN TRY
    EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 3, @minuto = 72, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'INVALIDO';
    PRINT 'FALLO 2.5 - Debio fallar por motivo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.6 ERROR: el cambio 10 hace entrar a b12, que sale en el cambio 11 (min 70): no puede entrar despues (min 80)
BEGIN TRY
    EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 10, @minuto = 80, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'LESION';
    PRINT 'FALLO 2.6 - Debio fallar porque el que entra ya habia salido';
END TRY
BEGIN CATCH
    PRINT 'OK 2.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.7 Modificacion valida (cambio 10 a min 50, anterior a la salida de b12)
EXEC torneo.Sustitucion_Modificar @id_partido = @p1, @nro = 10, @minuto = 50, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'LESION';
IF EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 10 AND minuto = 50)
    PRINT 'OK 2.7 - Cambio 10 adelantado al min 50';
ELSE PRINT 'FALLO 2.7';
GO

-------------------------------------- 3. SUSTITUCION - ELIMINAR
PRINT '=== 3. SUSTITUCION - ELIMINAR ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');

-- 3.1 ERROR: el que entro en el cambio 10 fue sustituido despues (cambio 11)
BEGIN TRY
    EXEC torneo.Sustitucion_Eliminar @id_partido = @p1, @nro = 10;
    PRINT 'FALLO 3.1 - Debio fallar por dependencia';
END TRY
BEGIN CATCH
    PRINT 'OK 3.1 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.2 Eliminacion valida (primero el cambio dependiente)
EXEC torneo.Sustitucion_Eliminar @id_partido = @p1, @nro = 11;
IF NOT EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 11) PRINT 'OK 3.2 - Cambio 11 eliminado';
ELSE PRINT 'FALLO 3.2';

-- 3.3 Ahora si se puede eliminar el cambio 10
EXEC torneo.Sustitucion_Eliminar @id_partido = @p1, @nro = 10;
IF NOT EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 10) PRINT 'OK 3.3 - Cambio 10 eliminado';
ELSE PRINT 'FALLO 3.3';

-- 3.4 Eliminacion valida del cambio adicional del alargue
EXEC torneo.Sustitucion_Eliminar @id_partido = @p1, @nro = 7;
IF NOT EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 7) PRINT 'OK 3.4 - Cambio de alargue eliminado';
ELSE PRINT 'FALLO 3.4';

-- 3.5 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Sustitucion_Eliminar @id_partido = @p1, @nro = 99;
    PRINT 'FALLO 3.5 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 4. GOL
PRINT '=== 4. GOL ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a9  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100009');
DECLARE @a10 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100010');
DECLARE @a11 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100011');
DECLARE @a12 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100012');
DECLARE @a20 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100020');
DECLARE @b3  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200003');
DECLARE @b9  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200009');
DECLARE @b10 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200010');

-- 4.1 Gol con asistencia
EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 1, @id_jugador_autor = @a9, @id_jugador_asistente = @a10, @minuto = 15, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 1) PRINT 'OK 4.1 - Gol con asistencia insertado';
ELSE PRINT 'FALLO 4.1';

-- 4.2 Gol sin asistencia
EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 2, @id_jugador_autor = @a11, @minuto = 30, @tipo = 'PENAL', @periodo = 'PRIMER_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 2 AND id_jugador_asistente IS NULL) PRINT 'OK 4.2 - Gol sin asistencia insertado';
ELSE PRINT 'FALLO 4.2';

-- 4.3 Gol en contra (autor de Brasil, sin asistente)
EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 3, @id_jugador_autor = @b3, @minuto = 50, @tipo = 'EN_CONTRA', @periodo = 'SEGUNDO_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 3 AND tipo = 'EN_CONTRA') PRINT 'OK 4.3 - Gol en contra insertado';
ELSE PRINT 'FALLO 4.3';

-- 4.4 Gol de un suplente de la formacion
EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 4, @id_jugador_autor = @a12, @id_jugador_asistente = @a9, @minuto = 75, @tipo = 'CABEZAZO', @periodo = 'SEGUNDO_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 4) PRINT 'OK 4.4 - Gol de suplente insertado';
ELSE PRINT 'FALLO 4.4';

-- 4.5 Gol de Brasil
EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 5, @id_jugador_autor = @b9, @id_jugador_asistente = @b10, @minuto = 85, @tipo = 'TIRO_LIBRE', @periodo = 'SEGUNDO_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 5) PRINT 'OK 4.5 - Gol de Brasil insertado';
ELSE PRINT 'FALLO 4.5';

-- 4.6 Gol en la definicion por penales
EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 6, @id_jugador_autor = @b10, @minuto = 120, @tipo = 'PENAL', @periodo = 'DEFINICION_PENALES';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 6 AND periodo = 'DEFINICION_PENALES') PRINT 'OK 4.6 - Gol de definicion por penales insertado';
ELSE PRINT 'FALLO 4.6';

-- 4.7 ERROR: partido inexistente
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = 99999, @nro = 20, @id_jugador_autor = @a9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.7 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.8 ERROR: numero de gol repetido
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 1, @id_jugador_autor = @a9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.8 - Debio fallar por nro repetido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.9 ERROR: numero de gol nulo
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = NULL, @id_jugador_autor = @a9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.9 - Debio fallar por nro nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 4.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.10 ERROR: autor inexistente
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 21, @id_jugador_autor = 99999, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.10 - Debio fallar por autor';
END TRY
BEGIN CATCH
    PRINT 'OK 4.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.11 ERROR: asistente inexistente
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 22, @id_jugador_autor = @a9, @id_jugador_asistente = 99999, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.11 - Debio fallar por asistente';
END TRY
BEGIN CATCH
    PRINT 'OK 4.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.12 ERROR: minuto invalido
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 23, @id_jugador_autor = @a9, @minuto = 0, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.12 - Debio fallar por minuto';
END TRY
BEGIN CATCH
    PRINT 'OK 4.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.13 ERROR: tipo invalido
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 24, @id_jugador_autor = @a9, @minuto = 10, @tipo = 'INVALIDO', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.13 - Debio fallar por tipo';
END TRY
BEGIN CATCH
    PRINT 'OK 4.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.14 ERROR: periodo invalido
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 25, @id_jugador_autor = @a9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'INVALIDO';
    PRINT 'FALLO 4.14 - Debio fallar por periodo';
END TRY
BEGIN CATCH
    PRINT 'OK 4.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.15 ERROR: el autor no figura en las formaciones del partido
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 26, @id_jugador_autor = @a20, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.15 - Debio fallar porque el autor no esta en el partido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.16 ERROR: el asistente no figura en las formaciones del partido
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 27, @id_jugador_autor = @a9, @id_jugador_asistente = @a20, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.16 - Debio fallar porque el asistente no esta en el partido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.17 ERROR: asistente = autor
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 28, @id_jugador_autor = @a9, @id_jugador_asistente = @a9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.17 - Debio fallar por asistente = autor';
END TRY
BEGIN CATCH
    PRINT 'OK 4.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.18 ERROR: gol en contra con asistencia
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 29, @id_jugador_autor = @b3, @id_jugador_asistente = @a9, @minuto = 10, @tipo = 'EN_CONTRA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.18 - Debio fallar: gol en contra no tiene asistencia';
END TRY
BEGIN CATCH
    PRINT 'OK 4.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.19 ERROR: asistente de otra seleccion (gol que no es en contra)
BEGIN TRY
    EXEC torneo.Gol_Insertar @id_partido = @p1, @nro = 30, @id_jugador_autor = @a9, @id_jugador_asistente = @b9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.19 - Debio fallar por asistente de otra seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 4.19 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-------- Modificar
-- 4.20 Modificacion valida (gol 1: minuto 16)
EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @id_jugador_asistente = @a10, @minuto = 16, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 1 AND minuto = 16) PRINT 'OK 4.20 - Gol modificado';
ELSE PRINT 'FALLO 4.20';

-- 4.21 Modificacion valida (gol 2: se le agrega asistente y cambia el tipo)
EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 2, @id_jugador_asistente = @a10, @minuto = 31, @tipo = 'TIRO_LIBRE', @periodo = 'PRIMER_TIEMPO';
IF EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 2 AND id_jugador_asistente = @a10 AND tipo = 'TIRO_LIBRE') PRINT 'OK 4.21 - Gol modificado con asistente';
ELSE PRINT 'FALLO 4.21';

-- 4.22 ERROR: gol inexistente
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 99, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.22 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 4.22 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.23 ERROR: minuto invalido
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @minuto = 0, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.23 - Debio fallar por minuto';
END TRY
BEGIN CATCH
    PRINT 'OK 4.23 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.24 ERROR: tipo invalido
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @minuto = 10, @tipo = 'INVALIDO', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.24 - Debio fallar por tipo';
END TRY
BEGIN CATCH
    PRINT 'OK 4.24 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.25 ERROR: periodo invalido
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @minuto = 10, @tipo = 'JUGADA', @periodo = 'INVALIDO';
    PRINT 'FALLO 4.25 - Debio fallar por periodo';
END TRY
BEGIN CATCH
    PRINT 'OK 4.25 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.26 ERROR: asistente inexistente
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @id_jugador_asistente = 99999, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.26 - Debio fallar por asistente';
END TRY
BEGIN CATCH
    PRINT 'OK 4.26 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.27 ERROR: asistente = autor (autor del gol 1 es a9)
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @id_jugador_asistente = @a9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.27 - Debio fallar por asistente = autor';
END TRY
BEGIN CATCH
    PRINT 'OK 4.27 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.28 ERROR: convertir en gol en contra manteniendo asistente
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @id_jugador_asistente = @a10, @minuto = 10, @tipo = 'EN_CONTRA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.28 - Debio fallar: gol en contra no tiene asistencia';
END TRY
BEGIN CATCH
    PRINT 'OK 4.28 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.29 ERROR: asistente de otra seleccion
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @id_jugador_asistente = @b9, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.29 - Debio fallar por asistente de otra seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 4.29 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.30 ERROR: asistente que no figura en el partido
BEGIN TRY
    EXEC torneo.Gol_Modificar @id_partido = @p1, @nro = 1, @id_jugador_asistente = @a20, @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO';
    PRINT 'FALLO 4.30 - Debio fallar porque el asistente no esta en el partido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.30 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-------- Eliminar
-- 4.31 Eliminacion valida
EXEC torneo.Gol_Eliminar @id_partido = @p1, @nro = 6;
IF NOT EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 6) PRINT 'OK 4.31 - Gol eliminado';
ELSE PRINT 'FALLO 4.31';

-- 4.32 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Gol_Eliminar @id_partido = @p1, @nro = 99;
    PRINT 'FALLO 4.32 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 4.32 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 5. SANCION (TARJETAS)
PRINT '=== 5. SANCION ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @p2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @a8  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100008');
DECLARE @a20 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100020');
DECLARE @b2  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200002');
DECLARE @b4  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200004');
DECLARE @b5  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200005');
DECLARE @b6  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200006');

-- 5.1 a 5.5 Altas validas
EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @a8, @color = 'AMARILLA', @minuto = 20, @motivo = 'Falta';
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 1) PRINT 'OK 5.1 - Amarilla a a8 insertada';
ELSE PRINT 'FALLO 5.1';

EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 2, @id_jugador = @b4, @color = 'AMARILLA', @minuto = 30, @motivo = 'Mano';
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 2) PRINT 'OK 5.2 - Amarilla a b4 insertada';
ELSE PRINT 'FALLO 5.2';

EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 3, @id_jugador = @a8, @color = 'AMARILLA', @minuto = 55, @motivo = 'Protesta';
IF (SELECT COUNT(*) FROM torneo.Sancion WHERE id_partido = @p1 AND id_jugador = @a8 AND color = 'AMARILLA') = 2 PRINT 'OK 5.3 - Segunda amarilla a a8 insertada';
ELSE PRINT 'FALLO 5.3';

EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 4, @id_jugador = @b2, @color = 'ROJA', @minuto = 40, @motivo = 'Juego brusco grave';
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 4 AND color = 'ROJA') PRINT 'OK 5.4 - Roja a b2 insertada';
ELSE PRINT 'FALLO 5.4';

EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 5, @id_jugador = @b5, @color = 'AMARILLA', @minuto = 60;
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 5 AND motivo IS NULL) PRINT 'OK 5.5 - Amarilla sin motivo insertada';
ELSE PRINT 'FALLO 5.5';

-- 5.6 Amarilla de b4 en el partido 2 (sirve luego para la suspension por acumulacion)
EXEC torneo.Sancion_Insertar @id_partido = @p2, @nro = 1, @id_jugador = @b4, @color = 'AMARILLA', @minuto = 25, @motivo = 'Falta';
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p2 AND nro = 1) PRINT 'OK 5.6 - Amarilla a b4 en el partido 2 insertada';
ELSE PRINT 'FALLO 5.6';

-- 5.7 ERROR: tercera amarilla en el mismo partido
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 6, @id_jugador = @a8, @color = 'AMARILLA', @minuto = 70;
    PRINT 'FALLO 5.7 - Debio fallar por tercera amarilla';
END TRY
BEGIN CATCH
    PRINT 'OK 5.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.8 ERROR: partido inexistente
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = 99999, @nro = 7, @id_jugador = @b6, @color = 'AMARILLA', @minuto = 10;
    PRINT 'FALLO 5.8 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 5.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.9 ERROR: numero repetido
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @b6, @color = 'AMARILLA', @minuto = 10;
    PRINT 'FALLO 5.9 - Debio fallar por nro repetido';
END TRY
BEGIN CATCH
    PRINT 'OK 5.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.10 ERROR: numero nulo
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = NULL, @id_jugador = @b6, @color = 'AMARILLA', @minuto = 10;
    PRINT 'FALLO 5.10 - Debio fallar por nro nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 5.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.11 ERROR: jugador inexistente
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 8, @id_jugador = 99999, @color = 'AMARILLA', @minuto = 10;
    PRINT 'FALLO 5.11 - Debio fallar por jugador';
END TRY
BEGIN CATCH
    PRINT 'OK 5.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.12 ERROR: color invalido
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 9, @id_jugador = @b6, @color = 'AZUL', @minuto = 10;
    PRINT 'FALLO 5.12 - Debio fallar por color';
END TRY
BEGIN CATCH
    PRINT 'OK 5.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.13 ERROR: minuto invalido
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 10, @id_jugador = @b6, @color = 'AMARILLA', @minuto = 0;
    PRINT 'FALLO 5.13 - Debio fallar por minuto';
END TRY
BEGIN CATCH
    PRINT 'OK 5.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.14 ERROR: jugador que no figura en las formaciones del partido
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 11, @id_jugador = @a20, @color = 'AMARILLA', @minuto = 10;
    PRINT 'FALLO 5.14 - Debio fallar porque el jugador no esta en el partido';
END TRY
BEGIN CATCH
    PRINT 'OK 5.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-------- Modificar
-- 5.15 Modificacion valida
EXEC torneo.Sancion_Modificar @id_partido = @p1, @nro = 2, @color = 'AMARILLA', @minuto = 31, @motivo = 'Mano (corregido)';
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 2 AND minuto = 31 AND motivo = 'Mano (corregido)') PRINT 'OK 5.15 - Tarjeta modificada';
ELSE PRINT 'FALLO 5.15';

-- 5.16 ERROR: tarjeta inexistente
BEGIN TRY
    EXEC torneo.Sancion_Modificar @id_partido = @p1, @nro = 99, @color = 'AMARILLA', @minuto = 10;
    PRINT 'FALLO 5.16 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 5.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.17 ERROR: color invalido
BEGIN TRY
    EXEC torneo.Sancion_Modificar @id_partido = @p1, @nro = 2, @color = 'AZUL', @minuto = 10;
    PRINT 'FALLO 5.17 - Debio fallar por color';
END TRY
BEGIN CATCH
    PRINT 'OK 5.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.18 ERROR: minuto invalido
BEGIN TRY
    EXEC torneo.Sancion_Modificar @id_partido = @p1, @nro = 2, @color = 'AMARILLA', @minuto = 0;
    PRINT 'FALLO 5.18 - Debio fallar por minuto';
END TRY
BEGIN CATCH
    PRINT 'OK 5.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-------- Eliminar
-- 5.19 Eliminacion valida (amarilla de b5, sin expulsion asociada)
EXEC torneo.Sancion_Eliminar @id_partido = @p1, @nro = 5;
IF NOT EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 5) PRINT 'OK 5.19 - Tarjeta eliminada';
ELSE PRINT 'FALLO 5.19';

-- 5.20 ERROR: eliminar inexistente
BEGIN TRY
    EXEC torneo.Sancion_Eliminar @id_partido = @p1, @nro = 99;
    PRINT 'FALLO 5.20 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 5.20 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 6. EXPULSION
PRINT '=== 6. EXPULSION ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a8  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100008');
DECLARE @b2  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200002');
DECLARE @b4  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200004');
DECLARE @b12 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200012');

-- 6.1 ERROR: roja directa sin tarjeta roja (a8 solo tiene amarillas)
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @a8, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.1 - Debio fallar por falta de tarjeta roja';
END TRY
BEGIN CATCH
    PRINT 'OK 6.1 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.2 ERROR: doble amarilla sin dos amarillas (b2 no tiene amarillas)
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @b2, @causa = 'DOBLE_AMARILLA';
    PRINT 'FALLO 6.2 - Debio fallar por falta de amarillas';
END TRY
BEGIN CATCH
    PRINT 'OK 6.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.3 ERROR: causa invalida
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @b2, @causa = 'INVALIDA';
    PRINT 'FALLO 6.3 - Debio fallar por causa';
END TRY
BEGIN CATCH
    PRINT 'OK 6.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.4 ERROR: partido inexistente
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = 99999, @nro = 1, @id_jugador = @b2, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.4 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 6.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.5 ERROR: jugador inexistente
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = 99999, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.5 - Debio fallar por jugador';
END TRY
BEGIN CATCH
    PRINT 'OK 6.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.6 ERROR: numero nulo
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = NULL, @id_jugador = @b2, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.6 - Debio fallar por nro nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 6.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.7 Alta valida: roja directa (b2 tiene la roja del 5.4)
EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @b2, @causa = 'ROJA_DIRECTA';
IF EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1 AND nro = 1 AND causa = 'ROJA_DIRECTA') PRINT 'OK 6.7 - Expulsion por roja directa insertada';
ELSE PRINT 'FALLO 6.7';

-- 6.8 Alta valida: doble amarilla (a8 tiene dos amarillas)
EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 2, @id_jugador = @a8, @causa = 'DOBLE_AMARILLA';
IF EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1 AND nro = 2 AND causa = 'DOBLE_AMARILLA') PRINT 'OK 6.8 - Expulsion por doble amarilla insertada';
ELSE PRINT 'FALLO 6.8';

-- 6.9 ERROR: numero de expulsion repetido
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 1, @id_jugador = @b4, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.9 - Debio fallar por nro repetido';
END TRY
BEGIN CATCH
    PRINT 'OK 6.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.10 ERROR: jugador ya expulsado en el partido
BEGIN TRY
    EXEC torneo.Expulsion_Insertar @id_partido = @p1, @nro = 3, @id_jugador = @b2, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.10 - Debio fallar porque ya fue expulsado';
END TRY
BEGIN CATCH
    PRINT 'OK 6.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.11 ERROR: no se puede sancionar a un jugador ya expulsado
BEGIN TRY
    EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 12, @id_jugador = @b2, @color = 'AMARILLA', @minuto = 80;
    PRINT 'FALLO 6.11 - Debio fallar: jugador expulsado';
END TRY
BEGIN CATCH
    PRINT 'OK 6.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.12 ERROR: no puede ser sustituido un jugador expulsado
BEGIN TRY
    EXEC torneo.Sustitucion_Insertar @id_partido = @p1, @nro = 40, @id_jugador_sale = @b2, @id_jugador_entra = @b12, @minuto = 50, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 6.12 - Debio fallar: jugador expulsado no puede salir en un cambio';
END TRY
BEGIN CATCH
    PRINT 'OK 6.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.13 ERROR: cambiar a AMARILLA la roja de una roja directa
BEGIN TRY
    EXEC torneo.Sancion_Modificar @id_partido = @p1, @nro = 4, @color = 'AMARILLA', @minuto = 40;
    PRINT 'FALLO 6.13 - Debio fallar: la roja respalda la expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 6.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.14 ERROR: cambiar a ROJA una de las dos amarillas de una doble amarilla
BEGIN TRY
    EXEC torneo.Sancion_Modificar @id_partido = @p1, @nro = 1, @color = 'ROJA', @minuto = 20;
    PRINT 'FALLO 6.14 - Debio fallar: la amarilla respalda la expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 6.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.15 ERROR: eliminar la roja de una roja directa
BEGIN TRY
    EXEC torneo.Sancion_Eliminar @id_partido = @p1, @nro = 4;
    PRINT 'FALLO 6.15 - Debio fallar: primero hay que eliminar la expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 6.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.16 ERROR: eliminar una de las amarillas de una doble amarilla
BEGIN TRY
    EXEC torneo.Sancion_Eliminar @id_partido = @p1, @nro = 1;
    PRINT 'FALLO 6.16 - Debio fallar: primero hay que eliminar la expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 6.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-------- Modificar
-- 6.17 ERROR: expulsion inexistente
BEGIN TRY
    EXEC torneo.Expulsion_Modificar @id_partido = @p1, @nro = 99, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.17 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.18 ERROR: causa invalida
BEGIN TRY
    EXEC torneo.Expulsion_Modificar @id_partido = @p1, @nro = 1, @causa = 'INVALIDA';
    PRINT 'FALLO 6.18 - Debio fallar por causa';
END TRY
BEGIN CATCH
    PRINT 'OK 6.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.19 ERROR: pasar a doble amarilla a quien no tiene dos amarillas (b2)
BEGIN TRY
    EXEC torneo.Expulsion_Modificar @id_partido = @p1, @nro = 1, @causa = 'DOBLE_AMARILLA';
    PRINT 'FALLO 6.19 - Debio fallar por falta de amarillas';
END TRY
BEGIN CATCH
    PRINT 'OK 6.19 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.20 ERROR: pasar a roja directa a quien no tiene roja (a8)
BEGIN TRY
    EXEC torneo.Expulsion_Modificar @id_partido = @p1, @nro = 2, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 6.20 - Debio fallar por falta de roja';
END TRY
BEGIN CATCH
    PRINT 'OK 6.20 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.21 Modificacion valida (misma causa, todavia sin suspension asociada)
EXEC torneo.Expulsion_Modificar @id_partido = @p1, @nro = 1, @causa = 'ROJA_DIRECTA';
IF EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1 AND nro = 1 AND causa = 'ROJA_DIRECTA') PRINT 'OK 6.21 - Expulsion modificada';
ELSE PRINT 'FALLO 6.21';
GO

-------------------------------------- 7. SUSPENSION
PRINT '=== 7. SUSPENSION ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @p2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @a8  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100008');
DECLARE @a20 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100020');
DECLARE @b2  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200002');
DECLARE @b4  INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200004');
DECLARE @s1 INT, @s2 INT, @s3 INT;

-- 7.1 Suspension por roja directa
EXEC torneo.Suspension_Insertar @id_jugador = @b2, @id_partido_origen = @p1, @motivo = 'ROJA_DIRECTA', @partidos_a_cumplir = 1, @id_suspension = @s1 OUTPUT;
IF @s1 IS NOT NULL PRINT 'OK 7.1 - Suspension por roja directa insertada con id=' + CAST(@s1 AS VARCHAR);
ELSE PRINT 'FALLO 7.1';

-- 7.2 Suspension por doble amarilla
EXEC torneo.Suspension_Insertar @id_jugador = @a8, @id_partido_origen = @p1, @motivo = 'DOBLE_AMARILLA', @partidos_a_cumplir = 1, @id_suspension = @s2 OUTPUT;
IF @s2 IS NOT NULL PRINT 'OK 7.2 - Suspension por doble amarilla insertada con id=' + CAST(@s2 AS VARCHAR);
ELSE PRINT 'FALLO 7.2';

-- 7.3 Suspension por acumulacion de amarillas (b4: amarilla en partido 1 y en partido 2)
EXEC torneo.Suspension_Insertar @id_jugador = @b4, @id_partido_origen = @p2, @motivo = 'ACUMULACION_AMARILLAS', @partidos_a_cumplir = 1, @id_suspension = @s3 OUTPUT;
IF @s3 IS NOT NULL PRINT 'OK 7.3 - Suspension por acumulacion insertada con id=' + CAST(@s3 AS VARCHAR);
ELSE PRINT 'FALLO 7.3';

-- 7.4 ERROR: suspension duplicada
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @b2, @id_partido_origen = @p1, @motivo = 'ROJA_DIRECTA', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.4 - Debio fallar por duplicada';
END TRY
BEGIN CATCH
    PRINT 'OK 7.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.5 ERROR: jugador inexistente
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = 99999, @id_partido_origen = @p1, @motivo = 'ROJA_DIRECTA', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.5 - Debio fallar por jugador';
END TRY
BEGIN CATCH
    PRINT 'OK 7.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.6 ERROR: partido de origen inexistente
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @b2, @id_partido_origen = 99999, @motivo = 'ROJA_DIRECTA', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.6 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 7.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.7 ERROR: motivo invalido
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @b2, @id_partido_origen = @p1, @motivo = 'INVALIDO', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.7 - Debio fallar por motivo';
END TRY
BEGIN CATCH
    PRINT 'OK 7.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.8 ERROR: partidos a cumplir = 0
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @b4, @id_partido_origen = @p1, @motivo = 'ACUMULACION_AMARILLAS', @partidos_a_cumplir = 0;
    PRINT 'FALLO 7.8 - Debio fallar por partidos a cumplir';
END TRY
BEGIN CATCH
    PRINT 'OK 7.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.9 ERROR: el jugador no figura en las formaciones del partido de origen
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @a20, @id_partido_origen = @p1, @motivo = 'ACUMULACION_AMARILLAS', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.9 - Debio fallar porque el jugador no esta en el partido';
END TRY
BEGIN CATCH
    PRINT 'OK 7.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.10 ERROR: roja directa sin expulsion con esa causa en el partido de origen (b4 no fue expulsado)
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @b4, @id_partido_origen = @p1, @motivo = 'ROJA_DIRECTA', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.10 - Debio fallar por falta de expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 7.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.11 ERROR: acumulacion sin llegar al umbral (a8 solo tiene amarillas en un partido)
BEGIN TRY
    EXEC torneo.Suspension_Insertar @id_jugador = @a8, @id_partido_origen = @p1, @motivo = 'ACUMULACION_AMARILLAS', @partidos_a_cumplir = 1;
    PRINT 'FALLO 7.11 - Debio fallar porque no llego al umbral de amarillas';
END TRY
BEGIN CATCH
    PRINT 'OK 7.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.12 fn_JugadorSuspendido: b2 debe cumplir 1 partido -> no puede jugar el partido 2, y si el partido 1
IF torneo.fn_JugadorSuspendido(@b2, @p2) = 1 PRINT 'OK 7.12a - fn_JugadorSuspendido = 1 para el partido siguiente';
ELSE PRINT 'FALLO 7.12a - fn_JugadorSuspendido devolvio 0';
IF torneo.fn_JugadorSuspendido(@b2, @p1) = 0 PRINT 'OK 7.12b - fn_JugadorSuspendido = 0 para el partido de origen';
ELSE PRINT 'FALLO 7.12b - fn_JugadorSuspendido devolvio 1';

-------- Modificar
-- 7.13 Modificacion valida
EXEC torneo.Suspension_Modificar @id_suspension = @s1, @partidos_a_cumplir = 2, @partidos_cumplidos = 1;
IF EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_suspension = @s1 AND partidos_a_cumplir = 2 AND partidos_cumplidos = 1) PRINT 'OK 7.13 - Suspension modificada';
ELSE PRINT 'FALLO 7.13';

-- 7.14 ERROR: suspension inexistente
BEGIN TRY
    EXEC torneo.Suspension_Modificar @id_suspension = 99999, @partidos_a_cumplir = 1, @partidos_cumplidos = 0;
    PRINT 'FALLO 7.14 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 7.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.15 ERROR: partidos a cumplir = 0
BEGIN TRY
    EXEC torneo.Suspension_Modificar @id_suspension = @s1, @partidos_a_cumplir = 0, @partidos_cumplidos = 0;
    PRINT 'FALLO 7.15 - Debio fallar por partidos a cumplir';
END TRY
BEGIN CATCH
    PRINT 'OK 7.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.16 ERROR: cumplidos mayor que a cumplir
BEGIN TRY
    EXEC torneo.Suspension_Modificar @id_suspension = @s1, @partidos_a_cumplir = 2, @partidos_cumplidos = 3;
    PRINT 'FALLO 7.16 - Debio fallar por cumplidos > a cumplir';
END TRY
BEGIN CATCH
    PRINT 'OK 7.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.17 ERROR: cumplidos nulo
BEGIN TRY
    EXEC torneo.Suspension_Modificar @id_suspension = @s1, @partidos_a_cumplir = 2, @partidos_cumplidos = NULL;
    PRINT 'FALLO 7.17 - Debio fallar por cumplidos nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 7.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 8. COHERENCIA EXPULSION / SUSPENSION Y LIMPIEZA EN ORDEN
PRINT '=== 8. COHERENCIA Y BAJAS EN CASCADA ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a8 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90100008');
DECLARE @b2 INT = (SELECT id_participante FROM personas.Participante WHERE dni = '90200002');

-- 8.1 ERROR: modificar una expulsion que ya origino una suspension
BEGIN TRY
    EXEC torneo.Expulsion_Modificar @id_partido = @p1, @nro = 1, @causa = 'ROJA_DIRECTA';
    PRINT 'FALLO 8.1 - Debio fallar: hay una suspension originada en la expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 8.1 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 8.2 ERROR: eliminar una expulsion que ya origino una suspension
BEGIN TRY
    EXEC torneo.Expulsion_Eliminar @id_partido = @p1, @nro = 1;
    PRINT 'FALLO 8.2 - Debio fallar: hay una suspension originada en la expulsion';
END TRY
BEGIN CATCH
    PRINT 'OK 8.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 8.3 Eliminar las suspensiones
DECLARE @s_b2 INT = (SELECT id_suspension FROM torneo.Suspension WHERE id_jugador = @b2);
DECLARE @s_a8 INT = (SELECT id_suspension FROM torneo.Suspension WHERE id_jugador = @a8);
DECLARE @s_b4 INT = (SELECT id_suspension FROM torneo.Suspension WHERE motivo = 'ACUMULACION_AMARILLAS');

EXEC torneo.Suspension_Eliminar @id_suspension = @s_b2;
EXEC torneo.Suspension_Eliminar @id_suspension = @s_a8;
EXEC torneo.Suspension_Eliminar @id_suspension = @s_b4;
IF NOT EXISTS (SELECT 1 FROM torneo.Suspension) PRINT 'OK 8.3 - Suspensiones eliminadas';
ELSE PRINT 'FALLO 8.3';

-- 8.4 ERROR: eliminar suspension inexistente
BEGIN TRY
    EXEC torneo.Suspension_Eliminar @id_suspension = @s_b2;
    PRINT 'FALLO 8.4 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 8.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 8.5 ERROR: eliminar expulsion inexistente
BEGIN TRY
    EXEC torneo.Expulsion_Eliminar @id_partido = @p1, @nro = 99;
    PRINT 'FALLO 8.5 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 8.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 8.6 Sin suspension ya se pueden eliminar las expulsiones
EXEC torneo.Expulsion_Eliminar @id_partido = @p1, @nro = 2;
EXEC torneo.Expulsion_Eliminar @id_partido = @p1, @nro = 1;
IF NOT EXISTS (SELECT 1 FROM torneo.Expulsion) PRINT 'OK 8.6 - Expulsiones eliminadas';
ELSE PRINT 'FALLO 8.6';

-- 8.7 Sin expulsion ya se pueden eliminar las tarjetas que la respaldaban
EXEC torneo.Sancion_Eliminar @id_partido = @p1, @nro = 4;
EXEC torneo.Sancion_Eliminar @id_partido = @p1, @nro = 1;
IF NOT EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro IN (1, 4)) PRINT 'OK 8.7 - Tarjetas eliminadas tras eliminar las expulsiones';
ELSE PRINT 'FALLO 8.7';

-- 8.8 Tras eliminar la expulsion, el jugador ya puede volver a recibir tarjetas en el partido
EXEC torneo.Sancion_Insertar @id_partido = @p1, @nro = 13, @id_jugador = @b2, @color = 'AMARILLA', @minuto = 80;
IF EXISTS (SELECT 1 FROM torneo.Sancion WHERE id_partido = @p1 AND nro = 13) PRINT 'OK 8.8 - Jugador sin expulsion vuelve a poder ser amonestado';
ELSE PRINT 'FALLO 8.8';
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
DBCC CHECKIDENT('torneo.Formacion' , RESEED, 0)
DBCC CHECKIDENT('torneo.Suspension' , RESEED, 0)
GO