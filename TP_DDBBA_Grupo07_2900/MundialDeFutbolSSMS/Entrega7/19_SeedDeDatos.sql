/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 06/11/2026
   Objetivo     : Inserción masiva de datos para continuar con la entrega 7:
                    1. Importacion General Mundial 2022: Sedes, Selecciones, Jugadores, Partidos y Alineaciones.
                    2. Importación Goles Mundial 2022.
                    3. Importación Másiva Arbitros Oficiales
                    4. Importación Moneda, Tipo de Cambio
                    5. Importación Feriados
                    6. Asignacion arbitral y conflicto de nacionalidad
                        6.1 Caso de Asignacion por conflicto de nacionalidad 
                    7. Generación Aleatoria de Tarjetas y Expulsiones
                    8. Generación Publicitaria y Asignación
                        8.1 Generación
                        8.2 Asignación
                    9. Caso Obligatorio: Cambio por Lesión (< 20 mins)
                    10.Caso Obligatorio: Suspensión por Acumulación y Doble Amarilla
                        10.1. Forzar Acumulación (Mismo jugador, 2 partidos distintos)
                        10.2. Forzar Doble Amarilla (Mismo jugador, mismo partido)
                    11. Importacion Info Clubes
                    12. Importacion Husos Horarios
                 
  ============================================================================= */

USE MundialFutbol;
GO

DECLARE @ruta VARCHAR(260);
DECLARE @repo VARCHAR(200) = 'C:\Users\golde\Documents\Universidad\BDA_TP\TP_DDBBA_Grupo07_2900\TP_DDBBA_Grupo07_2900';   -- << AJUSTAR: único dato a cambiar, la carpeta donde está el repo (con o sin barra final)
DECLARE @carpeta VARCHAR(260) = CASE WHEN RIGHT(@repo, 1) = '\' THEN @repo ELSE @repo + '\' END + 'importacion\';   -- worldcup.json y goals.csv

--============================================================================================
-- 1. Importación General Mundial 2022: Sedes, Selecciones, Jugadores, Partidos y Alineaciones
--============================================================================================

PRINT '1. Importación General Mundial 2022.'

SET @ruta = @carpeta + 'worldcup.json';
DECLARE @id_torneo VARCHAR(10) = 'WC-2022';
EXEC importacion.Mundial_Importar @ruta = @ruta, @id_torneo = @id_torneo;

-- Importa Sedes, Selecciones, Jugadores, Partidos y Alineaciones
-- Verificación
-- SELECT * FROM torneo.Sede
-- SELECT * FROM torneo.Seleccion
-- SELECT * FROM personas.Jugador
-- SELECT * FROM torneo.Partido 
-- SELECT * FROM torneo.Formacion

PRINT 'Ok - Importación General.'

--============================================================================================
-- 2. Importación Goles Mundial 2022.
--============================================================================================

PRINT '2. Importación Goles Mundial 2022.'

SET @ruta = @carpeta + 'goals.csv';
EXEC importacion.Goles_Importar @ruta = @ruta, @id_torneo = @id_torneo;

-- Importa los goles del torneo
-- Verificación
-- SELECT * FROM torneo.Gol

PRINT 'Ok - Importación Goles.'

--============================================================================================
-- 2. Importación Másiva Arbitros Oficiales
--============================================================================================

PRINT '2. Importación Másiva Arbitros Oficiales.'

-- ARBITROS
EXEC importacion.Arbitro_ImportarWeb;

-- SELECT * FROM personas.Arbitro

PRINT 'Ok - Importación Arbitros.'

--============================================================================================
-- 3. Importación PBI Paises
--============================================================================================
PRINT '3. Importación PBI Paises.'

-- PBI paises
EXEC importacion.Pbi_ImportarWeb;

-- SELECT * FROM geo.Pais

PRINT 'Ok - Importación PBI Paises.'

--============================================================================================
-- 4. Importación Moneda, Tipo de Cambio
--============================================================================================
PRINT '4. Importación Moneda, Tipo de Cambio.'

-- Cotizaciones Moneda 
EXEC importacion.TipoCambio_ImportarFrankfurter;

-- SELECT * FROM publicidad.TipoCambio

PRINT 'Ok - Importación Moneda, Tipo de Cambio.'

--============================================================================================
-- 5. Importación Feriados
--============================================================================================
PRINT '5. Importación Feriados'

-- Feriados 
EXEC importacion.Feriado_ImportarNager @anio = 2022;

-- SELECT * FROM publicidad.Feriado

PRINT 'Ok - Importación Feriados'

-- ===============================================================================================
--  6. Asignacion arbitral y conflicto de nacionalidad
-- ===============================================================================================

PRINT '6. Asignación Aleatoria y conflicto de nacionalidad.';
GO

