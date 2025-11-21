SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_UnPickMoveLog_Rpt                               */  
/* Creation Date: 07-DEC-2012                                            */  
/* Copyright: LF                                                         */  
/* Written by: YTWan                                                     */  
/*                                                                       */  
/* Purpose: SOS#249056: FNPC Mass Unpick/Pack - UnpickMoveLog report     */  
/*                                                                       */  
/* Called By: Call from UnPickPack Order & UCC- RCM Prit UnPickMoveLog   */
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author   Ver  Purposes                                   */ 
/* 18-Jan-2013  Adrian   1.1  Fixed retrieve multiplying records. (A01)  */
/*************************************************************************/  

CREATE PROC [dbo].[isp_UnPickMoveLog_Rpt] 
      @c_UnPickMoveKeys  NVARCHAR(4000)
AS  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @c_ExecStatement   NVARCHAR(4000)
         , @c_ExecArgument    NVARCHAR(4000)

   SET @c_ExecStatement = ''
   SET @c_ExecArgument  = ''

   CREATE TABLE #TMP_UPKMOVLOG (
         UnpickMoveKey   NVARCHAR(10) NOT NULL   DEFAULT ('') )

   SET @c_ExecStatement = N' INSERT INTO #TMP_UPKMOVLOG ( UnpickMoveKey )' 
--                        +  ' SELECT UnpickMoveKey'                           --(A01) 
                        +  ' SELECT DISTINCT UnpickMoveKey'                    --(A01)
                        +  ' FROM UNPICKMOVELOG WITH (NOLOCK)'
                        +  ' WHERE UnpickMoveKey IN ( ' + @c_UnPickMoveKeys + ')'
   EXEC (@c_ExecStatement) 

   SELECT UnpickMoveLog.UnpickMoveKey
	      ,UnpickMoveLog.MBOLKey   
         ,UnpickMoveLog.ExternMBOLKey   
         ,UnpickMoveLog.LoadKey   
         ,UnpickMoveLog.ConsoOrderKey   
         ,UnpickMoveLog.OrderKey   
         ,UnpickMoveLog.UnpickpackLoc   
         ,UnpickMoveLog.Storerkey   
         ,UnpickMoveLog.Sku  
         ,UnpickMoveLog.Loc  
         ,Qty = SUM(UnpickMoveLog.Qty)
         ,UCC = CASE WHEN ISNULL(RTRIM(UnpickMoveLog.CaseID),'') <> '' THEN UnpickMoveLog.CaseID ELSE UnpickMoveLog.DropID END
    FROM #TMP_UPKMOVLOG TMP
    JOIN UnpickMoveLog WITH (NOLOCK) ON (TMP.UnpickMoveKey = UnpickMoveLog.UnpickMoveKey)
    GROUP BY UnpickMoveLog.UnpickMoveKey
	         ,UnpickMoveLog.MBOLKey   
            ,UnpickMoveLog.ExternMBOLKey   
            ,UnpickMoveLog.LoadKey   
            ,UnpickMoveLog.ConsoOrderKey   
            ,UnpickMoveLog.OrderKey   
            ,UnpickMoveLog.UnpickpackLoc   
            ,UnpickMoveLog.Storerkey   
            ,UnpickMoveLog.Sku  
            ,UnpickMoveLog.Loc
            ,CASE WHEN ISNULL(RTRIM(UnpickMoveLog.CaseID),'') <> '' THEN UnpickMoveLog.CaseID ELSE UnpickMoveLog.DropID END  

   DROP TABLE #TMP_UPKMOVLOG
END

GO