SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispInventoryHoldByReceipt                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: SOS#297511:Auto Create ASN for AEO ECOM Orders              */
/*                                                                      */
/* Input Parameters: @c_ReceiptKey                                      */
/*                 , @c_ReasonCode                                      */
/*                 , @c_ReceiptLineNumber                               */
/* Output Parameters: @b_success , @n_err, @c_errmsg                    */
/*                                                                      */
/* Return Status: NONE                                                  */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/*                                                                      */
/* Called By: of_receipt_hold_lot  ASN Maintenance Screen               */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */ 
/*                                                                      */
/*                                                                      */
/* Updates:                                                             */
/*Date         Author  Ver. Purposes                                    */
/*15-Jan-2014  YTWan   1.1  SOS#298639 - Washington - Finalize by       */
/*                          Receipt Line (Wan01)                        */
/************************************************************************/

CREATE PROC [dbo].[ispInventoryHoldByReceipt]
      @c_ReceiptKey   NVARCHAR(10)
,     @c_ReasonCode   NVARCHAR(10)
,     @b_success  int OUTPUT
,     @n_err      int OUTPUT
,     @c_errmsg NVARCHAR(250) OUTPUT
,     @c_ReceiptLineNumber    NVARCHAR(5) = ''  --(Wan01)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE   @n_continue   int
   ,         @n_starttcnt  int -- bring forward tran count
   ,         @b_debug      int

   SELECT @n_continue = 1, @b_debug = 0, @b_success = 1
   SELECT @n_starttcnt = @@TRANCOUNT

   SET @c_ReceiptLineNumber = ISNULL(RTRIM(@c_ReceiptLineNumber),'')    --(Wan01)

   BEGIN TRAN
         
   IF dbo.fnc_RTrim(@c_ReasonCode) IS NULL OR dbo.fnc_RTrim(@c_ReasonCode) = ''
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=78401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Reason Code CANNOT be BLANK. (ispInventoryHoldByReceipt)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
   END 
   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @cLOT NVARCHAR(10)

      SELECT LOT
      INTO   #LotByBatch 
      FROM   ITRN (NOLOCK)
      WHERE  Sourcekey like @c_ReceiptKey + RTRIM(@c_ReceiptLineNumber) + '%'  --(Wan01) 
      AND    TranType = 'DP'
      AND   (SourceType = 'ntrReceiptDetailUpdate' OR SourceType = 'ntrReceiptDetailAdd' )
      

      WHILE EXISTS( SELECT * FROM #LotByBatch )
      BEGIN
         SET ROWCOUNT 1

         SELECT @cLOT = lot FROM #LotByBatch
         SET ROWCOUNT 0
         If @b_debug = 1 
         Begin
            Select '@cLOT: ' + @cLOT
         End
            
         EXECUTE nspInventoryHold @cLOT
         ,              ''
         ,              ''
         ,              @c_ReasonCode
         ,              '1'
         ,              @b_Success OUTPUT
         ,              @n_err OUTPUT
         ,              @c_errmsg OUTPUT

         IF @b_Success = 0 
         BEGIN
            SELECT @n_continue = 3
            DELETE FROM #LotByBatch
         END
         ELSE
         BEGIN
            DELETE FROM #LotByBatch WHERE lot = @cLOT
         END
      END
   END -- IF @n_continue = 1 OR @n_continue = 2
   
   IF @n_continue = 3
   BEGIN 
      SELECT @b_success = 0 
      IF (@@TRANCOUNT = 1) AND (@@TRANCOUNT > @n_starttcnt)
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
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END --MAIN



GO