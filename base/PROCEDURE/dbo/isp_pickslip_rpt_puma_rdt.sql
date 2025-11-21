SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Proc: isp_pickslip_rpt_puma_rdt                               */
/* Creation Date: 30-JAN-2023                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-21611 - ID-PUMA-B2B Pick Slip (New Format)              */
/*                                                                      */
/* Called By: r_dw_pickslip_rpt_puma_rdt                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 30-Jan-2023  WLChooi  1.0  DevOps Combine Script                     */
/* 28-Jun-2023  CSCHONG  1.1  WMS-22915 support print by Wave (CS01)    */
/************************************************************************/
CREATE   PROC [dbo].[isp_pickslip_rpt_puma_rdt] @c_Orderkey NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF;


  WITH CTE AS
   (
      SELECT OH.OrderKey
           , TRIM(ISNULL(OH.ExternOrderKey, '')) AS ExternOrderKey
           , OH.UserDefine09 AS Wavekey
           , TRIM(ISNULL(L.PickZone, '')) AS PickZone
           , ISNULL(PD.PickSlipNo, '') AS PickSlipNo
      FROM ORDERS OH (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
      --JOIN #TMPWAVEORD TORD ON TORD.ORDERKEY = oh.OrderKey AND TORD.WAVEKEY = OH.UserDefine09             --
     WHERE OH.OrderKey = @c_Orderkey
      GROUP BY OH.OrderKey
             , OH.ExternOrderKey
             , OH.UserDefine09
             , ISNULL(L.PickZone, '')
             , ISNULL(PD.PickSlipNo, '')
 UNION  --CS01 S
SELECT OH.OrderKey
           , TRIM(ISNULL(OH.ExternOrderKey, '')) AS ExternOrderKey
           , OH.UserDefine09 AS Wavekey
           , TRIM(ISNULL(L.PickZone, '')) AS PickZone
           , ISNULL(PD.PickSlipNo, '') AS PickSlipNo
      FROM ORDERS OH (NOLOCK)
      JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = OH.OrderKey
      JOIN LOC L (NOLOCK) ON L.Loc = PD.Loc
      --JOIN #TMPWAVEORD TORD ON TORD.ORDERKEY = oh.OrderKey AND TORD.WAVEKEY = OH.UserDefine09             --
     WHERE OH.UserDefine09 = @c_Orderkey
      GROUP BY OH.OrderKey
             , OH.ExternOrderKey
             , OH.UserDefine09
             , ISNULL(L.PickZone, '')
             , ISNULL(PD.PickSlipNo, '')  --CS01 E
   )
   SELECT CTE.OrderKey
        , CTE.ExternOrderKey
        , CTE.Wavekey
        , CTE.PickZone
        , CTE.PickSlipNo
        , TRIM(CTE.OrderKey) + TRIM(CTE.ExternOrderKey) + TRIM(CTE.Wavekey) + 
          TRIM(CTE.PickZone) + TRIM(CTE.PickSlipNo) AS Group1
   FROM CTE
   ORDER BY CTE.Wavekey     --CS01
          , CTE.OrderKey
         -- , CTE.Wavekey   --CS01 
          , CTE.PickZone
          , CTE.PickSlipNo 



   IF OBJECT_ID('tempdb..#TMPWAVEORD') IS NOT NULL
      DROP TABLE #TMPWAVEORD

END

GO