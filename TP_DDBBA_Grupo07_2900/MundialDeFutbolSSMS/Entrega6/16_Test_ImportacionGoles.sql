/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Script de testing para 16_SP_ImportacionGoles.sql. Importa el archivo REAL goals.csv (torneo WC-2022)
                  sobre los datos que deja el archivo real worldcup.json y comprueba el resultado con OK o FALLO:
                    1    carga inicial de los 172 goles y control contra los marcadores de los 64 partidos
                    2    segunda importación del mismo archivo: nada se duplica
                    3    actualización: se corrige un gol alterado y se repone uno borrado
                    4    importación parcial: sin la alineación de Argentina en la final fallan sus 3 goles
                    5    errores de archivo: inexistente, no es un goals.csv y torneo sin goles
                  Requisitos:
                    * Haber ejecutado los scripts 00 a 16_SP_ImportacionGoles.sql.
                    * Copiar worldcup.json y goals.csv a una carpeta que pueda leer el servicio de SQL Server
                      y ajustar @carpeta (con la barra final).
                  El script borra los datos del modelo al inicio y vuelve a importar worldcup.json (setup).
                  No se usan archivos de prueba: son los reales.
   ============================================================================= */

USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

-- LIMPIEZA PREVIA (deja vacías las tablas del modelo y las de importación; EquivalenciaPais se conserva)
DELETE FROM importacion.Registro;
DELETE FROM importacion.Importacion;
DELETE FROM importacion.PbiCarga;
DELETE FROM importacion.ArbitroCarga;
DELETE FROM importacion.GolCarga;
DELETE FROM importacion.JsonCarga;
DELETE FROM publicidad.Feriado;
DELETE FROM publicidad.TipoCambio;
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

DECLARE @ruta VARCHAR(260);
DECLARE @carpeta VARCHAR(200) = 'C:\MundialFutbol\Datos\';   -- << AJUSTAR (con la barra final): carpeta con worldcup.json y goals.csv
DECLARE @id_imp INT, @id_final INT, @id_formacion INT, @id_arg INT, @id_messi INT;

-------------------------------------- SETUP: los goles necesitan partidos y alineaciones ya importados
PRINT '=== SETUP: Mundial_Importar con el worldcup.json real ===';
SET @ruta = @carpeta + 'worldcup.json';
EXEC importacion.Mundial_Importar @ruta = @ruta;
SELECT @id_final = id_partido FROM torneo.Partido WHERE fecha = '2022-12-18';
IF (SELECT COUNT(*) FROM torneo.Partido) = 64 AND (SELECT COUNT(*) FROM torneo.PartidoFormacion) = 128 AND NOT EXISTS (SELECT 1 FROM torneo.Gol)
    PRINT 'OK SETUP - 64 partidos, 128 alineaciones y ningun gol';
ELSE PRINT 'FALLO SETUP - Revisar 15_Test_ImportacionMundial.sql';

-------------------------------------- 1. CARGA INICIAL
PRINT '=== 1. goals.csv - los 172 goles de WC-2022 ===';
SET @ruta = @carpeta + 'goals.csv';
EXEC importacion.Goles_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND formato = 'CSV' AND estado = 'OK'
           AND filas_leidas = 172 AND filas_nuevas = 172 AND filas_error = 0)
   AND (SELECT COUNT(*) FROM torneo.Gol) = 172
    PRINT 'OK 1.1 - 172 goles nuevos, sin errores (el archivo trae goles de todos los Mundiales: se filtra WC-2022)';
ELSE PRINT 'FALLO 1.1 - Revisar importacion.Registro';

-- Esperado: los goles cargados suman los marcadores de los 64 partidos; 17 penales y 2 goles en contra
IF (SELECT SUM(goles_1 + goles_2) FROM torneo.Partido) = 172
   AND (SELECT COUNT(*) FROM torneo.Gol WHERE tipo = 'PENAL') = 17
   AND (SELECT COUNT(*) FROM torneo.Gol WHERE tipo = 'EN_CONTRA') = 2
    PRINT 'OK 1.2 - Los goles coinciden con los marcadores: 172 en total, 17 penales y 2 en contra';
ELSE PRINT 'FALLO 1.2';

-- Final: Messi (23 penal, 108), Di Maria (36), Mbappe (80 penal, 81, 118 penal); dos goles en el alargue
IF (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @id_final) = 6
   AND (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @id_final AND tipo = 'PENAL') = 3
   AND (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @id_final AND periodo = 'ALARGUE') = 2
   AND EXISTS (SELECT 1 FROM torneo.Gol g JOIN personas.Participante p ON p.id_participante = g.id_jugador_autor
               WHERE g.id_partido = @id_final AND p.dni = 'P-14758' AND g.minuto = 23 AND g.tipo = 'PENAL' AND g.periodo = 'PRIMER_TIEMPO')
    PRINT 'OK 1.3 - Final: 6 goles, 3 penales, 2 en el alargue; Messi de penal a los 23''';
ELSE PRINT 'FALLO 1.3';

