SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 2017-07-25   TLTING  1.1   SET Option                         */

CREATE PROC    [dbo].[nspg_GETSKU2]
               @c_StorerKey   NVARCHAR(15)
,              @c_sku         NVARCHAR(20)          OUTPUT
,              @b_success     int               OUTPUT
,              @n_err         int               OUTPUT
,              @c_errmsg      NVARCHAR(250)         OUTPUT
,              @c_uom         NVARCHAR(10)          OUTPUT
,              @c_packkey     NVARCHAR(10)          OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
	DECLARE @n_continue int
	SELECT @n_continue = 1
	SELECT @b_success = 1
	
	IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey)
	BEGIN
		IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey)
		BEGIN
			SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
			FROM SKU (NOLOCK), PACK (NOLOCK)
			WHERE AltSku = @c_sku and StorerKey = @c_StorerKey
			AND SKU.PackKey = PACK.PackKey
			RETURN	           
		END

		IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey)
		BEGIN
			SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
			FROM SKU (NOLOCK), PACK (NOLOCK)
			WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey
			AND SKU.PackKey = PACK.PackKey
			RETURN
		END

   	IF EXISTS (SELECT * FROM UPC (NOLOCK) WHERE Upc = @c_sku)   -- BEGIN UPC Code Found
   	BEGIN  
   		SELECT @c_sku = Sku, @c_packkey = PackKey, @c_uom = UOM 
         FROM UPC (NOLOCK) WHERE Upc = @c_sku
			RETURN
   	END

		IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku) --Why are we not checking for "@c_StorerKey"
		BEGIN
			SELECT @n_continue=3
			SELECT @n_err=68500
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Sku (nspg_GETSKU2)"
		END
		ELSE
		BEGIN
			SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
			FROM SKU (NOLOCK), PACK (NOLOCK)
			WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey
			AND SKU.PackKey = PACK.PackKey
		END
   END


	IF @n_continue = 3
	BEGIN
		SELECT @b_success = 0
	END
END


GO