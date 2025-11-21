SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
-- 2018-01-01 created ===============================================
-- Author   : KHLim
-- Date       Author   Ver Purpose
-- ==================================================================
CREATE PROC  [dbo].[ispLogQuery]
   @SQLDb        NVARCHAR(128) = ''
  ,@SQLSchema    NVARCHAR(128) = ''
  ,@SQLProc      NVARCHAR(128) = ''
  ,@SourceKey    INT           = 0
  ,@SQLText      NVARCHAR(MAX) = ''
  ,@Duration     INT           = 0
  ,@RowCnt       INT           = 0
  ,@SourceTable  NVARCHAR(128) = ''
  ,@SQLId        INT      OUTPUT
AS    
BEGIN    
   SET NOCOUNT ON       ;   SET ANSI_NULLS OFF  ;   SET QUOTED_IDENTIFIER OFF;   SET CONCAT_NULL_YIELDS_NULL OFF;

      IF OBJECT_ID('tempdb..#tId','u') IS NOT NULL
         DROP TABLE #tId;
      CREATE  TABLE #tId (Id INT) 

   IF @SQLDb       IS NULL  SET @SQLDb     = ''
   IF @SQLSchema   IS NULL  SET @SQLSchema = ''
   IF @SQLProc     IS NULL  SET @SQLProc   = ''
   SELECT  @SourceKey        =     ISNULL(@SourceKey     ,0)
   IF @SourceTable IS NULL  SET @SourceTable=''
   IF @SourceTable = ''
      IF      @SQLDb = 'CustPortal'   SET @SourceTable = 'WSLog'
      ELSE IF @SQLDb LIKE '%DATAMART' SET @SourceTable = 'DATA_EXTRACTION_HISTORY'

   IF ISNULL(@SQLText,'') <> ''
   BEGIN
      INSERT INTO dbo.LogSQL ( SQLDb, SQLSchema, SQLProc, SQLText, Duration, SourceKey, RowCnt, SourceTable) OUTPUT INSERTED.SQLId INTO #tId
                      VALUES (@SQLDb,@SQLSchema,@SQLProc,@SQLText,@Duration,@SourceKey,@RowCnt,@SourceTable)
      
      SELECT @SQLId = Id FROM #tId
   END
END

GO