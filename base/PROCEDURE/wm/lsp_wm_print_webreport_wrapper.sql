SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: WM.lsp_WM_Print_WebReport_Wrapper                       */
/* Creation Date: 2023-08-01                                            */
/* Copyright: Maersk                                                    */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: NextGen Ecom Packing                                        */
/*        : PAC-15:Ecom Packing | Print Packing Report - Backend        */
/*                                                                      */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 8.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2023-02-15  Wan      1.0   Created & DevOps Combine Script           */ 
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Print_WebReport_Wrapper]
   @n_WMReportRowID      BIGINT 
,  @c_Storerkey          NVARCHAR(15)
,  @c_Facility           NVARCHAR(5)
,  @c_UserName           NVARCHAR(128)  
,  @n_Noofcopy           INT            = 1                                                   
,  @c_PrinterID          NVARCHAR(100)  = ''
,  @c_IsPaperPrinter     NCHAR(1)       = 'Y'
,  @n_Noofparms          INT            = 0
,  @c_Parm1              NVARCHAR(60)
,  @c_Parm2              NVARCHAR(60)   = ''
,  @c_Parm3              NVARCHAR(60)   = ''
,  @c_Parm4              NVARCHAR(60)   = ''
,  @c_Parm5              NVARCHAR(60)   = ''
,  @c_Parm6              NVARCHAR(60)   = ''
,  @c_Parm7              NVARCHAR(60)   = ''
,  @c_Parm8              NVARCHAR(60)   = ''
,  @c_Parm9              NVARCHAR(60)   = ''
,  @c_Parm10             NVARCHAR(60)   = ''         
,  @c_Parm11             NVARCHAR(60)   = ''
,  @c_Parm12             NVARCHAR(60)   = ''
,  @c_Parm13             NVARCHAR(60)   = ''
,  @c_Parm14             NVARCHAR(60)   = ''
,  @c_Parm15             NVARCHAR(60)   = ''
,  @c_Parm16             NVARCHAR(60)   = ''
,  @c_Parm17             NVARCHAR(60)   = ''
,  @c_Parm18             NVARCHAR(60)   = ''
,  @c_Parm19             NVARCHAR(60)   = ''
,  @c_Parm20             NVARCHAR(60)   = ''
,  @b_Success            INT            = 1  OUTPUT
,  @n_Err                INT            = 0  OUTPUT
,  @c_ErrMsg             NVARCHAR(255)  = '' OUTPUT
,  @c_ReturnURL          NVARCHAR(MAX)  = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt             INT               = @@TRANCOUNT
         , @n_Continue              INT               = 1
  
         , @b_PrintOverInternet     INT               = 0

         , @c_SourceType            NVARCHAR(50)      = 'lsp_WM_Print_WebReport_Wrapper'
         , @c_ReportID              NVARCHAR(10)      = ''
         , @c_ReportLineNo          NVARCHAR(5)       = ''
         , @c_ReportType            NVARCHAR(30)      = ''
         , @c_PrintType             NVARCHAR(30)      = ''
         
         , @c_PrintData             NVARCHAR(MAX)     = ''
         , @c_PrintSettings         NVARCHAR(4000)    = ''
         , @c_ReportTemplate        NVARCHAR(1000)    = ''
         , @c_PrintTemplateSP       NVARCHAR(1000)    = ''
         , @c_FileFolder            NVARCHAR(100)     = ''
         , @c_JSpoolerFolder        NVARCHAR(120)     = ''

         , @c_SQL                   NVARCHAR(MAX)     = ''
         , @c_SQLParms              NVARCHAR(2000)    = ''  
         , @c_SQL_Select            NVARCHAR(MAX)     = ''

   BEGIN TRY
      SELECT @c_ReportID = w.ReportID
            ,@c_PrintType  = w.Printtype
            ,@c_PrintSettings = w.PrintSettings
            ,@c_ReportLineNo = w.ReportLineNo
            ,@c_ReportTemplate = w.ReportTemplate           
            ,@c_PrintTemplateSP = w.PrintTemplateSP
            ,@c_FileFolder             = w.FileFolder 
      FROM dbo.WMREPORTDETAIL AS w WITH (NOLOCK)
      WHERE w.RowID = @n_WMReportRowID
  
      IF @c_PrinterID <> ''
      BEGIN
         SELECT @b_PrintOverInternet = IIF(cpc.PrintClientID IS NULL,0,1)               
         FROM rdt.RDTPrinter AS rp (NOLOCK) 
         LEFT OUTER JOIN dbo.CloudPrintConfig AS cpc WITH (NOLOCK) ON cpc.PrintClientID = rp.CloudPrintClientID 
         WHERE rp.PrinterID = @c_PrinterID
      END
    
      EXEC WM.lsp_WM_Get_WebReport_URL
            @c_ReportID          = @c_ReportID
         ,  @n_DetailRowID       = @n_WMReportRowID
         ,  @c_Parm1             = @c_Parm1           
         ,  @c_Parm2             = @c_Parm2           
         ,  @c_Parm3             = @c_Parm3           
         ,  @c_Parm4             = @c_Parm4           
         ,  @c_Parm5             = @c_Parm5           
         ,  @c_Parm6             = @c_Parm6           
         ,  @c_Parm7             = @c_Parm7           
         ,  @c_Parm8             = @c_Parm8           
         ,  @c_Parm9             = @c_Parm9           
         ,  @c_Parm10            = @c_Parm10          
         ,  @c_Parm11            = @c_Parm11          
         ,  @c_Parm12            = @c_Parm12          
         ,  @c_Parm13            = @c_Parm13          
         ,  @c_Parm14            = @c_Parm14          
         ,  @c_Parm15            = @c_Parm15          
         ,  @c_Parm16            = @c_Parm16          
         ,  @c_Parm17            = @c_Parm17          
         ,  @c_Parm18            = @c_Parm18          
         ,  @c_Parm19            = @c_Parm19          
         ,  @c_Parm20            = @c_Parm20          
         ,  @c_ReturnURL         = @c_ReturnURL OUTPUT
         ,  @b_Success           = @b_Success   OUTPUT  
         ,  @n_err               = @n_err       OUTPUT                                                                                                             
         ,  @c_ErrMsg            = @c_ErrMsg    OUTPUT
         ,  @b_PrintOverInternet = @b_PrintOverInternet
      
      IF @b_Success = 0  
      BEGIN
         GOTO EXIT_SP
      END
      
      IF @b_PrintOverInternet = 1 AND @c_ReturnURL <> ''
      BEGIN
         SET @c_PrintData = @c_ReturnURL 
         SET @c_ReturnURL = ''
      END
      
      IF @c_PrintData <> ''                           
      BEGIN
         SET @c_FileFolder= IIF(@c_FileFolder='','INVOICE',@c_FileFolder)
         
         SELECT @c_JSpoolerFolder = ISNULL(n.NSQLDescrip,'')
         FROM dbo.NSQLCONFIG AS n (NOLOCK)
         WHERE n.Configkey = 'JSpoolerFolder'
    
         IF @c_JSpoolerFolder <> ''
         BEGIN
            SET @c_PrintData = '{"TargetURL":"'+ @c_PrintData + '"'
                             +',"HTTPMethod":"GET"'
                             +',"ContentType":"application/json"'
                             +',"RequestHeader":""'
                             +',"RequestBody":""'  
                             +',"SetWebProxy":"N"'  
                             +',"CountryFolder":"' + @c_JSpoolerFolder+'"'
                             +',"DocType":"' + @c_FileFolder+'"}'
         END
      END

      IF @c_PrintData <> ''                           --WebService RequestString
      BEGIN
         EXEC [WM].[lsp_WM_SendPrintJobToProcessApp]  
            @c_ReportID       = @c_ReportID
         ,  @c_ReportLineNo   = @c_ReportLineNo       
         ,  @c_Storerkey      = @c_Storerkey  
         ,  @c_Facility       = @c_Facility         
         ,  @n_Noofparms      = @n_Noofparms  
         ,  @c_Parm1          = @c_Parm1            
         ,  @c_Parm2          = @c_Parm2            
         ,  @c_Parm3          = @c_Parm3            
         ,  @c_Parm4          = @c_Parm4            
         ,  @c_Parm5          = @c_Parm5            
         ,  @c_Parm6          = @c_Parm6            
         ,  @c_Parm7          = @c_Parm7            
         ,  @c_Parm8          = @c_Parm8            
         ,  @c_Parm9          = @c_Parm9            
         ,  @c_Parm10         = @c_Parm10     
         ,  @c_Parm11         = @c_Parm11       
         ,  @c_Parm12         = @c_Parm12       
         ,  @c_Parm13         = @c_Parm13       
         ,  @c_Parm14         = @c_Parm14                            
         ,  @c_Parm15         = @c_Parm15         
         ,  @c_Parm16         = @c_Parm16         
         ,  @c_Parm17         = @c_Parm17         
         ,  @c_Parm18         = @c_Parm18         
         ,  @c_Parm19         = @c_Parm19         
         ,  @c_Parm20         = @c_Parm20                 
         ,  @n_Noofcopy       = @n_Noofcopy          --optional
         ,  @c_PrinterID      = @c_PrinterID         --optional
         ,  @c_IsPaperPrinter = @c_IsPaperPrinter    --optional
         ,  @c_ReportTemplate = @c_ReportTemplate    --optional
         ,  @c_PrintData      = @c_PrintData         --optional
         ,  @c_PrintType      = @c_PrintType         --ZPL / TCPSPOOLER /  ITFFILE
         ,  @c_UserName       = ''                   --optional  
         ,  @b_SCEPreView     = 0        
         ,  @n_JobID          = 0                               
         ,  @b_success        = @b_success          OUTPUT 
         ,  @n_err            = @n_err              OUTPUT 
         ,  @c_errmsg         = @c_errmsg           OUTPUT
               
         IF @n_Err <> 0
         BEGIN 
            SET @n_Continue = 3        
            GOTO EXIT_SP               
         END
      END
   END TRY
 
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
EXIT_SP:
   IF OBJECT_ID('tempdb..#ZPLData','u') IS NOT NULL
   BEGIN
      DROP TABLE #ZPLData;
   END
         
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Print_WebReport_Wrapper'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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
END -- procedure

GO