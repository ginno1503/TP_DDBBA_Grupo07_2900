/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 02/11/2026
   Objetivo     : Script de testing para 09_SP_Negocio.sql. Cada prueba indica en comentarios el resultado
                  esperado y muestra con OK o FALLO si se cumplió. Las pruebas de error comprueban además
                  que no quedó nada a medias (la transacción se deshizo). Cubre sedes, convocatoria y
                  reemplazos, alineaciones, cambios, goles, tarjetas con suspensión por acumulación,
                  cierre de resultados, designación arbitral con conflicto de nacionalidad, prime time
                  y asignación automática de las cuatro piezas publicitarias.
                  Requisito: haber ejecutado antes los scripts 00 a 09_SP_Negocio.sql.
                  Los datos de esta prueba son propios: el script borra todo al inicio.
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
PRINT '=== SETUP: parametros, paises, selecciones, club y arbitros ===';

DECLARE @id INT, @id_pais INT;

-- Parametros de la prueba (valores chicos para no cargar 23 jugadores por seleccion)
EXEC torneo.Parametro_Insertar @clave = 'MIN_CONVOCADOS', @valor = 13, @descripcion = 'Minimo de convocados';
EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 15, @descripcion = 'Maximo de convocados';
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11, @descripcion = 'Titulares por partido';
EXEC torneo.Parametro_Insertar @clave = 'MAX_SUPLENTES', @valor = 3, @descripcion = 'Suplentes por partido';
EXEC torneo.Parametro_Insertar @clave = 'AMARILLAS_PARA_SUSPENSION', @valor = 2, @descripcion = 'Amarillas para suspender';
EXEC torneo.Parametro_Insertar @clave = 'PARTIDOS_SUSPENSION', @valor = 1, @descripcion = 'Partidos por suspension';
EXEC torneo.Parametro_Insertar @clave = 'MAX_CAMBIOS', @valor = 5, @descripcion = 'Cambios por equipo';
EXEC torneo.Parametro_Insertar @clave = 'MAX_VENTANAS', @valor = 3, @descripcion = 'Ventanas de cambios';

-- Paises: huso horario y PBI per capita (el PBI se usa en el ranking de publicidad)
EXEC geo.Pais_Insertar @nombre = 'Argentina',       @huso_horario = -3.00, @pbi_per_capita = 14000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil',          @huso_horario = -3.00, @pbi_per_capita = 9000.00,  @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Francia',         @huso_horario = 1.00,  @pbi_per_capita = 45000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Alemania',        @huso_horario = 1.00,  @pbi_per_capita = 52000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Portugal',        @huso_horario = 0.00,  @pbi_per_capita = 25000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Italia',          @huso_horario = 1.00,  @pbi_per_capita = 38000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Espana',          @huso_horario = 2.00,  @pbi_per_capita = 32000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Japon',           @huso_horario = 9.00,  @pbi_per_capita = 34000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Estados Unidos',  @huso_horario = -5.00, @pbi_per_capita = 80000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Uruguay',         @huso_horario = -3.00, @pbi_per_capita = 18000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Chile',           @huso_horario = -4.00, @pbi_per_capita = 16000.00, @id_pais = @id OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Mexico',          @huso_horario = -6.00, @pbi_per_capita = 11000.00, @id_pais = @id OUTPUT;

-- Selecciones: Argentina y Brasil juegan los partidos de la prueba; Francia solo sirve para probar la advertencia arbitral
SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id OUTPUT;
SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Brasil');
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id OUTPUT;
SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Francia');
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais, @confederacion = 'UEFA', @grupo = 'B', @id_seleccion = @id OUTPUT;

EXEC personas.Club_Insertar @nombre = 'Club Test', @id_club = @id OUTPUT;

-- Arbitros (uno por pais; ARB00008 es argentino y sirve para el conflicto de nacionalidad)
DECLARE @arb TABLE (n INT IDENTITY(1,1), dni VARCHAR(20), nombre VARCHAR(100), pais VARCHAR(80));
INSERT INTO @arb (dni, nombre, pais) VALUES
    ('ARB00001', 'Arbitro Uruguay',   'Uruguay'),        ('ARB00002', 'Arbitro Chile',     'Chile'),
    ('ARB00003', 'Arbitro Francia',   'Francia'),        ('ARB00004', 'Arbitro Alemania',  'Alemania'),
    ('ARB00005', 'Arbitro Portugal',  'Portugal'),       ('ARB00006', 'Arbitro Japon',     'Japon'),
    ('ARB00007', 'Arbitro EEUU',      'Estados Unidos'), ('ARB00008', 'Arbitro Argentina', 'Argentina'),
    ('ARB00009', 'Arbitro Italia',    'Italia'),         ('ARB00010', 'Arbitro Espana',    'Espana'),
    ('ARB00011', 'Arbitro Mexico',    'Mexico');

DECLARE @a_dni VARCHAR(20), @a_nombre VARCHAR(100), @a_pais VARCHAR(80), @k INT = 1;
WHILE @k <= (SELECT COUNT(*) FROM @arb)
BEGIN
    SELECT @a_dni = dni, @a_nombre = nombre, @a_pais = pais FROM @arb WHERE n = @k;
    SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = @a_pais);
    EXEC personas.Arbitro_Insertar @dni = @a_dni, @nombre = @a_nombre, @id_pais = @id_pais,
         @categoria = 'FIFA', @id_participante = @id OUTPUT;
    SET @k += 1;
END;

IF (SELECT COUNT(*) FROM geo.Pais) = 12 AND (SELECT COUNT(*) FROM torneo.Seleccion) = 3
   AND (SELECT COUNT(*) FROM personas.Arbitro) = 11 AND (SELECT COUNT(*) FROM torneo.Parametro) = 8
    PRINT 'OK SETUP - 12 paises, 3 selecciones, 11 arbitros y 8 parametros cargados';
ELSE PRINT 'FALLO SETUP - Revisar los datos base';
GO

-------------------------------------- 1. SEDE_REGISTRAR
PRINT '=== 1. SEDE_REGISTRAR ===';

DECLARE @id_sede INT;

-- 1.1 El pais existe y la ciudad no: se crean la ciudad y la sede en una transaccion.
-- Esperado: devuelve @id_sede, hay una sola Argentina y la ciudad Buenos Aires con la sede Monumental.
EXEC torneo.Sede_Registrar @pais = 'Argentina', @ciudad = 'Buenos Aires', @huso_ciudad = -3.00,
     @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede OUTPUT;
IF @id_sede IS NOT NULL
   AND (SELECT COUNT(*) FROM geo.Pais WHERE nombre = 'Argentina') = 1
   AND EXISTS (SELECT 1 FROM torneo.Sede s JOIN geo.Ciudad c ON c.id_ciudad = s.id_ciudad
               WHERE s.id_sede = @id_sede AND s.nombre_estadio = 'Monumental' AND c.nombre = 'Buenos Aires')
    PRINT 'OK 1.1 - Sede Monumental registrada con su ciudad (id ' + CAST(@id_sede AS VARCHAR(10)) + ')';
ELSE PRINT 'FALLO 1.1';

-- 1.2 Otro pais ya cargado (Estados Unidos) con una ciudad nueva.
-- Esperado: se crea Dallas con huso -5 y la sede AT&T Stadium.
EXEC torneo.Sede_Registrar @pais = 'Estados Unidos', @ciudad = 'Dallas', @huso_ciudad = -5.00,
     @nombre_estadio = 'AT&T Stadium', @capacidad = 80000, @id_sede = @id_sede OUTPUT;
IF @id_sede IS NOT NULL AND EXISTS (SELECT 1 FROM torneo.Sede s JOIN geo.Ciudad c ON c.id_ciudad = s.id_ciudad
                                    WHERE s.nombre_estadio = 'AT&T Stadium' AND c.nombre = 'Dallas' AND c.huso_horario = -5.00)
    PRINT 'OK 1.2 - Sede AT&T Stadium registrada en Dallas';
ELSE PRINT 'FALLO 1.2';

-- 1.3 Pais nuevo (Canada) sin huso propio (se usa el de la ciudad).
-- Esperado: se crean el pais (con el huso de la ciudad, -5), la ciudad Toronto y la sede BMO Field.
EXEC torneo.Sede_Registrar @pais = 'Canada', @ciudad = 'Toronto', @huso_ciudad = -5.00,
     @nombre_estadio = 'BMO Field', @capacidad = 45000, @id_sede = @id_sede OUTPUT;
IF @id_sede IS NOT NULL AND EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Canada' AND huso_horario = -5.00)
   AND EXISTS (SELECT 1 FROM torneo.Sede WHERE nombre_estadio = 'BMO Field')
    PRINT 'OK 1.3 - Pais Canada creado junto con su ciudad y su sede';
ELSE PRINT 'FALLO 1.3';

-- 1.4 ERROR: pais vacio. Lo informa Pais_Insertar.
-- Esperado: error "nombre del pais"; no se crea nada (siguen 3 sedes).
BEGIN TRY
    EXEC torneo.Sede_Registrar @pais = '', @ciudad = 'Lima', @huso_ciudad = -5.00,
         @nombre_estadio = 'Estadio Nacional', @capacidad = 50000;
    PRINT 'FALLO 1.4 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%nombre del pa%' AND (SELECT COUNT(*) FROM torneo.Sede) = 3
        PRINT 'OK 1.4 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.4 - ' + ERROR_MESSAGE();
