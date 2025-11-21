SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_PLIST_WAVE_018_3                         */
/* Creation Date: 16-Mar-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Adarsh                                                    */
/*                                                                       */
/* Purpose: WMS-22131-Migrate WMS Report To LogiReport                   */
/*                                                                       */
/* Called By: RPT_WV_PLIST_WAVE_018_3                                    */
/*                                                                       */
/* GitLab Version: 1.0                                                   */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 30-Mar-2023 WLChooi 1.0   DevOps Combine Script                       */
/*************************************************************************/
CREATE   PROC [dbo].[isp_RPT_WV_PLIST_WAVE_018_3]
(@c_WaveKey NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt INT
         , @n_Continue  INT

   SET @n_StartTCnt = @@TRANCOUNT

   SELECT ORDERS.Route
        , WAVE.AddDate
        , WAVE.WaveKey
        , PICKDETAIL.Loc
        , PICKDETAIL.Sku
        , SKU.DESCR
        , PACK.CaseCnt
        , PICKDETAIL.Qty
        , ISNULL(LOC.LogicalLocation,'') AS LogicalLocation
        , ISNULL(LOTATTRIBUTE.Lottable02,'') AS Lottable02
        , CASE WHEN ISNULL(SC.Svalue, '') = '1' AND SKU.Sku <> SKU.RETAILSKU AND ISNULL(SKU.RETAILSKU, '') <> '' THEN
                  ISNULL(SKU.RETAILSKU, '')
               ELSE '' END AS RetailSku
        , CONVERT(NVARCHAR(10), ISNULL(LOTATTRIBUTE.Lottable04,'19000101'), 126) AS Lottable04
   FROM ORDERS (NOLOCK)
   JOIN PICKDETAIL (NOLOCK) ON PICKDETAIL.OrderKey = ORDERS.OrderKey
   JOIN LOC (NOLOCK) ON LOC.Loc = PICKDETAIL.Loc
   JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.OrderKey = ORDERS.OrderKey
   JOIN WAVE (NOLOCK) ON WAVE.WaveKey = WAVEDETAIL.WaveKey
   JOIN SKU (NOLOCK) ON SKU.StorerKey = PICKDETAIL.Storerkey AND SKU.Sku = PICKDETAIL.Sku
   JOIN PACK (NOLOCK) ON PACK.PackKey = SKU.PACKKey
   JOIN LOTATTRIBUTE (NOLOCK) ON PICKDETAIL.Lot = LOTATTRIBUTE.Lot
   LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.LISTNAME = 'LOCCASHOW' AND C.Storerkey = ORDERS.StorerKey
   LEFT JOIN CODELKUP C1 WITH (NOLOCK) ON  C1.LISTNAME = 'REPORTCFG'
                                       AND C1.Long = 'RPT_WV_PLIST_WAVE_018_3'
                                       AND C1.Code = 'SHOWPICKLOC'
                                       AND C1.Storerkey = ORDERS.StorerKey
                                       AND C1.Short = ORDERS.Stop
   LEFT JOIN V_StorerConfig2 SC WITH (NOLOCK) ON ORDERS.StorerKey = SC.storerkey AND SC.ConfigKey = 'DELNOTE06_RSKU'
   WHERE WAVE.WaveKey = @c_WaveKey
   AND   1 = CASE WHEN ISNULL(C1.Short, '') <> ''
                  AND  ISNULL(C.Code, '') <> ''
                  AND  C.Code = LOC.LocationCategory
                  AND  LOC.LocLevel > CONVERT(INT, C.UDF02) THEN 1
                  WHEN ISNULL(C1.Short, 'N') = 'N' THEN 1
                  ELSE 0 END
   ORDER BY LOC.LogicalLocation
          , PICKDETAIL.Loc
          , PICKDETAIL.Sku
          , ISNULL(LOTATTRIBUTE.Lottable02,'')
          , CONVERT(NVARCHAR(10), ISNULL(LOTATTRIBUTE.Lottable04,'19000101'), 126)
END

GO