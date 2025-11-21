SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- 2018-01-01 created ===============================================
-- Author   : KHLim
-- Date       Author   Ver Purpose
-- ==================================================================
CREATE PROC  [dbo].[ispLogError]
   @ErrDb        NVARCHAR(128) = ''
  ,@ErrSchema    NVARCHAR(128) = ''
  ,@ErrProc      NVARCHAR(128) = ''
  ,@SourceKey    INT           = 0
  ,@ErrMsg       NVARCHAR(1024)= '' OUTPUT
  ,@ErrNo        INT           = 0  OUTPUT
  ,@Success      INT           = 0  OUTPUT
  ,@ErrSeverity  TINYINT       = 0  OUTPUT
  ,@ErrState     TINYINT       = 0  OUTPUT
  ,@SourceTable  NVARCHAR(128) = ''
AS    
BEGIN    
   SET NOCOUNT ON       ;   SET ANSI_NULLS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;

   DECLARE @ErrLine INT
   SET     @ErrLine         =      ISNULL(ERROR_LINE()    ,0)

   SELECT  @SourceKey       =      ISNULL(@SourceKey     ,0)
          ,@ErrMsg          = LEFT(ISNULL(ERROR_MESSAGE(),''),1024)
          ,@ErrNo           =      ISNULL(ERROR_NUMBER()  ,0)
          ,@ErrSeverity     =      ISNULL(ERROR_SEVERITY(),0)
          ,@ErrState        =      ISNULL(ERROR_STATE()   ,0)

   IF @Success     > 0      SET @Success   = 0
   IF @ErrDb       IS NULL  SET @ErrDb     = ''
   IF @ErrSchema   IS NULL  SET @ErrSchema = ''
IF ISNULL(@ErrProc,'') = '' SET @ErrProc   = ERROR_PROCEDURE() -- if '' or NULL, try get from ERROR_PROCEDURE
   IF @ErrProc     IS NULL  SET @ErrProc   = ''                -- if still NULL, then set to '' only
   IF @SourceTable IS NULL  SET @SourceTable=''
   IF @SourceTable = ''
      IF      @ErrDb = 'CustPortal'   SET @SourceTable = 'WSLog'
      ELSE IF @ErrDb LIKE '%DATAMART' SET @SourceTable = 'DATA_EXTRACTION_HISTORY'

   IF @ErrNo     <> 0
      INSERT INTO dbo.LogError ( ErrDb, ErrSchema, ErrProc, ErrLine, ErrMsg, ErrNo, ErrSeverity, ErrState, Success, SourceKey, SourceTable)
                       VALUES  (@ErrDb,@ErrSchema,@ErrProc,@ErrLine,@ErrMsg,@ErrNo,@ErrSeverity,@ErrState,@Success,@SourceKey,@SourceTable)
END

GO