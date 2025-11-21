SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC    [dbo].[nspg_GETPARENTSKU]
               @c_StorerKey   NVARCHAR(15)
,              @c_sku         NVARCHAR(20)          OUTPUT
,              @b_success     int               OUTPUT
,              @n_err         int               OUTPUT
,              @c_errmsg      NVARCHAR(250)         OUTPUT
,              @c_uom         NVARCHAR(10)          OUTPUT
,              @c_packkey     NVARCHAR(10)          OUTPUT

-- Added by YokeBeen on 04-Nov-2002. (SOS # 8476)
-- To retrieve the Parent Sku SKU.ManufacturerSku from the SKU table for Return.

-- Added by YokeBeen on 24-Jun-2003. (YokeBeen01)
-- Added the check on the 'SKU.ManufacturerSku IS NULL' into the select statement.

AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_continue INT
SELECT @n_continue = 1

DECLARE @c_ManufacturerSku NVARCHAR(20)
select @c_ManufacturerSku = ''

SELECT @b_success = 1
	
	
IF EXISTS (SELECT * FROM UPC (NOLOCK) WHERE Upc = @c_sku)   -- BEGIN UPC Code Found
	BEGIN  
		SELECT @c_sku = Sku, @c_packkey = PackKey, @c_uom = UOM
		  FROM UPC (NOLOCK) WHERE Upc = @c_sku
	END
ELSE
	BEGIN    
		IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey)
			BEGIN
			  IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey)
					BEGIN
						IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey)
							BEGIN
							   IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey)
									BEGIN
										SELECT @n_continue=3
										SELECT @n_err=68500
										SELECT @c_errmsg= 'NSQL' + CONVERT(char(5),@n_err) + ': Bad Sku (nspg_GETPARENTSKU)'
									END
								ELSE
									BEGIN
									   SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
									     FROM SKU (NOLOCK), PACK (NOLOCK)
									    WHERE ManufacturerSku = @c_sku AND StorerKey = @c_StorerKey
											AND SKU.PackKey = PACK.PackKey
									END
							END
					ELSE
					   BEGIN
							SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
							  FROM SKU (NOLOCK), PACK (NOLOCK)
							 WHERE RetailSku = @c_sku AND StorerKey = @c_StorerKey
							 	AND SKU.PackKey = PACK.PackKey
					   END
					END
			    ELSE
					BEGIN
					   SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
					     FROM SKU (NOLOCK), PACK (NOLOCK)
						 WHERE AltSku = @c_sku AND StorerKey = @c_StorerKey
							AND SKU.PackKey = PACK.PackKey
					END
			END
		ELSE
			IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey
									AND (ManufacturerSku = NULL OR ManufacturerSku = '' OR ManufacturerSku IS NULL))	-- (YokeBeen01)
				BEGIN
				   SELECT @c_sku = ManufacturerSku, @c_uom = PACK.PackUOM3, @c_ManufacturerSku = ManufacturerSku  
				     FROM SKU (NOLOCK), PACK (NOLOCK)
					 WHERE Sku = @c_sku AND StorerKey = @c_StorerKey
						AND SKU.PackKey = PACK.PackKey

				   SELECT @c_packkey = SKU.PackKey 
				     FROM SKU (NOLOCK), PACK (NOLOCK)
					 WHERE Sku = @c_ManufacturerSku AND StorerKey = @c_StorerKey
						AND SKU.PackKey = PACK.PackKey
				END
			ELSE
				BEGIN
				   SELECT @c_sku = Sku, @c_packkey = SKU.PackKey, @c_uom = PACK.PackUOM3 
				     FROM SKU (NOLOCK), PACK (NOLOCK)
					 WHERE Sku = @c_sku AND StorerKey = @c_StorerKey
						AND SKU.PackKey = PACK.PackKey
				END
	END  -- END UPC Code Found
     
	IF @n_continue = 3
		BEGIN
			SELECT @b_success = 0
		END
END


GO