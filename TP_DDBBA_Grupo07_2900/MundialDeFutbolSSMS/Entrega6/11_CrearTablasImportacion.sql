/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Crear las tablas del esquema importacion (el esquema lo crea 00_CrearBaseDeDatosYEsquemas.sql).

                  Bitácora (no se vacían nunca):
                    importacion.Importacion  una fila por importación, con el resultado y los totales
                    importacion.Registro     una fila por registro procesado (clave, estado y motivo)

                  Áreas de paso (se vacían al comenzar cada importación):
                    importacion.JsonCarga    recibe el archivo worldcup.json completo (una sola fila)
                    importacion.GolCarga     recibe goals.csv; mismas 27 columnas y mismo orden que el archivo,
                                             porque BULK INSERT las mapea por posición
                    importacion.ArbitroCarga árbitros leídos de la página web de la FIFA (nombre, país y código FIFA)
                    importacion.PbiCarga     PBI per cápita leído de la página web (país y valor como texto)

                  Las columnas de las áreas de paso son texto: el dato se guarda tal como llegó y la
                  conversión de tipos se hace después, registro por registro, para poder informar cuál
                  falló y por qué sin perder el resto. JsonCarga es NVARCHAR(MAX) porque el JSON trae
                  nombres con caracteres que no existen en la página de códigos de la base.
   ============================================================================= */

USE MundialFutbol;
GO

-- el esquema se crea en el script 00; si la base se creó con una versión anterior, se agrega acá
IF SCHEMA_ID('importacion') IS NULL
    EXEC ('CREATE SCHEMA importacion');
GO

DROP TABLE IF EXISTS importacion.PbiCarga;
DROP TABLE IF EXISTS importacion.ArbitroCarga;
DROP TABLE IF EXISTS importacion.GolCarga;
DROP TABLE IF EXISTS importacion.JsonCarga;
DROP TABLE IF EXISTS importacion.Registro;
DROP TABLE IF EXISTS importacion.Importacion;
GO

CREATE TABLE importacion.Importacion (
    id_importacion INT IDENTITY(1,1) NOT NULL,
    archivo VARCHAR(500) NOT NULL,   -- ruta del archivo o URL consultada
    formato VARCHAR(10) NOT NULL,     -- CSV, JSON, API o SCRAPING
    fecha_inicio DATETIME2(0) NOT NULL CONSTRAINT DF_Importacion_fecha_inicio DEFAULT (SYSDATETIME()),
    fecha_fin DATETIME2(0) NULL,
    estado VARCHAR(12) NOT NULL CONSTRAINT DF_Importacion_estado DEFAULT ('EN_CURSO'),
    filas_leidas INT NOT NULL CONSTRAINT DF_Importacion_filas_leidas DEFAULT (0),
    filas_nuevas INT NOT NULL CONSTRAINT DF_Importacion_filas_nuevas DEFAULT (0),
    filas_actualizadas INT NOT NULL CONSTRAINT DF_Importacion_filas_actualizadas DEFAULT (0),
    filas_sin_cambios INT NOT NULL CONSTRAINT DF_Importacion_filas_sin_cambios DEFAULT (0),
    filas_error INT NOT NULL CONSTRAINT DF_Importacion_filas_error DEFAULT (0),
    mensaje VARCHAR(500) NULL,   -- motivo cuando la importación completa no se pudo hacer
    CONSTRAINT PK_Importacion PRIMARY KEY (id_importacion),
    CONSTRAINT CK_Importacion_formato CHECK (formato IN ('CSV', 'JSON', 'API', 'SCRAPING')),
    CONSTRAINT CK_Importacion_estado CHECK (estado IN ('EN_CURSO', 'OK', 'CON_ERRORES', 'FALLIDA'))
);
GO

CREATE TABLE importacion.Registro (
    id_registro INT IDENTITY(1,1) NOT NULL,
    id_importacion INT NOT NULL,
    clave VARCHAR(200) NOT NULL,       -- identifica el registro (ej: 'PARTIDO M-2022-64', 'USD/EUR 2026-11-03')
    estado VARCHAR(12) NOT NULL,
    mensaje VARCHAR(2000) NULL,        -- motivo cuando terminó en ERROR
    CONSTRAINT PK_Registro PRIMARY KEY (id_registro),
    CONSTRAINT FK_Registro_id_importacion FOREIGN KEY (id_importacion) REFERENCES importacion.Importacion (id_importacion),
    CONSTRAINT CK_Registro_estado CHECK (estado IN ('NUEVO', 'ACTUALIZADO', 'SIN_CAMBIOS', 'ERROR'))
);
GO

CREATE TABLE importacion.JsonCarga (
    contenido NVARCHAR(MAX) NULL
);
GO

-- Mismo orden de columnas que goals.csv: BULK INSERT las mapea por posición.
CREATE TABLE importacion.GolCarga (
    key_id VARCHAR(100) NULL,
    goal_id VARCHAR(100) NULL,
    tournament_id VARCHAR(100) NULL,
    tournament_name VARCHAR(100) NULL,
    match_id VARCHAR(100) NULL,
    match_name VARCHAR(100) NULL,
    match_date VARCHAR(100) NULL,
    stage_name VARCHAR(100) NULL,
    group_name VARCHAR(100) NULL,
    team_id VARCHAR(100) NULL,
    team_name VARCHAR(100) NULL,
    team_code VARCHAR(100) NULL,
    home_team VARCHAR(100) NULL,
    away_team VARCHAR(100) NULL,
    player_id VARCHAR(100) NULL,
    family_name VARCHAR(100) NULL,
    given_name VARCHAR(100) NULL,
    shirt_number VARCHAR(100) NULL,
    player_team_id VARCHAR(100) NULL,
    player_team_name VARCHAR(100) NULL,
    player_team_code VARCHAR(100) NULL,
    minute_label VARCHAR(100) NULL,
    minute_regulation VARCHAR(100) NULL,
    minute_stoppage VARCHAR(100) NULL,
    match_period VARCHAR(100) NULL,
    own_goal VARCHAR(100) NULL,
    penalty VARCHAR(100) NULL
);
GO

CREATE TABLE importacion.ArbitroCarga (
    id INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(100) NULL,
    pais VARCHAR(100) NULL,
    codigo_pais VARCHAR(10) NULL,
    CONSTRAINT PK_ArbitroCarga PRIMARY KEY (id)
);
GO

CREATE TABLE importacion.PbiCarga (
    id INT IDENTITY(1,1) NOT NULL,
    pais VARCHAR(100) NULL,
    valor VARCHAR(50) NULL,
    CONSTRAINT PK_PbiCarga PRIMARY KEY (id)
);
GO