-- 6 Arbitros por partido: principal, var, asistente 1 y 2, cuarto arbitro

CREATE OR ALTER PROCEDURE torneo.AsignarArbitrosAleatoriamente
AS
BEGIN
    
    CREATE TABLE #PartidosArbitraje
    (
        id_partido INT, 
        p_ref INT, v_ref INT, a1_ref INT, a2_ref INT, c_ref INT
    );

    -- Buscamos los arbitros válidos para cada partido asegurandose que sean diferentes personas
    -- CTE de una consulta join que muestra los arbitros que son validos para cada partido y los enumera
    WITH ArbitrosValidosPorPartido AS 
    (
        SELECT  p.id_partido,
                a.id_participante, 
                ROW_NUMBER() OVER (PARTITION BY p.id_partido ORDER BY NEWID() ) as orden_arbitro
        FROM torneo.Partido p
        JOIN torneo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion
        JOIN torneo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion
        JOIN personas.Arbitro a ON a.id_pais NOT IN(s1.id_pais, s2.id_pais)
    )

    INSERT INTO #PartidosArbitraje (id_partido, p_ref, v_ref, a1_ref, a2_ref, c_ref)
    SELECT 
        id_partido, 
        [1] AS p_ref,
        [2] AS v_ref,
        [3] AS a1_ref,
        [4] AS a2_ref,
        [5] AS c_ref
    FROM (
        SELECT id_partido, id_participante, orden_arbitro
        FROM ArbitrosValidosPorPartido
        WHERE orden_arbitro <= 5 
    ) AS Origen 
    PIVOT ( 
        MAX(id_participante)  -- Ignora los NULOS causados por la naturaleza de la consulta y rellena efectivamente con el único valor válido
        FOR orden_arbitro IN ([1], [2], [3], [4], [5])
    ) AS OrganizacionPivot

    DECLARE @id_part INT, 
            @p_ref INT,
            @v_ref INT, 
            @a1_ref INT,
            @a2_ref INT,
            @c_ref INT;

    SELECT @id_part = MIN(id_partido) FROM #PartidosArbitraje
    
    WHILE @id_part IS NOT NULL
    BEGIN
        
        SELECT  @p_ref = p_ref, 
                @v_ref = v_ref, 
                @a1_ref = a1_ref, 
                @a2_ref = a2_ref,
                @c_ref = c_ref
        FROM #PartidosArbitraje 
        WHERE id_partido = @id_part; 

        BEGIN TRY
            EXEC torneo.Partido_DesignarArbitros @id_part, @p_ref, @v_ref, @a1_ref, @a2_ref, @c_ref
        END TRY
            
        BEGIN CATCH
            PRINT 'Error en el partido con id ' + CAST(@id_part as VARCHAR(10));
        END CATCH

        SELECT @id_part = MIN(id_partido) FROM #PartidosArbitraje WHERE id_partido > @id_part --siguiente

    END;

    PRINT 'Ok. Asignacion Aleatoria en todos los partidos Finalizada'

    DROP TABLE #PartidosArbitraje;
END
GO

IF 
    ( SELECT COUNT(id_arbitro) FROM torneo.ArbitroSecundario  ) <> 192 
    OR  
    ( SELECT COUNT (id_arbitro_principal) FROM torneo.Partido ) <> 64
    EXEC torneo.AsignarArbitrosAleatoriamente -- Asigna o Reasigna

--Verificación: 
-- SELECT * FROM torneo.Partido
-- SELECT * FROM torneo.ArbitroSecundario

-- =======================================================
-- 6.1 Caso de Asignacion por conflicto de nacionalidad 
-- =======================================================


PRINT '----Caso de Asignacion por conflicto de nacionalidad----'

DECLARE @id_partido_arg INT, @id_arbitro_arg INT;

SELECT TOP 1 @id_partido_arg = p.id_partido FROM torneo.Partido p 
JOIN torneo.Seleccion s ON s.id_seleccion = p.id_seleccion_1 JOIN geo.Pais pa ON pa.id_pais = s.id_pais WHERE pa.nombre = 'Argentina';

SELECT TOP 1 @id_arbitro_arg = a.id_participante 
FROM personas.Arbitro a 
JOIN geo.Pais p ON p.id_pais = a.id_pais
WHERE p.nombre = 'Argentina';

BEGIN TRY
    EXEC torneo.Partido_DesignarArbitros @id_partido_arg, @id_arbitro_arg, @id_arbitro_arg, @id_arbitro_arg, @id_arbitro_arg, @id_arbitro_arg;
END TRY

BEGIN CATCH
    PRINT 'Ok - Caso: Conflicto de nacionalidad capturado exitosamente:' + ERROR_MESSAGE();
END CATCH;


-- ==========================================================================================
-- 7. Generación Aleatoria de Tarjetas y Expulsiones
-- ==========================================================================================

