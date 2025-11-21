SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lspUOMCONV_Wrapper                                  */  
/* Creation Date: 2020-12-04                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-2440 - UAT  Philippines  PH SCE Inventory Move using    */
/*          ToUOM Not Functional Autocomputing                           */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2020-12-04  Wan      1.0   Creation                                   */
/*************************************************************************/   
CREATE PROCEDURE [WM].[lspUOMCONV_Wrapper]  
        @n_FromQty   FLOAT 
      , @c_FromUOM   NVARCHAR(10)    
      , @c_ToUOM     NVARCHAR(10)    
      , @c_Packkey   NVARCHAR(10)    
      , @n_Toqty     FLOAT                   OUTPUT  
      , @b_Success   int            = 1      OUTPUT
      , @n_Err       int            = 0      OUTPUT
      , @c_Errmsg    NVARCHAR(250)  = ''     OUTPUT   
      , @c_UOMInOut  NVARCHAR(2)    = '__'   OUTPUT    
      , @c_UserName  NVARCHAR(128)  = ''
AS  
BEGIN  
   SET NOCOUNT ON                                                                                                                                           
   SET ANSI_NULLS OFF                                                                                                                                       
   SET QUOTED_IDENTIFIER OFF                                                                                                                                
   SET CONCAT_NULL_YIELDS_NULL OFF       

   --Notes:
   --ALL Pass In data are same as pass to call nspUOMCONV. Adding @c_UserName in case need in Future 
   --This is WM SP Wrapper to handle Exception.

   DECLARE @n_Continue        INT = 1
         , @n_StartTCnt       INT = @@TRANCOUNT
         
   SET @b_Success = 1
   SET @c_ErrMsg = ''

   --Need to Create Big Outer BEGIN TRY..END TRY If more Logic in the SP

   BEGIN TRY      
      EXECUTE nspUOMCONV 
        @n_FromQty   = @n_FromQty 
      , @c_FromUOM   = @c_FromUOM 
      , @c_ToUOM     = @c_ToUOM   
      , @c_Packkey   = @c_Packkey 
      , @n_Toqty     = @n_Toqty      OUTPUT  
      , @b_Success   = @b_Success    OUTPUT
      , @n_Err       = @n_Err        OUTPUT
      , @c_Errmsg    = @c_Errmsg     OUTPUT   
      , @c_UOMInOut  = @c_UOMInOut   OUTPUT 
   END TRY

   BEGIN CATCH
      SET @n_Continue = 3
      SET @n_err = 559101
      SET @c_Errmsg = ERROR_MESSAGE()
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspUOMCONV. (lspUOMCONV_Wrapper)'
               + '( ' + @c_errmsg + ' )'

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lspUOMCONV_Wrapper'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END  

GO