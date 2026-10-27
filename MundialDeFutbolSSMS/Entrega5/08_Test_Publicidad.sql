/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 26/10/2026
   Objetivo     : Script de testing para 08_SP_ABM_Publicidad.sql
                  Prueba altas, modificaciones y bajas de Anunciante, Campania,
                  Contenido, ContenidoPais, Tarifa y EspacioPublicitario,
                  incluyendo casos de error (nulos, duplicados, integridad
                  referencial, FK compuestas y contenido completo).
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

-------------------------------------- SETUP: datos base
PRINT '=== SETUP: datos base ===';

DECLARE @id_idioma_es INT, @id_idioma_en INT, @id_idioma_pt INT;
DECLARE @id_pais_arg INT, @id_pais_bra INT, @id_pais_uru INT;
DECLARE @id_ciudad_ba INT;
DECLARE @id_sede_monumental INT;
DECLARE @id_sel_arg INT, @id_sel_bra INT;
DECLARE @id_partido INT;

-- Idiomas
EXEC geo.Idioma_Insertar @nombre = 'Español',  @id_idioma = @id_idioma_es OUTPUT;
EXEC geo.Idioma_Insertar @nombre = 'Inglés',   @id_idioma = @id_idioma_en OUTPUT;
EXEC geo.Idioma_Insertar @nombre = 'Portugués',@id_idioma = @id_idioma_pt OUTPUT;

-- Países
EXEC geo.Pais_Insertar @nombre = 'Argentina', @huso_horario = -3.00, @id_pais = @id_pais_arg OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Brasil',    @huso_horario = -3.00, @id_pais = @id_pais_bra OUTPUT;
EXEC geo.Pais_Insertar @nombre = 'Uruguay',   @huso_horario = -3.00, @id_pais = @id_pais_uru OUTPUT;

-- Ciudad y Sede
EXEC geo.Ciudad_Insertar @id_pais = @id_pais_arg, @nombre = 'Buenos Aires', @huso_horario = -3.00, @id_ciudad = @id_ciudad_ba OUTPUT;
EXEC torneo.Sede_Insertar @id_ciudad = @id_ciudad_ba, @nombre_estadio = 'Monumental', @capacidad = 70000, @id_sede = @id_sede_monumental OUTPUT;

-- Selecciones
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_arg, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_arg OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @id_pais_bra, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @id_sel_bra OUTPUT;

-- Parámetros
EXEC torneo.Parametro_Insertar @clave = 'MAX_CONVOCADOS', @valor = 26;
EXEC torneo.Parametro_Insertar @clave = 'MAX_TITULARES', @valor = 11;
EXEC torneo.Parametro_Insertar @clave = 'MAX_SUPLENTES', @valor = 15;
EXEC torneo.Parametro_Insertar @clave = 'AMARILLAS_PARA_SUSPENSION', @valor = 2;

-- Partido (para probar EspacioPublicitario)
EXEC torneo.Partido_Insertar
    @id_sede = @id_sede_monumental, @fase = 'GRUPOS', @fecha = '2026-06-10', @horario = '16:00',
    @id_seleccion_1 = @id_sel_arg, @id_seleccion_2 = @id_sel_bra,
    @id_partido = @id_partido OUTPUT;

PRINT 'OK SETUP - Datos base cargados (partido id=' + CAST(@id_partido AS VARCHAR) + ')';
GO

-------------------------------------- 1. ANUNCIANTE
PRINT '=== 1. ANUNCIANTE ===';

DECLARE @id_anu1 INT, @id_anu2 INT, @id_anu3 INT;

-- 1.1 Alta válida
EXEC publicidad.Anunciante_Insertar
    @nombre = 'Coca-Cola', @razon_social = 'Coca-Cola S.A.', @id_anunciante = @id_anu1 OUTPUT;
IF @id_anu1 IS NOT NULL PRINT 'OK 1.1 - Anunciante insertado con id=' + CAST(@id_anu1 AS VARCHAR);
ELSE PRINT 'FALLO 1.1';

-- 1.2 Alta válida con trim
EXEC publicidad.Anunciante_Insertar
    @nombre = '  Nike  ', @razon_social = '  Nike Inc.  ', @id_anunciante = @id_anu2 OUTPUT;
