/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  :  Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 07/11/2026
   Objetivo     : Testing de encriptacion.
   ============================================================================= */
   
USE MundialFutbol;
GO

SET NOCOUNT ON;
GO

-- LIMPIEZA PREVIA
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.ContenidoPais;
DELETE FROM publicidad.Contenido;
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;
DELETE FROM publicidad.Feriado;

DELETE FROM torneo.Parametro;
DELETE FROM torneo.Suspension;
DELETE FROM torneo.Expulsion;
DELETE FROM torneo.Sancion;
DELETE FROM torneo.Gol;
DELETE FROM torneo.Sustitucion;
DELETE FROM torneo.FormacionSuplente;
DELETE FROM torneo.FormacionTitular;
DELETE FROM torneo.PartidoFormacion;
DELETE FROM torneo.Formacion;
DELETE FROM torneo.ArbitroSecundario;
DELETE FROM torneo.Partido;
DELETE FROM torneo.Sede;
DELETE FROM torneo.ReemplazoConvocatoria;
DELETE FROM personas.Ayudante;
DELETE FROM personas.DirectorTecnico;
DELETE FROM personas.ArbitroIdioma;
DELETE FROM personas.Arbitro;
DELETE FROM personas.Jugador;
DELETE FROM personas.Club;
DELETE FROM personas.Participante;
DELETE FROM torneo.Seleccion;
DELETE FROM geo.Ciudad;
DELETE FROM geo.Pais;
DELETE FROM geo.Idioma;
GO

PRINT '=== TEST 22_Encriptacion ===';

DECLARE @pais INT, @sel INT, @club INT, @j1 INT, @j2 INT, @arb INT, @dt INT, @ay INT, @nuevo INT;

EXEC geo.Pais_Insertar @nombre = 'TEST Pais', @huso_horario = -3.00, @id_pais = @pais OUTPUT;
EXEC torneo.Seleccion_Insertar @id_pais = @pais, @confederacion = 'CONMEBOL', @grupo = 'A', @id_seleccion = @sel OUTPUT;
EXEC personas.Club_Insertar @nombre = 'TEST Club', @id_club = @club OUTPUT;

-- 1. Estado general tras correr el script de cifrado
IF NOT EXISTS (SELECT 1 FROM personas.Participante WHERE dni_cifrado IS NULL)
   AND NOT EXISTS (SELECT 1 FROM personas.Participante WHERE dni <> CAST(id_participante AS VARCHAR(20)))
    PRINT 'OK 1 - Todas las filas tienen dni_cifrado y dni = id';
ELSE PRINT 'FALLO 1 - Hay filas sin cifrar o con dni distinto del id';

-- 2. Cifrar y descifrar con las funciones
IF personas.fn_CifrarDni('12345678', 1) IS NOT NULL
   AND CONVERT(VARCHAR(20), DecryptByPassPhrase(personas.fn_FraseClave(), personas.fn_CifrarDni('12345678', 1), 1, CONVERT(VARBINARY(20), 1))) = '12345678'
    PRINT 'OK 2 - fn_CifrarDni se descifra con la misma clave y authenticator';
ELSE PRINT 'FALLO 2';

-- 3. Alta de jugador: DNI guardado cifrado
EXEC personas.Jugador_Insertar @dni = '80000001', @nombre = 'TEST Jugador 1', @id_seleccion = @sel, @id_club = @club,
     @nro_dorsal = 10, @posicion = 'DELANTERO', @id_participante = @j1 OUTPUT;
IF EXISTS (SELECT 1 FROM personas.Participante WHERE id_participante = @j1 AND dni = CAST(@j1 AS VARCHAR(20)) AND dni_cifrado IS NOT NULL)
   AND personas.fn_IdPorDni('80000001') = @j1
   AND personas.fn_DescifrarDni(@j1) = '80000001'
    PRINT 'OK 3 - Jugador_Insertar: dni = id, dni_cifrado cargado, fn_IdPorDni y fn_DescifrarDni correctos';
ELSE PRINT 'FALLO 3';

-- 4. ERROR: DNI duplicado
BEGIN TRY
    EXEC personas.Jugador_Insertar @dni = '80000001', @nombre = 'TEST Duplicado', @id_seleccion = @sel, @id_club = @club,
         @nro_dorsal = 11, @posicion = 'DEFENSOR';
    PRINT 'FALLO 4 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 4 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 5. Modificar jugador: cambia el DNI real
EXEC personas.Jugador_Modificar @id_participante = @j1, @dni = '80000002', @nombre = 'TEST Jugador 1', @id_seleccion = @sel,
     @id_club = @club, @nro_dorsal = 10, @posicion = 'DELANTERO';
IF personas.fn_IdPorDni('80000002') = @j1 AND personas.fn_IdPorDni('80000001') IS NULL
   AND (SELECT dni FROM personas.Participante WHERE id_participante = @j1) = CAST(@j1 AS VARCHAR(20))
    PRINT 'OK 5 - Jugador_Modificar: DNI nuevo encontrado, DNI viejo ya no existe';
ELSE PRINT 'FALLO 5';

-- 6. ERROR: modificar con el DNI de otra persona
EXEC personas.Jugador_Insertar @dni = '80000003', @nombre = 'TEST Jugador 2', @id_seleccion = @sel, @id_club = @club,
     @nro_dorsal = 9, @posicion = 'DEFENSOR', @id_participante = @j2 OUTPUT;
