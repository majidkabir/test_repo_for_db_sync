SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_013_2                        */        
/* Creation Date: 24-AUG-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: Convert to Logi Report - r_dw_print_wave_pickslip_21_2  (TW)*/      
/*                                                                      */        
/* Called By: RPT_WV_PLIST_WAVE_013_2										      */        
/*                                                                      */        
/* PVCS Version: 1.0                                                    */        
/*                                                                      */        
/* Version: 7.0                                                         */        
/*                                                                      */        
/* Data Modifications:                                                  */        
/*                                                                      */        
/* Updates:                                                             */        
/* Date         Author   Ver  Purposes                                  */
/* 24-AUG-2022  WZPang   1.0  DevOps Combine Script                     */     
/************************************************************************/        
CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_013_2] (
      @c_WaveKey   NVARCHAR(10),
      @c_Orderkey  NVARCHAR(10), 
      @c_PreGenRptData     NVARCHAR(10)    
)   
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        
   
   
   SELECT WAVEDETAIL.Wavekey
         ,SKU.SKUGROUP 
         ,SUM(PICKDETAIL.Qty) Qty
   FROM PICKDETAIL (NOLOCK) 
          JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = Pickdetail.Orderkey) 
          JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey) 
          JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku) 
   WHERE (WAVEDETAIL.Wavekey = @c_Wavekey) 
          AND (WAVEDETAIL.Orderkey = @c_Orderkey)
   GROUP BY WAVEDETAIL.Wavekey ,SKU.SKUGROUP 

      
END -- procedure    

GO