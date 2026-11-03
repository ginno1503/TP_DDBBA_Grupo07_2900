/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : IMPORTACIÓN POR SCRAPING de dos datasets que no están en los archivos del Mundial. Los dos
                  usan las mismas piezas del script 14:

                  TÉCNICA (web scraping de tablas HTML con T-SQL, sin librerías)
                    1. Pedido HTTP GET con importacion.Http_Obtener (objeto COM MSXML2.ServerXMLHTTP.6.0), que
                       se identifica con un User-Agent propio.
                    2. Ubicar el dato dentro del HTML con CHARINDEX: una tabla <table> (Wikipedia) o el JSON
                       incrustado en <script id="__NEXT_DATA__"> (FIFA).
                    3. Tabla: recorrer las filas <tr> con CHARINDEX/SUBSTRING y sacar el texto de cada celda con
                       importacion.fn_CeldaHtml / fn_QuitarHtml. JSON: leerlo con OPENJSON.
                    4. Guardar el resultado en un área de paso (tabla importacion.*Carga).
                    5. Procesar el área de paso registro por registro (UPSERT con los SP de la Entrega 5).
                  Si la página cambia y el dato no se encuentra, falla todo con THROW (queda FALLIDA).

                  DATASET 1 - ÁRBITROS INTERNACIONALES DE LA FIFA
                    Página : https://inside.fifa.com/es/refereeing/international-referees
                    SP     : importacion.Arbitro_ImportarWeb [@url] [@codigo_rol]
                    Técnica: la página de la FIFA está hecha con Next.js: no trae una tabla <table> sino que el
                             servidor incrusta toda la lista como JSON dentro del HTML, en la etiqueta
                             <script id="__NEXT_DATA__" type="application/json">. Se ubica esa etiqueta con
                             CHARINDEX, se extrae el JSON y se lo lee con ISJSON/OPENJSON (no hace falta ejecutar
                             JavaScript). La lista está en $.props.pageProps.pageData.content[0].results y cada
                             elemento trae: name ("APELLIDO Nombre"), country.name (en español), country.flag
                             (URL de la bandera que termina en el código FIFA del país, p. ej. .../FRA),
                             role.code, confederation, gender, internationalSince.
                    Roles  : la lista incluye árbitros (1), asistentes (2), asistentes de video (16), futsal (12) y
                             beach soccer (8). Por defecto se importan los árbitros de fútbol (@codigo_rol = 1).
                    Destino: personas.Participante + personas.Arbitro (categoría FIFA) vía Arbitro_Insertar /
                             Arbitro_Modificar. Clave natural: nombre tal como lo publica la FIFA. La página no
                             trae DNI: se genera un código interno REF000001, REF000002... El país se traduce por
                             su código FIFA con fn_PaisLocal; si no está en EquivalenciaPais se usa el nombre en
                             español que publica la FIFA (y se crea el país si falta).

                  DATASET 2 - PODER ADQUISITIVO (PBI per cápita según paridad de poder adquisitivo)
                    Página : https://en.wikipedia.org/wiki/List_of_countries_by_GDP_(PPP)_per_capita
                    SP     : importacion.Pbi_ImportarWeb
                    Tabla  : la primera wikitable con las columnas Country, IMF y World Bank. Las columnas se
                             buscan por el texto del encabezado (no por su posición). Se toma el valor del Banco
                             Mundial y, si falta, el del FMI. Los valores son dólares internacionales.
                    Destino: geo.Pais.pbi_per_capita vía geo.Pais_Modificar. Se recorren los países del
                             sistema (no los de la página): el que no figura o no tiene valor es un ERROR.

                  LÍMITES Y BUENAS PRÁCTICAS: un solo pedido por importación a cada sitio (la página de la FIFA
                  pesa ~1,1 MB; no se la debe pedir en bucle). Wikimedia pide identificarse con un User-Agent y
                  no abusar del servicio. Wikipedia es de uso libre (CC BY-SA, se cita como fuente); los datos de
                  árbitros son información pública publicada por la FIFA y se citan como tal. La estructura de
                  ambas páginas puede cambiar sin aviso: por eso se controla y se informa con THROW. Si la FIFA
                  bloqueara los pedidos automáticos, la importación falla (queda FALLIDA) y no se carga nada.
                  Requisitos: scripts 00 a 14 ejecutados, 'Ole Automation Procedures' activado (script 10) y
                  salida a Internet desde el servidor.
   ============================================================================= */

