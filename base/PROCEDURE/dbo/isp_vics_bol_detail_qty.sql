SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[isp_vics_bol_detail_qty] ( 
            @c_mbolkey  NVARCHAR(10)
			  ,@c_consigneekey NVARCHAR(10))
AS
BEGIN
SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  
    SELECT DISTINCT SKU.busr3,
       SKU.busr6, 
       SKU.busr7,
       QTY = ROUND(MD.TTLCTN,2), 
       WEIGHT = ROUND(MD.TTLWeight,2)
    FROM MBOLDETAIL WITH (NOLOCK)
    JOIN LoadPlan WITH (NOLOCK) ON ( MBOLDETAIL.LoadKey = LoadPlan.LoadKey )   
    JOIN ORDERS WITH (NOLOCK) ON ( MBOLDETAIL.OrderKey = ORDERS.OrderKey ) 
    JOIN ORDERDetail WITH (NOLOCK) ON  ( ORDERDetail.OrderKey = ORDERS.OrderKey ) 
    JOIN SKU WITH (NOLOCK) ON ( SKU.SKU = ORDERDetail.SKU AND SKU.StorerKey = ORDERDetail.StorerKey )
    JOIN (SELECT DISTINCT MBOLDET.MBOLKEY AS MBLKey, SUM(MBOLDET.TotalCartons) AS TTLCTN ,
                 SUM(MBOLDET.Weight) AS TTLWeight 
        FROM MBOLDETAIL MBOLDET WITH (NOLOCK)
        JOIN ORDERS ORD WITH (NOLOCK) ON (ORD.OrderKey = MBOLDET.OrderKey)
        WHERE MBOLDET.MBOLKEY = @c_mbolkey
        AND ORD.ConsigneeKey = @c_consigneekey
        GROUP BY MBOLDET.MBOLKEY, ORD.ConsigneeKey) AS MD ON (MD.MBLKey = MBOLDETAIL.MBOLKEY)
    WHERE MBOLDETAIL.MBOLKEY = @c_mbolkey 
    AND ( ORDERS.ConsigneeKey = @c_ConsigneeKey )
    GROUP BY SKU.busr3,
             SKU.busr6, 
             SKU.busr7,
             ORDERS.ExternOrderkey,
             ORDERS.ConsigneeKey,
             MD.TTLCTN,  
             MD.TTLWeight 
END

GO