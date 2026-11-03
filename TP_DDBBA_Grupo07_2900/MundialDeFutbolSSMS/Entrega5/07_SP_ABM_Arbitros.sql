/* =============================================================================
   Universidad Nacional de la Matanza
   Materia      : 3641 - Bases de Datos Aplicada
   Comisión     : 2900          Grupo: 07
   Integrantes  : Ginno Verdecchia - Tiago Patri - Matias Ariel Espinoza - Juan Andres Leguizamón Sarmiento
   Fecha        : 15/10/2026
   Objetivo     : Designación de los árbitros secundarios de un partido (2 asistentes y 1 cuarto árbitro).
                  Controla que sean distintos del principal y del VAR, el conflicto de nacionalidad y,
                  desde dieciseisavos, avisa si el país del árbitro sigue en competencia.
                  El principal y el VAR se designan desde torneo.Partido_Insertar / Partido_Modificar.
   ============================================================================= */

USE MundialFutbol;
GO

CREATE OR ALTER PROCEDURE torneo.ArbitroSecundario_Insertar
    @id_partido INT,
    @id_arbitro INT,
    @rol VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';
    DECLARE @fase VARCHAR(15), @sel_1 INT, @sel_2 INT, @principal INT, @var INT, @pais INT;
    DECLARE @partido_existe BIT = 0;

    SELECT @fase = fase, @sel_1 = id_seleccion_1, @sel_2 = id_seleccion_2,
           @principal = id_arbitro_principal, @var = id_arbitro_var, @partido_existe = 1
    FROM torneo.Partido WHERE id_partido = @id_partido;
    SELECT @pais = id_pais FROM personas.Arbitro WHERE id_participante = @id_arbitro;

    IF @partido_existe = 0
        SET @errores += 'El partido no existe. ';
    IF @pais IS NULL
        SET @errores += 'El árbitro no existe. ';
    IF @rol IS NULL OR @rol NOT IN ('ASISTENTE', 'CUARTO')
        SET @errores += 'El rol debe ser ASISTENTE o CUARTO. ';
    IF EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro)
        SET @errores += 'El árbitro ya está designado como secundario en ese partido. ';
    IF @id_arbitro IN (ISNULL(@principal, 0), ISNULL(@var, 0))
        SET @errores += 'El árbitro ya es el principal o el de VAR de ese partido. ';
    IF EXISTS (SELECT 1 FROM torneo.Seleccion WHERE id_pais = @pais AND id_seleccion IN (@sel_1, @sel_2))
        SET @errores += 'Conflicto de nacionalidad: el árbitro es de una de las selecciones del partido. ';
    IF @rol = 'ASISTENTE' AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido AND rol = 'ASISTENTE') >= 2
        SET @errores += 'El partido ya tiene sus dos asistentes. ';
    IF @rol = 'CUARTO' AND EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido AND rol = 'CUARTO')
        SET @errores += 'El partido ya tiene cuarto árbitro. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    IF @fase <> 'GRUPOS' AND torneo.fn_PaisSigueEnCompetencia(@pais) = 1
        PRINT 'ADVERTENCIA: el país del árbitro todavía tiene una selección en competencia.';

    INSERT INTO torneo.ArbitroSecundario (id_partido, id_arbitro, rol) VALUES (@id_partido, @id_arbitro, @rol);
END;
GO

CREATE OR ALTER PROCEDURE torneo.ArbitroSecundario_Modificar
    @id_partido INT,
    @id_arbitro INT,
    @rol VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores VARCHAR(2000) = '';

    IF NOT EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro)
        SET @errores += 'El árbitro no es secundario de ese partido. ';
    IF @rol IS NULL OR @rol NOT IN ('ASISTENTE', 'CUARTO')
        SET @errores += 'El rol debe ser ASISTENTE o CUARTO. ';
    IF @rol = 'ASISTENTE' AND (SELECT COUNT(*) FROM torneo.ArbitroSecundario
                               WHERE id_partido = @id_partido AND rol = 'ASISTENTE' AND id_arbitro <> @id_arbitro) >= 2
        SET @errores += 'El partido ya tiene sus dos asistentes. ';
    IF @rol = 'CUARTO' AND EXISTS (SELECT 1 FROM torneo.ArbitroSecundario
                                   WHERE id_partido = @id_partido AND rol = 'CUARTO' AND id_arbitro <> @id_arbitro)
        SET @errores += 'El partido ya tiene cuarto árbitro. ';

    IF @errores <> ''
        THROW 50001, @errores, 1;

    UPDATE torneo.ArbitroSecundario SET rol = @rol WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro;
END;
GO

CREATE OR ALTER PROCEDURE torneo.ArbitroSecundario_Eliminar
    @id_partido INT,
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro)
        THROW 50001, 'El árbitro no es secundario de ese partido. ', 1;

    DELETE FROM torneo.ArbitroSecundario WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro;
END;
GO
