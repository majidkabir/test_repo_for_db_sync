SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure ispPopulateTOASNHeader : 
--

/************************************************************************/
/* Trigger:  ispPopulateTOASNHeader                                     */
/* Creation Date: 30-Jun-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                     				*/
/*                                                                      */
/* Purpose:  Auto-Populate Receipt Header when MBOL Ship. Request by CV */
/*				 for Ordertype 'EO' - Exchange Returns (SOS37009).				*/		
/*                                                                      */
/* Input Parameters:	@c_OrderKey	- OrderKey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[ispPopulateTOASNHeader] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON

	DECLARE  @c_StorerKey            NVARCHAR(15),
            @c_CarrierName          NVARCHAR(30),
	         @c_ExternReceiptKey     NVARCHAR(20),
            @c_WarehouseReference   NVARCHAR(10),
            @c_POKey                NVARCHAR(20),
            @d_EffectiveDate        datetime,
            @d_ReceiptDate          datetime

   DECLARE  @c_NewReceiptKey   NVARCHAR(10),
            @n_continue        int,
            @b_success         int,
            @n_err             int,
            @c_errmsg          NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0

   -- Insert into Receipt Header   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_StorerKey = ORDERS.Storerkey,  
             @c_CarrierName = ORDERS.ConsigneeKey,
             @c_ExternReceiptKey = ORDERS.ExternOrderkey,
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_POKey = ORDERS.BuyerPO,
             @d_EffectiveDate = DeliveryDate,
             @d_ReceiptDate = DeliveryDate
      FROM   ORDERS (NOLOCK)
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
           
		IF dbo.fnc_RTRIM(@c_StorerKey) IS NOT NULL
		BEGIN
			-- Get next receipt key
			SELECT @b_success = 0
			EXECUTE   nspg_getkey
			"RECEIPT"
			, 10
			, @c_NewReceiptKey OUTPUT
			, @b_success OUTPUT
			, @n_err OUTPUT
			, @c_errmsg OUTPUT
         
         IF @b_success = 1
         BEGIN
            INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, CarrierName, 
					POKey, EffectiveDate, ReceiptDate, RecType, DOCTYPE)
            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, @c_CarrierName,
                    @c_POKey, @d_EffectiveDate, @d_ReceiptDate, 'GER', 'A')
         END
         ELSE
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
   			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! ispPopulateTOASNHeader" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
         END
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
   		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateTOASNHeader)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
      END
   END -- if continue = 1 or 2

END

GO