END CATCH;

-- 1.5 ERROR: estadio con capacidad cero en un pais nuevo (Peru). Lo informa Sede_Insertar.
-- Esperado: error "capacidad" y se deshace todo: Peru y Lima no quedan creados.
BEGIN TRY
    EXEC torneo.Sede_Registrar @pais = 'Peru', @ciudad = 'Lima', @huso_ciudad = -5.00,
         @nombre_estadio = 'Estadio Nacional', @capacidad = 0;
    PRINT 'FALLO 1.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%capacidad%' AND NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Peru')
       AND (SELECT COUNT(*) FROM torneo.Sede) = 3
        PRINT 'OK 1.5 - Error esperado y transaccion deshecha (Peru no se creo): ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.5 - ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 ERROR: estadio repetido en la misma ciudad.
-- Esperado: error "ya tiene un estadio"; sigue habiendo 3 sedes.
BEGIN TRY
    EXEC torneo.Sede_Registrar @pais = 'Argentina', @ciudad = 'Buenos Aires', @huso_ciudad = -3.00,
         @nombre_estadio = 'Monumental', @capacidad = 70000;
    PRINT 'FALLO 1.6 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya tiene un estadio%' AND (SELECT COUNT(*) FROM torneo.Sede) = 3
        PRINT 'OK 1.6 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.6 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT s.id_sede, s.nombre_estadio, s.capacidad, c.nombre AS ciudad, c.huso_horario AS huso_ciudad, p.nombre AS pais
FROM torneo.Sede s
JOIN geo.Ciudad c ON c.id_ciudad = s.id_ciudad
JOIN geo.Pais p ON p.id_pais = c.id_pais
ORDER BY s.id_sede;
GO

-------------------------------------- 2. CONVOCATORIA_REGISTRAR
PRINT '=== 2. CONVOCATORIA_REGISTRAR ===';

DECLARE @arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @club INT = (SELECT id_club FROM personas.Club WHERE nombre = 'Club Test');
IF OBJECT_ID('tempdb..#Convocados') IS NOT NULL DROP TABLE #Convocados;
CREATE TABLE #Convocados (id INT IDENTITY(1,1), dni VARCHAR(20), nombre VARCHAR(100), fecha_nacimiento DATE, id_club INT, nro_dorsal TINYINT, posicion VARCHAR(15));
DECLARE @i INT, @n INT;

-- 2.1 ERROR: lista de 12 jugadores validos (el minimo de la prueba es 13).
-- Esperado: error "menos jugadores que el minimo"; la transaccion se deshace y no queda ningun jugador.
SET @i = 1;
WHILE @i <= 12
BEGIN
    INSERT INTO #Convocados (dni, nombre, fecha_nacimiento, id_club, nro_dorsal, posicion)
    VALUES ('ARG' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5), 'ARG Jugador ' + CAST(@i AS VARCHAR(5)), '1998-01-01', @club, @i,
            CASE WHEN @i <= 2 THEN 'ARQUERO' WHEN @i <= 6 THEN 'DEFENSOR' WHEN @i <= 10 THEN 'MEDIOCAMPISTA' ELSE 'DELANTERO' END);
    SET @i += 1;
END;
BEGIN TRY
    EXEC torneo.Convocatoria_Registrar @id_seleccion = @arg;
    PRINT 'FALLO 2.1 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%menos jugadores%' AND (SELECT COUNT(*) FROM personas.Jugador) = 0
        PRINT 'OK 2.1 - Error esperado y nada quedo cargado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2.1 - ' + ERROR_MESSAGE();
END CATCH;

-- 2.2 ERROR: 14 jugadores pero el ultimo tiene un club inexistente. Lo informa Jugador_Insertar.
-- Esperado: error "club"; los 13 anteriores se deshacen y no queda ningun jugador.
INSERT INTO #Convocados (dni, nombre, fecha_nacimiento, id_club, nro_dorsal, posicion)
VALUES ('ARG00013', 'ARG Jugador 13', '1998-01-01', @club, 13, 'DELANTERO'),
       ('ARG00014', 'ARG Jugador 14', '1998-01-01', -1,    14, 'DELANTERO');
BEGIN TRY
    EXEC torneo.Convocatoria_Registrar @id_seleccion = @arg;
    PRINT 'FALLO 2.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%club%' AND (SELECT COUNT(*) FROM personas.Jugador) = 0
        PRINT 'OK 2.2 - Error esperado y nada quedo cargado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2.2 - ' + ERROR_MESSAGE();
END CATCH;

-- 2.3 OK: 15 convocados de Argentina (2 arqueros, 4 defensores, 4 mediocampistas, 5 delanteros).
-- Esperado: @n = 15 y quince jugadores de Argentina en la base.
DELETE FROM #Convocados;
SET @i = 1;
WHILE @i <= 15
BEGIN
    INSERT INTO #Convocados (dni, nombre, fecha_nacimiento, id_club, nro_dorsal, posicion)
    VALUES ('ARG' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5), 'ARG Jugador ' + CAST(@i AS VARCHAR(5)), '1998-01-01', @club, @i,
            CASE WHEN @i <= 2 THEN 'ARQUERO' WHEN @i <= 6 THEN 'DEFENSOR' WHEN @i <= 10 THEN 'MEDIOCAMPISTA' ELSE 'DELANTERO' END);
    SET @i += 1;
END;
EXEC torneo.Convocatoria_Registrar @id_seleccion = @arg, @cantidad_registrada = @n OUTPUT;
IF @n = 15 AND (SELECT COUNT(*) FROM personas.Jugador WHERE id_seleccion = @arg) = 15
    PRINT 'OK 2.3 - Convocatoria de Argentina registrada (15 jugadores)';
ELSE PRINT 'FALLO 2.3';

-- 2.4 OK: 15 convocados de Brasil.
-- Esperado: @n = 15 y quince jugadores de Brasil en la base.
DELETE FROM #Convocados;
SET @i = 1;
WHILE @i <= 15
BEGIN
    INSERT INTO #Convocados (dni, nombre, fecha_nacimiento, id_club, nro_dorsal, posicion)
    VALUES ('BRA' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5), 'BRA Jugador ' + CAST(@i AS VARCHAR(5)), '1998-01-01', @club, @i,
            CASE WHEN @i <= 2 THEN 'ARQUERO' WHEN @i <= 6 THEN 'DEFENSOR' WHEN @i <= 10 THEN 'MEDIOCAMPISTA' ELSE 'DELANTERO' END);
    SET @i += 1;
END;
EXEC torneo.Convocatoria_Registrar @id_seleccion = @bra, @cantidad_registrada = @n OUTPUT;
IF @n = 15 AND (SELECT COUNT(*) FROM personas.Jugador WHERE id_seleccion = @bra) = 15
    PRINT 'OK 2.4 - Convocatoria de Brasil registrada (15 jugadores)';
ELSE PRINT 'FALLO 2.4';

-- 2.5 ERROR: agregar un jugador mas a una seleccion que ya tiene el maximo (15). Lo informa Jugador_Insertar.
-- Esperado: error "maximo de jugadores"; Argentina sigue con 15.
DELETE FROM #Convocados;
INSERT INTO #Convocados (dni, nombre, fecha_nacimiento, id_club, nro_dorsal, posicion)
VALUES ('ARG00050', 'ARG Jugador 50', '1998-01-01', @club, 50, 'ARQUERO');
BEGIN TRY
    EXEC torneo.Convocatoria_Registrar @id_seleccion = @arg;
    PRINT 'FALLO 2.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%m_ximo de jugadores%' AND (SELECT COUNT(*) FROM personas.Jugador WHERE id_seleccion = @arg) = 15
        PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2.5 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT s.id_seleccion, p.nombre AS pais, COUNT(j.id_participante) AS convocados
FROM torneo.Seleccion s
JOIN geo.Pais p ON p.id_pais = s.id_pais
LEFT JOIN personas.Jugador j ON j.id_seleccion = s.id_seleccion
GROUP BY s.id_seleccion, p.nombre
ORDER BY s.id_seleccion;

DROP TABLE #Convocados;
GO

-------------------------------------- 3. CONVOCATORIA_REEMPLAZARJUGADOR
PRINT '=== 3. CONVOCATORIA_REEMPLAZARJUGADOR ===';

DECLARE @arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @club INT = (SELECT id_club FROM personas.Club WHERE nombre = 'Club Test');
DECLARE @sale INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00015');
DECLARE @a14 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00014');
DECLARE @entra INT;
DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
DECLARE @futuro DATE = DATEADD(DAY, 5, CAST(GETDATE() AS DATE));

