SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger:  ispPopulateTOASNHeader_CBTW                                */
/* Creation Date: 22-Nov-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                       				   */
/*                                                                      */
/* Purpose:  SOS#91980 Auto-Populate Receipt Header when MBOL Ship.     */
/*				 Request by CibaVision.				                           */		
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
/* 04-12-2007   Vicky     Change of Mapping	(Vicky01)                  */
/* 06-12-2007   Vicky     Change doctype to R and not A                 */
/* 12-05-2008   TLTING    Save more infor to Receipt                    */
/* 14-07-2009   GTGOH	  SOS#141495 - Remove duplicate checking on     */ 
/*                                     ExternReceiptKey 	               */
/* 15-11-2010   LimKH     fix bug                                       */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispPopulateTOASNHeader_CBTW] 
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
            @c_OrderType            NVARCHAR(10), 
            @c_RecType              NVARCHAR(10),
            @c_CarrierKey           NVARCHAR(15) -- (Vicky01)
            , @c_facility			   NVARCHAR(5)   -- 12-05-2008   TLTING
            , @c_originCountry      NVARCHAR(30)   -- 12-05-2008   TLTING
            , @c_ASNReason          NVARCHAR(10)   -- 12-05-2008   TLTING  
            , @c_CarrierReference   NVARCHAR(18)   -- 12-05-2008   TLTING

   DECLARE  @c_NewReceiptKey   NVARCHAR(10),
            @n_continue        int,
            @b_success         int,
            @n_err             int,
            @c_errmsg          NVARCHAR(255)

   SELECT @n_continue = 1, @b_success = 1, @n_err = 0
 
   SET @c_originCountry = 'TWN'  -- 12-05-2008   TLTING
   SET @c_ASNReason = 'CB11'       -- 12-05-2008   TLTING

   -- Insert into Receipt Header   
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN         
      SELECT @c_StorerKey = ORDERS.Storerkey,  
--              @c_CarrierName = ORDERS.ConsigneeKey,
             @c_CarrierKey = ORDERS.ConsigneeKey, -- (Vicky01)
             @c_ExternReceiptKey = ORDERS.ExternOrderkey,
             @c_WarehouseReference = ORDERS.Orderkey,
             @c_POKey = ORDERS.BuyerPO,
             @d_EffectiveDate = DeliveryDate,
             @d_ReceiptDate = DeliveryDate, 
             @c_OrderType = ORDERS.Type,
             @c_facility = ORDERS.facility,               -- 12-05-2008   TLTING
             @c_CarrierReference = Pickheader.Pickheaderkey -- 12-05-2008   TLTING
      FROM   ORDERS WITH (NOLOCK)
      JOIN   MBOL WITH (NOLOCK) ON (MBOL.MBOLKey = ORDERS.MBOLKey)
      LEFT JOIN   Pickheader WITH (NOLOCK) ON (Pickheader.OrderKey = ORDERS.OrderKey) -- 12-05-2008   TLTING
      WHERE  ORDERS.OrderKey = @c_OrderKey
           
		IF RTRIM(@c_StorerKey) IS NOT NULL
		BEGIN
/* Comment Start #141495
         IF NOT EXISTS(SELECT 1 FROM RECEIPT WITH (NOLOCK) 
                       WHERE  StorerKey = @c_StorerKey 
                       AND    ExternReceiptKey = @c_ExternReceiptKey)
	     BEGIN 
    Comment End #141495 */
            SELECT @c_RecType = ISNULL(SHORT, '') 
            FROM   CODELKUP WITH (NOLOCK)
            WHERE  ListName = 'ORDTYP2ASN' AND Code = @c_OrderType

   			-- Get next receipt key
   			SELECT @b_success = 0
   			EXECUTE   nspg_getkey
   			'RECEIPT'
   			, 10
   			, @c_NewReceiptKey OUTPUT
   			, @b_success OUTPUT
   			, @n_err OUTPUT
   			, @c_errmsg OUTPUT

            IF @b_success = 1
            BEGIN
               INSERT INTO RECEIPT (ReceiptKey, ExternReceiptKey, WarehouseReference, StorerKey, CarrierKey, -- (Vicky01) --CarrierName, 
   					     POKey, EffectiveDate, ReceiptDate, RecType, DOCTYPE,
                       facility,   OriginCountry,   ASNReason, CarrierReference )
               VALUES (@c_NewReceiptKey, @c_ExternReceiptKey, @c_warehousereference, @c_StorerKey, @c_CarrierKey, -- (Vicky01) --@c_CarrierName,
                       @c_POKey, @d_EffectiveDate, @d_ReceiptDate, @c_RecType, 'R', 
                       @c_facility,  @c_originCountry,  @c_ASNReason, @c_CarrierReference  )  -- 12-05-2008   TLTING
            END
            ELSE
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
      			SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate Receipt Key Failed! ispPopulateTOASNHeader_CBTW' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
         --Comment #141495 END -- End Not exists in Receipt Header then insert
      END    
      ELSE
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63526   
   		SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Storer Key is BLANK! (ispPopulateTOASNHeader_CBTW)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   END -- if continue = 1 or 2

END





GO