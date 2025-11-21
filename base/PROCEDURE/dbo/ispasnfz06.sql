SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ06                                            */
/* Creation Date: 22-SEP-2015                                              */
/* Copyright: LF                                                           */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: SOS#352282 - PH - L'Oreal Auto Create Transfer                 */
/*          (Create and finalize transfer from ASN)                        */
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
CREATE PROC [dbo].[ispASNFZ06]  
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
   
   DECLARE @c_UDF01 NVARCHAR(30), 
           @c_UDF02 NVARCHAR(30), 
           @c_UDF03 NVARCHAR(30), 
           @c_UDF04 NVARCHAR(30),       
           @c_Notes NVARCHAR(200),    
           @c_Storerkey NVARCHAR(15),
           @c_ExternReceiptkey NVARCHAR(20),
           @c_Sku NVARCHAR(20),
           @c_FromLoc NVARCHAR(10),
           @c_ToLoc NVARCHAR(10),
           @c_ID NVARCHAR(18),
           @n_QtyReceived INT,
           @c_Packkey NVARCHAR(10),
           @c_UOM NVARCHAR(10),
           @c_Lottable01 NVARCHAR(18),
           @c_Lottable02 NVARCHAR(18),
           @c_Lottable03 NVARCHAR(18),
           @dt_Lottable04 DATETIME,
           @dt_Lottable05 DATETIME,
           @c_Lot NVARCHAR(10),
           @c_ExportStatus NCHAR(1),
           @c_Transferkey NVARCHAR(10),
           @c_Facility NVARCHAR(5),
           @c_TransferLineNumber NVARCHAR(5)                      
   
   DECLARE @c_CreateTRF NCHAR(1),
           @n_Continue INT,
           @n_StartTranCount INT,
           @n_LineNo INT

   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT, @c_CreateTRF='Y', @n_LineNo=1           
   
   DECLARE CUR_RECEIPT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT CL.UDF01, CL.UDF02, CL.UDF03, CL.UDF04, CONVERT(NVARCHAR(200),ISNULL(CL.Notes,'')) AS Notes,
             R.Storerkey, R.ExternReceiptkey, R.Facility, 
             RD.ReceiptLineNumber, RD.Sku, RD.ToLoc, RD.QtyReceived, RD.Packkey,
             RD.UOM, RD.Lottable01, RD.Lottable02, RD.Lottable03, RD.Lottable04,
             RD.Lottable05, ITRN.Lot, ITRN.ToID 
      FROM RECEIPT R (NOLOCK) 
      JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
      JOIN ITRN (NOLOCK) ON ITRN.SourceKey = R.Receiptkey+RD.ReceiptLinenumber 
                         AND ITRN.Trantype = 'DP' AND LEFT(Sourcetype,10) = 'ntrReceipt'        
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Code = R.RecType AND CL.Storerkey = R.Storerkey
      WHERE RD.Receiptkey = @c_Receiptkey
      AND CL.Listname = 'RECTYPE'
      AND ISNULL(CL.UDF01,'') = 'Y'

   OPEN CUR_RECEIPT  
  
   FETCH NEXT FROM CUR_RECEIPT INTO @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_Notes, @c_Storerkey, @c_ExternReceiptkey, @c_Facility, 
                                    @c_ReceiptLineNumber, @c_Sku, @c_FromLoc, @n_QtyReceived, @c_Packkey, @c_UOM, 
                                    @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_Lot, @c_ID

   WHILE @@FETCH_STATUS <> -1  
   BEGIN     	
     	--Create Transfer Header
     	IF @c_CreateTRF = 'Y'
     	BEGIN
         SELECT @b_success = 0
         EXECUTE nspg_getkey
         'TRANSFER'
         , 10
         , @c_TransferKey OUTPUT
         , @b_success OUTPUT
         , @n_err OUTPUT
         , @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO TRANSFER (Transferkey, FromStorerkey, ToStorerkey, Type, ReasonCode, CustomerRefNo, Remarks, Facility, ToFacility)
                          VALUES (@c_TransferKey, @c_Storerkey, @c_Storerkey, @c_UDF02, @c_UDF02, @c_ExternReceiptkey, @c_Notes, @c_Facility, @c_Facility)

   	        SELECT @n_err = @@ERROR
   	        IF  @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63504
   	           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Transfer Failed! (ispASNFZ06)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP
            END
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505
   	        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Transfer Key Failed! (ispASNFZ06)' + ' ( '
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            GOTO QUIT_SP
         END
     		 
     		 SET @c_CreateTRF = 'N'
     	END
     	
     	--Create Transfer Detail     	  	
      SELECT @c_TransferLineNumber = RIGHT( '0000' + RTRIM(CAST(@n_LineNo AS NChar(5))), 5)
      
      SET @c_ToLoc = @c_UDF03
      
      INSERT TRANSFERDETAIL (Transferkey, TransferLineNumber, FromStorerkey, FromSku, FromLot, FromLoc, FromID, FromQty, FromPackkey, FromUOM,
                             Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, ToStorerkey, ToSku, ToLot, ToLoc, ToID, ToQty, ToPackkey, ToUOM,
                             ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05)
      VALUES (@c_Transferkey, @c_TransferLineNumber, @c_Storerkey, @c_Sku, @c_Lot, @c_FromLoc, @c_ID, @n_QtyReceived, @c_Packkey, @c_UOM,
              @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_Storerkey, @c_Sku, '', @c_ToLoc, @c_ID, @n_QtyReceived, @c_Packkey, @c_UOM,
              @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05)

   	  SELECT @n_err = @@ERROR
   	  IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63506
   	     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert TransferDetail Failed! (ispASNFZ06)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
     	
     	SELECT @n_LineNo = @n_LineNo + 1     	
 
   	  /*
   	  UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   	  SET toloc = @c_Toloc
   	      TrafficCop = NULL,
   	      EditWho = SUSER_SNAME(),
   	      EditDate = GETDATE()
   	  WHERE Receiptkey = @c_Receiptkey
   	  AND ReceiptLineNumber = @c_ReceiptLineNumber
   	    	  
   	  SELECT @n_err = @@ERROR
   	  IF  @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63507
   	     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update ReceiptDetail Failed! (ispASNFZ06)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
      */
         	  
      FETCH NEXT FROM CUR_RECEIPT INTO @c_UDF01, @c_UDF02, @c_UDF03, @c_UDF04, @c_Notes, @c_Storerkey, @c_ExternReceiptkey, @c_Facility,
                                       @c_ReceiptLineNumber, @c_Sku, @c_FromLoc, @n_QtyReceived, @c_Packkey, @c_UOM, 
                                       @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_Lot, @c_ID
   END
   CLOSE CUR_RECEIPT 
   DEALLOCATE CUR_RECEIPT
   
   /*
   IF ISNULL(@c_Transferkey,'') <> ''
   BEGIN
      EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63508
   	     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer Failed! (ispASNFZ06)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         GOTO QUIT_SP
      END
   END   
   */
  
   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_RECEIPT') in (0 , 1)
   BEGIN
      CLOSE CUR_RECEIPT
      DEALLOCATE CUR_RECEIPT
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ06'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
      
      --RAISERROR @n_err @c_errmsg
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