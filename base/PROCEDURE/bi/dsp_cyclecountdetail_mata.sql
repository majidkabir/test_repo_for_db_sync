SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************************/
/* Title: TH-Michelin_Cycle-Count_Dashboard https://jiralfl.atlassian.net/browse/BI-220 */
/* Date		      Author			Ver		Purposes                                      */
/* 27/OCT/2021    gywong         1.0      Created                                       */
/*****************************************************************************************/
CREATE PROC [BI].[dsp_CycleCountDetail_MATA]
AS
BEGIN                            
SET NOCOUNT ON;                           
SET ANSI_NULLS OFF;                              
SET QUOTED_IDENTIFIER OFF;                            
SET CONCAT_NULL_YIELDS_NULL OFF;            

DECLARE @PARAM_StorerKey  NVARCHAR(15) = '' --'MATA'

   DECLARE @Debug BIT = 0, @LogId   INT
         , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
         , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
         , @cParamOut NVARCHAR(4000)= ''
         , @cParamIn  NVARCHAR(4000)= ''

   EXEC BI.dspExecInit @ClientId = @PARAM_StorerKey
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

   SET @Stmt = CONCAT(@Stmt , N'select dateadd(hh,-1,GETDATE()) as Date
      ,CCKEY,RefNo as Team
      ,CCSheetNo,Status
      ,COUNT(distinct(Loc)) Total_Location
      ,SUM(QTY) CountQTY
      ,SUM(systemQTY) systemQTY
      ,SUM(systemQTY)-sum(QTY) Diff_Count3
      ,(Case when status=''0'' then ''Count 2 Not count''
             WHEN status=''4'' then ''Count 2 Completed (Diff)''
             WHEN status=''2'' and sum(systemQTY)-sum(QTY)<>''0'' then ''Count 2 Completed (Diff)''
       ELSE ''Count 2 Completed (No Diff)'' end) as CountStatus
       ,(Case when Left(CCKEY,2)=''CS'' then ''Casing''
       ELSE ''Finish Goods''end) as Group_FG_CS
FROM dbo.ccdetail cc WITH (NOLOCK)
WHERE EXISTS (SELECT 1 FROM dbo.CODELKUP WITH (NOLOCK) WHERE listname=''CCKey4DB''
AND STORERKEY = cc.STORERKEY AND code2 = cc.CCKey )
GROUP by CCKEY
        ,CCSheetNo
        ,status
        ,QTY,systemQTY
        ,RefNo
');

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END -- Procedure

GO