/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 25/10/2026
   Objetivo     : Script de testing para 04_SP_ABM_Personas.sql
                  Prueba altas, modificaciones y bajas de Jugador, Arbitro,
                  ArbitroIdioma, DirectorTecnico, Ayudante y ReemplazoConvocatoria,
                  incluyendo casos de error.
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

-- SETUP: datos base necesarios
PRINT '=== SETUP: datos base ===';

DECLARE @id_idioma_es INT, @id_idioma_en INT, @id_idioma_pt INT;
DECLARE @id_pais_arg INT, @id_pais_bra INT, @id_pais_uru INT;
DECLARE @id_ciudad_ba INT;
DECLARE @id_sede_monumental INT;
DECLARE @id_sel_arg INT, @id_sel_bra INT;
DECLARE @id_club_river INT, @id_club_boca INT;

-- Idiomas
EXEC geo.Idioma_Insertar @nombre = 'Español', @id_idioma = @id_idioma_es OUTPUT;
EXEC geo.Idioma_Insertar @nombre = 'Inglés', @id_idioma = @id_idioma_en OUTPUT;
EXEC geo.Idioma_Insertar @nombre = 'Portugués', @id_idioma = @id_idioma_pt OUTPUT;

-- Países
EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @pbi_per_capita = 14000.00, @id_pais = @id_pais_arg OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil', @huso_horario = -3.00, @pbi_per_capita = 10000.00, @id_pais = @id_pais_bra OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Uruguay', @huso_horario = -3.00, @pbi_per_capita = 17000.00, @id_pais = @id_pais_uru OUTPUT;

-- Ciudades
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00, @id_ciudad = @id_ciudad_ba OUTPUT;

-- Sede
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede_monumental OUTPUT;

-- Selecciones
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_arg OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_bra, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_bra OUTPUT;

-- Clubes
EXEC personas.Club_Insertar @nombre = 'River Plate', @id_club = @id_club_river OUTPUT;
EXEC personas.Club_Insertar @nombre = 'Boca Juniors', @id_club = @id_club_boca OUTPUT;

-- Parámetros
EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 26, @descripcion = 'Máximo de convocados';
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11, @descripcion = 'Titulares';
EXEC torneo.Parametro_Insertar @clave = 'MAX_SUPLENTES', @valor = 15, @descripcion = 'Suplentes';
EXEC torneo.Parametro_Insertar @clave = 'AMARILLAS_PARA_SUSPENSION', @valor = 2, @descripcion = 'Amarillas para suspender';

PRINT 'OK SETUP - Datos base cargados';
GO

-------------------------------------- 1. JUGADOR
PRINT '=== 1. JUGADOR ===';

DECLARE @id_jug1 INT, @id_jug2 INT, @id_jug3 INT, @id_jug4 INT;
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @id_club_river INT = (SELECT id_club FROM personas.Club WHERE nombre = 'River Plate');
DECLARE @id_club_boca INT = (SELECT id_club FROM personas.Club WHERE nombre = 'Boca Juniors');

-- 1.1 Alta válida
EXEC personas.Jugador_Insertar
    @dni = '30111222', @nombre = 'Lionel Messi', @fecha_nacimiento = '1987-06-24',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river,
    @nro_dorsal = 10, @posicion = 'DELANTERO', @id_participante = @id_jug1 OUTPUT;
IF @id_jug1 IS NOT NULL PRINT 'OK 1.1 - Jugador insertado con id=' + CAST(@id_jug1 AS VARCHAR);
ELSE PRINT 'FALLO 1.1';

-- 1.2 Alta válida (segundo jugador, otra selección)
EXEC personas.Jugador_Insertar
    @dni = '30222333', @nombre = 'Neymar Jr', @fecha_nacimiento = '1992-02-05',
    @id_seleccion = @id_sel_bra, @id_club = @id_club_boca,
    @nro_dorsal = 10, @posicion = 'DELANTERO', @id_participante = @id_jug2 OUTPUT;
IF @id_jug2 IS NOT NULL PRINT 'OK 1.2 - Jugador brasilero insertado';
ELSE PRINT 'FALLO 1.2';

