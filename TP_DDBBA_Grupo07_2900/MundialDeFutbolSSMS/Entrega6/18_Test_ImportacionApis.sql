/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Script de testing para 18_SP_ImportacionApis.sql. Llama a las APIs REALES (Frankfurter y Nager.Date) y
                  comprueba el resultado con OK o FALLO; si el servidor no tiene Internet informa OMITIDA:
                    1    Frankfurter: carga, segunda importación sin duplicados, fn_ConvertirDesdeUsd y moneda inexistente
                    2    Nager.Date: feriados 2026 de Argentina y Brasil, país sin ISO2 informado como error,
                         fn_EsFeriado y segunda importación sin duplicados
                  Requisitos: scripts 00 a 18_SP_ImportacionApis.sql y el 10 (Ole Automation Procedures).
                  Los resultados dependen de lo que publican las APIs ese día: los controles usan rangos.
                  El script borra los datos del modelo al inicio. No se usan datos de prueba.
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

DECLARE @id_imp INT, @id INT, @id_arg INT, @id_bra INT, @n INT, @cotizacion DECIMAL(18,6), @r DECIMAL(18,2);

-- Estas pruebas llaman a las APIs reales: necesitan salida a Internet y 'Ole Automation Procedures' (script 10).
-- Si el servidor no tiene conexión cada sección informa OMITIDA y no FALLO.

-------------------------------------- SETUP
PRINT '=== SETUP: Argentina, Brasil y Narnia (Narnia no existe en importacion.EquivalenciaPais) ===';
EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @id_pais = @id_arg OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil',    @huso_horario = -3.00, @id_pais = @id_bra OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Narnia',    @huso_horario = 0.00,  @id_pais = @id OUTPUT;
IF (SELECT COUNT(*) FROM geo.Pais) = 3 PRINT 'OK SETUP - 3 paises';
ELSE PRINT 'FALLO SETUP';

-------------------------------------- 1. FRANKFURTER
PRINT '=== 1. Frankfurter - cotizaciones del dolar (GET /v1/latest?base=USD) ===';
BEGIN TRY
    EXEC importacion.TipoCambio_ImportarFrankfurter;
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    SELECT @n = COUNT(*) FROM publicidad.TipoCambio;

    -- Esperado: una fila por moneda (EUR, BRL, JPY, GBP...) con la fecha que informa el BCE
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND formato = 'API' AND estado = 'OK'
               AND filas_leidas >= 20 AND filas_nuevas = filas_leidas AND filas_error = 0)
       AND @n = (SELECT filas_leidas FROM importacion.Importacion WHERE id_importacion = @id_imp)
       AND EXISTS (SELECT 1 FROM publicidad.TipoCambio WHERE moneda = 'EUR' AND moneda_base = 'USD')
       AND EXISTS (SELECT 1 FROM publicidad.TipoCambio WHERE moneda = 'BRL' AND moneda_base = 'USD')
        PRINT 'OK 1.1 - ' + CAST(@n AS VARCHAR(10)) + ' cotizaciones nuevas, sin errores';
    ELSE PRINT 'FALLO 1.1 - Revisar importacion.Registro';

    -- 1.2 Segunda importación: la misma fecha no se duplica (si el BCE publicó otro día, queda el historial)
    EXEC importacion.TipoCambio_ImportarFrankfurter;
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'OK' AND filas_nuevas = 0 AND filas_error = 0)
       AND (SELECT COUNT(*) FROM publicidad.TipoCambio) = @n
        PRINT 'OK 1.2 - Segunda importacion sin cotizaciones duplicadas';
    ELSE PRINT 'FALLO 1.2';

    -- 1.3 Función que usa lo importado
    SELECT TOP 1 @cotizacion = cotizacion FROM publicidad.TipoCambio WHERE moneda = 'EUR' ORDER BY fecha DESC;
    SET @r = publicidad.fn_ConvertirDesdeUsd(100, 'EUR', CAST(GETDATE() AS DATE));
    IF @r = CAST(ROUND(100 * @cotizacion, 2) AS DECIMAL(18,2)) AND publicidad.fn_ConvertirDesdeUsd(100, 'USD', CAST(GETDATE() AS DATE)) = 100
       AND publicidad.fn_ConvertirDesdeUsd(100, 'XXX', CAST(GETDATE() AS DATE)) IS NULL
        PRINT 'OK 1.3 - fn_ConvertirDesdeUsd: 100 USD = ' + CAST(@r AS VARCHAR(20)) + ' EUR; USD a USD igual; moneda sin cotizacion es NULL';
    ELSE PRINT 'FALLO 1.3';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%No se pudo%' PRINT 'OMITIDA 1 - Sin conexion a Internet: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1 - ' + ERROR_MESSAGE();