USE MundialFutbol;
GO

-- ------------------------------------------------------------------ 1. ÁRBITROS
-- Recibe el HTML de la FIFA y deja en ArbitroCarga una fila por persona del rol pedido (nombre, país y código FIFA)
CREATE OR ALTER PROCEDURE importacion.Arbitro_CargarWeb
    @html VARCHAR(MAX),
    @codigo_rol INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ini INT, @fin INT, @json NVARCHAR(MAX);

    -- 1. ubicar el JSON incrustado por Next.js: <script id="__NEXT_DATA__" ...>{...}</script>
    SET @ini = CHARINDEX('id="__NEXT_DATA__"', @html);
    IF @ini = 0
        THROW 50001, 'No se encontró el bloque __NEXT_DATA__ en la página de la FIFA (cambió el formato o la FIFA bloqueó el pedido). ', 1;
    SET @ini = CHARINDEX('>', @html, @ini) + 1;
    SET @fin = CHARINDEX('</script>', @html, @ini);
    IF @fin = 0
        THROW 50001, 'El bloque __NEXT_DATA__ está incompleto en el HTML recibido. ', 1;
    SET @json = SUBSTRING(@html, @ini, @fin - @ini);

    IF ISJSON(@json) = 0
        THROW 50001, 'El bloque __NEXT_DATA__ de la FIFA no es un JSON válido. ', 1;

    -- 2. leer la lista de árbitros: el código FIFA del país es lo último de la URL de la bandera
    INSERT INTO importacion.ArbitroCarga (nombre, pais, codigo_pais)
    SELECT LTRIM(RTRIM(nombre)), LTRIM(RTRIM(pais)), RIGHT(bandera, CHARINDEX('/', REVERSE(bandera) + '/') - 1)
    FROM OPENJSON(@json, '$.props.pageProps.pageData.content[0].results')
         WITH (nombre NVARCHAR(100) '$.name',
               pais NVARCHAR(100) '$.country.name',
               bandera NVARCHAR(300) '$.country.flag',
               rol INT '$.role.code')
    WHERE rol = @codigo_rol;

    IF NOT EXISTS (SELECT 1 FROM importacion.ArbitroCarga)
        THROW 50001, 'La lista de la FIFA no trae árbitros del rol pedido (cambió el formato de la página). ', 1;
END;
GO