-- 1.3 Alta válida (mismo dorsal 10 pero distinta selección -> OK)
EXEC personas.Jugador_Insertar
    @dni = '30333444', @nombre = 'Emiliano Martínez', @fecha_nacimiento = '1992-09-02',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river,
    @nro_dorsal = 23, @posicion = 'ARQUERO', @id_participante = @id_jug3 OUTPUT;
IF @id_jug3 IS NOT NULL PRINT 'OK 1.3 - Arquero insertado';
ELSE PRINT 'FALLO 1.3';

-- 1.4 ERROR: DNI nulo
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = NULL, @nombre = 'X', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.4 - Debio fallar por DNI nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.5 ERROR: DNI muy corto
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '123', @nombre = 'X', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.5 - Debio fallar por DNI corto';
END TRY
BEGIN CATCH
    PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 ERROR: DNI duplicado
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30111222', @nombre = 'Otro', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 7, @posicion = 'MEDIOCAMPISTA';
    PRINT 'FALLO 1.6 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.7 ERROR: nombre vacío
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = '   ', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.7 - Debio fallar por nombre vacio';
END TRY
BEGIN CATCH
    PRINT 'OK 1.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.8 ERROR: fecha futura
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = 'X', @fecha_nacimiento = '2099-01-01', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.8 - Debio fallar por fecha futura';
END TRY
BEGIN CATCH
    PRINT 'OK 1.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.9 ERROR: selección inexistente
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = 'X', @id_seleccion = 99999, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.9 - Debio fallar por seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 1.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.10 ERROR: club inexistente
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = 'X', @id_seleccion = @id_sel_arg, @id_club = 99999, @nro_dorsal = 5, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.10 - Debio fallar por club';
END TRY
BEGIN CATCH
    PRINT 'OK 1.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.11 ERROR: dorsal fuera de rango
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = 'X', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 100, @posicion = 'DEFENSOR';
    PRINT 'FALLO 1.11 - Debio fallar por dorsal';
END TRY
BEGIN CATCH
    PRINT 'OK 1.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.12 ERROR: posición inválida
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = 'X', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 5, @posicion = 'INVALIDO';
    PRINT 'FALLO 1.12 - Debio fallar por posicion';
END TRY
BEGIN CATCH
    PRINT 'OK 1.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.13 ERROR: dorsal ya usado en la misma selección
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '30999888', @nombre = 'X', @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 10, @posicion = 'DELANTERO';
    PRINT 'FALLO 1.13 - Debio fallar por dorsal duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.13 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.14 Modificación válida
EXEC personas.Jugador_Modificar
    @id_participante = @id_jug1, @dni = '30111222', @nombre = 'Lionel Andrés Messi',
    @fecha_nacimiento = '1987-06-24', @id_seleccion = @id_sel_arg, @id_club = @id_club_boca,
    @nro_dorsal = 10, @posicion = 'DELANTERO';
PRINT 'OK 1.14 - Jugador modificado (cambio de club)';

-- 1.15 ERROR: modificar inexistente
BEGIN TRY
    EXEC personas.Jugador_Modificar @id_participante = 99999, @dni = '30111222', @nombre = 'X',
        @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 10, @posicion = 'DELANTERO';
    PRINT 'FALLO 1.15 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.16 ERROR: DNI duplicado al modificar
BEGIN TRY
    EXEC personas.Jugador_Modificar @id_participante = @id_jug1, @dni = '30333444', @nombre = 'Lionel',
        @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 10, @posicion = 'DELANTERO';
    PRINT 'FALLO 1.16 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 1.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.17 Alta de un jugador sin dependencias para probar baja
EXEC personas.Jugador_Insertar
    @dni = '30555666', @nombre = 'Jugador Borrable', @fecha_nacimiento = '1995-01-01',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river,
    @nro_dorsal = 50, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug4 OUTPUT;

-- 1.18 Eliminación válida (sin dependencias)
EXEC personas.Jugador_Eliminar @id_participante = @id_jug4;
IF NOT EXISTS (SELECT 1 FROM personas.Jugador WHERE id_participante = @id_jug4)
    PRINT 'OK 1.18 - Jugador eliminado';
ELSE PRINT 'FALLO 1.18';

-- 1.19 ERROR: eliminar inexistente
BEGIN TRY
    EXEC personas.Jugador_Eliminar @id_participante = 99999;
    PRINT 'FALLO 1.19 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.19 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 2. ARBITRO