IF @id_anu2 IS NOT NULL PRINT 'OK 1.2 - Anunciante con trim insertado';
ELSE PRINT 'FALLO 1.2';

-- 1.3 ERROR: nombre nulo
BEGIN TRY
    EXEC publicidad.Anunciante_Insertar @nombre = NULL, @razon_social = 'X S.A.';
    PRINT 'FALLO 1.3 - Debio fallar por nombre nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 1.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.4 ERROR: nombre vacío
BEGIN TRY
    EXEC publicidad.Anunciante_Insertar @nombre = '   ', @razon_social = 'X S.A.';
    PRINT 'FALLO 1.4 - Debio fallar por nombre vacio';
END TRY
BEGIN CATCH
    PRINT 'OK 1.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.5 ERROR: razón social nula
BEGIN TRY
    EXEC publicidad.Anunciante_Insertar @nombre = 'X', @razon_social = NULL;
    PRINT 'FALLO 1.5 - Debio fallar por razon social nula';
END TRY
BEGIN CATCH
    PRINT 'OK 1.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.6 ERROR: razón social duplicada
BEGIN TRY
    EXEC publicidad.Anunciante_Insertar @nombre = 'Otra', @razon_social = 'Coca-Cola S.A.';
    PRINT 'FALLO 1.6 - Debio fallar por razon social duplicada';
END TRY
BEGIN CATCH
    PRINT 'OK 1.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.7 Modificación válida
EXEC publicidad.Anunciante_Modificar
    @id_anunciante = @id_anu1, @nombre = 'Coca-Cola Company', @razon_social = 'Coca-Cola S.A.';
PRINT 'OK 1.7 - Anunciante modificado';

-- 1.8 ERROR: modificar inexistente
BEGIN TRY
    EXEC publicidad.Anunciante_Modificar @id_anunciante = 99999, @nombre = 'X', @razon_social = 'X S.A.';
    PRINT 'FALLO 1.8 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.9 ERROR: modificar a razón social de otro
BEGIN TRY
    EXEC publicidad.Anunciante_Modificar @id_anunciante = @id_anu1, @nombre = 'X', @razon_social = 'Nike Inc.';
    PRINT 'FALLO 1.9 - Debio fallar por razon social duplicada';
END TRY
BEGIN CATCH
    PRINT 'OK 1.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 1.10 Alta de anunciante sin dependencias para probar baja
EXEC publicidad.Anunciante_Insertar
    @nombre = 'Adidas', @razon_social = 'Adidas AG', @id_anunciante = @id_anu3 OUTPUT;

-- 1.11 Eliminación válida (sin campañas)
EXEC publicidad.Anunciante_Eliminar @id_anunciante = @id_anu3;
IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE id_anunciante = @id_anu3)
    PRINT 'OK 1.11 - Anunciante eliminado';
ELSE PRINT 'FALLO 1.11';

-- 1.12 ERROR: eliminar inexistente
BEGIN TRY
    EXEC publicidad.Anunciante_Eliminar @id_anunciante = 99999;
    PRINT 'FALLO 1.12 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 1.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 2. CAMPANIA
PRINT '=== 2. CAMPANIA ===';

DECLARE @id_anu1 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Coca-Cola S.A.');
DECLARE @id_anu2 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Nike Inc.');

-- 2.1 Alta válida
EXEC publicidad.Campania_Insertar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @nombre = 'Campaña Mundial 2026';
PRINT 'OK 2.1 - Campaña insertada';

-- 2.2 Alta válida con trim
EXEC publicidad.Campania_Insertar
    @id_anunciante = @id_anu2, @cod_campania = '  NK-01  ', @nombre = '  Just Do It  ';
PRINT 'OK 2.2 - Campaña con trim insertada';

-- 2.3 ERROR: anunciante inexistente
BEGIN TRY
    EXEC publicidad.Campania_Insertar @id_anunciante = 99999, @cod_campania = 'X', @nombre = 'X';
    PRINT 'FALLO 2.3 - Debio fallar por anunciante';
END TRY
BEGIN CATCH
    PRINT 'OK 2.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.4 ERROR: código nulo
