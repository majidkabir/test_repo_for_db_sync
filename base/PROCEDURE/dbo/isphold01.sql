SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  ispHold01                                          */
/* Creation Date:  06-Mar-2019                                          */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-8016 CN-Fabory Inventory unhold by lottable02          */
/*           validation                                                 */
/*           storerconfig: HoldStatusChangeValidation_SP                */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: Inventory Hold (isp_HoldStatusChangeValidation_Wrapper)   */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver  Purposes                                   */
/* 28-Jun-2019 CSCHONG  1.1  WMS-9516 revised field logic (CS01)        */
/************************************************************************/

CREATE PROC [dbo].[ispHold01]
   @c_InventoryHoldkey   NVARCHAR(10), 
   @c_NewHoldStatus NVARCHAR(1),
   @c_prompttosave  NVARCHAR(10) = 'N' OUTPUT,
   @b_Success int OUTPUT,
   @n_err     int OUTPUT,
   @c_errmsg  NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON   -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
           @n_StartTranCnt int
           
   DECLARE @c_Lottable02 NVARCHAR(18),
           @c_Lot NVARCHAR(10),
           @c_CurrHoldStatus NVARCHAR(1),
           @c_Storerkey NVARCHAR(15),
           @c_Sku NVARCHAR(20),
           @n_InvQty INT,
           @n_UCCQty INT,
           @d_Lottable05 DATETIME       --CS01
                        
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @b_Success = 1, @n_err = 0, @c_errmsg = '', @c_Prompttosave  ='N', @n_InvQty = 0, @n_UCCQty = 0
   
   SELECT @c_CurrHoldStatus = IH.Hold,
          @c_Storerkey = IH.Storerkey,
          @c_Sku = IH.Sku,
          @c_Lottable02 = IH.Lottable02,
          @c_Lot = IH.Lot,
          @d_Lottable05 = IH.Lottable05            --CS01
   FROM INVENTORYHOLD  IH (NOLOCK)
   JOIN SKU (NOLOCK) ON IH.Storerkey = SKU.Storerkey AND IH.Sku = SKU.Sku
   WHERE IH.InventoryHoldkey = @c_Inventoryholdkey
   AND SKU.Busr1 = 'Y' --Only for modulize sku
   
   IF @c_NewHoldStatus = '0' AND @c_CurrHoldStatus = '1' AND (ISNULL(@c_Lottable02,'') <> '' OR ISNULL(@c_Lot,'') <> '')
   BEGIN
      IF ISNULL(@c_Lot,'') <> ''
      BEGIN        
         SELECT @n_InvQty = SUM(LLI.Qty)
         FROM LOTXLOCXID LLI (NOLOCK)
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
         WHERE LLI.Lot = @c_Lot
         
         SELECT @n_UCCQty = SUM(Qty)
         FROM UCC (NOLOCK) 
         WHERE Lot = @c_Lot

         IF ISNULL(@n_InvQty,0) <> ISNULL(@n_UCCQty,0)
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Unhold rejected. UCC Qty is not matched with Inventory Qty of lot ''' + RTRIM(@c_lot) + ''' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END                        
         ELSE
         BEGIN
            SET @c_Prompttosave = 'Y'
            SET @c_errmsg = 'Do you want to unhold lot ''' + RTRIM(@c_lot) + ''' ?'
         END
      END
      ELSE
      BEGIN --by lottable02
         SELECT @n_InvQty = SUM(LLI.Qty)
         FROM LOTXLOCXID LLI (NOLOCK)
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
         WHERE LA.Lottable02 = @c_Lottable02
         AND LA.Storerkey = @c_Storerkey
         AND (LA.Sku = @c_Sku OR ISNULL(@c_Sku,'')='')
         AND (LA.Lottable05 = @d_Lottable05 OR ISNULL(@d_Lottable05,'') = '')     --CS01

         SELECT @n_UCCQty = SUM(UCC.Qty)
         FROM UCC (NOLOCK) 
         JOIN LOTATTRIBUTE LA (NOLOCK) ON UCC.Lot = LA.Lot
         WHERE LA.Lottable02 = @c_Lottable02
         AND UCC.Storerkey = @c_Storerkey AND UCC.Status <> '6'       --CS01
         AND (UCC.Sku = @c_Sku OR ISNULL(@c_Sku,'')='')
         AND (LA.Lottable05 = @d_Lottable05 OR ISNULL(@d_Lottable05,'') = '')     --CS01
         
         IF ISNULL(@n_InvQty,0) <> ISNULL(@n_UCCQty,0)
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 36020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+':Unhold rejected. UCC Qty is not matched with Inventory Qty of lottable02 ''' + RTRIM(@c_lottable02) + ''' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END       
         ELSE                                   
         BEGIN
            SET @c_Prompttosave = 'Y'
            SET @c_errmsg = 'Do you want to unhold lottable02 ''' + RTRIM(@c_lottable02) + ''' ?'
         END
      END           
   END   
END

QUIT_SP:

IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
 SELECT @b_success = 0
 IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  ROLLBACK TRAN
 END
 ELSE
 BEGIN
  WHILE @@TRANCOUNT > @n_StartTranCnt
  BEGIN
   COMMIT TRAN
  END
 END
 execute nsp_logerror @n_err, @c_errmsg, 'ispHold01'
 --RAISERROR @n_err @c_errmsg
 RETURN
END
ELSE
BEGIN
 SELECT @b_success = 1
 WHILE @@TRANCOUNT > @n_StartTranCnt
 BEGIN
  COMMIT TRAN
 END
 RETURN
END

GO