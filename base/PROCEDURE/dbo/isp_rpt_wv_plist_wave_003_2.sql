SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_003_2                           */    
/* Creation Date: 21-JAN-2022                                              */    
/* Copyright: LFL                                                          */    
/* Written by: Harshitha                                                   */    
/*                                                                         */    
/* Purpose: WMS-18806                                                      */    
/*                                                                         */    
/* Called By: RPT_WV_PLIST_WAVE_003_2                                      */    
/*                                                                         */    
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author      Ver. Purposes                                  */
/* 24-Jan-2022  WLChooi     1.0  DevOps Combine Script                     */
/***************************************************************************/

CREATE PROC [dbo].[isp_RPT_WV_PLIST_WAVE_003_2]    
      @c_Wavekey        NVARCHAR(20),
      @c_Orderkey       NVARCHAR(20)
            
AS    
BEGIN
 
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF     
   SET CONCAT_NULL_YIELDS_NULL OFF 

   SELECT WAVEDETAIL.Wavekey
        , SKU.SKUGROUP 
        , SUM(PICKDETAIL.Qty) Qty
   FROM PICKDETAIL (NOLOCK) 
   JOIN ORDERS (NOLOCK) ON (ORDERS.Orderkey = Pickdetail.Orderkey) 
   JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey) 
   JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku) 
   WHERE (WAVEDETAIL.Wavekey = @c_Wavekey) 
   AND (WAVEDETAIL.Orderkey = @c_Orderkey)
   GROUP BY WAVEDETAIL.Wavekey ,SKU.SKUGROUP 

END      

GO