PRINT '=== 2. ARBITRO ===';

DECLARE @id_arb1 INT, @id_arb2 INT, @id_arb3 INT;
DECLARE @id_pais_arg INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');
DECLARE @id_pais_bra INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Brasil');
DECLARE @id_pais_uru INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Uruguay');

-- 2.1 Alta válida
EXEC personas.Arbitro_Insertar
    @dni = '40111222', @nombre = 'Néstor Pitana', @fecha_nacimiento = '1975-06-17',
    @id_pais = @id_pais_arg, @categoria = 'FIFA', @id_participante = @id_arb1 OUTPUT;
IF @id_arb1 IS NOT NULL PRINT 'OK 2.1 - Arbitro insertado con id=' + CAST(@id_arb1 AS VARCHAR);
ELSE PRINT 'FALLO 2.1';

-- 2.2 Alta válida (segundo árbitro)
EXEC personas.Arbitro_Insertar
    @dni = '40222333', @nombre = 'Wilton Sampaio', @fecha_nacimiento = '1981-12-25',
    @id_pais = @id_pais_bra, @categoria = 'FIFA', @id_participante = @id_arb2 OUTPUT;
IF @id_arb2 IS NOT NULL PRINT 'OK 2.2 - Arbitro brasilero insertado';
ELSE PRINT 'FALLO 2.2';

-- 2.3 ERROR: DNI nulo
BEGIN TRY
    EXEC personas.Arbitro_Insertar @dni = NULL, @nombre = 'X', @id_pais = @id_pais_arg, @categoria = 'FIFA';
    PRINT 'FALLO 2.3 - Debio fallar por DNI nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 ERROR: DNI duplicado (ya existe como jugador)
BEGIN TRY
    EXEC personas.Arbitro_Insertar @dni = '30111222', @nombre = 'X', @id_pais = @id_pais_arg, @categoria = 'FIFA';
    PRINT 'FALLO 2.4 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 2.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.5 ERROR: país inexistente
BEGIN TRY
    EXEC personas.Arbitro_Insertar @dni = '40999888', @nombre = 'X', @id_pais = 99999, @categoria = 'FIFA';
    PRINT 'FALLO 2.5 - Debio fallar por pais';
END TRY
BEGIN CATCH
    PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.6 ERROR: categoría inválida
BEGIN TRY
    EXEC personas.Arbitro_Insertar @dni = '40999888', @nombre = 'X', @id_pais = @id_pais_arg, @categoria = 'INVALIDO';
    PRINT 'FALLO 2.6 - Debio fallar por categoria';
END TRY
BEGIN CATCH
    PRINT 'OK 2.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.7 Modificación válida
EXEC personas.Arbitro_Modificar
    @id_participante = @id_arb1, @dni = '40111222', @nombre = 'Néstor Fabián Pitana',
    @fecha_nacimiento = '1975-06-17', @id_pais = @id_pais_arg, @categoria = 'CONFEDERACION';
PRINT 'OK 2.7 - Arbitro modificado';

-- 2.8 ERROR: modificar inexistente
BEGIN TRY
    EXEC personas.Arbitro_Modificar @id_participante = 99999, @dni = '40111222', @nombre = 'X',
        @id_pais = @id_pais_arg, @categoria = 'FIFA';
    PRINT 'FALLO 2.8 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.9 ERROR: modificar a DNI duplicado
BEGIN TRY
    EXEC personas.Arbitro_Modificar @id_participante = @id_arb1, @dni = '40222333', @nombre = 'Nestor',
        @id_pais = @id_pais_arg, @categoria = 'FIFA';
    PRINT 'FALLO 2.9 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 2.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.10 Alta de árbitro sin dependencias para probar baja
EXEC personas.Arbitro_Insertar
    @dni = '40555666', @nombre = 'Arbitro Borrable', @fecha_nacimiento = '1980-01-01',
    @id_pais = @id_pais_uru, @categoria = 'CONFEDERACION', @id_participante = @id_arb3 OUTPUT;

