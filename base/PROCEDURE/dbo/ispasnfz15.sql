SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ15                                            */
/* Creation Date: 01-OCT-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-6456 - PH Alcon finalize ASN auto create transfer          */
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
CREATE PROC [dbo].[ispASNFZ15]  
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
      
   DECLARE @n_Continue       INT,
           @n_StartTranCount INT,           
           @c_Storerkey      NVARCHAR(15),
           @c_Facility       NVARCHAR(5),
           @c_Sku            NVARCHAR(20),
           @n_QtyReceived    INT, 
           @c_UOM            NVARCHAR(10), 
           @c_Lot            NVARCHAR(10), 
           @c_Loc            NVARCHAR(10), 
           @c_ID             NVARCHAR(18),            
           @c_Userdefine02   NVARCHAR(30),
           @c_Userdefine01   NVARCHAR(30),
           @c_Lottable06     NVARCHAR(30),
           @c_Transferkey    NVARCHAR(10)
           
                                     
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT
   SET @c_Transferkey = ''             
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   IF @n_continue IN(1,2) AND EXISTS (SELECT 1 
                                      FROM RECEIPT R (NOLOCK)
                                      JOIN CODELKUP CL (NOLOCK) ON R.Storerkey = CL.Storerkey
                                                                AND R.RecType = CL.Code
                                                                AND CL.Listname = 'RECTYPE'
                                                                AND UDF01 = 'Y'
                                      WHERE R.Receiptkey = @c_Receiptkey)
                                      
   BEGIN
      DECLARE CUR_TRF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT R.Facility, R.Storerkey, RD.Sku, I.Lot, SUM(RD.QtyReceived) AS Qty, RD.UOM, RD.ToLoc, RD.ToID, RD.Userdefine02, RD.Userdefine01, RD.Lottable06
         FROM RECEIPT R (NOLOCK)
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
         JOIN ITRN I (NOLOCK) ON RD.Storerkey = I.Storerkey AND RD.Sku = I.Sku AND I.TranType = 'DP'
                                 AND I.SourceKey = R.Receiptkey + RD.ReceiptLineNumber AND LEFT(I.SourceType,10) = 'ntrReceipt'
         WHERE R.Receiptkey = @c_Receiptkey
         GROUP BY R.Facility, R.Storerkey, RD.Sku, I.Lot, RD.UOM, RD.ToLoc, RD.ToID, RD.Userdefine02, RD.Userdefine01, RD.Lottable06

      OPEN CUR_TRF  
      
      FETCH NEXT FROM CUR_TRF INTO @c_Facility, @c_Storerkey, @c_Sku, @c_Lot, @n_QtyReceived, @c_UOM, @c_Loc, @c_ID, @c_Userdefine02, @c_Userdefine01, @c_Lottable06
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN        	      	 
      	 SET @b_Success = 0
      	 EXEC ispCreateTransfer
      	    @c_Transferkey = @c_Transferkey OUTPUT,
      	    @c_FromFacility = @c_Facility,
      	    @c_FromLot = @c_Lot,
            @c_FromLoc = @c_Loc,
            @c_FromID  = @c_ID,
      	    @n_FromQty = @n_QtyReceived,
      	    @c_ToLottable01 = @c_Userdefine02,
      	    @c_ToLottable06 = @c_Lottable06,
      	    @c_ToLottable07 = @c_Userdefine01,
      	    @c_ToLottable08 = 'EMPTY',
      	    @c_CopyLottable = 'Y',
      	    @c_Finalize = 'N',
      	    @c_Type = 'BSU',
      	    @c_ReasonCode = '02',
      	    @c_CustomerRefNo = @c_Receiptkey,      	    
      	    @b_Success = @b_Success OUTPUT,
      	    @n_Err = @n_Err OUTPUT,
      	    @c_ErrMsg = @c_ErrMsg OUTPUT

   	     IF  @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
   	        SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (ispASNFZ15)'
         END
      	 
         FETCH NEXT FROM CUR_TRF INTO @c_Facility, @c_Storerkey, @c_Sku, @c_Lot, @n_QtyReceived, @c_UOM, @c_Loc, @c_ID, @c_Userdefine02, @c_Userdefine01, @c_Lottable06
      END
   	  CLOSE CUR_TRF
   	  DEALLOCATE CUR_TRF
   	  
   END
   
   /*IF ISNULL(@c_Transferkey,'') <> '' AND @n_continue IN(1,2)
   BEGIN
      EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63100
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ShelfLifeExpiredAlert)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END*/   
            	   	   	   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ15'
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