BEGIN TRY
    EXEC publicidad.Campania_Insertar @id_anunciante = @id_anu1, @cod_campania = NULL, @nombre = 'X';
    PRINT 'FALLO 2.4 - Debio fallar por codigo nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.5 ERROR: nombre nulo
BEGIN TRY
    EXEC publicidad.Campania_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-NEW', @nombre = NULL;
    PRINT 'FALLO 2.5 - Debio fallar por nombre nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.6 ERROR: código duplicado para el mismo anunciante
BEGIN TRY
    EXEC publicidad.Campania_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @nombre = 'Otra';
    PRINT 'FALLO 2.6 - Debio fallar por codigo duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 2.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.7 Alta válida: mismo código pero distinto anunciante (PK compuesta)
EXEC publicidad.Campania_Insertar
    @id_anunciante = @id_anu2, @cod_campania = 'CC-2026', @nombre = 'Campaña cruzada Nike';
IF EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anu2 AND cod_campania = 'CC-2026')
    PRINT 'OK 2.7 - Mismo código en distinto anunciante permitido';
ELSE PRINT 'FALLO 2.7';

-- 2.8 Modificación válida
EXEC publicidad.Campania_Modificar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @nombre = 'Campaña Mundial 2026 (actualizada)';
IF EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anu1 AND cod_campania = 'CC-2026'
           AND nombre = 'Campaña Mundial 2026 (actualizada)')
    PRINT 'OK 2.8 - Campaña modificada';
ELSE PRINT 'FALLO 2.8';

-- 2.9 ERROR: modificar inexistente
BEGIN TRY
    EXEC publicidad.Campania_Modificar @id_anunciante = @id_anu1, @cod_campania = 'NO-EXISTE', @nombre = 'X';
    PRINT 'FALLO 2.9 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 2.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 2.10 ERROR: modificar a nombre nulo
BEGIN TRY
    EXEC publicidad.Campania_Modificar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @nombre = NULL;
    PRINT 'FALLO 2.10 - Debio fallar por nombre nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 2.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 3. CONTENIDO
PRINT '=== 3. CONTENIDO ===';

DECLARE @id_anu1 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Coca-Cola S.A.');
DECLARE @id_anu2 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Nike Inc.');
DECLARE @id_idioma_es INT = (SELECT id_idioma FROM geo.Idioma WHERE nombre = 'Español');
DECLARE @id_idioma_en INT = (SELECT id_idioma FROM geo.Idioma WHERE nombre = 'Inglés');

-- 3.1 Alta válida
EXEC publicidad.Contenido_Insertar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01',
    @nombre = 'Spot TV Español', @id_idioma = @id_idioma_es;
PRINT 'OK 3.1 - Contenido insertado';

-- 3.2 Alta válida (segundo contenido, otro idioma)
EXEC publicidad.Contenido_Insertar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-02',
    @nombre = 'Spot TV Inglés', @id_idioma = @id_idioma_en;
PRINT 'OK 3.2 - Contenido en inglés insertado';

-- 3.3 Alta válida con trim
EXEC publicidad.Contenido_Insertar
    @id_anunciante = @id_anu2, @cod_campania = 'NK-01', @cod_contenido = '  NK-C1  ',
    @nombre = '  Video Nike  ', @id_idioma = @id_idioma_en;
PRINT 'OK 3.3 - Contenido con trim insertado';

-- 3.4 ERROR: campaña inexistente
BEGIN TRY
    EXEC publicidad.Contenido_Insertar @id_anunciante = @id_anu1, @cod_campania = 'NO-EXISTE',
        @cod_contenido = 'X', @nombre = 'X', @id_idioma = @id_idioma_es;
    PRINT 'FALLO 3.4 - Debio fallar por campania';
END TRY
BEGIN CATCH
    PRINT 'OK 3.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.5 ERROR: código de contenido nulo
BEGIN TRY
    EXEC publicidad.Contenido_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = NULL, @nombre = 'X', @id_idioma = @id_idioma_es;
    PRINT 'FALLO 3.5 - Debio fallar por codigo nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 3.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.6 ERROR: nombre nulo
BEGIN TRY
    EXEC publicidad.Contenido_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-99', @nombre = NULL, @id_idioma = @id_idioma_es;
    PRINT 'FALLO 3.6 - Debio fallar por nombre nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 3.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.7 ERROR: idioma inexistente
