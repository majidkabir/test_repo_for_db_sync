SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenishment_report_04                    */
/* Creation Date: 04-Oct-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: UA Replenishment Summary                                     */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_replenishment_report_04     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_replenishment_report_04] (
       @as_storerkey NVARCHAR(15)
     , @as_wavekey   NVARCHAR(10)
     , @as_loadkey   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TEMP_REPLEN') IS NOT NULL
      DROP TABLE #TEMP_REPLEN


   SELECT ReplenishmentKey = ISNULL( RTRIM( RP.ReplenishmentKey ), '' )
        , Storerkey        = ISNULL( RTRIM( RP.Storerkey ), '' )
        , Company          = ISNULL( RTRIM( ST.Company ), '' )
        , Wavekey          = ISNULL( RTRIM( RP.Wavekey ), '' )
        , Sku              = ISNULL( RTRIM( RP.Sku ), '' )
        , FromLoc          = ISNULL( RTRIM( RP.FromLoc ), '' )
        , ToLoc            = ISNULL( RTRIM( RP.ToLoc ), '' )
        , Confirmed        = ISNULL( RTRIM( RP.Confirmed ), '' )
        , LogicalLocation  = ISNULL( RTRIM( LOC.LogicalLocation ), '' )
        , Qty              = ISNULL( RP.Qty, 0 )
        , Lot              = ISNULL( RTRIM( RP.Lot ), '' )
        , Lottable11       = ISNULL( RTRIM( LA.Lottable11 ), '' )
        , Lottable03       = ISNULL( RTRIM( LA.Lottable03 ), '' )
        , Id               = ISNULL( RTRIM( RP.Id ), '' )
        , WaveDescr        = ISNULL( RTRIM( WAVE.Descr ), '' )
        , Weight           = ISNULL( IIF( ISNUMERIC(UCC.Userdefined04)=1, CONVERT(FLOAT,UCC.Userdefined04), 0), 0 )
        , CartonsCBM       = ISNULL( IIF( ISNUMERIC(UCC.Userdefined08)=1, CONVERT(FLOAT,UCC.Userdefined08), 0), 0 )
        , SeqRPK           = ROW_NUMBER() OVER(PARTITION BY RP.ReplenishmentKey ORDER BY PD.Pickdetailkey)

   INTO #TEMP_REPLEN

   FROM dbo.REPLENISHMENT RP (NOLOCK)
   JOIN dbo.WAVE        WAVE (NOLOCK) ON (RP.Wavekey = WAVE.WaveKey)
   JOIN dbo.PICKDETAIL    PD (NOLOCK) ON (RP.Lot = PD.Lot AND RP.Sku = PD.Sku AND RP.Storerkey = PD.Storerkey)
   JOIN dbo.ORDERS        OH (NOLOCK) ON (PD.OrderKey = OH.OrderKey AND RP.Wavekey = OH.Userdefine09)
   JOIN dbo.STORER        ST (NOLOCK) ON (RP.Storerkey = ST.Storerkey)
   LEFT OUTER JOIN dbo.LOC         LOC (NOLOCK) ON (RP.FromLoc = LOC.Loc)
   LEFT OUTER JOIN dbo.LOTATTRIBUTE LA (NOLOCK) ON (RP.Lot = LA.Lot)
   LEFT OUTER JOIN dbo.UCC         UCC (NOLOCK) ON (LA.Lottable11 = UCC.UCCNo AND LA.StorerKey = UCC.Storerkey AND LA.Sku = UCC.Sku)

   WHERE RP.Storerkey = @as_storerkey
     AND (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'')
     AND (ISNULL(@as_wavekey,'')='' OR RP.Wavekey = @as_wavekey)
     AND (ISNULL(@as_loadkey,'')='' OR OH.Loadkey = @as_loadkey)



   SELECT [ReplenishmentKey] = Y.ReplenishmentKey
        , [Storerkey]        = Y.Storerkey
        , [Company]          = Y.Company
        , [Wavekey]          = Y.Wavekey
        , [Sku]              = Y.Sku
        , [FromLoc]          = Y.FromLoc
        , [FromLoc_BC]       = master.dbo.fnc_IDAutomation_Uni_C128( Y.FromLoc, 0 )
        , [ToLoc]            = Y.ToLoc
        , [Confirmed]        = Y.Confirmed
        , [Location Routing] = Y.LogicalLocation
        , [Qty]              = Y.Qty
        , [Lot]              = Y.Lot
        , [UCC No]           = Y.Lottable11
        , [UCC_No_BC]        = master.dbo.fnc_IDAutomation_Uni_C128( Y.Lottable11, 0 )
        , [PO Number]        = Y.Lottable03
        , [Pallet ID]        = Y.Id
        , [Wave Descr]       = Y.WaveDescr
        , [LoadKeys]         = CAST( STUFF((SELECT DISTINCT TOP 10 ', ', RTRIM(LoadKey) FROM ORDERS (NOLOCK)
                                 WHERE Userdefine09<>'' AND Userdefine09=Y.Wavekey
                                 FOR XML PATH('')), 1, 2, '') AS NVARCHAR(120) )
        , [Weight]           = Y.Weight
        , [EEM GW]           = MAX( Y.Weight ) OVER(PARTITION BY Y.Lottable11) * Y.Qty / SUM( Y.Qty ) OVER(PARTITION BY Y.Lottable11)
        , [Cartons CBM]      = Y.CartonsCBM

   FROM (
      SELECT ReplenishmentKey = X.ReplenishmentKey
           , Storerkey        = MAX( X.Storerkey )
           , Company          = MAX( X.Company )
           , Wavekey          = MAX( X.Wavekey )
           , Sku              = MAX( X.Sku )
           , FromLoc          = MAX( X.FromLoc )
           , ToLoc            = MAX( X.ToLoc )
           , Confirmed        = MAX( X.Confirmed )
           , LogicalLocation  = MAX( X.LogicalLocation )
           , Qty              = SUM( IIF( X.SeqRPK=1, X.Qty, 0 ) )
           , Lot              = MAX( X.Lot )
           , Lottable11       = MAX( X.Lottable11 )
           , Lottable03       = MAX( X.Lottable03 )
           , Id               = MAX( X.Id )
           , WaveDescr        = MAX( X.WaveDescr )
           , Weight           = MAX( X.Weight )
           , CartonsCBM       = MAX( X.CartonsCBM )
      FROM #TEMP_REPLEN X
      GROUP BY X.ReplenishmentKey
   ) Y
   ORDER BY [Wavekey]
          , [Location Routing]
          , [FromLoc]
          , [Pallet ID]
          , [ToLoc]
          , [Sku]
          , [UCC No]
          , [Qty] DESC

END

GO