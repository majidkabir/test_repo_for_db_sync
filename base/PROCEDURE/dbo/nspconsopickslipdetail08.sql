SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspConsoPickSlipDetail08]
@c_LoadKey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_ExprDate DateTime
   SELECT  @d_ExprDate = NULL
  SELECT  ORDERS.Storerkey,   
          ORDERS.C_Company,   
          ORDERS.LabelPrice,
 	 ORDERS.OrderKey,      
          LoadPlan.LoadKey,   
          ORDERS.ExternOrderKey,   
          LoadPlan.AddDate,   
 	 QtyToPick = SUM(ORDERDETAIL.QtyPicked + ORDERDETAIL.QtyAllocated + ORDERDETAIL.ShippedQty),   
          ORDERDETAIL.Sku,   
          PACK.PackUOM1,   
          PACK.CaseCnt,   
          PACK.PackUOM3,   
          PACK.PackUOM4,   
          PACK.Pallet,   
          SKU.DESCR,
          ExprDate =  @d_ExprDate,
          Status='F',
          C_Address1, C_Address2, C_Address3, C_Address4 , C_Zip,
          SKU.StdNetWgt,
          SKU.StdCube,
          Remarks=CONVERT(NVARCHAR(255), ORDERS.Notes),
			 ORDERS.ConsigneeKey,
			 ORDERS.DeliveryDate
     INTO #RESULT
     FROM LoadPlan (NOLOCK) 
     JOIN LoadPlanDetail (NOLOCK) ON ( LoadPlan.LoadKey = LoadPlanDetail.LoadKey )
     JOIN ORDERS (NOLOCK) ON ( LoadPlanDetail.OrderKey = ORDERS.OrderKey ) 
     JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
     JOIN SKU (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) and  
                          ( SKU.Sku = ORDERDETAIL.Sku ) 
     JOIN PACK (NOLOCK) ON ( SKU.PackKey = PACK.PackKey )
     JOIN (SELECT DISTINCT ORDERKEY FROM ORDERDETAIL (NOLOCK) WHERE LoadKey = @c_LoadKey AND
              (Lottable04 > '19000101' OR Lottable04 IS NOT NULL) )  as NonCodeDate 
         ON (NonCodeDate.ORDERKEY = ORDERS.OrderKey) 
    WHERE LoadPlan.LoadKey = @c_LoadKey
    GROUP BY ORDERS.Storerkey,   
          ORDERS.C_Company,   
          ORDERS.LabelPrice,
 	       ORDERS.OrderKey,      
          LoadPlan.LoadKey,   
          ORDERS.ExternOrderKey,   
          LoadPlan.AddDate,   
          ORDERDETAIL.Sku,   
          PACK.PackUOM1,   
          PACK.CaseCnt,   
          PACK.PackUOM3,   
          PACK.Qty,   
          PACK.PackUOM4,   
          PACK.Pallet,   
          SKU.DESCR,
          C_Address1, C_Address2, C_Address3, C_Address4, C_Zip, 
			 SKU.StdNetWgt, SKU.StdCube, CONVERT(NVARCHAR(255), ORDERS.Notes),
			 ORDERS.ConsigneeKey,
			 ORDERS.DeliveryDate	 

 SELECT * FROM #RESULT
 DROP TABLE #RESULT
END -- Procedure

GO