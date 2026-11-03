/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Script de testing para 15_SP_ImportacionMundial.sql. Importa el archivo REAL worldcup.json (torneo WC-2022)
                  y comprueba el resultado con OK o FALLO:
                    A    importación parcial: se quita el huso de Catar, fallan las sedes (y lo que depende de ellas)
                         y se importan igual las selecciones y los jugadores
                    B    se corrige el dato y se completa la importación (sedes, partidos, alineaciones)
                    C    segunda importación del mismo archivo: nada se duplica
                    D    actualización: se alteran una sede, un resultado y un jugador y se corrigen
                    E    errores de archivo: inexistente, no es JSON y torneo que no está en el archivo
                  Requisitos:
                    * Haber ejecutado los scripts 00 a 15_SP_ImportacionMundial.sql.
                    * Copiar worldcup.json (y goals.csv, para la prueba E.2) a una carpeta que pueda leer el
                      servicio de SQL Server y ajustar @carpeta (con la barra final).
                  El script borra los datos del modelo al inicio. No se usan archivos de prueba: son los reales.
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
DECLARE @carpeta VARCHAR(200) = 'C:\Users\usuario\Documents\git\TP_DDBBA';   -- << AJUSTAR (carpeta donde se cargo el repo)
DECLARE @id_imp INT, @id_messi INT, @capacidad INT;

-- Los números esperados son los del torneo WC-2022 del archivo real: 8 sedes, 32 selecciones, 831 jugadores
-- (plantillas de 26, una de 25), 64 partidos y 128 alineaciones (una por selección y partido) = 1063 registros.

-------------------------------------- A. IMPORTACION PARCIAL: falta el huso horario de Qatar
PRINT '=== A. Importacion parcial: se quita el huso de Catar de EquivalenciaPais ===';
UPDATE importacion.EquivalenciaPais SET huso_horario = NULL WHERE nombre_pais = 'Catar';
SET @ruta = @carpeta + '\TP_DDBBA_Grupo07_2900\importacion\worldcup.json';
EXEC importacion.Mundial_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

-- Esperado: las 8 sedes fallan y con ellas los 64 partidos y las 128 alineaciones (200 errores);
--           se importan igual las 32 selecciones y los 831 jugadores (863 nuevos)
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND formato = 'JSON' AND estado = 'CON_ERRORES'
           AND filas_leidas = 1063 AND filas_nuevas = 863 AND filas_error = 200)
   AND (SELECT COUNT(*) FROM torneo.Seleccion) = 32 AND (SELECT COUNT(*) FROM personas.Jugador) = 831
   AND NOT EXISTS (SELECT 1 FROM torneo.Sede) AND NOT EXISTS (SELECT 1 FROM torneo.Partido)
    PRINT 'OK A.1 - Importacion parcial: 863 nuevos y 200 errores';
ELSE PRINT 'FALLO A.1 - Revisar importacion.Importacion y importacion.Registro';
IF EXISTS (SELECT 1 FROM importacion.Registro WHERE id_importacion = @id_imp AND clave LIKE 'SEDE Lusail%' AND estado = 'ERROR' AND mensaje LIKE '%huso horario%')
   AND EXISTS (SELECT 1 FROM importacion.Registro WHERE id_importacion = @id_imp AND clave = 'PARTIDO M-2022-64' AND estado = 'ERROR' AND mensaje LIKE '%sede%')
    PRINT 'OK A.2 - Cada error informa su motivo';
ELSE PRINT 'FALLO A.2';

-------------------------------------- B. SE CORRIGE EL DATO Y SE VUELVE A IMPORTAR
PRINT '=== B. Con el huso de Catar corregido se completa lo que faltaba ===';
UPDATE importacion.EquivalenciaPais SET huso_horario = 3.00 WHERE nombre_pais = 'Catar';
SET @ruta = @carpeta + 'worldcup.json';
EXEC importacion.Mundial_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