CREATE OR ALTER PROCEDURE importacion.Arbitro_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id INT, @nombre VARCHAR(100), @pais_txt VARCHAR(100), @codigo VARCHAR(10), @pais VARCHAR(80), @id_pais INT;
    DECLARE @id_arbitro INT, @pais_actual INT, @fecha_nacimiento DATE, @dni VARCHAR(20);
    DECLARE @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    SELECT @id = MIN(id) FROM importacion.ArbitroCarga;
    WHILE @id IS NOT NULL
    BEGIN
        SELECT @nombre = NULLIF(LTRIM(RTRIM(nombre)), ''), @pais_txt = NULLIF(LTRIM(RTRIM(pais)), ''),
               @codigo = NULLIF(LTRIM(RTRIM(codigo_pais)), '')
        FROM importacion.ArbitroCarga WHERE id = @id;

        SET @clave = 'ARBITRO ' + ISNULL(@nombre, '(sin nombre)') + ' (' + ISNULL(@pais_txt, ISNULL(@codigo, 'sin país')) + ')';
        SET @errores = '';
        SET @estado = NULL;
        SET @id_arbitro = NULL;

        IF @nombre IS NULL
            SET @errores += 'Falta el nombre del árbitro. ';
        IF @pais_txt IS NULL AND @codigo IS NULL
            SET @errores += 'Falta el país. ';

        IF @errores = ''
        BEGIN
            BEGIN TRY
                BEGIN TRANSACTION;

                -- primero por código FIFA (EquivalenciaPais); si no lo conoce, el nombre en español que publica la FIFA
                SET @pais = importacion.fn_PaisLocal(@codigo);
                IF @pais IS NULL OR @pais = @codigo
                    SET @pais = ISNULL(@pais_txt, @codigo);
                SET @id_pais = (SELECT id_pais FROM geo.Pais WHERE nombre = @pais);
                IF @id_pais IS NULL
                    EXEC geo.Pais_Insertar @nombre = @pais, @id_pais = @id_pais OUTPUT;

                SELECT @id_arbitro = p.id_participante, @pais_actual = a.id_pais, @dni = p.dni,
                       @fecha_nacimiento = p.fecha_nacimiento
                FROM personas.Participante p
                JOIN personas.Arbitro a ON a.id_participante = p.id_participante
                WHERE p.nombre = @nombre;

                IF @id_arbitro IS NULL
                BEGIN
                    SET @dni = 'REF' + RIGHT('000000' + CAST(ISNULL((SELECT MAX(TRY_CAST(SUBSTRING(dni, 4, 10) AS INT))
                                                                     FROM personas.Participante WHERE dni LIKE 'REF%'), 0) + 1 AS VARCHAR(10)), 6);
                    EXEC personas.Arbitro_Insertar @dni = @dni, @nombre = @nombre, @id_pais = @id_pais,
                                                   @categoria = 'FIFA', @id_participante = @id_arbitro OUTPUT;
                    SET @estado = 'NUEVO';
                END
                ELSE IF @pais_actual <> @id_pais
                BEGIN
                    EXEC personas.Arbitro_Modificar @id_participante = @id_arbitro, @dni = @dni, @nombre = @nombre,
                                                    @fecha_nacimiento = @fecha_nacimiento, @id_pais = @id_pais,
                                                    @categoria = 'FIFA';
                    SET @estado = 'ACTUALIZADO';
                END
                ELSE
                    SET @estado = 'SIN_CAMBIOS';

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id = MIN(id) FROM importacion.ArbitroCarga WHERE id > @id;
    END;
END;
GO

-- Importa por scraping los árbitros internacionales de la FIFA. @url y @codigo_rol tienen valor por defecto.
CREATE OR ALTER PROCEDURE importacion.Arbitro_ImportarWeb
    @url VARCHAR(1000) = 'https://inside.fifa.com/es/refereeing/international-referees',
    @codigo_rol INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_importacion INT, @html VARCHAR(MAX);

    EXEC importacion.Importacion_Iniciar @archivo = @url, @formato = 'SCRAPING', @id_importacion = @id_importacion OUTPUT;
    BEGIN TRY
        DELETE FROM importacion.ArbitroCarga;
        EXEC importacion.Http_Obtener @url = @url, @respuesta = @html OUTPUT;
        EXEC importacion.Arbitro_CargarWeb @html = @html, @codigo_rol = @codigo_rol;
        EXEC importacion.Arbitro_Procesar @id_importacion = @id_importacion;
        EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    END TRY
    BEGIN CATCH
        EXEC importacion.Importacion_Fallar @id_importacion = @id_importacion;
        THROW;
    END CATCH;

    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
END;
GO

