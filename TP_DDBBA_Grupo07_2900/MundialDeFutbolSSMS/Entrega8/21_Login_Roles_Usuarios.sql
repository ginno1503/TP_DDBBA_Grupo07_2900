/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 07/11/2026
   Objetivo     : Creacion de Login, Usuarios y Roles.
   
   =============================================================================*/

-- 1. Creacion de los Logins
USE master;
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'organizador')
    CREATE LOGIN organizador WITH PASSWORD = 'Temporal#Org2026!', CHECK_POLICY = ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'planteles')
    CREATE LOGIN planteles WITH PASSWORD = 'Temporal#Plant2026!', CHECK_POLICY = ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'operador')
    CREATE LOGIN operador WITH PASSWORD = 'Temporal#Op2026!', CHECK_POLICY = ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'comercial')
    CREATE LOGIN comercial WITH PASSWORD = 'Temporal#Com2026!', CHECK_POLICY = ON;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'importador')
    CREATE LOGIN importador WITH PASSWORD = 'Temporal#Imp2026!', CHECK_POLICY = ON;



-- 2. Creacion de los Usuarios
USE MundialFutbol;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'organizador')
    CREATE USER organizador FOR LOGIN organizador;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'planteles')
    CREATE USER planteles FOR LOGIN planteles;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'operador')
    CREATE USER operador FOR LOGIN operador;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'comercial')
    CREATE USER comercial FOR LOGIN comercial;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'importador')
    CREATE USER importador FOR LOGIN importador;
GO

-- 3. Creacion de Roles y asignacion de permisos.
IF DATABASE_PRINCIPAL_ID('rol_organizador') IS NULL CREATE ROLE rol_organizador;
IF DATABASE_PRINCIPAL_ID('rol_planteles') IS NULL CREATE ROLE rol_planteles;
IF DATABASE_PRINCIPAL_ID('rol_operador') IS NULL CREATE ROLE rol_operador;
IF DATABASE_PRINCIPAL_ID('rol_publicidad') IS NULL CREATE ROLE rol_publicidad;
IF DATABASE_PRINCIPAL_ID('rol_importacion') IS NULL CREATE ROLE rol_importacion;
GO

-- rol_organizador: administra el torneo. Sedes, selecciones, partidos,
-- parámetros, formaciones, y corrección de goles, tarjetas y suspensiones.
GRANT EXECUTE ON SCHEMA::torneo TO rol_organizador;
GRANT EXECUTE ON SCHEMA::geo TO rol_organizador;
GRANT SELECT ON SCHEMA::torneo TO rol_organizador;
GRANT SELECT ON SCHEMA::geo TO rol_organizador;
GRANT SELECT ON SCHEMA::personas TO rol_organizador;

-- rol_planteles: gestiona las personas. Jugadores, árbitros, cuerpo técnico
--y clubes, más convocatorias, reemplazos y alineaciones.
GRANT EXECUTE ON SCHEMA::personas TO rol_planteles;
GRANT EXECUTE ON OBJECT::torneo.Convocatoria_Registrar TO rol_planteles;
GRANT EXECUTE ON OBJECT::torneo.Convocatoria_ReemplazarJugador TO rol_planteles;
GRANT EXECUTE ON OBJECT::torneo.ReemplazoConvocatoria_Insertar TO rol_planteles;
GRANT EXECUTE ON OBJECT::torneo.ReemplazoConvocatoria_Modificar TO rol_planteles;
GRANT EXECUTE ON OBJECT::torneo.ReemplazoConvocatoria_Eliminar TO rol_planteles;
GRANT EXECUTE ON OBJECT::torneo.Alineacion_Registrar TO rol_planteles;
GRANT SELECT ON SCHEMA::personas TO rol_planteles;
GRANT SELECT ON SCHEMA::torneo TO rol_planteles;
GRANT SELECT ON SCHEMA::geo TO rol_planteles;

-- rol_operador: carga en vivo durante el partido. Cambios, goles,
-- tarjetas (con expulsión y suspensión), resultado y equipo arbitral.
GRANT EXECUTE ON OBJECT::torneo.Cambio_Registrar TO rol_operador;
GRANT EXECUTE ON OBJECT::torneo.Gol_Registrar TO rol_operador;
GRANT EXECUTE ON OBJECT::torneo.Tarjeta_Registrar TO rol_operador;
GRANT EXECUTE ON OBJECT::torneo.Partido_RegistrarResultado TO rol_operador;
GRANT EXECUTE ON OBJECT::torneo.Partido_DesignarArbitros TO rol_operador;
GRANT SELECT ON SCHEMA::torneo TO rol_operador;
GRANT SELECT ON SCHEMA::personas TO rol_operador;

-- rol_publicidad: área comercial. Anunciantes, campañas, contenidos,
-- tarifas, espacios de cada partido, tipo de cambio y feriados.
GRANT EXECUTE ON SCHEMA::publicidad TO rol_publicidad;
GRANT SELECT ON SCHEMA::publicidad TO rol_publicidad;
GRANT SELECT ON SCHEMA::geo TO rol_publicidad;
GRANT SELECT ON OBJECT::torneo.Partido TO rol_publicidad;
GRANT SELECT ON OBJECT::torneo.Seleccion TO rol_publicidad;

-- rol_importacion: ejecuta las cargas de datos externos. Mundial (JSON),
-- goles (CSV), APIs de cambio y feriados, y scraping de árbitros y PBI.
GRANT EXECUTE ON SCHEMA::importacion TO rol_importacion;
GRANT SELECT ON SCHEMA::importacion TO rol_importacion;
-- BULK INSERT corre en sp_executesql: necesita INSERT directo
GRANT INSERT ON OBJECT::importacion.JsonCarga TO rol_importacion;
GRANT INSERT ON OBJECT::importacion.GolCarga TO rol_importacion;

-- 4. Asignacion de roles a usuarios
ALTER ROLE rol_organizador ADD MEMBER organizador;
ALTER ROLE rol_planteles ADD MEMBER planteles;
ALTER ROLE rol_operador ADD MEMBER operador;
ALTER ROLE rol_publicidad ADD MEMBER comercial;
ALTER ROLE rol_importacion ADD MEMBER importador;
GO

-- Consultar los SP de un Esquema en especifico
/*USE MundialFutbol;
SELECT 
    SCHEMA_NAME(schema_id) AS [Schema],
    name AS [Stored Procedure]
FROM 
    sys.procedures
WHERE 
    SCHEMA_NAME(schema_id) = 'torneo' -- Reemplaza con el nombre de tu schema
ORDER BY 
    name;
GO*/