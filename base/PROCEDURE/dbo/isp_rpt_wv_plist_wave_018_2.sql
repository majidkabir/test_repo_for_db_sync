SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_018_2                         */
/* Creation Date: 29-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Adarsh                                                    */
/*                                                                       */
/* Purpose: WMS-22131-Migrate WMS Report To LogiReport                   */
/*                                                                       */
/* Called By: RPT_WV_PLIST_WAVE_018_2                                    */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 30-Mar-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_018_2]
(@c_Wavekey NVARCHAR(10), @c_Orderkey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SELECT WAVEDETAIL.WaveKey
        , SKU.SKUGROUP
        , SUM(PICKDETAIL.Qty) Qty
   FROM PICKDETAIL (NOLOCK)
   JOIN ORDERS (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey)
   JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.OrderKey = WAVEDETAIL.OrderKey)
   JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
   WHERE (WAVEDETAIL.WaveKey = @c_Wavekey
   AND WAVEDETAIL.OrderKey = @c_Orderkey)
   GROUP BY WAVEDETAIL.WaveKey
          , SKU.SKUGROUP
END

GO