PRINT '7. Generación Aleatoria de Tarjetas y Expulsiones';
GO

CREATE OR ALTER PROCEDURE torneo.generarAmonestacionesAleatorias
AS
BEGIN
    
    CREATE TABLE #Tarjetas 
    (
        id INT IDENTITY(1,1),
        id_partido INT, 
        id_jugador INT,
        minuto TINYINT, 
        color VARCHAR(8)
    );

    --  AMARILLA
    INSERT INTO #Tarjetas(id_partido, id_jugador, minuto, color)
    SELECT TOP 100
        id_partido,
        id_jugador,
        minuto,
        color
    FROM (

        SELECT
            pf.id_partido,
            ft.id_jugador,
            CAST(ABS(CHECKSUM(NEWID())) % 91 AS TINYINT) AS Minuto, -- Del minuto 0 al 90
            'AMARILLA' AS Color,
            ROW_NUMBER() OVER (PARTITION BY pf.id_partido, ft.id_jugador ORDER BY NEWID()) AS cantidad_tarjetas_jugador 
        FROM torneo.PartidoFormacion pf
        JOIN torneo.FormacionTitular ft ON pf.id_formacion = ft.id_formacion

    ) AS TarjetasAleatorias
    WHERE cantidad_tarjetas_jugador <= 2 -- Un jugador solo puede tener 2 tarjetas amarillas máximo
    ORDER BY NEWID()

    --ROJA DIRECTA

    INSERT INTO #Tarjetas(id_partido, id_jugador, minuto, color)
    SELECT TOP 5
        id_partido,
        id_jugador,
        minuto,
        color
    FROM (

        SELECT
            pf.id_partido,
            ft.id_jugador,
            CAST(ABS(CHECKSUM(NEWID())) % 91 AS TINYINT) AS Minuto, -- Del minuto 0 al 90
            'ROJA' AS Color,
            ROW_NUMBER() OVER (PARTITION BY pf.id_partido, ft.id_jugador ORDER BY NEWID()) AS cantidad_tarjetas_jugador 
        FROM torneo.PartidoFormacion pf
        JOIN torneo.FormacionTitular ft ON pf.id_formacion = ft.id_formacion

    ) AS TarjetasAleatorias
    WHERE cantidad_tarjetas_jugador <= 1 -- Un jugador solo puede tener 1 tarjetas roja como máximo
    ORDER BY NEWID()

    DECLARE @id_tarjeta INT,
            @id_partido INT, 
            @id_jugador  INT, 
            @minuto TINYINT, 
            @color CHAR(8);
    DECLARE @nro_sancion TINYINT, @motivo_susp VARCHAR(25);;

    SELECT @id_tarjeta = MIN(id) FROM #Tarjetas;

    WHILE @id_tarjeta IS NOT NULL 
    BEGIN
        
        SELECT  @id_partido = id_partido, 
                @id_jugador = id_jugador,
                @minuto = minuto,
                @color = color
        FROM #Tarjetas 
        WHERE id = @id_tarjeta;

        BEGIN TRY 
            EXEC torneo.Tarjeta_Registrar @id_partido, @id_jugador, @color, @minuto, 'Falta de Juego', @nro_sancion OUTPUT, @motivo_susp OUTPUT; -- Se puede mejorar el nro y el motivo
        END TRY

        BEGIN CATCH
            PRINT 'Error en la asignación de Tarjetas.'
        END CATCH

        SELECT @id_tarjeta = MIN(id) FROM #Tarjetas WHERE id > @id_tarjeta; -- Siguiente

    END

    DROP TABLE #Tarjetas

END
GO

IF ( SELECT COUNT(nro) FROM torneo.Expulsion ) < 50 AND
 ( SELECT COUNT(nro) FROM torneo.Sancion ) < 6
    EXEC torneo.generarAmonestacionesAleatorias 

PRINT 'Ok - Generación Aleatoria de Tarjetas y Expulsiones'

--Verificación: 
-- SELECT * FROM torneo.Expulsion
-- SELECT * FROM torneo.Sancion

-- ==========================================================================================
-- 8. Generacion Publicitaria y Asignación 
-- ==========================================================================================

PRINT '8.1. Generacion Publicitaria ';
GO

