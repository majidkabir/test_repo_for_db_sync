SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_LoadPlanDetail_STD                  */  
/* Creation Date: 03-Apr-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Loadplandetail Pre-delete process / validation              */  
/*                                                                      */  
/* Called By: LOadplandetail delete                                     */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */ 
/* 2021-02-08   mingle01 1.1  Add Big Outer Begin try/Catch             */  
/* 2021-02-11   Wan01    1.1  Add Execute Login UserName.. Revert       */
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_LoadPlanDetail_STD]
      @c_StorerKey         NVARCHAR(15)
   ,  @c_RefKey1           NVARCHAR(50)  = '' 
   ,  @c_RefKey2           NVARCHAR(50)  = '' 
   ,  @c_RefKey3           NVARCHAR(50)  = '' 
   ,  @c_RefreshHeader     CHAR(1) = 'N'        OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N'        OUTPUT 
   ,  @b_Success           INT = 1              OUTPUT   
   ,  @n_Err               INT = 0              OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = ''   OUTPUT
   ,  @c_UserName          NVARCHAR(128) = '' 
   ,  @c_IsSupervisor      CHAR(1) = 'N' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT

         , @n_Allow                    INT = 0

         , @c_Loadkey                  NVARCHAR(10) = ''
         , @c_LoadLineNumber           NVARCHAR(5)  = ''
         , @c_Orderkey                 NVARCHAR(10) = '' 

   SET @n_err=0
   SET @b_success=1
   SET @c_errmsg='' 
   SET @c_RefreshDetail = 'Y'
   
   SET @c_LoadKey = ISNULL(@c_RefKey1,'')
   SET @c_LoadLineNumber = ISNULL(@c_RefKey2,'')

   --(Wan01) - START Login @c_UserName as there calling Sub SP
   SET @n_Err = 0 
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName OUTPUT, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END 
       
      EXECUTE AS LOGIN = @c_UserName 
   END
   --(Wan01) - END
   
   --(mingle01) - START
   BEGIN TRY
      IF @c_Loadkey = '' AND @c_LoadLineNumber = ''
      BEGIN
         GOTO EXIT_SP  
      END
            
      SELECT @c_Orderkey = LPD.Orderkey
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      WHERE LPD.Loadkey = @c_LoadKey
      AND   LPD.LoadLineNumber = @c_LoadLineNumber

      EXEC dbo.ispLoadplanDetAllow2Del
               @c_LoadKey  = @c_Loadkey 
            ,  @c_OrderKey = @c_Orderkey 
            ,  @n_Allow    = @n_Allow  OUTPUT   -- 0=Not Allow, 1=Allow  
            ,  @c_ErrMsg   = @c_ErrMsg OUTPUT  

      IF @n_Allow = 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 556901
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Disallow to delete Loadplan. (lsp_Pre_Delete_LoadPlanDetail_STD)'
                      +'(' + @c_ErrMsg + ')'   
         GOTO EXIT_SP  
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
EXIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SELECT @b_success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
   ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_starttcnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_LoadPlanDetail_STD'
      RETURN                  --(Wan01)
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      --RETURN                --(Wan01)  
   END  
   REVERT            
END -- End Procedure

GO