SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: lsp_Pre_Delete_Adjustmentdetail_STD                */  
/* Creation Date: 24-Jul-2018                                           */  
/* Copyright: LFLogistics                                               */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: Adjustment detail Pre-delete process / validation           */  
/*                                                                      */  
/* Called By: Adjustmentdetail delete                                   */  
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
/************************************************************************/   
CREATE PROCEDURE [WM].[lsp_Pre_Delete_Adjustmentdetail_STD]
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
          ,@c_Adjustmentkey         NVARCHAR(10) = ''
          ,@c_AdjustmentLineNumber  NVARCHAR(5) = ''   
          ,@c_Facility              NVARCHAR(5)
          ,@c_FinalizeAdjustment    NVARCHAR(30)
          ,@c_FinalizedFlag         NVARCHAR(30) 
          ,@c_AdjStatusControl      NVARCHAR(30)
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_err=0, @b_success=1, @c_errmsg='', @n_continue=1

   SET @c_Adjustmentkey = @c_RefKey1
   SET @c_AdjustmentLineNumber = @c_Refkey2
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
      SELECT @c_Storerkey = ADJUSTMENT.Storerkey
            ,@c_Facility = ADJUSTMENT.Facility
            ,@c_FinalizedFlag = ADJUSTMENTDETAIL.Finalizedflag
      FROM ADJUSTMENT (NOLOCK)
      JOIN ADJUSTMENTDETAIL (NOLOCK) ON ADJUSTMENT.Adjustmentkey = ADJUSTMENTDETAIL.Adjustmentkey
      WHERE ADJUSTMENTDETAIL.Adjustmentkey = @c_Adjustmentkey
      AND ADJUSTMENTDETAIL.AdjustmentLineNumber = @c_AdjustmentLineNumber
   
      SELECT @c_FinalizeAdjustment = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'FinalizeAdjustment')
      SELECT @c_AdjStatusControl = dbo.fnc_GetRight(@c_Facility, @c_Storerkey, '', 'AdjStatusControl')
 
      IF @n_Continue IN (1,2) 
      BEGIN      
         IF EXISTS (SELECT 1 
                    FROM ADJUSTMENTDETAIL (NOLOCK)
                      WHERE Finalizedflag = 'Y'
                         AND Adjustmentkey =  @c_Adjustmentkey 
                         AND AdjustmentLineNumber = @c_AdjustmentLineNumber)
            BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 553401   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': Cannot Delete Finalized Adjustment Line. (lsp_Pre_Delete_Adjustmentdetail_STD)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END                  
      END    

      IF @n_Continue IN (1,2) AND @c_FinalizeAdjustment = '1' AND @c_AdjStatusControl = '1'
      BEGIN    
         IF @c_IsSupervisor <> 'Y' AND @c_FinalizedFlag NOT IN ('N','R')
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 553402   
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(6),@n_err)+': User is not allowed to delete Submitted or Approved line. Please check with supervisor. (lsp_Pre_Delete_Adjustmentdetail_STD)' + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
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
      execute nsp_logerror @n_err, @c_errmsg, 'lsp_Pre_Delete_Adjustmentdetail_STD'  
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