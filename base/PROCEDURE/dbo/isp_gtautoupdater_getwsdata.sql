SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
  
/*********************************************************************************/      
/* Stored Procedure: isp_GTAutoUpdater_GetWSData                                 */      
/* Creation Date: 23-Jun-2021                                                    */      
/* Copyright: LFL                                                                */      
/* Written by: GHChan                                                            */      
/*                                                                               */      
/* Purpose: Retrieve GTAutoUpdater configuration from GTApps                     */      
/*                                                                               */      
/* Called By:  GTAutoUpdater                                                     */      
/*                                                                               */      
/* PVCS Version: -                                                               */      
/*                                                                               */      
/* Updates:                                                                      */      
/* Date         Author   Ver  Purposes                                           */      
/* 23-Jun-2021  GHChan   1.0  Initial Development                                */      
/* 24-Jun-2021  TKLim    1.0  Remove user and alter WS & DeviceID Logic (TK01)   */      
/*********************************************************************************/      

CREATE PROC [dbo].[isp_GTAutoUpdater_GetWSData] (      
    @b_Debug            INT               = 0      
   ,@c_Format           VARCHAR(10)       = ''      
   ,@c_UserID           NVARCHAR(256)     = ''      
   ,@c_OperationType    NVARCHAR(60)      = ''      
   ,@c_RequestString    NVARCHAR(MAX)     = ''      
   ,@b_Success          INT               = 0    OUTPUT      
   ,@n_ErrNo            INT               = 0    OUTPUT      
   ,@c_ErrMsg           NVARCHAR(250)     = ''   OUTPUT      
   ,@c_ResponseString   NVARCHAR(MAX)     = ''   OUTPUT       
)      
AS       
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_DEFAULTS OFF       
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   /*********************************************/      
   /* Variables Declaration (Start)             */      
   /*********************************************/      
      
   DECLARE @n_Continue        INT            = 1  
         , @n_StartCnt        INT            = @@TRANCOUNT  
         , @c_AppName         NVARCHAR(30)  = ''  
         , @c_WorkStation     NVARCHAR(30)  = ''  
         , @c_DeviceID        NVARCHAR(50)  = ''  
         , @c_CurrentVersion  NVARCHAR(12)  = ''  
         , @c_ResponseType    NVARCHAR(5)   = 'XML'  
  
   SET @b_Success = 1  
     
   DECLARE @t_RequestString TABLE(  
      RowRef         INT IDENTITY(1,1)  
    , AppName        NVARCHAR(30)   NOT NULL  
    , WorkStation    NVARCHAR(30)   NULL  DEFAULT ''  
    , DeviceID       NVARCHAR(50)   NULL  DEFAULT ''  
    , CurrentVersion NVARCHAR(12)   NULL  DEFAULT ''  
    , ResponseType   NVARCHAR(5)   NULL  DEFAULT ''  
    )  
   /*********************************************/      
   /* Variables Declaration (End)               */      
   /*********************************************/      
       
   --Extract RequestBody Data into Temp Table  
   IF ISNULL(RTRIM(@c_RequestString),'') = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @b_Success = 0  
      SET @n_ErrNo = N'90000'    
      SET @c_ErrMsg = N'RequestBody Cannot be NULL or EMPTY.(isp_GTAutoUpdater_GetWSData)'  
      GOTO QUIT  
   END  
  
   BEGIN TRY      
      INSERT INTO @t_RequestString ( AppName  
                                   , WorkStation  
                                   , DeviceID  
                                   , CurrentVersion  
                                   --, ResponseType  
                                   )        
                             SELECT  AppName  
                , WorkStation  
                                   , DeviceID  
                                   , CurrentVersion  
                                   --, ResponseType  
                             FROM OPENJSON(@c_RequestString)  
                             WITH (  
                               AppName          NVARCHAR(30)   '$.AppName'  
                             , WorkStation      NVARCHAR(30)   '$.WorkStation'  
                             , DeviceID         NVARCHAR(50)   '$.DeviceID'  
                             , CurrentVersion   NVARCHAR(12)   '$.CurrentVersion'  
                             --, ResponseType     NVARCHAR(5)   '$.ResponseType'  
                             )   
      
      SELECT @c_AppName          =  AppName  
           , @c_WorkStation      = ISNULL(RTRIM(WorkStation), '')  
           , @c_DeviceID         = ISNULL(RTRIM(DeviceID), '')  
           , @c_CurrentVersion   = ISNULL(RTRIM(CurrentVersion), '')  
           --, @c_ResponseType     = ISNULL(RTRIM(ResponseType), '')  
      FROM @t_RequestString  
     
   END TRY      
   BEGIN CATCH     
      SET @n_Continue = 3  
      SET @b_Success = 0  
      SET @n_ErrNo = N'90001'    
      SET @c_ErrMsg = N'Failed to Extract RequestBody Data. ' + ERROR_MESSAGE() + '(isp_GTAutoUpdater_GetWSData)'  
      GOTO QUIT      
   END CATCH  
  
  
   IF @c_WorkStation = '' AND @c_DeviceID = ''  
   BEGIN  
      SET @n_Continue = 3  
      SET @b_Success = 0  
      SET @n_ErrNo = N'90002'    
      SET @c_ErrMsg = N'Invalid Request! Either (Workstation & DeviceID) one of the property must contains values.(isp_GTAutoUpdater_GetWSData)'  
      GOTO QUIT  
   END   
  
   IF @c_CurrentVersion = ''  
   BEGIN   
      SET @n_Continue = 3  
      SET @b_Success = 0  
      SET @n_ErrNo = N'90003'    
      SET @c_ErrMsg = N'Current Version cannot be null or empty!(isp_GTAutoUpdater_GetWSData)'  
      GOTO QUIT  
   END  
  
   --Create a New Config when not exist, else Update CurrentVersion into DB when not match.  
   IF NOT EXISTS(SELECT 1 FROM [API].[AppWorkstation] WITH (NOLOCK)  
                 WHERE APPName = @c_AppName  
                 AND WorkStation = @c_WorkStation   
                 AND DeviceID = @c_DeviceID)        --(TK01)  
   BEGIN  
      INSERT INTO [API].[AppWorkstation] ([APPName], [Workstation], [DeviceID], [AddWho], [EditWho], [CurrentVersion], [TargetVersion])  
      VALUES (@c_AppName, @c_WorkStation, @c_DeviceID, suser_sname(), suser_sname(), @c_CurrentVersion, @c_CurrentVersion)  
   END  
   ELSE IF EXISTS(SELECT 1 FROM [API].[AppWorkstation] WITH (NOLOCK)  
                 WHERE APPName = @c_AppName  
                 AND WorkStation = @c_WorkStation   
                 AND DeviceID = @c_DeviceID         --(TK01)  
                 AND CurrentVersion != @c_CurrentVersion)  
   BEGIN  
  
      UPDATE [API].[AppWorkstation] WITH (ROWLOCK)  
      SET CurrentVersion = @c_CurrentVersion  
      WHERE APPName = @c_AppName  
      AND WorkStation = @c_WorkStation   
      AND DeviceID = @c_DeviceID            --(TK01)  
  
   END  
  
   IF @c_ResponseType = 'JSON'  
   BEGIN  
      SET @c_ResponseString =(  
               SELECT CurrentVersion, TargetVersion   
               FROM [API].[AppWorkstation] WITH (NOLOCK)  
               WHERE APPName = @c_AppName  
               AND WorkStation = @c_WorkStation   
               AND DeviceID = @c_DeviceID      --(TK01)  
               FOR JSON PATH, ROOT ('AppVersion'))  
  
   END  
   ELSE IF @c_ResponseType = 'XML'  
   BEGIN  
      SET @c_ResponseString = '<?xml version="1.0" encoding="UTF-8"?>'  
      SET @c_ResponseString = @c_ResponseString + (  
               SELECT CurrentVersion, TargetVersion   
               FROM [API].[AppWorkstation] WITH (NOLOCK)  
               WHERE APPName = @c_AppName  
               AND WorkStation = @c_WorkStation   
               AND DeviceID = @c_DeviceID  
               FOR XML PATH ('AppVersion'))  
   END  
  
   IF ISNULL(RTRIM(@c_ResponseString),'') = ''      
   BEGIN      
      SET @n_Continue = 3     
      SET @b_Success = 0  
      SET @n_ErrNo = N'90003'      
      SET @c_ErrMsg = 'No available config records have been found!(isp_GTAutoUpdater_GetWSData)'     
   END  
     
  