BEGIN TRY
    EXEC personas.Jugador_Modificar @id_participante = @j2, @dni = '80000002', @nombre = 'TEST Jugador 2', @id_seleccion = @sel,
         @id_club = @club, @nro_dorsal = 9, @posicion = 'DEFENSOR';
    PRINT 'FALLO 6 - Debio fallar por DNI de otra persona';
END TRY
BEGIN CATCH
    PRINT 'OK 6 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 7. Modificar conservando su propio DNI (no es duplicado)
EXEC personas.Jugador_Modificar @id_participante = @j2, @dni = '80000003', @nombre = 'TEST Jugador 2 mod', @id_seleccion = @sel,
     @id_club = @club, @nro_dorsal = 9, @posicion = 'DEFENSOR';
IF personas.fn_IdPorDni('80000003') = @j2 PRINT 'OK 7 - Modificar con el mismo DNI permitido';
ELSE PRINT 'FALLO 7';

-- 8. Arbitro, Director Tecnico y Ayudante
EXEC personas.Arbitro_Insertar @dni = '80000010', @nombre = 'TEST Arbitro', @id_pais = @pais, @categoria = 'FIFA', @id_participante = @arb OUTPUT;
EXEC personas.DirectorTecnico_Insertar @dni = '80000020', @nombre = 'TEST DT', @id_seleccion = @sel, @id_participante = @dt OUTPUT;
EXEC personas.Ayudante_Insertar @dni = '80000030', @nombre = 'TEST Ayudante', @id_seleccion = @sel, @id_participante = @ay OUTPUT;
IF personas.fn_IdPorDni('80000010') = @arb AND personas.fn_IdPorDni('80000020') = @dt AND personas.fn_IdPorDni('80000030') = @ay
    PRINT 'OK 8 - Alta cifrada de arbitro, director tecnico y ayudante';
ELSE PRINT 'FALLO 8';

-- 9. ERROR: el DNI de un arbitro no puede repetirse en otro tipo de persona
BEGIN TRY
    EXEC personas.Ayudante_Insertar @dni = '80000010', @nombre = 'TEST Ayudante Dup', @id_seleccion = @sel;
    PRINT 'FALLO 9 - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 9 - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 10. Reemplazo de convocatoria
EXEC torneo.Convocatoria_ReemplazarJugador @id_jugador_sale = @j2, @fecha = '2026-06-01', @motivo = 'Lesion',
     @dni = '80000040', @nombre = 'TEST Reemplazo', @id_club = @club, @posicion = 'DEFENSOR', @id_jugador_entra = @nuevo OUTPUT;
IF @nuevo IS NOT NULL AND personas.fn_IdPorDni('80000040') = @nuevo
   AND EXISTS (SELECT 1 FROM torneo.ReemplazoConvocatoria WHERE id_jugador_sale = @j2 AND id_jugador_entra = @nuevo)
    PRINT 'OK 10 - Convocatoria_ReemplazarJugador cifra el DNI del reemplazo';
ELSE PRINT 'FALLO 10';

BEGIN TRY
    EXEC torneo.Convocatoria_ReemplazarJugador @id_jugador_sale = @j1, @fecha = '2026-06-02', @motivo = 'Lesion',
         @dni = '80000040', @nombre = 'TEST Reemplazo 2', @id_club = @club, @posicion = 'DEFENSOR';
    PRINT 'FALLO 10b - Debio fallar por DNI duplicado';
END TRY
BEGIN CATCH
    PRINT 'OK 10b - Error esperado: ' + ERROR_MESSAGE();
END CATCH;

-- 11. DNI inexistente
IF personas.fn_IdPorDni('00000000') IS NULL PRINT 'OK 11 - fn_IdPorDni devuelve NULL si no existe';
ELSE PRINT 'FALLO 11';
GO


-- LIMPIEZA
DELETE FROM publicidad.EspacioPublicitario;
DELETE FROM publicidad.ContenidoPais;
DELETE FROM publicidad.Contenido;
DELETE FROM publicidad.Campania;
DELETE FROM publicidad.Anunciante;
DELETE FROM publicidad.Tarifa;

DELETE FROM torneo.Parametro;
DELETE FROM torneo.Suspension;
DELETE FROM torneo.Expulsion;
DELETE FROM torneo.Sancion;
DELETE FROM torneo.Gol;
DELETE FROM torneo.Sustitucion;
DELETE FROM torneo.FormacionSuplente;
DELETE FROM torneo.FormacionTitular;
DELETE FROM torneo.PartidoFormacion;
DELETE FROM torneo.Formacion;
DELETE FROM torneo.ArbitroSecundario;
DELETE FROM torneo.Partido;
DELETE FROM torneo.Sede;
DELETE FROM torneo.ReemplazoConvocatoria;
DELETE FROM personas.Ayudante;
DELETE FROM personas.DirectorTecnico;
DELETE FROM personas.ArbitroIdioma;
DELETE FROM personas.Arbitro;
DELETE FROM personas.Jugador;
DELETE FROM personas.Club;
DELETE FROM personas.Participante;
DELETE FROM torneo.Seleccion;
DELETE FROM geo.Ciudad;
DELETE FROM geo.Pais;
DELETE FROM geo.Idioma;
GO