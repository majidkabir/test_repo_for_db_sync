SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_Build_Wave_VLDN                                 */                                                                                  
/* Creation Date:                                                       */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-3672 - [CN] LOREAL_New Tab for order analysis          */                                                                                  
/*                                                                      */                                                                                  
/* Called By: SCE                                                       */                                                                                  
/*          :                                                           */                                                                                  
/* PVCS Version: 1.0                                                    */                                                                                  
/*                                                                      */                                                                                  
/* Version: 8.0                                                         */                                                                                  
/*                                                                      */                                                                                  
/* Data Modifications:                                                  */                                                                                  
/*                                                                      */                                                                                  
/* Updates:                                                             */                                                                                  
/* Date        Author   Ver.  Purposes                                  */  
/* 2022-08-08  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_Build_Wave_VLDN]                                                                                                                       
      @c_BuildParmKey      NVARCHAR(10)                                                                                                                    
   ,  @b_Success           INT            = 1  OUTPUT  
   ,  @n_err               INT            = 0  OUTPUT                                                                                                             
   ,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT 
   ,  @b_debug             INT            = 0                                                                                                                              
AS 
BEGIN
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF                                                                                                                          
   
   DECLARE @n_Continue              INT = 1
         , @n_StartTCnt             INT = @@TRANCOUNT
         
         , @b_MutlipleValue         BIT = 0
         , @c_BuildValue            NVARCHAR(4000) = ''
         
   DECLARE @t_RETURNVALUE           TABLE
         ( InSQLValue               NVARCHAR(255) )               
         
   IF EXISTS ( SELECT 1 FROM BUILDPARMPREWAVE AS b WITH (NOLOCK)
               WHERE b.BuildParmKey = @c_BuildParmKey
   )
   BEGIN
      IF NOT EXISTS (SELECT 1 FROM BUILDPREWAVE AS b WITH (NOLOCK) WHERE b.BuildParmKey = @c_BuildParmKey
                     AND b.[Status] = '1'
                     )
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560751
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': Pre Wave record not found. (lsp_Build_Wave_VLDN)' 
         GOTO EXIT_SP
      END
   END
   
   IF EXISTS ( SELECT 1 FROM dbo.BUILDPARMDETAIL AS b WITH (NOLOCK)
               WHERE b.BuildParmKey = @c_BuildParmKey
               AND b.[Type] = 'Edit'
               AND b.Operator NOT IN ( '=', 'IN', 'IN SQL' )
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 560752
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': Invalid Operator type for Edit Type. (lsp_Build_Wave_VLDN)' 
      GOTO EXIT_SP
   END
   
   IF EXISTS ( SELECT 1 FROM dbo.BUILDPARMDETAIL AS b WITH (NOLOCK)
               WHERE b.BuildParmKey = @c_BuildParmKey
               AND b.[Type] = 'Edit'
               AND b.BuildValue = ''
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 560753
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': BuildValue is required for Edit Type. (lsp_Build_Wave_VLDN)' 
      GOTO EXIT_SP
   END
      
   IF EXISTS ( SELECT 1 FROM dbo.BUILDPARMDETAIL AS b WITH (NOLOCK)
               WHERE b.BuildParmKey = @c_BuildParmKey
               AND b.[Type] = 'Edit'
               AND b.Operator IN ( 'IN' )
               AND b.BuildValue LIKE '%,%'
             )
   BEGIN
   	SET @b_MutlipleValue = 1
   END
   
   IF @b_MutlipleValue = 0
   BEGIN
      SELECT @c_BuildValue = b.BuildValue
      FROM dbo.BUILDPARMDETAIL AS b WITH (NOLOCK)
      WHERE b.BuildParmKey = @c_BuildParmKey
      AND b.[Type] = 'Edit'
      AND b.Operator IN ( 'IN SQL' )
   
      BEGIN TRY
         INSERT INTO @t_RETURNVALUE (InSQLValue)
         EXEC (@c_BuildValue)
   
         IF @@ROWCOUNT > 1
         BEGIN
            SET @b_MutlipleValue = 1 	
         END
      END TRY
      BEGIN CATCH
         SET @n_Continue = 3
         SET @n_Err = 560755
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': Insert Into @t_RETURNVALUE fail. (lsp_Build_Wave_VLDN)' 
         GOTO EXIT_SP
      END CATCH
   END

   IF @b_MutlipleValue = 1
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 560754
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6),@n_Err) + ': 1 Value is allow for Edit Type. (lsp_Build_Wave_VLDN)' 
      GOTO EXIT_SP
   END
  
   EXIT_SP:
   
   SET @b_Success = 1
   IF @n_Continue = 3
   BEGIN
   	SET @b_Success = 0
   END
END

GO