END CATCH;

-- 1.4 Error de la API: una moneda base que no existe (la API responde con un error HTTP) falla con THROW
BEGIN TRY
    EXEC importacion.TipoCambio_ImportarFrankfurter @base = 'XXX';
    PRINT 'FALLO 1.4 - Debio fallar';
END TRY
BEGIN CATCH
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'FALLIDA' AND mensaje IS NOT NULL)
        PRINT 'OK 1.4 - Moneda base inexistente: importacion FALLIDA. ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 1.4 - ' + ERROR_MESSAGE();
END CATCH;

-------------------------------------- 2. NAGER.DATE
PRINT '=== 2. Nager.Date - feriados 2026 (GET /api/v3/PublicHolidays/2026/{ISO2}) ===';
BEGIN TRY
    EXEC importacion.Feriado_ImportarNager @anio = 2026;
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    SELECT @n = COUNT(*) FROM publicidad.Feriado;

    -- Esperado: Argentina y Brasil traen sus feriados; Narnia no tiene código ISO2 y es el único error
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND estado = 'CON_ERRORES'
               AND filas_nuevas >= 15 AND filas_error = 1)
       AND EXISTS (SELECT 1 FROM importacion.Registro WHERE id_importacion = @id_imp AND clave = 'Narnia' AND estado = 'ERROR' AND mensaje LIKE '%ISO2%')
       AND @n = (SELECT filas_nuevas FROM importacion.Importacion WHERE id_importacion = @id_imp)
        PRINT 'OK 2.1 - ' + CAST(@n AS VARCHAR(10)) + ' feriados nuevos; Narnia informada como error y sin frenar a los demas';
    ELSE PRINT 'FALLO 2.1 - Revisar importacion.Registro';

    IF EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_pais = @id_arg AND fecha = '2026-07-09')
       AND EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_pais = @id_arg AND fecha = '2026-05-25')
       AND EXISTS (SELECT 1 FROM publicidad.Feriado WHERE id_pais = @id_bra AND fecha = '2026-09-07')
        PRINT 'OK 2.2 - Argentina (9 de julio, 25 de mayo) y Brasil (7 de septiembre) cargados';
    ELSE PRINT 'FALLO 2.2';

    -- 2.3 Función que usa lo importado
    IF publicidad.fn_EsFeriado(@id_arg, '2026-07-09') = 1 AND publicidad.fn_EsFeriado(@id_arg, '2026-07-08') = 0
        PRINT 'OK 2.3 - fn_EsFeriado: 9/7/2026 es feriado en Argentina y el 8/7 no';
    ELSE PRINT 'FALLO 2.3';

    -- 2.4 Segunda importación: sin duplicados
    EXEC importacion.Feriado_ImportarNager @anio = 2026;
    SELECT @id_imp = MAX(id_importacion) FROM importacion.Importacion;
    IF EXISTS (SELECT 1 FROM importacion.Importacion WHERE id_importacion = @id_imp AND filas_nuevas = 0 AND filas_error = 1)
       AND (SELECT COUNT(*) FROM publicidad.Feriado) = @n
        PRINT 'OK 2.4 - Segunda importacion sin feriados duplicados';
    ELSE PRINT 'FALLO 2.4';
END TRY
BEGIN CATCH
    IF ERROR_MESSAGE() LIKE '%No se pudo%' PRINT 'OMITIDA 2 - Sin conexion a Internet: ' + ERROR_MESSAGE();
    ELSE PRINT 'FALLO 2 - ' + ERROR_MESSAGE();
END CATCH;

-- Para ver la bitácora completa:
-- SELECT * FROM importacion.Importacion;  SELECT * FROM importacion.Registro WHERE estado = 'ERROR';
GO
