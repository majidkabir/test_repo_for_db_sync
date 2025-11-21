SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ14                                            */
/* Creation Date: 29-Jun-2018                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-5438 - CN Levis B2B Auto kitting after finalize ASN        */
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
/* 25/01/2019   NJOW01  1.0   WMS-7720 use codelkup to get reasoncode      */
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ14]  
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
           @c_ToSku          NVARCHAR(20),
           @n_QtyReceived    INT, 
           @c_Packkey        NVARCHAR(10), 
           @c_UOM            NVARCHAR(10), 
           @c_Lot            NVARCHAR(10), 
           @c_Loc            NVARCHAR(10), 
           @c_ID             NVARCHAR(18), 
           @dt_Lottable05    DATETIME, 
           @c_Packkey2       NVARCHAR(10),
           @c_UOM2           NVARCHAR(10),
           @c_Kitkey         NVARCHAR(10),
           @c_ReasonCode     NVARCHAR(10)
                                     
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT             
   
   IF @@TRANCOUNT = 0
      BEGIN TRAN 

   IF @n_continue IN(1,2)
   BEGIN   	
   	  --Retrieve Kit sku
      DECLARE CUR_KIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
         SELECT RD.Storerkey, R.Facility, RD.Sku, SKU.Busr1 AS ToSku, 
                RD.QtyReceived, RD.Packkey, RD.UOM, RD.ReceiptLineNumber,
                ITRN.Lot, ITRN.ToLoc, ITRN.ToID, ITRN.LOTTABLE05, PACK2.Packkey, PACK2.PackUOM3,
                ISNULL(CL.Code,'LVB2B') --NJOW01
         FROM RECEIPT R (NOLOCK) 
         JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey
         JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku
         JOIN SKU SKU2 (NOLOCK) ON SKU.Storerkey = SKU2.Storerkey AND SKU.Busr1 = SKU2.Sku
         JOIN PACK PACK2 (NOLOCK) ON SKU2.Packkey = PACK2.Packkey
         JOIN ITRN (NOLOCK) ON RD.ReceiptKey + RD.ReceiptLineNumber = ITRN.SourceKey AND ITRN.TranType = 'DP' AND RD.Storerkey = ITRN.StorerKey
                               AND RD.Sku = ITRN.Sku
         LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Listname = 'LEVKITCODE' AND CL.Short = ISNULL(R.ReceiptGroup,'')   --NJOW01                   
         WHERE R.Receiptkey = @c_Receiptkey
         AND RD.Userdefine10 = 'Y'
         ORDER BY RD.ReceiptLineNumber
      
      OPEN CUR_KIT   
      
      FETCH NEXT FROM CUR_KIT INTO @c_Storerkey, @c_Facility, @c_Sku, @c_ToSku, @n_QtyReceived, @c_Packkey, @c_UOM, @c_ReceiptLineNumber, 
                                   @c_Lot, @c_Loc, @c_ID, @dt_Lottable05, @c_Packkey2, @c_UOM2, @c_ReasonCode

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)             
      BEGIN      	         
      	 --Generate new kitkey for each sku
      	 SET @b_success = 1	  
         EXECUTE nspg_GetKey
                'kitting'
               ,10 
               ,@c_Kitkey        OUTPUT 
               ,@b_success       OUTPUT 
               ,@n_err           OUTPUT 
               ,@c_errmsg        OUTPUT

         --create kitting header
         INSERT INTO KIT (KitKey, Type, Facility, Storerkey, ToStorerkey, ExternKitkey, CustomerRefNo, ReasonCode)
         VALUES (@c_Kitkey, 'KIT', @c_Facility, @c_Storerkey, @c_Storerkey, @c_Receiptkey,  @c_Receiptkey, @c_ReasonCode)               
         
         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
             SET @n_continue = 3  
             SET @n_Err = 31200 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                           + ': Insert KIT Table Failed. (ispASNFZ14)'  
         END     

         --Create kit-from 
         INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Lot, Loc, ID, Lottable05)
                        VALUES (@c_Kitkey, '00001', 'F', @c_Storerkey, @c_Sku, @n_QtyReceived, @n_QtyReceived, @c_Packkey, @c_UOM, @c_Receiptkey, @c_ReceiptLineNumber,
                                @c_Lot, @c_Loc, @c_ID, @dt_Lottable05)
                     
         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
             SET @n_continue = 3  
             SET @n_Err = 31210 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                           + ': Insert KITDETAIL(F) Table Failed. (ispASNFZ14)'  
         END              	  

         --Create kit-to 
         INSERT INTO KITDETAIL (KitKey, KitLineNumber, Type, Storerkey, Sku, ExpectedQty, Qty, Packkey, UOM, ExternKitkey, ExternLineNo, Loc, ID, Lottable05)
                        VALUES (@c_Kitkey, '00001', 'T', @c_Storerkey, @c_ToSku, @n_QtyReceived, @n_QtyReceived, @c_Packkey2, @c_UOM2, @c_Receiptkey, @c_ReceiptLineNumber,
                                @c_Loc, @c_ID, @dt_Lottable05)         

         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
             SET @n_continue = 3  
             SET @n_Err = 31220 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
             SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                           + ': Insert KITDETAIL(T) Table Failed. (ispASNFZ14)'  
         END     
         
         IF @n_continue IN(1,2)
         BEGIN
       	    UPDATE KIT WITH (ROWLOCK)
            SET Status = '9'
      	    WHERE Kitkey = @c_Kitkey         	
      	    
            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN
                SET @n_continue = 3  
                SET @n_Err = 31230 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                              + ': Update KIT Table Failed. (ispASNFZ14)'  
            END     
            
            UPDATE KITDETAIL WITH (ROWLOCK)  
            SET Status = '9'  
        	  WHERE kitkey = @c_KitKey
   	        AND Status <> '9'

            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN
                SET @n_continue = 3  
                SET @n_Err = 31240 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) 
                              + ': Update KITDETAIL Table Failed. (ispASNFZ14)'  
            END        	              	 
         END         

         FETCH NEXT FROM CUR_KIT INTO @c_Storerkey, @c_Facility, @c_Sku, @c_ToSku, @n_QtyReceived, @c_Packkey, @c_UOM, @c_ReceiptLineNumber, 
                                      @c_Lot, @c_Loc, @c_ID, @dt_Lottable05, @c_Packkey2, @c_UOM2, @c_ReasonCode
      END
      CLOSE CUR_KIT 
      DEALLOCATE CUR_KIT
   END
        	   	   	   
   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ14'
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