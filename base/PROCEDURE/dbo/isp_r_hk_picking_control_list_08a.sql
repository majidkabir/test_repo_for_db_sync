SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_control_list_08a                   */
/* Creation Date: 22-Sep-2020                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Picking Control List                                         */
/*                                                                       */
/* Called By: Datawidnow r_hk_picking_control_list_08a                   */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2020-10-22   ML       1.1  WMS-15310 Add Replen check, First PAZone   */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_08a] (
       @as_Storerkey NVARCHAR(15)
     , @as_Loadkey   NVARCHAR(MAX)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_DataWindow        NVARCHAR(40)

   SELECT @c_DataWindow = 'r_hk_picking_control_list_08a'

   IF OBJECT_ID('tempdb..#TEMP_PICKHEADER') IS NOT NULL
      DROP TABLE #TEMP_PICKHEADER


   -- #TEMP_PICKHEADER
   SELECT Orderkey     = OH.Orderkey
        , PickslipNo   = MAX(ISNULL(PH1.PickHeaderKey,PH2.PickHeaderKey))
        , IsConsol     = MAX(IIF(PH2.PickHeaderKey IS NOT NULL, 'Y', 'N'))
        , FOK          = MIN(OH.Orderkey) OVER(PARTITION BY MAX(ISNULL(PH1.PickHeaderKey,PH2.PickHeaderKey)))
        , Storerkey    = MAX(OH.Storerkey)

   INTO #TEMP_PICKHEADER

   FROM dbo.ORDERS OH(NOLOCK)
   LEFT JOIN dbo.PICKHEADER PH1(NOLOCK) ON OH.Orderkey = PH1.Orderkey AND ISNULL(OH.Orderkey,'')<>''
   LEFT JOIN dbo.PICKHEADER PH2(NOLOCK) ON OH.Loadkey = PH2.ExternOrderkey AND ISNULL(OH.Loadkey,'')<>'' AND ISNULL(PH2.Orderkey,'')=''

   WHERE OH.Storerkey = @as_Storerkey
     AND OH.Loadkey IN (SELECT DISTINCT LTRIM(RTRIM(value)) FROM STRING_SPLIT(REPLACE(@as_Loadkey,CHAR(13)+CHAR(10),','), ',') WHERE value<>'')
     AND OH.Loadkey <> ''
     AND OH.Status >= '1' AND OH.Status <= '9'
     AND (PH1.PickheaderKey IS NOT NULL OR PH2.PickheaderKey IS NOT NULL)

   GROUP BY OH.Orderkey





   -- Final Result
   SELECT PickslipNo        = RTRIM( PH.PickslipNo )
        , CustomerGroupCode = RTRIM( MAX( ST.CustomerGroupCode ) )
        , Orderkey          = RTRIM( MAX( IIF(PH.IsConsol='Y', '', FOH.Orderkey) ) )
        , ExternOrderkey    = RTRIM( MAX( IIF(PH.IsConsol='Y', '', FOH.ExternOrderkey) ) )
        , Loadkey           = RTRIM( MAX( FOH.Loadkey ) )
        , Wavekey           = RTRIM( MAX( FOH.Userdefine09 ) )
        , C_Company         = RTRIM( ISNULL( MAX( CASE WHEN ISNULL(FOH.C_Company,'')='' THEN FOH.C_Contact1 ELSE FOH.C_Company END ), '') )
        , C_Address1        = RTRIM( ISNULL( MAX( FOH.C_Address1 ), '') )
        , C_Address2        = RTRIM( ISNULL( MAX( FOH.C_Address2 ), '') )
        , C_Address3        = RTRIM( ISNULL( MAX( FOH.C_Address3 ), '') )
        , C_Address4        = RTRIM( ISNULL( MAX( FOH.C_Address4 ), '') )
        , C_Country         = RTRIM( ISNULL( MAX( FOH.C_Country ), '') )
        , AllocQty          = SUM( PD.Qty )
        , SkuCount          = COUNT( DISTINCT PD.Sku )
        , LocCount          = COUNT( DISTINCT IIF(PD.ToLoc<>'', PD.ToLoc, PD.Loc) )
        , datawindow        = @c_DataWindow
        , PAZoneCount       = COUNT(DISTINCT LOC.PutawayZone)
        , FirstPAZone       = RTRIM( ISNULL( MIN( LOC.PutawayZone ), '') )
        , MarketPlace       = RTRIM( ISNULL( MAX( RTRIM(ISNULL(FOH.OrderGroup,''))+'-'+ISNULL(MKT.Long,'') ), '') )
        , Courier           = RTRIM( ISNULL( MAX( FOH.Door ), '') )
        , AddDate           = MAX( FOH.AddDate )
        , Replen            = MAX( CASE WHEN LOC.LocationCategory='SELECTIVE' THEN 'Y' ELSE 'N' END )
        , MultiPAZone       = CASE WHEN COUNT(DISTINCT LOC.PutawayZone)>1 THEN 'Y' ELSE 'N' END

   FROM #TEMP_PICKHEADER   PH
   JOIN dbo.ORDERS        FOH(NOLOCK) ON PH.FOK=FOH.Orderkey
   JOIN dbo.STORER         ST(NOLOCK) ON PH.Storerkey=ST.Storerkey
   JOIN dbo.PICKDETAIL     PD(NOLOCK) ON PH.Orderkey=PD.Orderkey
   JOIN dbo.LOC           LOC(NOLOCK) ON PD.Loc=LOC.Loc
   JOIN dbo.SKU           SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku
   LEFT JOIN dbo.CODELKUP MKT(NOLOCK) ON MKT.LISTNAME='AEO_FOM_ID' AND FOH.Storerkey=MKT.Storerkey AND FOH.OrderGroup=MKT.Code

   WHERE PD.Qty > 0

   GROUP BY PH.PickslipNo

   ORDER BY Replen, MultiPAZone, FirstPAZone, Orderkey
END

GO