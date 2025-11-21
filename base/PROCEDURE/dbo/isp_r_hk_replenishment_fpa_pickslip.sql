SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_replenishment_fpa_pickslip                 */
/* Creation Date: 30-Apr-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Picking Control List                                         */
/*                                                                       */
/* Called By: RCM - Popup Discrete Pickslip FPA                          */
/*                  Popup Combine Pickslip FPA                           */
/*            Datawidnow r_hk_replenishment_fpa_pickslip                 */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2019-10-04   ML       1.1  Check Userdefine08=N when Type=LP          */
/* 2020-11-30   ML       1.2  Add ShowFields to result set               */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_replenishment_fpa_pickslip] (
       @as_Key_Type   NVARCHAR(13)
     , @as_DataWindow NVARCHAR(40) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [SHOWFIELD]
      DefaultRDTPick, AllowUserChangePickMethod
      Code39
*/

   DECLARE @c_DataWindow   NVARCHAR(40)
         , @c_Type         NVARCHAR(2)
         , @c_Key          NVARCHAR(10)
         , @b_FirstPrint   INT
         , @b_Success      INT
         , @n_Err          INT
         , @c_ErrMsg       NVARCHAR(250)
         , @c_ShowFields   NVARCHAR(MAX)

   SELECT @c_DataWindow = IIF(ISNULL(@as_DataWindow,'')<>'', @as_DataWindow, 'r_hk_replenishment_fpa_pickslip')
        , @c_Key  = LEFT(@as_Key_Type, 10)
        , @c_Type = RIGHT(@as_Key_Type, 2)
        , @b_FirstPrint = 1

   SET @as_DataWindow  = 'r_hk_replenishment_fpa_pickslip'


   IF OBJECT_ID('tempdb..#TEMP_RESULT') IS NOT NULL
      DROP TABLE #TEMP_RESULT


   IF @c_Type = 'WP'
   BEGIN
      IF EXISTS(SELECT TOP 1 1
                FROM dbo.WAVE     WAVE(NOLOCK)
                JOIN dbo.ORDERS     OH(NOLOCK) ON WAVE.Wavekey=OH.Userdefine09
                JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey
                JOIN dbo.SKU       SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku
                LEFT JOIN dbo.CODELKUP BRD(NOLOCK) ON BRD.LISTNAME='LORBRAND' AND BRD.Storerkey=SKU.Storerkey AND BRD.Description=SKU.Class
                LEFT JOIN (
                 SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
                      , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
                   FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
                ) RptCfg
                ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1
                WHERE OH.Status < '5' AND PD.Qty > 0 AND WAVE.Wavekey = @c_Key
                HAVING ((ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(WAVE.Userdefine03),'')='PICKSLIP')
                     OR (NOT ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,DefaultRDTPick,%'
                         AND NOT (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(WAVE.Userdefine03),'')='RDT')))
                   AND MAX(IIF(BRD.UDF01='RDT',1,0)) = 0
      )
      BEGIN
         IF EXISTS(SELECT TOP 1 1
                   FROM dbo.ORDERS     OH(NOLOCK)
                   JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Orderkey=PH.Orderkey
                   WHERE OH.Userdefine09=@c_Key
            )
         BEGIN
            SET @b_FirstPrint = 0
         END

         EXEC isp_CreatePickSlip
              @c_Orderkey           = ''
            , @c_Loadkey            = ''
            , @c_Wavekey            = @c_Key
            , @c_PickslipType       = '8'
            , @c_ConsolidateByLoad  = 'N'
            , @c_Refkeylookup       = 'N'
            , @c_LinkPickSlipToPick = 'N'
            , @c_AutoScanIn         = 'N'
            , @b_Success            = @b_Success OUTPUT
            , @n_Err                = @n_Err     OUTPUT
            , @c_ErrMsg             = @c_ErrMsg  OUTPUT

         IF @b_FirstPrint = 0 AND
            EXISTS(SELECT TOP 1 1
                   FROM dbo.ORDERS     OH(NOLOCK)
                   JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Orderkey=PH.Orderkey
                   WHERE OH.Userdefine09=@c_Key AND PH.Zone='8' AND PH.PickType='0'
            )
         BEGIN
            UPDATE PH WITH(ROWLOCK)
               SET PickType = '1'
                 , TrafficCop = NULL
              FROM dbo.ORDERS     OH(NOLOCK)
              JOIN dbo.PICKHEADER PH ON OH.Orderkey=PH.Orderkey
             WHERE OH.Userdefine09=@c_Key AND PH.Zone='8' AND PH.PickType='0'
         END
      END
   END
   ELSE IF @c_Type = 'LP'
   BEGIN
      IF EXISTS(SELECT TOP 1 1
                FROM dbo.LOADPLAN   LP(NOLOCK)
                JOIN dbo.ORDERS     OH(NOLOCK) ON LP.Loadkey=OH.Loadkey
                JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey
                JOIN dbo.SKU       SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku
                LEFT JOIN dbo.CODELKUP BRD(NOLOCK) ON BRD.LISTNAME='LORBRAND' AND BRD.Storerkey=SKU.Storerkey AND BRD.Description=SKU.Class
                LEFT JOIN (
                 SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
                      , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
                   FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
                ) RptCfg
                ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1
                WHERE OH.Status < '5' AND PD.Qty>0 AND LP.Loadkey = @c_Key
                HAVING ((ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(LP.Userdefine03),'')='PICKSLIP')
                     OR (NOT ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,DefaultRDTPick,%'
                         AND NOT (ISNULL(MAX(RptCfg.ShowFields),'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(MAX(LP.Userdefine03),'')='RDT')))
                   AND MAX(IIF(BRD.UDF01='RDT',1,0)) = 0
      )
      BEGIN
         IF EXISTS(SELECT TOP 1 1
                   FROM dbo.ORDERS     OH(NOLOCK)
                   JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Loadkey=PH.ExternOrderkey AND PH.Orderkey='' AND OH.Loadkey<>''
                   WHERE OH.Loadkey=@c_Key
            )
         BEGIN
            SET @b_FirstPrint = 0
         END

         IF NOT EXISTS(SELECT TOP 1 1 FROM dbo.ORDERS(NOLOCK) WHERE Loadkey=@c_Key AND ISNULL(Userdefine08,'')<>'N')
         BEGIN
            EXEC isp_CreatePickSlip
                 @c_Orderkey           = ''
               , @c_Loadkey            = @c_Key
               , @c_Wavekey            = ''
               , @c_PickslipType       = '9'
               , @c_ConsolidateByLoad  = 'Y'
               , @c_Refkeylookup       = 'N'
               , @c_LinkPickSlipToPick = 'N'
               , @c_AutoScanIn         = 'N'
               , @b_Success            = @b_Success OUTPUT
               , @n_Err                = @n_Err     OUTPUT
               , @c_ErrMsg             = @c_ErrMsg  OUTPUT
         END

         IF @b_FirstPrint = 0 AND
            EXISTS(SELECT TOP 1 1
                   FROM dbo.ORDERS     OH(NOLOCK)
                   JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Loadkey=PH.ExternOrderkey AND PH.Orderkey='' AND OH.Loadkey<>''
                   WHERE OH.Loadkey=@c_Key AND PH.Zone='9' AND PH.PickType='0'
            )
         BEGIN
            UPDATE PH WITH(ROWLOCK)
               SET PickType = '1'
                 , TrafficCop = NULL
              FROM dbo.ORDERS     OH(NOLOCK)
              JOIN dbo.PICKHEADER PH ON OH.Loadkey=PH.ExternOrderkey AND PH.Orderkey='' AND OH.Loadkey<>''
             WHERE OH.Loadkey=@c_Key AND PH.Zone='9' AND PH.PickType='0'
         END
      END
   END



   SELECT PickslipNo        = RTRIM( ISNULL(PH1.PickheaderKey, PH2.PickheaderKey) )
        , ConsolPick        = IIF(PH2.PickHeaderKey IS NOT NULL, 'Y', 'N')
        , DocKey            = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, OH.Loadkey, OH.Orderkey) )
        , Wavekey           = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.Userdefine09 ) )
        , Loadkey           = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, OH.Loadkey, '' ) )
        , PrintedFlag       = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, PH2.PickType, PH1.PickType) )
        , Storerkey         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.Storerkey ) )
        , ST_Company        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', ST.Company ) )
        , Facility          = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Facility, OH.Facility ) )
        , Orderkey          = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.Orderkey ) )
        , ExternOrderKey    = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.ExternOrderKey ) )
        , OrderType         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.Type ) )
        , Route             = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.Route ) )
        , Route_Desc        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', RM.Descr ) )
        , TrfRoom           = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.TrfRoom, '' ) )
        , VehicleNo         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, (SELECT TOP 1 VehicleNumber FROM dbo.IDS_LP_VEHICLE(NOLOCK) WHERE Loadkey=LP.Loadkey ORDER BY LineNumber), '' ) )
        , Delivery_zone     = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Delivery_zone, '' ) )
        , ExternPOKey       = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.ExternPOKey ) )
        , BuyerPO           = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.BuyerPO ) )
        , InvoiceNo         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.InvoiceNo ) )
        , DeliveryDate      = IIF(PH2.PickHeaderKey IS NOT NULL, LP.LPUSERDEFDATE01, OH.DeliveryDate)
        , Consigneekey      = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.ConsigneeKey ) )
        , C_Company         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.C_Company ) )
        , C_Address1        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.C_Address1 ) )
        , C_Address2        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.C_Address2 ) )
        , C_Address3        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.C_Address3 ) )
        , C_Address4        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.C_Address4 ) )
        , BillToKey         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.BillToKey ) )
        , B_Company         = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.B_Company ) )
        , B_Address1        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.B_Address1 ) )
        , B_Address2        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.B_Address2 ) )
        , B_Address3        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.B_Address3 ) )
        , B_Address4        = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '', OH.B_Address4 ) )
        , Notes             = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Load_Userdef1, OH.Notes ) )
        , Notes2            = RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Load_Userdef2, OH.Notes2 ) )
        , Capacity          = SUM(PD.Qty * SKU.StdCube) OVER(PARTITION BY ISNULL(PH1.PickheaderKey, PH2.PickheaderKey))
        , GrossWeight       = SUM(PD.Qty * SKU.STDGROSSWGT) OVER(PARTITION BY ISNULL(PH1.PickheaderKey, PH2.PickheaderKey))
        , NoOfTotes         = CASE WHEN ISNULL(TRY_PARSE(ISNULL(CBM.Long,'') AS FLOAT),0.0)=0.0
                                     OR ISNULL(TRY_PARSE(ISNULL(RTO.Long,'') AS FLOAT),0.0)=0.0
                                   THEN 0.0
                                   ELSE CEILING(ISNULL(SUM(PD.Qty * SKU.StdCube) OVER(PARTITION BY ISNULL(PH1.PickheaderKey, PH2.PickheaderKey)),0.0) /
                                        ISNULL(TRY_PARSE(ISNULL(CBM.Long,'') AS FLOAT),0.0) * ISNULL(TRY_PARSE(ISNULL(RTO.Long,'') AS FLOAT),0.0))
                                   END
        , Sku               = RTRIM( PD.Sku )
        , SkuDescr          = RTRIM( SKU.Descr )
        , Altsku            = RTRIM( SKU.Altsku )
        , Busr10            = RTRIM( SKU.Busr10 )
        , HazardousFlag     = RTRIM( SKU.HazardousFlag )
        , PutawayZone       = RTRIM( IIF(ISNULL(PD.ToLoc,'')<>'', TOLOC.PutawayZone, LOC.PutawayZone) )
        , PADescr           = RTRIM( IIF(ISNULL(PD.ToLoc,'')<>'', TOPA.Descr, PA.Descr) )
        , Loc               = RTRIM( IIF(ISNULL(PD.ToLoc,'')<>'', PD.ToLoc, PD.Loc) )
        , LogicalLocation   = RTRIM( IIF(ISNULL(PD.ToLoc,'')<>'', TOLOC.LogicalLocation, LOC.LogicalLocation) )
        , ID                = RTRIM( PD.ID )
        , DropID            = RTRIM( PD.DropID )
        , Qty               = PD.Qty
        , CaseCnt           = PACK.CaseCnt
        , Lottable02        = RTRIM( LA.Lottable02 )
        , Lottable03        = RTRIM( LA.Lottable03 )
        , Lottable04        = CASE WHEN ISNULL(LA.Lottable04,'')<>'' THEN LA.Lottable04 END
        , ExtendedField02   = RTRIM( SI.ExtendedField02 )
        , datawindow        = @as_DataWindow
        , Report_Logo       = CASE WHEN RL.Notes<>'' THEN RTRIM( RL.Notes ) END
        , ShowFields        = RTRIM( ISNULL(RptCfg.ShowFields, '') )
        , UseRDT            = CASE WHEN (ISNULL(RptCfg.ShowFields,'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(IIF(PH2.PickHeaderKey IS NOT NULL, LP.Userdefine03, WAVE.Userdefine03),'')='RDT')
                                     OR (ISNULL(RptCfg.ShowFields,'') LIKE '%,DefaultRDTPick,%'
                                         AND NOT (ISNULL(RptCfg.ShowFields,'') LIKE '%,AllowUserChangePickMethod,%' AND ISNULL(IIF(PH2.PickHeaderKey IS NOT NULL, LP.Userdefine03, WAVE.Userdefine03),'')='PICKSLIP'))
                                     OR ISNULL(BRD.UDF01,'')='RDT' THEN 1 ELSE 0 END

   INTO #TEMP_RESULT

   FROM dbo.ORDERS              OH(NOLOCK)
   JOIN dbo.STORER              ST(NOLOCK) ON OH.Storerkey=ST.Storerkey
   JOIN dbo.PICKDETAIL          PD(NOLOCK) ON OH.Orderkey=PD.Orderkey
   JOIN dbo.LOTATTRIBUTE        LA(NOLOCK) ON PD.Lot=LA.Lot
   JOIN dbo.SKU                SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku
   JOIN dbo.PACK              PACK(NOLOCK) ON SKU.Packkey=PACK.Packkey
   JOIN dbo.LOC                LOC(NOLOCK) ON PD.Loc=LOC.Loc
   JOIN dbo.PUTAWAYZONE         PA(NOLOCK) ON LOC.PutawayZone=PA.PutawayZone
   LEFT JOIN dbo.PICKHEADER    PH1(NOLOCK) ON OH.Orderkey = PH1.Orderkey AND ISNULL(OH.Orderkey,'')<>''
   LEFT JOIN dbo.PICKHEADER    PH2(NOLOCK) ON OH.Loadkey = PH2.ExternOrderkey AND ISNULL(OH.Loadkey,'')<>'' AND ISNULL(PH2.Orderkey,'')=''
   LEFT JOIN dbo.ROUTEMASTER    RM(NOLOCK) ON OH.Route=RM.Route
   LEFT JOIN dbo.LOC         TOLOC(NOLOCK) ON PD.ToLoc=TOLOC.Loc AND ISNULL(PD.ToLoc,'')<>''
   LEFT JOIN dbo.PUTAWAYZONE  TOPA(NOLOCK) ON TOLOC.PutawayZone=TOPA.PutawayZone
   LEFT JOIN dbo.SKUINFO        SI(NOLOCK) ON PD.Storerkey=SI.Storerkey AND PD.Sku=SI.Sku
   LEFT JOIN dbo.WAVE         WAVE(NOLOCK) ON OH.Userdefine09=WAVE.Wavekey AND ISNULL(OH.Userdefine09,'')<>'' AND PH1.PickheaderKey IS NOT NULL
   LEFT JOIN dbo.LOADPLAN       LP(NOLOCK) ON OH.Loadkey=LP.Loadkey AND ISNULL(OH.Loadkey,'')<>''  AND PH2.PickheaderKey IS NOT NULL
   LEFT JOIN dbo.CODELKUP      CBM(NOLOCK) ON CBM.LISTNAME='ToteCBM' AND CBM.Storerkey=OH.Storerkey
   LEFT JOIN dbo.CODELKUP      RTO(NOLOCK) ON RTO.LISTNAME='Ratio' AND RTO.Storerkey=OH.Storerkey
   LEFT JOIN dbo.CODELKUP       RL(NOLOCK) ON RL.Listname='RPTLOGO' AND RL.Code='LOGO' AND RL.Storerkey = OH.Storerkey AND RL.Long = @as_DataWindow
   LEFT JOIN dbo.CODELKUP      BRD(NOLOCK) ON BRD.LISTNAME='LORBRAND' AND BRD.Storerkey=SKU.Storerkey AND BRD.Description=SKU.Class
   LEFT JOIN (
    SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
         , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
      FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1

   WHERE OH.Status >= '1' AND OH.Status < '9'
     AND PD.Status < '5' AND PD.Qty > 0
     AND (PD.Pickmethod = '8' OR PD.Pickmethod = '')
     AND (PH1.PickheaderKey IS NOT NULL OR PH2.PickheaderKey IS NOT NULL)
     AND ( @c_Type = 'WP' OR @c_Type = 'LP' )
     AND ((@c_Type = 'WP' AND OH.Userdefine09 = @c_Key)
       OR (@c_Type = 'LP' AND OH.Loadkey      = @c_Key)
         )



   SELECT PickslipNo      = PickslipNo
        , ConsolPick      = MAX( ConsolPick )
        , DocKey          = MAX( DocKey )
        , Wavekey         = MAX( Wavekey )
        , Loadkey         = MAX( Loadkey )
        , PrintedFlag     = MAX( PrintedFlag )
        , Storerkey       = MAX( Storerkey )
        , ST_Company      = MAX( ST_Company )
        , Facility        = MAX( Facility )
        , Orderkey        = MAX( Orderkey )
        , ExternOrderKey  = MAX( ExternOrderKey )
        , OrderType       = MAX( OrderType )
        , Route           = MAX( Route )
        , Route_Desc      = MAX( Route_Desc )
        , TrfRoom         = MAX( TrfRoom )
        , VehicleNo       = MAX( VehicleNo )
        , Delivery_zone   = MAX( Delivery_zone )
        , ExternPOKey     = MAX( ExternPOKey )
        , BuyerPO         = MAX( BuyerPO )
        , InvoiceNo       = MAX( InvoiceNo )
        , DeliveryDate    = MAX( DeliveryDate )
        , Consigneekey    = MAX( Consigneekey )
        , C_Company       = MAX( C_Company )
        , C_Address1      = MAX( C_Address1 )
        , C_Address2      = MAX( C_Address2 )
        , C_Address3      = MAX( C_Address3 )
        , C_Address4      = MAX( C_Address4 )
        , BillToKey       = MAX( BillToKey )
        , B_Company       = MAX( B_Company )
        , B_Address1      = MAX( B_Address1 )
        , B_Address2      = MAX( B_Address2 )
        , B_Address3      = MAX( B_Address3 )
        , B_Address4      = MAX( B_Address4 )
        , Notes           = MAX( Notes )
        , Notes2          = MAX( Notes2 )
        , Capacity        = MAX( Capacity )
        , GrossWeight     = MAX( GrossWeight )
        , NoOfTotes       = MAX( NoOfTotes )
        , Sku             = Sku
        , SkuDescr        = MAX( SkuDescr )
        , Altsku          = MAX( Altsku )
        , Busr10          = MAX( Busr10 )
        , HazardousFlag   = MAX( HazardousFlag )
        , PutawayZone     = PutawayZone
        , PADescr         = MAX( PADescr )
        , Loc             = Loc
        , LogicalLocation = MAX( LogicalLocation )
        , ID              = ID
        , DropID          = DropID
        , Qty             = SUM( Qty )
        , CaseCnt         = CaseCnt
        , Lottable02      = Lottable02
        , Lottable03      = Lottable03
        , Lottable04      = Lottable04
        , ExtendedField02 = MAX( ExtendedField02 )
        , datawindow      = MAX( datawindow )
        , Report_Logo     = MAX( Report_Logo )
        , ShowFields      = MAX( ShowFields )

   FROM #TEMP_RESULT X

   WHERE PickslipNo NOT IN (SELECT DISTINCT PickslipNo FROM #TEMP_RESULT WHERE UseRDT=1)

   GROUP BY PickslipNo
          , Sku
          , PutawayZone
          , Loc
          , ID
          , DropID
          , CaseCnt
          , Lottable02
          , Lottable03
          , Lottable04
END

GO