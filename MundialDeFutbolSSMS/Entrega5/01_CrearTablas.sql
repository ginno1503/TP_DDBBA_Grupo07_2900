/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  : [Apellido, Nombre] - [Apellido, Nombre] - [Apellido, Nombre] - [Apellido, Nombre]
   Fecha        : 15/10/2026
   Objetivo     : Crear las 30 tablas del modelo con sus claves primarias, foraneas, unicidades y restricciones CHECK segun el DER.
   ============================================================================= */

/* Los comentarios previos a cada tabla indican a que parte del DER corresponde y cada AJUSTE/AGREGADO
   respecto del DER. Reemplazo completo: primero se eliminan las tablas existentes (en orden inverso de
   dependencias) y luego se crean. ATENCION: borra los datos de las tablas. */

USE MundialFutbol;
GO

DROP TABLE IF EXISTS publicidad.EspacioPublicitario;
DROP TABLE IF EXISTS publicidad.Tarifa;
DROP TABLE IF EXISTS publicidad.ContenidoPais;
DROP TABLE IF EXISTS publicidad.Contenido;
DROP TABLE IF EXISTS publicidad.Campania;
DROP TABLE IF EXISTS publicidad.Anunciante;
DROP TABLE IF EXISTS torneo.Parametro;
DROP TABLE IF EXISTS torneo.Suspension;
DROP TABLE IF EXISTS torneo.Expulsion;
DROP TABLE IF EXISTS torneo.Sancion;
DROP TABLE IF EXISTS torneo.Gol;
DROP TABLE IF EXISTS torneo.Sustitucion;
DROP TABLE IF EXISTS torneo.FormacionSuplente;
DROP TABLE IF EXISTS torneo.FormacionTitular;
DROP TABLE IF EXISTS torneo.Formacion;
DROP TABLE IF EXISTS torneo.ArbitroSecundario;
DROP TABLE IF EXISTS torneo.Partido;
DROP TABLE IF EXISTS torneo.Sede;
DROP TABLE IF EXISTS torneo.ReemplazoConvocatoria;
DROP TABLE IF EXISTS personas.Ayudante;
DROP TABLE IF EXISTS personas.DirectorTecnico;
DROP TABLE IF EXISTS personas.ArbitroIdioma;
DROP TABLE IF EXISTS personas.Arbitro;
DROP TABLE IF EXISTS personas.Jugador;
DROP TABLE IF EXISTS personas.Club;
DROP TABLE IF EXISTS personas.Participante;
DROP TABLE IF EXISTS torneo.Seleccion;
DROP TABLE IF EXISTS geo.Ciudad;
DROP TABLE IF EXISTS geo.Pais;
DROP TABLE IF EXISTS geo.Idioma;
GO

-- ===========================================================================
-- ESQUEMA geo
-- ===========================================================================
CREATE TABLE geo.Idioma (
    id_idioma INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_Idioma PRIMARY KEY (id_idioma),
    CONSTRAINT UQ_Idioma_nombre UNIQUE (nombre)
);
GO


CREATE TABLE geo.Pais (
    id_pais INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(80) NOT NULL,
    huso_horario DECIMAL(4,2) NULL,
    pbi_per_capita DECIMAL(12,2) NULL,
    CONSTRAINT PK_Pais PRIMARY KEY (id_pais),
    CONSTRAINT UQ_Pais_nombre UNIQUE (nombre),
    CONSTRAINT CK_Pais_huso_horario CHECK (huso_horario BETWEEN -12 AND 14),
    CONSTRAINT CK_Pais_pbi_per_capita CHECK (pbi_per_capita >= 0)
);
GO

-- DER: Ciudad (id, nombre, huso_horario). 'contiene': Pais 1 - N Ciudad.
CREATE TABLE geo.Ciudad (
    id_ciudad INT IDENTITY(1,1) NOT NULL,
    id_pais INT NOT NULL,
    nombre NVARCHAR(80) NOT NULL,
    huso_horario DECIMAL(4,2) NOT NULL,
    CONSTRAINT PK_Ciudad PRIMARY KEY (id_ciudad),
    CONSTRAINT UQ_Ciudad_id_pais_nombre UNIQUE (id_pais, nombre),
    CONSTRAINT FK_Ciudad_id_pais FOREIGN KEY (id_pais) REFERENCES geo.Pais (id_pais),
    CONSTRAINT CK_Ciudad_huso_horario CHECK (huso_horario BETWEEN -12 AND 14)
);
GO

