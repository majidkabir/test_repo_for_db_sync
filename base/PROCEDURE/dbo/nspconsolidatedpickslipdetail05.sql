SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : nspConsolidatedPickSlipDetail05                           */
/* Creation Date: 4-06-2014                                                */
/* Copyright: IDS                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose:                                                                */
/*                                                                         */
/*                                                                         */
/* Usage:                                                                  */
/*                                                                         */
/* Local Variables:                                                        */
/*                                                                         */
/* Called By: r_dw_consolidated_pick05                                     */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date        Author      Ver   Purposes                                  */
/* 14-Jun-2016 CSCHONG     1.1   SOS#371657 Add barcode (CS01)             */
/***************************************************************************/
CREATE PROC    [dbo].[nspConsolidatedPickSlipDetail05]
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
          Remarks=convert(NVARCHAR(255), ORDERS.Notes),
          showbarcode=CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END 
          INTO #RESULT
          FROM LoadPlan (NOLOCK)   
          /*CS01 start*/
          JOIN LoadPlanDetail (NOLOCK) ON ( LoadPlan.LoadKey = LoadPlanDetail.LoadKey )  
          JOIN ORDERS (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey )  
          JOIN ORDERDETAIL (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
          JOIN SKU (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) and  
                               ( SKU.Sku = ORDERDETAIL.Sku )
          JOIN PACK (NOLOCK) ON   ( SKU.PackKey = PACK.PackKey )       
          LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= ORDERS.Storerkey               
               AND listname = 'REPORTCFG' and code ='SHOWBARCODE'                            
	            AND long='r_dw_consolidated_pick05_3' 
	      /*CS01 End*/      
    WHERE ( ( LoadPlan.LoadKey = @c_LoadKey ) )   
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
          ,CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END                   --(CS01)
          
          
 SELECT * FROM #RESULT
 DROP TABLE #RESULT
 
 
 END -- Procedure




GO