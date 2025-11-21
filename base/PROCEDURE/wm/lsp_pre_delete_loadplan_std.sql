SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_Loadplan_STD                        */  
/* Creation Date: 03-Apr-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Orders Pre-delete process / validation                      */  
/*                                                                      */  
/* Called By: Orders delete                                             */  
/*                                                                      */  
/* PVCS Version: 1.2                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 2021-02-08   mingle01 1.1  Add Big Outer Begin try/Catch             */
/* 2023-01-27   Wan01    1.2  LFWM-3865 - SCE CN  Allow remove allocated*/
/*                            orders from Load                          */
/*                            DevOps Combine Script                     */
/************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_Pre_Delete_Loadplan_STD]
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

   DECLARE @n_Continue              INT = 1
         , @n_StartTCnt             INT = @@TRANCOUNT

         , @c_LoadKey               NVARCHAR(10) = ''
         , @c_Facility              NVARCHAR(10) = ''             --(Wan01)
         , @c_LoadStatus            NVARCHAR(10) = ''             --(Wan01)
         , @c_OrderStatus           NVARCHAR(10) = ''             --(Wan01)
         , @c_SCENonExceedLoadflow  NVARCHAR(10) = ''             --(Wan01)
   
   SET @n_err=0
   SET @b_success=1
   SET @c_errmsg='' 
   SET @c_RefreshHeader = 'Y'
        
   SET @c_LoadKey = ISNULL(@c_RefKey1,'')

   --(mingle01) - START
   BEGIN TRY     
      IF @c_LoadKey = ''
      BEGIN
         GOTO EXIT_SP  
      END
      
      SELECT TOP 1                                                                  --(Wan01) - START
            @c_Facility   = lp.facility 
         ,  @c_LoadStatus = lp.[Status]
         ,  @c_OrderStatus= o.[Status]
         ,  @c_Storerkey  = o.Storerkey
      FROM dbo.LoadPlan AS lp WITH (NOLOCK)
      JOIN dbo.ORDERS AS o WITH (NOLOCK) ON o.LoadKey = lp.LoadKey
      WHERE lp.Loadkey = @c_Loadkey
      ORDER BY o.[Status] Desc
                  
      SELECT @c_SCENonExceedLoadflow = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'SCENonExceedLoadflow') 
      
      --IF EXISTS(  SELECT 1 
      --            FROM LOADPLAN WITH (NOLOCK)
      --            WHERE Loadkey = @c_Loadkey
      --            AND [Status] > '0' 
      --            )
      IF @c_LoadStatus > '0' AND @c_SCENonExceedLoadflow = '0'    
      BEGIN
         SET @n_continue = 3
         SET @n_err = 556901
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Only Load Plan# With ''Normal'' Status Can Be Deleted. (lsp_Pre_Delete_Loadplan_STD)'   
         GOTO EXIT_SP             
      END
      ELSE IF @c_OrderStatus > '2' AND @c_SCENonExceedLoadflow = '1'    
      BEGIN
         SET @n_continue = 3
         SET @n_err = 556902
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Load Plan# is Pick In Progress. Disallow to delete. (lsp_Pre_Delete_Loadplan_STD)'   
         GOTO EXIT_SP             
      END                                                                           --(Wan01) - END                       
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_Loadplan_STD'
      RETURN  
   END  
   ELSE  
   BEGIN  
      SELECT @b_success = 1  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END              
END -- End Procedure

GO