-- ===========================================================================
-- ESQUEMA torneo
-- ===========================================================================
-- DER: seleccion (id, confederacion, grupo)
-- grupo es NULL hasta el sorteo.
CREATE TABLE torneo.Seleccion (
    id_seleccion INT IDENTITY(1,1) NOT NULL,
    id_pais INT NOT NULL,
    confederacion VARCHAR(10) NOT NULL,
    grupo CHAR(1) NULL,
    CONSTRAINT PK_Seleccion PRIMARY KEY (id_seleccion),
    CONSTRAINT UQ_Seleccion_id_pais UNIQUE (id_pais),--Una sola seleccion por pais
    CONSTRAINT FK_Seleccion_id_pais FOREIGN KEY (id_pais) REFERENCES geo.Pais (id_pais),
    CONSTRAINT CK_Seleccion_confederacion CHECK (confederacion IN ('UEFA','CONMEBOL','CONCACAF','CAF','AFC','OFC')), --todas las confederaciones de la fifa
    CONSTRAINT CK_Seleccion_grupo CHECK (grupo IN ('A','B','C','D','E','F','G','H','I','J','K','L'))
);
GO

-- ===========================================================================
-- ESQUEMA personas
-- ===========================================================================
-- Participantes (id, dni, nombre) = padre de las entidades: Arbitro, Jugador, DT, Ayudante.
-- FK compuesto (id_participante, tipo) para despues chequear que por ejemplo jugador sea de tipo J.
--(garantizamos que un participante no pueda ser de dos tipos al mismo tiempo)
CREATE TABLE personas.Participante (
    id_participante INT IDENTITY(1,1) NOT NULL,
    dni VARCHAR(20) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    fecha_nacimiento DATE NULL,
    tipo CHAR(1) NOT NULL,
    CONSTRAINT PK_Participante PRIMARY KEY (id_participante),
    CONSTRAINT UQ_Participante_dni UNIQUE (dni),
    CONSTRAINT UQ_Participante_id_participante_tipo UNIQUE (id_participante, tipo),
    CONSTRAINT CK_Participante_tipo CHECK (tipo IN ('J','A','D','Y'))
);
GO

-- DER: club (id, nombre). 
CREATE TABLE personas.Club (
    id_club INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_Club PRIMARY KEY (id_club),
    CONSTRAINT UQ_Club_nombre UNIQUE (nombre)
);
GO

-- El dorsal NO es UNIQUE por seleccion a nivel de tabla: un reemplazo de ultima hora puede heredar el dorsal del jugador
-- dado de baja. La unicidad entre convocados activos se valida en los stored procedures.
CREATE TABLE personas.Jugador (
    id_participante INT NOT NULL,
    tipo CHAR(1) NOT NULL CONSTRAINT DF_Jugador_tipo DEFAULT 'J',
    id_seleccion INT NOT NULL,
    id_club INT NOT NULL,
    nro_dorsal TINYINT NOT NULL,
    posicion VARCHAR(15) NOT NULL,
    CONSTRAINT PK_Jugador PRIMARY KEY (id_participante),
    CONSTRAINT FK_Jugador_Participante FOREIGN KEY (id_participante, tipo) REFERENCES personas.Participante (id_participante, tipo),
    CONSTRAINT CK_Jugador_tipo CHECK (tipo = 'J'),
    CONSTRAINT FK_Jugador_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES torneo.Seleccion (id_seleccion),
    CONSTRAINT FK_Jugador_id_club FOREIGN KEY (id_club) REFERENCES personas.Club (id_club),
    CONSTRAINT CK_Jugador_nro_dorsal CHECK (nro_dorsal BETWEEN 1 AND 99),
    CONSTRAINT CK_Jugador_posicion CHECK (posicion IN ('ARQUERO','DEFENSOR','MEDIOCAMPISTA','DELANTERO'))
);
GO