-- 2.11 Eliminación válida (sin designaciones)
EXEC personas.Arbitro_Eliminar @id_participante = @id_arb3;
IF NOT EXISTS (SELECT 1 FROM personas.Arbitro WHERE id_participante = @id_arb3)
    PRINT 'OK 2.11 - Arbitro eliminado';
ELSE PRINT 'FALLO 2.11';

-- 2.12 ERROR: eliminar inexistente
BEGIN TRY
    EXEC personas.Arbitro_Eliminar @id_participante = 99999;
    PRINT 'FALLO 2.12 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 3. ARBITRO IDIOMA
PRINT '=== 3. ARBITRO IDIOMA ===';

DECLARE @id_arb1 INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre = 'Néstor Fabián Pitana');
DECLARE @id_idioma_es INT = (SELECT id_idioma FROM geo.Idioma WHERE nombre = 'Español');
DECLARE @id_idioma_en INT = (SELECT id_idioma FROM geo.Idioma WHERE nombre = 'Inglés');
DECLARE @id_idioma_pt INT = (SELECT id_idioma FROM geo.Idioma WHERE nombre = 'Portugués');

-- 3.1 Alta válida
EXEC personas.ArbitroIdioma_Insertar @id_arbitro = @id_arb1, @id_idioma = @id_idioma_es;
PRINT 'OK 3.1 - Idioma Español asignado al arbitro';

-- 3.2 Alta válida (segundo idioma)
EXEC personas.ArbitroIdioma_Insertar @id_arbitro = @id_arb1, @id_idioma = @id_idioma_en;
PRINT 'OK 3.2 - Idioma Inglés asignado al arbitro';

-- 3.3 ERROR: árbitro inexistente
BEGIN TRY
    EXEC personas.ArbitroIdioma_Insertar @id_arbitro = 99999, @id_idioma = @id_idioma_es;
    PRINT 'FALLO 3.3 - Debio fallar por arbitro';
END TRY
BEGIN CATCH
    PRINT 'OK 3.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.4 ERROR: idioma inexistente
BEGIN TRY
    EXEC personas.ArbitroIdioma_Insertar @id_arbitro = @id_arb1, @id_idioma = 99999;
    PRINT 'FALLO 3.4 - Debio fallar por idioma';
END TRY
BEGIN CATCH
    PRINT 'OK 3.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.5 ERROR: idioma duplicado
BEGIN TRY
    EXEC personas.ArbitroIdioma_Insertar @id_arbitro = @id_arb1, @id_idioma = @id_idioma_es;
    PRINT 'FALLO 3.5 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 3.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.6 Eliminación válida
EXEC personas.ArbitroIdioma_Eliminar @id_arbitro = @id_arb1, @id_idioma = @id_idioma_en;
IF NOT EXISTS (SELECT 1 FROM personas.ArbitroIdioma WHERE id_arbitro = @id_arb1 AND id_idioma = @id_idioma_en)
    PRINT 'OK 3.6 - Idioma eliminado';
ELSE PRINT 'FALLO 3.6';

-- 3.7 ERROR: eliminar idioma que no tiene
BEGIN TRY
    EXEC personas.ArbitroIdioma_Eliminar @id_arbitro = @id_arb1, @id_idioma = @id_idioma_pt;
    PRINT 'FALLO 3.7 - Debio fallar por idioma no asignado';
END TRY
BEGIN CATCH
    PRINT 'OK 3.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 4. DIRECTOR TECNICO
PRINT '=== 4. DIRECTOR TECNICO ===';

DECLARE @id_dt1 INT, @id_dt2 INT, @id_dt3 INT;
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @id_sel_uru INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Uruguay');

-- 4.1 Alta válida
EXEC personas.DirectorTecnico_Insertar
    @dni = '50111222', @nombre = 'Lionel Scaloni', @fecha_nacimiento = '1978-05-16',
    @id_seleccion = @id_sel_arg, @id_participante = @id_dt1 OUTPUT;
IF @id_dt1 IS NOT NULL PRINT 'OK 4.1 - DT insertado con id=' + CAST(@id_dt1 AS VARCHAR);
ELSE PRINT 'FALLO 4.1';

-- 4.2 Alta válida
EXEC personas.DirectorTecnico_Insertar
    @dni = '50222333', @nombre = 'Dorival Junior', @fecha_nacimiento = '1962-04-25',
    @id_seleccion = @id_sel_bra, @id_participante = @id_dt2 OUTPUT;