CREATE OR ALTER PROCEDURE publicidad.generarPublicidad
AS
BEGIN

   SET NOCOUNT ON;

    -- Variables para ids
    DECLARE @id_idioma_es INT, @id_idioma_ing INT, @id_idioma_ar INT;
    DECLARE @id_tarifa INT;
    DECLARE @id_a1 INT, @id_a2 INT, @id_a3 INT, @id_a4 INT, @id_a5 INT, @id_a6 INT, @id_a7 INT;
    DECLARE @id_p1 INT, @id_p2 INT, @id_p3 INT, @id_p4 INT, @id_p5 INT, @id_p6 INT, @id_p7 INT;

    BEGIN TRY 
        BEGIN TRANSACTION; 

        -- Idiomas 
        IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE nombre = 'Español')
            EXEC geo.Idioma_Insertar 'Español', @id_idioma_es OUTPUT;
        ELSE 
            SELECT @id_idioma_es = id_idioma FROM geo.Idioma WHERE nombre = 'Español';

       IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE nombre = 'Ingles')
            EXEC geo.Idioma_Insertar 'Ingles', @id_idioma_ing OUTPUT;
        ELSE 
            SELECT @id_idioma_ing = id_idioma FROM geo.Idioma WHERE nombre = 'Ingles';

       IF NOT EXISTS (SELECT 1 FROM geo.Idioma WHERE nombre = 'Arabe')
            EXEC geo.Idioma_Insertar 'Arabe', @id_idioma_ar OUTPUT;
        ELSE 
            SELECT @id_idioma_ar = id_idioma FROM geo.Idioma WHERE nombre = 'Arabe';


            SELECT * FROM publicidad.tarifa
        -- Tarifa 150.000 USD por espacio
        IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE franja = 'Prime Time Mundial')
            EXEC publicidad.Tarifa_Insertar 'Prime Time Mundial', 250000.00, @id_tarifa OUTPUT;
        ELSE 
            SELECT @id_tarifa = id_tarifa FROM publicidad.Tarifa WHERE franja = 'Prime Time Mundial';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE franja = 'Tarde')
            EXEC publicidad.Tarifa_Insertar 'Tarde', 150000.00, @id_tarifa OUTPUT;
        ELSE 
            SELECT @id_tarifa = id_tarifa FROM publicidad.Tarifa WHERE franja = 'Tarde';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE franja = 'Mediodia')
            EXEC publicidad.Tarifa_Insertar 'Mediodia', 75000.00, @id_tarifa OUTPUT;
        ELSE 
            SELECT @id_tarifa = id_tarifa FROM publicidad.Tarifa WHERE franja = 'Mediodia';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Tarifa WHERE franja = 'Mañana')
            EXEC publicidad.Tarifa_Insertar 'Mañana', 50000.00, @id_tarifa OUTPUT;
        ELSE 
            SELECT @id_tarifa = id_tarifa FROM publicidad.Tarifa WHERE franja = 'Mañana';


        -- Anunciantes (Se busca si existe, sino se inserta)
        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'Adidas AG')
            EXEC publicidad.Anunciante_Insertar 'Adidas', 'Adidas AG', @id_a1 OUTPUT;
        ELSE SELECT @id_a1 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Adidas AG';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'The Coca-Cola Company')
            EXEC publicidad.Anunciante_Insertar 'Coca-Cola', 'The Coca-Cola Company', @id_a2 OUTPUT;
        ELSE SELECT @id_a2 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'The Coca-Cola Company';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'Hyundai Motor Co')
            EXEC publicidad.Anunciante_Insertar 'Hyundai', 'Hyundai Motor Co', @id_a3 OUTPUT;
        ELSE SELECT @id_a3 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Hyundai Motor Co';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'Visa Inc')
            EXEC publicidad.Anunciante_Insertar 'Visa', 'Visa Inc', @id_a4 OUTPUT;
        ELSE SELECT @id_a4 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Visa Inc';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'Qatar Airways Group')
            EXEC publicidad.Anunciante_Insertar 'Qatar Airways', 'Qatar Airways Group', @id_a5 OUTPUT;
        ELSE SELECT @id_a5 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Qatar Airways Group';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'Laboratorios Andrómaco')
            EXEC publicidad.Anunciante_Insertar 'Dermaglós', 'Laboratorios Andrómaco', @id_a6 OUTPUT;
        ELSE SELECT @id_a6 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Laboratorios Andrómaco';

        IF NOT EXISTS (SELECT 1 FROM publicidad.Anunciante WHERE razon_social = 'Cervecerías Unidas Argentina')
            EXEC publicidad.Anunciante_Insertar 'Schneider', 'Cervecerías Unidas Argentina', @id_a7 OUTPUT;
        ELSE SELECT @id_a7 = id_anunciante FROM publicidad.Anunciante WHERE razon_social = 'Cervecerías Unidas Argentina';

        -- Campañas
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-ADI') 
            EXEC publicidad.Campania_Insertar @id_a1, 'CAMP-ADI', 'Impossible is Nothing';
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-KO')  
            EXEC publicidad.Campania_Insertar @id_a2, 'CAMP-KO', 'Real Magic';
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-HYU') 
            EXEC publicidad.Campania_Insertar @id_a3, 'CAMP-HYU', 'Goal of the Century';
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-VIS') 
            EXEC publicidad.Campania_Insertar @id_a4, 'CAMP-VIS', 'Everywhere You Want to Be';
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-QAT') 
            EXEC publicidad.Campania_Insertar @id_a5, 'CAMP-QAT', 'Going Places Together';
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-DER') 
            EXEC publicidad.Campania_Insertar @id_a6, 'CAMP-DER', 'En la cancha, cada detalle cuenta';
        IF NOT EXISTS (SELECT 1 FROM publicidad.Campania WHERE cod_campania = 'CAMP-SCH') 
            EXEC publicidad.Campania_Insertar @id_a7, 'CAMP-SCH', 'La plaga';

        -- Contenidos
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-ADI') 
            EXEC publicidad.Contenido_Insertar @id_a1, 'CAMP-ADI', 'SPOT-ADI', 'Spot Zapatos', @id_idioma_ing;
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-KO')  
            EXEC publicidad.Contenido_Insertar @id_a2, 'CAMP-KO', 'SPOT-KO', 'Spot Bebida', @id_idioma_es;
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-HYU') 
            EXEC publicidad.Contenido_Insertar @id_a3, 'CAMP-HYU', 'SPOT-HYU', 'Spot Auto', @id_idioma_ing;
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-VIS') 
            EXEC publicidad.Contenido_Insertar @id_a4, 'CAMP-VIS', 'SPOT-VIS', 'Spot Tarjeta', @id_idioma_es;
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-QAT') 
            EXEC publicidad.Contenido_Insertar @id_a5, 'CAMP-QAT', 'SPOT-QAT', 'Spot Vuelo', @id_idioma_ar;
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-DER') 
            EXEC publicidad.Contenido_Insertar @id_a6, 'CAMP-DER', 'SPOT-DER', 'Spot Protector', @id_idioma_es;
        IF NOT EXISTS (SELECT 1 FROM publicidad.Contenido WHERE cod_contenido = 'SPOT-SCH') 
            EXEC publicidad.Contenido_Insertar @id_a7, 'CAMP-SCH', 'SPOT-SCH', 'Spot Cerveza', @id_idioma_es;


        -- Vincular contenido a pais

        -- Buscamos (o insertamos si no existen) 6 países estratégicos para forzar el Prime Time
        IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Emiratos Arabes') 
            EXEC geo.Pais_Insertar 'Emiratos Arabes', 4.0, 45000, @id_p1 OUTPUT;
        ELSE SELECT @id_p1 = id_pais FROM geo.Pais WHERE nombre = 'Emiratos Arabes';

        IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Pakistan') 
            EXEC geo.Pais_Insertar 'Pakistan', 5.0, 1500, @id_p2 OUTPUT;
        ELSE SELECT @id_p2 = id_pais FROM geo.Pais WHERE nombre = 'Pakistan';

        IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'India') 
            EXEC geo.Pais_Insertar 'India', 5.5, 11748.00, @id_p3 OUTPUT;
        ELSE SELECT @id_p3 = id_pais FROM geo.Pais WHERE nombre = 'India';

        IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Bangladesh') 
            EXEC geo.Pais_Insertar 'Bangladesh', 6.0, 9646.00, @id_p4 OUTPUT;
        ELSE SELECT @id_p4 = id_pais FROM geo.Pais WHERE nombre = 'Bangladesh';

        IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Tailandia') 
            EXEC geo.Pais_Insertar 'Tailandia', 7.0, 26250.00, @id_p5 OUTPUT;
        ELSE SELECT @id_p5 = id_pais FROM geo.Pais WHERE nombre = 'Tailandia';

        IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'China') 
            EXEC geo.Pais_Insertar 'China', 8.0, 13500, @id_p6 OUTPUT;
        ELSE SELECT @id_p6 = id_pais FROM geo.Pais WHERE nombre = 'China';

         IF NOT EXISTS (SELECT 1 FROM geo.Pais WHERE nombre = 'Argentina') 
            EXEC geo.Pais_Insertar 'Argentina ', -3, 32587.00, @id_p7 OUTPUT;
        ELSE SELECT @id_p7 = id_pais FROM geo.Pais WHERE nombre = 'Argentina';

        -- Vincular contenido a país (Cargamos la tabla publicidad.ContenidoPais)
        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-ADI' AND id_pais = @id_p1) 
            EXEC publicidad.ContenidoPais_Insertar @id_a1, 'CAMP-ADI', 'SPOT-ADI', @id_p1;
            
        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-KO' AND id_pais = @id_p2)  
            EXEC publicidad.ContenidoPais_Insertar @id_a2, 'CAMP-KO', 'SPOT-KO', @id_p2;
            
        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-HYU' AND id_pais = @id_p3) 
            EXEC publicidad.ContenidoPais_Insertar @id_a3, 'CAMP-HYU', 'SPOT-HYU', @id_p3;
            
        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-VIS' AND id_pais = @id_p4) 
            EXEC publicidad.ContenidoPais_Insertar @id_a4, 'CAMP-VIS', 'SPOT-VIS', @id_p4;
            
        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-QAT' AND id_pais = @id_p5) 
            EXEC publicidad.ContenidoPais_Insertar @id_a5, 'CAMP-QAT', 'SPOT-QAT', @id_p5;

        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-QAT' AND id_pais = @id_p6) 
            EXEC publicidad.ContenidoPais_Insertar @id_a5, 'CAMP-QAT', 'SPOT-QAT', @id_p6;
            
        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-DER' AND id_pais = @id_p7) 
            EXEC publicidad.ContenidoPais_Insertar @id_a6, 'CAMP-DER', 'SPOT-DER', @id_p6;

        IF NOT EXISTS (SELECT 1 FROM publicidad.ContenidoPais WHERE cod_contenido = 'SPOT-SCH' AND id_pais = @id_p7) 
            EXEC publicidad.ContenidoPais_Insertar @id_a7, 'CAMP-SCH', 'SPOT-SCH', @id_p7;
        

        COMMIT TRANSACTION; 
        PRINT 'Ok - Contenido Pais Generado.'
    
    END TRY 

    BEGIN CATCH

        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION; 
        PRINT 'Error en la generacion contenido pais: ' + ERROR_MESSAGE(); 
        THROW; 
    
    END CATCH;

 END
