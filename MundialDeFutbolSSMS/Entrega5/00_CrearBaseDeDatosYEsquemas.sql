/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Objetivo     : Recrear la base de datos MundialFutbol (reemplazo completo) y crear sus esquemas: geo, personas, torneo y publicidad.
   ============================================================================= */

/* Reemplazo completo: si la base existe se elimina y se crea de nuevo, de modo que los esquemas
   siempre se crean sobre una base vacia. ATENCION: borra todos los datos. Cerrar antes las otras
   ventanas conectadas a MundialFutbol. Usa las rutas de datos y logs configuradas en la Entrega 4. */

USE master;
GO

DROP DATABASE IF EXISTS MundialFutbol;
GO

CREATE DATABASE MundialFutbol COLLATE SQL_Latin1_General_CP1_CI_AS;
GO

USE MundialFutbol;
GO

CREATE SCHEMA geo;         -- paises, ciudades, idiomas
GO
CREATE SCHEMA personas;    -- participantes, jugadores, arbitros, cuerpo tecnico, clubes
GO
CREATE SCHEMA torneo;      -- sedes, selecciones, partidos, formaciones, eventos, parametros
GO
CREATE SCHEMA publicidad;  -- anunciantes, campanias, contenidos, espacios, tarifas
GO