IF @id_dt2 IS NOT NULL PRINT 'OK 4.2 - DT brasilero insertado';
ELSE PRINT 'FALLO 4.2';

-- 4.3 ERROR: selección ya tiene DT
BEGIN TRY
    EXEC personas.DirectorTecnico_Insertar @dni = '50999888', @nombre = 'X', @id_seleccion = @id_sel_arg;
    PRINT 'FALLO 4.3 - Debio fallar por seleccion ya con DT';
END TRY
BEGIN CATCH
    PRINT 'OK 4.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.4 ERROR: DNI duplicado
BEGIN TRY
    EXEC personas.DirectorTecnico_Insertar @dni = '50111222', @nombre = 'X', @id_seleccion = @id_sel_uru;
    PRINT 'FALLO 4.4 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 4.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.5 ERROR: selección inexistente
BEGIN TRY
    EXEC personas.DirectorTecnico_Insertar @dni = '50999888', @nombre = 'X', @id_seleccion = 99999;
    PRINT 'FALLO 4.5 - Debio fallar por seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 4.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.6 Modificación válida
EXEC personas.DirectorTecnico_Modificar
    @id_participante = @id_dt1, @dni = '50111222', @nombre = 'Lionel Sebastián Scaloni',
    @fecha_nacimiento = '1978-05-16', @id_seleccion = @id_sel_arg;
PRINT 'OK 4.6 - DT modificado';

-- 4.7 ERROR: modificar inexistente
BEGIN TRY
    EXEC personas.DirectorTecnico_Modificar @id_participante = 99999, @dni = '50111222', @nombre = 'X',
        @id_seleccion = @id_sel_arg;
    PRINT 'FALLO 4.7 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 4.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.8 Alta de DT sin dependencias para probar baja
-- Primero necesitamos una selección libre (Uruguay)
DECLARE @id_pais_uru INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Uruguay');
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_uru,
    @confederacion = 'CONMEBOL', @id_seleccion = @id_sel_uru OUTPUT;
EXEC personas.DirectorTecnico_Insertar
    @dni = '50555666', @nombre = 'DT Borrable', @fecha_nacimiento = '1970-01-01',
    @id_seleccion = @id_sel_uru, @id_participante = @id_dt3 OUTPUT;

-- 4.9 Eliminación válida
EXEC personas.DirectorTecnico_Eliminar @id_participante = @id_dt3;
IF NOT EXISTS (SELECT 1 FROM personas.DirectorTecnico WHERE id_participante = @id_dt3)
    PRINT 'OK 4.9 - DT eliminado';
ELSE PRINT 'FALLO 4.9';

-- 4.10 ERROR: eliminar inexistente
BEGIN TRY
    EXEC personas.DirectorTecnico_Eliminar @id_participante = 99999;
    PRINT 'FALLO 4.10 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 4.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 5. AYUDANTE
PRINT '=== 5. AYUDANTE ===';

DECLARE @id_ay1 INT, @id_ay2 INT;
DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');

-- 5.1 Alta válida
EXEC personas.Ayudante_Insertar
    @dni = '60111222', @nombre = 'Pablo Aimar', @fecha_nacimiento = '1979-11-03',
    @id_seleccion = @id_sel_arg, @id_participante = @id_ay1 OUTPUT;
IF @id_ay1 IS NOT NULL PRINT 'OK 5.1 - Ayudante insertado con id=' + CAST(@id_ay1 AS VARCHAR);
ELSE PRINT 'FALLO 5.1';

-- 5.2 Alta válida (varios ayudantes por selección)
EXEC personas.Ayudante_Insertar
    @dni = '60222333', @nombre = 'Walter Samuel', @fecha_nacimiento = '1978-03-23',
    @id_seleccion = @id_sel_arg, @id_participante = @id_ay2 OUTPUT;
IF @id_ay2 IS NOT NULL PRINT 'OK 5.2 - Segundo ayudante insertado';
ELSE PRINT 'FALLO 5.2';

