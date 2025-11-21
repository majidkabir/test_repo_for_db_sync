SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_UpdateRDTPrintJobStatus                             */
/* Creation Date: 01-NOV-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2018-11-11  Wan01    1.1   Fixed  to rollback                        */
/* 2019-03-12  Wan01    1.0   WM - Printing: Add Parm11 - Parm20        */
/* 2019-06-16  James    1.2   Comment commit tran before start          */
/*                            transaction (james01)                     */
/* 2020-11-23  Wan02    1.3   Fixed.Insert NULL to RDT.RDTPRINTJOB_LOG  */
/* 2021-07-28  Wan03    1.4   LFWM-2800 - RG UAT PB Report Print Preview*/
/*                            SP & sharedrive for PDF Storage           */
/* 2021-09-24  Wan03    1.4   DevOps Combine Script                     */
/* 2023-04-13  Wan04    1.5   WMS-22142 - Backend PB Report-MQ(SP Change)*/
/*                            DevOps combine Script                     */
/* 2023-07-07  Wan05    1.6   PAC-15:Ecom Packing | Print Packing Report*/
/*                            - Backend                                 */
/* 2023-10-23  Wan06    1.7   Get Print Over Internet Printing          */ 
/************************************************************************/
CREATE   PROC [dbo].[isp_UpdateRDTPrintJobStatus]
      @n_JobID          BIGINT
   ,  @c_JobStatus      NVARCHAR(10)
   ,  @c_JobErrMsg      NVARCHAR(255)
   ,  @b_Success        INT            = 1   OUTPUT
   ,  @n_Err            INT            = 0   OUTPUT
   ,  @c_ErrMsg         NVARCHAR(255)  = ''  OUTPUT
   ,  @c_PrintData      NVARCHAR(MAX)  = ''  
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt                INT            = 0
         , @n_Continue                 INT            = 1
         
         , @n_PrintOverInternet        INT            = 0               --(Wan04)

         , @c_Storerkey                NVARCHAR(15)   = ''              --(Wan04)
         , @c_JobId                    NVARCHAR(10)   = ''              --(Wan04)
         , @c_JobType                  NVARCHAR(10)   = ''              --(Wan04)
         , @c_PDFPreview               CHAR(1)        = 'N'             --(Wan04) 
         , @c_IfCloudClientPrinter     NVARCHAR(30)   = ''              --(Wan04)
         , @c_CloudClientPrinterID     NVARCHAR(30)   = ''              --(Wan04)
         , @c_CloudClientPrinterName   NVARCHAR(128)  = ''              --(Wan04)
         , @c_PrintBy                  NVARCHAR(128)  = ''              --(Wan04)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1

   SET @c_JobErrMsg = ISNULL(RTRIM(@c_JobErrMsg), '')             -- (Wan01)

   --( james01)
   /*
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   */
   IF @c_JobStatus IN ('5', '9')
   BEGIN
      BEGIN TRAN
         --(Wan04) - START
         SET @c_JobId = CONVERT(NVARCHAR(10),@n_JobID)
         SELECT @c_Storerkey = rpj.Storerkey
               ,@c_JobType   = rpj.JobType
               ,@c_PDFPreview= rpj.PDFPreview
               ,@c_IfCloudClientPrinter = rpj.Printer 
               ,@c_CloudClientPrinterID = rpj.CloudClientPrinterID
               ,@c_PrintBy = rpj.AddWho
               ,@c_PrintData = IIF(@c_PrintData='',rpj.PrintData,@c_PrintData)  --(Wan05)               
         FROM rdt.RDTPrintJob AS rpj WITH (NOLOCK)
         WHERE rpj.JobID = @n_JobId          

         IF @c_CloudClientPrinterID <> '' SET @c_IfCloudClientPrinter = @c_CloudClientPrinterID
         
         IF @c_JobStatus = '9' AND @c_IfCloudClientPrinter <> ''
         BEGIN
            --(Wan06) - START
            SELECT @n_PrintOverInternet = dbo.fnc_GetCloudPrint ('', @c_JobType, @c_IfCloudClientPrinter)    
            SELECT --@n_PrintOverInternet = IIF(cpc.PrintClientID IS NULL,0,1)   
                   @c_CloudClientPrinterName = rp.WinPrinter
            FROM rdt.RDTPrinter AS rp WITH (NOLOCK)
            --LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID 
            WHERE rp.PrinterID = @c_IfCloudClientPrinter
            --(Wan06) - END

            IF @c_CloudClientPrinterName <> '' AND CHARINDEX(',', @c_CloudClientPrinterName,1) > 0
            BEGIN
               SET @c_CloudClientPrinterName = LEFT(@c_CloudClientPrinterName, CHARINDEX(',', @c_CloudClientPrinterName,1) - 1)
            END
         END
         
         IF @c_PDFPreview = 'Y' AND @c_JobStatus = '9' AND @n_PrintOverInternet = 1
         BEGIN
            IF OBJECT_ID('tempdb..#PreviewPDF', 'U') IS NOT NULL
            BEGIN
               DROP TABLE #PreviewPDF
            END
         
            CREATE TABLE #PreviewPDF 
            (
               RowID          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY
            ,  JobID          INT            NOT NULL DEFAULT (0)
            ,  FilePath       NVARCHAR(250)  NOT NULL DEFAULT('')
            ,  ReturnURL      NVARCHAR(1000) NOT NULL DEFAULT('')
            ,  [Status]       NVARCHAR(10)   NOT NULL DEFAULT('9') 
            )

            EXEC [WM].[lsp_WM_Get_PrintPreviewPDF]
                  @c_JobIDs   = @c_JobID
               ,  @c_UserName = @c_PrintBy
               ,  @b_Success  = @b_Success   OUTPUT    
               ,  @n_err      = @n_err       OUTPUT
               ,  @c_errmsg   = @c_errmsg    OUTPUT
    
            --UPDATE #PreviewPDF SET STATUS = '9'       
            SELECT TOP 1 @c_PrintData = pp.ReturnURL
            FROM #PreviewPDF AS pp
    
            IF OBJECT_ID('tempdb..#PreviewPDF', 'U') IS NOT NULL
            BEGIN
               DROP TABLE #PreviewPDF
            END
         END
 
         INSERT INTO RDT.RDTPRINTJOB_LOG
         (  [JobId]         
         ,  [JobName]       
         ,  [ReportID]      
         ,  [JobStatus]  
         ,  [JobErrMsg]     
         ,  [NextRun]       
         ,  [LastRun]       
         ,  [Datawindow]    
         ,  [NoOfParms]     
         ,  [Parm1]         
         ,  [Parm2]         
         ,  [Parm3]         
         ,  [Parm4]         
         ,  [Parm5]         
         ,  [Parm6]         
         ,  [Parm7]         
         ,  [Parm8]         
         ,  [Parm9]         
         ,  [Parm10]        
         ,  [Printer]       
         ,  [NoOfCopy]      
         ,  [Mobile]        
         ,  [TargetDB]      
         ,  [AddDate]       
         ,  [AddWho]        
         ,  [EditDate]      
         ,  [EditWho]       
         ,  [PrintCount]    
         ,  [PrintData]     
         ,  [JobType]       
         ,  [StorerKey]     
         ,  [ExportFileName]
         ,  [Parm11]        
         ,  [Parm12]        
         ,  [Parm13]        
         ,  [Parm14]        
         ,  [Parm15]        
         ,  [Parm16]        
         ,  [Parm17]        
         ,  [Parm18]        
         ,  [Parm19]        
         ,  [Parm20]        
         ,  [Function_ID] 
         ,  [ReportLineNo]
         ,  [PDFPreview]                                 --(Wan03)   
         ,  [CloudClientPrinterID]                       --(Wan04)
         ,  [PaperSizeWxH]                               --(Wan04) 2023-06-19    
         ,  [DCropWidth]                                 --(Wan04) 2023-06-19
         ,  [DCropHeight]                                --(Wan04) 2023-06-19
         ,  [IsLandScape]                                --(Wan04) 2023-06-19
         ,  [IsColor]                                    --(Wan04) 2023-06-19
         ,  [IsDuplex]                                   --(Wan04) 2023-06-19
         ,  [IsCollate]                                  --(Wan04) 2023-06-19         
         )
      SELECT   [JobId]         
            ,  [JobName]       
            ,  [ReportID]      
            ,  @c_JobStatus     
            ,  @c_JobErrMsg  
            ,  [NextRun]       
            ,  [LastRun]       
            ,  Datawindow = ISNULL([Datawindow],'')    -- (Wan02) ,  [Datawindow]    
            ,  [NoOfParms]     
            ,  [Parm1]         
            ,  [Parm2]         
            ,  [Parm3]         
            ,  [Parm4]         
            ,  [Parm5]         
            ,  [Parm6]         
            ,  [Parm7]         
            ,  [Parm8]         
            ,  [Parm9]         
            ,  [Parm10]        
            ,  [Printer]       
            ,  [NoOfCopy]      
            ,  [Mobile]        
            ,  [TargetDB]      
            ,  [AddDate]       
            ,  [AddWho]        
            ,  GETDATE()     
            ,  SUSER_NAME()      
            ,  [PrintCount]     
            ,  [PrintData] = IIF(@c_PrintData<>'' AND @c_PrintData<>[PrintData], @c_PrintData,[PrintData])  --(Wan04)     
            ,  [JobType]         
            ,  [StorerKey]     
            ,  [ExportFileName]   
            ,  [Parm11]        
            ,  [Parm12]        
            ,  [Parm13]        
            ,  [Parm14]        
            ,  [Parm15]        
            ,  [Parm16]        
            ,  [Parm17]        
            ,  [Parm18]        
            ,  [Parm19]        
            ,  [Parm20]  
            ,  [Function_ID] 
            ,  [ReportLineNo] 
            ,  [PDFPreview]                                 --(Wan04) 
            ,  [CloudClientPrinterID]                       --(Wan04) 
            ,  [PaperSizeWxH]                               --(Wan04) 2023-06-19 
            ,  [DCropWidth]                                 --(Wan04) 2023-06-19
            ,  [DCropHeight]                                --(Wan04) 2023-06-19
            ,  [IsLandScape]                                --(Wan04) 2023-06-19
            ,  [IsColor]                                    --(Wan04) 2023-06-19
            ,  [IsDuplex]                                   --(Wan04) 2023-06-19  
            ,  [IsCollate]                                  --(Wan04) 2023-06-19                                                             --          
      FROM RDT.RDTPRINTJOB WITH (NOLOCK)
      WHERE JobID = @n_JobId   
      
      SET @n_Err = @@ERROR
      
      IF @n_Err  <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg =  CONVERT(CHAR(5), @n_Err) 
         SET @n_Err = 62820
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Insert record Into RDT.RDTPRINTJOB_LOG Fail - JobID:' + CAST(@n_JobId AS NVARCHAR) + '. (isp_UpdateRDTPrintJobStatus)'
                       + '(' + @c_ErrMsg + ')'
         GOTO QUIT_SP
      END  
            
      DELETE RDT.RDTPRINTJOB   
      WHERE JobID = @n_JobId   
      
      SET @n_Err = @@ERROR
      
      IF  @n_Err  <> 0
      BEGIN
         SET @n_Continue = 3
         SET @c_ErrMsg =  CONVERT(CHAR(5), @n_Err) 
         SET @n_Err = 62830
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Delete record from RDT.RDTPRINTJOB Fail. (isp_UpdateRDTPrintJobStatus)'
                       + '(' + @c_ErrMsg + ')'
         GOTO QUIT_SP
      END 

      IF @n_PrintOverInternet = 1
      BEGIN
         EXEC dbo.isp_SubmitPrintJobToCloudPrint
            @c_DataProcess    = 'CloudPrint'
         ,  @c_Storerkey      = @c_Storerkey   
         ,  @c_PrintType      = @c_JobType
         ,  @c_PrinterName    = @c_CloudClientPrinterName
         ,  @c_IP             = N''
         ,  @c_Port           = N''
         ,  @c_DocumentType   = ''
         ,  @c_DocumentId     = N''            
         ,  @c_JobID          = @n_JobID
         ,  @c_Data           = @c_PrintData
         ,  @b_Success        = @b_Success      OUTPUT  
         ,  @n_Err            = @n_Err          OUTPUT  
         ,  @c_ErrMsg         = @c_ErrMsg       OUTPUT  
      END

      --(Wan04) - END
   END
QUIT_SP:
   IF OBJECT_ID('tempdb..#PreviewPDF', 'U') IS NOT NULL
   BEGIN
      DROP TABLE #PreviewPDF
   END
            
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT > @n_StartTCnt--0 --@n_StartTCnt   (Wan01) 
      BEGIN
         ROLLBACK TRAN
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_UpdateRDTPrintJobStatus'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt--0
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT <  @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO