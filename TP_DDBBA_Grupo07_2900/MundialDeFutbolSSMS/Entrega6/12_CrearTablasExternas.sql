/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Crear las tablas que necesitan los datasets externos de la Entrega 6:

                    importacion.EquivalenciaPais  traduce cada país de las fuentes externas al país del
                                                  sistema. Cada fuente usa su propio identificador:
                                                    * worldcup.json / goals.csv  nombre en inglés y código FIFA
                                                    * Wikipedia (scraping)       nombre en inglés
                                                    * Nager.Date (API)           código ISO2 (AR, BR...)
                                                  Las filas sin ISO/FIFA son alias históricos (West Germany,
                                                  Soviet Union...) que se asignan al país actual.
                                                  huso_horario: huso de los países anfitriones de un Mundial
                                                  (el JSON no trae husos y geo.Ciudad lo exige). Los países de
                                                  varios husos (EE.UU., México, Canadá, Rusia, Brasil) llevan
                                                  el del huso principal.
                    publicidad.TipoCambio         cotizaciones diarias (API Frankfurter), con historial
                    publicidad.Feriado            feriados por país y fecha (API Nager.Date)

                  Si una fuente trae un país que no está en EquivalenciaPais, ese registro se informa como
                  error y el resto se importa: agregar una fila acá lo resuelve.
   ============================================================================= */

USE MundialFutbol;
GO

DROP TABLE IF EXISTS publicidad.Feriado;
DROP TABLE IF EXISTS publicidad.TipoCambio;
DROP TABLE IF EXISTS importacion.EquivalenciaPais;
GO

CREATE TABLE importacion.EquivalenciaPais (
    id_equivalencia INT IDENTITY(1,1) NOT NULL,
    codigo_iso2 CHAR(2) NULL,
    codigo_iso3 CHAR(3) NULL,
    codigo_fifa VARCHAR(3) NULL,
    nombre_ingles VARCHAR(80) NOT NULL,
    nombre_pais VARCHAR(80) NOT NULL,     -- nombre en geo.Pais (se crea si todavía no existe)
    huso_horario DECIMAL(4,2) NULL,       -- huso del país (solo los países anfitriones; el JSON no lo trae)
    CONSTRAINT PK_EquivalenciaPais PRIMARY KEY (id_equivalencia),
    CONSTRAINT UQ_EquivalenciaPais_nombre_ingles UNIQUE (nombre_ingles)
);
GO

CREATE TABLE publicidad.TipoCambio (
    id_tipo_cambio INT IDENTITY(1,1) NOT NULL,
    moneda_base CHAR(3) NOT NULL,         -- se cotiza 1 unidad de la moneda base (USD)
    moneda CHAR(3) NOT NULL,
    fecha DATE NOT NULL,
    cotizacion DECIMAL(18,6) NOT NULL,
    CONSTRAINT PK_TipoCambio PRIMARY KEY (id_tipo_cambio),
    CONSTRAINT UQ_TipoCambio_base_moneda_fecha UNIQUE (moneda_base, moneda, fecha),
    CONSTRAINT CK_TipoCambio_cotizacion CHECK (cotizacion > 0)
);
GO

CREATE TABLE publicidad.Feriado (
    id_feriado INT IDENTITY(1,1) NOT NULL,
    id_pais INT NOT NULL,
    fecha DATE NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    CONSTRAINT PK_Feriado PRIMARY KEY (id_feriado),
    CONSTRAINT FK_Feriado_id_pais FOREIGN KEY (id_pais) REFERENCES geo.Pais (id_pais),
    CONSTRAINT UQ_Feriado_pais_fecha UNIQUE (id_pais, fecha)
);
GO

