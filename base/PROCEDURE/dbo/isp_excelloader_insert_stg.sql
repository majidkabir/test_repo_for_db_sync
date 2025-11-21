SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/    
/* Stored Procedure: isp_ExcelLoader_Insert_STG                          */    
/* Creation Date: 11 Oct 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GHChan                                                    */    
/*                                                                       */    
/* Purpose: Insert STG records into  DB                                  */    
/*                                                                       */    
/* Called By:  Excel Loader                                              */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 11-Oct-2019  GHChan   1.0  Initial Development                        */    
/*************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_ExcelLoader_Insert_STG](    
    @c_Data             NVARCHAR(MAX)     = ''  
   ,@c_TableName        NVARCHAR(255)     = ''  
   ,@b_Debug            INT               =0    
   ,@b_Success          INT               =0    OUTPUT    
   ,@n_ErrNo            INT               =0    OUTPUT    
   ,@c_ErrMsg           NVARCHAR(250)     = ''  OUTPUT    
)   
AS     
BEGIN    
    
    SET NOCOUNT ON    
    SET ANSI_DEFAULTS OFF     
    SET QUOTED_IDENTIFIER OFF    
    SET CONCAT_NULL_YIELDS_NULL ON    
    SET ANSI_WARNINGS ON    
    SET ANSI_PADDING ON    
        
    /*********************************************/    
    /* Variables Declaration (Start)             */    
    /*********************************************/    
    
    DECLARE  @n_Continue         INT    
           , @n_StartCnt         INT    
           , @SQL              NVARCHAR(MAX)  
             
   SET @SQL = ''  
   SET @n_Continue = 1    
   SET @n_StartCnt = @@TRANCOUNT    
   SET @b_Success = 0    
   SET @n_ErrNo = 0    
   SET @c_ErrMsg = ''    
       
   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/    
  
   BEGIN TRY  
        
      IF ISNULL(RTRIM(@c_Data), '') = ''  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_ErrNo = 730001  
         SET @c_ErrMsg = '@c_Data IS EMPTY OR NULL! (isp_ExcelLoader_Insert_STG)'  
         GOTO QUIT   
      END  
  
      EXEC dbo.isp_ExcelLoader_LoadSTGTable  
      @json=@c_Data,  
      @c_TableName = @c_TableName,  
      @SQL = @SQL OUTPUT  
  
      IF @@TRANCOUNT < @n_StartCnt        
         BEGIN TRAN   
  
      IF @b_Debug = 1  
         PRINT @SQL  
  
      EXEC sp_ExecuteSQL  @SQL, N' @json NVARCHAR(MAX)', @c_Data    
        
   END TRY  
   BEGIN CATCH  
      SET @n_Continue = 3  
      SET @n_ErrNo = ERROR_NUMBER()  
      SET @c_ErrMsg = ERROR_MESSAGE() + '(isp_ExcelLoader_Insert_STG)'  
      GOTO QUIT  
   END CATCH  
  
QUIT:    
   IF @n_Continue IN (1,2)    
   BEGIN    
      WHILE @@TRANCOUNT > @n_StartCnt    
         COMMIT TRAN    
   END    
   ELSE IF @n_Continue=3  -- Error Occured - Process And Return          
   BEGIN          
      SELECT @b_success = 0          
      IF @@TRANCOUNT > @n_StartCnt          
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
      IF @c_ErrMsg <> ''     
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
          
      --IF @b_Debug = 1    
      --BEGIN    
      --   PRINT(@c_ReturnedData)    
      --END    
      RETURN    
   END    
   /***********************************************/    
   /* Std - Error Handling (End)                  */    
   /***********************************************/    
END  --End Procedure

GO