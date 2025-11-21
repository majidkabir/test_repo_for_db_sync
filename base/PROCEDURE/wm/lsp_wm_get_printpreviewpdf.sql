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
/* PVCS Version: 1.2                                                    */
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
/* 2023-04-13  Wan02    1.2   WMS-22142 - Backend PB Report-MQ(SP Change)*/
/************************************************************************/
CREATE   PROC [WM].[lsp_WM_Get_PrintPreviewPDF]
      @c_JobIDs         NVARCHAR(MAX)  --Standard with module report where by return multiple jobs ID (seperate by '|'). View Report only return 1 Jobid
    , @c_UserName       NVARCHAR(128)  = ''
    , @b_Success        INT            = 0   OUTPUT    
    , @n_err            INT            = 0   OUTPUT
    , @c_errmsg         NVARCHAR(255)  = ''  OUTPUT
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
         , @c_CountryPDFFolder   NVARCHAR(250) = '' 
         , @c_FilePath           NVARCHAR(50)  = ''
         , @c_Encrypted          NVARCHAR(MAX) = ''  
         , @c_Urlencoded         NVARCHAR(MAX) = ''  
         , @c_Urltemplate        NVARCHAR(2000)= ''--'https://api-ut.lflogistics.com/wms/rgn/dstrg/p/v1/GetFile/'
         
         , @b_Apigee             BIT           = 1                                  --(Wan02)                             
         , @c_FileNameURL        NVARCHAR(50)  = ''                                 --(Wan02)  
         , @c_FileExt            NVARCHAR(5)   = ''                                 --(Wan02)                                                                                     

         , @n_JobID              BIGINT        = 0                                  --(Wan02)
         , @c_Storerkey          NVARCHAR(15)  = ''                                 --(Wan02)
         , @c_ReturnURL          NVARCHAR(1000)= ''                                 --(Wan02)
         
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
                                                         
      IF CHARINDEX('|',@c_JobIDs,1) > 0                                             --(Wan02) - START                
      BEGIN
         SET @n_JobID = LEFT(@c_JobIDs, CHARINDEX('|',@c_JobIDs,1)-1)
      END
      ELSE 
      BEGIN
      	SET @n_JobID = @c_JobIDs   
      END
      
      SELECT TOP 1 @c_Storerkey = rpj.StorerKey
      FROM rdt.RDTPrintJob AS rpj (NOLOCK)
      WHERE rpj.JobId = @n_JobID
      
      IF @c_Storerkey = ''
      BEGIN
         SELECT TOP 1 @c_Storerkey = rpjl.StorerKey
         FROM rdt.RDTPrintJob_Log AS rpjl (NOLOCK)
         WHERE rpjl.JobId = @n_JobID   
      END
      
      IF @c_Storerkey = ''
      BEGIN
         SET @c_Storerkey = 'ALL'
      END
      
      SELECT TOP 1                                                                             
             @c_CountryPDFFolder = ISNULL(Option1,'')    --Country PDF Path. 
            ,@n_MaxGetPDFSecond  = ISNULL(Option2,'')    --MaxPrintSecond
            ,@c_Urltemplate      = ISNULL(Option5,'')    --URL Template    
      FROM StorerConfig (NOLOCK)  
      WHERE ConfigKey='PDFPreviewServer'  
      AND Storerkey IN (@c_Storerkey, 'ALL') 
      AND SValue > '' 
      ORDER BY CASE WHEN Storerkey = @c_Storerkey THEN 1
                    WHEN Storerkey = 'ALL'  THEN 3
                    ELSE 9
                    END                                                             --(Wan02) - END 
   
      IF @n_MaxGetPDFSecond = 0 SET @n_MaxGetPDFSecond = 300
      
      SET @b_Apigee = 1                                                             --(Wan02) - START
      SET @c_FileNameURL= ''
      IF @c_CountryPDFFolder <> ''
      BEGIN
         IF CHARINDEX('\', @c_CountryPDFFolder,1) > 0
         BEGIN
            SET @b_Apigee = 0
         END   
      
         IF @b_Apigee = 1 
         BEGIN 
            IF RIGHT(@c_CountryPDFFolder,1) <> '/'  SET @c_CountryPDFFolder = @c_CountryPDFFolder + '/'
         END
         ELSE IF @b_Apigee = 0
         BEGIN
            SET @c_Encrypted = MASTER.dbo.fnc_CryptoEncrypt(@c_CountryPDFFolder,'') 
           
            EXEC master.dbo.isp_URLEncode
             @c_InputString = @c_Encrypted 
            ,@c_OutputString= @c_Urlencoded  OUTPUT 
            ,@c_vbErrMsg    = @c_ErrMsg      OUTPUT        
            
            SET @c_CountryPDFFolder = @c_Urlencoded       
            SET @c_FileNameURL = '&filename='
            SET @c_FileExt = '.pdf'
         END
      END                                                                           --(Wan02) - END

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
                           THEN @c_Urltemplate + @c_CountryPDFFolder + @c_FileNameURL + CONVERT (NVARCHAR(10), rjl.JobId)  --(Wan02) 
                              + @c_FileExt                                                                                 --(Wan02) 
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
   
   IF OBJECT_ID('tempdb..#PreviewPDF', 'U') IS NULL                 --(Wan02) - START
   BEGIN
      SELECT tpji.JobID, tpji.ReturnURL, [Status] = CASE WHEN @c_JobStatus_Exceeded = '6' THEN '6' ELSE tpji.[Status] END
      FROM @t_PreviewJobID AS tpji
      ORDER BY tpji.RowID        
   END
   ELSE
   BEGIN
      SET @c_ReturnURL = @c_Urltemplate + @c_CountryPDFFolder 
      INSERT INTO #PreviewPDF (JobID, ReturnURL, [Status])
      SELECT tpji.JobID, ReturnURL = @c_ReturnURL + CONVERT(NVARCHAR(10), tpji.jobID)
      , [Status] = CASE WHEN @c_JobStatus_Exceeded = '6' THEN '6' ELSE tpji.[Status] END
      FROM @t_PreviewJobID AS tpji
      ORDER BY tpji.RowID 
   END                                                               --(Wan02) - END                                                
                       
END -- procedure

GO