INSERT INTO importacion.EquivalenciaPais (codigo_iso2, codigo_iso3, codigo_fifa, nombre_ingles, nombre_pais) VALUES
    ('AR', 'ARG', 'ARG', 'Argentina', 'Argentina'),
    ('BR', 'BRA', 'BRA', 'Brazil', 'Brasil'),
    ('UY', 'URY', 'URU', 'Uruguay', 'Uruguay'),
    ('CL', 'CHL', 'CHI', 'Chile', 'Chile'),
    ('CO', 'COL', 'COL', 'Colombia', 'Colombia'),
    ('PE', 'PER', 'PER', 'Peru', 'Peru'),
    ('PY', 'PRY', 'PAR', 'Paraguay', 'Paraguay'),
    ('EC', 'ECU', 'ECU', 'Ecuador', 'Ecuador'),
    ('BO', 'BOL', 'BOL', 'Bolivia', 'Bolivia'),
    ('VE', 'VEN', 'VEN', 'Venezuela', 'Venezuela'),
    ('MX', 'MEX', 'MEX', 'Mexico', 'Mexico'),
    ('US', 'USA', 'USA', 'United States', 'Estados Unidos'),
    ('CA', 'CAN', 'CAN', 'Canada', 'Canada'),
    ('CR', 'CRI', 'CRC', 'Costa Rica', 'Costa Rica'),
    ('PA', 'PAN', 'PAN', 'Panama', 'Panama'),
    ('HN', 'HND', 'HON', 'Honduras', 'Honduras'),
    ('SV', 'SLV', 'SLV', 'El Salvador', 'El Salvador'),
    ('GT', 'GTM', 'GUA', 'Guatemala', 'Guatemala'),
    ('JM', 'JAM', 'JAM', 'Jamaica', 'Jamaica'),
    ('TT', 'TTO', 'TRI', 'Trinidad and Tobago', 'Trinidad y Tobago'),
    ('CU', 'CUB', 'CUB', 'Cuba', 'Cuba'),
    ('ES', 'ESP', 'ESP', 'Spain', 'Espana'),
    ('PT', 'PRT', 'POR', 'Portugal', 'Portugal'),
    ('FR', 'FRA', 'FRA', 'France', 'Francia'),
    ('DE', 'DEU', 'GER', 'Germany', 'Alemania'),
    ('IT', 'ITA', 'ITA', 'Italy', 'Italia'),
    ('GB', 'GBR', 'ENG', 'England', 'Inglaterra'),
    ('NL', 'NLD', 'NED', 'Netherlands', 'Paises Bajos'),
    ('BE', 'BEL', 'BEL', 'Belgium', 'Belgica'),
    ('CH', 'CHE', 'SUI', 'Switzerland', 'Suiza'),
    ('AT', 'AUT', 'AUT', 'Austria', 'Austria'),
    ('SE', 'SWE', 'SWE', 'Sweden', 'Suecia'),
    ('NO', 'NOR', 'NOR', 'Norway', 'Noruega'),
    ('DK', 'DNK', 'DEN', 'Denmark', 'Dinamarca'),
    ('FI', 'FIN', 'FIN', 'Finland', 'Finlandia'),
    ('PL', 'POL', 'POL', 'Poland', 'Polonia'),
    ('CZ', 'CZE', 'CZE', 'Czech Republic', 'Chequia'),
    ('HR', 'HRV', 'CRO', 'Croatia', 'Croacia'),
    ('RS', 'SRB', 'SRB', 'Serbia', 'Serbia'),
    ('RU', 'RUS', 'RUS', 'Russia', 'Rusia'),
    ('UA', 'UKR', 'UKR', 'Ukraine', 'Ucrania'),
    ('TR', 'TUR', 'TUR', 'Turkey', 'Turquia'),
    ('GR', 'GRC', 'GRE', 'Greece', 'Grecia'),
    ('HU', 'HUN', 'HUN', 'Hungary', 'Hungria'),
    ('RO', 'ROU', 'ROU', 'Romania', 'Rumania'),
    ('BG', 'BGR', 'BUL', 'Bulgaria', 'Bulgaria'),
    ('IE', 'IRL', 'IRL', 'Republic of Ireland', 'Irlanda'),
    ('SK', 'SVK', 'SVK', 'Slovakia', 'Eslovaquia'),
    ('SI', 'SVN', 'SVN', 'Slovenia', 'Eslovenia'),
    ('IS', 'ISL', 'ISL', 'Iceland', 'Islandia'),
    ('EG', 'EGY', 'EGY', 'Egypt', 'Egipto'),
    ('MA', 'MAR', 'MAR', 'Morocco', 'Marruecos'),
    ('TN', 'TUN', 'TUN', 'Tunisia', 'Tunez'),
    ('DZ', 'DZA', 'ALG', 'Algeria', 'Argelia'),
    ('SN', 'SEN', 'SEN', 'Senegal', 'Senegal'),
    ('NG', 'NGA', 'NGA', 'Nigeria', 'Nigeria'),
    ('GH', 'GHA', 'GHA', 'Ghana', 'Ghana'),
    ('CM', 'CMR', 'CMR', 'Cameroon', 'Camerun'),
    ('CI', 'CIV', 'CIV', 'Ivory Coast', 'Costa de Marfil'),
    ('ZA', 'ZAF', 'RSA', 'South Africa', 'Sudafrica'),
    ('GA', 'GAB', 'GAB', 'Gabon', 'Gabon'),
    ('BJ', 'BEN', 'BEN', 'Benin', 'Benin'),
    ('MU', 'MUS', 'MRI', 'Mauritius', 'Mauricio'),
    ('ML', 'MLI', 'MLI', 'Mali', 'Mali'),
    ('JP', 'JPN', 'JPN', 'Japan', 'Japon'),
    ('KR', 'KOR', 'KOR', 'South Korea', 'Corea del Sur'),
    ('CN', 'CHN', 'CHN', 'China', 'China'),
    ('AU', 'AUS', 'AUS', 'Australia', 'Australia'),
    ('NZ', 'NZL', 'NZL', 'New Zealand', 'Nueva Zelanda'),
    ('IR', 'IRN', 'IRN', 'Iran', 'Iran'),
    ('SA', 'SAU', 'KSA', 'Saudi Arabia', 'Arabia Saudita'),
    ('QA', 'QAT', 'QAT', 'Qatar', 'Catar'),
    ('AE', 'ARE', 'UAE', 'United Arab Emirates', 'Emiratos Arabes Unidos'),
    ('UZ', 'UZB', 'UZB', 'Uzbekistan', 'Uzbekistan'),
    ('JO', 'JOR', 'JOR', 'Jordan', 'Jordania'),
    ('SG', 'SGP', 'SIN', 'Singapore', 'Singapur'),
    ('OM', 'OMN', 'OMA', 'Oman', 'Oman'),
    ('BH', 'BHR', 'BHR', 'Bahrain', 'Barein'),
    ('IL', 'ISR', 'ISR', 'Israel', 'Israel'),
    (NULL, NULL, 'FRG', 'West Germany', 'Alemania'),
    (NULL, NULL, 'GDR', 'East Germany', 'Alemania'),
    (NULL, NULL, 'URS', 'Soviet Union', 'Rusia'),
    (NULL, NULL, 'TCH', 'Czechoslovakia', 'Chequia'),
    (NULL, NULL, 'YUG', 'Yugoslavia', 'Serbia'),
    (NULL, NULL, 'SCO', 'Scotland', 'Escocia'),
    (NULL, NULL, 'WAL', 'Wales', 'Gales'),
    (NULL, NULL, 'NIR', 'Northern Ireland', 'Irlanda del Norte'),
    (NULL, NULL, NULL, 'Czechia', 'Chequia'),
    (NULL, NULL, NULL, 'Turkiye', 'Turquia'),
    (NULL, NULL, NULL, 'Korea Republic', 'Corea del Sur'),
    (NULL, NULL, NULL, 'United States of America', 'Estados Unidos'),
    (NULL, NULL, NULL, 'Ireland', 'Irlanda'),
    (NULL, NULL, NULL, 'United Kingdom', 'Inglaterra'),
    (NULL, NULL, NULL, 'Türkiye', 'Turquia'),
    ('AO', 'AGO', 'ANG', 'Angola', 'Angola'),
    ('BA', 'BIH', 'BIH', 'Bosnia and Herzegovina', 'Bosnia y Herzegovina'),
    ('TW', 'TWN', 'TPE', 'Chinese Taipei', 'Taipei Chino'),
    ('GQ', 'GNQ', 'EQG', 'Equatorial Guinea', 'Guinea Ecuatorial'),
    ('HT', 'HTI', 'HAI', 'Haiti', 'Haiti'),
    ('IQ', 'IRQ', 'IRQ', 'Iraq', 'Irak'),
    ('KW', 'KWT', 'KUW', 'Kuwait', 'Kuwait'),
    ('KP', 'PRK', 'PRK', 'North Korea', 'Corea del Norte'),
    ('TH', 'THA', 'THA', 'Thailand', 'Tailandia'),
    ('TG', 'TGO', 'TOG', 'Togo', 'Togo'),
    ('CD', 'COD', 'COD', 'Zaire', 'Congo'),
    (NULL, NULL, NULL, 'Serbia and Montenegro', 'Serbia'),
    (NULL, NULL, NULL, 'Dutch East Indies', 'Indonesia'),
    ('RW', 'RWA', 'RWA', 'Rwanda', 'Ruanda'),
    ('ZM', 'ZMB', 'ZAM', 'Zambia', 'Zambia');
