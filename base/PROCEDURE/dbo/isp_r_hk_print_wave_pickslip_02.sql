SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_wave_pickslip_02                     */
/* Creation Date: 13-Dec-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Picking Slip                                                 */
/*                                                                       */
/* Called By: RCM - Generate Pickslip                                    */
/*            Datawidnow r_hk_print_wave_pickslip_02                     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 23/03/2022   ML       1.2  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_print_wave_pickslip_02] (
       @as_wavekey   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      LineRemark
   [MAPVALUE]
      T_LineRemark
*/

   DECLARE @c_DataWindow     NVARCHAR(40)
         , @b_FirstPrint     INT
         , @b_Success        INT
         , @n_Err            INT
         , @c_ErrMsg         NVARCHAR(250)
         , @c_Storerkey      NVARCHAR(15)
         , @c_LineRemarkExp  NVARCHAR(4000)
         , @c_ExecStatements NVARCHAR(MAX)
         , @c_ExecArguments  NVARCHAR(MAX)

   SELECT @c_DataWindow = 'r_hk_print_wave_pickslip_02'
        , @b_FirstPrint = 1

   IF OBJECT_ID('tempdb..#TEMP_RESULT') IS NOT NULL
      DROP TABLE #TEMP_RESULT


   IF EXISTS(SELECT TOP 1 1
             FROM dbo.ORDERS     OH(NOLOCK)
             JOIN dbo.PICKDETAIL PD(NOLOCK) ON OH.Orderkey=PD.Orderkey
             WHERE OH.Status < '5' AND PD.Qty > 0 AND OH.Userdefine09 = @as_wavekey AND @as_wavekey<>''
   )
   BEGIN
      IF EXISTS(SELECT TOP 1 1
                FROM dbo.ORDERS     OH(NOLOCK)
                JOIN dbo.PICKHEADER PH(NOLOCK) ON OH.Orderkey=PH.Orderkey
                WHERE OH.Userdefine09 = @as_wavekey
         )
      BEGIN
         SET @b_FirstPrint = 0
      END

      EXEC isp_CreatePickSlip
           @c_Orderkey           = ''
         , @c_Loadkey            = ''
         , @c_Wavekey            = @as_wavekey
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
                WHERE OH.Userdefine09=@as_wavekey AND PH.Zone='8' AND PH.PickType='0'
         )
      BEGIN
         UPDATE PH WITH(ROWLOCK)
            SET PickType = '1'
              , TrafficCop = NULL
           FROM dbo.ORDERS     OH(NOLOCK)
           JOIN dbo.PICKHEADER PH ON OH.Orderkey=PH.Orderkey
          WHERE OH.Userdefine09=@as_wavekey AND PH.Zone='8' AND PH.PickType='0'
      END
   END


   CREATE TABLE #TEMP_RESULT (
        PickslipNo      NVARCHAR(18)   NULL
      , ConsolPick      VARCHAR(1)     NULL
      , DocKey          NVARCHAR(10)   NULL
      , Wavekey         NVARCHAR(10)   NULL
      , Loadkey         NVARCHAR(10)   NULL
      , PrintedFlag     NVARCHAR(10)   NULL
      , Storerkey       NVARCHAR(15)   NULL
      , ST_Company      NVARCHAR(45)   NULL
      , Facility        NVARCHAR(5)    NULL
      , Orderkey        NVARCHAR(10)   NULL
      , ExternOrderKey  NVARCHAR(50)   NULL
      , OrderType       NVARCHAR(10)   NULL
      , Route           NVARCHAR(10)   NULL
      , Route_Desc      NVARCHAR(60)   NULL
      , TrfRoom         NVARCHAR(10)   NULL
      , VehicleNo       NVARCHAR(10)   NULL
      , Delivery_zone   NVARCHAR(10)   NULL
      , ExternPOKey     NVARCHAR(20)   NULL
      , BuyerPO         NVARCHAR(20)   NULL
      , InvoiceNo       NVARCHAR(20)   NULL
      , DeliveryDate    DATETIME       NULL
      , Consigneekey    NVARCHAR(15)   NULL
      , C_Company       NVARCHAR(45)   NULL
      , C_Address1      NVARCHAR(45)   NULL
      , C_Address2      NVARCHAR(45)   NULL
      , C_Address3      NVARCHAR(45)   NULL
      , C_Address4      NVARCHAR(45)   NULL
      , BillToKey       NVARCHAR(15)   NULL
      , B_Company       NVARCHAR(45)   NULL
      , B_Address1      NVARCHAR(45)   NULL
      , B_Address2      NVARCHAR(45)   NULL
      , B_Address3      NVARCHAR(45)   NULL
      , B_Address4      NVARCHAR(45)   NULL
      , Notes           NVARCHAR(4000) NULL
      , Notes2          NVARCHAR(4000) NULL
      , Capacity        FLOAT          NULL
      , GrossWeight     FLOAT          NULL
      , Sku             NVARCHAR(20)   NULL
      , SkuDescr        NVARCHAR(60)   NULL
      , Altsku          NVARCHAR(20)   NULL
      , HazardousFlag   NVARCHAR(30)   NULL
      , PutawayZone     NVARCHAR(10)   NULL
      , PADescr         NVARCHAR(60)   NULL
      , Loc             NVARCHAR(10)   NULL
      , LogicalLocation NVARCHAR(18)   NULL
      , ID              NVARCHAR(18)   NULL
      , Qty             INT            NULL
      , CaseCnt         FLOAT          NULL
      , Lottable02      NVARCHAR(18)   NULL
      , Lottable03      NVARCHAR(18)   NULL
      , Lottable04      DATETIME       NULL
      , Report_Logo     NVARCHAR(4000) NULL
      , LineRemark      NVARCHAR(4000) NULL
   )


   -- Storerkey Loop
   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
   FROM dbo.ORDERS (NOLOCK)
   WHERE Userdefine09 = @as_wavekey
   ORDER BY 1

   OPEN C_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_LineRemarkExp = ''

      SELECT TOP 1
             @c_LineRemarkExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRemark')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_RESULT'
          +' (PickslipNo, ConsolPick, DocKey, Wavekey, Loadkey, PrintedFlag, Storerkey, ST_Company, Facility, Orderkey'
          +', ExternOrderKey, OrderType, Route, Route_Desc, TrfRoom, VehicleNo, Delivery_zone, ExternPOKey, BuyerPO, InvoiceNo'
          +', DeliveryDate, Consigneekey, C_Company, C_Address1, C_Address2, C_Address3, C_Address4, BillToKey, B_Company, B_Address1'
          +', B_Address2, B_Address3, B_Address4, Notes, Notes2, Capacity, GrossWeight, Sku, SkuDescr, Altsku'
          +', HazardousFlag, PutawayZone, PADescr, Loc, LogicalLocation, ID, Qty, CaseCnt, Lottable02, Lottable03'
          +', Lottable04, LineRemark)'
          +' SELECT RTRIM( ISNULL(PH1.PickheaderKey, PH2.PickheaderKey) )'
               + ', IIF(PH2.PickHeaderKey IS NOT NULL, ''Y'', ''N'')'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, OH.Loadkey, OH.Orderkey) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.Userdefine09 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, OH.Loadkey, '''' ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, PH2.PickType, PH1.PickType) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.Storerkey ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', ST.Company ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Facility, OH.Facility ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.Orderkey ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.ExternOrderKey ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.Type ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.Route ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', RM.Descr ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.TrfRoom, '''' ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, (SELECT TOP 1 VehicleNumber FROM dbo.IDS_LP_VEHICLE(NOLOCK) WHERE Loadkey=LP.Loadkey ORDER BY LineNumber), '''' ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Delivery_zone, '''' ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.ExternPOKey ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.BuyerPO ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.InvoiceNo ) )'
               + ', IIF(PH2.PickHeaderKey IS NOT NULL, LP.LPUSERDEFDATE01, OH.DeliveryDate)'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.ConsigneeKey ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.C_Company ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.C_Address1 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.C_Address2 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.C_Address3 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.C_Address4 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.BillToKey ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.B_Company ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.B_Address1 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.B_Address2 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.B_Address3 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, '''', OH.B_Address4 ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Load_Userdef1, OH.Notes ) )'
               + ', RTRIM( IIF(PH2.PickHeaderKey IS NOT NULL, LP.Load_Userdef2, OH.Notes2 ) )'
               + ', SUM(PD.Qty * SKU.StdCube) OVER(PARTITION BY ISNULL(PH1.PickheaderKey, PH2.PickheaderKey))'
               + ', SUM(PD.Qty * SKU.STDGROSSWGT) OVER(PARTITION BY ISNULL(PH1.PickheaderKey, PH2.PickheaderKey))'
               + ', RTRIM( PD.Sku )'
               + ', RTRIM( SKU.Descr )'
               + ', RTRIM( SKU.Altsku )'
               + ', RTRIM( SKU.HazardousFlag )'
               + ', RTRIM( LOC.PutawayZone )'
               + ', RTRIM( PA.Descr )'
               + ', RTRIM( PD.Loc )'
               + ', RTRIM( LOC.LogicalLocation )'
               + ', RTRIM( PD.ID )'
               + ', PD.Qty'
               + ', PACK.CaseCnt'
               + ', RTRIM( LA.Lottable02 )'
               + ', RTRIM( LA.Lottable03 )'
               + ', CASE WHEN ISNULL(LA.Lottable04,'''')<>'''' THEN LA.Lottable04 END'

      SET @c_ExecStatements = @c_ExecStatements
               + ', ' + CASE WHEN ISNULL(@c_LineRemarkExp  ,'')<>'' THEN @c_LineRemarkExp   ELSE '''''' END

      SET @c_ExecStatements = @c_ExecStatements
          +' FROM dbo.ORDERS              OH(NOLOCK)'
          +' JOIN dbo.STORER              ST(NOLOCK) ON OH.Storerkey=ST.Storerkey'
          +' JOIN dbo.PICKDETAIL          PD(NOLOCK) ON OH.Orderkey=PD.Orderkey'
          +' JOIN dbo.LOTATTRIBUTE        LA(NOLOCK) ON PD.Lot=LA.Lot'
          +' JOIN dbo.SKU                SKU(NOLOCK) ON PD.Storerkey=SKU.Storerkey AND PD.Sku=SKU.Sku'
          +' JOIN dbo.PACK              PACK(NOLOCK) ON SKU.Packkey=PACK.Packkey'
          +' JOIN dbo.LOC                LOC(NOLOCK) ON PD.Loc=LOC.Loc'
          +' JOIN dbo.PUTAWAYZONE         PA(NOLOCK) ON LOC.PutawayZone=PA.PutawayZone'
          +' LEFT JOIN dbo.PICKHEADER    PH1(NOLOCK) ON OH.Orderkey = PH1.Orderkey AND ISNULL(OH.Orderkey,'''')<>'''''
          +' LEFT JOIN dbo.PICKHEADER    PH2(NOLOCK) ON OH.Loadkey = PH2.ExternOrderkey AND ISNULL(OH.Loadkey,'''')<>'''' AND ISNULL(PH2.Orderkey,'''')='''''
          +' LEFT JOIN dbo.ROUTEMASTER    RM(NOLOCK) ON OH.Route=RM.Route'
          +' LEFT JOIN dbo.LOADPLAN       LP(NOLOCK) ON OH.Loadkey=LP.Loadkey AND ISNULL(OH.Loadkey,'''')<>''''  AND PH2.PickheaderKey IS NOT NULL'

      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE OH.Status >= ''1'' AND OH.Status < ''9'''
          +'   AND PD.Status < ''5'' AND PD.Qty > 0'
          +'   AND (PD.Pickmethod = ''8'' OR PD.Pickmethod = '''')'
          +'   AND (PH1.PickheaderKey IS NOT NULL OR PH2.PickheaderKey IS NOT NULL)'
          +'   AND OH.Userdefine09 = @c_Wavekey'
          +'   AND OH.Storerkey = @c_Storerkey'

      SET @c_ExecArguments = N'@c_Wavekey    NVARCHAR(10)'
                           + ',@c_Storerkey  NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @as_wavekey
                       , @c_Storerkey
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY


   SELECT PickslipNo      = X.PickslipNo
        , ConsolPick      = MAX( X.ConsolPick )
        , DocKey          = MAX( X.DocKey )
        , Wavekey         = MAX( X.Wavekey )
        , Loadkey         = MAX( X.Loadkey )
        , PrintedFlag     = MAX( X.PrintedFlag )
        , Storerkey       = X.Storerkey
        , ST_Company      = MAX( X.ST_Company )
        , Facility        = MAX( X.Facility )
        , Orderkey        = MAX( X.Orderkey )
        , ExternOrderKey  = MAX( X.ExternOrderKey )
        , OrderType       = MAX( X.OrderType )
        , Route           = MAX( X.Route )
        , Route_Desc      = MAX( X.Route_Desc )
        , TrfRoom         = MAX( X.TrfRoom )
        , VehicleNo       = MAX( X.VehicleNo )
        , Delivery_zone   = MAX( X.Delivery_zone )
        , ExternPOKey     = MAX( X.ExternPOKey )
        , BuyerPO         = MAX( X.BuyerPO )
        , InvoiceNo       = MAX( X.InvoiceNo )
        , DeliveryDate    = MAX( X.DeliveryDate )
        , Consigneekey    = MAX( X.Consigneekey )
        , C_Company       = MAX( X.C_Company )
        , C_Address1      = MAX( X.C_Address1 )
        , C_Address2      = MAX( X.C_Address2 )
        , C_Address3      = MAX( X.C_Address3 )
        , C_Address4      = MAX( X.C_Address4 )
        , BillToKey       = MAX( X.BillToKey )
        , B_Company       = MAX( X.B_Company )
        , B_Address1      = MAX( X.B_Address1 )
        , B_Address2      = MAX( X.B_Address2 )
        , B_Address3      = MAX( X.B_Address3 )
        , B_Address4      = MAX( X.B_Address4 )
        , Notes           = MAX( X.Notes )
        , Notes2          = MAX( X.Notes2 )
        , Capacity        = MAX( X.Capacity )
        , GrossWeight     = MAX( X.GrossWeight )
        , Sku             = X.Sku
        , SkuDescr        = MAX( X.SkuDescr )
        , Altsku          = MAX( X.Altsku )
        , HazardousFlag   = MAX( X.HazardousFlag )
        , PutawayZone     = X.PutawayZone
        , PADescr         = MAX( X.PADescr )
        , Loc             = X.Loc
        , LogicalLocation = MAX( X.LogicalLocation )
        , ID              = X.ID
        , Qty             = SUM( X.Qty )
        , CaseCnt         = X.CaseCnt
        , Lottable02      = X.Lottable02
        , Lottable03      = X.Lottable03
        , Lottable04      = X.Lottable04
        , datawindow      = @c_DataWindow
        , Report_Logo     = MAX( CASE WHEN RL.Notes<>'''' THEN RTRIM( RL.Notes ) END)
        , Lbl_LineRemark  = CAST( RTRIM( (select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='T_LineRemark') ) AS NVARCHAR(500))
        , LineRemark      = MAX( X.LineRemark )
        , ShowFields      = MAX( RptCfg.ShowFields )

   FROM #TEMP_RESULT X
   LEFT JOIN dbo.CODELKUP RL(NOLOCK) ON RL.Listname='RPTLOGO' AND RL.Code='LOGO' AND RL.Storerkey = X.Storerkey AND RL.Long = @c_DataWindow

   LEFT JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=X.Storerkey AND RptCfg.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=X.Storerkey AND RptCfg3.SeqNo=1

   GROUP BY X.PickslipNo
          , X.Storerkey
          , X.Sku
          , X.PutawayZone
          , X.Loc
          , X.ID
          , X.CaseCnt
          , X.Lottable02
          , X.Lottable03
          , X.Lottable04
END

GO