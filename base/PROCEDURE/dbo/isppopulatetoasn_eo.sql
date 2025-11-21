SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger:  ispPopulateToASN_EO                                        */
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
/* Called By:                                       							      */
/*                                                                      */
/* PVCS Version: 1.0                                                   	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 17.Aug.2005  June		  SOS#39552 - Check the Receipt before Insert   */
/*											  to prevent duplicate records		            	*/
/* 29.Feb.2012  GTGOH     SOS#237799 - Console with ispPopulateToASN_E  */
/*                        (GOH01)                                       */
/* 22.Aug.2018  NJOW01    WMS-6054 SG-CPV change mapping                */
/* 18.Sep.2023  NJOW02    WMS-23682 add mapping Appointment_No          */  
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPopulateToASN_EO] 
   @c_OrderKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE  @c_StorerKey            NVARCHAR(15),
            @c_CarrierName          NVARCHAR(30),
	         @c_ExternReceiptKey     NVARCHAR(20),
            @c_WarehouseReference   NVARCHAR(10),
            @c_POKey                NVARCHAR(20),
            @d_EffectiveDate        datetime,
            @d_ReceiptDate          datetime,
            @c_Facility             NVARCHAR(5),
            @n_ShippedQty           int

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
             @c_CarrierName = ISNULL(ORDERS.ConsigneeKey,''),
--GOH01 Console with ispPopulateToASN_E and remove ispPopulateToASN_E
             @c_ExternReceiptKey = ORDERS.ExternOrderkey,  --NJOW01
				 --@c_ExternReceiptKey = LEFT(LTRIM(RTRIM(ORDERS.ConsigneeKey)) + '/' + LTRIM(RTRIM(ORDERS.ExternOrderkey)),20),
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_POKey = ORDERS.BuyerPO,
             @d_EffectiveDate = ORDERS.DeliveryDate,
             @d_ReceiptDate = ORDERS.DeliveryDate,
             @c_Facility = ORDERS.Facility,
             @n_ShippedQty = SUM(OrderDetail.QtyPicked + OrderDetail.ShippedQty)
      FROM   ORDERS (NOLOCK)
		JOIN 	 ORDERDETAIL (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey)      
      JOIN   MBOL (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      WHERE  ORDERS.OrderKey = @c_OrderKey
		GROUP BY ORDERS.Storerkey,  
            ORDERS.ConsigneeKey,
            ORDERS.ExternOrderkey,
            ORDERS.Orderkey,
            ORDERS.BuyerPO,
            ORDERS.DeliveryDate,
            ORDERS.DeliveryDate,
            ORDERS.Facility      
           
		IF dbo.fnc_RTrim(@c_StorerKey) IS NOT NULL
		BEGIN
			-- Start : SOS39552
			IF NOT EXISTS (SELECT 1 FROM RECEIPT (NOLOCK) WHERE WarehouseReference = @c_OrderKey)
			BEGIN
			-- End : SOS39552
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
	                                 POKey, BilledContainerQty, EffectiveDate, ReceiptDate, Facility, RecType, DOCTYPE, ASNReason, Appointment_No) --NJOW01  NJOW02
	            VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, @c_CarrierName,
	                    @c_POKey, @n_ShippedQty, @d_EffectiveDate, @d_ReceiptDate, @c_Facility, 'GRN', 'R', 'CPV-RPL', CAST(@n_ShippedQty AS NVARCHAR))	--GOH01 NJOW02
--GOH01	                    @c_POKey, @n_ShippedQty, @d_EffectiveDate, @d_ReceiptDate, @c_Facility, 'GER', 'R')
	         END
	         ELSE
	         BEGIN
	            SELECT @n_continue = 3
	            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
	   					SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Generate Receipt Key Failed! ispPopulateToASN_EO" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	         END
	       END -- SOS39552
	      END    
	      ELSE
	      BEGIN
	         SELECT @n_continue = 3
	         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
	   			 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Storer Key is BLANK! (ispPopulateToASN_EO)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	      END
   END -- if continue = 1 or 2
END

GO