QUIT:    
   IF @n_Continue = 3      
   BEGIN   
     
      IF @c_ResponseType = 'JSON'  
      BEGIN  
         SET @c_ResponseString = (SELECT @n_ErrNo AS [ErrNo]  
                                      , @c_ErrMsg AS [ErrMsg]   
                                 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)     
        
      END  
      ELSE IF @c_ResponseType = 'XML'  
      BEGIN  
         SET @c_ResponseString = (SELECT @n_ErrNo AS [ErrNo]  
                                      , @c_ErrMsg AS [ErrMsg]   
                                 FOR XML PATH ('AppVersion'))     
           
      END  
  
  
   END            
      
   IF ISNULL(RTRIM(@c_ResponseString),'') = ''      
   BEGIN      
      SET @n_Continue = 3      
      SET @n_ErrNo = 30003      
      SET @c_ErrMsg = '@c_ResponseString is NULL or EMPTY! (isp_GTAutoUpdater_GetWSData)'     
   END      
      
   IF @n_Continue=3  -- Error Occured - Process And Return            
   BEGIN            
      SELECT @b_success = 0            
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartCnt            
      BEGIN                     
         ROLLBACK TRAN            
      END            
      ELSE            
      BEGIN            
         WHILE @@TRANCOUNT > @n_StartCnt            
         BEGIN            
            COMMIT TRAN            
         END            
      END         
      
      IF @b_Debug = 1      
      BEGIN      
         PRINT(@c_ResponseString)      
      END      
      
      RETURN            
   END            
   ELSE            
   BEGIN      
      IF ISNULL(RTRIM(@c_ErrMsg), '') <> ''  
      BEGIN      
         SELECT @b_Success = 0      
      END      
      ELSE      
      BEGIN       
         SELECT @b_Success = 1       
      END              
      
      WHILE @@TRANCOUNT > @n_StartCnt            
      BEGIN            
         COMMIT TRAN            
      END           
            
      IF @b_Debug = 1      
      BEGIN      
         PRINT(@c_ResponseString)      
      END      
      RETURN      
   END      
   /***********************************************/      
   /* Std - Error Handling (End)                  */      
   /***********************************************/      
END  --End Procedure

GO