-- 3.1 OK: el delantero n 15 se lesiona y lo reemplaza un jugador nuevo que hereda su dorsal (15).
-- Esperado: queda una baja registrada, el reemplazo es convocado activo con dorsal 15 y Argentina sigue con 15 activos.
EXEC torneo.Convocatoria_ReemplazarJugador @id_jugador_sale = @sale, @fecha = @hoy, @motivo = 'Lesion muscular',
     @dni = 'ARG99999', @nombre = 'ARG Reemplazo', @fecha_nacimiento = '1999-05-05', @id_club = @club,
     @posicion = 'DELANTERO', @id_jugador_entra = @entra OUTPUT;
IF @entra IS NOT NULL
   AND (SELECT COUNT(*) FROM torneo.ReemplazoConvocatoria WHERE id_jugador_sale = @sale AND id_jugador_entra = @entra) = 1
   AND (SELECT COUNT(*) FROM personas.fn_ConvocadosActivos(@arg)) = 15
   AND NOT EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@arg) WHERE id_participante = @sale)
   AND EXISTS (SELECT 1 FROM personas.fn_ConvocadosActivos(@arg) WHERE id_participante = @entra AND nro_dorsal = 15)
    PRINT 'OK 3.1 - Reemplazo registrado; Argentina conserva 15 convocados activos';
ELSE PRINT 'FALLO 3.1';

-- 3.2 ERROR: dar de baja otra vez al mismo jugador. Lo informa ReemplazoConvocatoria_Insertar.
-- Esperado: error "ya fue reemplazado"; se deshace el alta del nuevo jugador (siguen 31 jugadores y 1 reemplazo).
BEGIN TRY
    EXEC torneo.Convocatoria_ReemplazarJugador @id_jugador_sale = @sale, @fecha = @hoy, @motivo = 'Otro motivo',
         @dni = 'ARG88888', @nombre = 'ARG Otro', @id_club = @club, @posicion = 'DELANTERO';
    PRINT 'FALLO 3.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya fue reemplazado%' AND (SELECT COUNT(*) FROM torneo.ReemplazoConvocatoria) = 1
       AND (SELECT COUNT(*) FROM personas.Jugador) = 31
        PRINT 'OK 3.2 - Error esperado y transaccion deshecha: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.2 - ' + ERROR_MESSAGE();
END CATCH;

-- 3.3 ERROR: el DNI del reemplazo ya existe.
-- Esperado: error "ya existe una persona"; siguen 31 jugadores.
BEGIN TRY
    EXEC torneo.Convocatoria_ReemplazarJugador @id_jugador_sale = @a14, @fecha = @hoy, @motivo = 'Lesion',
         @dni = 'ARG00001', @nombre = 'ARG Repetido', @id_club = @club, @posicion = 'DELANTERO';
    PRINT 'FALLO 3.3 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya existe una persona%' AND (SELECT COUNT(*) FROM personas.Jugador) = 31
        PRINT 'OK 3.3 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.3 - ' + ERROR_MESSAGE();
END CATCH;

-- 3.4 ERROR: fecha futura y motivo vacio juntos. Los informa ReemplazoConvocatoria_Insertar en un unico mensaje.
-- Esperado: un unico mensaje con "fecha" y "motivo"; se deshace el alta (siguen 31 jugadores).
BEGIN TRY
    EXEC torneo.Convocatoria_ReemplazarJugador @id_jugador_sale = @a14, @fecha = @futuro, @motivo = '',
         @dni = 'ARG77777', @nombre = 'ARG Futuro', @id_club = @club, @posicion = 'DELANTERO';
    PRINT 'FALLO 3.4 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%fecha%' AND ERROR_MESSAGE() LIKE '%motivo%' AND (SELECT COUNT(*) FROM personas.Jugador) = 31
        PRINT 'OK 3.4 - Error esperado (condiciones juntas): ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.4 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT r.id_jugador_sale, ps.nombre AS sale, r.id_jugador_entra, pe.nombre AS entra, r.fecha, r.motivo
FROM torneo.ReemplazoConvocatoria r
JOIN personas.Participante ps ON ps.id_participante = r.id_jugador_sale
JOIN personas.Participante pe ON pe.id_participante = r.id_jugador_entra;
GO

-------------------------------------- 4. ALINEACION_REGISTRAR
PRINT '=== 4. ALINEACION_REGISTRAR ===';

DECLARE @arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @fra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Francia');
DECLARE @sede_mon INT = (SELECT id_sede FROM torneo.Sede WHERE nombre_estadio = 'Monumental');
DECLARE @sede_dal INT = (SELECT id_sede FROM torneo.Sede WHERE nombre_estadio = 'AT&T Stadium');
DECLARE @p1 INT, @p2 INT, @p3 INT, @psim INT, @f INT, @i INT, @id INT;
IF OBJECT_ID('tempdb..#Titulares') IS NOT NULL DROP TABLE #Titulares;
IF OBJECT_ID('tempdb..#Suplentes') IS NOT NULL DROP TABLE #Suplentes;
CREATE TABLE #Titulares (id INT IDENTITY(1,1), id_jugador INT, posicion_cancha VARCHAR(20), dorsal_cancha TINYINT);
CREATE TABLE #Suplentes (id INT IDENTITY(1,1), id_jugador INT);

-- Partidos de la prueba (por el ABM): grupo, octavos, cuartos y una final sin selecciones definidas
EXEC torneo.Partido_Insertar @id_sede = @sede_mon, @fase = 'GRUPOS',  @fecha = '2026-06-10', @horario = '16:00',
     @id_seleccion_1 = @arg, @id_seleccion_2 = @bra, @id_partido = @p1 OUTPUT;
EXEC torneo.Partido_Insertar @id_sede = @sede_mon, @fase = 'OCTAVOS', @fecha = '2026-06-20', @horario = '16:00',
     @id_seleccion_1 = @arg, @id_seleccion_2 = @bra, @id_partido = @p2 OUTPUT;
EXEC torneo.Partido_Insertar @id_sede = @sede_mon, @fase = 'CUARTOS', @fecha = '2026-06-30', @horario = '16:00',
     @id_seleccion_1 = @arg, @id_seleccion_2 = @bra, @id_partido = @p3 OUTPUT;
EXEC torneo.Partido_Insertar @id_sede = @sede_dal, @fase = 'FINAL',   @fecha = '2026-06-10', @horario = '13:00',
     @id_partido = @psim OUTPUT;

-- 4.1 ERROR: solo 10 titulares (el reglamento pide 11) y 3 suplentes (lo valida PartidoFormacion_Insertar).
-- Esperado: error sobre la cantidad de titulares; la transaccion se deshace y no queda ninguna formacion.
SET @i = 1;
WHILE @i <= 10
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@i AS VARCHAR(5)), @i);
    SET @i += 1;
END;
INSERT INTO #Suplentes (id_jugador)
SELECT id_participante FROM personas.Participante WHERE dni IN ('ARG00012', 'ARG00013', 'ARG00014');
BEGIN TRY
    EXEC torneo.Alineacion_Registrar @id_partido = @p1, @id_seleccion = @arg, @esquema_tactico = '4-3-3';
    PRINT 'FALLO 4.1 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%titulares%' AND (SELECT COUNT(*) FROM torneo.Formacion) = 0
       AND (SELECT COUNT(*) FROM torneo.FormacionTitular) = 0
        PRINT 'OK 4.1 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 4.1 - ' + ERROR_MESSAGE();
END CATCH;

-- 4.2 OK: Argentina, partido de grupos: 11 titulares (1 a 11) y 3 suplentes (12 a 14).
-- Esperado: devuelve @f; la formacion tiene 11 titulares y 3 suplentes y queda vinculada al partido.
DELETE FROM #Titulares; DELETE FROM #Suplentes;
SET @i = 1;
WHILE @i <= 11
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@i AS VARCHAR(5)), @i);
    SET @i += 1;
END;
SET @i = 12;
WHILE @i <= 14
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5));
    INSERT INTO #Suplentes (id_jugador) VALUES (@id);
    SET @i += 1;
END;
EXEC torneo.Alineacion_Registrar @id_partido = @p1, @id_seleccion = @arg, @esquema_tactico = '4-3-3', @id_formacion = @f OUTPUT;
IF @f IS NOT NULL
   AND (SELECT COUNT(*) FROM torneo.FormacionTitular WHERE id_formacion = @f) = 11
   AND (SELECT COUNT(*) FROM torneo.FormacionSuplente WHERE id_formacion = @f) = 3
   AND EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @p1 AND id_formacion = @f AND id_seleccion = @arg)
    PRINT 'OK 4.2 - Alineacion de Argentina registrada (11 titulares, 3 suplentes)';
ELSE PRINT 'FALLO 4.2';

-- 4.3 OK: Brasil, mismo partido.
-- Esperado: segunda formacion vinculada al partido de grupos.
DELETE FROM #Titulares; DELETE FROM #Suplentes;
SET @i = 1;
WHILE @i <= 11
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@i AS VARCHAR(5)), @i);
    SET @i += 1;
END;
SET @i = 12;
WHILE @i <= 14
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA' + RIGHT('00000' + CAST(@i AS VARCHAR(5)), 5));
    INSERT INTO #Suplentes (id_jugador) VALUES (@id);
    SET @i += 1;
