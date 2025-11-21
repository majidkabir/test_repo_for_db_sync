SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_print_wave_pickslip_03                     */
/*                 modified from nsp_GetPickSlipWave_08 (ver 14-Mar-2012)*/
/* Creation Date: 18-Nov-2020                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Discrete Pickslip                                            */
/*                                                                       */
/* Called By: RCM - Popup Pickslip in Loadplan / WavePlan                */
/*            Datawidnow r_hk_print_wave_pickslip_03                     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2021-04-28   Michael  V1.1 Add Configurable Fields for IDSMED         */
/* 2021-06-24   Michael  V1.2 Add Showfield Update_PD_PickslipNo         */
/* 2021-10-08   Michael  V1.3 Add MapField: OrderType; Showfield:        */
/*                            ExternOrderkey_BC, NoGenPickHeader         */
/* 2021-11-30   Michael  V1.4 Fix RptCfg.ShowFields NULL value issue     */
/* 2022-03-23   Michael  V1.5 Add NULL to Temp Table                     */
/* 2022-06-01   Michael  V1.6 Add Post Process Script                    */
/*                            Add MAPFIELD: Temp01-Temp05                */
/* 2022-06-24   Michael  V1.7 WMS-20060 AddMapField:Cartons,Inners,Pieces*/
/*                            Add ShowField: HideCaseCnt, HideInnerPack, */
/*                            HideCartons, HideInners, HidePieces        */
/*************************************************************************/

CREATE PROC [dbo].[isp_r_hk_print_wave_pickslip_03] (
       @c_Wavekey_type   NVARCHAR(13)
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      StorerCompany, ExternOrderKey, OrderType, ExternPOKey, BuyerPO, InvoiceNo, DeliveryDate, ConsigneeKey, Company, Address1, Address2
      Address3, PostCode, Route, RouteDesc, TrfRoom, LabelPrice, PendingFlag, Notes1, Notes2, SkuDesc
      ZoneDesc, AltSku, SUSR2, BUSR8, BUSR10, Lottable01, Lottable02, Lottable03, Lottable04, CaseCnt
      InnerPack, PackUOM1, PackUOM2, PackUOM3, Cartons, Inners, Pieces
      StdCube, StdGrossWgt, DCC, LineRemark1, LineRemark2, LineRemark3
      Temp01, Temp02, Temp03, Temp04, Temp05


   [MAPVALUE]
      T_Customer, T_InvoiceNo, T_ExternOrderkey, T_ExternPOKey, T_Notes1, T_Notes2, T_SUSR2, T_DeliveryDate, T_PendingFlag
      T_Route, T_TrfRoom, T_BuyerPO, T_CBM, T_Weight
      T_Loc, T_Sku, T_SkuDescr, T_AltSku, T_DCC, T_BUSR8, T_Lottable01, T_Lottable02, T_Lottable03, T_Lottable04, T_ID
      T_CaseCnt, T_InnerPack, T_PackUOM1, T_PackUOM2, T_PackUOM3

   [SHOWFIELD]
      Consigneekey, ExternOrderkey_BC, DCC, LineRemark1, LineRemark2, LineRemark3
      HideLottable01, HideAltSku, HideCaseCnt, HideInnerPack, HideCartons, HideInners, HidePieces
      Update_PD_PickslipNo, NoGenPickHeader

   [SQLJOIN]

   [POSTSCRIPT]
*/
   DECLARE @c_DataWindow       NVARCHAR(40)  = 'r_hk_print_wave_pickslip_03'
         , @n_continue         INT           = 1
         , @n_StartTCnt        INT           = @@TRANCOUNT
         , @c_Wavekey          NVARCHAR(10)  = LEFT(@c_Wavekey_type, 10)
         , @c_Type             NVARCHAR(2)   = RIGHT(@c_Wavekey_type,2)
         , @c_Pickheaderkey    NVARCHAR(10)
         , @c_Orderkey         NVARCHAR(10)
         , @c_Update_PD_PSNo   NVARCHAR(10)
         , @c_errmsg           NVARCHAR(255)
         , @b_success          INT
         , @n_err              INT
         , @c_Storerkey        NVARCHAR(15)
         , @c_Storer_Logo      NVARCHAR(60)
         , @c_ExecStatements   NVARCHAR(MAX)
         , @c_ExecArguments    NVARCHAR(MAX)
         , @c_ShowFields       NVARCHAR(MAX)
         , @c_JoinClause       NVARCHAR(MAX)
         , @c_PostScript       NVARCHAR(MAX)
         , @c_StrCompanyExp    NVARCHAR(MAX)
         , @c_ExtOrderKeyExp   NVARCHAR(MAX)
         , @c_OrderTypeExp     NVARCHAR(MAX)
         , @c_ExternPOKeyExp   NVARCHAR(MAX)
         , @c_BuyerPOExp       NVARCHAR(MAX)
         , @c_InvoiceNoExp     NVARCHAR(MAX)
         , @c_DeliveryDateExp  NVARCHAR(MAX)
         , @c_ConsigneeKeyExp  NVARCHAR(MAX)
         , @c_CompanyExp       NVARCHAR(MAX)
         , @c_Addr1Exp         NVARCHAR(MAX)
         , @c_Addr2Exp         NVARCHAR(MAX)
         , @c_Addr3Exp         NVARCHAR(MAX)
         , @c_PostCodeExp      NVARCHAR(MAX)
         , @c_RouteExp         NVARCHAR(MAX)
         , @c_RouteDescExp     NVARCHAR(MAX)
         , @c_TrfRoomExp       NVARCHAR(MAX)
         , @c_LabelPriceExp    NVARCHAR(MAX)
         , @c_PendingFlagExp   NVARCHAR(MAX)
         , @c_Notes1Exp        NVARCHAR(MAX)
         , @c_Notes2Exp        NVARCHAR(MAX)
         , @c_SkuDescExp       NVARCHAR(MAX)
         , @c_ZoneDescExp      NVARCHAR(MAX)
         , @c_AltSkuExp        NVARCHAR(MAX)
         , @c_SUSR2Exp         NVARCHAR(MAX)
         , @c_BUSR8Exp         NVARCHAR(MAX)
         , @c_BUSR10Exp        NVARCHAR(MAX)
         , @c_Lottable01Exp    NVARCHAR(MAX)
         , @c_Lottable02Exp    NVARCHAR(MAX)
         , @c_Lottable03Exp    NVARCHAR(MAX)
         , @c_Lottable04Exp    NVARCHAR(MAX)
         , @c_CaseCntExp       NVARCHAR(MAX)
         , @c_InnerPackExp     NVARCHAR(MAX)
         , @c_PackUOM1Exp      NVARCHAR(MAX)
         , @c_PackUOM2Exp      NVARCHAR(MAX)
         , @c_PackUOM3Exp      NVARCHAR(MAX)
         , @c_CartonsExp       NVARCHAR(MAX)
         , @c_InnersExp        NVARCHAR(MAX)
         , @c_PiecesExp        NVARCHAR(MAX)
         , @c_StdCubeExp       NVARCHAR(MAX)
         , @c_StdGrossWgtExp   NVARCHAR(MAX)
         , @c_DCCExp           NVARCHAR(MAX)
         , @c_LineRemark1Exp   NVARCHAR(MAX)
         , @c_LineRemark2Exp   NVARCHAR(MAX)
         , @c_LineRemark3Exp   NVARCHAR(MAX)
         , @c_Temp01Exp        NVARCHAR(MAX)
         , @c_Temp02Exp        NVARCHAR(MAX)
         , @c_Temp03Exp        NVARCHAR(MAX)
         , @c_Temp04Exp        NVARCHAR(MAX)
         , @c_Temp05Exp        NVARCHAR(MAX)

   IF OBJECT_ID('tempdb..#TEMP_PIKDT') IS NOT NULL
      DROP TABLE #TEMP_PIKDT

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN


   -- Generate PickHeader
   DECLARE PICK_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
    SELECT OH.Orderkey, MAX(CASE WHEN ISNULL(RptCfg.ShowFields,'') LIKE '%,Update_PD_PickslipNo,%' THEN 'Y' ELSE 'N' END)
      FROM dbo.WAVEDETAIL WD (NOLOCK)
      JOIN dbo.ORDERS     OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
      JOIN dbo.PICKDETAIL PD (NOLOCK) ON WD.Orderkey = PD.Orderkey
      LEFT JOIN dbo.PICKHEADER PH (NOLOCK) ON WD.Orderkey = PH.Orderkey
      LEFT JOIN dbo.PICKHEADER PH2(NOLOCK) ON OH.Loadkey  = PH2.ExternOrderkey AND ISNULL(PH2.Orderkey,'')='' AND ISNULL(OH.Loadkey,'')<>''
      LEFT JOIN (
         SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg
      ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1
    WHERE WD.wavekey = @c_Wavekey
      AND OH.Userdefine08 = 'Y' -- only for wave plan OH.
      AND PD.Status < '5'
      AND (PD.Pickmethod = '8' OR PD.Pickmethod = '')
      AND PH.PickHeaderKey IS NULL
      AND PH2.PickHeaderKey IS NULL
      AND NOT (ISNULL(RptCfg.ShowFields,'') LIKE '%,NoGenPickHeader,%')
    GROUP BY OH.Orderkey
    ORDER BY 1

   OPEN PICK_CUR

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM PICK_CUR INTO @c_Orderkey, @c_Update_PD_PSNo

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
             (PickHeaderKey   , OrderKey   , WaveKey   , PickType, Zone, TrafficCop)
      VALUES (@c_Pickheaderkey, @c_Orderkey, @c_Wavekey, '0'     , '8' ,  ''       )

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
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
          WHERE Orderkey = @c_Orderkey
            AND Status < '9'
            AND ShipFlag <> 'Y'
            AND ISNULL(PickslipNo,'') <> @c_Pickheaderkey
      END
   END

   CLOSE PICK_CUR
   DEALLOCATE PICK_CUR



   CREATE TABLE #TEMP_PIKDT (
        Wavekey          NVARCHAR(10)   NULL
      , Storerkey        NVARCHAR(15)   NULL
      , StorerCompany    NVARCHAR(50)   NULL
      , PickSlipNo       NVARCHAR(18)   NULL
      , OrderKey         NVARCHAR(10)   NULL
      , ExternOrderKey   NVARCHAR(50)   NULL
      , OrderType        NVARCHAR(50)   NULL
      , ExternPOKey      NVARCHAR(50)   NULL
      , BuyerPO          NVARCHAR(50)   NULL
      , InvoiceNo        NVARCHAR(50)   NULL
      , DeliveryDate     DATETIME       NULL
      , ConsigneeKey     NVARCHAR(50)   NULL
      , Company          NVARCHAR(50)   NULL
      , Addr1            NVARCHAR(50)   NULL
      , Addr2            NVARCHAR(50)   NULL
      , Addr3            NVARCHAR(50)   NULL
      , PostCode         NVARCHAR(50)   NULL
      , Route            NVARCHAR(50)   NULL
      , Route_Desc       NVARCHAR(60)   NULL
      , TrfRoom          NVARCHAR(50)   NULL
      , PrintedFlag      NVARCHAR(1)    NULL
      , LabelPrice       NVARCHAR(50)   NULL
      , PendingFlag      NVARCHAR(50)   NULL
      , Notes1           NVARCHAR(500)  NULL
      , Notes2           NVARCHAR(500)  NULL
      , SKU              NVARCHAR(20)   NULL
      , SkuDesc          NVARCHAR(60)   NULL
      , Putawayzone      NVARCHAR(10)   NULL
      , ZoneDesc         NVARCHAR(60)   NULL
      , LogicalLocation  NVARCHAR(18)   NULL
      , LOC              NVARCHAR(10)   NULL
      , ID               NVARCHAR(18)   NULL
      , AltSKU           NVARCHAR(50)   NULL
      , SUSR2            NVARCHAR(50)   NULL
      , BUSR8            NVARCHAR(50)   NULL
      , BUSR10           NVARCHAR(50)   NULL
      , Lottable01       NVARCHAR(50)   NULL
      , Lottable02       NVARCHAR(50)   NULL
      , Lottable03       NVARCHAR(50)   NULL
      , Lottable04       DATETIME       NULL
      , Qty              INT            NULL
      , CaseCnt          INT            NULL
      , InnerPack        INT            NULL
      , PackUOM1         NVARCHAR(50)   NULL
      , PackUOM2         NVARCHAR(50)   NULL
      , PackUOM3         NVARCHAR(50)   NULL
      , Cartons          INT            NULL
      , Inners           INT            NULL
      , Pieces           INT            NULL
      , StdCube          FLOAT          NULL
      , StdGrossWgt      FLOAT          NULL
      , DCC              NVARCHAR(50)   NULL
      , LineRemark1      NVARCHAR(500)  NULL
      , LineRemark2      NVARCHAR(500)  NULL
      , LineRemark3      NVARCHAR(500)  NULL
      , Temp01           NVARCHAR(MAX)  NULL
      , Temp02           NVARCHAR(MAX)  NULL
      , Temp03           NVARCHAR(MAX)  NULL
      , Temp04           NVARCHAR(MAX)  NULL
      , Temp05           NVARCHAR(MAX)  NULL
      , DWName           NVARCHAR(40)   NULL
      , ShowFields       NVARCHAR(4000) NULL
      , Storer_Logo      NVARCHAR(60)   NULL
   )


   -- Storerkey Loop
   DECLARE C_CUR_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT PD.Storerkey
     FROM dbo.WAVEDETAIL   WD   (NOLOCK)
     JOIN dbo.ORDERS       OH   (NOLOCK) ON WD.Orderkey = OH.Orderkey
     JOIN dbo.PICKHEADER   PH   (NOLOCK) ON WD.Orderkey = PH.Orderkey
     JOIN dbo.PICKDETAIL   PD   (NOLOCK) ON WD.Orderkey = PD.Orderkey
    WHERE WD.wavekey = @c_Wavekey
      AND OH.Status >= '1' AND OH.Status <= '9'
      AND ( PD.Pickmethod = '8' OR PD.Pickmethod = ' ' )
    ORDER BY 1

   OPEN C_CUR_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CUR_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_ShowFields      = ''
           , @c_JoinClause      = ''
           , @c_PostScript      = ''
           , @c_Storer_Logo     = ''
           , @c_StrCompanyExp   = ''
           , @c_ExtOrderKeyExp  = ''
           , @c_OrderTypeExp    = ''
           , @c_ExternPOKeyExp  = ''
           , @c_BuyerPOExp      = ''
           , @c_InvoiceNoExp    = ''
           , @c_DeliveryDateExp = ''
           , @c_ConsigneeKeyExp = ''
           , @c_CompanyExp      = ''
           , @c_Addr1Exp        = ''
           , @c_Addr2Exp        = ''
           , @c_Addr3Exp        = ''
           , @c_PostCodeExp     = ''
           , @c_RouteExp        = ''
           , @c_RouteDescExp    = ''
           , @c_TrfRoomExp      = ''
           , @c_LabelPriceExp   = ''
           , @c_PendingFlagExp  = ''
           , @c_Notes1Exp       = ''
           , @c_Notes2Exp       = ''
           , @c_SkuDescExp      = ''
           , @c_ZoneDescExp     = ''
           , @c_AltSkuExp       = ''
           , @c_SUSR2Exp        = ''
           , @c_BUSR8Exp        = ''
           , @c_BUSR10Exp       = ''
           , @c_Lottable01Exp   = ''
           , @c_Lottable02Exp   = ''
           , @c_Lottable03Exp   = ''
           , @c_Lottable04Exp   = ''
           , @c_CaseCntExp      = ''
           , @c_InnerPackExp    = ''
           , @c_PackUOM1Exp     = ''
           , @c_PackUOM2Exp     = ''
           , @c_PackUOM3Exp     = ''
           , @c_CartonsExp      = ''
           , @c_InnersExp       = ''
           , @c_PiecesExp       = ''
           , @c_StdCubeExp      = ''
           , @c_StdGrossWgtExp  = ''
           , @c_DCCExp          = ''
           , @c_LineRemark1Exp  = ''
           , @c_LineRemark2Exp  = ''
           , @c_LineRemark3Exp  = ''
           , @c_Temp01Exp       = ''
           , @c_Temp02Exp       = ''
           , @c_Temp03Exp       = ''
           , @c_Temp04Exp       = ''
           , @c_Temp05Exp       = ''

      SELECT TOP 1
             @c_ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
      FROM dbo.CODELKUP (NOLOCK)
      WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_JoinClause = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_PostScript = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='POSTSCRIPT' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SELECT TOP 1
             @c_Storer_Logo = ISNULL(RTRIM(RL.Notes), '')
        FROM dbo.CODELKUP RL(NOLOCK)
       WHERE Listname='RPTLOGO' AND Code='LOGO' AND Long=@c_DataWindow
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_StrCompanyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='StorerCompany')), '' )
           , @c_ExtOrderKeyExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderKey')), '' )
           , @c_OrderTypeExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='OrderType')), '' )
           , @c_ExternPOKeyExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='ExternPOKey')), '' )
           , @c_BuyerPOExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='BuyerPO')), '' )
           , @c_InvoiceNoExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='InvoiceNo')), '' )
           , @c_DeliveryDateExp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDate')), '' )
           , @c_ConsigneeKeyExp= ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='ConsigneeKey')), '' )
           , @c_CompanyExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Company')), '' )
           , @c_Addr1Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address1')), '' )
           , @c_Addr2Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address2')), '' )
           , @c_Addr3Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Address3')), '' )
           , @c_PostCodeExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='PostCode')), '' )
           , @c_RouteExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Route')), '' )
           , @c_RouteDescExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='RouteDesc')), '' )
           , @c_TrfRoomExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='TrfRoom')), '' )
           , @c_LabelPriceExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LabelPrice')), '' )
           , @c_PendingFlagExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='PendingFlag')), '' )
           , @c_Notes1Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Notes1')), '' )
           , @c_Notes2Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Notes2')), '' )
           , @c_SkuDescExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='SkuDesc')), '' )
           , @c_ZoneDescExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='ZoneDesc')), '' )
           , @c_AltSkuExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='AltSku')), '' )
           , @c_SUSR2Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='SUSR2')), '' )
           , @c_BUSR8Exp       = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='BUSR8')), '' )
           , @c_BUSR10Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='BUSR10')), '' )
           , @c_Lottable01Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Lottable01')), '' )
           , @c_Lottable02Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Lottable02')), '' )
           , @c_Lottable03Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Lottable03')), '' )
           , @c_Lottable04Exp  = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Lottable04')), '' )
           , @c_CaseCntExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='CaseCnt')), '' )
           , @c_InnerPackExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='InnerPack')), '' )
           , @c_PackUOM1Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='PackUOM1')), '' )
           , @c_PackUOM2Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='PackUOM2')), '' )
           , @c_PackUOM3Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='PackUOM3')), '' )
           , @c_CartonsExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Cartons')), '' )
           , @c_InnersExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Inners')), '' )
           , @c_PiecesExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Pieces')), '' )
           , @c_StdCubeExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='StdCube')), '' )
           , @c_StdGrossWgtExp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='StdGrossWgt')), '' )
           , @c_DCCExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='DCC')), '' )
           , @c_LineRemark1Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark1')), '' )
           , @c_LineRemark2Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark2')), '' )
           , @c_LineRemark3Exp = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='LineRemark3')), '' )
           , @c_Temp01Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Temp01')), '' )
           , @c_Temp02Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Temp02')), '' )
           , @c_Temp03Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Temp03')), '' )
           , @c_Temp04Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Temp04')), '' )
           , @c_Temp05Exp      = ISNULL(RTRIM((select top 1 b.ColValue
                                 from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                 where a.SeqNo=b.SeqNo and a.ColValue='Temp05')), '' )
        FROM dbo.CODELKUP (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SET @c_ExecStatements =
        N'INSERT INTO #TEMP_PIKDT ('
        +    ' Wavekey, Storerkey, StorerCompany, PickSlipNo, OrderKey, ExternOrderKey, OrderType, ExternPOKey, BuyerPO, InvoiceNo, DeliveryDate'
        +   ', ConsigneeKey, Company, Addr1, Addr2, Addr3, PostCode, Route, Route_Desc, TrfRoom, PrintedFlag'
        +   ', LabelPrice, PendingFlag, Notes1, Notes2, SKU, SkuDesc, Putawayzone, ZoneDesc, LogicalLocation, LOC'
        +   ', ID, AltSKU, SUSR2, BUSR8, BUSR10, Lottable01, Lottable02, Lottable03, Lottable04, Qty'
        +   ', CaseCnt, InnerPack, PackUOM1, PackUOM2, PackUOM3, Cartons, Inners, Pieces'
        +   ', StdCube, StdGrossWgt, DCC, LineRemark1, LineRemark2'
        +   ', LineRemark3, Temp01, Temp02, Temp03, Temp04, Temp05, DWName, ShowFields, Storer_Logo)'

      SET @c_ExecStatements = @c_ExecStatements
        + ' SELECT Wavekey          = ISNULL(RTRIM(WD.Wavekey),'''')'
        +       ', Storerkey        = ISNULL(RTRIM(PD.Storerkey),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', StorerCompany    = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StrCompanyExp  ,'')<>'' THEN @c_StrCompanyExp   ELSE 'ST.Company'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PickSlipNo       = ISNULL(RTRIM(PH.PickheaderKey),'''')'
        +       ', OrderKey         = ISNULL(RTRIM(PD.Orderkey),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ExternOrderKey   = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExtOrderKeyExp ,'')<>'' THEN @c_ExtOrderKeyExp  ELSE 'OH.ExternOrderKey' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', OrderType        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderTypeExp   ,'')<>'' THEN @c_OrderTypeExp    ELSE 'OH.Type'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ExternPOKey      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternPOKeyExp ,'')<>'' THEN @c_ExternPOKeyExp  ELSE 'OH.ExternPoKey'  END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', BuyerPO          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BuyerPOExp     ,'')<>'' THEN @c_BuyerPOExp      ELSE 'OH.BuyerPO'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', InvoiceNo        = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_InvoiceNoExp   ,'')<>'' THEN @c_InvoiceNoExp    ELSE 'OH.InvoiceNo'    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', DeliveryDate     = '              + CASE WHEN ISNULL(@c_DeliveryDateExp,'')<>'' THEN @c_DeliveryDateExp ELSE 'OH.DeliveryDate' END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ConsigneeKey     = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ConsigneeKeyExp ,'')<>'' THEN @c_ConsigneeKeyExp
                                                            ELSE CASE WHEN @c_ShowFields LIKE '%,Consigneekey,%' THEN 'OH.Consigneekey' ELSE 'OH.BillToKey'  END
                                                       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Company          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_CompanyExp     ,'')<>'' THEN @c_CompanyExp      ELSE 'OH.C_Company'    END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Addr1            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Addr1Exp       ,'')<>'' THEN @c_Addr1Exp        ELSE 'OH.C_Address1'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Addr2            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Addr2Exp       ,'')<>'' THEN @c_Addr2Exp        ELSE 'OH.C_Address2'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Addr3            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Addr3Exp       ,'')<>'' THEN @c_Addr3Exp        ELSE 'OH.C_Address3'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PostCode         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PostCodeExp    ,'')<>'' THEN @c_PostCodeExp     ELSE 'OH.C_Zip'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Route            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteExp       ,'')<>'' THEN @c_RouteExp        ELSE 'OH.Route'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Route_Desc       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RouteDescExp   ,'')<>'' THEN @c_RouteDescExp    ELSE 'RT.Descr'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', TrfRoom          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_TrfRoomExp     ,'')<>'' THEN @c_TrfRoomExp      ELSE 'OH.Door'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PrintedFlag      = CASE WHEN PH.PickType = ''1'' THEN ''Y'' ELSE ''N'' END'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LabelPrice       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LabelPriceExp  ,'')<>'' THEN @c_LabelPriceExp   ELSE 'ISNULL(OH.LabelPrice,''N'')' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PendingFlag      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PendingFlagExp ,'')<>'' THEN @c_PendingFlagExp  ELSE 'OH.RDD'          END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Notes1           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes1Exp      ,'')<>'' THEN @c_Notes1Exp       ELSE 'OH.Notes'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Notes2           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Notes2Exp      ,'')<>'' THEN @c_Notes2Exp       ELSE 'OH.Notes2'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', SKU              = ISNULL(RTRIM(PD.Sku),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', SkuDesc          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SkuDescExp     ,'')<>'' THEN @c_SkuDescExp      ELSE 'SKU.Descr'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Putawayzone      = ISNULL(RTRIM(CASE WHEN PD.ToLoc<>'''' THEN TOLOC.Putawayzone ELSE LOC.Putawayzone END),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', ZoneDesc         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ZoneDescExp    ,'')<>'' THEN @c_ZoneDescExp
                                                            ELSE 'CASE WHEN PD.ToLoc<>'''' THEN TOPA.Descr ELSE PA.Descr END'
                                                       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LogicalLocation  = ISNULL(RTRIM(LOC.LogicalLocation),'''')'
        +       ', LOC              = ISNULL(RTRIM(CASE WHEN PD.ToLoc<>'''' THEN PD.ToLoc ELSE PD.Loc END),'''')'
        +       ', ID               = ISNULL(RTRIM(PD.ID),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', AltSKU           = ISNULL(RTRIM(' + CASE WHEN @c_ShowFields LIKE '%,HideAltSku,%'       THEN 'NULL'
                                                            ELSE CASE WHEN ISNULL(@c_AltSkuExp,'')<>''     THEN @c_AltSkuExp      ELSE 'SKU.AltSKU'    END
                                                       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', SUSR2            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SUSR2Exp,'')<>''  THEN @c_SUSR2Exp
                                                            ELSE CASE WHEN @c_ShowFields LIKE '%,Consigneekey,%' THEN 'SHPTO.SUSR2' ELSE 'BILTO.SUSR2' END
                                                       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', BUSR8            = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BUSR8Exp       ,'')<>'' THEN @c_BUSR8Exp        ELSE 'SKU.BUSR8'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', BUSR10           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BUSR10Exp      ,'')<>'' THEN @c_BUSR10Exp       ELSE 'SKU.BUSR10'      END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable01       = ISNULL(RTRIM(' + CASE WHEN @c_ShowFields LIKE '%,HideLottable01,%'   THEN 'NULL'
                                                            ELSE CASE WHEN ISNULL(@c_Lottable01Exp,'')<>'' THEN @c_Lottable01Exp  ELSE 'LA.Lottable01' END
                                                       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable02       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lottable02Exp  ,'')<>'' THEN @c_Lottable02Exp   ELSE 'LA.Lottable02'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable03       = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Lottable03Exp  ,'')<>'' THEN @c_Lottable03Exp   ELSE 'LA.Lottable03'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Lottable04       = '              + CASE WHEN ISNULL(@c_Lottable04Exp  ,'')<>'' THEN @c_Lottable04Exp   ELSE 'LA.Lottable04'   END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Qty              = PD.Qty'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', CaseCnt          = '              + CASE WHEN ISNULL(@c_CaseCntExp     ,'')<>'' THEN @c_CaseCntExp      ELSE 'PACK.CaseCnt'    END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', InnerPack        = '              + CASE WHEN ISNULL(@c_InnerPackExp   ,'')<>'' THEN @c_InnerPackExp    ELSE 'PACK.InnerPack'  END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PackUOM1         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PackUOM1Exp    ,'')<>'' THEN @c_PackUOM1Exp     ELSE 'PACK.PackUOM1'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PackUOM2         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PackUOM2Exp    ,'')<>'' THEN @c_PackUOM2Exp     ELSE 'PACK.PackUOM2'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', PackUOM3         = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_PackUOM3Exp    ,'')<>'' THEN @c_PackUOM3Exp     ELSE 'PACK.PackUOM3'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Cartons          = '              + CASE WHEN ISNULL(@c_CartonsExp     ,'')<>'' THEN @c_CartonsExp      ELSE 'NULL'            END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Inners           = '              + CASE WHEN ISNULL(@c_InnersExp      ,'')<>'' THEN @c_InnersExp       ELSE 'NULL'            END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Pieces           = '              + CASE WHEN ISNULL(@c_PiecesExp      ,'')<>'' THEN @c_PiecesExp       ELSE 'NULL'            END
      SET @c_ExecStatements = @c_ExecStatements
        +       ', StdCube          = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StdCubeExp     ,'')<>'' THEN @c_StdCubeExp      ELSE 'SKU.StdCube'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', StdGrossWgt      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StdGrossWgtExp ,'')<>'' THEN @c_StdGrossWgtExp  ELSE 'SKU.StdGrossWgt' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', DCC              = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DCCExp         ,'')<>'' THEN @c_DCCExp          ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark1      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark1Exp ,'')<>'' THEN @c_LineRemark1Exp  ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark2      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark2Exp ,'')<>'' THEN @c_LineRemark2Exp  ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', LineRemark3      = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemark3Exp ,'')<>'' THEN @c_LineRemark3Exp  ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Temp01           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Temp01Exp      ,'')<>'' THEN @c_Temp01Exp       ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Temp02           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Temp02Exp      ,'')<>'' THEN @c_Temp02Exp       ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Temp03           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Temp03Exp      ,'')<>'' THEN @c_Temp03Exp       ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Temp04           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Temp04Exp      ,'')<>'' THEN @c_Temp04Exp       ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', Temp05           = ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_Temp05Exp      ,'')<>'' THEN @c_Temp05Exp       ELSE 'NULL'            END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
        +       ', DWName           = @c_DataWindow'
        +       ', ShowFields       = ISNULL(RTRIM(@c_ShowFields),'''')'
        +       ', Storer_Logo      = ISNULL(RTRIM(@c_Storer_Logo),'''')'

      SET @c_ExecStatements = @c_ExecStatements
        +   ' FROM dbo.WAVEDETAIL   WD   (NOLOCK)'
        +   ' JOIN dbo.ORDERS       OH   (NOLOCK) ON WD.Orderkey = OH.Orderkey'
        +   ' JOIN ('
        +      ' SELECT *, SeqNo = ROW_NUMBER() OVER(PARTITION BY Orderkey ORDER BY CASE WHEN Zone=''8'' THEN 1 ELSE 2 END, PickHeaderKey)'
        +      ' FROM dbo.PICKHEADER (NOLOCK) WHERE Orderkey<>'''''
        +    ') PH ON WD.Orderkey = PH.Orderkey AND PH.SeqNo=1'
        +   ' JOIN dbo.PICKDETAIL   PD   (NOLOCK) ON WD.Orderkey = PD.Orderkey'
        +   ' JOIN dbo.PACK         PACK (NOLOCK) ON PD.Packkey = PACK.Packkey'
        +   ' JOIN dbo.LOC          LOC  (NOLOCK) ON PD.Loc = LOC.Loc'
        +   ' JOIN dbo.SKU          SKU  (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +   ' JOIN dbo.LOTATTRIBUTE LA   (NOLOCK) ON PD.Lot = LA.Lot'
        +   ' JOIN dbo.STORER       ST   (NOLOCK) ON PD.Storerkey = ST.Storerkey'
        +   ' LEFT JOIN dbo.ROUTEMASTER  RT   (NOLOCK) ON OH.Route = RT.Route'
        +   ' LEFT JOIN dbo.PUTAWAYZONE  PA   (NOLOCK) ON LOC.PutawayZone = PA.PutawayZone'
        +   ' LEFT JOIN dbo.LOC          TOLOC(NOLOCK) ON PD.ToLoc = TOLOC.Loc AND ISNULL(PD.ToLoc,'''')<>'''''
        +   ' LEFT JOIN dbo.PUTAWAYZONE  TOPA (NOLOCK) ON TOLOC.PutawayZone = TOPA.PutawayZone'
        +   ' LEFT JOIN dbo.STORER       SHPTO(NOLOCK) ON OH.Consigneekey = SHPTO.Storerkey'
        +   ' LEFT JOIN dbo.STORER       BILTO(NOLOCK) ON OH.BillToKey = BILTO.Storerkey'
      SET @c_ExecStatements = @c_ExecStatements
        + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END

      SET @c_ExecStatements = @c_ExecStatements
        +   ' WHERE WD.wavekey = @c_Wavekey'
        +     ' AND PD.Storerkey = @c_Storerkey'
        +     ' AND OH.Status >= ''1'' AND OH.Status <= ''9'''
        +     ' AND ( PD.Pickmethod = ''8'' OR PD.Pickmethod = '' '' )'

      SET @c_ExecArguments = N'@c_DataWindow  NVARCHAR(40)'
                           + ',@c_ShowFields  NVARCHAR(MAX)'
                           + ',@c_Wavekey     NVARCHAR(10)'
                           + ',@c_Storerkey   NVARCHAR(15)'
                           + ',@c_Storer_Logo NVARCHAR(60)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_DataWindow
                       , @c_ShowFields
                       , @c_Wavekey
                       , @c_Storerkey
                       , @c_Storer_Logo


      IF ISNULL(@c_PostScript,'')<>''
      BEGIN
         BEGIN TRY
            EXEC sp_ExecuteSql @c_PostScript
                             , @c_ExecArguments
                             , @c_DataWindow
                             , @c_ShowFields
                             , @c_Wavekey
                             , @c_Storerkey
                             , @c_Storer_Logo
            WITH RESULT SETS NONE
         END TRY
         BEGIN CATCH
         END CATCH
      END
   END
   CLOSE C_CUR_STORERKEY
   DEALLOCATE C_CUR_STORERKEY


   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 8 - By Order
   -- Update PickType: 0=New, 1=Reprint
   IF EXISTS(SELECT TOP 1 1
             FROM #TEMP_PIKDT PIKDT
             JOIN dbo.PICKHEADER PH(NOLOCK) ON PIKDT.PickslipNo = PH.PickHeaderkey
             WHERE PH.PickType = '0')
   BEGIN
      BEGIN TRAN

      UPDATE PH WITH(ROWLOCK)
         SET PickType = '1'
           , EditDate = GETDATE()
           , EditWho  = SUSER_SNAME()
           , TrafficCop = NULL
        FROM dbo.PICKHEADER PH
       WHERE PH.PickHeaderkey IN (SELECT DISTINCT PickslipNo FROM #TEMP_PIKDT WHERE PickslipNo<>'')
         AND PH.PickType = '0'

      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         IF @@TRANCOUNT >= 1
         BEGIN
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT > 0
            COMMIT TRAN
         ELSE
         BEGIN
            SELECT @n_continue = 3
            ROLLBACK TRAN
            GOTO QUIT
         END
      END
   END


   SELECT Wavekey            = UPPER( PIKDT.Wavekey )
        , Storerkey          = UPPER( PIKDT.Storerkey )
        , StorerCompany      = MAX( PIKDT.StorerCompany )
        , PickSlipNo         = UPPER( PIKDT.PickSlipNo )
        , OrderKey           = UPPER( PIKDT.OrderKey )
        , ExternOrderKey     = MAX( PIKDT.ExternOrderKey )
        , ExternPOKey        = MAX( PIKDT.ExternPOKey )
        , BuyerPO            = MAX( PIKDT.BuyerPO )
        , InvoiceNo          = MAX( PIKDT.InvoiceNo )
        , DeliveryDate       = MAX( PIKDT.DeliveryDate )
        , ConsigneeKey       = UPPER( MAX( PIKDT.ConsigneeKey ) )
        , Company            = MAX( PIKDT.Company )
        , Addr1              = MAX( PIKDT.Addr1 )
        , Addr2              = MAX( PIKDT.Addr2 )
        , Addr3              = MAX( PIKDT.Addr3 )
        , PostCode           = MAX( PIKDT.PostCode )
        , Route              = MAX( PIKDT.Route )
        , Route_Desc         = MAX( PIKDT.Route_Desc )
        , TrfRoom            = MAX( PIKDT.TrfRoom )
        , PrintedFlag        = MAX( PIKDT.PrintedFlag )
        , LabelPrice         = MAX( PIKDT.LabelPrice )
        , PendingFlag        = MAX( PIKDT.PendingFlag )
        , Notes1             = MAX( PIKDT.Notes1 )
        , Notes2             = MAX( PIKDT.Notes2 )
        , SKU                = UPPER( PIKDT.SKU )
        , SkuDesc            = MAX( PIKDT.SkuDesc )
        , Putawayzone        = UPPER( MAX( PIKDT.Putawayzone ) )
        , ZoneDesc           = MAX( PIKDT.ZoneDesc )
        , LogicalLocation    = UPPER( MAX( PIKDT.LogicalLocation ) )
        , LOC                = UPPER( PIKDT.LOC )
        , ID                 = UPPER( PIKDT.ID )
        , AltSKU             = MAX( PIKDT.AltSKU )
        , SUSR2              = MAX( PIKDT.SUSR2 )
        , BUSR8              = MAX( PIKDT.BUSR8 )
        , BUSR10             = UPPER( MAX( PIKDT.BUSR10 ) )
        , Lottable01         = UPPER( PIKDT.Lottable01 )
        , Lottable02         = UPPER( PIKDT.Lottable02 )
        , Lottable03         = UPPER( PIKDT.Lottable03 )
        , Lottable04         = PIKDT.Lottable04
        , Qty                = SUM( PIKDT.Qty )
        , CaseCnt            = MAX( PIKDT.CaseCnt )
        , InnerPack          = MAX( PIKDT.InnerPack )
        , PackUOM1           = MAX( PIKDT.PackUOM1 )
        , PackUOM2           = MAX( PIKDT.PackUOM2 )
        , PackUOM3           = MAX( PIKDT.PackUOM3 )
        , Cartons            = CASE WHEN SUM(PIKDT.Cartons) IS NOT NULL THEN SUM(PIKDT.Cartons) ELSE
                                  CASE WHEN ISNULL(MAX(PIKDT.CaseCnt  ),0)=0 THEN 0 ELSE FLOOR(SUM(PIKDT.Qty) / MAX(PIKDT.CaseCnt)) END
                               END
        , Inners             = CASE WHEN SUM(PIKDT.Inners) IS NOT NULL THEN SUM(PIKDT.Inners) ELSE
                                  CASE WHEN ISNULL(MAX(PIKDT.InnerPack),0)=0 THEN 0 ELSE FLOOR( IIF(ISNULL(MAX(PIKDT.CaseCnt),0)=0, SUM(PIKDT.Qty), SUM(PIKDT.Qty) % MAX(PIKDT.CaseCnt)) / MAX(PIKDT.InnerPack)) END
                               END
        , Pieces             = CASE WHEN SUM(PIKDT.Pieces) IS NOT NULL THEN SUM(PIKDT.Pieces) ELSE
                                  CASE WHEN ISNULL(MAX(PIKDT.InnerPack),0)=0 THEN IIF(ISNULL(MAX(PIKDT.CaseCnt),0)=0, SUM(PIKDT.Qty), SUM(PIKDT.Qty) % MAX(PIKDT.CaseCnt))
                                                                      ELSE IIF(ISNULL(MAX(PIKDT.CaseCnt),0)=0, SUM(PIKDT.Qty), SUM(PIKDT.Qty) % MAX(PIKDT.CaseCnt)) % MAX(PIKDT.InnerPack) END
                               END
        , StdCube            = MAX( PIKDT.StdCube )
        , StdGrossWgt        = MAX( PIKDT.StdGrossWgt )
        , DCC                = PIKDT.DCC
        , LineRemark1        = PIKDT.LineRemark1
        , LineRemark2        = PIKDT.LineRemark2
        , LineRemark3        = PIKDT.LineRemark3
        , DWName             = MAX( PIKDT.DWName )
        , ShowFields         = MAX( PIKDT.ShowFields )
        , Storer_Logo        = MAX( PIKDT.Storer_Logo )
        , Lbl_Customer       = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Customer') ) AS NVARCHAR(50))
        , Lbl_InvoiceNo      = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_InvoiceNo') ) AS NVARCHAR(50))
        , Lbl_ExternOrderkey = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ExternOrderkey') ) AS NVARCHAR(50))
        , Lbl_ExternPOKey    = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ExternPOKey') ) AS NVARCHAR(50))
        , Lbl_Notes1         = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Notes1') ) AS NVARCHAR(50))
        , Lbl_Notes2         = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Notes2') ) AS NVARCHAR(50))
        , Lbl_SUSR2          = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_SUSR2') ) AS NVARCHAR(50))
        , Lbl_DeliveryDate   = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate') ) AS NVARCHAR(50))
        , Lbl_PendingFlag    = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PendingFlag') ) AS NVARCHAR(50))
        , Lbl_Route          = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Route') ) AS NVARCHAR(50))
        , Lbl_TrfRoom        = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_TrfRoom') ) AS NVARCHAR(50))
        , Lbl_BuyerPO        = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_BuyerPO') ) AS NVARCHAR(50))
        , Lbl_CBM            = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CBM') ) AS NVARCHAR(50))
        , Lbl_Weight         = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Weight') ) AS NVARCHAR(50))
        , Lbl_Loc            = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Loc') ) AS NVARCHAR(50))
        , Lbl_Sku            = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Sku') ) AS NVARCHAR(50))
        , Lbl_SkuDescr       = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_SkuDescr') ) AS NVARCHAR(50))
        , Lbl_AltSku         = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_AltSku') ) AS NVARCHAR(50))
        , Lbl_DCC            = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_DCC') ) AS NVARCHAR(50))
        , Lbl_BUSR8          = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_BUSR8') ) AS NVARCHAR(50))
        , Lbl_Lottable01     = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Lottable01') ) AS NVARCHAR(50))
        , Lbl_Lottable02     = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Lottable02') ) AS NVARCHAR(50))
        , Lbl_Lottable03     = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Lottable03') ) AS NVARCHAR(50))
        , Lbl_Lottable04     = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_Lottable04') ) AS NVARCHAR(50))
        , Lbl_ID             = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_ID') ) AS NVARCHAR(50))
        , Lbl_CaseCnt        = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CaseCnt') ) AS NVARCHAR(50))
        , Lbl_InnerPack      = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_InnerPack') ) AS NVARCHAR(50))
        , Lbl_PackUOM1       = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PackUOM1') ) AS NVARCHAR(50))
        , Lbl_PackUOM2       = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PackUOM2') ) AS NVARCHAR(50))
        , Lbl_PackUOM3       = CAST( RTRIM( (select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_PackUOM3') ) AS NVARCHAR(50))
        , OrderType          = MAX( PIKDT.OrderType )

   FROM #TEMP_PIKDT PIKDT

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=PIKDT.Storerkey AND RptCfg3.SeqNo=1

   GROUP BY PIKDT.Wavekey
          , PIKDT.Storerkey
          , PIKDT.PickSlipNo
          , PIKDT.OrderKey
          , PIKDT.SKU
          , PIKDT.LOC
          , PIKDT.ID
          , PIKDT.Lottable01
          , PIKDT.Lottable02
          , PIKDT.Lottable03
          , PIKDT.Lottable04
          , PIKDT.DCC
          , PIKDT.LineRemark1
          , PIKDT.LineRemark2
          , PIKDT.LineRemark3
    ORDER BY Orderkey, ZoneDesc, LogicalLocation, Loc

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_r_hk_print_wave_pickslip_03'
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