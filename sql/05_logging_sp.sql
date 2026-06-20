/* ============================================================================
   PROYECTO: adf-docs-lab
   ARCHIVO : sql/05_logging_sp.sql
   MOTOR   : Azure SQL Database
   CAPA    : LOGGING / AUDITORIA DE CORRIDAS
   ----------------------------------------------------------------------------
   Dos SPs que ADF llama al inicio y al final de cada pipeline:

     usp_log_start : inserta una fila STARTED  (al arrancar)
     usp_log_end   : actualiza esa fila a SUCCESS o FAILED (al terminar)

   La correlacion se hace por run_id (el RunId unico de cada corrida de ADF).
   Tabla destino: dw.etl_log (ya creada previamente).

   Ejecutar en la base de datos: ventas_dw
   ============================================================================ */

------------------------------------------------------------------------------
-- 1. usp_log_start : marca el inicio de una corrida
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_log_start
    @run_id        VARCHAR(100),
    @pipeline_name VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dw.etl_log (run_id, pipeline_name, started_at, status)
    VALUES (@run_id, @pipeline_name, SYSUTCDATETIME(), 'STARTED');
END;
GO

------------------------------------------------------------------------------
-- 2. usp_log_end : cierra la corrida (SUCCESS o FAILED)
--    Actualiza la fila STARTED que coincide con el run_id.
------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dw.usp_log_end
    @run_id      VARCHAR(100),
    @status      VARCHAR(20),
    @rows_copied INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dw.etl_log
    SET finished_at = SYSUTCDATETIME(),
        status      = @status,
        rows_copied = @rows_copied
    WHERE run_id = @run_id
      AND status = 'STARTED';
END;
GO

------------------------------------------------------------------------------
-- 3. Verificacion (despues de correr el pipeline desde ADF)
------------------------------------------------------------------------------
SELECT log_id, run_id, pipeline_name, started_at, finished_at, status, rows_copied
FROM dw.etl_log
ORDER BY log_id DESC;
GO
