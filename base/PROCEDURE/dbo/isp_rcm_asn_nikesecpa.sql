SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Proc: isp_RCM_ASN_NikeSECPA                                   */  
/* Creation Date: 03-MAR-2021                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: WMS-16330 - CN Nike SEC Putaway                             */  
/*        :                                                             */  
/* Called By: Custom RCM Menu                                           */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 22-Oct-2021 NJOW     1.0   DEVOPS combine script                     */
/************************************************************************/  
CREATE PROC [dbo].[isp_RCM_ASN_NikeSECPA]  
      @c_Receiptkey  NVARCHAR(MAX)     
   ,  @b_success     INT OUTPUT  
   ,  @n_err         INT OUTPUT  
   ,  @c_errmsg      NVARCHAR(225) OUTPUT  
   ,  @c_code        NVARCHAR(30)=''  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE    
           @n_StartTCnt          INT  
         , @n_Continue           INT   
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
   SET @n_err      = 0  
   SET @c_errmsg   = ''  
  
  
   EXEC ispBatPA03
         @c_ReceiptKey = @c_Receiptkey
        ,@b_Success = @b_Success OUTPUT
        ,@n_Err = @n_Err OUTPUT
        ,@c_ErrMsg = @c_Errmsg OUTPUT
       
   IF @b_Success <> 1  
   BEGIN
     SET @n_Continue = 3  
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
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_ASN_NikeSECPA'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END -- procedure  

GO