BEGIN TRY
    EXEC publicidad.Contenido_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-99', @nombre = 'X', @id_idioma = 99999;
    PRINT 'FALLO 3.7 - Debio fallar por idioma';
END TRY
BEGIN CATCH
    PRINT 'OK 3.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.8 ERROR: código de contenido duplicado en la misma campaña
BEGIN TRY
    EXEC publicidad.Contenido_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-01', @nombre = 'Otro', @id_idioma = @id_idioma_en;
    PRINT 'FALLO 3.8 - Debio fallar por codigo duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 3.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.9 Alta válida: mismo código de contenido en otra campaña (PK compuesta)
EXEC publicidad.Contenido_Insertar
    @id_anunciante = @id_anu2, @cod_campania = 'CC-2026', @cod_contenido = 'C-01',
    @nombre = 'Contenido cruzado Nike', @id_idioma = @id_idioma_en;
IF EXISTS (SELECT 1 FROM publicidad.Contenido WHERE id_anunciante = @id_anu2 AND cod_campania = 'CC-2026' AND cod_contenido = 'C-01')
    PRINT 'OK 3.9 - Mismo código en distinta campaña permitido';
ELSE PRINT 'FALLO 3.9';

-- 3.10 Modificación válida
EXEC publicidad.Contenido_Modificar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01',
    @nombre = 'Spot TV Español (v2)', @id_idioma = @id_idioma_en;
IF EXISTS (SELECT 1 FROM publicidad.Contenido
           WHERE id_anunciante = @id_anu1 AND cod_campania = 'CC-2026' AND cod_contenido = 'C-01'
             AND nombre = 'Spot TV Español (v2)' AND id_idioma = @id_idioma_en)
    PRINT 'OK 3.10 - Contenido modificado';
ELSE PRINT 'FALLO 3.10';

-- 3.11 ERROR: modificar inexistente
BEGIN TRY
    EXEC publicidad.Contenido_Modificar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'NO-EXISTE', @nombre = 'X', @id_idioma = @id_idioma_es;
    PRINT 'FALLO 3.11 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 3.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 3.12 ERROR: modificar con idioma inexistente
BEGIN TRY
    EXEC publicidad.Contenido_Modificar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-01', @nombre = 'X', @id_idioma = 99999;
    PRINT 'FALLO 3.12 - Debio fallar por idioma';
END TRY
BEGIN CATCH
    PRINT 'OK 3.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 4. CONTENIDO PAIS
PRINT '=== 4. CONTENIDO PAIS ===';

DECLARE @id_anu1 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Coca-Cola S.A.');
DECLARE @id_pais_arg INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Argentina');
DECLARE @id_pais_bra INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Brasil');
DECLARE @id_pais_uru INT = (SELECT id_pais FROM geo.Pais WHERE nombre = 'Uruguay');

-- 4.1 Alta válida
EXEC publicidad.ContenidoPais_Insertar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01', @id_pais = @id_pais_arg;
PRINT 'OK 4.1 - Contenido dirigido a Argentina';

-- 4.2 Alta válida (segundo país objetivo)
EXEC publicidad.ContenidoPais_Insertar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01', @id_pais = @id_pais_bra;
PRINT 'OK 4.2 - Contenido dirigido a Brasil';

-- 4.3 ERROR: contenido inexistente
BEGIN TRY
    EXEC publicidad.ContenidoPais_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'NO-EXISTE', @id_pais = @id_pais_arg;
    PRINT 'FALLO 4.3 - Debio fallar por contenido';
END TRY
BEGIN CATCH
    PRINT 'OK 4.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.4 ERROR: país inexistente
BEGIN TRY
    EXEC publicidad.ContenidoPais_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-01', @id_pais = 99999;
    PRINT 'FALLO 4.4 - Debio fallar por pais';
END TRY
BEGIN CATCH
    PRINT 'OK 4.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.5 ERROR: país duplicado para el mismo contenido
BEGIN TRY
    EXEC publicidad.ContenidoPais_Insertar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-01', @id_pais = @id_pais_arg;
    PRINT 'FALLO 4.5 - Debio fallar por duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 4.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 4.6 Eliminación válida
EXEC publicidad.ContenidoPais_Eliminar
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01', @id_pais = @id_pais_bra;
IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais
               WHERE id_anunciante = @id_anu1 AND cod_campania = 'CC-2026'
                 AND cod_contenido = 'C-01' AND id_pais = @id_pais_bra)
    PRINT 'OK 4.6 - ContenidoPais eliminado';
ELSE PRINT 'FALLO 4.6';

-- 4.7 ERROR: eliminar inexistente
BEGIN TRY
    EXEC publicidad.ContenidoPais_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026',
        @cod_contenido = 'C-01', @id_pais = @id_pais_uru;
    PRINT 'FALLO 4.7 - Debio fallar por no existir la relacion';
END TRY
BEGIN CATCH
    PRINT 'OK 4.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 5. TARIFA
PRINT '=== 5. TARIFA ===';

DECLARE @id_tarifa1 INT, @id_tarifa2 INT, @id_tarifa3 INT;

-- 5.1 Alta válida
EXEC publicidad.Tarifa_Insertar @franja = 'PRIME_TIME', @costo = 15000.00, @id_tarifa = @id_tarifa1 OUTPUT;
IF @id_tarifa1 IS NOT NULL PRINT 'OK 5.1 - Tarifa PRIME_TIME insertada';
ELSE PRINT 'FALLO 5.1';

-- 5.2 Alta válida con trim
EXEC publicidad.Tarifa_Insertar @franja = '  MATUTINO  ', @costo = 8000.00, @id_tarifa = @id_tarifa2 OUTPUT;
IF @id_tarifa2 IS NOT NULL PRINT 'OK 5.2 - Tarifa MATUTINO con trim insertada';
ELSE PRINT 'FALLO 5.2';

-- 5.3 ERROR: franja nula
BEGIN TRY
    EXEC publicidad.Tarifa_Insertar @franja = NULL, @costo = 1000;
    PRINT 'FALLO 5.3 - Debio fallar por franja nula';
END TRY
BEGIN CATCH
    PRINT 'OK 5.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.4 ERROR: franja vacía
BEGIN TRY
    EXEC publicidad.Tarifa_Insertar @franja = '   ', @costo = 1000;
    PRINT 'FALLO 5.4 - Debio fallar por franja vacia';
END TRY
BEGIN CATCH
    PRINT 'OK 5.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.5 ERROR: costo nulo
BEGIN TRY
    EXEC publicidad.Tarifa_Insertar @franja = 'NOCTURNO', @costo = NULL;
    PRINT 'FALLO 5.5 - Debio fallar por costo nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 5.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.6 ERROR: costo negativo
BEGIN TRY
    EXEC publicidad.Tarifa_Insertar @franja = 'NOCTURNO', @costo = -1;
    PRINT 'FALLO 5.6 - Debio fallar por costo negativo';
END TRY
BEGIN CATCH
    PRINT 'OK 5.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.7 ERROR: franja duplicada
BEGIN TRY
    EXEC publicidad.Tarifa_Insertar @franja = 'PRIME_TIME', @costo = 20000;
    PRINT 'FALLO 5.7 - Debio fallar por franja duplicada';
END TRY
BEGIN CATCH
    PRINT 'OK 5.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.8 Modificación válida
EXEC publicidad.Tarifa_Modificar @id_tarifa = @id_tarifa1, @franja = 'PRIME_TIME', @costo = 18000.00;
IF EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa1 AND costo = 18000.00)
    PRINT 'OK 5.8 - Tarifa modificada';
ELSE PRINT 'FALLO 5.8';

-- 5.9 ERROR: modificar inexistente
BEGIN TRY
    EXEC publicidad.Tarifa_Modificar @id_tarifa = 99999, @franja = 'X', @costo = 1000;
    PRINT 'FALLO 5.9 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 5.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.10 ERROR: modificar a franja duplicada
BEGIN TRY
    EXEC publicidad.Tarifa_Modificar @id_tarifa = @id_tarifa1, @franja = 'MATUTINO', @costo = 1000;
    PRINT 'FALLO 5.10 - Debio fallar por franja duplicada';
END TRY
BEGIN CATCH
    PRINT 'OK 5.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.11 ERROR: modificar con costo negativo