END;
EXEC torneo.Alineacion_Registrar @id_partido = @p1, @id_seleccion = @bra, @esquema_tactico = '4-4-2', @id_formacion = @f OUTPUT;
IF @f IS NOT NULL AND (SELECT COUNT(*) FROM torneo.PartidoFormacion WHERE id_partido = @p1) = 2
    PRINT 'OK 4.3 - Alineacion de Brasil registrada; el partido tiene sus dos formaciones';
ELSE PRINT 'FALLO 4.3';

-- 4.4 ERROR: volver a registrar la formacion de Brasil para el mismo partido.
-- Esperado: error "ya tiene una formacion"; sigue habiendo dos formaciones.
BEGIN TRY
    EXEC torneo.Alineacion_Registrar @id_partido = @p1, @id_seleccion = @bra, @esquema_tactico = '4-4-2';
    PRINT 'FALLO 4.4 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya tiene una formaci%' AND (SELECT COUNT(*) FROM torneo.Formacion) = 2
        PRINT 'OK 4.4 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 4.4 - ' + ERROR_MESSAGE();
END CATCH;

-- 4.5 ERROR: una formacion de Francia con jugadores de Brasil.
-- Esperado: error "no es un convocado activo" (los jugadores no son de Francia); sigue habiendo dos formaciones.
BEGIN TRY
    EXEC torneo.Alineacion_Registrar @id_partido = @p1, @id_seleccion = @fra, @esquema_tactico = '4-3-3';
    PRINT 'FALLO 4.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%convocado activo%' AND (SELECT COUNT(*) FROM torneo.Formacion) = 2
        PRINT 'OK 4.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 4.5 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT pf.id_partido, p.fase, pf.id_seleccion, f.id_formacion, f.esquema_tactico,
       (SELECT COUNT(*) FROM torneo.FormacionTitular ft WHERE ft.id_formacion = f.id_formacion) AS titulares,
       (SELECT COUNT(*) FROM torneo.FormacionSuplente fs WHERE fs.id_formacion = f.id_formacion) AS suplentes
FROM torneo.PartidoFormacion pf
JOIN torneo.Formacion f ON f.id_formacion = pf.id_formacion
JOIN torneo.Partido p ON p.id_partido = pf.id_partido;

DROP TABLE #Titulares;
DROP TABLE #Suplentes;
GO

-------------------------------------- 5. CAMBIO_REGISTRAR
PRINT '=== 5. CAMBIO_REGISTRAR ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a2  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00002');
DECLARE @a3  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00003');
DECLARE @a4  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00004');
DECLARE @a12 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00012');
DECLARE @a13 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00013');
DECLARE @a14 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00014');
DECLARE @nro TINYINT;

-- 5.1 OK: cambio por lesion en el minuto 15 (dentro de los primeros 20 minutos).
-- Esperado: numero 1, motivo LESION, periodo PRIMER_TIEMPO.
EXEC torneo.Cambio_Registrar @id_partido = @p1, @id_jugador_sale = @a2, @id_jugador_entra = @a12,
     @minuto = 15, @periodo = 'PRIMER_TIEMPO', @motivo = 'LESION', @nro = @nro OUTPUT;
IF @nro = 1 AND EXISTS (SELECT 1 FROM torneo.Sustitucion WHERE id_partido = @p1 AND nro = 1 AND motivo = 'LESION' AND minuto = 15)
    PRINT 'OK 5.1 - Cambio por lesion en el minuto 15 registrado con numero 1';
ELSE PRINT 'FALLO 5.1';

-- 5.2 OK: segundo cambio, tactico, en el minuto 60.
-- Esperado: numero 2 (la numeracion es automatica).
EXEC torneo.Cambio_Registrar @id_partido = @p1, @id_jugador_sale = @a3, @id_jugador_entra = @a13,
     @minuto = 60, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO', @nro = @nro OUTPUT;
IF @nro = 2 AND (SELECT COUNT(*) FROM torneo.Sustitucion WHERE id_partido = @p1) = 2
    PRINT 'OK 5.2 - Segundo cambio registrado con numero 2';
ELSE PRINT 'FALLO 5.2';

-- 5.3 ERROR: entra un jugador que ya habia salido (no esta en el banco).
-- Esperado: error "banco de suplentes"; siguen habiendo 2 cambios.
BEGIN TRY
    EXEC torneo.Cambio_Registrar @id_partido = @p1, @id_jugador_sale = @a4, @id_jugador_entra = @a2,
         @minuto = 70, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 5.3 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%banco de suplentes%' AND (SELECT COUNT(*) FROM torneo.Sustitucion WHERE id_partido = @p1) = 2
        PRINT 'OK 5.3 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 5.3 - ' + ERROR_MESSAGE();
END CATCH;

-- 5.4 ERROR: sale un suplente que todavia no entro (no esta en cancha).
-- Esperado: error "en cancha"; siguen habiendo 2 cambios.
BEGIN TRY
    EXEC torneo.Cambio_Registrar @id_partido = @p1, @id_jugador_sale = @a14, @id_jugador_entra = @a4,
         @minuto = 70, @periodo = 'SEGUNDO_TIEMPO', @motivo = 'TACTICO';
    PRINT 'FALLO 5.4 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%en cancha%' AND (SELECT COUNT(*) FROM torneo.Sustitucion WHERE id_partido = @p1) = 2
        PRINT 'OK 5.4 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 5.4 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT s.id_partido, s.nro, ps.nombre AS sale, pe.nombre AS entra, s.minuto, s.periodo, s.motivo
FROM torneo.Sustitucion s
JOIN personas.Participante ps ON ps.id_participante = s.id_jugador_sale
JOIN personas.Participante pe ON pe.id_participante = s.id_jugador_entra
ORDER BY s.nro;
GO

-------------------------------------- 6. GOL_REGISTRAR
PRINT '=== 6. GOL_REGISTRAR ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a8  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00008');
DECLARE @a9  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00009');
DECLARE @a10 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00010');
DECLARE @a13 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00013');
DECLARE @a99 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG99999');
DECLARE @b3  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00003');
DECLARE @b11 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00011');
DECLARE @nro TINYINT;

-- 6.1 OK: gol de Argentina con asistencia.
-- Esperado: numero 1.
EXEC torneo.Gol_Registrar @id_partido = @p1, @id_jugador_autor = @a9, @id_jugador_asistente = @a8,
     @minuto = 10, @tipo = 'JUGADA', @periodo = 'PRIMER_TIEMPO', @nro = @nro OUTPUT;
IF @nro = 1 AND EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 1 AND id_jugador_autor = @a9)
    PRINT 'OK 6.1 - Gol 1 registrado';
ELSE PRINT 'FALLO 6.1';

-- 6.2 OK: penal de Brasil.
-- Esperado: numero 2 (la numeracion es automatica).
EXEC torneo.Gol_Registrar @id_partido = @p1, @id_jugador_autor = @b11, @minuto = 30,
     @tipo = 'PENAL', @periodo = 'PRIMER_TIEMPO', @nro = @nro OUTPUT;
IF @nro = 2 AND EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 2 AND tipo = 'PENAL')
    PRINT 'OK 6.2 - Penal registrado con numero 2';
ELSE PRINT 'FALLO 6.2';

-- 6.3 OK: gol en contra de un defensor de Brasil (sin asistencia).
-- Esperado: numero 3.
EXEC torneo.Gol_Registrar @id_partido = @p1, @id_jugador_autor = @b3, @minuto = 70,
     @tipo = 'EN_CONTRA', @periodo = 'SEGUNDO_TIEMPO', @nro = @nro OUTPUT;
IF @nro = 3 AND EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @p1 AND nro = 3 AND tipo = 'EN_CONTRA')
    PRINT 'OK 6.3 - Gol en contra registrado con numero 3';
ELSE PRINT 'FALLO 6.3';

-- 6.4 OK: gol de cabeza del jugador que entro en el minuto 60.
-- Esperado: numero 4 y cuatro goles en el partido.
EXEC torneo.Gol_Registrar @id_partido = @p1, @id_jugador_autor = @a13, @id_jugador_asistente = @a10,
     @minuto = 85, @tipo = 'CABEZAZO', @periodo = 'SEGUNDO_TIEMPO', @nro = @nro OUTPUT;
IF @nro = 4 AND (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @p1) = 4
    PRINT 'OK 6.4 - Gol de cabeza registrado con numero 4';
ELSE PRINT 'FALLO 6.4';

-- 6.5 ERROR: el autor no figura en las formaciones del partido (lo valida Gol_Insertar).
-- Esperado: error "formaciones"; siguen habiendo 4 goles.
BEGIN TRY
    EXEC torneo.Gol_Registrar @id_partido = @p1, @id_jugador_autor = @a99, @minuto = 88,
         @tipo = 'JUGADA', @periodo = 'SEGUNDO_TIEMPO';
    PRINT 'FALLO 6.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%formaciones%' AND (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @p1) = 4
        PRINT 'OK 6.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 6.5 - ' + ERROR_MESSAGE();
END CATCH;

