SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC    [dbo].[nspConsolidatedPickSlipDetail37]
    @c_LoadKey NVARCHAR(10)
 AS
 BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  DECLARE @d_ExprDate DateTime

  SELECT @d_ExprDate = NULL
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
          Remarks=convert(NVARCHAR(255), ORDERS.Notes)
     INTO #RESULT
     FROM LoadPlan (NOLOCK),   
          LoadPlanDetail (NOLOCK),   
          ORDERS (NOLOCK),   
          ORDERDETAIL (NOLOCK),
          PACK (NOLOCK),   
          SKU (NOLOCK)  
    WHERE ( LoadPlan.LoadKey = LoadPlanDetail.LoadKey ) and  
          ( ORDERS.OrderKey = ORDERDETAIL.OrderKey ) and  
          ( LoadPlanDetail.OrderKey = ORDERS.OrderKey ) and  
          ( SKU.StorerKey = ORDERDETAIL.Storerkey ) and  
          ( SKU.Sku = ORDERDETAIL.Sku ) and  
 	 ( SKU.PackKey = PACK.PackKey ) and   
          ( ( LoadPlan.LoadKey = @c_LoadKey ) )   
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
          C_Address1, C_Address2, C_Address3, C_Address4, C_Zip, SKU.StdNetWgt, SKU.StdCube, convert(NVARCHAR(255), ORDERS.Notes)
 SELECT * FROM #RESULT
 DROP TABLE #RESULT
 END -- Procedure




GO