BEGIN TRY
    EXEC publicidad.Tarifa_Modificar @id_tarifa = @id_tarifa1, @franja = 'PRIME_TIME', @costo = -5;
    PRINT 'FALLO 5.11 - Debio fallar por costo negativo';
END TRY
BEGIN CATCH
    PRINT 'OK 5.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5.12 Alta de tarifa sin uso para probar baja
EXEC publicidad.Tarifa_Insertar @franja = 'MADRUGADA', @costo = 3000.00, @id_tarifa = @id_tarifa3 OUTPUT;

-- 5.13 Eliminación válida (sin espacios publicitarios)
EXEC publicidad.Tarifa_Eliminar @id_tarifa = @id_tarifa3;
IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE id_tarifa = @id_tarifa3)
    PRINT 'OK 5.13 - Tarifa eliminada';
ELSE PRINT 'FALLO 5.13';

-- 5.14 ERROR: eliminar inexistente
BEGIN TRY
    EXEC publicidad.Tarifa_Eliminar @id_tarifa = 99999;
    PRINT 'FALLO 5.14 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 5.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 6. ESPACIO PUBLICITARIO
PRINT '=== 6. ESPACIO PUBLICITARIO ===';

DECLARE @id_partido INT = (SELECT TOP 1 id_partido FROM torneo.Partido ORDER BY id_partido);
DECLARE @id_anu1 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Coca-Cola S.A.');
DECLARE @id_tarifa1 INT = (SELECT id_tarifa FROM publicidad.Tarifa WHERE franja = 'PRIME_TIME');
DECLARE @id_tarifa2 INT = (SELECT id_tarifa FROM publicidad.Tarifa WHERE franja = 'MATUTINO');

-- 6.1 Alta válida sin contenido asignado
EXEC publicidad.EspacioPublicitario_Insertar
    @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
    @horario = '2026-06-10 19:00:00';
IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = 1)
    PRINT 'OK 6.1 - Espacio 1 insertado (sin contenido)';
ELSE PRINT 'FALLO 6.1';

-- 6.2 Alta válida con contenido asignado
EXEC publicidad.EspacioPublicitario_Insertar
    @id_partido = @id_partido, @nro = 2, @id_tarifa = @id_tarifa2,
    @horario = '2026-06-10 19:15:00',
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01';
IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = 2)
    PRINT 'OK 6.2 - Espacio 2 insertado (con contenido)';
ELSE PRINT 'FALLO 6.2';

-- 6.3 ERROR: partido inexistente
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = 99999, @nro = 1, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.3 - Debio fallar por partido';
END TRY
BEGIN CATCH
    PRINT 'OK 6.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.4 ERROR: número fuera de rango (0)
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 0, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.4 - Debio fallar por nro 0';
END TRY
BEGIN CATCH
    PRINT 'OK 6.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.5 ERROR: número fuera de rango (5)
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 5, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.5 - Debio fallar por nro 5';
END TRY
BEGIN CATCH
    PRINT 'OK 6.5 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.6 ERROR: número nulo
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = NULL, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.6 - Debio fallar por nro nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 6.6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.7 ERROR: espacio ya existente en el partido
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa2,
        @horario = '2026-06-10 20:00:00';
    PRINT 'FALLO 6.7 - Debio fallar por espacio duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 6.7 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.8 ERROR: tarifa inexistente
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 3, @id_tarifa = 99999,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.8 - Debio fallar por tarifa';
END TRY
BEGIN CATCH
    PRINT 'OK 6.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.9 ERROR: horario nulo
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 3, @id_tarifa = @id_tarifa1,
        @horario = NULL;
    PRINT 'FALLO 6.9 - Debio fallar por horario nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 6.9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.10 ERROR: contenido incompleto (falta campaña y código)
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 3, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:30:00', @id_anunciante = @id_anu1, @cod_campania = NULL, @cod_contenido = NULL;
    PRINT 'FALLO 6.10 - Debio fallar por contenido incompleto';
END TRY
BEGIN CATCH
    PRINT 'OK 6.10 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.11 ERROR: contenido inexistente
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 3, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:30:00', @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'NO-EXISTE';
    PRINT 'FALLO 6.11 - Debio fallar por contenido inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.11 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.12 ERROR: contenido repetido en el mismo partido
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Insertar @id_partido = @id_partido, @nro = 3, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:30:00', @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01';
    PRINT 'FALLO 6.12 - Debio fallar por contenido repetido';