-- Esperado: 200 nuevos (sedes, partidos, alineaciones) y 863 sin cambios
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK'
           AND filas_leidas = 1063 AND filas_nuevas = 200 AND filas_sin_cambios = 863 AND filas_error = 0)
    PRINT 'OK B.1 - 200 registros nuevos y 863 sin cambios';
ELSE PRINT 'FALLO B.1';
IF (SELECT COUNT(*) FROM torneo.Sede) = 8 AND (SELECT COUNT(*) FROM torneo.Seleccion) = 32
   AND (SELECT COUNT(*) FROM personas.Jugador) = 831 AND (SELECT COUNT(*) FROM torneo.Partido) = 64
   AND (SELECT COUNT(*) FROM torneo.Partido WHERE goles_1 IS NOT NULL) = 64
   AND (SELECT COUNT(*) FROM torneo.PartidoFormacion) = 128 AND (SELECT COUNT(*) FROM torneo.Formacion) = 128
   AND (SELECT COUNT(*) FROM torneo.FormacionTitular) = 1408
   AND (SELECT COUNT(*) FROM personas.Club) = 1
    PRINT 'OK B.2 - 8 sedes, 32 selecciones, 831 jugadores, 64 partidos con resultado y 128 alineaciones de 11 titulares';
ELSE PRINT 'FALLO B.2 - Revisar los totales de las tablas';

-- Datos puntuales del archivo: la final Argentina 3-3 Francia se jugó el 18/12/2022 a las 18:00 en Lusail (UTC+3)
IF EXISTS (SELECT 1 FROM torneo.Partido p JOIN torneo.Sede s ON s.id_sede = p.id_sede
           WHERE p.fecha = '2022-12-18' AND p.fase = 'FINAL' AND p.goles_1 = 3 AND p.goles_2 = 3
             AND s.nombre_estadio = 'Lusail Stadium' AND s.capacidad = 89000
             AND p.horario = '18:00' AND p.fecha_hora_utc = '2022-12-18 15:00:00')
   AND EXISTS (SELECT 1 FROM torneo.Partido p
               JOIN torneo.Seleccion s1 ON s1.id_seleccion = p.id_seleccion_1 JOIN geo.Pais p1 ON p1.id_pais = s1.id_pais
               WHERE p.fecha = '2022-12-18' AND p1.nombre = 'Argentina' AND s1.grupo = 'C' AND s1.confederacion = 'CONMEBOL')
    PRINT 'OK B.3 - Final: Argentina 3-3 Francia, Lusail, 18:00 local = 15:00 UTC; Argentina del grupo C de CONMEBOL';
ELSE PRINT 'FALLO B.3';
IF EXISTS (SELECT 1 FROM personas.Participante pa JOIN personas.Jugador j ON j.id_participante = pa.id_participante
           WHERE pa.dni = 'P-14758' AND pa.nombre = 'Lionel Messi' AND pa.fecha_nacimiento = '1987-06-24'
             AND j.nro_dorsal = 10 AND j.posicion = 'DELANTERO')
   AND (SELECT COUNT(*) FROM (SELECT grupo FROM torneo.Seleccion GROUP BY grupo HAVING COUNT(*) = 4) g) = 8
    PRINT 'OK B.4 - Messi (P-14758) dorsal 10 delantero; 8 grupos de 4 selecciones';
ELSE PRINT 'FALLO B.4';

-------------------------------------- C. SEGUNDA IMPORTACION DEL MISMO ARCHIVO
PRINT '=== C. Mismo archivo otra vez: no se duplica nada ===';
SET @ruta = @carpeta + 'worldcup.json';
EXEC importacion.Mundial_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK'
           AND filas_leidas = 1063 AND filas_nuevas = 0 AND filas_actualizadas = 0 AND filas_sin_cambios = 1063 AND filas_error = 0)
   AND (SELECT COUNT(*) FROM torneo.Partido) = 64 AND (SELECT COUNT(*) FROM personas.Jugador) = 831
   AND (SELECT COUNT(*) FROM torneo.Formacion) = 128 AND (SELECT COUNT(*) FROM torneo.Sede) = 8
    PRINT 'OK C.1 - 1063 registros sin cambios y ningun duplicado';