GO


 EXEC publicidad.generarPublicidad
 GO

 -- Verificacion: 
 -- SELECT * FROM publicidad.Anunciante
 -- SELECT * FROM publicidad.Campania 
 -- SELECT * FROM publicidad.Contenido
 -- SELECT * FROM publicidad.ContenidoPais

 PRINT 'Ok - Publicidad y Prime Time'
 GO


 -- =========================================================================================
 --8.2 Asignacion masiva a todos los partiods
 -- =========================================================================================

PRINT '8.2 Asignacion masiva a todos los partiods';
GO

CREATE OR ALTER PROCEDURE publicidad.AsignarPublicidadMasiva
AS
BEGIN
    
    SET NOCOUNT ON;

    DECLARE @id_partido INT;
    DECLARE @cantidad_asignados INT = 0;

    -- Tabla temporal para almacenar solo los partidos que no tienen publicidad
    CREATE TABLE #PartidosSinPublicidad (
        id_partido INT PRIMARY KEY
    );

    INSERT INTO #PartidosSinPublicidad (id_partido)
    SELECT p.id_partido
    FROM torneo.Partido p
    WHERE NOT EXISTS (
        SELECT 1 FROM publicidad.EspacioPublicitario ep 
        WHERE ep.id_partido = p.id_partido
    );

    SELECT @id_partido = MIN(id_partido) FROM #PartidosSinPublicidad;

    -- Asignamos partido por partido
    WHILE @id_partido IS NOT NULL
    BEGIN
        BEGIN TRY

            -- SP que hace todo el trabajo
            EXEC publicidad.AsignarAutomaticamenteAPartido @id_partido;

        END TRY

        BEGIN CATCH

            PRINT 'Error asignando publicidad al partido ' + CAST(@id_partido AS VARCHAR) + ': ' + ERROR_MESSAGE();
        
        END CATCH;

        SELECT @id_partido = MIN(id_partido) FROM #PartidosSinPublicidad WHERE id_partido > @id_partido;
    END

    DROP TABLE #PartidosSinPublicidad;
    PRINT 'OK - Asignación finalizada.';
