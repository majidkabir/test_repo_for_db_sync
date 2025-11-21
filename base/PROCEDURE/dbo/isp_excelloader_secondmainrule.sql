SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*************************************************************************/    
/* Stored Procedure: isp_ExcelLoader_SecondMainRule                      */    
/* Creation Date: 27 Nov 2019                                            */    
/* Copyright: LFL                                                        */    
/* Written by: GHChan                                                    */    
/*                                                                       */    
/* Purpose: Excel Loader Manage Sub Rule                                 */    
/*                                                                       */    
/* Called By:  Excel Loader                                              */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 27-Nov-2019  GHChan   1.0  Initial Development                        */    
/*************************************************************************/    
    
CREATE PROCEDURE [dbo].[isp_ExcelLoader_SecondMainRule](    
    @n_BatchNo          INT               = 0
   ,@n_EIMOpID          INT               = 0
   ,@c_STGTableName     NVARCHAR(255)     = ''  
   ,@c_POSTTableName    NVARCHAR(255)     = ''  
   ,@c_PrimaryKey       NVARCHAR(1000)    = ''  
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
   
   DECLARE @n_Continue          INT             = 1 
          ,@n_StartCnt          INT             = @@TRANCOUNT   
          ,@n_Step              INT             = 0
          ,@c_Bs_SubRule_SP     NVARCHAR(300)   = ''
          ,@c_ExecStatements    NVARCHAR(MAX)   = ''
          ,@c_ExecArguments     NVARCHAR(2000)  = ''

   SET @b_Success = 1 

   /*********************************************/    
   /* Variables Declaration (End)               */    
   /*********************************************/  
   
   BEGIN TRY
      DECLARE CURMR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT Step, Bs_SubRule_SP FROM [GTApps].[dbo].[ExcelLoader_BusinessLogic] WITH (NOLOCK)
      WHERE Flag = 2 AND EIMOpID = @n_EIMOpID 
      ORDER BY Step ASC
      
      OPEN CURMR

      FETCH FROM CURMR INTO @n_Step,@c_Bs_SubRule_SP

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         SET @c_ExecStatements = N'EXEC ' + @c_Bs_SubRule_SP
                               + N'  @n_BatchNo         = @n_BatchNo '
                               + N', @n_EIMOpID         = @n_EIMOpID '   
                               + N', @c_STGTableName    = @c_STGTableName ' 
                               + N', @c_POSTTableName   = @c_POSTTableName '       
                               + N', @c_PrimaryKey      = @c_PrimaryKey '         
                               + N', @c_ActionType      = @c_ActionType '        
                               + N', @n_Offset          = @n_Offset '
                               + N', @n_Limit           = @n_Limit '
                               + N', @b_Debug           = @b_Debug '
                               + N', @b_Success         = @b_Success OUTPUT'
                               + N', @n_ErrNo           = @n_ErrNo   OUTPUT'
                               + N', @c_ErrMsg          = @c_ErrMsg  OUTPUT'
                               
         SET @c_ExecArguments = N' @n_BatchNo           INT'          
                              + ', @n_EIMOpID           INT'          
                              + ', @c_STGTableName      NVARCHAR(255)'
                              + ', @c_POSTTableName     NVARCHAR(255)'
                              + ', @c_PrimaryKey        NVARCHAR(1000)'
                              + ', @c_ActionType        CHAR(1)'
		   							+ ', @n_Offset            INT'
                              + ', @n_Limit             INT'
                              + ', @b_Debug             INT'
                              + ', @b_Success           INT             OUTPUT'
		   							+ ', @n_ErrNo             INT             OUTPUT'
                              + ', @c_ErrMsg            NVARCHAR(250)   OUTPUT'        
                               
                               
         EXEC sp_ExecuteSql @c_ExecStatements
                          , @c_ExecArguments
                          , @n_BatchNo      
                          , @n_EIMOpID      
                          , @c_STGTableName 
                          , @c_POSTTableName
                          , @c_PrimaryKey   
                          , @c_ActionType   
                          , @n_Offset       
                          , @n_Limit        
                          , @b_Debug        
                          , @b_Success  OUTPUT    
                          , @n_ErrNo    OUTPUT    
                          , @c_ErrMsg   OUTPUT
         
         IF @n_ErrNo <> 0 OR ISNULL(RTRIM(@c_ErrMsg),'') <> ''
         BEGIN
            SET @n_Continue = 3
            --SET @n_ErrNo = @nErrNo
            --SET @c_ErrMsg = @c_ErrMsg
            BREAK
         END

         FETCH FROM CURMR INTO @n_Step,@c_Bs_SubRule_SP
      END
      CLOSE CURMR
      DEALLOCATE CURMR
   END  TRY
   BEGIN CATCH
      SET @n_Continue = 3    
      SET @n_ErrNo = ERROR_NUMBER()    
      SET @c_ErrMsg = LTRIM(RTRIM(ERROR_MESSAGE())) + ' (isp_ExcelLoader_SecondMainRule)'    
      IF @b_Debug = 1    
      BEGIN    
         PRINT '[isp_ExcelLoader_SecondMainRule]: Execute ' + @c_Bs_SubRule_SP + ' SP Failed...'     
               + ' @c_ErrMsg=' + @c_ErrMsg    
      END    
      GOTO QUIT 
   END CATCH
   

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
END --End Procedure

GO