-- 5.3 ERROR: DNI nulo
BEGIN TRY
    EXEC personas.Ayudante_Insertar @dni = NULL, @nombre = 'X', @id_seleccion = @id_sel_arg;
    PRINT 'FALLO 5.3 - Debio fallar por DNI nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 5.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.4 ERROR: DNI duplicado
BEGIN TRY
    EXEC personas.Ayudante_Insertar @dni = '60111222', @nombre = 'X', @id_seleccion = @id_sel_bra;
    PRINT 'FALLO 5.4 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 5.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.5 ERROR: selección inexistente
BEGIN TRY
    EXEC personas.Ayudante_Insertar @dni = '60999888', @nombre = 'X', @id_seleccion = 99999;
    PRINT 'FALLO 5.5 - Debio fallar por seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 5.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.6 Modificación válida
EXEC personas.Ayudante_Modificar
    @id_participante = @id_ay1, @dni = '60111222', @nombre = 'Pablo César Aimar',
    @fecha_nacimiento = '1979-11-03', @id_seleccion = @id_sel_arg;
PRINT 'OK 5.6 - Ayudante modificado';

-- 5.7 ERROR: modificar inexistente
BEGIN TRY
    EXEC personas.Ayudante_Modificar @id_participante = 99999, @dni = '60111222', @nombre = 'X',
        @id_seleccion = @id_sel_arg;
    PRINT 'FALLO 5.7 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 5.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.8 Eliminación válida
EXEC personas.Ayudante_Eliminar @id_participante = @id_ay2;
IF NOT EXISTS (SELECT 1 FROM personas.Ayudante WHERE id_participante = @id_ay2)
    PRINT 'OK 5.8 - Ayudante eliminado';
ELSE PRINT 'FALLO 5.8';

-- 5.9 ERROR: eliminar inexistente
BEGIN TRY
    EXEC personas.Ayudante_Eliminar @id_participante = 99999;
    PRINT 'FALLO 5.9 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 5.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 6. REEMPLAZO CONVOCATORIA
PRINT '=== 6. REEMPLAZO CONVOCATORIA ===';

DECLARE @id_sel_arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @id_club_river INT = (SELECT id_club FROM personas.Club WHERE nombre = 'River Plate');
DECLARE @id_jug_a INT, @id_jug_b INT, @id_jug_c INT, @id_jug_d INT;
DECLARE @id_jug_messi INT = (SELECT p.id_participante FROM personas.Participante p WHERE p.nombre LIKE 'Lionel Andrés Messi%');

-- 6.1 Alta de jugadores para probar reemplazos
EXEC personas.Jugador_Insertar @dni = '70111222', @nombre = 'Jugador A', @fecha_nacimiento = '1995-01-01',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 60, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_a OUTPUT;
EXEC personas.Jugador_Insertar @dni = '70222333', @nombre = 'Jugador B', @fecha_nacimiento = '1996-01-01',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 61, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_b OUTPUT;
EXEC personas.Jugador_Insertar @dni = '70333444', @nombre = 'Jugador C', @fecha_nacimiento = '1997-01-01',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 62, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_c OUTPUT;
EXEC personas.Jugador_Insertar @dni = '70444555', @nombre = 'Jugador D', @fecha_nacimiento = '1998-01-01',
    @id_seleccion = @id_sel_arg, @id_club = @id_club_river, @nro_dorsal = 63, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_d OUTPUT;

-- 6.2 Alta válida de reemplazo
EXEC torneo.ReemplazoConvocatoria_Insertar
    @id_jugador_sale = @id_jug_a, @id_jugador_entra = @id_jug_b,
    @fecha = '2026-05-15', @motivo = 'Lesión muscular';
PRINT 'OK 6.2 - Reemplazo insertado (A sale, B entra)';

-- 6.3 Verificar que A ya no es convocado activo y B sí
IF NOT EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@id_sel_arg) WHERE id_participante = @id_jug_a)
    PRINT 'OK 6.3a - Jugador A ya no es convocado activo';
ELSE PRINT 'FALLO 6.3a';
IF EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@id_sel_arg) WHERE id_participante = @id_jug_b)
    PRINT 'OK 6.3b - Jugador B es convocado activo';
ELSE PRINT 'FALLO 6.3b';