END;
GO


EXEC publicidad.AsignarPublicidadMasiva

-- Verificación: 
-- SELECT * FROM publicidad.EspacioPublicitario


-- ==========================================================================================
-- 9. Caso Obligatorio: Cambio por Lesión (< 20 mins)
-- ==========================================================================================
PRINT '9. Caso Obligatorio: Cambio por Lesión en primeros 20 minutos.';
GO

DECLARE @partido_cambio INT, @jugador_sale INT, @jugador_entra INT, @nro_cambio TINYINT;

-- Del primer partido disponible y extrae un titular y un suplente de la misma formación
SELECT TOP 1 
    @partido_cambio = pf.id_partido, 
    @jugador_sale = ft.id_jugador, 
    @jugador_entra = fs.id_jugador
FROM torneo.PartidoFormacion pf
JOIN torneo.FormacionTitular ft ON pf.id_formacion = ft.id_formacion
JOIN torneo.FormacionSuplente fs ON pf.id_formacion = fs.id_formacion;

BEGIN TRY
    EXEC torneo.Cambio_Registrar @partido_cambio, @jugador_sale, @jugador_entra, 12, 'PRIMER_TIEMPO', 'LESION', @nro_cambio OUTPUT;
    PRINT 'Ok - Cambio por lesión al minuto 12 registrado con éxito.';
