SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_GetRCMReportDW                                      */
/* Creation Date: 2021-12-07                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-18500 - [CN] PB_Packing_Enhancement                     */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-12-07  Wan      1.0   Created.                                  */
/* 2021-12-07  Wan      1.0   DevOps Combine Script.                    */
/* 2022-01-25  Wan01    1.1   Fixed Get RCMUsingUserID config setting   */
/* 2022-02-10  WLChooi  1.2   Fixed Datawindow Name being truncated when*/
/*                            inserting TraceInfo (WL01)                */
/* 2023-03-21  WLChooi  1.3   Fixed Initialize @c_PB_Datawindow to blank*/
/*                            (WL02)                                    */
/* 2023-03-27  WLChooi  1.4   Bug Fix - Extend Length (WL03)            */
/************************************************************************/
CREATE   PROC [dbo].[isp_GetRCMReportDW]
           @c_ShortAppName          NVARCHAR(30)
         , @c_ComputerName          NVARCHAR(30)
         , @c_Storerkey             NVARCHAR(15)
         , @c_ReportType            NVARCHAR(10)
         , @n_SetupIsRequired       INT          = 1
         , @c_PB_Datawindow         NVARCHAR(40) = '' OUTPUT
         , @c_Rpt_Printer           NVARCHAR(100)= '' OUTPUT
         , @c_ExtendParmName1       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName2       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName3       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName4       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName5       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName6       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName7       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName8       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName9       NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmName10      NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault1    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault2    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault3    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault4    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault5    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault6    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault7    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault8    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault9    NVARCHAR(30) = '' OUTPUT
         , @c_ExtendParmDefault10   NVARCHAR(30) = '' OUTPUT
         , @c_AutoPrint             NVARCHAR(10) = '' OUTPUT
         , @c_JReportFlag           NVARCHAR(10) = '' OUTPUT
         , @b_Success               INT          = 1  OUTPUT
         , @n_Err                   INT          = 0  OUTPUT
         , @c_ErrMsg                NVARCHAR(255)= '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
           @n_StartTCnt             INT = @@TRANCOUNT
         , @n_Continue              INT = 1

         , @c_RCMUsingUserID        NVARCHAR(10) = ''
         , @c_WorkStation           NVARCHAR(30) = ''
         , @c_PB_Datawindow_DF      NVARCHAR(40) = @c_PB_Datawindow   --WL03

         , @dt_sysdate              DATETIME     = GETDATE()

         , @c_DW1                   NVARCHAR(20) = ''   --WL01
         , @c_DW2                   NVARCHAR(20) = ''   --WL01

   SET @n_err      = 0
   SET @c_errmsg   = ''

   SET @c_WorkStation = @c_Computername

   SET @c_PB_Datawindow = ''   --WL02

   SELECT @c_RCMUsingUserID = fgr.authority FROM dbo.fnc_GetRight2('', @c_Storerkey, '', 'RCMUsingUserID') AS fgr

   IF @c_RCMUsingUserID = '' --'0'              --(Wan01)
   BEGIN
      SELECT TOP 1 @c_RCMUsingUserID = '1'
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'RCMBYUSER'
      AND Code = @c_ReportType
      AND Storerkey = @c_Storerkey
   END

   IF @c_RCMUsingUserID = '1'
   BEGIN
      SET @c_Computername = SUSER_SNAME()
   END

   SELECT TOP 1
         @c_PB_Datawindow      = rr.PB_Datawindow
      ,  @c_Rpt_Printer        = rr.Rpt_Printer
      ,  @c_ExtendParmName1    = ISNULL(rr.ExtendParmName1,'')
      ,  @c_ExtendParmName2    = ISNULL(rr.ExtendParmName2,'')
      ,  @c_ExtendParmName3    = ISNULL(rr.ExtendParmName3,'')
      ,  @c_ExtendParmName4    = ISNULL(rr.ExtendParmName4,'')
      ,  @c_ExtendParmName5    = ISNULL(rr.ExtendParmName5,'')
      ,  @c_ExtendParmName6    = ISNULL(rr.ExtendParmName6 ,'')
      ,  @c_ExtendParmName7    = ISNULL(rr.ExtendParmName7 ,'')
      ,  @c_ExtendParmName8    = ISNULL(rr.ExtendParmName8 ,'')
      ,  @c_ExtendParmName9    = ISNULL(rr.ExtendParmName9 ,'')
      ,  @c_ExtendParmName10   = ISNULL(rr.ExtendParmName10,'')
      ,  @c_ExtendParmDefault1 = ISNULL(rr.ExtendParmDefault1,'')
      ,  @c_ExtendParmDefault2 = ISNULL(rr.ExtendParmDefault2,'')
      ,  @c_ExtendParmDefault3 = ISNULL(rr.ExtendParmDefault3,'')
      ,  @c_ExtendParmDefault4 = ISNULL(rr.ExtendParmDefault4,'')
      ,  @c_ExtendParmDefault5 = ISNULL(rr.ExtendParmDefault5,'')
      ,  @c_ExtendParmDefault6 = ISNULL(rr.ExtendParmDefault6,'')
      ,  @c_ExtendParmDefault7 = ISNULL(rr.ExtendParmDefault7,'')
      ,  @c_ExtendParmDefault8 = ISNULL(rr.ExtendParmDefault8,'')
      ,  @c_ExtendParmDefault9 = ISNULL(rr.ExtendParmDefault9,'')
      ,  @c_ExtendParmDefault10= ISNULL(rr.ExtendParmDefault10,'')
      ,  @c_AutoPrint          = rr.AutoPrint
      ,  @c_JReportFlag        = ISNULL(rr.JReportFlag,'')
   FROM dbo.RCMReport AS rr WITH (NOLOCK)
   WHERE rr.ComputerName = @c_Computername
   AND rr.StorerKey = @c_Storerkey
   AND rr.ReportType= @c_ReportType

   IF @c_PB_Datawindow = ''
   BEGIN
      SELECT TOP 1
            @c_PB_Datawindow      = rr.PB_Datawindow
         ,  @c_Rpt_Printer        = rr.Rpt_Printer
         ,  @c_ExtendParmName1    = ISNULL(rr.ExtendParmName1,'')
         ,  @c_ExtendParmName2    = ISNULL(rr.ExtendParmName2,'')
         ,  @c_ExtendParmName3    = ISNULL(rr.ExtendParmName3,'')
         ,  @c_ExtendParmName4    = ISNULL(rr.ExtendParmName4,'')
         ,  @c_ExtendParmName5    = ISNULL(rr.ExtendParmName5,'')
         ,  @c_ExtendParmName6    = ISNULL(rr.ExtendParmName6 ,'')
         ,  @c_ExtendParmName7    = ISNULL(rr.ExtendParmName7 ,'')
         ,  @c_ExtendParmName8    = ISNULL(rr.ExtendParmName8 ,'')
         ,  @c_ExtendParmName9    = ISNULL(rr.ExtendParmName9 ,'')
         ,  @c_ExtendParmName10   = ISNULL(rr.ExtendParmName10,'')
         ,  @c_ExtendParmDefault1 = ISNULL(rr.ExtendParmDefault1,'')
         ,  @c_ExtendParmDefault2 = ISNULL(rr.ExtendParmDefault2,'')
         ,  @c_ExtendParmDefault3 = ISNULL(rr.ExtendParmDefault3,'')
         ,  @c_ExtendParmDefault4 = ISNULL(rr.ExtendParmDefault4,'')
         ,  @c_ExtendParmDefault5 = ISNULL(rr.ExtendParmDefault5,'')
         ,  @c_ExtendParmDefault6 = ISNULL(rr.ExtendParmDefault6,'')
         ,  @c_ExtendParmDefault7 = ISNULL(rr.ExtendParmDefault7,'')
         ,  @c_ExtendParmDefault8 = ISNULL(rr.ExtendParmDefault8,'')
         ,  @c_ExtendParmDefault9 = ISNULL(rr.ExtendParmDefault9,'')
         ,  @c_ExtendParmDefault10= ISNULL(rr.ExtendParmDefault10,'')
         ,  @c_AutoPrint          = rr.AutoPrint
         ,  @c_JReportFlag        = ISNULL(rr.JReportFlag,'')
      FROM dbo.RCMReport AS rr WITH (NOLOCK)
      WHERE rr.ComputerName = @c_ShortAppName
      AND rr.StorerKey = @c_Storerkey
      AND rr.ReportType= @c_ReportType
   END

   IF @c_PB_Datawindow = '' AND @c_PB_Datawindow_DF <> ''
   BEGIN
      SET @c_PB_Datawindow = @c_PB_Datawindow_DF
   END

   IF @n_SetupIsRequired = 1 AND @c_PB_Datawindow = ''
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68910
      SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': RCM Report Type ('''+ @c_ReportType + ''') Not Found.'
   END

   IF @c_JReportFlag = 'JREPORT' AND @c_PB_Datawindow <> ''
   BEGIN
      SET @c_PB_Datawindow = ''
   END

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT > 0
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetRCMReportDW'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > 0
      BEGIN
         COMMIT TRAN
      END
   END

   --WL01 S
   SET @c_DW1 = SUBSTRING(@c_PB_Datawindow, 1, 20)

   IF LEN(TRIM(@c_PB_Datawindow)) > 20
      SET @c_DW2 = SUBSTRING(@c_PB_Datawindow, 21, 20)
   --WL01 E

   EXEC dbo.isp_InsertTraceInfo
         @c_TraceCode = N'RCMREPORT4WM'
       , @c_TraceName = N'RCMREPORT4WM'
       , @c_StartTime = @dt_sysdate
       , @c_EndTime   = @dt_sysdate
       , @c_Step1 = @c_Computername
       , @c_Step2 = @c_Storerkey
       , @c_Step3 = @c_ReportType
       , @c_Step4 = @c_JReportFlag
       , @c_Step5 = N''
       , @c_Col1  = @c_DW1   --WL01
       , @c_Col2  = @c_DW2   --WL01
       , @c_Col3  = N''
       , @c_Col4  = N''
       , @c_Col5  = N''
       , @b_Success = @b_Success
       , @n_Err     = @n_Err
       , @c_ErrMsg  = @c_ErrMsg

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO