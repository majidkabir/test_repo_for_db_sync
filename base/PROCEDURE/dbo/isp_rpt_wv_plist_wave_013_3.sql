SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/        
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_013_3                        */        
/* Creation Date: 24-AUG-2022                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: WZPang                                                   */    
/*                                                                      */    
/* Purpose: Convert to Logi Report - r_dw_print_wave_pickslip_21_3  (TW)*/      
/*                                                                      */        
/* Called By: RPT_WV_PLIST_WAVE_013_3                                   */        
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
/* 01-JUN-2023  CHONGCS  1.1  WMS-22661 revised field logic(CS01)       */
/************************************************************************/        
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_013_3] (
      @c_WaveKey   NVARCHAR(10)
    , @c_PreGenRptData     NVARCHAR(10)    
)        
 AS        
 BEGIN        
            
   SET NOCOUNT ON        
   SET ANSI_NULLS ON        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
   SET ANSI_WARNINGS ON        
    
    DECLARE    
           @n_StartTCnt       INT  
         , @n_Continue        INT   

   IF @c_PreGenRptData = '0' SET @c_PreGenRptData = ''  
   SET @n_StartTCnt = @@TRANCOUNT  
   
   IF ISNULL(@c_PreGenRptData,'') = ''
   SELECT '' AS [route],--ORDERS.Route,    --CS01 
          Wave.AddDate,   
          WAVE.WaveKey,   
          PICKDETAIL.LOC,   
          PICKDETAIL.SKU,    
          SKU.DESCR,    
          PACK.CaseCnt,   
          SUM(PICKDETAIL.Qty),                 --CS01   
          LOC.LogicalLocation,  
          LOTATTRIBUTE.Lottable02,   
          CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN   
                    ISNULL(SKU.RetailSku,'')  
          ELSE '' END AS RetailSku,  
          convert(nvarchar(10),LOTATTRIBUTE.Lottable04,126)  AS Lottable04,  
          CASE WHEN ISNULL(C2.Short,'N') = 'Y' THEN LOC.Putawayzone ELSE '' END AS Putawayzone,   
          ISNULL(C2.Short,'N') AS ShowPutawayzone,   
          PACK.InnerPack   
                                                                
   FROM ORDERS (NOLOCK)    
   JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey   
   JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.LOC   
   JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey   
   JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey   
   JOIN SKU (NOLOCK) ON SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.SKU = PICKDETAIL.SKU   
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PackKey   
   JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot  
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME='LOCCASHOW' AND C.Storerkey=ORDERS.storerkey--AND C.code=LOC.LocationCategory  
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME='REPORTCFG' AND C1.Long='r_dw_print_wave_pickslip_21'   
                                       AND C1.Code='SHOWPICKLOC' AND c1.Storerkey=ORDERS.storerkey  
                                       AND C1.short=ORDERS.stop                                          
   LEFT JOIN CODELKUP C2 WITH (NOLOCK) ON  C2.LISTNAME = 'REPORTCFG' AND C2.Long = 'r_dw_print_wave_pickslip_21'     
                                       AND C2.Code = 'ShowPutawayzone' AND C2.Storerkey = ORDERS.Storerkey           
   LEFT JOIN v_storerconfig2 SC WITH (NOLOCK) ON ORDERS.Storerkey = SC.Storerkey AND SC.Configkey = 'DELNOTE06_RSKU'    
   WHERE WAVE.WaveKey = @c_WaveKey     
                     AND 1 = CASE WHEN ISNULL(C1.short,'') <> '' AND ISNULL(C.code,'') <> ''   
                     AND C.code=LOC.LocationCategory AND LOC.LocLevel>CONVERT(INT,C.UDF02) THEN 1         
        WHEN ISNULL(C1.short,'N') = 'N'THEN 1 ELSE 0 END  
 --CS01 S
  GROUP BY  
            --ORDERS.Route,        --CS01
            Wave.AddDate, 
            WAVE.WaveKey, 
            PICKDETAIL.LOC, 
            PICKDETAIL.SKU,  
            SKU.DESCR,  
            PACK.CaseCnt, 
            LOC.LogicalLocation,
            LOTATTRIBUTE.Lottable02, 
            CASE WHEN ISNULL(SC.Svalue,'') = '1' AND SKU.Sku <> SKU.RetailSku AND ISNULL(SKU.RetailSku,'') <> '' THEN 
                     ISNULL(SKU.RetailSku,'')
            ELSE '' END ,
            convert(nvarchar(10),LOTATTRIBUTE.Lottable04,126),
            CASE WHEN ISNULL(C2.Short,'N') = 'Y' THEN LOC.Putawayzone ELSE '' END ,
            ISNULL(C2.Short,'N') ,  
            PACK.InnerPack, 
            SKU.ALTSKU 
  --CS01 E
   ORDER BY  LOC.LogicalLocation,PICKDETAIL.LOC,   
             PICKDETAIL.SKU, LOTATTRIBUTE.Lottable02 ,convert(nvarchar(10),LOTATTRIBUTE.Lottable04,126)   
  
  
   
END -- procedure    

GO