GO

-- Husos de los países que fueron sede de un Mundial (los parámetros de Ciudad_Insertar lo exigen)
UPDATE importacion.EquivalenciaPais SET huso_horario = CASE nombre_pais
    WHEN 'Uruguay' THEN -3 WHEN 'Italia' THEN 1 WHEN 'Francia' THEN 1 WHEN 'Brasil' THEN -3
    WHEN 'Suiza' THEN 1 WHEN 'Suecia' THEN 1 WHEN 'Chile' THEN -4 WHEN 'Inglaterra' THEN 0
    WHEN 'Mexico' THEN -6 WHEN 'Alemania' THEN 1 WHEN 'Argentina' THEN -3 WHEN 'Espana' THEN 1
    WHEN 'Estados Unidos' THEN -5 WHEN 'Japon' THEN 9 WHEN 'Corea del Sur' THEN 9
    WHEN 'Sudafrica' THEN 2 WHEN 'Rusia' THEN 3 WHEN 'Catar' THEN 3 WHEN 'Canada' THEN -5
    WHEN 'China' THEN 8 END
WHERE nombre_pais IN ('Uruguay', 'Italia', 'Francia', 'Brasil', 'Suiza', 'Suecia', 'Chile', 'Inglaterra',
                      'Mexico', 'Alemania', 'Argentina', 'Espana', 'Estados Unidos', 'Japon', 'Corea del Sur',
                      'Sudafrica', 'Rusia', 'Catar', 'Canada', 'China');
GO