-- 6.6 ERROR: un gol en contra con asistencia (lo valida Gol_Insertar).
-- Esperado: error "gol en contra"; siguen habiendo 4 goles.
BEGIN TRY
    EXEC torneo.Gol_Registrar @id_partido = @p1, @id_jugador_autor = @b3, @id_jugador_asistente = @b11,
         @minuto = 75, @tipo = 'EN_CONTRA', @periodo = 'SEGUNDO_TIEMPO';
    PRINT 'FALLO 6.6 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%gol en contra%' AND (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @p1) = 4
        PRINT 'OK 6.6 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 6.6 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT g.nro, pa.nombre AS autor, g.minuto, g.tipo, g.periodo
FROM torneo.Gol g
JOIN personas.Participante pa ON pa.id_participante = g.id_jugador_autor
WHERE g.id_partido = @p1
ORDER BY g.nro;
GO

-------------------------------------- 7. TARJETA_REGISTRAR (doble amarilla, roja directa y acumulacion)
PRINT '=== 7. TARJETA_REGISTRAR ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @a5  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00005');
DECLARE @a99 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG99999');
DECLARE @b4  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00004');
DECLARE @b6  INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00006');
DECLARE @nro TINYINT, @susp VARCHAR(25);

-- 7.1 OK: amarilla simple a un jugador de Brasil.
-- Esperado: numero 1, sin suspension y sin expulsion.
EXEC torneo.Tarjeta_Registrar @id_partido = @p1, @id_jugador = @b4, @color = 'AMARILLA', @minuto = 20,
     @motivo = 'Falta tactica', @nro = @nro OUTPUT, @motivo_suspension = @susp OUTPUT;
IF @nro = 1 AND @susp IS NULL AND NOT EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1)
    PRINT 'OK 7.1 - Amarilla simple registrada, sin suspension';
ELSE PRINT 'FALLO 7.1';

-- 7.2 OK: primera amarilla a un jugador de Argentina.
-- Esperado: sin suspension y sin expulsion.
EXEC torneo.Tarjeta_Registrar @id_partido = @p1, @id_jugador = @a5, @color = 'AMARILLA', @minuto = 25,
     @motivo = 'Falta', @nro = @nro OUTPUT, @motivo_suspension = @susp OUTPUT;
IF @susp IS NULL AND NOT EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1 AND id_jugador = @a5)
    PRINT 'OK 7.2 - Primera amarilla, sin consecuencias';
ELSE PRINT 'FALLO 7.2';

-- 7.3 OK: segunda amarilla al mismo jugador en el mismo partido.
-- Esperado: expulsion por DOBLE_AMARILLA y suspension DOBLE_AMARILLA de 1 partido, en una sola operacion.
EXEC torneo.Tarjeta_Registrar @id_partido = @p1, @id_jugador = @a5, @color = 'AMARILLA', @minuto = 55,
     @motivo = 'Protesta', @nro = @nro OUTPUT, @motivo_suspension = @susp OUTPUT;
IF @susp = 'DOBLE_AMARILLA'
   AND EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1 AND id_jugador = @a5 AND causa = 'DOBLE_AMARILLA')
   AND EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_jugador = @a5 AND id_partido_origen = @p1
               AND motivo = 'DOBLE_AMARILLA' AND partidos_a_cumplir = 1)
    PRINT 'OK 7.3 - Doble amarilla: expulsion y suspension generadas automaticamente';
ELSE PRINT 'FALLO 7.3';

-- 7.4 OK: roja directa a un jugador de Brasil.
-- Esperado: expulsion por ROJA_DIRECTA y suspension ROJA_DIRECTA de 1 partido.
EXEC torneo.Tarjeta_Registrar @id_partido = @p1, @id_jugador = @b6, @color = 'ROJA', @minuto = 80,
     @motivo = 'Juego brusco grave', @nro = @nro OUTPUT, @motivo_suspension = @susp OUTPUT;
IF @susp = 'ROJA_DIRECTA'
   AND EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_partido = @p1 AND id_jugador = @b6 AND causa = 'ROJA_DIRECTA')
   AND EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_jugador = @b6 AND id_partido_origen = @p1 AND motivo = 'ROJA_DIRECTA')
    PRINT 'OK 7.4 - Roja directa: expulsion y suspension generadas automaticamente';
ELSE PRINT 'FALLO 7.4';

-- 7.5 ERROR: tarjeta a un jugador que ya fue expulsado en el partido.
-- Esperado: error "expulsado"; siguen habiendo 4 tarjetas y 2 expulsiones.
BEGIN TRY
    EXEC torneo.Tarjeta_Registrar @id_partido = @p1, @id_jugador = @a5, @color = 'AMARILLA', @minuto = 60;
    PRINT 'FALLO 7.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%expulsado%' AND (SELECT COUNT(*) FROM torneo.Sancion WHERE id_partido = @p1) = 4
       AND (SELECT COUNT(*) FROM torneo.Expulsion WHERE id_partido = @p1) = 2
        PRINT 'OK 7.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 7.5 - ' + ERROR_MESSAGE();
END CATCH;

-- 7.6 ERROR: tarjeta a un jugador que no figura en las formaciones del partido.
-- Esperado: error "formaciones"; siguen habiendo 4 tarjetas.
BEGIN TRY
    EXEC torneo.Tarjeta_Registrar @id_partido = @p1, @id_jugador = @a99, @color = 'AMARILLA', @minuto = 60;
    PRINT 'FALLO 7.6 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%formaciones%' AND (SELECT COUNT(*) FROM torneo.Sancion WHERE id_partido = @p1) = 4
        PRINT 'OK 7.6 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 7.6 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT sa.nro, pa.nombre AS jugador, sa.color, sa.minuto, sa.motivo
FROM torneo.Sancion sa JOIN personas.Participante pa ON pa.id_participante = sa.id_jugador
WHERE sa.id_partido = @p1 ORDER BY sa.nro;
SELECT e.nro, pa.nombre AS jugador, e.causa
FROM torneo.Expulsion e JOIN personas.Participante pa ON pa.id_participante = e.id_jugador
WHERE e.id_partido = @p1 ORDER BY e.nro;
SELECT s.id_suspension, pa.nombre AS jugador, s.motivo, s.partidos_a_cumplir, s.partidos_cumplidos
FROM torneo.Suspension s JOIN personas.Participante pa ON pa.id_participante = s.id_jugador;
GO

-------------------------------------- 7B. SUSPENSIONES EN LAS ALINEACIONES SIGUIENTES Y ACUMULACION DE AMARILLAS
PRINT '=== 7B. SUSPENSIONES Y ACUMULACION ===';

DECLARE @arg INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Argentina');
DECLARE @bra INT = (SELECT s.id_seleccion FROM torneo.Seleccion s JOIN geo.Pais p ON p.id_pais = s.id_pais WHERE p.nombre = 'Brasil');
DECLARE @p2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @p3 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'CUARTOS');
DECLARE @b4 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00004');
DECLARE @f INT, @k INT, @idx INT, @id INT, @nro TINYINT, @susp VARCHAR(25);
IF OBJECT_ID('tempdb..#Titulares') IS NOT NULL DROP TABLE #Titulares;
IF OBJECT_ID('tempdb..#Suplentes') IS NOT NULL DROP TABLE #Suplentes;
CREATE TABLE #Titulares (id INT IDENTITY(1,1), id_jugador INT, posicion_cancha VARCHAR(20), dorsal_cancha TINYINT);
CREATE TABLE #Suplentes (id INT IDENTITY(1,1), id_jugador INT);

-- 7.7 ERROR: Argentina arma la alineacion de octavos con el jugador expulsado por doble amarilla (n 5).
-- Esperado: error "suspendidos" con el nombre "ARG Jugador 5"; no se crea la formacion.
SET @k = 1;
WHILE @k <= 11
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG' + RIGHT('00000' + CAST(@k AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@k AS VARCHAR(5)), @k);
    SET @k += 1;
END;
SET @k = 12;
WHILE @k <= 14
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG' + RIGHT('00000' + CAST(@k AS VARCHAR(5)), 5));
    INSERT INTO #Suplentes (id_jugador) VALUES (@id);
    SET @k += 1;
END;
BEGIN TRY
    EXEC torneo.Alineacion_Registrar @id_partido = @p2, @id_seleccion = @arg, @esquema_tactico = '4-3-3';
    PRINT 'FALLO 7.7 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%suspendidos%' AND ERROR_MESSAGE() LIKE '%ARG Jugador 5%'
       AND NOT EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @p2)
        PRINT 'OK 7.7 - Error esperado (jugador suspendido fuera de la formacion): ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 7.7 - ' + ERROR_MESSAGE();
END CATCH;

-- 7.8 OK: Argentina arma octavos sin el suspendido (titulares 1 a 4 y 6 a 12; suplentes 13, 14 y el reemplazo ARG99999).
-- Esperado: formacion vinculada al partido de octavos.
DELETE FROM #Titulares; DELETE FROM #Suplentes;
SET @k = 1;
WHILE @k <= 11
BEGIN
    SET @idx = CASE WHEN @k < 5 THEN @k ELSE @k + 1 END;
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG' + RIGHT('00000' + CAST(@idx AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@k AS VARCHAR(5)), @k);
    SET @k += 1;
