SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: lsp_DoorBookAutoBuild_Wrapper                           */
/* Creation Date: 2022-04-13                                            */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: LFWM-3482 - UAT RG  Generate appointment & Generate booking */
/*        : SP creation                                                 */
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
/* Date        Author   Ver   Purposes                                  */
/* 2022-04-13  Wan      1.0   Created & DevOps Combine Script           */
/************************************************************************/
CREATE PROC [WM].[lsp_DoorBookAutoBuild_Wrapper]
      @c_Facility          NVARCHAR(5)                
   ,  @c_Storerkey         NVARCHAR(15)              
   ,  @b_Success           INT = 1             OUTPUT
   ,  @n_Err               INT = 0             OUTPUT
   ,  @c_ErrMsg            NVARCHAR(255)  = '' OUTPUT
   ,  @c_UserName          NVARCHAR(128)  = ''  
   ,  @n_ErrGroupKey       INT            = 0  OUTPUT  
   ,  @b_debug             INT            = 0            --Debug mode. Pass in 0 by App, used to trace issue by manualy run SP 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt                INT            = @@TRANCOUNT
         , @n_Continue                 INT            = 1
         
         , @c_TableName                NVARCHAR(50)   = 'DoorBookingAutoBuild'
         , @c_SourceType               NVARCHAR(50)   = 'lsp_DoorBookAutoBuild_Wrapper'
                                       
         , @c_SQL                      NVARCHAR(4000) = ''
         , @c_SQLWhere                 NVARCHAR(1000) = ''
         , @c_SQLGrpFieldName          NVARCHAR(1000) = ''
         , @c_SQLParms                 NVARCHAR(4000) = ''
                                 
         , @c_DoorBookingStrategyKey   NVARCHAR(10)   = ''
         , @c_SPCode                   NVARCHAR(30)   = ''
         
         , @CUR_STRATEGY               CURSOR           
   
   BEGIN TRY      
      SET @n_Err = 0  
   
      IF SUSER_SNAME() <> @c_UserName     
      BEGIN 
         EXEC [WM].[lsp_SetUser]   
               @c_UserName = @c_UserName  OUTPUT  
            ,  @n_Err      = @n_Err       OUTPUT  
            ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT  
         
         IF @n_Err <> 0   
         BEGIN
            GOTO EXIT_SP  
         END          
                  
         EXECUTE AS LOGIN = @c_UserName  
      END 
      
      SET @CUR_STRATEGY = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT dbs.DoorBookingstrategykey
            ,SPCode =  ISNULL(dbs.SPCode,'')
      FROM DoorBookingStrategy dbs WITH (NOLOCK)
      WHERE dbs.Facility = @c_Facility
      AND dbs.Storerkey = @c_Storerkey
      AND dbs.Active = 'Y' 
      GROUP BY dbs.DoorBookingstrategykey, ISNULL(dbs.SPCode,''), dbs.[Priority] -- Add & Order by Priority
      ORDER BY dbs.[Priority], dbs.DoorBookingstrategykey                        -- Add & Order by Priority

      OPEN @CUR_STRATEGY
      
      FETCH NEXT FROM @CUR_STRATEGY INTO @c_DoorBookingStrategyKey
                                       , @c_SPCode
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF @c_SPCode = ''
         BEGIN
            SET @c_SPCode = 'WM.lsp_DoorBookAutoBuild_STD'
         END

         IF EXISTS (SELECT 1 FROM sys.objects WHERE Object_ID(@c_SPCode) = object_id AND [Type] = 'P')
         BEGIN
   
            SET @b_Success = 1
            SET @n_Err = 0
            SET @c_ErrMsg = ''
            SET @c_SQL = N'EXEC ' + @c_SPCode  
                       +  ' @c_DoorBookingStrategyKey = @c_DoorBookingStrategyKey'
                       + ', @b_Success    = @b_Success      OUTPUT'
                       + ', @n_Err        = @n_Err          OUTPUT'
                       + ', @c_ErrMsg     = @c_ErrMsg       OUTPUT'
                       + ', @c_UserName   = @c_UserName'   
                       + ', @n_ErrGroupKey= @n_ErrGroupKey  OUTPUT'
                       + ', @b_debug      = @b_debug'
                       
            SET @c_SQLParms = N'@c_DoorBookingStrategyKey   NVARCHAR(10)'  
                            + ', @b_Success     INT             OUTPUT'
                            + ', @n_Err         INT             OUTPUT'
                            + ', @c_ErrMsg      NVARCHAR(255)   OUTPUT'
                            + ', @c_UserName    NVARCHAR(128)'
                            + ', @n_ErrGroupKey INT             OUTPUT'
                            + ', @b_debug       INT'
                            
            EXEC sp_ExecuteSQL   @c_SQL
                              ,  @c_SQLParms
                              ,  @c_DoorBookingStrategyKey
                              ,  @b_Success        OUTPUT
                              ,  @n_Err            OUTPUT
                              ,  @c_ErrMsg         OUTPUT
                              ,  @c_UserName
                              ,  @n_ErrGroupKey    OUTPUT
                              ,  @b_debug
                              
         END
         FETCH NEXT FROM @CUR_STRATEGY INTO @c_DoorBookingStrategyKey
                                          , @c_SPCode
      END
   END TRY
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
   END CATCH
   
   EXIT_SP:
   IF (XACT_STATE()) = -1                                      
   BEGIN
      SET @n_Continue = 3
      ROLLBACK TRAN
   END 
  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF @n_StartTCnt = 0 AND @@TRANCOUNT > @n_StartTCnt       
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_DoorBookAutoBuild_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   IF @n_Continue = 3
   BEGIN
      EXEC [WM].[lsp_WriteError_List]   
            @i_iErrGroupKey= @n_ErrGroupKey OUTPUT   
         ,  @c_TableName   = @c_TableName  
         ,  @c_SourceType  = @c_SourceType  
         ,  @c_Refkey1     = @c_Facility  
         ,  @c_Refkey2     = @c_Storerkey  
         ,  @c_Refkey3     = ''  
         ,  @n_LogWarningNo= 0  
         ,  @c_WriteType   = 'ERROR'  
         ,  @n_err2        = @n_err   
         ,  @c_errmsg2     = @c_errmsg   
         ,  @b_Success     = @b_Success      
         ,  @n_err         = @n_err          
         ,  @c_errmsg      = @c_errmsg   
   END
   
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
           
   REVERT   
END

GO