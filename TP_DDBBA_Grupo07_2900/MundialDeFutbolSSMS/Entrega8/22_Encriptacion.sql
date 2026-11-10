/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 07/11/2026
   Objetivo     : Encriptacion de los Datos sensibles (DNI de participantes).

   
   =============================================================================*/

USE MundialFutbol;
GO

-- 1) Columna para el DNI cifrado.

ALTER TABLE personas.Participante
ADD dni_cifrado VARBINARY(256) NULL;
GO


-- 2) Cifrado de todos los DNIs.
DECLARE @FraseClaveCargadaPorUsuario NVARCHAR(128);
SET @FraseClaveCargadaPorUsuario = 'ClaveDeCifrado2026';

UPDATE personas.Participante
SET dni_cifrado = EncryptByPassPhrase(
        @FraseClaveCargadaPorUsuario, dni, 1,
        CONVERT(VARBINARY(20), id_participante))
WHERE dni_cifrado IS NULL;
GO


-- 3) Verificación: descifrar y comparar con el DNI original.
DECLARE @FraseClaveCargadaPorUsuario NVARCHAR(128);
SET @FraseClaveCargadaPorUsuario = 'ClaveDeCifrado2026';

SELECT id_participante, dni AS dni_original, dni_cifrado,
    CONVERT(VARCHAR(20),
        DecryptByPassPhrase(
            @FraseClaveCargadaPorUsuario, dni_cifrado,  1,
            CONVERT(VARBINARY(20), id_participante))
    ) AS dni_descifrado
FROM personas.Participante;
GO

select * From personas.Participante

-- DNI es Unique y Not NULL. No puedo dejar la columna en null. Y si remuevo la condicion
-- se podran ingresar jugadores sin DNI, cosa que no se deberia permitir.
-- Igualar: DNI = ID ?