-- ------------------------------------------------------------------ 2. PODER ADQUISITIVO (PBI per cápita PPA)
-- Recibe el HTML y deja en PbiCarga una fila por país con el valor como texto sin separador de miles
CREATE OR ALTER PROCEDURE importacion.Pbi_CargarWeb
    @html VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @pos INT = 1, @fin_tabla INT, @tabla VARCHAR(MAX), @encontrada BIT = 0;
    DECLARE @ini_fila INT, @fin_fila INT, @fin_etiqueta INT, @fila VARCHAR(MAX);
    DECLARE @c_pais INT, @c_wb INT, @c_imf INT, @n INT, @texto VARCHAR(MAX);
    DECLARE @pais VARCHAR(100), @valor VARCHAR(50), @alternativo VARCHAR(50);

    -- 1. ubicar la tabla con las columnas de País, FMI y Banco Mundial
    WHILE @encontrada = 0
    BEGIN
        SET @pos = CHARINDEX('<table', @html, @pos);
        IF @pos = 0
            THROW 50001, 'No se encontró en la página la tabla de PBI per cápita (cambió el formato de Wikipedia). ', 1;
        SET @fin_tabla = CHARINDEX('</table>', @html, @pos);
        IF @fin_tabla = 0
            THROW 50001, 'La tabla de PBI per cápita está incompleta en el HTML recibido. ', 1;
        SET @tabla = SUBSTRING(@html, @pos, @fin_tabla - @pos);
        IF @tabla LIKE '%IMF%' AND @tabla LIKE '%World Bank%'
            SET @encontrada = 1;
        ELSE
            SET @pos = @fin_tabla;
    END;

    -- 2. recorrer las filas: la primera con "World Bank" es el encabezado y dice en qué celda está cada columna
    SET @ini_fila = CHARINDEX('<tr', @tabla);
    WHILE @ini_fila > 0
    BEGIN
        SET @fin_fila = CHARINDEX('</tr>', @tabla, @ini_fila);
        IF @fin_fila = 0 SET @fin_fila = LEN(@tabla) + 1;
        SET @fin_etiqueta = CHARINDEX('>', @tabla, @ini_fila);
        SET @fila = SUBSTRING(@tabla, @fin_etiqueta + 1, @fin_fila - @fin_etiqueta - 1);

        IF @c_wb IS NULL
        BEGIN
            SET @n = 1;
            SET @texto = importacion.fn_CeldaHtml(@fila, @n);
            WHILE @texto IS NOT NULL
            BEGIN
                IF @texto LIKE 'Country%' SET @c_pais = @n;
                IF @texto LIKE 'IMF%' SET @c_imf = @n;
                IF @texto LIKE 'World Bank%' SET @c_wb = @n;
                SET @n += 1;
                SET @texto = importacion.fn_CeldaHtml(@fila, @n);
            END;

            -- si el encabezado de País está en otra fila (celda combinada), los datos tienen una celda más al inicio
            IF @c_wb IS NOT NULL AND @c_pais IS NULL
            BEGIN
                SET @c_pais = 1;
                SET @c_wb += 1;
                SET @c_imf = ISNULL(@c_imf, 0) + 1;
            END;
        END
        ELSE
        BEGIN
            -- 3. fila de datos: país + valor del Banco Mundial (o del FMI si falta)
            SET @pais = RTRIM(REPLACE(importacion.fn_CeldaHtml(@fila, @c_pais), '*', ''));
            SET @valor = REPLACE(importacion.fn_CeldaHtml(@fila, @c_wb), ',', '');
            IF TRY_CAST(@valor AS DECIMAL(12,2)) IS NULL
            BEGIN
                SET @alternativo = REPLACE(importacion.fn_CeldaHtml(@fila, @c_imf), ',', '');
                SET @valor = CASE WHEN TRY_CAST(@alternativo AS DECIMAL(12,2)) IS NULL THEN NULL ELSE @alternativo END;
            END;

            IF @pais IS NOT NULL AND @pais <> ''
                INSERT INTO importacion.PbiCarga (pais, valor) VALUES (@pais, @valor);
        END;

        SET @ini_fila = CHARINDEX('<tr', @tabla, @fin_fila);
    END;

    IF @c_wb IS NULL
        THROW 50001, 'No se encontró el encabezado World Bank en la tabla (cambió el formato de Wikipedia). ', 1;
    IF NOT EXISTS (SELECT 1 FROM importacion.PbiCarga)
        THROW 50001, 'La tabla de PBI per cápita no trae filas de países. ', 1;
END;
GO

