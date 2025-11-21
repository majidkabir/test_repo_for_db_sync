SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROCEDURE [dbo].[ispRequireSerialNo] 
	@c_PickSlipNo NVARCHAR(10) = '', 
	@b_Require bit  OUTPUT
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	
   DECLARE @c_Zone NVARCHAR(10),
           @c_LoadKey NVARCHAR(10),
           @c_OrderKey NVARCHAR(10)

   SELECT @b_Require = 0

   SELECT @c_Zone = PICKHEADER.Zone,
          @c_LoadKey = PICKHEADER.ExternOrderKey,
          @c_OrderKey = PICKHEADER.OrderKey
   FROM   PICKHEADER (NOLOCK)
   WHERE  PICKHEADERKEY = @c_PickSlipNo

   IF dbo.fnc_RTrim(@c_Zone) IS NOT NULL AND dbo.fnc_RTrim(@c_Zone) <> ''
   BEGIN
      IF @c_Zone = '8' or @c_Zone = '3'
      BEGIN
         IF EXISTS(SELECT 1 FROM ORDERDETAIL (NOLOCK)  
                   JOIN SKU (NOLOCK) ON (( ORDERDETAIL.Storerkey = SKU.StorerKey ) AND ( ORDERDETAIL.SKU = SKU.Sku ) AND 
                                         ( SKU.SUSR4 = 'YES' ))
                   WHERE ORDERKEY = @c_OrderKey
                   -- Added By SHONG on 22-Dec-2003. Should Filter by Allocated Order Line Only
                   AND   (QtyAllocated + QtyPicked) > 0 )
            SELECT @b_Require = 1
         ELSE
            SELECT @b_Require = 0
      END
      ELSE
      BEGIN
         IF @c_Zone = '7'
         BEGIN
            IF EXISTS(SELECT 1 FROM ORDERDETAIL (NOLOCK)  
                      JOIN SKU (NOLOCK) ON (( ORDERDETAIL.Storerkey = SKU.StorerKey ) AND ( ORDERDETAIL.SKU = SKU.Sku ) AND 
                                            ( SKU.SUSR4 = 'YES' ))
                      WHERE LoadKey = @c_LoadKey
                      -- Added By SHONG on 22-Dec-2003. Should Filter by Allocated Order Line Only
                      AND   (QtyAllocated + QtyPicked) > 0 )
               SELECT @b_Require = 1
            ELSE
               SELECT @b_Require = 0
         END
      END   
   END -- zone

GO