ELSE PRINT 'FALLO C.1';

-------------------------------------- D. ACTUALIZACION
PRINT '=== D. Se alteran 3 datos y la importacion los corrige ===';
SELECT @id_messi = id_participante FROM personas.Participante WHERE dni = 'P-14758';
UPDATE torneo.Sede SET capacidad = 80000 WHERE nombre_estadio = 'Lusail Stadium';
UPDATE torneo.Partido SET goles_1 = 0, goles_2 = 0 WHERE fecha = '2022-12-18';
UPDATE personas.Jugador SET posicion = 'ARQUERO' WHERE id_participante = @id_messi;

SET @ruta = @carpeta + 'worldcup.json';

EXEC importacion.Mundial_Importar @ruta = @ruta;
SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;

-- Esperado: 1 sede, 1 partido y 1 jugador ACTUALIZADOS; el resto sin cambios
IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK'
           AND filas_nuevas = 0 AND filas_actualizadas = 3 AND filas_sin_cambios = 1060 AND filas_error = 0)
   AND (SELECT capacidad FROM torneo.Sede WHERE nombre_estadio = 'Lusail Stadium') = 89000
   AND EXISTS (SELECT 1 FROM torneo.Partido WHERE fecha = '2022-12-18' AND goles_1 = 3 AND goles_2 = 3)
   AND (SELECT posicion FROM personas.Jugador WHERE id_participante = @id_messi) = 'DELANTERO'
    PRINT 'OK D.1 - Capacidad, resultado y posicion vuelven a los valores del archivo';
ELSE PRINT 'FALLO D.1';

-------------------------------------- E. ERRORES DE ARCHIVO (la importacion completa falla con THROW)
PRINT '=== E. Errores de archivo ===';
-- E.1 el archivo no existe
BEGIN TRY
    SET @ruta = @carpeta + 'no_existe.json';
    EXEC importacion.Mundial_Importar @ruta = @ruta;
    PRINT 'FALLO E.1 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje IS NOT NULL)
        PRINT 'OK E.1 - Archivo inexistente: importacion FALLIDA. ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO E.1';
END CATCH;
-- E.2 el archivo existe pero no es un JSON (se le pasa goals.csv)
BEGIN TRY
    SET @ruta = @carpeta + 'goals.csv';
    EXEC importacion.Mundial_Importar @ruta = @ruta;
    PRINT 'FALLO E.2 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje LIKE '%JSON%')
        PRINT 'OK E.2 - Un CSV no es un JSON valido: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO E.2 - ' + ERROR_MESSAGE();
END CATCH;
-- E.3 el torneo pedido no está en el archivo
BEGIN TRY
    SET @ruta = @carpeta + 'worldcup.json';
    EXEC importacion.Mundial_Importar @ruta = @ruta, @id_torneo = 'WC-1800';
    PRINT 'FALLO E.3 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje LIKE '%torneo%')
        PRINT 'OK E.3 - Torneo inexistente: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO E.3 - ' + ERROR_MESSAGE();
END CATCH;
-- E.4 los errores de archivo no tocaron los datos ya cargados
IF (SELECT COUNT(*) FROM torneo.Partido) = 64 AND (SELECT COUNT(*) FROM personas.Jugador) = 831
    PRINT 'OK E.4 - Los datos importados siguen intactos';
ELSE PRINT 'FALLO E.4';

-- Para ver la bitácora completa:
-- SELECT * FROM importacion.Importacion;  SELECT * FROM importacion.Registro WHERE estado = 'ERROR';
GO
