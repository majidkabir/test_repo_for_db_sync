SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Purpos: Execute dynamic SQL statement and log the execution details     */
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 23-May-2022  KHLim      1.0 https://jiralfl.atlassian.net/browse/CT-327 */
/***************************************************************************/

CREATE   PROC [BI].[dspExecStmt]
    @Stmt    NVARCHAR(MAX)
  , @LinkSrv NVARCHAR(128) = ''
  , @LogId   INT
  , @Debug   BIT
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;
        
   DECLARE @RowCnt  INT = 0
         , @ParamOut NVARCHAR(4000)= ''
         , @Err     INT = 0
         , @ErrMsg  NVARCHAR(250)  = ''

   IF ISNULL(@LinkSrv,'')<>'' 
      AND EXISTS (SELECT 1 FROM sys.servers WHERE server_id > 0 AND [name] = @LinkSrv) 
   BEGIN
      SET @Stmt = CONCAT('EXEC(N''', REPLACE(@Stmt,'''',''''''), ''') AT ', @LinkSrv)
   END

   IF @Debug = 1
   BEGIN
      PRINT @Stmt
      PRINT SUBSTRING(@Stmt, 4001, 8000)
      PRINT SUBSTRING(@Stmt, 8001,12000)
      PRINT SUBSTRING(@Stmt,12001,16000)
      PRINT SUBSTRING(@Stmt,16001,20000)
   END

   BEGIN TRY
      EXEC sp_ExecuteSql @Stmt;
      SELECT @RowCnt = @@ROWCOUNT;
   END TRY
   BEGIN CATCH
      SELECT @Err = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE();
   END CATCH

   IF @Err > 0
   BEGIN
      SET @RowCnt = 0
   END

   SET @ParamOut = CONCAT('{ "Stmt": "', LEFT(@Stmt,3985)+CASE WHEN LEN(@Stmt)>3985 THEN '…' ELSE '' END, '" }');

   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @RowCnt, ParamOut = @ParamOut
   , ErrNo = @Err
   , ErrMsg = @ErrMsg
   WHERE LogId = @LogId;
   
   IF @Err > 0
   BEGIN
      SET @Err = @Err + 50000; --   Because error_number in THROW syntax must be >= 50000
      THROW @Err, @ErrMsg, 1;  -- THROW [ { error_number }, { exception_message }, { state } ]
   END

END -- Procedure 

GO