-------------------------------------- 2. SEGUNDA IMPORTACION
PRINT '=== 2. Mismo archivo otra vez: no se duplica nada ===';
SET @ruta = @carpeta + 'goals.csv';
EXEC importacion.Goles_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK'
           AND filas_leidas = 172 AND filas_nuevas = 0 AND filas_actualizadas = 0 AND filas_sin_cambios = 172 AND filas_error = 0)
   AND (SELECT COUNT(*) FROM torneo.Gol) = 172
    PRINT 'OK 2.1 - 172 sin cambios y ningun duplicado';
ELSE PRINT 'FALLO 2.1';

-------------------------------------- 3. ACTUALIZACION
PRINT '=== 3. Se altera un gol y se borra otro: se corrigen en la nueva importacion ===';
SELECT @id_messi = id_participante FROM personas.Participante WHERE dni = 'P-14758';
UPDATE torneo.Gol SET tipo = 'OTRO' WHERE id_partido = @id_final AND id_jugador_autor = @id_messi AND minuto = 23;
DELETE FROM torneo.Gol WHERE id_partido = @id_final AND id_jugador_autor = @id_messi AND minuto = 108;

SET @ruta = @carpeta + 'goals.csv';

EXEC importacion.Goles_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK'
           AND filas_nuevas = 1 AND filas_actualizadas = 1 AND filas_sin_cambios = 170 AND filas_error = 0)
   AND (SELECT COUNT(*) FROM torneo.Gol) = 172
   AND EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @id_final AND id_jugador_autor = @id_messi AND minuto = 23 AND tipo = 'PENAL')
   AND EXISTS (SELECT 1 FROM torneo.Gol WHERE id_partido = @id_final AND id_jugador_autor = @id_messi AND minuto = 108)
    PRINT 'OK 3.1 - 1 gol repuesto, 1 corregido y 170 sin cambios';
ELSE PRINT 'FALLO 3.1';

-------------------------------------- 4. IMPORTACION PARCIAL
PRINT '=== 4. Sin la alineacion de Argentina en la final fallan sus 3 goles y se importan los demas ===';
SELECT @id_arg = pf.id_seleccion, @id_formacion = pf.id_formacion
FROM torneo.PartidoFormacion pf
JOIN torneo.Seleccion s ON s.id_seleccion = pf.id_seleccion
JOIN geo.Pais p ON p.id_pais = s.id_pais
WHERE pf.id_partido = @id_final AND p.nombre = 'Argentina';

DELETE FROM torneo.Gol WHERE id_partido = @id_final;
DELETE FROM torneo.FormacionTitular WHERE id_formacion = @id_formacion;
DELETE FROM torneo.FormacionSuplente WHERE id_formacion = @id_formacion;
DELETE FROM torneo.PartidoFormacion WHERE id_formacion = @id_formacion;
DELETE FROM torneo.Formacion WHERE id_formacion = @id_formacion;

SET @ruta = @carpeta + 'goals.csv';

EXEC importacion.Goles_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

-- Esperado: los 3 goles de Mbappe (Francia) se cargan; los 3 de Messi y Di Maria fallan porque no figuran en una alineacion
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'CON_ERRORES'
           AND filas_nuevas = 3 AND filas_sin_cambios = 166 AND filas_error = 3)
   AND (SELECT COUNT(*) FROM torneo.Gol WHERE id_partido = @id_final) = 3
   AND (SELECT COUNT(*) FROM importacion.Registro WHERE id_importacion = @id_imp AND estado = 'ERROR' AND mensaje LIKE '%formaciones%') = 3
    PRINT 'OK 4.1 - Importacion parcial: 3 goles nuevos y 3 errores con su motivo';
ELSE PRINT 'FALLO 4.1 - Revisar importacion.Registro';

-------------------------------------- 5. ERRORES DE ARCHIVO
PRINT '=== 5. Errores de archivo ===';
-- 5.1 el archivo no existe
BEGIN TRY
    SET @ruta = @carpeta + 'no_existe.csv';
    EXEC importacion.Goles_Importar @ruta = @ruta;
    PRINT 'FALLO 5.1 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje IS NOT NULL)
        PRINT 'OK 5.1 - Archivo inexistente: importacion FALLIDA. ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 5.1';
END CATCH;
-- 5.2 el archivo existe pero no tiene el formato de goals.csv (se le pasa worldcup.json)
BEGIN TRY
    SET @ruta = @carpeta + 'worldcup.json';
    EXEC importacion.Goles_Importar @ruta = @ruta;
    PRINT 'FALLO 5.2 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA')
        PRINT 'OK 5.2 - Un JSON no es goals.csv: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 5.2 - ' + ERROR_MESSAGE();
END CATCH;
-- 5.3 el torneo pedido no tiene goles en el archivo
BEGIN TRY
    SET @ruta = @carpeta + 'goals.csv';
    EXEC importacion.Goles_Importar @ruta = @ruta, @id_torneo = 'WC-1800';
    PRINT 'FALLO 5.3 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje LIKE '%torneo%')
        PRINT 'OK 5.3 - Torneo sin goles: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 5.3 - ' + ERROR_MESSAGE();
END CATCH;

-- Para ver la bitácora completa:
-- SELECT * FROM importacion.Importacion;  SELECT * FROM importacion.Registro WHERE estado = 'ERROR';
GO