-- 6.4 ERROR: jugador que sale ya fue reemplazado
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar
        @id_jugador_sale = @id_jug_a, @id_jugador_entra = @id_jug_c,
        @fecha = '2026-05-16', @motivo = 'Otro motivo';
    PRINT 'FALLO 6.4 - Debio fallar por jugador ya reemplazado';
END TRY
BEGIN CATCH
    PRINT 'OK 6.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.5 ERROR: jugador que entra ya reemplazó a otro
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar
        @id_jugador_sale = @id_jug_c, @id_jugador_entra = @id_jug_b,
        @fecha = '2026-05-16', @motivo = 'Otro motivo';
    PRINT 'FALLO 6.5 - Debio fallar por jugador que entra ya reemplazo';
END TRY
BEGIN CATCH
    PRINT 'OK 6.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.6 ERROR: mismo jugador sale y entra
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar
        @id_jugador_sale = @id_jug_c, @id_jugador_entra = @id_jug_c,
        @fecha = '2026-05-16', @motivo = 'X';
    PRINT 'FALLO 6.6 - Debio fallar por mismo jugador';
END TRY
BEGIN CATCH
    PRINT 'OK 6.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.7 ERROR: jugadores de distinta selección
DECLARE @id_sel_bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @id_club_boca INT = (SELECT id_club FROM personas.Club WHERE nombre = 'Boca Juniors');
DECLARE @id_jug_bra INT;
EXEC personas.Jugador_Insertar @dni = '70555666', @nombre = 'Jugador Brasil', @fecha_nacimiento = '1995-01-01',
    @id_seleccion = @id_sel_bra, @id_club = @id_club_boca, @nro_dorsal = 70, @posicion = 'MEDIOCAMPISTA', @id_participante = @id_jug_bra OUTPUT;
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar
        @id_jugador_sale = @id_jug_c, @id_jugador_entra = @id_jug_bra,
        @fecha = '2026-05-16', @motivo = 'X';
    PRINT 'FALLO 6.7 - Debio fallar por distinta seleccion';
END TRY
BEGIN CATCH
    PRINT 'OK 6.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.8 ERROR: fecha futura
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar
        @id_jugador_sale = @id_jug_c, @id_jugador_entra = @id_jug_d,
        @fecha = '2099-01-01', @motivo = 'X';
    PRINT 'FALLO 6.8 - Debio fallar por fecha futura';
END TRY
BEGIN CATCH
    PRINT 'OK 6.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.9 ERROR: motivo vacío
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Insertar
        @id_jugador_sale = @id_jug_c, @id_jugador_entra = @id_jug_d,
        @fecha = '2026-05-16', @motivo = '   ';
    PRINT 'FALLO 6.9 - Debio fallar por motivo vacio';
END TRY
BEGIN CATCH
    PRINT 'OK 6.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.10 Modificación válida
EXEC torneo.ReemplazoConvocatoria_Modificar
    @id_jugador_entra = @id_jug_b, @fecha = '2026-05-20', @motivo = 'Lesión muscular (corregido)';
PRINT 'OK 6.10 - Reemplazo modificado';

-- 6.11 ERROR: modificar inexistente
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Modificar @id_jugador_entra = 99999, @fecha = '2026-05-20', @motivo = 'X';
    PRINT 'FALLO 6.11 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.12 Eliminación válida (deshacer reemplazo)
EXEC torneo.ReemplazoConvocatoria_Eliminar @id_jugador_entra = @id_jug_b;
IF NOT EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_entra = @id_jug_b)
    PRINT 'OK 6.12 - Reemplazo eliminado';
ELSE PRINT 'FALLO 6.12';

-- 6.13 Verificar que A vuelve a ser convocado activo
IF EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@id_sel_arg) WHERE id_participante = @id_jug_a)
    PRINT 'OK 6.13 - Jugador A vuelve a ser convocado activo';
ELSE PRINT 'FALLO 6.13';

-- 6.14 ERROR: eliminar reemplazo inexistente
BEGIN TRY
    EXEC torneo.ReemplazoConvocatoria_Eliminar @id_jugador_entra = @id_jug_b;
    PRINT 'FALLO 6.14 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.14 - Error esperado: ' + ERROR_MESSAGE();
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

DBCC CHECKIDENT('personas.Participante' , RESEED, 0)
GO