-- Recorre los países del sistema y busca su valor en lo leído de la página
CREATE OR ALTER PROCEDURE importacion.Pbi_Procesar
    @id_importacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_pais INT, @nombre VARCHAR(80), @huso DECIMAL(4,2), @pbi_actual DECIMAL(12,2);
    DECLARE @encontrado BIT, @valor DECIMAL(12,2), @clave VARCHAR(200), @estado VARCHAR(12), @errores VARCHAR(2000);

    SELECT @id_pais = MIN(id_pais) FROM geo.Pais;
    WHILE @id_pais IS NOT NULL
    BEGIN
        SELECT @nombre = nombre, @huso = huso_horario, @pbi_actual = pbi_per_capita FROM geo.Pais WHERE id_pais = @id_pais;

        -- el país de la página puede figurar con el nombre del sistema o con alguno de sus nombres en inglés
        SET @encontrado = CASE WHEN EXISTS (SELECT 1 FROM importacion.PbiCarga
                                            WHERE pais = @nombre OR pais IN (SELECT nombre_ingles FROM importacion.EquivalenciaPais
                                                                              WHERE nombre_pais = @nombre))
                               THEN 1 ELSE 0 END;
        SET @valor = (SELECT TOP 1 TRY_CAST(valor AS DECIMAL(12,2)) FROM importacion.PbiCarga
                      WHERE (pais = @nombre OR pais IN (SELECT nombre_ingles FROM importacion.EquivalenciaPais
                                                        WHERE nombre_pais = @nombre))
                        AND valor IS NOT NULL
                      ORDER BY id);

        SET @clave = 'PBI ' + @nombre;
        SET @errores = '';
        SET @estado = NULL;

        IF @encontrado = 0
            SET @errores += 'El país no figura en la tabla de la página. ';
        ELSE IF @valor IS NULL
            SET @errores += 'La página no informa el PBI per cápita de este país. ';

        IF @errores = ''
        BEGIN
            BEGIN TRY
                IF @pbi_actual = @valor
                    SET @estado = 'SIN_CAMBIOS';
                ELSE
                BEGIN
                    EXEC geo.Pais_Modificar @id_pais = @id_pais, @nombre = @nombre, @huso_horario = @huso,
                                            @pbi_per_capita = @valor;
                    SET @estado = CASE WHEN @pbi_actual IS NULL THEN 'NUEVO' ELSE 'ACTUALIZADO' END;
                END;
            END TRY
            BEGIN CATCH
                SET @errores = ERROR_MESSAGE();
            END CATCH;
        END;

        EXEC importacion.Registro_Agregar @id_importacion = @id_importacion, @clave = @clave,
                                          @estado = @estado, @errores = @errores;

        SELECT @id_pais = MIN(id_pais) FROM geo.Pais WHERE id_pais > @id_pais;
    END;
END;
GO

-- Importa por scraping el PBI per cápita (PPA) de Wikipedia
CREATE OR ALTER PROCEDURE importacion.Pbi_ImportarWeb
    @url VARCHAR(1000) = 'https://en.wikipedia.org/wiki/List_of_countries_by_GDP_(PPP)_per_capita'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_importacion INT, @html VARCHAR(MAX);

    EXEC importacion.Importacion_Iniciar @archivo = @url, @formato = 'SCRAPING', @id_importacion = @id_importacion OUTPUT;
    BEGIN TRY
        DELETE FROM importacion.PbiCarga;
        EXEC importacion.Http_Obtener @url = @url, @respuesta = @html OUTPUT;
        EXEC importacion.Pbi_CargarWeb @html = @html;
        EXEC importacion.Pbi_Procesar @id_importacion = @id_importacion;
        EXEC importacion.Importacion_Cerrar @id_importacion = @id_importacion;
    END TRY
    BEGIN CATCH
        EXEC importacion.Importacion_Fallar @id_importacion = @id_importacion;
        THROW;
    END CATCH;

    EXEC importacion.Resultado_Mostrar @id_importacion = @id_importacion;
END;
GO