-- DER: Arbitro (categoria) 
CREATE TABLE personas.Arbitro (
    id_participante INT NOT NULL,
    tipo CHAR(1) NOT NULL CONSTRAINT DF_Arbitro_tipo DEFAULT 'A',
    id_pais INT NOT NULL,
    categoria VARCHAR(15) NOT NULL,
    CONSTRAINT PK_Arbitro PRIMARY KEY (id_participante),
    CONSTRAINT FK_Arbitro_Participante FOREIGN KEY (id_participante, tipo) REFERENCES personas.Participante (id_participante, tipo),
    CONSTRAINT CK_Arbitro_tipo CHECK (tipo = 'A'),
    CONSTRAINT FK_Arbitro_id_pais FOREIGN KEY (id_pais) REFERENCES geo.Pais (id_pais),
    CONSTRAINT CK_Arbitro_categoria CHECK (categoria IN ('FIFA','CONFEDERACION'))
);
GO

-- DER: relacion 'habla' Arbitro - Idiomas. se resuelve como N:M.(puede hablar varios idiomas)
CREATE TABLE personas.ArbitroIdioma (
    id_arbitro INT NOT NULL,
    id_idioma INT NOT NULL,
    CONSTRAINT PK_ArbitroIdioma PRIMARY KEY (id_arbitro, id_idioma),
    CONSTRAINT FK_ArbitroIdioma_id_arbitro FOREIGN KEY (id_arbitro) REFERENCES personas.Arbitro (id_participante),
    CONSTRAINT FK_ArbitroIdioma_id_idioma FOREIGN KEY (id_idioma) REFERENCES geo.Idioma (id_idioma)
);
GO

-- cada DT dirige 1 seleccion
CREATE TABLE personas.DirectorTecnico (
    id_participante INT NOT NULL,
    tipo CHAR(1) NOT NULL CONSTRAINT DF_DirectorTecnico_tipo DEFAULT 'D',
    id_seleccion INT NOT NULL,
    CONSTRAINT PK_DirectorTecnico PRIMARY KEY (id_participante),
    CONSTRAINT UQ_DirectorTecnico_id_seleccion UNIQUE (id_seleccion),
    CONSTRAINT FK_DirectorTecnico_Participante FOREIGN KEY (id_participante, tipo) REFERENCES personas.Participante (id_participante, tipo),
    CONSTRAINT CK_DirectorTecnico_tipo CHECK (tipo = 'D'),
    CONSTRAINT FK_DirectorTecnico_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES torneo.Seleccion (id_seleccion)
);
GO

-- Ayudante
CREATE TABLE personas.Ayudante (
    id_participante INT NOT NULL,
    tipo CHAR(1) NOT NULL CONSTRAINT DF_Ayudante_tipo DEFAULT 'Y',
    id_seleccion INT NOT NULL,
    CONSTRAINT PK_Ayudante PRIMARY KEY (id_participante),
    CONSTRAINT FK_Ayudante_Participante FOREIGN KEY (id_participante, tipo) REFERENCES personas.Participante (id_participante, tipo),
    CONSTRAINT CK_Ayudante_tipo CHECK (tipo = 'Y'),
    CONSTRAINT FK_Ayudante_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES torneo.Seleccion (id_seleccion)
);
GO

-- ===========================================================================
-- ESQUEMA torneo
-- ===========================================================================
-- DER: relacion unaria 'reemplaza' Jugador - Jugador con atributos fecha y motivo (cardinalidad (0,1)).
-- Un jugador reemplaza como maximo a uno (PK = id_jugador_entra) y es reemplazado como maximo por uno (UNIQUE id_jugador_sale).
-- Es el registro de altas y bajas de ultima hora de la convocatoria (consigna B): el jugador 'sale' queda dado de baja.
CREATE TABLE torneo.ReemplazoConvocatoria (
    id_jugador_entra INT NOT NULL,
    id_jugador_sale INT NOT NULL,
    fecha DATE NOT NULL,
    motivo NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_ReemplazoConvocatoria PRIMARY KEY (id_jugador_entra),
    CONSTRAINT UQ_ReemplazoConvocatoria_id_jugador_sale UNIQUE (id_jugador_sale),
    CONSTRAINT FK_ReemplazoConvocatoria_id_jugador_entra FOREIGN KEY (id_jugador_entra) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT FK_ReemplazoConvocatoria_id_jugador_sale FOREIGN KEY (id_jugador_sale) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT CK_ReemplazoConvocatoria_entra_distinto_de_sale CHECK (id_jugador_entra <> id_jugador_sale)
);
GO

