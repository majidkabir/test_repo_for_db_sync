SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_LP_PLISTC_009_3                            */        
/* Creation Date: 06-DEC-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: WMS-21180 (TW)                                              */      
/*                                                                      */        
/* Called By: RPT_LP_PLISTC_009_3         								      */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 06-DEC-2022  WZPang   1.0  DevOps Combine Script                     */     
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_LP_PLISTC_009_3] (
      @c_LoadKey        NVARCHAR(10)   
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        
  
     SELECT LOADPLANDETAIL.LoadKey, 
         LOADPLAN.Route,  
         LOADPLAN.AddDate,  
         PICKDETAIL.Loc,  
         TRIM(PICKDETAIL.Sku) AS SKU,
         SUM(PICKDETAIL.Qty) AS Qty,
         TRIM(SKU.DESCR) AS DESCR,  
         PACK.CaseCnt,
         PACK.PackKey,  
         LOTATTRIBUTE.Lottable04,  
         LOC.Putawayzone,  
         LOC.LogicalLocation  
     FROM LoadPlanDetail (NOLOCK)  
     JOIN ORDERDETAIL (NOLOCK) ON ( LoadPlanDetail.LoadKey = ORDERDETAIL.LoadKey AND  
                                    LoadPlanDetail.OrderKey = ORDERDETAIL.OrderKey)  
     JOIN ORDERS (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )  
     JOIN PICKDETAIL (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND  
                    ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )  
     JOIN SKU  (NOLOCK) ON  ( SKU.StorerKey = PICKDETAIL.Storerkey ) AND  
                           ( SKU.Sku = PICKDETAIL.Sku )  
     JOIN LoadPlan (NOLOCK) ON ( LoadPlanDetail.LoadKey = LoadPlan.LoadKey )  
     JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey )  
     JOIN PICKHEADER (NOLOCK) ON ( PICKHEADER.OrderKey = ORDERS.OrderKey )  
     JOIN LOTATTRIBUTE (NOLOCK) ON ( LOTATTRIBUTE.Storerkey = PICKDETAIL.Storerkey  
            AND LOTATTRIBUTE.SKU = PICKDETAIL.SKU  
            AND LOTATTRIBUTE.Lot = PICKDETAIL.Lot)  
     JOIN LOC (NOLOCK) ON PICKDETAIL.LOC = LOC.Loc  
     WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )  
	  GROUP BY LoadPlanDetail.LoadKey,  
         LoadPlan.Route,  
         LoadPlan.AddDate,  
         PICKDETAIL.Loc,  
         PICKDETAIL.Sku,  
         SKU.DESCR,  
         PACK.CaseCnt,  
         PACK.PackKey,  
         LOTATTRIBUTE.Lottable04,  
         LOC.Putawayzone,  
         LOC.LogicalLocation
     --ORDER BY LOC.Putawayzone,CASE WHEN ISNULL(loc.LogicalLocation,'') = '' THEN 0 ELSE 1 END, Loc.LogicalLocation, PICKDETAIL.Loc,PICKDETAIL.Sku    
     ORDER BY Loc.LogicalLocation, PICKDETAIL.Loc
    
  
  


END -- procedure    

GO