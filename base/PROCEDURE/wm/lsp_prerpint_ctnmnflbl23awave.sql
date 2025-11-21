SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_PreRpint_CtnMnfLbl23aWave                       */  
/* Creation Date: 2023-04-20                                             */  
/* Copyright: Maersk                                                     */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-4010 - [CN] - PVHSZ Wave report print issue             */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2023-04-20  Wan      1.0   Created.                                   */
/* 2023-04-20  Wan      1.0   DevOps Script Combine                      */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_PreRpint_CtnMnfLbl23aWave]  
    @n_WMReportRowID BIGINT 
   ,@c_Parm1         NVARCHAR(60)      OUTPUT   
   ,@c_Parm2         NVARCHAR(60)      OUTPUT   
   ,@c_Parm3         NVARCHAR(60)      OUTPUT   
   ,@c_Parm4         NVARCHAR(60)      OUTPUT   
   ,@c_Parm5         NVARCHAR(60)      OUTPUT   
   ,@c_Parm6         NVARCHAR(60)      OUTPUT   
   ,@c_Parm7         NVARCHAR(60)      OUTPUT   
   ,@c_Parm8         NVARCHAR(60)      OUTPUT   
   ,@c_Parm9         NVARCHAR(60)      OUTPUT   
   ,@c_Parm10        NVARCHAR(60)      OUTPUT   
   ,@c_Parm11        NVARCHAR(60)      OUTPUT   
   ,@c_Parm12        NVARCHAR(60)      OUTPUT   
   ,@c_Parm13        NVARCHAR(60)      OUTPUT   
   ,@c_Parm14        NVARCHAR(60)      OUTPUT   
   ,@c_Parm15        NVARCHAR(60)      OUTPUT   
   ,@c_Parm16        NVARCHAR(60)      OUTPUT   
   ,@c_Parm17        NVARCHAR(60)      OUTPUT   
   ,@c_Parm18        NVARCHAR(60)      OUTPUT   
   ,@c_Parm19        NVARCHAR(60)      OUTPUT   
   ,@c_Parm20        NVARCHAR(60)      OUTPUT 
   ,@n_Noofparms     INT               OUTPUT   
   ,@b_ContinuePrint BIT               OUTPUT   
   ,@n_NoOfCopy      INT               OUTPUT   
   ,@c_PrinterID     NVARCHAR(30)      OUTPUT   
   ,@c_PrintData     NVARCHAR(4000)    OUTPUT 
   ,@b_Success       INT               OUTPUT 
   ,@n_Err           INT               OUTPUT 
   ,@c_ErrMsg        NVARCHAR(255)     OUTPUT 
   ,@c_UserName      NVARCHAR(30) =  ''
   ,@c_PrintSource   NVARCHAR(10) = 'WMReport' 
   ,@b_SCEPreView    INT          = 0     
   ,@n_JobID         INT          = 0  OUTPUT 
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT 
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_Facility        NVARCHAR(5)  = ''         
         , @c_ReportID        NVARCHAR(10) = ''
         , @c_ReportLineNo    NVARCHAR(5)  = '' 
         , @c_ReportTemplate  NVARCHAR(200)= '' 
         , @c_PrintType       NVARCHAR(30) = ''  
         , @c_PickSlipNo      NVARCHAR(10) = ''
         , @c_CartonNo        NVARCHAR(5)  = '' 
                 
         , @CUR_BatPrt     CURSOR 
   
   DECLARE @t_PrtJob       TABLE  
         (  JobID          INT            NOT NULL DEFAULT (0)
         ,  ReportID       NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  ReportLineNo   NVARCHAR(5)    NOT NULL DEFAULT ('')
         ,  ReportTemplate NVARCHAR(200)  NOT NULL DEFAULT ('')
         ,  PrintType      NVARCHAR(30)   NOT NULL DEFAULT ('')
         )      
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 

   IF @c_UserName = '' SET @c_UserName = SUSER_SNAME()

   IF SUSER_SNAME() <> @c_UserName 
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END

   --IF @b_SCEPreView = 1
   --BEGIN
   -- SET @n_Continue = 3
   -- SET @n_Err = 561601
   -- SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
   --               + ': Unable to preview Batch Print Report. (lsp_PreRpint_CtnMnfLbl23aWave)'
   -- GOTO EXIT_SP
   --END
   
   BEGIN TRAN

   BEGIN TRY 
      --INSERT Record to RDT.RDTPRINTJOB for process templated - datawindow  
      INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms
                                 , Parm1, Parm2, Parm3, Parm4, Parm5, Parm6, Parm7, Parm8, Parm9, Parm10
                                 , Parm11, Parm12, Parm13, Parm14, Parm15, Parm16, Parm17, Parm18, Parm19, Parm20                      
                                 , ReportLineNo                                                                                        
                                 , Printer, NoOfCopy, Mobile, TargetDB, PrintData, JobType, Storerkey, Function_ID
                                 , PDFPreview                                                                                         
      ) OUTPUT INSERTED.JobID, INSERTED.ReportID, INSERTED.ReportLineNo, INSERTED.Datawindow, INSERTED.JobType
        INTO @t_PrtJob
      SELECT 'PRINT_' + w.ReportID, w.ReportID, '9', w.ReportTemplate, @n_Noofparms
            ,@c_Parm1, @c_Parm2, @c_Parm3, @c_Parm4, @c_Parm5, @c_Parm6, @c_Parm7, @c_Parm8, @c_Parm9, @c_Parm10
            ,@c_Parm11, @c_Parm12, @c_Parm13, @c_Parm14, @c_Parm15, @c_Parm16, @c_Parm17, @c_Parm18, @c_Parm19, @c_Parm20    
            ,w.ReportLineNo                                                                                                           
            ,@c_PrinterId, @n_Noofcopy, 0, DB_NAME()
            ,@c_PrintData, w.PrintType, w.Storerkey, 999
            ,CASE WHEN @b_SCEPreView = 0 THEN 'N' ELSE 'Y' END
      FROM dbo.WMREPORTDETAIL AS w WITH (NOLOCK)
      WHERE w.RowID  = @n_WMReportRowID
      
      SELECT @n_JobID = tpj.JobID
           , @c_ReportID = tpj.ReportID
           , @c_ReportLineNo = tpj.ReportLineNo
           , @c_ReportTemplate = tpj.ReportTemplate
           , @c_PrintType = tpj.PrintType
      FROM @t_PrtJob AS tpj 
   
      EXEC [dbo].[isp_UpdateRDTPrintJobStatus]                
          @n_JobID      = @n_JobID                
         ,@c_JobStatus  = '9'                
         ,@c_JobErrMsg  = ''                
         ,@b_Success    = @b_Success   OUTPUT                
         ,@n_Err        = @n_Err       OUTPUT                
         ,@c_ErrMsg     = @c_ErrMsg    OUTPUT  
                
      WHILE @@ROWCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END 
    
      SET @CUR_BatPrt = CURSOR FAST_FORWARD LOCAL READ_ONLY FOR
      SELECT o.Storerkey
            ,o.Facility   
            ,ph.PickSlipNo
            ,cartonno = CONVERT(NVARCHAR(5),pd.cartonno)
      FROM dbo.WAVEDETAIL AS w WITH (NOLOCK)        
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON w.OrderKey = o.orderkey
      JOIN dbo.PackHeader AS ph WITH (NOLOCK) ON ph.Loadkey = o.loadkey AND ph.Loadkey <> ''     
      JOIN dbo.PackDetail AS pd  WITH (NOLOCK) ON PD.PickSlipNo = PH.pickslipno        
      WHERE w.WaveKey = @c_Parm1       
      GROUP BY o.Storerkey ,o.Facility, ph.PickSlipNo, pd.cartonno       
      ORDER BY ph.PickSlipNo, pd.cartonno 
      
      OPEN @CUR_BatPrt  

      FETCH NEXT FROM @CUR_BatPrt INTO @c_Storerkey, @c_Facility, @c_PickSlipNo, @c_CartonNo
      
      WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
      BEGIN
         EXEC [WM].[lsp_WM_SendPrintJobToProcessApp] 
                  @c_ReportID       = @c_ReportID      
               ,  @c_ReportLineNo   = @c_ReportLineNo  
               ,  @c_Storerkey      = @c_Storerkey     
               ,  @c_Facility       = @c_Facility      
               ,  @n_NoOfParms      = 3     
               ,  @c_Parm1          = @c_PickSlipNo       
               ,  @c_Parm2          = @c_CartonNo       
               ,  @c_Parm3          = @c_CartonNo       
               ,  @c_Parm4          = ''       
               ,  @c_Parm5          = ''       
               ,  @c_Parm6          = ''       
               ,  @c_Parm7          = ''       
               ,  @c_Parm8          = ''      
               ,  @c_Parm9          = ''      
               ,  @c_Parm10         = ''
               ,  @c_Parm11         = ''  
               ,  @c_Parm12         = ''  
               ,  @c_Parm13         = ''   
               ,  @c_Parm14         = ''   
               ,  @c_Parm15         = ''   
               ,  @c_Parm16         = ''   
               ,  @c_Parm17         = ''   
               ,  @c_Parm18         = ''   
               ,  @c_Parm19         = ''   
               ,  @c_Parm20         = ''          
               ,  @n_Noofcopy       = @n_Noofcopy       
               ,  @c_PrinterID      = @c_PrinterID      
               ,  @c_IsPaperPrinter = 'Y' 
               ,  @c_ReportTemplate = @c_ReportTemplate
               ,  @c_PrintData      = ''      
               ,  @c_PrintType      = @c_PrintType      
               ,  @c_UserName       = @c_UserName       
               ,  @b_SCEPreView     = @b_SCEPreView       
               ,  @n_JobID          = @n_JobID           OUTPUT   
               ,  @b_success        = @b_success         OUTPUT 
               ,  @n_err            = @n_err             OUTPUT 
               ,  @c_errmsg         = @c_errmsg          OUTPUT
         
         IF @b_success = 0
         BEGIN
            SET @n_Continue = 3
         END      
         
         FETCH NEXT FROM @CUR_BatPrt INTO @c_Storerkey, @c_Facility, @c_PickSlipNo, @c_CartonNo
      END
      CLOSE @CUR_BatPrt
      DEALLOCATE @CUR_BatPrt
      
      SET @b_ContinuePrint = 0
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE() + '. (lsp_PreRpint_CtnMnfLbl23aWave)'
      GOTO EXIT_SP
   END CATCH

   EXIT_SP:
   
   IF (XACT_STATE()) = -1  
   BEGIN
      ROLLBACK TRAN
   END 
       
   IF @n_Continue = 3   
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_PreRpint_CtnMnfLbl23aWave'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   REVERT
END  

GO