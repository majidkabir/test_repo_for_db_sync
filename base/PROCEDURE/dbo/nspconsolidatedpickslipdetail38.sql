SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Proc : nspConsolidatedPickSlipDetail38                           */
/* Creation Date: 3-03-2017                                                */
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
/* Called By: r_dw_consolidated_pick38                                     */
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
/* 2018-Apr-30  CSCHONG       WMS-4742 - Revised field mapping (CS01)      */
/***************************************************************************/
CREATE PROC    [dbo].[nspConsolidatedPickSlipDetail38]
    @c_LoadKey NVARCHAR(10)
 AS
 BEGIN 
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  DECLARE @d_ExprDate DateTime
  SELECT @d_ExprDate = NULL
  
  SELECT  ORDERS.Storerkey,   
          STO.Company,   
          ORDERS.consigneekey,
 	       ORDERS.OrderKey,      
          ORDERS.LoadKey,   
          ORDERS.ExternOrderKey,   
          LoadDate=LoadPlan.AddDate,   
 	       QtyToPick = SUM(PD.UOMQty),
 	       SKU = PD.Sku,  
          ORDType= ORDERS.[Type],   
         -- ODUOM = ORDERDETAIL.UOM,     --CS01
         ODUOM = CASE WHEN PD.UOM = '6' THEN pack.PackUOM3 ELSE 
	               CASE WHEN  PD.UOM = '3' THEN pack.PackUOM2 ELSE
	               CASE WHEN PD.UOM = '2' THEN pack.PackUOM1 ELSE '' END END END  ,                 --CS01
          SKUDescr = SKU.DESCR,
          C_Address1, C_Address2, C_Address3, C_Address4 , C_Zip,
          Remarks=convert(NVARCHAR(255), ORDERS.Notes),
          showbarcode=CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END 
          INTO #RESULT
          FROM LoadPlan (NOLOCK)   
          /*CS01 start*/
          JOIN LoadPlanDetail WITH (NOLOCK) ON ( LoadPlan.LoadKey = LoadPlanDetail.LoadKey )  
          JOIN ORDERS WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey )  
          JOIN ORDERDETAIL WITH (NOLOCK) ON ( ORDERS.OrderKey = ORDERDETAIL.OrderKey )
          JOIN PICKDETAIL AS PD WITH (NOLOCK) ON PD.orderkey =ORDERDETAIL.OrderKey AND PD.OrderLineNumber = ORDERDETAIL.OrderLineNumber
                                              AND PD.Sku = ORDERDETAIL.Sku 
          LEFT JOIN STORER STO WITH (NOLOCK) ON STO.storerkey = ORDERS.ConsigneeKey
          JOIN SKU WITH (NOLOCK) ON ( SKU.StorerKey = ORDERDETAIL.Storerkey ) and  
                               ( SKU.Sku = ORDERDETAIL.Sku )
          JOIN PACK WITH (NOLOCK) ON   ( SKU.PackKey = PACK.PackKey )       
          LEFT JOIN CODELKUP C WITH (nolock) ON C.storerkey= ORDERS.Storerkey               
               AND listname = 'REPORTCFG' and code ='SHOWBARCODE'                            
	            AND long='r_dw_consolidated_pick38_3' 
	      /*CS01 End*/      
    WHERE ( ( LoadPlan.LoadKey = @c_LoadKey ) )   
 	GROUP BY ORDERS.Storerkey,   
          STO.Company,   
          ORDERS.consigneekey,
 	       ORDERS.OrderKey,      
          ORDERS.LoadKey,   
          ORDERS.ExternOrderKey,   
          LoadPlan.AddDate,   
          PD.Sku,    
          SKU.DESCR, ORDERS.[Type],   
          --ORDERDETAIL.UOM,  --CS01 Start
          CASE WHEN PD.UOM = '6' THEN pack.PackUOM3 ELSE 
	               CASE WHEN  PD.UOM = '3' THEN pack.PackUOM2 ELSE
	               CASE WHEN PD.UOM = '2' THEN pack.PackUOM1 ELSE '' END END END  ,                 --CS01 END
          C_Address1, C_Address2, C_Address3, C_Address4, C_Zip, convert(NVARCHAR(255), ORDERS.Notes)
          ,CASE WHEN ISNULL(C.Code,'') <> '' THEN 'Y' ELSE 'N' END                   
          
          
 SELECT * FROM #RESULT
 DROP TABLE #RESULT
 
 
 END -- Procedure




GO