SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_Delete_ReceiptDetail_WIP                        */  
/* Creation Date: 2020-09-21                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: WMS-14739 - CN NIKE O2 WMS RFID Receiving Module             */
/*          ASN Header                                                   */  
/*                                                                       */  
/* Called By: ue_delete_receiptdetail_wip                                */  
/*                                                                       */  
/* Version: 1.1                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 09-OCT-2020 Wan      1.0   Created                                    */
/* 2021-03-19  Wan01    1.1   WMS-16505 - [CN]NIKE_Phoenix_RFID_Receiving*/
/*                           _Overall_CR                                 */
/*************************************************************************/   
CREATE PROCEDURE [dbo].[isp_Delete_ReceiptDetail_WIP] 
   @n_RowID       BIGINT         = 0            -- If Value = 0, call from close window
,  @n_SessionID   BIGINT         = 0            --(Wan01)
,  @b_Success     INT            = 1   OUTPUT   
,  @n_Err         INT            = 0   OUTPUT
,  @c_Errmsg      NVARCHAR(255)  = ''  OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT

   --(Wan01) - START
   IF @n_RowID = 0
   BEGIN
      ; WITH R_WIP (RowID) AS 
      ( SELECT r.RowID FROM RECEIPTDETAIL_WIP r WITH (NOLOCK) WHERE r.SessionID = @n_SessionID)
      
      DELETE R_WIP
      FROM R_WIP 
      JOIN RECEIPTDETAIL_WIP r1 ON R_WIP.RowID = r1.RowID
   END 
   ELSE
   BEGIN
      DELETE RECEIPTDETAIL_WIP
      WHERE RowID = @n_RowID
   END
   --(Wan01) - END
   IF @@ERROR <> 0
   BEGIN
      SET @n_continue = 3      
      SET @n_err = 89210
      SET @c_errmsg = 'NSQL' +CONVERT(CHAR(5),@n_err) + ': Update RECEIPTDETAIL_WIP Failed. (isp_Delete_ReceiptDetail_WIP)'
      GOTO QUIT_SP
   END

   QUIT_SP:

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_Delete_ReceiptDetail_WIP'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
   REVERT      
END  

GO