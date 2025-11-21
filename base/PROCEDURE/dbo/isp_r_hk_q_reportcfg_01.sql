SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_q_reportcfg_01                             */
/* Creation Date: 04-Nov-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Checking Report Configure                                    */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_q_reportcfg_01              */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_q_reportcfg_01] (
       @as_storerkey       NVARCHAR(15)  = ''
     , @as_rpt_id          NVARCHAR(8)   = ''
     , @as_datawindow      NVARCHAR(250) = ''
     , @as_code            NVARCHAR(30)  = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TEMP_REPORTCFG') IS NOT NULL
      DROP TABLE #TEMP_REPORTCFG
   
   DECLARE @c_Storerkey    NVARCHAR(15)
         , @c_Long         NVARCHAR(250)
         , @c_Code         NVARCHAR(30)
         , @c_Code2        NVARCHAR(30)
         , @c_Short        NVARCHAR(10)
         , @c_Description  NVARCHAR(250)
         , @c_Notes        NVARCHAR(4000)
         , @c_Notes2       NVARCHAR(4000)
         , @c_UDF01        NVARCHAR(60)
         , @c_UDF02        NVARCHAR(60)
         , @c_UDF03        NVARCHAR(60)
   
   CREATE TABLE #TEMP_REPORTCFG (
      Long         NVARCHAR(250)  NULL
    , Storerkey    NVARCHAR(15)   NULL
    , Code         NVARCHAR(30)   NULL
    , Short        NVARCHAR(10)   NULL
    , SeqNo        INT            NULL
    , Notes        NVARCHAR(4000) NULL
    , Notes2       NVARCHAR(4000) NULL
    , UDF01        NVARCHAR(60)   NULL
    , UDF02        NVARCHAR(60)   NULL
    , UDF03        NVARCHAR(60)   NULL
    , Code2        NVARCHAR(30)   NULL
    , Description  NVARCHAR(250)  NULL
   )
   DECLARE C_REPORTCFG CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(RC.Long),'')
        , ISNULL(RTRIM(RC.Storerkey),'')
        , ISNULL(RTRIM(RC.Code),'')
        , ISNULL(RTRIM(RC.Code2),'')
        , ISNULL(RTRIM(RC.Short),'')
        , ISNULL(RTRIM(RC.Description),'')
        , ISNULL(RTRIM(RC.Notes),'')
        , ISNULL(RTRIM(RC.Notes2),'')
        , ISNULL(RTRIM(RC.UDF01),'')
        , ISNULL(RTRIM(RC.UDF02),'')
        , ISNULL(RTRIM(RC.UDF03),'')
   FROM dbo.CODELKUP RC (NOLOCK)
   WHERE RC.ListName='REPORTCFG'
     AND RC.Long LIKE 'r_hk%'
	 AND (ISNULL(@as_storerkey ,'')='' OR RC.Storerkey = @as_storerkey  )
     AND (ISNULL(@as_rpt_id    ,'')='' OR EXISTS(SELECT TOP 1 1 FROM dbo.pbsrpt_reports (NOLOCK) WHERE rpt_id = @as_rpt_id AND rpt_datawindow=RC.Long) )
	 AND (ISNULL(@as_datawindow,'')='' OR RC.Long   LIKE @as_datawindow )
	 AND (ISNULL(@as_code      ,'')='' OR RC.Code      = @as_code       )
   ORDER BY Long, Storerkey, Code, Code2
   
   OPEN C_REPORTCFG
   
   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_REPORTCFG
      INTO @c_Long, @c_Storerkey, @c_Code, @c_Code2, @c_Short
         , @c_Description, @c_Notes, @c_Notes2, @c_UDF01, @c_UDF02, @c_UDF03
   
      IF @@FETCH_STATUS<>0
         BREAK
   
      IF @c_Code IN ('MAPFIELD', 'MAPVALUE', 'MAPCODE', 'SHOWFIELD')
      BEGIN
          INSERT INTO #TEMP_REPORTCFG (
                 Long, Storerkey, Code, Code2, Short, Description
               , SeqNo, Notes, Notes2, UDF01, UDF02, UDF03)
          SELECT @c_Long, @c_Storerkey, @c_Code, @c_Code2, @c_Short, @c_Description
               , a.SeqNo, a.ColValue, ISNULL(b.ColValue,''), @c_UDF01, @c_UDF02, @c_UDF03
          FROM      dbo.fnc_DelimSplit(@c_UDF01, @c_Notes ) AS a
          LEFT JOIN dbo.fnc_DelimSplit(@c_UDF01, @c_Notes2) AS b ON a.SeqNo = b.SeqNo
      END
      ELSE
      BEGIN
          INSERT INTO #TEMP_REPORTCFG (
                 Long, Storerkey, Code, Code2, Short, Description
               , SeqNo, Notes, Notes2, UDF01, UDF02, UDF03)
          VALUES(@c_Long, @c_Storerkey, @c_Code, @c_Code2, @c_Short, @c_Description
               , 0, @c_Notes, @c_Notes2, @c_UDF01, @c_UDF02, @c_UDF03)
      END
   END
   
   CLOSE C_REPORTCFG
   DEALLOCATE C_REPORTCFG
   
   SELECT DataWindow  = RC.Long
        , Storerkey   = RC.Storerkey
        , Code        = RC.Code
        , Enabled     = RC.Short
        , SeqNo       = RC.SeqNo
        , MapFrom     = RC.Notes
        , MapTo       = RC.Notes2
        , Delimiter   = RC.UDF01
        , UDF02       = RC.UDF02
        , UDF03       = RC.UDF03
        , Code2       = RC.Code2
        , Description = RC.Description
     FROM #TEMP_REPORTCFG AS RC
    ORDER BY DataWindow, Storerkey, Code, Code2, SeqNo
END

GO