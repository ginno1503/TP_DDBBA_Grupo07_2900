/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Script de testing para 17_SP_Scraping.sql. Hace pedidos REALES a la web (scraping de los árbitros
                  internacionales de la página de la FIFA y del PBI per cápita de Wikipedia) y comprueba el resultado con OK o FALLO:
                    1    árbitros: carga, categoría y DNI interno, casos puntuales y segunda importación sin duplicados
                    2    PBI per cápita: carga sobre los países ya importados, valores razonables y repetición
                    3    errores: página sin el bloque de datos de la FIFA, página inexistente (404) y página sin la tabla buscada
                  Requisitos:
                    * Haber ejecutado los scripts 00 a 17_SP_Scraping.sql y el 10 (Ole Automation Procedures).
                    * El servidor necesita salida a Internet. Los resultados dependen de la página en el momento
                      de la prueba: los controles usan rangos y no valores exactos.
                    * Copiar worldcup.json a una carpeta que pueda leer el servicio de SQL Server y ajustar
                      @carpeta (con la barra final).
                  El script borra los datos del modelo al inicio. No se usan datos de prueba: son los reales.
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
DECLARE @carpeta VARCHAR(200) = 'C:\MundialFutbol\Datos\';   -- << AJUSTAR (con la barra final): carpeta con worldcup.json
DECLARE @id_imp INT, @arbitros INT, @paises INT, @con_pbi INT, @id_arg INT, @id_cat INT;

-- Estas pruebas hacen pedidos reales a Wikipedia: necesitan salida a Internet y 'Ole Automation Procedures' (script 10).

-------------------------------------- SETUP: los países salen del archivo real (los 32 de WC-2022)
PRINT '=== SETUP: Mundial_Importar con el worldcup.json real ===';
SET @ruta = @carpeta + 'worldcup.json';
EXEC importacion.Mundial_Importar @ruta = @ruta;
IF (SELECT COUNT(*) FROM geo.Pais) = 32 AND NOT EXISTS (SELECT 1 FROM geo.Pais WHERE pbi_per_capita IS NOT NULL)
    PRINT 'OK SETUP - 32 paises y ninguno con PBI cargado';
ELSE PRINT 'FALLO SETUP - Revisar 15_Test_ImportacionMundial.sql';

-------------------------------------- 1. ARBITROS (scraping de inside.fifa.com/es/refereeing/international-referees)
PRINT '=== 1. Arbitros por scraping ===';
EXEC importacion.Arbitro_ImportarWeb;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
SELECT @arbitros = COUNT(*) FROM personas.Arbitro;

-- Esperado: la lista de la FIFA trae más de mil árbitros de fútbol (rol 1) de las 6 confederaciones; se acepta un rango porque la lista cambia
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND formato = 'SCRAPING' AND estado = 'OK'
           AND filas_leidas BETWEEN 1000 AND 2500 AND filas_nuevas = filas_leidas AND filas_error = 0)
   AND @arbitros = (SELECT filas_leidas FROM importacion.Importacion WHERE id_importacion = @id_imp)
    PRINT 'OK 1.1 - ' + CAST(@arbitros AS VARCHAR(10)) + ' arbitros nuevos, sin errores';
ELSE PRINT 'FALLO 1.1 - Revisar importacion.Registro (¿hay Internet? ¿cambió la página?)';

-- Todos son categoria FIFA con DNI interno REF......; los paises se crearon si faltaban (la mayoría no son selecciones del Mundial)
IF NOT EXISTS (SELECT 1 FROM personas.Arbitro WHERE categoria <> 'FIFA')
   AND NOT EXISTS (SELECT 1 FROM personas.Participante pa JOIN personas.Arbitro a ON a.id_participante = pa.id_participante
                   WHERE pa.dni NOT LIKE 'REF[0-9][0-9][0-9][0-9][0-9][0-9]')
   AND EXISTS (SELECT 1 FROM personas.Participante pa JOIN personas.Arbitro a ON a.id_participante = pa.id_participante
               JOIN geo.Pais p ON p.id_pais = a.id_pais
               WHERE pa.nombre LIKE 'FRAPPART St%phanie' AND p.nombre = 'Francia')
   AND EXISTS (SELECT 1 FROM personas.Participante pa JOIN personas.Arbitro a ON a.id_participante = pa.id_participante
               JOIN geo.Pais p ON p.id_pais = a.id_pais
               WHERE pa.nombre = 'TELLO Facundo' AND p.nombre = 'Argentina')
    PRINT 'OK 1.2 - Categoria FIFA, DNI interno, Frappart (Francia) y Tello (Argentina) cargados';
ELSE PRINT 'FALLO 1.2';

PRINT '=== 1b. Segunda importacion: no se duplica ===';
EXEC importacion.Arbitro_ImportarWeb;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK'
           AND filas_nuevas = 0 AND filas_sin_cambios = filas_leidas AND filas_error = 0)
   AND (SELECT COUNT(*) FROM personas.Arbitro) = @arbitros
    PRINT 'OK 1.3 - Todo sin cambios y ningun arbitro duplicado';