END;
INSERT INTO #Suplentes (id_jugador)
SELECT id_participante FROM personas.Participante WHERE dni IN ('ARG00013', 'ARG00014', 'ARG99999');
EXEC torneo.Alineacion_Registrar @id_partido = @p2, @id_seleccion = @arg, @esquema_tactico = '4-3-3', @id_formacion = @f OUTPUT;
IF @f IS NOT NULL AND EXISTS (SELECT 1 FROM torneo.PartidoFormacion WHERE id_partido = @p2 AND id_seleccion = @arg)
    PRINT 'OK 7.8 - Alineacion de Argentina para octavos sin el suspendido';
ELSE PRINT 'FALLO 7.8';

-- 7.9 OK: Brasil arma octavos sin el expulsado por roja directa (n 6).
-- Esperado: segunda formacion del partido de octavos.
DELETE FROM #Titulares; DELETE FROM #Suplentes;
SET @k = 1;
WHILE @k <= 11
BEGIN
    SET @idx = CASE WHEN @k < 6 THEN @k ELSE @k + 1 END;
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA' + RIGHT('00000' + CAST(@idx AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@k AS VARCHAR(5)), @k);
    SET @k += 1;
END;
INSERT INTO #Suplentes (id_jugador)
SELECT id_participante FROM personas.Participante WHERE dni IN ('BRA00013', 'BRA00014', 'BRA00015');
EXEC torneo.Alineacion_Registrar @id_partido = @p2, @id_seleccion = @bra, @esquema_tactico = '4-4-2', @id_formacion = @f OUTPUT;
IF @f IS NOT NULL AND (SELECT COUNT(*) FROM torneo.PartidoFormacion WHERE id_partido = @p2) = 2
    PRINT 'OK 7.9 - Alineacion de Brasil para octavos sin el suspendido';
ELSE PRINT 'FALLO 7.9';

-- 7.10 OK: el jugador n 4 de Brasil recibe una amarilla en un segundo partido (la primera fue en el partido de grupos).
--       Con AMARILLAS_PARA_SUSPENSION = 2, la cantidad de partidos con amarilla (2) es multiplo de 2.
-- Esperado: se genera la suspension ACUMULACION_AMARILLAS de 1 partido con origen en octavos.
EXEC torneo.Tarjeta_Registrar @id_partido = @p2, @id_jugador = @b4, @color = 'AMARILLA', @minuto = 33,
     @motivo = 'Falta', @nro = @nro OUTPUT, @motivo_suspension = @susp OUTPUT;
IF @susp = 'ACUMULACION_AMARILLAS'
   AND EXISTS (SELECT 1 FROM torneo.Suspension WHERE id_jugador = @b4 AND id_partido_origen = @p2
               AND motivo = 'ACUMULACION_AMARILLAS' AND partidos_a_cumplir = 1)
   AND NOT EXISTS (SELECT 1 FROM torneo.Expulsion WHERE id_jugador = @b4)
    PRINT 'OK 7.10 - Suspension por acumulacion de amarillas generada automaticamente';
ELSE PRINT 'FALLO 7.10';

-- 7.11 ERROR: Brasil arma cuartos incluyendo al suspendido por acumulacion (n 4) y al que ya cumplio su fecha (n 6).
-- Esperado: error "suspendidos" que nombra a "BRA Jugador 4" y NO nombra a "BRA Jugador 6".
DELETE FROM #Titulares; DELETE FROM #Suplentes;
SET @k = 1;
WHILE @k <= 11
BEGIN
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA' + RIGHT('00000' + CAST(@k AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@k AS VARCHAR(5)), @k);
    SET @k += 1;
END;
INSERT INTO #Suplentes (id_jugador)
SELECT id_participante FROM personas.Participante WHERE dni IN ('BRA00012', 'BRA00013', 'BRA00014');
BEGIN TRY
    EXEC torneo.Alineacion_Registrar @id_partido = @p3, @id_seleccion = @bra, @esquema_tactico = '4-4-2';
    PRINT 'FALLO 7.11 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%suspendidos%' AND ERROR_MESSAGE() LIKE '%BRA Jugador 4%' AND ERROR_MESSAGE() NOT LIKE '%BRA Jugador 6%'
        PRINT 'OK 7.11 - Error esperado (queda afuera el suspendido por acumulacion): ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 7.11 - ' + ERROR_MESSAGE();
END CATCH;

-- 7.12 OK: Brasil arma cuartos sin el n 4; el n 6 puede jugar porque ya cumplio su suspension en octavos.
-- Esperado: formacion de Brasil vinculada al partido de cuartos (Argentina todavia no la cargo).
DELETE FROM #Titulares; DELETE FROM #Suplentes;
SET @k = 1;
WHILE @k <= 11
BEGIN
    SET @idx = CASE WHEN @k < 4 THEN @k ELSE @k + 1 END;
    SET @id = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA' + RIGHT('00000' + CAST(@idx AS VARCHAR(5)), 5));
    INSERT INTO #Titulares (id_jugador, posicion_cancha, dorsal_cancha) VALUES (@id, 'POS' + CAST(@k AS VARCHAR(5)), @k);
    SET @k += 1;
END;
INSERT INTO #Suplentes (id_jugador)
SELECT id_participante FROM personas.Participante WHERE dni IN ('BRA00013', 'BRA00014', 'BRA00015');
EXEC torneo.Alineacion_Registrar @id_partido = @p3, @id_seleccion = @bra, @esquema_tactico = '4-4-2', @id_formacion = @f OUTPUT;
IF @f IS NOT NULL AND EXISTS (SELECT 1 FROM torneo.FormacionTitular ft
                              JOIN personas.Participante pa ON pa.id_participante = ft.id_jugador
                              WHERE ft.id_formacion = @f AND pa.dni = 'BRA00006')
    PRINT 'OK 7.12 - Alineacion de Brasil para cuartos (con el n 6 que ya cumplio y sin el n 4)';
ELSE PRINT 'FALLO 7.12';

-- Evidencia
SELECT s.id_suspension, pa.nombre AS jugador, s.motivo, s.id_partido_origen, s.partidos_a_cumplir, s.partidos_cumplidos
FROM torneo.Suspension s JOIN personas.Participante pa ON pa.id_participante = s.id_jugador
ORDER BY s.id_suspension;

DROP TABLE #Titulares;
DROP TABLE #Suplentes;
GO

-------------------------------------- 8. PARTIDO_DESIGNARARBITROS
PRINT '=== 8. PARTIDO_DESIGNARARBITROS ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @p2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @psim INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'FINAL');
DECLARE @uru INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00001');
DECLARE @chi INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00002');
DECLARE @fra INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00003');
DECLARE @ale INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00004');
DECLARE @por INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00005');
DECLARE @jap INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00006');
DECLARE @usa INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00007');
DECLARE @arg INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00008');
DECLARE @ita INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00009');
DECLARE @esp INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00010');
DECLARE @mex INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARB00011');

-- 8.1 OK: equipo arbitral completo para el partido de grupos (ningun arbitro es de Argentina ni de Brasil).
-- Esperado: principal = Uruguay, VAR = Chile, 2 asistentes y 1 cuarto arbitro.
EXEC torneo.Partido_DesignarArbitros @id_partido = @p1, @id_principal = @uru, @id_var = @chi,
     @id_asistente_1 = @ale, @id_asistente_2 = @por, @id_cuarto = @jap;
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p1 AND id_arbitro_principal = @uru AND id_arbitro_var = @chi)
   AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p1 AND rol = 'ASISTENTE') = 2
   AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p1 AND rol = 'CUARTO') = 1
    PRINT 'OK 8.1 - Equipo arbitral completo designado';
ELSE PRINT 'FALLO 8.1';

-- 8.2 ERROR (caso obligatorio): el arbitro principal propuesto es argentino y Argentina juega el partido (lo valida Partido_Modificar).
-- Esperado: designacion descartada por "nacionalidad"; la transaccion se deshace y el partido conserva su equipo
--           anterior (principal Uruguay y 3 secundarios).
BEGIN TRY
    EXEC torneo.Partido_DesignarArbitros @id_partido = @p1, @id_principal = @arg, @id_var = @chi,
         @id_asistente_1 = @ale, @id_asistente_2 = @por, @id_cuarto = @jap;
    PRINT 'FALLO 8.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%nacionalidad%'
       AND EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p1 AND id_arbitro_principal = @uru)
       AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p1) = 3
        PRINT 'OK 8.2 - Designacion descartada por conflicto de nacionalidad: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 8.2 - ' + ERROR_MESSAGE();
END CATCH;

-- 8.3 ERROR: el mismo arbitro como principal y como VAR (lo valida Partido_Modificar).
-- Esperado: error "distintos"; el partido conserva su equipo anterior.
BEGIN TRY
    EXEC torneo.Partido_DesignarArbitros @id_partido = @p1, @id_principal = @uru, @id_var = @uru,
         @id_asistente_1 = @ale, @id_asistente_2 = @por, @id_cuarto = @jap;
    PRINT 'FALLO 8.3 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%distintos%' AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p1) = 3
        PRINT 'OK 8.3 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 8.3 - ' + ERROR_MESSAGE();
