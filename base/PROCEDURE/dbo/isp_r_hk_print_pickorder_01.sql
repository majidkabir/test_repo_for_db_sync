SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_pickorder_01                         */
/* Creation Date: 08-Jun-2021                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: non-TM Pickslip by Loadplan                                  */
/*                                                                       */
/* Called By: RCM - Print non-TM Pick Slips in LoadPlan                  */
/*            Datawidnow r_hk_print_pickorder_01                         */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2021-08-26   Michael  v1.1 Add Showfield Update_PD_PickslipNo         */
/* 2021-11-30   Michael  V1.2 Fix RptCfg.ShowFields NULL value issue     */
/* 2022-03-23   Michael  V1.3 Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_print_pickorder_01] (
       @c_Loadkey  NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      DocNumber, CarrierKey, ConsigneeKey, Company, Address1, Address2, Address3, Address4, Zip, LabelPrice
      Route, TrfRoom, Notes1, Notes2, VehicleNo, RefNo, Sku, SkuDesc, PutawayZone, ZoneDesc, LogicalLoc
      Loc, Lottable02, Lottable04, Qty, CaseCnt, InnerPack
      LineRemark1, LineRemark2, LineRemark3
      T_Route, T_DocNumber, T_Consigneekey, T_Company, T_Address1, T_Address2, T_Address3, T_Address4, T_Zip
      T_Notes1, T_Notes2, T_TrfRoom, T_Carrierkey, T_VehicleNo, T_RefNo
      T_Loc, T_Sku, T_Lottable02, T_Lottable04, T_CaseCnt, T_InnerPack, T_Cartons, T_Inner, T_Each

   [MAPVALUE]

   [SHOWFIELD]
      LineRemark1, LineRemark2, LineRemark3
      Update_PD_PickslipNo
*/
   DECLARE @c_DataWindow        NVARCHAR(40)  = 'r_hk_print_pickorder_01'
         , @n_continue          INT           = 1
         , @n_StartTCnt         INT           = @@TRANCOUNT
         , @c_PickHeaderkey     NVARCHAR(10)
         , @c_TmpLoadkey        NVARCHAR(10)
         , @c_TmpOrderkey       NVARCHAR(10)
         , @c_Update_PD_PSNo    NVARCHAR(10)
         , @c_errmsg            NVARCHAR(255)
         , @b_success           INT
         , @n_err               INT
         , @c_Storerkey         NVARCHAR(15)
         , @c_Storer_Logo       NVARCHAR(60)
         , @c_PrintedFlag       NVARCHAR(1)   = 'N'
         , @c_ExecStatements    NVARCHAR(MAX)
         , @c_ExecArguments     NVARCHAR(MAX)
         , @c_ShowFields        NVARCHAR(MAX)
         , @c_DocNumberExp      NVARCHAR(MAX)
         , @c_CarrierKeyExp     NVARCHAR(MAX)
         , @c_ConsigneeKeyExp   NVARCHAR(MAX)
         , @c_CompanyExp        NVARCHAR(MAX)
         , @c_Address1Exp       NVARCHAR(MAX)
         , @c_Address2Exp       NVARCHAR(MAX)
         , @c_Address3Exp       NVARCHAR(MAX)
         , @c_Address4Exp       NVARCHAR(MAX)
         , @c_ZipExp            NVARCHAR(MAX)
         , @c_LabelPriceExp     NVARCHAR(MAX)
         , @c_RouteExp          NVARCHAR(MAX)
         , @c_TrfRoomExp        NVARCHAR(MAX)
         , @c_Notes1Exp         NVARCHAR(MAX)
         , @c_Notes2Exp         NVARCHAR(MAX)
         , @c_VehicleNoExp      NVARCHAR(MAX)
         , @c_RefNoExp          NVARCHAR(MAX)
         , @c_SkuExp            NVARCHAR(MAX)
         , @c_SkuDescExp        NVARCHAR(MAX)
         , @c_PutawayZoneExp    NVARCHAR(MAX)
         , @c_ZoneDescExp       NVARCHAR(MAX)
         , @c_LogicalLocExp     NVARCHAR(MAX)
         , @c_LocExp            NVARCHAR(MAX)
         , @c_Lottable02Exp     NVARCHAR(MAX)
         , @c_Lottable04Exp     NVARCHAR(MAX)
         , @c_QtyExp            NVARCHAR(MAX)
         , @c_CaseCntExp        NVARCHAR(MAX)
         , @c_InnerPackExp      NVARCHAR(MAX)
         , @c_LineRemark1Exp    NVARCHAR(MAX)
         , @c_LineRemark2Exp    NVARCHAR(MAX)
         , @c_LineRemark3Exp    NVARCHAR(MAX)
         , @c_Lbl_RouteExp      NVARCHAR(MAX)
         , @c_Lbl_DocNumberExp  NVARCHAR(MAX)
         , @c_Lbl_ConsigneeExp  NVARCHAR(MAX)
         , @c_Lbl_CompanyExp    NVARCHAR(MAX)
         , @c_Lbl_Address1Exp   NVARCHAR(MAX)
         , @c_Lbl_Address2Exp   NVARCHAR(MAX)
         , @c_Lbl_Address3Exp   NVARCHAR(MAX)
         , @c_Lbl_Address4Exp   NVARCHAR(MAX)
         , @c_Lbl_ZipExp        NVARCHAR(MAX)
         , @c_Lbl_Notes1Exp     NVARCHAR(MAX)
         , @c_Lbl_Notes2Exp     NVARCHAR(MAX)
         , @c_Lbl_TrfRoomExp    NVARCHAR(MAX)
         , @c_Lbl_CarrierkeyExp NVARCHAR(MAX)
         , @c_Lbl_VehicleNoExp  NVARCHAR(MAX)
         , @c_Lbl_RefNoExp      NVARCHAR(MAX)
         , @c_Lbl_LocExp        NVARCHAR(MAX)
         , @c_Lbl_SkuExp        NVARCHAR(MAX)
         , @c_Lbl_Lottable02Exp NVARCHAR(MAX)
         , @c_Lbl_Lottable04Exp NVARCHAR(MAX)
         , @c_Lbl_CaseCntExp    NVARCHAR(MAX)
         , @c_Lbl_InnerPackExp  NVARCHAR(MAX)
         , @c_Lbl_CartonsExp    NVARCHAR(MAX)
         , @c_Lbl_InnerExp      NVARCHAR(MAX)
         , @c_Lbl_EachExp       NVARCHAR(MAX)


   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   -- Uses PickType as a Printed Flag
   IF EXISTS(SELECT TOP 1 1 FROM PICKHEADER (NOLOCK) WHERE ExternOrderKey = @c_loadkey AND Zone = '8')
   BEGIN
      SET @c_PrintedFlag = 'Y'

      BEGIN TRAN

      UPDATE dbo.PICKHEADER WITH(ROWLOCK)
         SET PickType = '1'
           , EditDate = GETDATE()
           , EditWho  = SUSER_SNAME()
           , TrafficCop = NULL
       WHERE ExternOrderkey = @c_Loadkey
         AND Zone = '8'
         AND PickType = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         IF @@TRANCOUNT >= 1
            ROLLBACK TRAN
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
            COMMIT TRAN
         ELSE
         BEGIN
            SELECT @n_continue = 3
            ROLLBACK TRAN
         END
      END
   END

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN


   -- Generate PickHeader
   DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT OH.Loadkey, OH.Orderkey, MAX(CASE WHEN ISNULL(RptCfg.ShowFields,'') LIKE '%,Update_PD_PickslipNo,%' THEN 'Y' ELSE 'N' END)
      FROM dbo.LOADPLANDETAIL  LPD(NOLOCK)
      JOIN dbo.ORDERS          OH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
      JOIN dbo.PICKDETAIL      PD (NOLOCK) ON LPD.Orderkey = PD.Orderkey
      LEFT JOIN dbo.PICKHEADER PH (NOLOCK) ON LPD.Loadkey = PH.ExternOrderkey AND PH.Zone='8'
      LEFT JOIN (
         SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg
      ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1
     WHERE LPD.Loadkey = @c_Loadkey
       AND PD.Status < '5'
       AND PH.PickHeaderKey IS NULL
    GROUP BY OH.Loadkey, OH.Orderkey
    ORDER BY 1, 2

   OPEN PICK_CUR

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM PICK_CUR INTO @c_TmpLoadkey, @c_TmpOrderkey, @c_Update_PD_PSNo

      IF @@FETCH_STATUS<>0
         BREAK

      EXECUTE nspg_GetKey
              'PICKSLIP'
            , 9
            , @c_Pickheaderkey OUTPUT
            , @b_success       OUTPUT
            , @n_err           OUTPUT
            , @c_errmsg        OUTPUT

      SELECT @c_Pickheaderkey = 'P' + @c_Pickheaderkey

      BEGIN TRAN

      INSERT INTO dbo.PICKHEADER WITH(ROWLOCK)
             (PickHeaderkey   , Orderkey      , ExternOrderkey, PickType, Zone, TrafficCop)
      VALUES (@c_PickHeaderkey, @c_TmpOrderkey, @c_TmpLoadkey , '0'     , '8' , ''        )

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         ROLLBACK TRAN
         GOTO QUIT
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > 0
            COMMIT TRAN
      END
      
      IF ISNULL(@c_Update_PD_PSNo,'')='Y'
      BEGIN
         UPDATE dbo.PICKDETAIL WITH(ROWLOCK)
            SET PickslipNo = @c_Pickheaderkey
              , TrafficCop = NULL
          WHERE Orderkey = @c_TmpOrderkey
            AND Status < '9'
            AND ShipFlag <> 'Y'
            AND ISNULL(PickslipNo,'') <> @c_Pickheaderkey
      END
   END

   CLOSE PICK_CUR
   DEALLOCATE PICK_CUR

   CREATE TABLE #TEMP_PIKDT (
        Loadkey           NVARCHAR(10)   NULL
      , Storerkey         NVARCHAR(15)   NULL
      , PickSlipNo        NVARCHAR(10)   NULL
      , OrderKey          NVARCHAR(10)   NULL
      , DocNumber         NVARCHAR(500)  NULL
      , CarrierKey        NVARCHAR(500)  NULL
      , ConsigneeKey      NVARCHAR(500)  NULL
      , Company           NVARCHAR(500)  NULL
      , Address1          NVARCHAR(500)  NULL
      , Address2          NVARCHAR(500)  NULL
      , Address3          NVARCHAR(500)  NULL
      , Address4          NVARCHAR(500)  NULL
      , Zip               NVARCHAR(500)  NULL
      , LabelPrice        NVARCHAR(500)  NULL
      , Route             NVARCHAR(500)  NULL
      , TrfRoom           NVARCHAR(500)  NULL
      , Notes1            NVARCHAR(500)  NULL
      , Notes2            NVARCHAR(500)  NULL
      , PrintedFlag       NVARCHAR(1)    NULL
      , VehicleNo         NVARCHAR(500)  NULL
      , RefNo             NVARCHAR(500)  NULL
      , Sku               NVARCHAR(500)  NULL
      , SkuDesc           NVARCHAR(500)  NULL
      , Putawayzone       NVARCHAR(500)  NULL
      , ZoneDesc          NVARCHAR(500)  NULL
      , LogicalLocation   NVARCHAR(500)  NULL
      , Loc               NVARCHAR(500)  NULL
      , Lottable02        NVARCHAR(500)  NULL
      , Lottable04        NVARCHAR(500)  NULL
      , Qty               INT            NULL
      , CaseCnt           INT            NULL
      , InnerPack         INT            NULL
      , LineRemark1       NVARCHAR(500)  NULL
      , LineRemark2       NVARCHAR(500)  NULL
      , LineRemark3       NVARCHAR(500)  NULL
      , ShowFields        NVARCHAR(4000) NULL
      , Storer_Logo       NVARCHAR(500)  NULL
      , Lbl_Route         NVARCHAR(500)  NULL
      , Lbl_DocNumber     NVARCHAR(500)  NULL
      , Lbl_Consignee     NVARCHAR(500)  NULL
      , Lbl_Company       NVARCHAR(500)  NULL
      , Lbl_Address1      NVARCHAR(500)  NULL
      , Lbl_Address2      NVARCHAR(500)  NULL
      , Lbl_Address3      NVARCHAR(500)  NULL
      , Lbl_Address4      NVARCHAR(500)  NULL
      , Lbl_Zip           NVARCHAR(500)  NULL
      , Lbl_Notes1        NVARCHAR(500)  NULL
      , Lbl_Notes2        NVARCHAR(500)  NULL
      , Lbl_TrfRoom       NVARCHAR(500)  NULL
      , Lbl_Carrierkey    NVARCHAR(500)  NULL
      , Lbl_VehicleNo     NVARCHAR(500)  NULL
      , Lbl_RefNo         NVARCHAR(500)  NULL
      , Lbl_Loc           NVARCHAR(500)  NULL
      , Lbl_Sku           NVARCHAR(500)  NULL
      , Lbl_Lottable02    NVARCHAR(500)  NULL
      , Lbl_Lottable04    NVARCHAR(500)  NULL
      , Lbl_CaseCnt       NVARCHAR(500)  NULL
      , Lbl_InnerPack     NVARCHAR(500)  NULL
      , Lbl_Cartons       NVARCHAR(500)  NULL
      , Lbl_Inner         NVARCHAR(500)  NULL
      , Lbl_Each          NVARCHAR(500)  NULL
   )

   -- Storerkey Loop
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.Storerkey
     FROM dbo.LOADPLANDETAIL LPD WITH (NOLOCK)
     JOIN dbo.ORDERS         OH  WITH (NOLOCK) ON LPD.Orderkey = OH.Orderkey
     JOIN dbo.PICKHEADER     PH  WITH (NOLOCK) ON LPD.Orderkey = PH.Orderkey AND LPD.Loadkey = PH.ExternOrderkey AND PH.Zone='8'
     JOIN dbo.PICKDETAIL     PD  WITH (NOLOCK) ON LPD.OrderKey = PD.OrderKey
    WHERE LPD.Loadkey = @c_Loadkey
      AND OH.Status >= '1' AND OH.Status <= '9'
    ORDER BY 1

   OPEN C_CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_ShowFields        = ''
           , @c_Storer_Logo       = ''
           , @c_DocNumberExp      = ''
           , @c_CarrierKeyExp     = ''
           , @c_ConsigneeKeyExp   = ''
           , @c_CompanyExp        = ''
           , @c_Address1Exp       = ''
           , @c_Address2Exp       = ''
           , @c_Address3Exp       = ''
           , @c_Address4Exp       = ''
           , @c_ZipExp            = ''
           , @c_LabelPriceExp     = ''
           , @c_RouteExp          = ''
           , @c_TrfRoomExp        = ''
           , @c_Notes1Exp         = ''
           , @c_Notes2Exp         = ''
           , @c_VehicleNoExp      = ''
           , @c_RefNoExp          = ''
           , @c_SkuExp            = ''
           , @c_SkuDescExp        = ''
           , @c_PutawayZoneExp    = ''
           , @c_ZoneDescExp       = ''
           , @c_LogicalLocExp     = ''
           , @c_LocExp            = ''
           , @c_Lottable02Exp     = ''
           , @c_Lottable04Exp     = ''
           , @c_QtyExp            = ''
           , @c_CaseCntExp        = ''
           , @c_InnerPackExp      = ''
           , @c_LineRemark1Exp    = ''
           , @c_LineRemark2Exp    = ''
           , @c_LineRemark3Exp    = ''
           , @c_Lbl_RouteExp      = ''
           , @c_Lbl_DocNumberExp  = ''
           , @c_Lbl_ConsigneeExp  = ''
           , @c_Lbl_CompanyExp    = ''
           , @c_Lbl_Address1Exp   = ''
           , @c_Lbl_Address2Exp   = ''
           , @c_Lbl_Address3Exp   = ''
           , @c_Lbl_Address4Exp   = ''
           , @c_Lbl_ZipExp        = ''
           , @c_Lbl_Notes1Exp     = ''
           , @c_Lbl_Notes2Exp     = ''
           , @c_Lbl_TrfRoomExp    = ''
           , @c_Lbl_CarrierkeyExp = ''
           , @c_Lbl_VehicleNoExp  = ''
           , @c_Lbl_RefNoExp      = ''
           , @c_Lbl_LocExp        = ''
           , @c_Lbl_SkuExp        = ''
           , @c_Lbl_Lottable02Exp = ''
           , @c_Lbl_Lottable04Exp = ''
           , @c_Lbl_CaseCntExp    = ''
           , @c_Lbl_InnerPackExp  = ''
           , @c_Lbl_CartonsExp    = ''
           , @c_Lbl_InnerExp      = ''
           , @c_Lbl_EachExp       = ''

      SELECT TOP 1
             @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
      FROM dbo.CODELKUP (NOLOCK)
      WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_Storer_Logo = RTRIM( ISNULL( RL.Notes, '') )
        FROM dbo.CODELKUP RL(NOLOCK)
       WHERE Listname='RPTLOGO' AND Code='LOGO' AND Long=@c_DataWindow
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_DocNumberExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='DocNumber')), '' )
           , @c_CarrierKeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='CarrierKey')), '' )
           , @c_ConsigneeKeyExp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='ConsigneeKey')), '' )
           , @c_CompanyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Company')), '' )
           , @c_Address1Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address1')), '' )
           , @c_Address2Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address2')), '' )
           , @c_Address3Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address3')), '' )
           , @c_Address4Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address4')), '' )
           , @c_ZipExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Zip')), '' )
           , @c_LabelPriceExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LabelPrice')), '' )
           , @c_RouteExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Route')), '' )
           , @c_TrfRoomExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='TrfRoom')), '' )
           , @c_Notes1Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Notes1')), '' )
           , @c_Notes2Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Notes2')), '' )
           , @c_VehicleNoExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='VehicleNo')), '' )
           , @c_RefNoExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='RefNo')), '' )
           , @c_SkuExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Sku')), '' )
           , @c_SkuDescExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='SkuDesc')), '' )
           , @c_PutawayZoneExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='PutawayZone')), '' )
           , @c_ZoneDescExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='ZoneDesc')), '' )
           , @c_LogicalLocExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LogicalLoc')), '' )
           , @c_LocExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Loc')), '' )
           , @c_Lottable02Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Lottable02')), '' )
           , @c_Lottable04Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Lottable04')), '' )
           , @c_QtyExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )
           , @c_CaseCntExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='CaseCnt')), '' )
           , @c_InnerPackExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='InnerPack')), '' )
           , @c_LineRemark1Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark1')), '' )
           , @c_LineRemark2Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark2')), '' )
           , @c_LineRemark3Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark3')), '' )
           , @c_Lbl_RouteExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Route')), '' )
           , @c_Lbl_DocNumberExp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_DocNumber')), '' )
           , @c_Lbl_ConsigneeExp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Consigneekey')), '' )
           , @c_Lbl_CompanyExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Company')), '' )
           , @c_Lbl_Address1Exp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Address1')), '' )
           , @c_Lbl_Address2Exp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Address2')), '' )
           , @c_Lbl_Address3Exp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Address3')), '' )
           , @c_Lbl_Address4Exp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Address4')), '' )
           , @c_Lbl_ZipExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Zip')), '' )
           , @c_Lbl_Notes1Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Notes1')), '' )
           , @c_Lbl_Notes2Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Notes2')), '' )
           , @c_Lbl_TrfRoomExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_TrfRoom')), '' )
           , @c_Lbl_CarrierkeyExp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Carrierkey')), '' )
           , @c_Lbl_VehicleNoExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_VehicleNo')), '' )
           , @c_Lbl_RefNoExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_RefNo')), '' )
           , @c_Lbl_LocExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Loc')), '' )
           , @c_Lbl_SkuExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Sku')), '' )
           , @c_Lbl_Lottable02Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Lottable02')), '' )
           , @c_Lbl_Lottable04Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Lottable04')), '' )
           , @c_Lbl_CaseCntExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_CaseCnt')), '' )
           , @c_Lbl_InnerPackExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_InnerPack')), '' )
           , @c_Lbl_CartonsExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Cartons')), '' )
           , @c_Lbl_InnerExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Inner')), '' )
           , @c_Lbl_EachExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='T_Each')), '' )
        FROM dbo.CODELKUP (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SET @c_ExecStatements =
        N'INSERT INTO #TEMP_PIKDT ('
        +    ' Loadkey, Storerkey, PickSlipNo, OrderKey, DocNumber, CarrierKey, ConsigneeKey, Company, Address1, Address2, Address3,'
        +    ' Address4, Zip, LabelPrice, Route, TrfRoom, Notes1, Notes2, PrintedFlag, VehicleNo, RefNo,'
        +    ' Sku, SkuDesc, PutawayZone, ZoneDesc, LogicalLocation, Loc, Lottable02, Lottable04, Qty, CaseCnt,'
        +    ' InnerPack, LineRemark1, LineRemark2, LineRemark3, ShowFields, Storer_Logo,'
        +    ' Lbl_Route, Lbl_DocNumber, Lbl_Consignee, Lbl_Company, Lbl_Address1, Lbl_Address2, Lbl_Address3, Lbl_Address4, Lbl_Zip, Lbl_Notes1,'
        +    ' Lbl_Notes2, Lbl_TrfRoom, Lbl_Carrierkey, Lbl_VehicleNo, Lbl_RefNo,'
        +    ' Lbl_Loc, Lbl_Sku, Lbl_Lottable02, Lbl_Lottable04, Lbl_CaseCnt, Lbl_InnerPack, Lbl_Cartons, Lbl_Inner, Lbl_Each)'
      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT Loadkey          = RTRIM(LPD.Loadkey)'
        +       ', Storerkey        = RTRIM(OH.Storerkey)'
        +       ', PickSlipNo       = RTRIM(PH.Pickheaderkey)'
        +       ', Orderkey         = RTRIM(ISNULL(OH.Orderkey, ''''))'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', DocNumber        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocNumberExp     ,'')<>'' THEN @c_DocNumberExp      ELSE 'ISNULL(TRIM(UPPER(OH.Orderkey)),'''')+'' / ''+ISNULL(TRIM(LPD.Loadkey),'''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', CarrierKey       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CarrierKeyExp    ,'')<>'' THEN @c_CarrierKeyExp     ELSE 'LP.CarrierKey'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ConsigneeKey     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ConsigneeKeyExp  ,'')<>'' THEN @c_ConsigneeKeyExp   ELSE 'OH.BillToKey'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Company          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CompanyExp       ,'')<>'' THEN @c_CompanyExp        ELSE 'OH.C_Company'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Address1         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Address1Exp      ,'')<>'' THEN @c_Address1Exp       ELSE 'OH.C_Address1'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Address2         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Address2Exp      ,'')<>'' THEN @c_Address2Exp       ELSE 'OH.C_Address2'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Address3         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Address3Exp      ,'')<>'' THEN @c_Address3Exp       ELSE 'OH.C_Address3'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Address4         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Address4Exp      ,'')<>'' THEN @c_Address4Exp       ELSE 'OH.C_Address4'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Zip              = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ZipExp           ,'')<>'' THEN @c_ZipExp            ELSE 'OH.C_Zip'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LabelPrice       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelPriceExp    ,'')<>'' THEN @c_LabelPriceExp     ELSE 'ISNULL(CASE WHEN ISNULL(OH.LabelPrice,''N'')=''Y'' THEN ''Price Labelling Required'' END,'''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Route            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteExp         ,'')<>'' THEN @c_RouteExp          ELSE 'ISNULL(TRIM(UPPER(LP.Route)),'''')+''     ''+ISNULL(TRIM(RM.Descr),'''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', TrfRoom          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TrfRoomExp       ,'')<>'' THEN @c_TrfRoomExp        ELSE 'LP.TrfRoom'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Notes1           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes1Exp        ,'')<>'' THEN @c_Notes1Exp         ELSE 'OH.Notes'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Notes2           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes2Exp        ,'')<>'' THEN @c_Notes2Exp         ELSE 'OH.Notes2'           END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PrintedFlag      = CASE WHEN PH.PickType = ''1'' THEN ''Y'' ELSE ''N'' END'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', VehicleNo        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_VehicleNoExp     ,'')<>'' THEN @c_VehicleNoExp      ELSE 'LP.TruckSize'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', RefNo            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RefNoExp         ,'')<>'' THEN @c_RefNoExp          ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Sku              = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuExp           ,'')<>'' THEN @c_SkuExp            ELSE 'PD.Sku'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', SkuDesc          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuDescExp       ,'')<>'' THEN @c_SkuDescExp        ELSE 'SKU.Descr'           END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PutawayZone      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PutawayZoneExp   ,'')<>'' THEN @c_PutawayZoneExp    ELSE 'LOC.PutawayZone'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ZoneDesc         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ZoneDescExp      ,'')<>'' THEN @c_ZoneDescExp       ELSE 'PA.Descr'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LogicalLocation  = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LogicalLocExp    ,'')<>'' THEN @c_LogicalLocExp     ELSE 'LOC.LogicalLocation' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Loc              = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LocExp           ,'')<>'' THEN @c_LocExp            ELSE 'PD.Loc'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable02       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lottable02Exp    ,'')<>'' THEN @c_Lottable02Exp     ELSE 'LA.Lottable02'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable04       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lottable04Exp    ,'')<>'' THEN @c_Lottable04Exp     ELSE 'CASE WHEN ISNULL(LA.Lottable04,'''')<>'''' THEN FORMAT(LA.Lottable04,''yyyy-MM-dd'') END' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Qty              = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_QtyExp           ,'')<>'' THEN @c_QtyExp            ELSE 'PD.Qty'              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', CaseCnt          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CaseCntExp       ,'')<>'' THEN @c_CaseCntExp        ELSE 'PACK.CaseCnt'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', InnerPack        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InnerPackExp     ,'')<>'' THEN @c_InnerPackExp      ELSE 'PACK.InnerPack'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark1      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark1Exp   ,'')<>'' THEN @c_LineRemark1Exp    ELSE 'NULL'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark2      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark2Exp   ,'')<>'' THEN @c_LineRemark2Exp    ELSE 'NULL'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark3      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark3Exp   ,'')<>'' THEN @c_LineRemark3Exp    ELSE 'NULL'                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ShowFields       = @c_ShowFields'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Storer_Logo      = RTRIM( ISNULL( @c_Storer_Logo, '''') )'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Route        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_RouteExp     ,'')<>'' THEN @c_Lbl_RouteExp      ELSE '''Route:'''          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_DocNumber    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_DocNumberExp ,'')<>'' THEN @c_Lbl_DocNumberExp  ELSE '''Order# / Load#:''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Consignee    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_ConsigneeExp ,'')<>'' THEN @c_Lbl_ConsigneeExp  ELSE '''Customer:'''       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Company      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_CompanyExp   ,'')<>'' THEN @c_Lbl_CompanyExp    ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Address1     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Address1Exp  ,'')<>'' THEN @c_Lbl_Address1Exp   ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Address2     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Address2Exp  ,'')<>'' THEN @c_Lbl_Address2Exp   ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Address3     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Address3Exp  ,'')<>'' THEN @c_Lbl_Address3Exp   ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Address4     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Address4Exp  ,'')<>'' THEN @c_Lbl_Address4Exp   ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Zip          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_ZipExp       ,'')<>'' THEN @c_Lbl_ZipExp        ELSE 'IIF(OH.C_Zip<>'''',''Zip:'','''')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Notes1       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Notes1Exp    ,'')<>'' THEN @c_Lbl_Notes1Exp     ELSE '''Order Notes:'''    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Notes2       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Notes2Exp    ,'')<>'' THEN @c_Lbl_Notes2Exp     ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_TrfRoom      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_TrfRoomExp   ,'')<>'' THEN @c_Lbl_TrfRoomExp    ELSE '''Trf. Room:'''      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Carrierkey   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_CarrierkeyExp,'')<>'' THEN @c_Lbl_CarrierkeyExp ELSE '''Transporter:'''    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_VehicleNo    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_VehicleNoExp ,'')<>'' THEN @c_Lbl_VehicleNoExp  ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_RefNo        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_RefNoExp     ,'')<>'' THEN @c_Lbl_RefNoExp      ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Loc          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_LocExp       ,'')<>'' THEN @c_Lbl_LocExp        ELSE '''Location'''        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Sku          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_SkuExp       ,'')<>'' THEN @c_Lbl_SkuExp        ELSE '''SKU'''             END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Lottable02   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Lottable02Exp,'')<>'' THEN @c_Lbl_Lottable02Exp ELSE '''Batch No'''        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Lottable04   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_Lottable04Exp,'')<>'' THEN @c_Lbl_Lottable04Exp ELSE '''Expiry Date'''     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_CaseCnt      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_CaseCntExp   ,'')<>'' THEN @c_Lbl_CaseCntExp    ELSE '''Case Cnt'''        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_InnerPack    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_InnerPackExp ,'')<>'' THEN @c_Lbl_InnerPackExp  ELSE '''Inner Pack'''      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Cartons      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_CartonsExp   ,'')<>'' THEN @c_Lbl_CartonsExp    ELSE '''Cartons'''         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Inner        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_InnerExp     ,'')<>'' THEN @c_Lbl_InnerExp      ELSE '''Inner'''           END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lbl_Each         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lbl_EachExp      ,'')<>'' THEN @c_Lbl_EachExp       ELSE '''Each'''            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +  ' FROM dbo.LOADPLANDETAIL   LPD  WITH(NOLOCK)'
        +  ' JOIN dbo.LOADPLAN         LP   WITH(NOLOCK) ON LPD.Loadkey = LP.Loadkey'
        +  ' JOIN dbo.ORDERS           OH   WITH(NOLOCK) ON LPD.Orderkey = OH.Orderkey'
        +  ' JOIN dbo.PICKHEADER       PH   WITH(NOLOCK) ON LPD.Orderkey = PH.Orderkey AND LPD.Loadkey = PH.ExternOrderkey AND PH.Zone=''8'''
        +  ' JOIN dbo.PICKDETAIL       PD   WITH(NOLOCK) ON LPD.OrderKey = PD.OrderKey'
        +  ' JOIN dbo.SKU              SKU  WITH(NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +  ' JOIN dbo.PACK             PACK WITH(NOLOCK) ON SKU.PackKey = PACK.PackKey'
        +  ' JOIN dbo.LOTATTRIBUTE     LA   WITH(NOLOCK) ON PD.Lot = LA.Lot'
        +  ' JOIN dbo.LOC              LOC  WITH(NOLOCK) ON PD.Loc = LOC.Loc'
        +  ' LEFT JOIN dbo.PUTAWAYZONE PA   WITH(NOLOCK) ON LOC.PutawayZone = PA.PutawayZone'
        +  ' LEFT JOIN dbo.ROUTEMASTER RM   WITH(NOLOCK) ON LP.Route = RM.Route'

      SET @c_ExecStatements = @c_ExecStatements
        + ' WHERE OH.Storerkey = @c_Storerkey'
        +   ' AND LPD.Loadkey  = @c_Loadkey'
        +   ' AND OH.Status >= ''1'' AND OH.Status <= ''9'''

      SET @c_ExecArguments = N'@c_DataWindow  NVARCHAR(40)'
                           + ',@c_ShowFields  NVARCHAR(MAX)'
                           + ',@c_Loadkey     NVARCHAR(10)'
                           + ',@c_Storerkey   NVARCHAR(15)'
                           + ',@c_Storer_Logo NVARCHAR(60)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_DataWindow
                       , @c_ShowFields
                       , @c_Loadkey
                       , @c_Storerkey
                       , @c_Storer_Logo
   END

   CLOSE C_CUR_STORERKEY
   DEALLocATE C_CUR_STORERKEY


   SELECT Loadkey         = MAX( UPPER( X.Loadkey ) )
        , Storerkey       = UPPER( X.Storerkey )
        , PickSlipNo      = UPPER( X.PickSlipNo )
        , OrderKey        = MAX( X.OrderKey )
        , DocNumber       = MAX( X.DocNumber )
        , CarrierKey      = MAX( X.CarrierKey )
        , ConsigneeKey    = MAX( X.ConsigneeKey )
        , Company         = MAX( X.Company )
        , Address1        = MAX( X.Address1 )
        , Address2        = MAX( X.Address2 )
        , Address3        = MAX( X.Address3 )
        , Address4        = MAX( X.Address4 )
        , Zip             = MAX( X.Zip )
        , LabelPrice      = MAX( X.LabelPrice )
        , Route           = MAX( X.Route )
        , TrfRoom         = MAX( X.TrfRoom )
        , Notes1          = MAX( X.Notes1 )
        , Notes2          = MAX( X.Notes2 )
        , PrintedFlag     = MAX( X.PrintedFlag )
        , VehicleNo       = MAX( X.VehicleNo )
        , RefNo           = MAX( X.RefNo )
        , Sku             = X.Sku
        , SkuDesc         = MAX( X.SkuDesc )
        , Putawayzone     = UPPER( MAX( X.Putawayzone ) )
        , ZoneDesc        = MAX( X.ZoneDesc )
        , LogicalLocation = UPPER( MAX( X.LogicalLocation ) )
        , Loc             = UPPER( X.Loc )
        , Lottable02      = X.Lottable02
        , Lottable04      = X.Lottable04
        , Qty             = SUM( X.Qty )
        , CaseCnt         = MAX( X.CaseCnt )
        , InnerPack       = MAX( X.InnerPack )
        , Cartons         = CASE WHEN ISNULL(MAX(X.CaseCnt  ),0)=0 THEN 0 ELSE FLOOR(SUM(X.Qty) / MAX(X.CaseCnt)) END
        , Inners          = CASE WHEN ISNULL(MAX(X.InnerPack),0)=0 THEN 0 ELSE FLOOR( IIF(ISNULL(MAX(X.CaseCnt),0)=0, SUM(X.Qty), SUM(X.Qty) % MAX(X.CaseCnt)) / MAX(X.InnerPack)) END
        , Pieces          = CASE WHEN ISNULL(MAX(X.InnerPack),0)=0 THEN IIF(ISNULL(MAX(X.CaseCnt),0)=0, SUM(X.Qty), SUM(X.Qty) % MAX(X.CaseCnt))
                                                                   ELSE IIF(ISNULL(MAX(X.CaseCnt),0)=0, SUM(X.Qty), SUM(X.Qty) % MAX(X.CaseCnt)) % MAX(X.InnerPack) END
        , LineRemark1     = X.LineRemark1
        , LineRemark2     = X.LineRemark2
        , LineRemark3     = X.LineRemark3
        , ShowFields      = MAX( X.ShowFields )
        , Storer_Logo     = MAX( X.Storer_Logo )
        , Lbl_Route       = MAX( X.Lbl_Route )
        , Lbl_DocNumber   = MAX( X.Lbl_DocNumber )
        , Lbl_Consignee   = MAX( X.Lbl_Consignee )
        , Lbl_Company     = MAX( X.Lbl_Company )
        , Lbl_Address1    = MAX( X.Lbl_Address1 )
        , Lbl_Address2    = MAX( X.Lbl_Address2 )
        , Lbl_Address3    = MAX( X.Lbl_Address3 )
        , Lbl_Address4    = MAX( X.Lbl_Address4 )
        , Lbl_Zip         = MAX( X.Lbl_Zip )
        , Lbl_Notes1      = MAX( X.Lbl_Notes1 )
        , Lbl_Notes2      = MAX( X.Lbl_Notes2 )
        , Lbl_TrfRoom     = MAX( X.Lbl_TrfRoom )
        , Lbl_Carrierkey  = MAX( X.Lbl_Carrierkey )
        , Lbl_VehicleNo   = MAX( X.Lbl_VehicleNo )
        , Lbl_RefNo       = MAX( X.Lbl_RefNo )
        , Lbl_Loc         = MAX( X.Lbl_Loc )
        , Lbl_Sku         = MAX( X.Lbl_Sku )
        , Lbl_Lottable02  = MAX( X.Lbl_Lottable02 )
        , Lbl_Lottable04  = MAX( X.Lbl_Lottable04 )
        , Lbl_CaseCnt     = MAX( X.Lbl_CaseCnt )
        , Lbl_InnerPack   = MAX( X.Lbl_InnerPack )
        , Lbl_Cartons     = MAX( X.Lbl_Cartons )
        , Lbl_Inner       = MAX( X.Lbl_Inner )
        , Lbl_Each        = MAX( X.Lbl_Each )
 FROM #TEMP_PIKDT X
   GROUP BY X.Storerkey
          , X.PickSlipNo
          , X.Sku
          , X.Loc
          , X.Lottable02
          , X.Lottable04
          , X.LineRemark1
          , X.LineRemark2
          , X.LineRemark3
   ORDER BY PickSlipNo, LogicalLocation, Loc, Sku, Lottable02, Lottable04

   DROP TABLE #TEMP_PIKDT

QUIT:
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @n_continue=3
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
         ROLLBACK TRAN
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
            COMMIT TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_r_hk_print_pickorder_01'
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
         COMMIT TRAN
      RETURN
   END
END

GO