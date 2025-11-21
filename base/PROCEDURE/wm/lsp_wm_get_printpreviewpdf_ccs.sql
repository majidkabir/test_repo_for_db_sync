SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: WM.lsp_WM_Get_PrintPreviewPDF                           */  
/* Creation Date: 2021-06-03                                            */  
/* Copyright: LF Logistics                                              */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: RG|PB report print preview pop up                           */  
/*        :                                                             */  
/* Called By:                                                           */  
/*          :                                                           */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 2021-06-03  Wan      1.0   Created.                                  */   
/* 2021-09-24  Wan      1.0   DevOps Combine Script                     */  
/* 2022-07-13  Wan01    1.1   LFWM-3585 - UAT  PH  ALL - WMReport cannot*/  
/*                            pass in start and end value. Increase     */  
/*                            @c_JobIDs to NVARCHAR(MAX)                */  
/* 2023-04-28 CSCHONG   1.2   Get Enctypt PDF folder (CS01)             */ 
/* 2023-05-31 CSCHONG   1.3   Change Decode to Encode (CS02)            */
/************************************************************************/  
create      PROC [WM].[lsp_WM_Get_PrintPreviewPDF_ccs]  
      @c_JobIDs      NVARCHAR(MAX)  --Standard with module report where by return multiple jobs ID (seperate by '|'). View Report only return 1 Jobid  
    , @c_UserName    NVARCHAR(128)  = ''  
    , @b_Success     INT            = 0   OUTPUT      
    , @n_err         INT            = 0   OUTPUT  
    , @c_errmsg      NVARCHAR(255)  = ''  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT = @@TRANCOUNT  
         , @n_Continue           INT = 1  
           
         , @n_RowID              INT = 0  
           
         , @n_MaxGetPDFSecond    INT = 0  
         , @c_JobStatus_Exceeded NVARCHAR(10)  = ''  
         , @c_CountryPDFFolder   NVARCHAR(250)  = ''       --CS01  
         , @c_FilePath           NVARCHAR(50)  = ''  
         , @c_Encrypted          NVARCHAR(MAX) = ''    
         , @c_Urlencoded         NVARCHAR(MAX) = ''    
         , @c_Urltemplate        NVARCHAR(2000)= ''--'https://api-ut.lflogistics.com/wms/rgn/dstrg/p/v1/GetFile/'  
           
         ,@b_Apigee              BIT           = 1          --CS01  
         ,@c_FileNameURL         NVARCHAR(max)  = ''        --CS01  
         ,@c_FileExt             NVARCHAR(5)   = ''         --CS01
           
           
   DECLARE @t_PreviewJobID  TABLE  
   (  RowID          INT            NOT NULL IDENTITY(1,1) PRIMARY KEY  
   ,  JobID          INT            NOT NULL DEFAULT (0)  
   ,  FilePath       NVARCHAR(250)  NOT NULL DEFAULT('')  
   ,  ReturnURL      NVARCHAR(1000) NOT NULL DEFAULT('')  
   ,  [Status]       NVARCHAR(10)   NOT NULL DEFAULT('0')  
   )        
  
   SET @b_Success  = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
     
   BEGIN TRY  
      SELECT @c_CountryPDFFolder = ISNULL(Option1,'')        --Country PDF Path.   
            ,@n_MaxGetPDFSecond  = ISNULL(Option2,'')        --MaxPrintSecond  
            ,@c_Urltemplate      = ISNULL(Option5,'')        --URL Template      
      FROM StorerConfig (NOLOCK)    
      WHERE ConfigKey='PDFPreviewServer'    
      AND Storerkey = 'ALL'    
      AND SValue > ''    
     
      IF @n_MaxGetPDFSecond = 0 SET @n_MaxGetPDFSecond = 300  
        
      --CS01  S  
      SET @b_Apigee  = 1  
      SET @c_FileNameURL = ''  
      IF @c_CountryPDFFolder <> ''  
      BEGIN  
           IF CHARINDEX('\',@c_CountryPDFFolder,1) > 0  
           BEGIN  
               SET @b_Apigee = 0  
           END         
  
           IF @b_Apigee =1  
           BEGIN    
                IF RIGHT(@c_CountryPDFFolder,1) <> '/' SET @c_CountryPDFFolder = @c_CountryPDFFolder + '/'  
           END  
           ELSE IF @b_Apigee = 0  
           BEGIN  
  
                SET @c_Encrypted = MASTER.dbo.fnc_CryptoEncrypt(@c_CountryPDFFolder,'')  
  
                 DECLARE @c_OutputString NVARCHAR(MAX),  
                         @c_vbErrMsg NVARCHAR(MAX);  

                 EXEC master.dbo.isp_URLEncode             --CS02
                             @c_InputString   = @c_Encrypted,  
                             @c_OutputString  = @c_Urlencoded OUTPUT,   
                             @c_vbErrMsg      = @c_vbErrMsg     OUTPUT   
  
  
                  --SET @c_CountryPDFFolder = replace(@c_Urlencoded,' ','%2B')--@c_Urlencoded  
                  SET @c_CountryPDFFolder = @c_Urlencoded 
                  SET @c_FileNameURL ='&filename='        
                  SET @c_FileExt = '.pdf'          --CS01
               END      
                    
           END   --CS01 E  
  
      INSERT INTO @t_PreviewJobID  
      (  
            JobID  
      ,     FilePath  
      ,     ReturnURL   
      ,     [Status]   
      )  
      SELECT rj.JobId  
         , FilePath = ''  
         , ReturnURL = ''  
         , JobStatus = CASE WHEN  @n_MaxGetPDFSecond > 0  AND DATEDIFF(SECOND,rj.adddate, GETDATE()) > @n_MaxGetPDFSecond  
                            THEN '6'            -- Exceeded Max Get PDF Second  
                            ELSE '0'  
                            END  
      FROM STRING_SPLIT(@c_JobIDs,'|') s  
      JOIN rdt.RDTPrintJob AS rj WITH (NOLOCK) ON s.[VALUE] = rj.JobId  
      WHERE PDFPreview = 'Y'  
      UNION  
      SELECT rjl.JobId  
         , FilePath = CASE WHEN rjl.JobStatus = '9'   
                           THEN @c_CountryPDFFolder + CONVERT (NVARCHAR(10), rjl.JobId)   
                           ELSE ''  
                      END  
         , ReturnURL= CASE WHEN rjl.JobStatus = '9'   
                           THEN @c_Urltemplate + @c_CountryPDFFolder + @c_FileNameURL+ CONVERT (NVARCHAR(10), rjl.JobId)+ @c_FileExt   --CS01  
                           ELSE ''  
                      END               
         , rjl.JobStatus  
      FROM STRING_SPLIT(@c_JobIDs,'|') s  
      JOIN rdt.RDTPrintJob_Log AS rjl WITH (NOLOCK) ON s.[VALUE] = rjl.JobId  
      WHERE PDFPreview = 'Y'  
   END TRY  
   BEGIN CATCH  
      SET @n_Continue = 3  
      SET @c_ErrMsg = ERROR_MESSAGE()  
      GOTO EXIT_SP  
   END CATCH  
   --(Wan01)  - END  
EXIT_SP:  
     
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_WM_Get_PrintPreviewPDF'  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
     
   SET @c_JobStatus_Exceeded = ''  
   SELECT @c_JobStatus_Exceeded = tpji.[Status]   
   FROM @t_PreviewJobID AS tpji  
   WHERE tpji.[Status] = '6'  
     
   SELECT tpji.JobID, tpji.ReturnURL, [Status] = CASE WHEN @c_JobStatus_Exceeded = '6' THEN '6' ELSE tpji.[Status] END  
   FROM @t_PreviewJobID AS tpji  
END -- procedure  


GO