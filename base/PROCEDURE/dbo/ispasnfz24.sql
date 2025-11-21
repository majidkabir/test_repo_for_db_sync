SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispASNFZ24                                            */
/* Creation Date: 23-Feb-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-18992 - [CN] Columbia_AddUCCFromLOT01                      */
/*                                                                         */
/* Called By: ispPostFinalizeReceiptWrapper                                */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 23-Feb-2022  WLChooi 1.0   DevOps Combine Script                        */
/* 29-Aug-2022  WLChooi 1.1   WMS-20635 - Map Lottable02 to UCC UDF03(WL01)*/
/***************************************************************************/  
CREATE PROC [dbo].[ispASNFZ24]  
(     @c_Receiptkey        NVARCHAR(10)   
  ,   @b_Success           INT           OUTPUT
  ,   @n_Err               INT           OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255) OUTPUT   
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
      
   DECLARE @n_Continue           INT,
           @n_StartTranCount     INT,
           @c_SKU                NVARCHAR(20),
           @c_Lottable01         NVARCHAR(18),
           @c_Lottable10         NVARCHAR(30),
           @c_Storerkey          NVARCHAR(15),
           @c_ToLot              NVARCHAR(10),
           @c_ToLoc              NVARCHAR(10),
           @c_ToID               NVARCHAR(18),
           @n_QtyReceived        INT,
           @c_Lottable02         NVARCHAR(30),    --WL01
           @c_Facility           NVARCHAR(5),     --WL01
           @c_Configkey          NVARCHAR(30) = 'PostFinalizeReceiptSP',    --WL01
           @c_Authority          NVARCHAR(30),    --WL01
           @c_Option1            NVARCHAR(50),    --WL01
           @c_Option2            NVARCHAR(50),    --WL01
           @c_Option3            NVARCHAR(50),    --WL01
           @c_Option4            NVARCHAR(50),    --WL01
           @c_Option5            NVARCHAR(4000),  --WL01
           @c_MapLott02ToUDF03   NVARCHAR(4000) = ''   --WL01

   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT                                                     

   --WL01 S
   IF @n_Continue IN (1,2)
   BEGIN
      SELECT @c_Facility   = Facility
           , @c_StorerKey  = StorerKey
      FROM RECEIPT WITH (NOLOCK)
      WHERE ReceiptKey = @c_Receiptkey

      EXECUTE nspGetRight                                
         @c_Facility  = @c_Facility,                     
         @c_StorerKey = @c_StorerKey,                    
         @c_sku       = '',
         @c_ConfigKey = @c_Configkey,
         @b_Success   = @b_Success    OUTPUT,             
         @c_authority = @c_Authority  OUTPUT,             
         @n_err       = @n_Err        OUTPUT,             
         @c_errmsg    = @c_Errmsg     OUTPUT,             
         @c_Option1   = @c_Option1    OUTPUT,               
         @c_Option2   = @c_Option2    OUTPUT,               
         @c_Option3   = @c_Option3    OUTPUT,               
         @c_Option4   = @c_Option4    OUTPUT,               
         @c_Option5   = @c_Option5    OUTPUT 

      IF ISNULL(@c_MapLott02ToUDF03,'') = ''
         SELECT @c_MapLott02ToUDF03 = dbo.fnc_GetParamValueFromString('@c_MapLott02ToUDF03', @c_Option5, @c_MapLott02ToUDF03)  
   END
   --WL01 E

   --Main Process
   IF @n_Continue IN (1,2)
   BEGIN
      DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT RD.ReceiptKey, RD.SKU, RD.Lottable10
           , RD.StorerKey, ITRN.Lot, RD.ToLoc, RD.ToID , SUM(RD.QtyReceived)
           , CASE WHEN @c_MapLott02ToUDF03 = 'Y' THEN RD.Lottable02 ELSE '' END   --WL01
      FROM RECEIPTDETAIL RD WITH (NOLOCK)
      JOIN ITRN WITH (NOLOCK) ON ITRN.TranType = 'DP' 
                             AND ITRN.SourceKey = RD.ReceiptKey + RD.ReceiptLineNumber
                             AND ITRN.StorerKey = RD.StorerKey AND ITRN.Sku = RD.SKU
      WHERE RD.ReceiptKey = @c_Receiptkey
      AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' 
                                      THEN @c_ReceiptLineNumber 
                                      ELSE ReceiptLineNumber END
      GROUP BY RD.ReceiptKey, RD.SKU, RD.Lottable10
             , RD.StorerKey, ITRN.Lot, RD.ToLoc, RD.ToID
             , CASE WHEN @c_MapLott02ToUDF03 = 'Y' THEN RD.Lottable02 ELSE '' END   --WL01

      OPEN CUR_RD 

      FETCH NEXT FROM CUR_RD INTO @c_Receiptkey, @c_SKU, @c_Lottable10
                                , @c_Storerkey, @c_ToLot, @c_ToLoc, @c_ToID, @n_QtyReceived
                                , @c_Lottable02   --WL01

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         IF ISNULL(@c_Lottable10,'') = ''
            GOTO NEXT_LOOP
         
         IF NOT EXISTS (SELECT 1 FROM UCC (NOLOCK) WHERE UCCNo = @c_Lottable10)
         BEGIN
            INSERT INTO UCC (UCCNo, Storerkey, SKU, Qty, [Status]
                           , Lot, Loc, ID, Receiptkey, ExternKey
                           , Sourcetype, Userdefined03)   --WL01
            SELECT @c_Lottable10, @c_Storerkey, @c_SKU, @n_QtyReceived, '1'
                 , @c_ToLot, @c_ToLoc, @c_ToID, @c_Receiptkey, ''
                 , 'ispASNFZ24', @c_Lottable02   --WL01

            SELECT @n_err = @@ERROR

            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63535
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert UCC Failed! (ispASNFZ24)' + ' ( '
                               +'SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               GOTO QUIT_SP
            END 
         END

         NEXT_LOOP:
         FETCH NEXT FROM CUR_RD INTO @c_Receiptkey, @c_SKU, @c_Lottable10
                                   , @c_Storerkey, @c_ToLot, @c_ToLoc, @c_ToID, @n_QtyReceived
                                   , @c_Lottable02   --WL01
      END
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
   END 

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_RD') IN (0 , 1)
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD   
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ24'
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