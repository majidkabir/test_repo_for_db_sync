SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/                                                                                  
/* Store Procedure: lsp_MBOLReleaseMoveTask_Wrapper                     */                                                                                  
/* Creation Date: 2021-10-29                                            */                                                                                  
/* Copyright: LFL                                                       */                                                                                  
/* Written by: Wan                                                      */                                                                                  
/*                                                                      */                                                                                  
/* Purpose: LFWM-2997 - UAT CN - Outbound Ship Reference for CSHP       */
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
/* 2021-10-29  Wan01    1.0   Created.                                  */
/* 2021-10-29  Wan01    1.0   DevOps Combine Script.                    */
/************************************************************************/                                                                                  
CREATE PROC [WM].[lsp_MBOLReleaseMoveTask_Wrapper]                                                                                                                     
      @c_MBolkey              NVARCHAR(10) = ''
   ,  @b_Success              INT = 1           OUTPUT  
   ,  @n_err                  INT = 0           OUTPUT                                                                                                             
   ,  @c_ErrMsg               NVARCHAR(255)     OUTPUT 
   ,  @n_WarningNo            INT          = 0  OUTPUT
   ,  @c_ProceedWithWarning   CHAR(1)      = 'N'                      
   ,  @c_UserName             NVARCHAR(128)= ''                                                                                                                         

AS  
BEGIN                                                                                                                                                        
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   DECLARE  @n_StartTCnt            INT = @@TRANCOUNT  
         ,  @n_Continue             INT = 1
         
         ,  @c_Facility             NVARCHAR(10) = ''
         ,  @c_Storerkey            NVARCHAR(15) = ''
         
         ,  @c_ReleaseCMBOL_MV_SP   NVARCHAR(30) = ''
         ,  @c_LocationCategory     NVARCHAR(10) = ''

   SET @b_Success = 1
   SET @n_Err     = 0
   
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
     
   BEGIN TRY
      IF @c_ProceedWithWarning = 'N' AND @n_WarningNo < 1
      BEGIN
         SELECT TOP 1 @c_ReleaseCMBOL_MV_SP = CASE WHEN fgr.Authority = 'ispMBRTK02' THEN fgr.Authority ELSE '' END
         FROM dbo.MBOLDETAIL AS m (NOLOCK)
         JOIN dbo.ORDERS AS o (NOLOCK) ON o.OrderKey = m.OrderKey
         OUTER APPLY dbo.fnc_GetRight2( o.Facility, o.Storerkey, '', 'ReleaseCMBOL_MV_SP') AS fgr
         ORDER BY 1 DESC
  
         SET @n_WarningNo = 1
         SET @c_ErrMsg = 'Confirm Release Move Task?'
         IF @c_ReleaseCMBOL_MV_SP = 'ispMBRTK02'
         BEGIN
            SELECT TOP 1 @c_LocationCategory = l.LocationCategory
            FROM dbo.LoadPlanLaneDetail AS lpld (NOLOCK)
            JOIN dbo.LOC AS l WITH (NOLOCK) ON l.Loc = lpld.LOC
            WHERE lpld.MBOLKey = @c_MBolkey
            ORDER BY CASE WHEN l.LocationCategory = 'STAGING' THEN 1
                          WHEN l.LocationCategory = 'QC'      THEN 2
                          ELSE 9 
                     END
            
            IF @c_LocationCategory NOT IN ('STAGING', 'QC')  
            BEGIN
               SET @c_LocationCategory = 'PACK&HOLD'
            END       
            SET @c_ErrMsg = 'Confirm Release Move Task From Pallet Build To ' + @c_LocationCategory + '?'      
         END 
         GOTO EXIT_SP         
      END
      
      BEGIN TRAN  
      EXEC  [dbo].[isp_CMBOLReleaseMoveTask_Wrapper]  
            @c_MBolKey = @c_MBolKey    
         ,  @b_Success = @b_Success OUTPUT
         ,  @n_Err     = @n_Err     OUTPUT 
         ,  @c_ErrMsg  = @c_ErrMsg  OUTPUT
         ,  @n_cbolkey = 0
            
      IF @b_Success = 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 560101
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Error Executing isp_CMBOLReleaseMoveTask_Wrapper. (lsp_MBOLReleaseMoveTask_Wrapper)'   
                        + '(' + @c_ErrMsg + ')'          

         GOTO EXIT_SP   
      END

      IF @c_ErrMsg = ''
      BEGIN
         SET @c_ErrMsg = 'Release Move Task Completed.'
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
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

      SET @n_WarningNo = 0
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_MBOLReleaseMoveTask_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   
   IF @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN 
   END
         
   REVERT
END

GO