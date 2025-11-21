SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: isp_RPT_WV_WAVPICKSUM_004_2                           */      
/* Creation Date: 04-NOV-2022                                              */      
/* Copyright: LFL                                                          */      
/* Written by: WZPang                                                      */      
/*                                                                         */      
/* Purpose: WMS-21095 - TW-NIK WM Report_WAVPICKSUM - CR                   */      
/*                                                                         */      
/* Called By: RPT_WV_WAVPICKSUM_004_2                                      */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */    
/* 04-NOV-2022  WZPang  1.0   DevOps Combine Script                        */  
/***************************************************************************/  
CREATE   PROC [dbo].[isp_RPT_WV_WAVPICKSUM_004_2] ( 
      @c_Wavekey           NVARCHAR(10)
    , @c_LocationCategory  NVARCHAR(10)
    )
AS  
BEGIN   
   SET NOCOUNT ON        
   SET ANSI_NULLS OFF        
   SET QUOTED_IDENTIFIER OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   SELECT WAVE.Wavekey
        ,    PICKDETAIL.Loc
        ,    LEFT(PICKDETAIL.SKU,6) + '-' + SUBSTRING(PICKDETAIL.SKU,7,3) AS Material
        ,    SUBSTRING(PICKDETAIL.Sku,10,3) AS Size
        ,    CAST(PACK.CaseCnt AS INT) AS CaseCnt
        ,    PICKDETAIL.ID
        ,    FLOOR(SUM(PICKDETAIL.Qty) / PACK.CaseCnt) AS CS
        ,    SUM(PICKDETAIL.Qty) % CAST(PACK.CaseCnt AS INT) AS pcs
		  ,	SUM(PICKDETAIL.Qty) AS PICKDETAILQty
    FROM WAVE (NOLOCK)
    JOIN WAVEDETAIL  (NOLOCK) ON (WAVE.WaveKey = WAVEDETAIL.WaveKey)
    JOIN PICKDETAIL  (NOLOCK) ON (WAVEDETAIL.Orderkey = PICKDETAIL.Orderkey)
    JOIN LOC LOC  (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc)
    JOIN SKU  (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)  
    JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)  
    WHERE WAVE.Wavekey = @c_Wavekey AND LOC.LocationCategory = @c_LocationCategory
    GROUP BY WAVE.Wavekey
        ,    LOC.LocationCategory
        ,    PICKDETAIL.Loc
		  ,    PICKDETAIL.SKU
        ,    PACK.CaseCnt
        ,    PICKDETAIL.ID	 
	ORDER BY LocationCategory, PICKDETAIL.Loc

END -- procedure   

GO