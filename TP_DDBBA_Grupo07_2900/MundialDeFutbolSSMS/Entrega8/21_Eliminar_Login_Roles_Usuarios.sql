/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 07/11/2026
   Objetivo     : Eliminar los Login, Usuarios y Roles creados con anterioridad. Para pruebas.
   
   =============================================================================*/

USE MundialFutbol;
GO
-- ELIMINA los usuarios, roles y logins creados en la Entrega 8.
 
-- 1) Usuarios de la base
IF DATABASE_PRINCIPAL_ID('organizador') IS NOT NULL DROP USER organizador;
IF DATABASE_PRINCIPAL_ID('planteles') IS NOT NULL DROP USER planteles;
IF DATABASE_PRINCIPAL_ID('operador') IS NOT NULL DROP USER operador;
IF DATABASE_PRINCIPAL_ID('comercial') IS NOT NULL DROP USER comercial;
IF DATABASE_PRINCIPAL_ID('importador') IS NOT NULL DROP USER importador;
GO
 
-- 2) Roles de la base (los permisos otorgados a cada rol se eliminan con el rol)
IF DATABASE_PRINCIPAL_ID('rol_organizador') IS NOT NULL DROP ROLE rol_organizador;
IF DATABASE_PRINCIPAL_ID('rol_planteles') IS NOT NULL DROP ROLE rol_planteles;
IF DATABASE_PRINCIPAL_ID('rol_operador') IS NOT NULL DROP ROLE rol_operador;
IF DATABASE_PRINCIPAL_ID('rol_publicidad') IS NOT NULL DROP ROLE rol_publicidad;
IF DATABASE_PRINCIPAL_ID('rol_importacion') IS NOT NULL DROP ROLE rol_importacion;
GO
 
-- 3) Logins del servidor (al borrar importador tambien se pierde su permiso ADMINISTER BULK OPERATIONS)
USE master;
GO
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'organizador') DROP LOGIN organizador;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'planteles') DROP LOGIN planteles;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'operador') DROP LOGIN operador;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'comercial') DROP LOGIN comercial;
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'importador') DROP LOGIN importador;
GO