END CATCH;

-- 8.4 ERROR: falta indicar el arbitro de VAR.
-- Esperado: error "cinco arbitros"; el partido conserva su equipo anterior.
BEGIN TRY
    EXEC torneo.Partido_DesignarArbitros @id_partido = @p1, @id_principal = @uru, @id_var = NULL,
         @id_asistente_1 = @ale, @id_asistente_2 = @por, @id_cuarto = @jap;
    PRINT 'FALLO 8.4 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%cinco%' AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p1) = 3
        PRINT 'OK 8.4 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 8.4 - ' + ERROR_MESSAGE();
END CATCH;

-- 8.5 OK: se reemplaza el equipo del partido de grupos (el principal pasa a ser el de Francia).
-- Esperado: principal = Francia y siguen 3 secundarios (los anteriores se reemplazan, no se acumulan).
EXEC torneo.Partido_DesignarArbitros @id_partido = @p1, @id_principal = @fra, @id_var = @chi,
     @id_asistente_1 = @ale, @id_asistente_2 = @por, @id_cuarto = @jap;
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p1 AND id_arbitro_principal = @fra)
   AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p1) = 3
    PRINT 'OK 8.5 - Designacion reemplazada: principal Francia, 3 secundarios';
ELSE PRINT 'FALLO 8.5';

-- 8.6 OK: partido de Dallas (final, sin selecciones definidas todavia), con arbitros de otros paises.
-- Esperado: principal = Uruguay y 3 secundarios.
EXEC torneo.Partido_DesignarArbitros @id_partido = @psim, @id_principal = @uru, @id_var = @usa,
     @id_asistente_1 = @ita, @id_asistente_2 = @esp, @id_cuarto = @mex;
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @psim AND id_arbitro_principal = @uru)
   AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @psim) = 3
    PRINT 'OK 8.6 - Partido de Dallas designado';
ELSE PRINT 'FALLO 8.6';

-- 8.7 OK con advertencia: octavos con un arbitro de Francia, pais que todavia tiene una seleccion en competencia.
-- Esperado: designacion correcta y, en la pestana Mensajes, "ADVERTENCIA: el pais del arbitro principal todavia
--           tiene una seleccion en competencia" (la emite Partido_Modificar).
EXEC torneo.Partido_DesignarArbitros @id_partido = @p2, @id_principal = @fra, @id_var = @uru,
     @id_asistente_1 = @chi, @id_asistente_2 = @ale, @id_cuarto = @por;
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p2 AND id_arbitro_principal = @fra)
   AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @p2) = 3
    PRINT 'OK 8.7 - Octavos designado (revisar que arriba aparezca la ADVERTENCIA)';
ELSE PRINT 'FALLO 8.7';

-- Evidencia
SELECT p.id_partido, p.fase, 'PRINCIPAL' AS rol, pa.nombre AS arbitro
FROM torneo.Partido p JOIN personas.Participante pa ON pa.id_participante = p.id_arbitro_principal
UNION ALL
SELECT p.id_partido, p.fase, 'VAR', pa.nombre
FROM torneo.Partido p JOIN personas.Participante pa ON pa.id_participante = p.id_arbitro_var
UNION ALL
SELECT s.id_partido, p.fase, s.rol, pa.nombre
FROM torneo.ArbitroSecundario s
JOIN torneo.Partido p ON p.id_partido = s.id_partido
JOIN personas.Participante pa ON pa.id_participante = s.id_arbitro
ORDER BY id_partido, rol;
GO

-------------------------------------- 9. PARTIDO_REGISTRARRESULTADO
PRINT '=== 9. PARTIDO_REGISTRARRESULTADO ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');
DECLARE @p2 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'OCTAVOS');
DECLARE @psim INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'FINAL');
DECLARE @a5 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'ARG00005');
DECLARE @b4 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00004');
DECLARE @b6 INT = (SELECT id_participante FROM personas.Participante WHERE dni = 'BRA00006');

-- 9.1 ERROR: asistencia mayor que la capacidad del estadio, que es de 70000 (lo valida Partido_Modificar).
-- Esperado: error "asistencia"; el partido sigue sin resultado.
BEGIN TRY
    EXEC torneo.Partido_RegistrarResultado @id_partido = @p1, @goles_1 = 3, @goles_2 = 1, @asistencia = 80000;
    PRINT 'FALLO 9.1 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%asistencia%' AND EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p1 AND goles_1 IS NULL)
        PRINT 'OK 9.1 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 9.1 - ' + ERROR_MESSAGE();
END CATCH;

-- 9.2 ERROR: partido sin las dos selecciones definidas (lo valida Partido_Modificar).
-- Esperado: error "definidas".
BEGIN TRY
    EXEC torneo.Partido_RegistrarResultado @id_partido = @psim, @goles_1 = 1, @goles_2 = 0;
    PRINT 'FALLO 9.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%definidas%'
        PRINT 'OK 9.2 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 9.2 - ' + ERROR_MESSAGE();
END CATCH;

-- 9.3 OK: cierre del partido de grupos 3-1 con asistencia 65000.
-- Esperado: resultado guardado. Las suspensiones nacidas en este partido todavia no cumplieron ninguna fecha (0).
EXEC torneo.Partido_RegistrarResultado @id_partido = @p1, @goles_1 = 3, @goles_2 = 1, @asistencia = 65000;
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p1 AND goles_1 = 3 AND goles_2 = 1 AND asistencia = 65000)
   AND NOT EXISTS (SELECT 1 FROM torneo.Suspension WHERE partidos_cumplidos <> 0)
    PRINT 'OK 9.3 - Partido de grupos cerrado 3-1 con asistencia 65000';
ELSE PRINT 'FALLO 9.3';

-- 9.4 ERROR: cerrar de nuevo un partido que ya tiene resultado.
-- Esperado: error "ya tiene resultado"; el marcador sigue 3-1.
BEGIN TRY
    EXEC torneo.Partido_RegistrarResultado @id_partido = @p1, @goles_1 = 0, @goles_2 = 0;
    PRINT 'FALLO 9.4 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya tiene resultado%' AND EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p1 AND goles_1 = 3 AND goles_2 = 1)
        PRINT 'OK 9.4 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 9.4 - ' + ERROR_MESSAGE();
END CATCH;

-- 9.5 OK: cierre de octavos 1-0 con asistencia 50000. Al cerrarlo, las suspensiones nacidas en el partido de grupos
--         (el doble amarilla de ARG00005 y la roja de BRA00006) cumplen su fecha; la acumulacion de BRA00004 nacio
--         en este mismo partido y todavia no cumplio ninguna.
-- Esperado: partidos_cumplidos = 1 para ARG00005 y BRA00006, y 0 para BRA00004.
EXEC torneo.Partido_RegistrarResultado @id_partido = @p2, @goles_1 = 1, @goles_2 = 0, @asistencia = 50000;
IF EXISTS (SELECT 1 FROM torneo.Partido WHERE id_partido = @p2 AND goles_1 = 1 AND goles_2 = 0 AND asistencia = 50000)
   AND (SELECT partidos_cumplidos FROM torneo.Suspension WHERE id_jugador = @a5 AND motivo = 'DOBLE_AMARILLA') = 1
   AND (SELECT partidos_cumplidos FROM torneo.Suspension WHERE id_jugador = @b6 AND motivo = 'ROJA_DIRECTA') = 1
   AND (SELECT partidos_cumplidos FROM torneo.Suspension WHERE id_jugador = @b4 AND motivo = 'ACUMULACION_AMARILLAS') = 0
    PRINT 'OK 9.5 - Octavos cerrado 1-0; suspensiones actualizadas';
ELSE PRINT 'FALLO 9.5';

-- Evidencia
SELECT p.id_partido, p.fase, p.goles_1, p.goles_2, p.asistencia FROM torneo.Partido p WHERE p.goles_1 IS NOT NULL ORDER BY p.id_partido;
SELECT s.id_suspension, pa.nombre AS jugador, s.motivo, s.partidos_a_cumplir, s.partidos_cumplidos
FROM torneo.Suspension s JOIN personas.Participante pa ON pa.id_participante = s.id_jugador
ORDER BY s.id_suspension;
GO

-------------------------------------- 10. PUBLICIDAD.SIMULARPRIMETIME
PRINT '=== 10. SIMULARPRIMETIME ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');

CREATE TABLE #pt (nombre NVARCHAR(80), hora_local DATETIME2(0), prime_time VARCHAR(2));