-- Sede (id, nombre estadio, capacidad). (pais y huso horario salen de la ciudad).
CREATE TABLE torneo.Sede (
    id_sede INT IDENTITY(1,1) NOT NULL,
    id_ciudad INT NOT NULL,
    nombre_estadio NVARCHAR(100) NOT NULL,
    capacidad INT NOT NULL,
    CONSTRAINT PK_Sede PRIMARY KEY (id_sede),
    CONSTRAINT UQ_Sede_id_ciudad_nombre_estadio UNIQUE (id_ciudad, nombre_estadio),
    CONSTRAINT FK_Sede_id_ciudad FOREIGN KEY (id_ciudad) REFERENCES geo.Ciudad (id_ciudad),
    CONSTRAINT CK_Sede_capacidad CHECK (capacidad > 0)
);
GO

-- DER: Partido (id, fase, fecha, horario, asistencia, resultado). 'se juega en': Sede 1 - N Partido.
-- 'principal' y 'VAR' (Arbitro 1 - N Partido) se resuelven como FK en Partido, NULL hasta la designacion.
-- AJUSTES: (1) fecha y horario son LOCALES de la sede; se agrega fecha_hora_utc porque la consigna exige ambos (la calcula el SP
-- a partir del huso de la ciudad; es una desnormalizacion deliberada). (2) 'resultado' se separa en goles_local/goles_visitante (1FN).
-- (3)no se relaciona Partido con Seleccion (Formacion es la formacion la que juega el partido y de ahi sale seleccion ya que las formaciones pertenecen a una unica foramacion)
--se agregan local/visitante porque el fixture existe antes de
-- las formaciones y debe poder filtrarse por seleccion. NULL permitido para llaves de eliminacion directa aun sin definir.
CREATE TABLE torneo.Partido (
    id_partido INT IDENTITY(1,1) NOT NULL,
    id_sede INT NOT NULL,
    id_seleccion_1 INT NULL,
    id_seleccion_2 INT NULL,
    fase VARCHAR(15) NOT NULL,
    fecha DATE NOT NULL,
    horario TIME(0) NOT NULL,
    fecha_hora_utc DATETIME2(0) NOT NULL,
    goles_1 TINYINT NULL,
    goles_2 TINYINT NULL,
    asistencia INT NULL,
    id_arbitro_principal INT NULL,
    id_arbitro_var INT NULL,
    CONSTRAINT PK_Partido PRIMARY KEY (id_partido),
    CONSTRAINT FK_Partido_id_sede FOREIGN KEY (id_sede) REFERENCES torneo.Sede (id_sede),
    CONSTRAINT FK_Partido_id_seleccion_local FOREIGN KEY (id_seleccion_1) REFERENCES torneo.Seleccion (id_seleccion),
    CONSTRAINT FK_Partido_id_seleccion_visitante FOREIGN KEY (id_seleccion_2) REFERENCES torneo.Seleccion (id_seleccion),
    CONSTRAINT FK_Partido_id_arbitro_principal FOREIGN KEY (id_arbitro_principal) REFERENCES personas.Arbitro (id_participante),
    CONSTRAINT FK_Partido_id_arbitro_var FOREIGN KEY (id_arbitro_var) REFERENCES personas.Arbitro (id_participante),
    CONSTRAINT CK_Partido_fase CHECK (fase IN ('GRUPOS','DIECISEISAVOS','OCTAVOS','CUARTOS','SEMIFINAL','TERCER_PUESTO','FINAL')),
    CONSTRAINT CK_Partido_asistencia CHECK (asistencia >= 0),
    CONSTRAINT CK_Partido_selecciones_distintas CHECK (id_seleccion_1 IS NULL OR id_seleccion_2 IS NULL OR id_seleccion_1 <> id_seleccion_2),
    CONSTRAINT CK_Partido_resultado_completo CHECK ((goles_1 IS NULL AND goles_2 IS NULL) OR (goles_1 IS NOT NULL AND goles_2 IS NOT NULL)),
    CONSTRAINT CK_Partido_principal_distinto_de_var CHECK (id_arbitro_principal IS NULL OR id_arbitro_var IS NULL OR id_arbitro_principal <> id_arbitro_var)
);
GO

