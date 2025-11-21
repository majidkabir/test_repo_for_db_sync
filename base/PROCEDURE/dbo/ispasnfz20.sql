SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ20                                            */
/* Creation Date: 05-DEC-2019                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-11251 - TH-Nike auto release PA task upon Finalize ASN     */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ20]  
(     @c_Receiptkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue INT,
           @n_StartTranCount INT,
           @c_Loadkey NVARCHAR(10),
           @c_Userdefine01 NVARCHAR(30),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20), 
           @c_ExternPokey NVARCHAR(18), 
           @c_ExternOrderkey NVARCHAR(18),
           @c_Orderkey NVARCHAR(10), 
           @n_QtyReceived INT,
           @c_Pokey NVARCHAR(10),
           @c_OrderLineNumber NVARCHAR(5),
           @n_OriginalQty INT

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     
            
   EXEC isp_ASNReleasePATask_Wrapper @c_receiptkey,@b_Success OUTPUT, @n_Err OUTPUT, @c_ErrMsg OUTPUT
   
   IF @b_Success <> 1  
   BEGIN  
       SELECT @n_continue = 3    
       GOTO QUIT_SP  
   END           

   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ20'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO