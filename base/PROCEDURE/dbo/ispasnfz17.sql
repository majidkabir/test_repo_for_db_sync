SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ17                                            */
/* Creation Date: 27-Jun-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-9524 CN - BoardRiders - Update UCC when Receipt Finalize   */
/*          Storerconfig: PostFinalizeReceiptSP                            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ17]  
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
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   IF @n_continue IN (1,2)
   BEGIN            	
   	  UPDATE UCC WITH (ROWLOCK)
   	  SET UCC.Userdefined02 = RD.UserDefine02
   	  FROM UCC 
   	  JOIN RECEIPTDETAIL RD (NOLOCK) ON RD.UserDefine01 = UCC.UCCNo AND RD.SKU = UCC.SKU AND RD.STORERKEY = UCC.STORERKEY
   	  WHERE RD.Receiptkey = @c_Receiptkey
   	  AND (RD.ReceiptLineNumber = @c_ReceiptLineNumber OR ISNULL(@c_ReceiptLineNumber,'') = '')
   	  AND RD.UserDefine02 <> ''
   	  AND RD.UserDefine02 IS NOT NULL

      SELECT @n_err = @@ERROR
      IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63500
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Table Failed! (ispASNFZ17)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END   	     	           
   END
   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ17'
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