-- DER: relacion 'secundarios' Arbitro N - M Partido. AGREGADO: rol (la consigna distingue asistentes de cuarto arbitro).
-- La cantidad (2 asistentes + 1 cuarto) se valida en los SP.
CREATE TABLE torneo.ArbitroSecundario (
    id_partido INT NOT NULL,
    id_arbitro INT NOT NULL,
    rol VARCHAR(10) NOT NULL,
    CONSTRAINT PK_ArbitroSecundario PRIMARY KEY (id_partido, id_arbitro),
    CONSTRAINT FK_ArbitroSecundario_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_ArbitroSecundario_id_arbitro FOREIGN KEY (id_arbitro) REFERENCES personas.Arbitro (id_participante),
    CONSTRAINT CK_ArbitroSecundario_rol CHECK (rol IN ('ASISTENTE','CUARTO'))
);
GO

-- DER: formacion (id, esquema tactico). 'emite': Seleccion 1 - N Formacion;
-- UNIQUE (partido, seleccion): como maximo 2 formaciones por partido (una por equipo).
CREATE TABLE torneo.Formacion (
    id_formacion INT IDENTITY(1,1) NOT NULL,
    id_seleccion INT NOT NULL,
    esquema_tactico VARCHAR(10) NOT NULL,
    CONSTRAINT PK_Formacion PRIMARY KEY (id_formacion),
    CONSTRAINT UQ_Formacion_id_formacion_id_seleccion UNIQUE (id_formacion, id_seleccion),
    CONSTRAINT FK_Formacion_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES torneo.Seleccion (id_seleccion),
    CONSTRAINT CK_Formacion_esquema_tactico CHECK (esquema_tactico LIKE '[0-9]-[0-9]%')
);
GO

CREATE TABLE torneo.PartidoFormacion (
    id_partido INT NOT NULL,
    id_formacion INT NOT NULL,
    id_seleccion INT NOT NULL,
    CONSTRAINT PK_PartidoFormacion PRIMARY KEY (id_partido, id_formacion),
    CONSTRAINT UQ_PartidoFormacion_id_partido_id_seleccion UNIQUE (id_partido, id_seleccion),
    CONSTRAINT FK_PartidoFormacion_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_PartidoFormacion_id_formacion FOREIGN KEY (id_formacion, id_seleccion) REFERENCES torneo.Formacion (id_formacion, id_seleccion)
);
GO

-- DER: relacion 'titular de' Jugador N - M Formacion. AGREGADOS: posicion_cancha y dorsal_cancha (consigna C: 'posicion/dorsal en cancha').
-- El historial de titularidad se obtiene de esta tabla.
CREATE TABLE torneo.FormacionTitular (
    id_formacion INT NOT NULL,
    id_jugador INT NOT NULL,
    posicion_cancha VARCHAR(20) NOT NULL,
    dorsal_cancha TINYINT NOT NULL,
    CONSTRAINT PK_FormacionTitular PRIMARY KEY (id_formacion, id_jugador),
    CONSTRAINT UQ_FormacionTitular_id_formacion_dorsal_cancha UNIQUE (id_formacion, dorsal_cancha),
    CONSTRAINT FK_FormacionTitular_id_formacion FOREIGN KEY (id_formacion) REFERENCES torneo.Formacion (id_formacion),
    CONSTRAINT FK_FormacionTitular_id_jugador FOREIGN KEY (id_jugador) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT CK_FormacionTitular_dorsal_cancha CHECK (dorsal_cancha BETWEEN 1 AND 99)
);
GO

-- DER: relacion 'suplente de' Jugador N - M Formacion (banco de suplentes del partido).
-- Que un jugador no sea titular y suplente a la vez en la misma formacion se valida en los SP (afecta a dos tablas).
CREATE TABLE torneo.FormacionSuplente (
    id_formacion INT NOT NULL,
    id_jugador INT NOT NULL,
    CONSTRAINT PK_FormacionSuplente PRIMARY KEY (id_formacion, id_jugador),
    CONSTRAINT FK_FormacionSuplente_id_formacion FOREIGN KEY (id_formacion) REFERENCES torneo.Formacion (id_formacion),
    CONSTRAINT FK_FormacionSuplente_id_jugador FOREIGN KEY (id_jugador) REFERENCES personas.Jugador (id_participante)
);
GO

-- DER: sustitucion (nro, minuto, motivo) - ENTIDAD DEBIL de Partido; 'sale' y 'entra' (Jugador 0..N). PK (id_partido, nro).
-- AGREGADO: periodo, necesario para validar el cambio adicional en tiempo suplementario (consigna D). Las ventanas se obtienen
-- contando minutos distintos de cambios del equipo (dato derivable: no se almacena).
CREATE TABLE torneo.Sustitucion (
    id_partido INT NOT NULL,
    nro TINYINT NOT NULL,
    id_jugador_sale INT NOT NULL,
    id_jugador_entra INT NOT NULL,
    minuto TINYINT NOT NULL,
    periodo VARCHAR(20) NOT NULL,
    motivo VARCHAR(10) NOT NULL,
    CONSTRAINT PK_Sustitucion PRIMARY KEY (id_partido, nro),
    CONSTRAINT FK_Sustitucion_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_Sustitucion_id_jugador_sale FOREIGN KEY (id_jugador_sale) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT FK_Sustitucion_id_jugador_entra FOREIGN KEY (id_jugador_entra) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT CK_Sustitucion_sale_distinto_de_entra CHECK (id_jugador_sale <> id_jugador_entra),
    CONSTRAINT CK_Sustitucion_minuto CHECK (minuto BETWEEN 1 AND 135),
    CONSTRAINT CK_Sustitucion_periodo CHECK (periodo IN ('PRIMER_TIEMPO','SEGUNDO_TIEMPO','ADICIONALES','ALARGUE')),
    CONSTRAINT CK_Sustitucion_motivo CHECK (motivo IN ('TACTICO','LESION','PRECAUCION'))
);
GO

-- DER: gol (nro, tipo, periodo, minuto) - ENTIDAD DEBIL de Partido; 'realiza' (autor) y 'asiste' (asistente, opcional).
-- PK (id_partido, nro).
CREATE TABLE torneo.Gol (
    id_partido INT NOT NULL,
    nro TINYINT NOT NULL,
    id_jugador_autor INT NOT NULL,
    id_jugador_asistente INT NULL,
    minuto TINYINT NOT NULL,
    tipo VARCHAR(10) NOT NULL,
    periodo VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Gol PRIMARY KEY (id_partido, nro),
    CONSTRAINT FK_Gol_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_Gol_id_jugador_autor FOREIGN KEY (id_jugador_autor) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT FK_Gol_id_jugador_asistente FOREIGN KEY (id_jugador_asistente) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT CK_Gol_autor_distinto_de_asistente CHECK (id_jugador_asistente IS NULL OR id_jugador_autor <> id_jugador_asistente),
    CONSTRAINT CK_Gol_minuto CHECK (minuto BETWEEN 1 AND 135),
    CONSTRAINT CK_Gol_tipo CHECK (tipo IN ('JUGADA','PENAL','TIRO_LIBRE','EN_CONTRA','CABEZAZO','OTRO')),
    CONSTRAINT CK_Gol_periodo CHECK (periodo IN ('PRIMER_TIEMPO','SEGUNDO_TIEMPO','ADICIONALES','ALARGUE','DEFINICION_PENALES'))
);
GO

-- DER: sancion (nro, color, minuto) - ENTIDAD DEBIL de Partido; 'recibe' (Jugador 0..N). Registra cada tarjeta.
-- AGREGADO: motivo
CREATE TABLE torneo.Sancion (
    id_partido INT NOT NULL,
    nro TINYINT NOT NULL,
    id_jugador INT NOT NULL,
    color VARCHAR(8) NOT NULL,
    minuto TINYINT NOT NULL,
    motivo NVARCHAR(100) NULL,
    CONSTRAINT PK_Sancion PRIMARY KEY (id_partido, nro),
    CONSTRAINT FK_Sancion_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_Sancion_id_jugador FOREIGN KEY (id_jugador) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT CK_Sancion_color CHECK (color IN ('AMARILLA','ROJA')),
    CONSTRAINT CK_Sancion_minuto CHECK (minuto BETWEEN 1 AND 135)
);
GO