ELSE PRINT 'FALLO 1.3';

-------------------------------------- 2. PODER ADQUISITIVO (scraping de List_of_countries_by_GDP_(PPP)_per_capita)
PRINT '=== 2. PBI per capita (PPA) por scraping ===';
EXEC importacion.Pbi_ImportarWeb;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
SELECT @paises = COUNT(*) FROM geo.Pais;
SELECT @con_pbi = COUNT(*) FROM geo.Pais WHERE pbi_per_capita IS NOT NULL;

-- Esperado: se procesan todos los países del sistema (los 32 de las selecciones y los de los árbitros) y la mayoría
-- figura en la página. Los que no (por ejemplo Gales, que no es un país independiente en esa lista) quedan como
-- ERROR de ese país y no frenan al resto.
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND formato = 'SCRAPING'
           AND estado IN ('OK', 'CON_ERRORES') AND filas_leidas = @paises AND filas_nuevas = @con_pbi AND filas_nuevas + filas_error = @paises)
   AND @con_pbi >= 28
    PRINT 'OK 2.1 - ' + CAST(@con_pbi AS VARCHAR(10)) + ' de ' + CAST(@paises AS VARCHAR(10)) + ' paises con PBI; el resto informado como error';
ELSE PRINT 'FALLO 2.1 - Revisar importacion.Registro (¿cambió la tabla de la página?)';

-- Argentina y Catar tienen valores razonables (dólares internacionales por persona) y Catar supera a Argentina
SELECT @id_arg = id_pais FROM geo.Pais WHERE nombre = 'Argentina';
SELECT @id_cat = id_pais FROM geo.Pais WHERE nombre = 'Catar';
IF (SELECT pbi_per_capita FROM geo.Pais WHERE id_pais = @id_arg) BETWEEN 15000 AND 80000
   AND (SELECT pbi_per_capita FROM geo.Pais WHERE id_pais = @id_cat) BETWEEN 60000 AND 250000
   AND (SELECT pbi_per_capita FROM geo.Pais WHERE id_pais = @id_cat) > (SELECT pbi_per_capita FROM geo.Pais WHERE id_pais = @id_arg)
    PRINT 'OK 2.2 - Argentina y Catar con valores razonables';
ELSE PRINT 'FALLO 2.2';

PRINT '=== 2b. Segunda importacion: sin duplicados ni cambios ===';
EXEC importacion.Pbi_ImportarWeb;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND filas_nuevas = 0
           AND filas_sin_cambios = @con_pbi AND filas_error = @paises - @con_pbi)
   AND (SELECT COUNT(*) FROM geo.Pais) = @paises
    PRINT 'OK 2.3 - Los valores ya cargados quedan sin cambios';
ELSE PRINT 'FALLO 2.3';

-------------------------------------- 3. ERRORES (la importación completa falla con THROW)
PRINT '=== 3. Errores ===';
-- 3.1 la página no existe: el sitio responde 404
BEGIN TRY
    EXEC importacion.Arbitro_ImportarWeb @url = 'https://en.wikipedia.org/wiki/1500_FIFA_World_Cup_officials';
    PRINT 'FALLO 3.1 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje LIKE '%404%')
        PRINT 'OK 3.1 - Pagina inexistente: importacion FALLIDA. ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.1 - ' + ERROR_MESSAGE();
END CATCH;
-- 3.1b la página existe pero no es la de la FIFA (no trae el bloque __NEXT_DATA__)
BEGIN TRY
    EXEC importacion.Arbitro_ImportarWeb @url = 'https://en.wikipedia.org/wiki/Lionel_Messi';
    PRINT 'FALLO 3.1b - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje LIKE '%__NEXT_DATA__%')
        PRINT 'OK 3.1b - Sin el bloque de datos: importacion FALLIDA. ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.1b - ' + ERROR_MESSAGE();
END CATCH;
-- 3.2 la página existe pero no tiene la tabla buscada (cambió el formato)
BEGIN TRY
    EXEC importacion.Pbi_ImportarWeb @url = 'https://en.wikipedia.org/wiki/Lionel_Messi';
    PRINT 'FALLO 3.2 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje LIKE '%tabla%')
        PRINT 'OK 3.2 - Sin la tabla esperada: importacion FALLIDA. ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 3.2 - ' + ERROR_MESSAGE();
END CATCH;
-- 3.3 los errores no tocaron lo ya importado
IF (SELECT COUNT(*) FROM personas.Arbitro) = @arbitros AND (SELECT COUNT(*) FROM geo.Pais WHERE pbi_per_capita IS NOT NULL) = @con_pbi
    PRINT 'OK 3.3 - Arbitros y PBI siguen intactos';
ELSE PRINT 'FALLO 3.3';

-- Para ver la bitácora completa:
-- SELECT * FROM importacion.Importacion;  SELECT * FROM importacion.Registro WHERE estado = 'ERROR';
GO
