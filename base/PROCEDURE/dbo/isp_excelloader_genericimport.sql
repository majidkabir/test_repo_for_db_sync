SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/    
/* Stored Procedure: isp_ExcelLoader_GenericImport                       */    
/* Creation Date: 27 Jun 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GHChan                                                    */    
/*                                                                       */    
/* Purpose: Generic Import Stored Procedure (Main StorProc)              */    
/*                                                                       */    
/* Called By:  Excel Loader                                              */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 27-Jun-2019  GHChan   1.0  Initial Development                        */    
/*************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_ExcelLoader_GenericImport](        
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
    
   DECLARE @n_Continue          INT             = 1
         , @n_StartCnt          INT             = @@TRANCOUNT
         , @n_EIMOpID           INT             = 0
         , @c_STGTableName      NVARCHAR(255)   = ''   
         , @c_POSTTableName     NVARCHAR(255)   = ''
         , @c_PrimaryKey        NVARCHAR(2000)  = ''
         , @c_ActionType        CHAR(1)         = '0'
         , @n_BatchNo           INT             = -1
         , @n_Offset            INT             = -1
         , @n_Limit             INT             = -1

   SET @b_Success          = 0      
    
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
   DECLARE @t_RequestString TABLE (      
     BatchNo        INT            NULL DEFAULT -1 
    ,EIMOpID        INT            NULL DEFAULT 0
    ,STGTableName   NVARCHAR(300)  NULL DEFAULT ''      
    ,POSTTableName  NVARCHAR(300)  NULL DEFAULT ''  
    ,PrimaryKey     NVARCHAR(2000) NULL DEFAULT ''  
    ,ActionType     CHAR(1)        NULL DEFAULT ''  
    ,[Offset]       INT            NULL DEFAULT -1  
    ,[Limit]        INT            NULL DEFAULT -1  
   )       
   
   BEGIN TRY    
      INSERT INTO @t_RequestString (BatchNo,EIMOpID,STGTableName,POSTTableName,PrimaryKey,ActionType,Offset,Limit)      
         SELECT BatchNo,EIMOpID,STGTableName,POSTTableName,PrimaryKey,ActionType,Offset,Limit      
         FROM OPENJSON(@c_RequestString,'$.MainData')      
         WITH ( BatchNo       INT           '$.BatchNo'
               ,EIMOpID       INT           '$.EIMOpID'
               ,STGTableName  NVARCHAR(300) '$.STGTableName'      
               ,POSTTableName NVARCHAR(300) '$.POSTTableName'  
               ,PrimaryKey    NVARCHAR(2000)'$.PrimaryKey'  
               ,ActionType    CHAR(1)       '$.ActionType'  
               ,Offset        INT           '$.offset'  
               ,Limit         INT           '$.limit'  
         )   
   END TRY    
   BEGIN CATCH   
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = ERROR_NUMBER()  
      SET @c_ErrMsg = N'Error Insert Data into Temporary Table. e.g. Invalid JSON Format or Data cannot be null.'+
                      N'(isp_ExcelLoader_GenericImport)'
      GOTO QUIT    
   END CATCH    
    
   SELECT TOP 1   @n_EIMOpID=EIMOpID,           @c_STGTableName =STGTableName,            @c_POSTTableName =POSTTableName, 
                  @c_PrimaryKey = PrimaryKey,   @c_ActionType = ActionType,               @n_BatchNo = BatchNo, 
                  @n_Offset=Offset,             @n_Limit=Limit    
   FROM @t_RequestString  
     
   IF ISNULL(RTRIM(@c_STGTableName),'') = '' AND ISNULL(RTRIM(@c_POSTTableName),'') = ''    
   BEGIN      
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 630001  
      SET @c_ErrMsg = 'Staging or Post TableName Cannot be Null or Empty.([isp_ExcelLoader_GenericImport])'    
      GOTO QUIT  
   END  
  
   IF ISNULL(RTRIM(@c_STGTableName),'') <> '' AND ISNULL(RTRIM(@c_POSTTableName),'') = ''       
   BEGIN   
      BEGIN TRY    
         EXEC [dbo].[isp_ExcelLoader_Insert_STG]  
              @c_RequestString  
            , @c_STGTableName  
            , @b_Debug       
            , @b_Success         OUTPUT      
            , @n_ErrNo           OUTPUT      
            , @c_ErrMsg          OUTPUT      
         
         IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END 
      END TRY    
      BEGIN CATCH      
         SET @n_Continue = 3    
         SET @n_ErrNo = ERROR_NUMBER()    
         SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_GenericImport)'    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_ExcelLoader_GenericImport]: Execute [dbo].[isp_ExcelLoader_Insert_STG] Failed...'     
                  + ' @c_ErrMsg=' + @c_ErrMsg    
         END    
         GOTO QUIT    
      END CATCH     
      
   END  
   ELSE IF ISNULL(RTRIM(@c_STGTableName),'') <> '' AND ISNULL(RTRIM(@c_POSTTableName),'') <> ''    
   BEGIN  
      BEGIN TRY  
         IF @n_BatchNo <= 0   
         BEGIN  
            SET @n_Continue = 3    
            SET @n_ErrNo = 630002  
            SET @c_ErrMsg = 'BatchNo Cannot Be Less Than or Equal 0!(isp_ExcelLoader_GenericImport)'  
            GOTO QUIT  
         END
         
         IF @n_EIMOpID <= 0
         BEGIN
            SET @n_Continue = 3    
            SET @n_ErrNo = 630003  
            SET @c_ErrMsg = 'EIMOpID Cannot Be Less Than or Equal 0!(isp_ExcelLoader_GenericImport)'  
            GOTO QUIT
         END
  
         EXEC [dbo].[isp_ExcelLoader_POST]  
              @n_BatchNo  
            , @n_EIMOpID
            , @c_STGTableName  
            , @c_POSTTableName  
            , @c_PrimaryKey  
            , @c_ActionType  
            , @n_Offset  
            , @n_Limit  
            , @b_Debug       
            , @b_Success         OUTPUT      
            , @n_ErrNo           OUTPUT      
            , @c_ErrMsg          OUTPUT
            
         IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg), '') <> ''
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END              
      END TRY    
      BEGIN CATCH       
         SET @n_Continue = 3
         SET @b_Success = 0
         SET @n_ErrNo = ERROR_NUMBER()    
         SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_GenericImport)'    
                   
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_ExcelLoader_GenericImport]: Execute [dbo].[isp_ExcelLoader_POST] SP Failed...'     
                  + ' @c_ErrMsg=' + @c_ErrMsg    
         END    
         GOTO QUIT    
      END CATCH        
   END    
           
QUIT:  
   IF @n_Continue = 3    
   BEGIN    
      SET @c_ResponseString = N' { "Response": "File Uploaded Unsuccessful!",'
                            + N' "ErrorNo": "' +CAST(@n_ErrNo AS NVARCHAR(10)) + '",'
                            + N' "ErrMessage": "' + @c_ErrMsg + '"}'     
      --SET @c_ResponseString = (    
      --      SELECT [No], [Status] FROM @t_RequestShipmentProfile ORDER BY [No] ASC    
      --      FOR JSON PATH, ROOT('Data')    
      --      )    
      --SET @c_ResponseString = SUBSTRING(@c_ResponseString, 2, LEN(@c_ResponseString) -2)    
      --IF EXISTS(SELECT 1 FROM @t_RequestShipmentProfile WHERE [No] = 1)    
      --BEGIN    
      --   SET @c_ResponseString = '{' + @c_ResponseString + ',"TypeofStorProc":"INSERT"' + '}'    
      --END    
   END    
   ELSE     
   BEGIN    
       SET @c_ResponseString = N' { "Response": "File Uploaded Successfully!",'
                             + N' "ErrorNo": "",'
                             + N' "ErrMessage": ""}'        
   END          
    
   IF ISNULL(@c_ResponseString,'') = ''    
   BEGIN    
      SET @n_Continue = 3    
      SET @n_ErrNo = 630004    
      SET @c_ErrMsg = '@c_ResponseString is EMPTY! (isp_ExcelLoader_GenericImport)'   
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