-- DER: expulsion (nro, causa) - ENTIDAD DEBIL de Partido; 'recibe' (Jugador 0..N). causa distingue doble amarilla de roja directa (consigna F).
-- El DER no vincula Expulsion con Sancion: la coherencia (roja directa <-> tarjeta ROJA; doble amarilla <-> 2 amarillas en el partido)
-- la controlan los SP.
CREATE TABLE torneo.Expulsion (
    id_partido INT NOT NULL,
    nro TINYINT NOT NULL,
    id_jugador INT NOT NULL,
    causa VARCHAR(15) NOT NULL,
    CONSTRAINT PK_Expulsion PRIMARY KEY (id_partido, nro),
    CONSTRAINT FK_Expulsion_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_Expulsion_id_jugador FOREIGN KEY (id_jugador) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT CK_Expulsion_causa CHECK (causa IN ('DOBLE_AMARILLA','ROJA_DIRECTA'))
);
GO

--esta tabla guarda el resultado de la expulsion: que no pueda jugar el proximo partido
-- El estado (activa/cumplida) se deduce de partidos_cumplidos < partidos_a_cumplir (no se almacena para no duplicar informacion).
CREATE TABLE torneo.Suspension (
    id_suspension INT IDENTITY(1,1) NOT NULL,
    id_jugador INT NOT NULL,
    id_partido_origen INT NOT NULL,
    motivo VARCHAR(25) NOT NULL,
    partidos_a_cumplir TINYINT NOT NULL,
    partidos_cumplidos TINYINT NOT NULL CONSTRAINT DF_Suspension_partidos_cumplidos DEFAULT 0,
    CONSTRAINT PK_Suspension PRIMARY KEY (id_suspension),
    CONSTRAINT UQ_Suspension_id_jugador_id_partido_origen_motivo UNIQUE (id_jugador, id_partido_origen, motivo),
    CONSTRAINT FK_Suspension_id_jugador FOREIGN KEY (id_jugador) REFERENCES personas.Jugador (id_participante),
    CONSTRAINT FK_Suspension_id_partido_origen FOREIGN KEY (id_partido_origen) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT CK_Suspension_motivo CHECK (motivo IN ('ACUMULACION_AMARILLAS','ROJA_DIRECTA','DOBLE_AMARILLA')),
    CONSTRAINT CK_Suspension_partidos_a_cumplir CHECK (partidos_a_cumplir >= 1),
    CONSTRAINT CK_Suspension_cumplidos_no_supera CHECK (partidos_cumplidos <= partidos_a_cumplir)
);
GO

-- Criterios parametrizables:“según el reglamento vigente”. Si esos números estuvieran escritos dentro de los procedimientos, 
-- habría que modificar y volver a crear los procedimientos cada vez que cambie una regla. En cambio, se guardan en una tabla. 
-- convocatoria minima/maxima, prime time). Ej.: AMARILLAS_PARA_SUSPENSION, MAX_CAMBIOS, MAX_VENTANAS, PRIME_TIME_DESDE.
CREATE TABLE torneo.Parametro (
    clave VARCHAR(40) NOT NULL,
    valor INT NOT NULL,
    descripcion NVARCHAR(200) NULL,
    CONSTRAINT PK_Parametro PRIMARY KEY (clave),
    CONSTRAINT CK_Parametro_valor CHECK (valor >= 0)
);
GO

-- ===========================================================================
-- ESQUEMA publicidad
-- ===========================================================================
-- DER: Anunciante (id, nombre, razon social).
CREATE TABLE publicidad.Anunciante (
    id_anunciante INT IDENTITY(1,1) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    razon_social NVARCHAR(150) NOT NULL,
    CONSTRAINT PK_Anunciante PRIMARY KEY (id_anunciante),
    CONSTRAINT UQ_Anunciante_razon_social UNIQUE (razon_social)
);
GO

-- Campania (cod, nombre) 
CREATE TABLE publicidad.Campania (
    id_anunciante INT NOT NULL,
    cod_campania VARCHAR(20) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_Campania PRIMARY KEY (id_anunciante, cod_campania),
    CONSTRAINT FK_Campania_id_anunciante FOREIGN KEY (id_anunciante) REFERENCES publicidad.Anunciante (id_anunciante)
);
GO

