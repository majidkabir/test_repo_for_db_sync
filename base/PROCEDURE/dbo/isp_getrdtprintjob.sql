SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetRDTPrintJob                                      */
/* Creation Date: 01-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By: d_dw_print_job_search (TCPSpooler & RDTPRint.exe)         */
/*          :                                                           */
/* PVCS Version: 1.3                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2019-07-22  Wan01    1.1   Fixed.                                    */
/* 2019-02-25  Wan02    1.2   WM - Printing: Add Parm11 - Parm20,Printdata*/
/* 2019-11-18  Wan03    1.2   WM - Printing: Return IsViewReport        */
/* 2022-01-11  Wan04    1.3   WM - Printing: Return RptTextConvByINI    */
/*                            LFWM-3342 - CN NIKECN TCPSpooler Language */
/*                            Conversion for POD Report Printing        */
/* 2022-01-11  Wan04    1.3   DevOps Combined Script                    */
/************************************************************************/
CREATE PROC [dbo].[isp_GetRDTPrintJob]
            @n_JobID              BIGINT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT            = 1
         , @n_Err             INT            = 0
         , @c_ErrMsg          NVARCHAR(255)  = ''

         , @n_Function_ID     INT            = 0
         , @c_ReportID        NVARCHAR(10)   = ''
         , @c_Datawindow      NVARCHAR(50)   = ''
         , @c_Loadkey         NVARCHAR(10)   = ''
         , @c_Storerkey       NVARCHAR(15)   = ''
         
   DECLARE @t_REPORTCFG       TABLE ( RowID     INT          NOT NULL IDENTITY(1,1) PRIMARY KEY
                                    , Code      NVARCHAR(30) NOT NULL DEFAULT('')
                                    , Long      NVARCHAR(100)NOT NULL DEFAULT('')
                                    , Short     NVARCHAR(10) NOT NULL DEFAULT('N')
                                    , Storerkey NVARCHAR(15) NOT NULL DEFAULT('')
                                    , UDF01     NVARCHAR(30) NOT NULL DEFAULT('')
                                    , UDF02     NVARCHAR(30) NOT NULL DEFAULT('')                                    
                                    )      

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END 

   --(Wan04) - START
   --Group by to prevent Multi RPTTEXTCONVBYINI setup by same datawindow & storerkey 
   INSERT INTO @t_REPORTCFG
       (
           Code,
           Long,
           Short,
           Storerkey,
           UDF01,
           UDF02
       )
   SELECT c.Code
      ,  c.Long
      ,  Short = ISNULL(MAX(c.Short),'N')
      ,  c.Storerkey
      ,  c.UDF01
      ,  c.UDF02
   FROM dbo.CODELKUP AS c WITH (NOLOCK)
   WHERE c.LISTNAME = 'REPORTCFG'
   AND c.Code = 'RptTextConvByINI'
   GROUP BY c.Code
         ,  c.Long
         ,  c.Storerkey
         ,  c.UDF01
         ,  c.UDF02
   --(Wan04) - END
   
   
   SELECT TOP 1 @c_ReportID  = P.ReportID
            ,   @c_Datawindow= P.Datawindow
            ,   @c_Loadkey   = P.Parm1
            ,   @c_Storerkey = P.Storerkey
            ,   @n_Function_ID = P.Function_ID
   FROM RDT.RDTPRINTJOB P WITH (NOLOCK)  
   WHERE P.JobStatus NOT IN ('9','E')           --(Wan01) 
   AND   P.JobId = @n_JobID 

   IF @c_ReportID = "SSCCLABEL" 
   BEGIN
      SET @c_Storerkey = ''
      IF @c_Datawindow = 'r_dw_sscc_cartonlabel_05'
      BEGIN
         SELECT TOP 1 @c_Storerkey = O.Storerkey
         FROM ORDERS O WITH (NOLOCK)
         WHERE O.Loadkey= @c_Loadkey
      END
   END

   IF @c_Storerkey = ''
   BEGIN
      SELECT @c_Storerkey = R.Storerkey
      FROM RDT.RDTREPORT R WITH (NOLOCK)
      WHERE R.ReportType= @c_ReportID
      AND R.DataWindow  = @c_Datawindow
      AND R.Function_ID = @n_Function_ID
   END      

   SELECT RDT.RDTPrintJob.JobId   
         ,RDT.RDTPrintJob.JobName   
         ,RDT.RDTPrintJob.ReportID   
         ,RDT.RDTPrintJob.JobStatus   
         ,RDT.RDTPrintJob.NextRun   
         ,RDT.RDTPrintJob.LastRun   
         ,RDT.RDTPrintJob.Datawindow   
         ,RDT.RDTPrintJob.Parm1   
         ,RDT.RDTPrintJob.Parm2   
         ,RDT.RDTPrintJob.Parm3   
         ,RDT.RDTPrintJob.Parm4   
         ,RDT.RDTPrintJob.Parm5   
         ,RDT.RDTPrintJob.Parm6   
         ,RDT.RDTPrintJob.Parm7   
         ,RDT.RDTPrintJob.Parm8   
         ,RDT.RDTPrintJob.Parm9   
         ,RDT.RDTPrintJob.Parm10   
         ,RDT.RDTPrintJob.AddDate   
         ,RDT.RDTPrintJob.AddWho   
         ,RDT.RDTPrintJob.Printer 
         ,RDT.RDTPrintJob.NoOfParms   
         ,RDT.RDTPrintJob.Mobile  
         ,RDT.RDTPrintJob.NoOfCopy  
         ,RDT.RDTPrintJob.TargetDB 
         ,RDT.RDTPrinter.Description
         ,ErrorMsg = SPACE(60) 
         ,RDT.RDTPrintJob.ExportFileName
         ,Storerkey = @c_Storerkey
         ,RDT.RDTPrinter.WinPrinter 
         ,RDT.RDTPrintJob.PrintData  
         ,RDT.RDTPrintJob.Parm11   
         ,RDT.RDTPrintJob.Parm12   
         ,RDT.RDTPrintJob.Parm13   
         ,RDT.RDTPrintJob.Parm14   
         ,RDT.RDTPrintJob.Parm15   
         ,RDT.RDTPrintJob.Parm16   
         ,RDT.RDTPrintJob.Parm17   
         ,RDT.RDTPrintJob.Parm18   
         ,RDT.RDTPrintJob.Parm19   
         ,RDT.RDTPrintJob.Parm20                                                    
         ,IsViewReport = CASE WHEN VR.Rpt_ID IS NULL THEN 'N' ELSE 'Y' END          --(Wan03)
         ,Rpt_Title   = ISNULL(RTRIM(VR.Rpt_Title),'')                              --(Wan03)
         ,HeaderFlag  = ISNULL(RTRIM(VR.HeaderFlag),'N')                            --(Wan03)
         ,FooterFlag  = ISNULL(RTRIM(VR.FooterFlag),'N')                            --(Wan03)
         ,PreparedBy  = RDT.RDTPrintJob.AddWho                                      --(Wan03)
         ,RptTextConvByINI = ISNULL(tr.Short,'N')                                   --(Wan04)
         ,LanguageFile = ISNULL(tr.UDF01,'')                                        --(Wan04) 
         ,[Language]   = ISNULL(tr.UDF02,'')                                        --(Wan04)                                                                                      --        
   FROM RDT.RDTPrintJob (NOLOCK)  
   JOIN RDT.RDTPrinter (NOLOCK) ON RDT.RDTPrinter.PrinterID = RDT.RDTPrintJob.Printer 
   LEFT JOIN PBSRPT_REPORTS VR (NOLOCK) ON RDT.RDTPrintJob.ReportID = VR.Rpt_Id     --(Wan03)
   LEFT JOIN @t_REPORTCFG AS tr ON tr.Long = RDT.RDTPrintJob.Datawindow             --(Wan04)
                                AND tr.Storerkey = RDT.RDTPrintJob.StorerKey        --(Wan04)
   WHERE JobStatus NOT IN ('9','E')             --(Wan01)  
   AND   RDT.RDTPrintJob.JobId = @n_JobID 


   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END 

QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetRDTPrintJob'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO