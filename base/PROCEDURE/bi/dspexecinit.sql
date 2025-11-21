SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Purpos: Initiate ExecutionLog to trace processing details of each query */
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 23-May-2022  KHLim      1.0 https://jiralfl.atlassian.net/browse/CT-327 */
/***************************************************************************/

CREATE PROC [BI].[dspExecInit]
    @ClientId NVARCHAR(50)
  , @Proc     NVARCHAR(128)
  , @ParamIn  NVARCHAR(4000) = ''
  , @LogId    INT           OUTPUT
  , @Debug    BIT           OUTPUT
  , @Schema   NVARCHAR(128)  = ''
AS
BEGIN
   SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

   IF ISNULL(@Schema,'') = '' SET @Schema = ISNULL(object_schema_name(@@procid),'')

   DECLARE @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, Sch, SP, ParamIn) OUTPUT INSERTED.LogId 
      INTO @tVarLogId VALUES (ISNULL(@ClientId,''), @Schema, @Proc, @ParamIn);

   SELECT TOP 1 @LogId = LogId FROM @tVarLogId

   IF OBJECT_ID('dbo.ExecDebug','u') IS NOT NULL
   BEGIN
      SELECT @Debug = Debug
      FROM dbo.ExecDebug WITH (NOLOCK)
      WHERE UserName = SUSER_SNAME()
   END

END

GO