-- DER: Contenido (cod, nombre) - ENTIDAD DEBIL de Campania ('Lanza' identificador, 1 - N). PK (id_anunciante, cod_campania, cod_contenido).
-- 'tiene': Contenido N - 1 Idioma (pieza por idioma/mercado, consigna H).
CREATE TABLE publicidad.Contenido (
    id_anunciante INT NOT NULL,
    cod_campania VARCHAR(20) NOT NULL,
    cod_contenido VARCHAR(20) NOT NULL,
    nombre NVARCHAR(100) NOT NULL,
    id_idioma INT NOT NULL,
    CONSTRAINT PK_Contenido PRIMARY KEY (id_anunciante, cod_campania, cod_contenido),
    CONSTRAINT FK_Contenido_id_anunciante_cod_campania FOREIGN KEY (id_anunciante, cod_campania) REFERENCES publicidad.Campania (id_anunciante, cod_campania),
    CONSTRAINT FK_Contenido_id_idioma FOREIGN KEY (id_idioma) REFERENCES geo.Idioma (id_idioma)
);
GO

-- DER: relacion 'objetivo' Contenido - Pais. La consigna habla de 'el pais (o los paises) de interes', por lo que se resuelve como N:M.
CREATE TABLE publicidad.ContenidoPais (
    id_anunciante INT NOT NULL,
    cod_campania VARCHAR(20) NOT NULL,
    cod_contenido VARCHAR(20) NOT NULL,
    id_pais INT NOT NULL,
    CONSTRAINT PK_ContenidoPais PRIMARY KEY (id_anunciante, cod_campania, cod_contenido, id_pais),
    CONSTRAINT FK_ContenidoPais_id_anunciante_cod_campania_cod_contenido FOREIGN KEY (id_anunciante, cod_campania, cod_contenido) REFERENCES publicidad.Contenido (id_anunciante, cod_campania, cod_contenido),
    CONSTRAINT FK_ContenidoPais_id_pais FOREIGN KEY (id_pais) REFERENCES geo.Pais (id_pais)
);
GO

-- DER: tarifa (id, franja, costo). 'sujeto a': Tarifa 1 - N Espacio Pub.
CREATE TABLE publicidad.Tarifa (
    id_tarifa INT IDENTITY(1,1) NOT NULL,
    franja NVARCHAR(40) NOT NULL,
    costo DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_Tarifa PRIMARY KEY (id_tarifa),
    CONSTRAINT UQ_Tarifa_franja UNIQUE (franja),
    CONSTRAINT CK_Tarifa_costo CHECK (costo >= 0)
);
GO

-- DER: Espacio Pub. (nro, horario) - ENTIDAD DEBIL de Partido ('Dispone de' identificador, 1 - 4). PK (id_partido, nro) con nro 1..4:
-- la PK mas el CHECK garantizan exactamente cuatro espacios por partido. 'asignado a': Contenido 1 - N Espacio (FK compuesta, NULL hasta
-- que el SP de asignacion elige las piezas). horario = inicio de la emision en UTC. El CHECK contenido_completo evita FK a medias.
-- Esta tabla es tambien el historial de lo exhibido por partido (base de facturacion).
CREATE TABLE publicidad.EspacioPublicitario (
    id_partido INT NOT NULL,
    nro TINYINT NOT NULL,
    id_tarifa INT NOT NULL,
    horario DATETIME2(0) NOT NULL,
    id_anunciante INT NULL,
    cod_campania VARCHAR(20) NULL,
    cod_contenido VARCHAR(20) NULL,
    CONSTRAINT PK_EspacioPublicitario PRIMARY KEY (id_partido, nro),
    CONSTRAINT FK_EspacioPublicitario_id_partido FOREIGN KEY (id_partido) REFERENCES torneo.Partido (id_partido),
    CONSTRAINT FK_EspacioPublicitario_id_tarifa FOREIGN KEY (id_tarifa) REFERENCES publicidad.Tarifa (id_tarifa),
    CONSTRAINT FK_EspacioPublicitario_id_anunciante_cod_campania_cod_contenido FOREIGN KEY (id_anunciante, cod_campania, cod_contenido) REFERENCES publicidad.Contenido (id_anunciante, cod_campania, cod_contenido),
    CONSTRAINT CK_EspacioPublicitario_nro CHECK (nro BETWEEN 1 AND 4),
    CONSTRAINT CK_EspacioPublicitario_contenido_completo CHECK ((id_anunciante IS NULL AND cod_campania IS NULL AND cod_contenido IS NULL) OR (id_anunciante IS NOT NULL AND cod_campania IS NOT NULL AND cod_contenido IS NOT NULL))
);
GO