-- 10.1 OK: el partido de grupos se juega a las 16:00 en Buenos Aires = 19:00 UTC.
-- Esperado (caso obligatorio): prime time (19 a 23 h locales) en 5 mercados -mas de cuatro-:
--   Francia 20:00, Alemania 20:00, Italia 20:00, Espana 21:00 y Portugal 19:00.
--   Fuera de prime time: Argentina 16:00, Brasil 16:00, Japon 04:00, Estados Unidos 14:00, Mexico 13:00, etc.
INSERT INTO #pt EXEC publicidad.SimularPrimeTime @id_partido = @p1;
IF (SELECT COUNT(*) FROM #pt WHERE prime_time = 'SI') = 5
   AND EXISTS (SELECT 1 FROM #pt WHERE nombre = 'Francia' AND prime_time = 'SI' AND DATEPART(HOUR, hora_local) = 20)
   AND EXISTS (SELECT 1 FROM #pt WHERE nombre = 'Portugal' AND prime_time = 'SI' AND DATEPART(HOUR, hora_local) = 19)
   AND EXISTS (SELECT 1 FROM #pt WHERE nombre = 'Espana' AND prime_time = 'SI' AND DATEPART(HOUR, hora_local) = 21)
   AND EXISTS (SELECT 1 FROM #pt WHERE nombre = 'Japon' AND prime_time = 'NO' AND DATEPART(HOUR, hora_local) = 4)
   AND EXISTS (SELECT 1 FROM #pt WHERE nombre = 'Argentina' AND prime_time = 'NO' AND DATEPART(HOUR, hora_local) = 16)
    PRINT 'OK 10.1 - Cinco mercados en prime time (mas de cuatro candidatos)';
ELSE PRINT 'FALLO 10.1';

SELECT nombre AS pais, hora_local, prime_time FROM #pt ORDER BY prime_time DESC, nombre;
DROP TABLE #pt;

-- 10.2 ERROR: partido inexistente.
-- Esperado: error "no existe".
BEGIN TRY
    EXEC publicidad.SimularPrimeTime @id_partido = 0;
    PRINT 'FALLO 10.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%no existe%'
        PRINT 'OK 10.2 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 10.2 - ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 11. PUBLICIDAD.ASIGNARAUTOMATICAMENTEAPARTIDO
PRINT '=== 11. ASIGNARAUTOMATICAMENTEAPARTIDO ===';

DECLARE @p1 INT = (SELECT id_partido FROM torneo.Partido WHERE fase = 'GRUPOS');

-- 11.1 ERROR: partido inexistente.
-- Esperado: error "inexistente".
BEGIN TRY
    EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido = 0;
    PRINT 'FALLO 11.1 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%inexistente%'
        PRINT 'OK 11.1 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 11.1 - ' + ERROR_MESSAGE();
END CATCH;

-- 11.2 ERROR: todavia no hay contenidos cargados.
-- Esperado: error "cuatro contenidos"; el partido no recibe espacios.
BEGIN TRY
    EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido = @p1;
    PRINT 'FALLO 11.2 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%cuatro contenidos%' AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario)
        PRINT 'OK 11.2 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 11.2 - ' + ERROR_MESSAGE();
END CATCH;

-- Carga de publicidad por el ABM: 3 anunciantes, una campania cada uno y 9 contenidos (uno por mercado)
DECLARE @idioma INT, @an1 INT, @an2 INT, @an3 INT;
EXEC geo.Idioma_Insertar @nombre = 'Espanol', @id_idioma = @idioma OUTPUT;
EXEC publicidad.Anunciante_Insertar @nombre = 'Adidas Test', @razon_social = 'Adidas Test SA', @id_anunciante = @an1 OUTPUT;
EXEC publicidad.Anunciante_Insertar @nombre = 'Visa Test',   @razon_social = 'Visa Test SA',   @id_anunciante = @an2 OUTPUT;
EXEC publicidad.Anunciante_Insertar @nombre = 'Coca Test',   @razon_social = 'Coca Test SA',   @id_anunciante = @an3 OUTPUT;
EXEC publicidad.Campania_Insertar @id_anunciante = @an1, @cod_campania = 'CAMP1', @nombre = 'Campania Mundial Adidas';
EXEC publicidad.Campania_Insertar @id_anunciante = @an2, @cod_campania = 'CAMP1', @nombre = 'Campania Mundial Visa';
EXEC publicidad.Campania_Insertar @id_anunciante = @an3, @cod_campania = 'CAMP1', @nombre = 'Campania Mundial Coca';

DECLARE @contenidos TABLE (n INT IDENTITY(1,1), id_anunciante INT, cod_contenido VARCHAR(20), pais VARCHAR(80));
INSERT INTO @contenidos (id_anunciante, cod_contenido, pais) VALUES
    (@an1, 'C-ARG', 'Argentina'), (@an1, 'C-BRA', 'Brasil'),   (@an1, 'C-JAP', 'Japon'),
    (@an2, 'C-FRA', 'Francia'),   (@an2, 'C-ALE', 'Alemania'), (@an2, 'C-POR', 'Portugal'),
    (@an3, 'C-ITA', 'Italia'),    (@an3, 'C-ESP', 'Espana'),   (@an3, 'C-USA', 'Estados Unidos');

DECLARE @c_anun INT, @c_cod VARCHAR(20), @c_pais VARCHAR(80), @c_id_pais INT, @c INT = 1;
WHILE @c <= (SELECT COUNT(*) FROM @contenidos)
BEGIN
    SELECT @c_anun = id_anunciante, @c_cod = cod_contenido, @c_pais = pais FROM @contenidos WHERE n = @c;
    SET @c_id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = @c_pais);
    EXEC publicidad.Contenido_Insertar @id_anunciante = @c_anun, @cod_campania = 'CAMP1', @cod_contenido = @c_cod,
         @nombre = @c_cod, @id_idioma = @idioma;
    EXEC publicidad.ContenidoPais_Insertar @id_anunciante = @c_anun, @cod_campania = 'CAMP1', @cod_contenido = @c_cod,
         @id_pais = @c_id_pais;
    SET @c += 1;
END;

-- 11.3 ERROR: hay contenidos pero no hay ninguna tarifa cargada.
-- Esperado: error "tarifa"; el partido no recibe espacios.
BEGIN TRY
    EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido = @p1;
    PRINT 'FALLO 11.3 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%tarifa%' AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario)
        PRINT 'OK 11.3 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 11.3 - ' + ERROR_MESSAGE();
END CATCH;

DECLARE @tarifa_prime INT, @tarifa_regular INT;
EXEC publicidad.Tarifa_Insertar @franja = 'Regular',    @costo = 2000.00, @id_tarifa = @tarifa_regular OUTPUT;
EXEC publicidad.Tarifa_Insertar @franja = 'Prime time', @costo = 5000.00, @id_tarifa = @tarifa_prime OUTPUT;

-- 11.4 OK: asignacion automatica para Argentina-Brasil (19:00 UTC), con 5 mercados en prime time compitiendo.
-- Puntaje por contenido (1000 si el pais juega, +500 si esta en prime time, +PBI/1000):
--   C-ARG 1014, C-BRA 1009, C-ALE 552, C-FRA 545, C-ITA 538, C-ESP 532, C-POR 525, C-USA 80, C-JAP 34.
-- Esperado: quedan solo cuatro espacios, en este orden: C-ARG, C-BRA, C-ALE, C-FRA; con la tarifa mas cara
--   (Prime time) y el horario UTC del partido. Los demas candidatos prime time quedan afuera.
EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido = @p1;
IF (SELECT COUNT(*) FROM publicidad.EspacioPublicitario WHERE id_partido = @p1) = 4
   AND (SELECT cod_contenido FROM publicidad.EspacioPublicitario WHERE id_partido = @p1 AND nro = 1) = 'C-ARG'
   AND (SELECT cod_contenido FROM publicidad.EspacioPublicitario WHERE id_partido = @p1 AND nro = 2) = 'C-BRA'
   AND (SELECT cod_contenido FROM publicidad.EspacioPublicitario WHERE id_partido = @p1 AND nro = 3) = 'C-ALE'
   AND (SELECT cod_contenido FROM publicidad.EspacioPublicitario WHERE id_partido = @p1 AND nro = 4) = 'C-FRA'
   AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @p1 AND id_tarifa <> @tarifa_prime)
   AND NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario e JOIN torneo.Partido p ON p.id_partido = e.id_partido
                   WHERE e.id_partido = @p1 AND e.horario <> p.fecha_hora_utc)
    PRINT 'OK 11.4 - Cuatro piezas asignadas por prioridad: C-ARG, C-BRA, C-ALE, C-FRA';
ELSE PRINT 'FALLO 11.4';

-- 11.5 ERROR: el partido ya tiene publicidad asignada.
-- Esperado: error "ya tiene publicidad"; siguen habiendo 4 espacios.
BEGIN TRY
    EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido = @p1;
    PRINT 'FALLO 11.5 - Debio fallar';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%ya tiene publicidad%' AND (SELECT COUNT(*) FROM publicidad.EspacioPublicitario WHERE id_partido = @p1) = 4
        PRINT 'OK 11.5 - Error esperado: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 11.5 - ' + ERROR_MESSAGE();
END CATCH;

-- Evidencia
SELECT e.id_partido, e.nro, e.cod_contenido, an.nombre AS anunciante, t.franja, t.costo, e.horario AS horario_utc
FROM publicidad.EspacioPublicitario e
JOIN publicidad.Anunciante an ON an.id_anunciante = e.id_anunciante
JOIN publicidad.Tarifa t ON t.id_tarifa = e.id_tarifa
WHERE e.id_partido = @p1
ORDER BY e.nro;
GO

PRINT '=== FIN DEL TEST DE LOGICA DE NEGOCIO ===';
GO