END TRY
BEGIN CATCH
    PRINT 'OK 6.12 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.13 Alta válida de espacio 3 con otro contenido
EXEC publicidad.EspacioPublicitario_Insertar
    @id_partido = @id_partido, @nro = 3, @id_tarifa = @id_tarifa1,
    @horario = '2026-06-10 19:30:00',
    @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-02';
IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = 3)
    PRINT 'OK 6.13 - Espacio 3 insertado';
ELSE PRINT 'FALLO 6.13';

-- 6.14 ERROR: intentar asignar al espacio 1 el contenido C-02 que ya está en el espacio 3
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar
        @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:05:00',
        @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-02';
    PRINT 'FALLO 6.14 - Debio fallar: contenido C-02 ya en espacio 3';
END TRY
BEGIN CATCH
    PRINT 'OK 6.14 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.14b ERROR: intentar asignar al espacio 1 el contenido C-01 que ya está en el espacio 2
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar
        @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:05:00',
        @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01';
    PRINT 'FALLO 6.14b - Debio fallar: contenido C-01 ya en espacio 2';
END TRY
BEGIN CATCH
    PRINT 'OK 6.14b - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.14c Modificación válida: espacio 1 sin contenido
EXEC publicidad.EspacioPublicitario_Modificar
    @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
    @horario = '2026-06-10 19:05:00';
IF EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario
           WHERE id_partido = @id_partido AND nro = 1 AND horario = '2026-06-10 19:05:00' AND id_anunciante IS NULL)
    PRINT 'OK 6.14c - Espacio 1 modificado (sin contenido)';
ELSE PRINT 'FALLO 6.14c';
GO

-- 6.15 ERROR: modificar espacio inexistente
DECLARE @id_partido INT = (SELECT TOP 1 id_partido FROM torneo.Partido ORDER BY id_partido);
DECLARE @id_tarifa1 INT = (SELECT id_tarifa FROM publicidad.Tarifa WHERE franja = 'PRIME_TIME');
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar @id_partido = @id_partido, @nro = 99, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.15 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.15 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.16 ERROR: modificar con tarifa inexistente
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar @id_partido = @id_partido, @nro = 1, @id_tarifa = 99999,
        @horario = '2026-06-10 19:00:00';
    PRINT 'FALLO 6.16 - Debio fallar por tarifa';
END TRY
BEGIN CATCH
    PRINT 'OK 6.16 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.17 ERROR: modificar con horario nulo
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
        @horario = NULL;
    PRINT 'FALLO 6.17 - Debio fallar por horario nulo';
END TRY
BEGIN CATCH
    PRINT 'OK 6.17 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.18 ERROR: modificar con contenido incompleto
DECLARE @id_anu1 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Coca-Cola S.A.');
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00', @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = NULL;
    PRINT 'FALLO 6.18 - Debio fallar por contenido incompleto';
END TRY
BEGIN CATCH
    PRINT 'OK 6.18 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.19 ERROR: modificar con contenido inexistente
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Modificar @id_partido = @id_partido, @nro = 1, @id_tarifa = @id_tarifa1,
        @horario = '2026-06-10 19:00:00', @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'NO-EXISTE';
    PRINT 'FALLO 6.19 - Debio fallar por contenido inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.19 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 6.20 Eliminación válida (espacio 3)
EXEC publicidad.EspacioPublicitario_Eliminar @id_partido = @id_partido, @nro = 3;
IF NOT EXISTS (SELECT 1 FROM publicidad.EspacioPublicitario WHERE id_partido = @id_partido AND nro = 3)
    PRINT 'OK 6.20 - Espacio 3 eliminado';
ELSE PRINT 'FALLO 6.20';

-- 6.21 ERROR: eliminar inexistente
BEGIN TRY
    EXEC publicidad.EspacioPublicitario_Eliminar @id_partido = @id_partido, @nro = 99;
    PRINT 'FALLO 6.21 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 6.21 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;
GO

