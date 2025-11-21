SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_Orderdetail_STD                     */  
/* Creation Date: 27-Mar-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Orderdetail Pre-delete process / validation                 */  
/*                                                                      */  
/* Called By: Orderdetail delete                                        */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 8.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver  Purposes                                   */ 
/* 2020-04-08  Wan01    1.1   LFWM-2062 - MYS SCE unable to delete      */
/*                            shipment order detail                     */
/* 2021-02-08  mingle01 1.2   Add Big Outer Begin try/Catch             */ 
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_Orderdetail_STD]
      @c_StorerKey         NVARCHAR(15)
   ,  @c_RefKey1           NVARCHAR(50)  = '' 
   ,  @c_RefKey2           NVARCHAR(50)  = '' 
   ,  @c_RefKey3           NVARCHAR(50)  = '' 
   ,  @c_RefreshHeader     CHAR(1) = 'N' OUTPUT
   ,  @c_RefreshDetail     CHAR(1) = 'N' OUTPUT 
   ,  @b_Success           INT = 1 OUTPUT   
   ,  @n_Err               INT = 0 OUTPUT
   ,  @c_Errmsg            NVARCHAR(255) = ''  OUTPUT
   ,  @c_UserName          NVARCHAR(128) = '' 
   ,  @c_IsSupervisor      CHAR(1) = 'N' 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue          INT 
          ,@n_starttcnt         INT
          ,@c_Orderkey          NVARCHAR(10) = ''
          ,@c_OrderLineNumber   NVARCHAR(5) = ''   
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1

   SET @c_Orderkey = @c_RefKey1
   SET @c_OrderLineNumber = @c_Refkey2
   SET @c_RefreshDetail = 'Y'
   
     /*
   SET @n_Err = 0 
   EXEC [WM].[lsp_SetUser] @c_UserName = @c_UserName, @n_Err = @n_Err OUTPUT, @c_ErrMsg = @c_ErrMsg OUTPUT

   IF @n_Err <> 0 
   BEGIN
      GOTO EXIT_SP
   END
   */
   
   --(mingle01) - START
   BEGIN TRY 
      IF @n_Continue IN (1,2)
      BEGIN      
         IF EXISTS ( SELECT 1 
                     FROM PICKDETAIL (NOLOCK)
                     WHERE STATUS >= '5'
                        AND Orderkey =  @c_Orderkey 
                        AND OrderLineNumber = @c_OrderLineNumber)
            BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 553551   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': This Shipment Order cannot be deleted. It has been Shipped or Picked. (lsp_Pre_Delete_Orderdetail_STD)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END                  
      END 
      
      IF @n_Continue IN (1,2)
      BEGIN      
         IF EXISTS (SELECT 1 PicksReleased            --(Wan01)
                    FROM TASKDETAIL WITH (NOLOCK)
                    WHERE TaskType = 'PK'
                    AND OrderKey = @c_Orderkey
                    AND OrderLineNumber = @c_OrderLineNumber)
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 553552  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': This Shipment Order cannot be deleted. It has been Shipped or Picked. (lsp_Pre_Delete_Orderdetail_STD)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END                  
      END
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END 
         
   EXIT_SP:
   --REVERT     
   
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_Orderdetail_STD'  
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