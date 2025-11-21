SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/    
/* Stored Procedure: isp_ExcelLoader_POST                                */    
/* Creation Date: 24 Oct 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GHChan                                                    */    
/*                                                                       */    
/* Purpose: Insert records into POST Table                               */    
/*                                                                       */    
/* Called By:  Excel Loader                                              */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 24-Oct-2019  GHChan   1.0  Initial Development                        */    
/*************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_ExcelLoader_POST](    
    @n_BatchNo          INT               = 0
   ,@n_EIMOpID          INT               = 0
   ,@c_STGTableName     NVARCHAR(255)     = ''  
   ,@c_POSTTableName    NVARCHAR(255)     = ''  
   ,@c_PrimaryKey       NVARCHAR(2000)    = ''  
   ,@c_ActionType       CHAR(1)           = ''  
   ,@n_Offset           INT               = 0
   ,@n_Limit            INT               = 0
   ,@b_Debug            INT               = 0    
   ,@b_Success          INT               = 0    OUTPUT    
   ,@n_ErrNo            INT               = 0    OUTPUT    
   ,@c_ErrMsg           NVARCHAR(250)     = ''   OUTPUT    
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
    
   DECLARE @n_Continue    INT            = 1
          ,@n_StartCnt    INT            = @@TRANCOUNT
          ,@SQL           NVARCHAR(MAX)  = ''
           
   SET @b_Success = 1
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
   
   IF @n_BatchNo < 0
   BEGIN  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 630003    
      SET @c_ErrMsg = 'Invalid Batch No. (isp_ExcelLoader_POST)'    
      GOTO QUIT  
   END  
   IF @n_Offset < 0 OR @n_Limit <= 0
   BEGIN  
      SET @SQL = 'SELECT @n_Count=COUNT(1) FROM ' + @c_STGTableName + ' WITH (NOLOCK) WHERE STG_BatchNo = @n_BatchNo'  
      EXEC sp_executesql @SQL, N'@n_BatchNo INT, @n_Count INT OUTPUT', @n_BatchNo, @n_Count = @n_Limit OUTPUT  
   
      SET @n_Offset =0  
   END  
   
   --IF ISNULL(RTRIM(@c_PrimaryKey), '') = ''  
   --BEGIN  
   --   SET @n_Continue = 3
   --   SET @b_Success = 0
   --   SET @n_ErrNo = 630004   
   --   SET @c_ErrMsg = 'Primary Key Field is null! (isp_ExcelLoader_POST)'   
   --   GOTO QUIT  
   --END 

   IF @n_EIMOpID <= 0
   BEGIN
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = 630005
      SET @c_ErrMsg = 'EIMOpID not found. (isp_ExcelLoader_POST)'    
      GOTO QUIT 
   END

   IF EXISTS (SELECT 1 FROM [GTApps].[dbo].[ExcelLoader_BusinessLogic] WITH (NOLOCK) WHERE EIMOpID = @n_EIMOpID AND Flag =1)
   BEGIN
      BEGIN TRY
         EXEC [dbo].[isp_ExcelLoader_MainRule]
               @n_BatchNo      
            ,  @n_EIMOpID      
            ,  @c_STGTableName 
            ,  @c_POSTTableName
            ,  @c_PrimaryKey   
            ,  @c_ActionType   
            ,  @n_Offset       
            ,  @n_Limit        
            ,  @b_Debug          
            ,  @b_Success OUTPUT  
            ,  @n_ErrNo   OUTPUT  
            ,  @c_ErrMsg  OUTPUT 

         IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END

      END TRY 
      BEGIN CATCH
         SET @n_Continue = 3 
         SET @b_Success = 0
         SET @n_ErrNo = ERROR_NUMBER()    
         SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_MainRule] SP Failed...'
                  + ' @c_ErrMsg=' + @c_ErrMsg    
         END    
      END CATCH
   END
   
   BEGIN TRY  
      IF @c_ActionType = '1'  
      BEGIN  
         BEGIN TRY  
            EXEC [dbo].[isp_ExcelLoader_DelInsert]  
                  @c_STGTableName   
               ,  @c_POSTTableName  
               ,  @n_BatchNo        
               ,  @n_Offset         
               ,  @n_Limit          
               ,  @b_Debug          
               ,  @b_Success OUTPUT  
               ,  @n_ErrNo   OUTPUT  
               ,  @c_ErrMsg  OUTPUT  

            IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT
            END
                 
         END TRY  
         BEGIN CATCH  
            SET @n_Continue = 3
            SET @b_Success = 0
            SET @n_ErrNo = ERROR_NUMBER()    
            SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_DelInsert] SP Failed...'     
                     + ' @c_ErrMsg=' + @c_ErrMsg    
            END    
            GOTO QUIT   
         END CATCH  
      END  
      ELSE IF @c_ActionType = '2'  
      BEGIN  
         BEGIN TRY  
            EXEC [dbo].[isp_ExcelLoader_UpdateInsert]  
                  @c_STGTableName   
               ,  @c_POSTTableName  
               ,  @c_PrimaryKey       
               ,  @n_BatchNo        
               ,  @n_Offset         
               ,  @n_Limit          
               ,  @b_Debug          
               ,  @b_Success OUTPUT  
               ,  @n_ErrNo   OUTPUT  
               ,  @c_ErrMsg  OUTPUT
               
            IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT
            END

         END TRY  
         BEGIN CATCH  
            SET @n_Continue = 3 
            SET @b_Success = 0
            SET @n_ErrNo = ERROR_NUMBER()    
            SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_UpdateInsert] SP Failed...'     
                     + ' @c_ErrMsg=' + @c_ErrMsg    
            END    
            GOTO QUIT   
         END CATCH  
      END  
      ELSE IF @c_ActionType = '3'  
      BEGIN  
         BEGIN TRY  
            EXEC [dbo].[isp_ExcelLoader_DelPartitionInsert]  
                  @c_STGTableName   
               ,  @c_POSTTableName  
               ,  @c_PrimaryKey      
               ,  @n_BatchNo        
               ,  @n_Offset         
               ,  @n_Limit          
               ,  @b_Debug          
               ,  @b_Success OUTPUT  
               ,  @n_ErrNo   OUTPUT  
               ,  @c_ErrMsg  OUTPUT
               
            IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT
            END

         END TRY  
         BEGIN CATCH  
            SET @n_Continue = 3
            SET @b_Success = 0
            SET @n_ErrNo = ERROR_NUMBER()    
            SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_DelPartitionInsert] SP Failed...'     
                     + ' @c_ErrMsg=' + @c_ErrMsg    
            END    
            GOTO QUIT   
         END CATCH  
      END  
      ELSE IF @c_ActionType = '4'  
      BEGIN  
         BEGIN TRY  
            EXEC [dbo].[isp_ExcelLoader_IgnoreDup_Insert]  
                  @c_STGTableName   
               ,  @c_POSTTableName  
               ,  @c_PrimaryKey      
               ,  @n_BatchNo        
               ,  @n_Offset         
               ,  @n_Limit          
               ,  @b_Debug          
               ,  @b_Success OUTPUT  
               ,  @n_ErrNo   OUTPUT  
               ,  @c_ErrMsg  OUTPUT              
         
            IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT
            END

         END TRY  
         BEGIN CATCH  
            SET @n_Continue = 3
            SET @b_Success = 0
            SET @n_ErrNo = ERROR_NUMBER()    
            SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_IgnoreDup_Insert] SP Failed...'     
                     + ' @c_ErrMsg=' + @c_ErrMsg    
            END    
            GOTO QUIT   
         END CATCH  
      END
      ELSE IF @c_ActionType = '5'  
      BEGIN  
         BEGIN TRY  
            EXEC [dbo].[isp_ExcelLoader_Insert]  
                  @c_STGTableName   
               ,  @c_POSTTableName  
               ,  @c_PrimaryKey      
               ,  @n_BatchNo        
               ,  @n_Offset         
               ,  @n_Limit          
               ,  @b_Debug          
               ,  @b_Success OUTPUT  
               ,  @n_ErrNo   OUTPUT  
               ,  @c_ErrMsg  OUTPUT              
         
            IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
            BEGIN
               SET @n_Continue = 3
               GOTO QUIT
            END

         END TRY  
         BEGIN CATCH  
            SET @n_Continue = 3
            SET @b_Success = 0
            SET @n_ErrNo = ERROR_NUMBER()    
            SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
            IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_Insert] SP Failed...'     
                     + ' @c_ErrMsg=' + @c_ErrMsg    
            END    
            GOTO QUIT   
         END CATCH  
      END
   
   END TRY  
   BEGIN CATCH  
      SET @n_Continue = 3
      SET @b_Success = 0
      SET @n_ErrNo = ERROR_NUMBER()  
      SET @c_ErrMsg = ERROR_MESSAGE() + '(isp_ExcelLoader_POST)'
      IF @b_Debug = 1    
            BEGIN    
               PRINT '[isp_ExcelLoader_POST]: Main TryCatch ERROR...'     
                     + ' @c_ErrMsg=' + @c_ErrMsg    
            END
      GOTO QUIT  
   END CATCH   
  
  IF EXISTS (SELECT 1 FROM [GTApps].[dbo].[ExcelLoader_BusinessLogic] WITH (NOLOCK) WHERE EIMOpID = @n_EIMOpID  AND Flag = 2)
   BEGIN
      BEGIN TRY
         EXEC [dbo].[isp_ExcelLoader_SecondMainRule]
               @n_BatchNo      
            ,  @n_EIMOpID      
            ,  @c_STGTableName 
            ,  @c_POSTTableName
            ,  @c_PrimaryKey   
            ,  @c_ActionType   
            ,  @n_Offset       
            ,  @n_Limit        
            ,  @b_Debug          
            ,  @b_Success OUTPUT  
            ,  @n_ErrNo   OUTPUT  
            ,  @c_ErrMsg  OUTPUT 

         IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
         BEGIN
            SET @n_Continue = 3
            GOTO QUIT
         END

      END TRY 
      BEGIN CATCH
         SET @n_Continue = 3 
         SET @b_Success = 0
         SET @n_ErrNo = ERROR_NUMBER()    
         SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_POST)'    
         IF @b_Debug = 1    
         BEGIN    
            PRINT '[isp_ExcelLoader_POST]: Execute [dbo].[isp_ExcelLoader_SecondMainRule] SP Failed...'
                  + ' @c_ErrMsg=' + @c_ErrMsg    
         END    
      END CATCH
   END

QUIT:    
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
      RETURN          
   END          
   ELSE          
   BEGIN    
      IF ISNULL(RTRIM(@c_ErrMsg),'') <> ''
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
      RETURN    
   END    
   /***********************************************/    
   /* Std - Error Handling (End)                  */    
   /***********************************************/    
END  --End Procedure

GO