-------------------------------------- 7. INTEGRIDAD REFERENCIAL Y BAJAS EN CASCADA
PRINT '=== 7. INTEGRIDAD REFERENCIAL Y BAJAS ===';

-- 7.1 ERROR: eliminar un anunciante con campañas
DECLARE @id_anu1 INT = (SELECT id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Coca-Cola S.A.');
BEGIN TRY
    EXEC publicidad.Anunciante_Eliminar @id_anunciante = @id_anu1;
    PRINT 'FALLO 7.1 - Debio fallar: tiene campanas';
END TRY
BEGIN CATCH
    PRINT 'OK 7.1 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.2 ERROR: eliminar una campaña con contenidos
BEGIN TRY
    EXEC publicidad.Campania_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026';
    PRINT 'FALLO 7.2 - Debio fallar: tiene contenidos';
END TRY
BEGIN CATCH
    PRINT 'OK 7.2 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.3 ERROR: eliminar un contenido asignado a un espacio publicitario
BEGIN TRY
    EXEC publicidad.Contenido_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01';
    PRINT 'FALLO 7.3 - Debio fallar: esta asignado a un espacio';
END TRY
BEGIN CATCH
    PRINT 'OK 7.3 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.4 ERROR: eliminar una tarifa usada en un espacio publicitario
DECLARE @id_tarifa1 INT = (SELECT id_tarifa FROM publicidad.Tarifa WHERE franja = 'PRIME_TIME');
BEGIN TRY
    EXEC publicidad.Tarifa_Eliminar @id_tarifa = @id_tarifa1;
    PRINT 'FALLO 7.4 - Debio fallar: esta usada en espacios';
END TRY
BEGIN CATCH
    PRINT 'OK 7.4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.5 Eliminación en orden correcto: primero el espacio 2, luego el contenido
DECLARE @id_partido INT = (SELECT TOP 1 id_partido FROM torneo.Partido ORDER BY id_partido);
EXEC publicidad.EspacioPublicitario_Eliminar @id_partido = @id_partido, @nro = 2;

-- 7.6 Ahora C-01 ya no está asignado a ningún espacio (el espacio 1 quedó sin contenido en 6.14c)
EXEC publicidad.Contenido_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01';
IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido
               WHERE id_anunciante = @id_anu1 AND cod_campania = 'CC-2026' AND cod_contenido = 'C-01')
    PRINT 'OK 7.6 - Contenido C-01 eliminado (y sus países objetivo)';
ELSE PRINT 'FALLO 7.6';

-- 7.7 Verificar que ContenidoPais de C-01 también se borró
IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais
               WHERE id_anunciante = @id_anu1 AND cod_campania = 'CC-2026' AND cod_contenido = 'C-01')
    PRINT 'OK 7.7 - Países objetivo de C-01 eliminados en cascada';
ELSE PRINT 'FALLO 7.7';

-- 7.8 ERROR: eliminar contenido inexistente
BEGIN TRY
    EXEC publicidad.Contenido_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-01';
    PRINT 'FALLO 7.8 - Debio fallar por inexistente';
END TRY
BEGIN CATCH
    PRINT 'OK 7.8 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7.9 Eliminar el contenido restante C-02 y la campaña CC-2026
EXEC publicidad.Contenido_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026', @cod_contenido = 'C-02';
EXEC publicidad.Campania_Eliminar @id_anunciante = @id_anu1, @cod_campania = 'CC-2026';
IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE id_anunciante = @id_anu1 AND cod_campania = 'CC-2026')
    PRINT 'OK 7.9 - Campaña CC-2026 eliminada';
ELSE PRINT 'FALLO 7.9';

-- 7.10 Ahora sí se puede eliminar el anunciante
EXEC publicidad.Anunciante_Eliminar @id_anunciante = @id_anu1;
IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE id_anunciante = @id_anu1)
    PRINT 'OK 7.10 - Anunciante eliminado';
ELSE PRINT 'FALLO 7.10';
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
DBCC CHECKIDENT('torneo.Sede' , RESEED, 0)
DBCC CHECKIDENT('torneo.Partido' , RESEED, 0)
DBCC CHECKIDENT('publicidad.Anunciante' , RESEED, 0)
DBCC CHECKIDENT('publicidad.Tarifa' , RESEED, 0)
GO