END TRY
BEGIN CATCH
    PRINT 'El cambio por lesión ya estaba registrado o hubo un error: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ==========================================================================================
-- 10. Caso Obligatorio: Suspensión por Acumulación y Doble Amarilla
-- ==========================================================================================
PRINT '10. Casos Obligatorios: Acumulación de Amarillas y Doble Amarilla.';
GO

DECLARE @jugador_acumula INT, @partido_A INT, @partido_B INT;
DECLARE @jugador_doble INT, @partido_exp INT;
DECLARE @nro_sancion TINYINT, @motivo_susp VARCHAR(25);

--========================================================================
-- 10.1. Forzar Acumulación (Mismo jugador, 2 partidos distintos)
--========================================================================
PRINT '10.1. Forzar Acumulación (Mismo jugador, 2 partidos distintos)'

-- Toma un jugador titular en dos partidos
SELECT TOP 1 
    @jugador_acumula = ft1.id_jugador, @partido_A = pf1.id_partido, @partido_B = pf2.id_partido
FROM torneo.FormacionTitular ft1
JOIN torneo.PartidoFormacion pf1 ON ft1.id_formacion = pf1.id_formacion
JOIN torneo.FormacionTitular ft2 ON ft1.id_jugador = ft2.id_jugador
JOIN torneo.PartidoFormacion pf2 ON ft2.id_formacion = pf2.id_formacion
WHERE pf1.id_partido <> pf2.id_partido;

BEGIN TRY
    EXEC torneo.Tarjeta_Registrar @partido_A, @jugador_acumula, 'AMARILLA', 25, 'Falta táctica', @nro_sancion OUTPUT, @motivo_susp OUTPUT;
    EXEC torneo.Tarjeta_Registrar @partido_B, @jugador_acumula, 'AMARILLA', 65, 'Sujeción', @nro_sancion OUTPUT, @motivo_susp OUTPUT;
    PRINT 'Ok - Jugador suspendido por acumulación en distintos partidos.';
END TRY
BEGIN CATCH
END CATCH;
    
--================================================================================
-- 10.2. Forzar Doble Amarilla (Mismo jugador, mismo partido)
--================================================================================
PRINT '10.2. Forzar Doble Amarilla (Mismo jugador, mismo partido)'

-- Toma un jugador titular de un partido
SELECT TOP 1 
    @jugador_doble = ft.id_jugador, @partido_exp = pf.id_partido
FROM torneo.PartidoFormacion pf
JOIN torneo.FormacionTitular ft ON pf.id_formacion = ft.id_formacion
WHERE pf.id_partido <> @partido_A AND pf.id_partido <> @partido_B;

BEGIN TRY
    EXEC torneo.Tarjeta_Registrar @partido_exp, @jugador_doble, 'AMARILLA', 15, 'Protestar', @nro_sancion OUTPUT, @motivo_susp OUTPUT;
    EXEC torneo.Tarjeta_Registrar @partido_exp, @jugador_doble, 'AMARILLA', 55, 'Falta dura', @nro_sancion OUTPUT, @motivo_susp OUTPUT;
    PRINT 'Ok - Expulsión por doble amarilla registrada.';
END TRY
BEGIN CATCH END CATCH;
GO


-- ===========================================================
-- Importacion Info clubes
-- ===========================================================


PRINT '11. Importacion Info Clubes'
GO

CREATE OR ALTER PROCEDURE importacion.Clubes_Importar
    @ruta VARCHAR(260)
AS 
BEGIN

    SET NOCOUNT ON; 

    BEGIN TRY 
        
        -- Tabla temporal para recibir los datos del CSV
        CREATE TABLE #TempClubesJugadores
        (
            nombre_jugador NVARCHAR(100) COLLATE DATABASE_DEFAULT,
            nombre_club NVARCHAR (100) COLLATE DATABASE_DEFAULT
        );

        DECLARE @sql NVARCHAR(MAX);
        SET @sql = '
        BULK INSERT #TempClubesJugadores
        FROM ''' + @ruta + ''' 
        WITH (
            FORMAT = ''CSV'',
            FIRSTROW = 2, 
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'' -- Soporte para UTF-8 (tildes, ñ) 
        );'; 

        EXEC sp_executesql @sql; 

        BEGIN TRANSACTION; 

        -- Inserta los clubes de los jugadores de el mundial en la tabla clubes
        INSERT INTO personas.Club (nombre)
        SELECT DISTINCT LTRIM(RTRIM(t.nombre_club)) -- Evita duplicados en temp
        FROM #TempClubesJugadores t
        WHERE t.nombre_club IS NOT NULL -- Descarta jugadores sin club
            AND t.nombre_club <> ''     -- Descarta clubes con cadena vacia
            AND NOT EXISTS (
                SELECT 1 
                FROM personas.Club c
                WHERE c.nombre = LTRIM(RTRIM(t.nombre_club)) -- Evita duplicados en tabla
        );

        -- Actualiza la tabla jugadores asignandoles su respectivo club
        UPDATE j
        SET j.id_club = c.id_club
        FROM personas.Jugador j
        JOIN personas.Participante p ON p.id_participante = j.id_participante
        JOIN #TempClubesJugadores t ON p.nombre = t.nombre_jugador -- Deben tener exactamente el mismo nombre
        JOIN personas.Club c ON c.nombre = LTRIM(RTRIM(t.nombre_club)) -- Une a cada jugador con su club

        COMMIT TRANSACTION; 

        PRINT 'Ok - Importacion de Clubes y actualizacion de jugadores.'
        DROP TABLE #TempClubesJugadores; 

    END TRY 
    
    BEGIN CATCH 
        
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error en Importacion' + ERROR_MESSAGE(); 
        THROW; 

    END CATCH;

