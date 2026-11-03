/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 03/11/2026
   Objetivo     : Preparar la instancia de SQL Server para consumir APIs y páginas web desde T-SQL.
                  Se ejecuta UNA sola vez por instancia (no por cada recreación de la base) y requiere
                  permisos de sysadmin. Los archivos CSV y JSON se leen con BULK INSERT y no necesitan
                  ninguna configuración de la instancia.

                  Requisitos fuera de SQL Server:
                    1. La cuenta de servicio de SQL Server debe poder LEER la carpeta donde están
                       worldcup.json y goals.csv (por ejemplo NT Service\MSSQL$SQLEXPRESS en una instancia
                       Express). Los archivos los lee el servidor, no el usuario que ejecuta el script.
                    2. El usuario que importa necesita el permiso ADMINISTER BULK OPERATIONS
                       (lo tiene sysadmin).
                    3. Para APIs y scraping: el servidor necesita salida a Internet por HTTPS (443) y
                       Windows con MSXML 6 (viene instalado). Las llamadas HTTP se hacen con el objeto
                       MSXML2.ServerXMLHTTP.6.0 a través de Ole Automation Procedures.
   ============================================================================= */

USE master;
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- Permite llamar a objetos COM (sp_OACreate...): es la forma de hacer pedidos HTTP desde T-SQL
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO

PRINT 'OK - Servidor listo para consumir APIs y paginas web desde T-SQL.';
GO
