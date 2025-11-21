SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/*************************************************************************/  
/* Stored Procedure: isp_EXG_Main                                        */  
/* Creation Date: 18-Feb-2021                                            */  
/* Copyright: LFL                                                        */  
/* Written by: GuanHao Chan                                              */  
/*                                                                       */  
/* Purpose: Excel Generator Main StorProc to call Sub StorProc           */  
/*                                                                       */  
/* Called By:  ExcelGenerator                                            */  
/*                                                                       */  
/* PVCS Version: -                                                       */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date          Author   Ver  Purposes                                  */  
/* 18-Feb-2021  GHChan   1.0  Initial Development                        */  
/*************************************************************************/  
  
CREATE PROCEDURE [dbo].[isp_EXG_Main]  
(  @c_FileKeyList NVARCHAR(500)  = ''  
,  @b_Debug       INT            = 1  
,  @b_Success     INT            = 1   OUTPUT  
,  @n_Err         INT            = 0   OUTPUT  
,  @c_ErrMsg      NVARCHAR(250)  = ''  OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   /*********************************************/  
   /* Variables Declaration (Start)             */  
   /*********************************************/  
  
   DECLARE @n_Continue     INT           = 1  
         , @n_StartTcnt    INT           = @@TRANCOUNT  
         , @n_ITFErr       INT           = 0  
         , @c_ITFErrMsg    NVARCHAR(250) = ''  
           
         , @c_SPName       NVARCHAR(200) = ''  
         , @c_ReportSheet  NVARCHAR(100) = ''  
           
         , @n_FileKey      INT           = 0  
         , @n_EXG_Hdr_ID   INT           = 0  
         , @c_FileName     NVARCHAR(255) = ''  
         , @c_ValidPVal1   NVARCHAR(200) = ''  
         , @c_ValidPVal2   NVARCHAR(200) = ''  
         , @c_ValidPVal3   NVARCHAR(200) = ''  
         , @c_ValidPVal4   NVARCHAR(200) = ''  
         , @c_ValidPVal5   NVARCHAR(200) = ''  
         , @c_ValidPVal6   NVARCHAR(200) = ''  
         , @c_ValidPVal7   NVARCHAR(200) = ''  
         , @c_ValidPVal8   NVARCHAR(200) = ''  
         , @c_ValidPVal9   NVARCHAR(200) = ''  
         , @c_ValidPVal10  NVARCHAR(200) = ''  
         , @c_Delimiter    NVARCHAR(2)   = ''  
  
   /*********************************************/  
   /* Variables Declaration (End)               */  
   /*********************************************/  
  
   IF @b_Debug = 1  
   BEGIN  
      PRINT '[dbo].[isp_EXG_Main]: Start...'  
      PRINT '[dbo].[isp_EXG_Main]: '  
          + ' @c_FileKeyList=' + ISNULL(RTRIM(@c_FileKeyList), '')  
   END  
  
      IF(ISNULL(RTRIM(@c_FileKeyList), '') = '')  
      BEGIN  
         SET @n_Err = 100002  
         SET @c_ErrMsg = 'List of FileKey not Found! (isp_EXG_Main)'  
         SET @n_Continue = 3  
         GOTO QUIT  
      END  
  
      IF NOT EXISTS (SELECT 1 FROM string_split(@c_FileKeyList, ','))  
      BEGIN  
         SET @n_Err = 100003  
         SET @c_ErrMsg = 'Invalid List of File Key. Unable to split the file key. (isp_EXG_Main)'  
         SET @n_Continue = 3  
         GOTO QUIT  
      END  
  
   BEGIN TRY      
      DECLARE C_FILEKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT [file_key]  
           , [EXG_Hdr_ID]  
           , [filename]  
           , [ParamVal1]  
           , [ParamVal2]  
           , [ParamVal3]  
           , [ParamVal4]  
           , [ParamVal5]  
           , [ParamVal6]  
           , [ParamVal7]  
           , [ParamVal8]  
          , [ParamVal9]  
           , [ParamVal10]  
           , [Delimiter]  
      FROM [dbo].[EXG_FileHdr] WITH (NOLOCK)  
      WHERE file_key IN (SELECT value FROM string_split(@c_FileKeyList, ','))  
      ORDER BY file_key ASC  
  
      OPEN C_FILEKEY  
      FETCH NEXT FROM C_FILEKEY INTO  @n_FileKey  
                                    , @n_EXG_Hdr_ID  
                                    , @c_FileName  
                                    , @c_ValidPVal1   
                                    , @c_ValidPVal2   
                                    , @c_ValidPVal3   
                                    , @c_ValidPVal4   
                                    , @c_ValidPVal5   
                                    , @c_ValidPVal6   
                                    , @c_ValidPVal7   
                                    , @c_ValidPVal8   
                                    , @c_ValidPVal9   
                                    , @c_ValidPVal10  
                                    , @c_Delimiter  
      WHILE(@@FETCH_STATUS <> -1)  
      BEGIN  
           
         --UPDATE [CNWMS].[dbo].[EXG_FileHdr]  
         --SET [status] = '1'  
         --WHERE file_key = @n_FileKey  
  
         BEGIN TRY  
            DECLARE C_TEMPSTORPROC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT SPName, Report_Sheet FROM [GTApps].[dbo].[EXG_Det]  WITH (NOLOCK)  
            WHERE EXG_Hdr_ID = @n_EXG_Hdr_ID  
  
            OPEN C_TEMPSTORPROC  
            FETCH NEXT FROM C_TEMPSTORPROC INTO @c_SPName,@c_ReportSheet  
  
            WHILE (@@FETCH_STATUS <> -1)  
            BEGIN  
              
               EXEC @c_SPName  
                    @n_FileKey  
                  , @n_EXG_Hdr_ID  
                  , @c_FileName   
                  , @c_ReportSheet  
                  , @c_Delimiter  
                  , @c_ValidPVal1   
                  , @c_ValidPVal2   
                  , @c_ValidPVal3   
                  , @c_ValidPVal4   
                  , @c_ValidPVal5   
                  , @c_ValidPVal6   
                  , @c_ValidPVal7   
                  , @c_ValidPVal8   
                  , @c_ValidPVal9   
                  , @c_ValidPVal10  
                  , @b_Debug   
                  , @b_Success         OUTPUT  
                  , @n_Err             OUTPUT  
                  , @c_ErrMsg          OUTPUT  
  
  
             IF ISNULL(RTRIM(@c_ErrMsg), '') <> '' OR @b_Success = 0  
             BEGIN  
              BREAK   
              GOTO QUIT  
             END  
      
                  FETCH NEXT FROM C_TEMPSTORPROC INTO @c_SPName, @c_ReportSheet  
            END    
            CLOSE C_TEMPSTORPROC    
            DEALLOCATE C_TEMPSTORPROC    
         END TRY  
         BEGIN CATCH  
            SET @n_Err = ERROR_NUMBER()  
            SET @c_ErrMsg = ERROR_MESSAGE() + '[isp_EXG_Main]'  
            SET @b_Success = 0  
         END CATCH  
  
         IF ISNULL(RTRIM(@c_ErrMsg), '') <> '' OR @b_Success = 0  
       BEGIN  
            SET @n_Err = @n_Err  
            SET @c_ErrMsg = @c_ErrMsg  
            SET @n_Continue = 3  
            UPDATE [dbo].[EXG_FileHdr] WITH (ROWLOCK)  
            SET [status] = '5'  
            WHERE file_key = @n_FileKey  
  
            UPDATE [dbo].[EXG_FileDet]  WITH (ROWLOCK)  
            SET [Status] = '5'  
            WHERE file_key = @n_FileKey  
  
        BREAK   
        GOTO QUIT  
       END  
  
          UPDATE [dbo].[EXG_FileDet]  WITH (ROWLOCK)  
         SET [status] = '0'  
         WHERE file_key = @n_FileKey  
  
         UPDATE [dbo].[EXG_FileHdr]  WITH (ROWLOCK)  
         SET [status] = '0'  
         WHERE file_key = @n_FileKey  
  
         FETCH NEXT FROM C_FILEKEY INTO   @n_FileKey  
                                        , @n_EXG_Hdr_ID  
                                        , @c_FileName  
                                        , @c_ValidPVal1   
                                        , @c_ValidPVal2   
                                        , @c_ValidPVal3   
                                    , @c_ValidPVal4   
                                        , @c_ValidPVal5   
                                        , @c_ValidPVal6   
                                        , @c_ValidPVal7   
                                        , @c_ValidPVal8   
                                        , @c_ValidPVal9   
                                        , @c_ValidPVal10  
                                        , @c_Delimiter  
      END  
      CLOSE C_FILEKEY    
      DEALLOCATE C_FILEKEY  
   END TRY  
   BEGIN CATCH  
      WHILE @@TRANCOUNT > 0  
         ROLLBACK TRAN  
           
      SELECT @n_ITFErr = ERROR_NUMBER(), @c_ITFErrMsg = ERROR_MESSAGE()  
           
      SET @n_Err = @n_ITFErr  
      SET @c_ErrMsg = LTRIM(RTRIM(@c_ITFErrMsg)) + ' (isp_EXG_Main)'  
                 
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[isp_EXG_Main]: Execute SP Name Failed...'   
               + ' @c_ErrMsg=' + @c_ErrMsg  
      END  
      GOTO QUIT  
   END CATCH  
     
      
  
   QUIT:  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   WHILE @@TRANCOUNT < @n_StartTCnt        
      BEGIN TRAN   
  
   IF @n_Continue=3  -- Error Occured - Process And Return        
   BEGIN        
      SELECT @b_success = 0        
      IF @@TRANCOUNT > @n_StartTCnt        
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
  
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_Main]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_Main]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
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
      --   SELECT   
      --     FileDET.file_key  
      --   , FileDET.SeqNo  
      --   , FileDET.EXG_Hdr_ID  
      --   , CONCAT(Hdr.TargetFolder,'\',FileDET.[FileName]) AS FilePath  
      --   , FileDET.SheetName  
      --   , FileDET.LineText1  
      --   , FileDET.LineText2  
      --   , Hdr.FileExtension  
      --   , Hdr.Delimiter  
      --FROM [GTApps].[dbo].[EXG_FileDet] FileDET WITH (NOLOCK)  
      --INNER JOIN [GTApps].[dbo].[EXG_Hdr] Hdr WITH (NOLOCK)  
      --ON Hdr.EXG_Hdr_ID = FileDET.EXG_Hdr_ID  
      --WHERE file_key IN (SELECT file_key FROM @Temp_FileKey)  
      --AND [Status] = '0'  
      --ORDER BY file_key ASC, SeqNo ASC  
      END          
  
      WHILE @@TRANCOUNT > @n_StartTCnt        
      BEGIN        
         COMMIT TRAN        
      END       
        
      IF @b_Debug = 1  
      BEGIN  
         PRINT '[dbo].[isp_EXG_Main]: @c_ErrMsg=' + RTRIM(@c_ErrMsg)  
         PRINT '[dbo].[isp_EXG_Main]: @b_Success=' + RTRIM(CAST(@b_Success AS NVARCHAR))  
      END        
      RETURN        
   END          
   /***********************************************/        
   /* Std - Error Handling (End)                  */        
   /***********************************************/      
END --End Procedure  
  

GO