END;
GO

DECLARE @ruta VARCHAR(260);
DECLARE @repo VARCHAR(200) = 'C:\Users\golde\Documents\Universidad\BDA_TP\TP_DDBBA_Grupo07_2900\TP_DDBBA_Grupo07_2900';   -- << AJUSTAR: único dato a cambiar, la carpeta donde está el repo (con o sin barra final)
DECLARE @carpeta VARCHAR(260) = CASE WHEN RIGHT(@repo, 1) = '\' THEN @repo ELSE @repo + '\' END + 'importacion\';   -- worldcup.json y goals.csv
 
SET @ruta = @carpeta + 'clubes_jugadores.csv'
EXEC importacion.Clubes_Importar @ruta = @ruta;
GO


/*
--Verificacion: 

SELECT p.nombre, c.nombre
FROM personas.Participante p 
JOIN personas.Jugador j ON p.id_participante = j.id_participante
JOIN personas.Club c ON j.id_club = c.id_club
*/


-- ===========================================================
-- 12. Importacion Husos Horarios
-- ===========================================================

PRINT '12. Importacion Husos Horarios'
GO

CREATE OR ALTER PROCEDURE importacion.HusoHorario_Importar
    @ruta VARCHAR(260)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        CREATE TABLE #TempHusos (
            nombre_pais NVARCHAR(80),
            huso_horario DECIMAL(4,2)
        );

        -- Ruta dinámica
        DECLARE @sql NVARCHAR(MAX);
        SET @sql = '
        BULK INSERT #TempHusos
        FROM ''' + @ruta + '''
        WITH (
            FORMAT = ''CSV'',
            FIRSTROW = 2, 
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001''
        );';

        EXEC sp_executesql @sql;

        BEGIN TRANSACTION;

        -- Actualizar Paises
        UPDATE p
        SET p.huso_horario = t.huso_horario
        FROM geo.Pais p
        JOIN #TempHusos t 
            ON p.nombre COLLATE SQL_Latin1_General_CP1_CI_AI
            = t.nombre_pais COLLATE SQL_Latin1_General_CP1_CI_AI
        WHERE p.huso_horario IS NULL OR p.huso_horario <> t.huso_horario;

        -- Insertar paises nuevos 
        INSERT INTO geo.Pais (nombre, huso_horario)
        SELECT DISTINCT t.nombre_pais, t.huso_horario
        FROM #TempHusos t
        WHERE t.nombre_pais IS NOT NULL 
          AND t.nombre_pais <> ''
          AND NOT EXISTS (SELECT 1 
                            FROM geo.Pais p 
                            WHERE p.nombre  COLLATE SQL_Latin1_General_CP1_CI_AI = 
                                  t.nombre_pais COLLATE SQL_Latin1_General_CP1_CI_AI);

        COMMIT TRANSACTION;

        PRINT 'Ok - Husos horarios actualizados e importados con éxito.';
        DROP TABLE #TempHusos;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        PRINT 'Error en importación de Husos Horarios: ' + ERROR_MESSAGE();
        THROW; 
    END CATCH;
END;
GO

DECLARE @ruta VARCHAR(260);
DECLARE @repo VARCHAR(200) = 'C:\Users\golde\Documents\Universidad\BDA_TP\TP_DDBBA_Grupo07_2900\TP_DDBBA_Grupo07_2900';   -- << AJUSTAR: único dato a cambiar, la carpeta donde está el repo (con o sin barra final)
DECLARE @carpeta VARCHAR(260) = CASE WHEN RIGHT(@repo, 1) = '\' THEN @repo ELSE @repo + '\' END + 'importacion\';   -- worldcup.json y goals.csv
 

SET @ruta = @carpeta + 'huso_horario.csv'
EXEC importacion.HusoHorario_Importar @ruta = @ruta;
GO

