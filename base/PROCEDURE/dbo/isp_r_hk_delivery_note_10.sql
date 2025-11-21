SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Stored Procedure: isp_r_hk_delivery_note_10                              */
/* Creation Date: 13-Mar-2019                                               */
/* Copyright: LFL                                                           */
/* Written by: Michael Lam (HK LIT)                                         */
/*                                                                          */
/* Purpose: Delivery note                                                   */
/*                                                                          */
/* Called By: Report Module. Datawidnow r_hk_delivery_note_10               */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 7.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author   Ver  Purposes                                      */
/* 23/06/2020   ML       1.1  Add Total_Doc_Amount                          */
/* 08/07/2020   ML       1.2  Add new fields                                */
/* 01/09/2020   ML       1.3  Remvoe non-necessary join to PACKHEADER       */
/*                            when inserting discrete #TEMP_FINALORDERKEY   */
/* 29/11/2021   ML       1.4  WMS-18469 Add                                 */
/*      1 MapField:  DeliveryDate, LineRef4-9, Currency                     */
/*      2 MapValue:  T_LineRef4-9, T_Signature, T_CompanyStamp,             */
/*                   N_*_LineRef4-9, N_Width_Currency, N_*_Signature,       */
/*                   N_*_CompanyStamp, N_Height_LineHeading                 */
/*      3 ShowField: LineRef4-9, Signature, CompanyStamp, AllowOrderStatus<5*/
/* 23/03/2022   ML       1.5  Add NULL to Temp Table                        */
/* 28/11/2022   ML       1.6  Fix decimal Qty issue                         */
/****************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_delivery_note_10] (
       @as_storerkey       NVARCHAR(15)
     , @as_wavekey         NVARCHAR(10)
     , @as_loadkey         NVARCHAR(10)
     , @as_pickslipno      NVARCHAR(4000)
     , @as_externorderkey  NVARCHAR(4000)
     , @as_orderkey        NVARCHAR(4000)
     , @as_sortbyinputseq  NVARCHAR(10) = 'Y'
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPFIELD]
      BrandLogoCode, ReportTitle, SplitPrintKey, DeliveryDate, DocNumber, ExternOrderkey, LFLRefNo, ReferenceNo,
      ReferenceNo2, ReferenceNo3, ReferenceNo4, ReferenceNo5, Remark,
      BilltoKey, B_Company, B_Address, B_Phone, B_Fax, B_Contact, Consigneekey, C_Company, C_Address, C_Phone, C_Fax, C_Contact
      LineGrouping, OrderLineNo, Descr, LineRemark, LineRef1, LineRef2, LineRef3, LineRef4, LineRef5, LineRef6, LineRef7, LineRef8, LineRef9
      Qty, UOM, Unitprice, Discount, Amount, GrossAmount, Currency
      ShowField, ConsigneePrefix
   [MAPVALUE]
      T_CopyDescr, T_ReportTitle, T_BillTo, T_B_Phone, T_ShipTo, T_C_Phone,
      T_DeliveryDate, T_DocNumber, T_LFLRefNo, T_ReferenceNo, T_ReferenceNo2, T_ReferenceNo3, T_ReferenceNo4, T_ReferenceNo5, T_Remark,
      T_LineNo, T_Sku, T_Descr, T_LineRemark, T_LineRef1, T_LineRef2, T_LineRef3, T_LineRef4, T_LineRef5, T_LineRef6, T_LineRef7, T_LineRef8, T_LineRef9
      T_Qty, T_UOM, T_UnitPrice, T_PriceFormat, T_Discount, T_Amount, T_GrossAmount, T_TotalQty, T_TotalAmount, T_TotalCarton,
      T_ReceivedBy, T_Signature, T_CompanyStamp, T_TermsNCond1, T_TermsNCond2,
      N_Xpos1, N_Xpos_S_Company, N_Xpos_Remark
      N_Xpos_LineNo, N_Xpos_Sku, N_Xpos_Descr, N_Xpos_LineRemark, N_Xpos_LineRef1, N_Xpos_LineRef2, N_Xpos_LineRef3,
      N_Xpos_LineRef4, N_Xpos_LineRef5, N_Xpos_LineRef6, N_Xpos_LineRef7, N_Xpos_LineRef8, N_Xpos_LineRef9,
      N_Xpos_Qty, N_Xpos_UOM, N_Xpos_UnitPrice, N_Xpos_Discount, N_Xpos_Amount, N_Xpos_GrossAmount,
      N_Xpos_TermsNCond1, N_Xpos_TermsNCond2, N_Xpos_ReceivedBy, N_Xpos_Signature, N_Xpos_CompanyStamp, N_Xpos_TotalQty, N_Xpos_TotalAmount,
      N_Ypos_LineRef1, N_Ypos_LineRef2, N_Ypos_LineRef3, N_Ypos_LineRef4, N_Ypos_LineRef5, N_Ypos_LineRef6, N_Ypos_LineRef7, N_Ypos_LineRef8, N_Ypos_LineRef9
      N_Ypos_TermsNCond1, N_Ypos_TermsNCond2, N_Ypos_ReceivedBy, N_Ypos_Signature, N_Ypos_CompanyStamp,
      N_Width_S_Company, N_Width_Remark
      N_Width_LineNo, N_Width_Sku, N_Width_Descr, N_Width_LineRemark, N_Width_LineRef1, N_Width_LineRef2, N_Width_LineRef3,
      N_Width_LineRef4, N_Width_LineRef5, N_Width_LineRef6, N_Width_LineRef7, N_Width_LineRef8, N_Width_LineRef9
      N_Width_Qty, N_Width_UOM, N_Width_UnitPrice, N_Width_Discount, N_Width_Amount, N_Width_GrossAmount, N_Width_Currency
      N_Width_TermsNCond1, N_Width_TermsNCond2, N_Width_ReceivedBy, N_Width_Signature, N_Width_CompanyStamp, N_Width_TotalQty, N_Width_TotalAmount
   [SHOWFIELD]
      UseLFLogo, UseCode39, UsePackDetail,
      Storer_B_ComAddr, AddressDirectConcate, City, State, Zip, Fax, Contact, Country, OrderType,
      ReferenceNo, ReferenceNo2, ReferenceNo3, ReferenceNo4, ReferenceNo5,
      ChineseDescr, LineRef1, LineRef2, LineRef3, LineRef4, LineRef5, LineRef6, LineRef7, LineRef8, LineRef9
      LineRemark, ChineseLineRemark, UnitPrice, Discount, Amount, GrossAmount, TotalAmount,
      Signature, CompanyStamp
      HidePrintDate, HidePageNo, HideBarcode, HideLFLRefNo, HideStorerCompany, HideStorerAddress, HideBillToKey, HideBillToCompany, HideBillToAddress, HideBillToPhone,
      HideConsigneeKey, HideShipToCompany, HideShipToAddress, HideShipToPhone, HideAddress4, HideC_Phone1, HideRemark, HideDeliveryDate, HideDocNumber,
      HideLineNo, HideSku, HideDescr, HideUOM, HideTotalQty, HideTotalCarton, HideReceivedBy, HideDataWindowName,
      Remark_SFont, Dethdr_SFont, Dethdr_SFont2, Dethdr_SFont3, Detline_SFont, Detline_SFont2, Detline_SFont3, Detftr_SFont, Detftr_SFont2, Detftr_SFont3, Descr_SFont,
      TermsNCond1_Bold, TermsNCond1_Italic, TermsNCond2_Bold, TermsNCond2_Italic,
      LineGrouping_Separateline,
      BoldDeliveryDate, BoldDocNumber, BoldLFLRefNo, BoldReferenceNo, BoldReferenceNo2, BoldReferenceNo3, BoldReferenceNo4, BoldReferenceNo5,
      PrintByOrder, WaterMark, DescrAutoHeight, LineRemarkAutoHeight, SumAmount, Total_Doc_Amount, AllowOrderStatus<5
   [SQLJOIN]
*/

   IF LEN(@as_storerkey)=10 AND @as_storerkey LIKE 'P[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.PACKHEADER (NOLOCK) WHERE PickslipNo=@as_storerkey)
      BEGIN
         SET    @as_pickslipno     = @as_storerkey
         SELECT @as_storerkey      = CHAR(9)
              , @as_wavekey        = ''
              , @as_loadkey        = ''
              , @as_externorderkey = ''
              , @as_orderkey       = ''
              , @as_sortbyinputseq = ''
      END
   END
   ELSE IF LEN(@as_storerkey)=10 AND @as_storerkey LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
   BEGIN
      IF EXISTS(SELECT 1 FROM dbo.WAVE (NOLOCK) WHERE Wavekey=@as_storerkey)
      BEGIN
         SET    @as_wavekey        = @as_storerkey
         SELECT @as_storerkey      = CHAR(9)
              , @as_loadkey        = ''
              , @as_pickslipno     = ''
              , @as_externorderkey = ''
              , @as_orderkey       = ''
              , @as_sortbyinputseq = ''
      END
      ELSE IF EXISTS(SELECT 1 FROM dbo.LOADPLAN (NOLOCK) WHERE Loadkey=@as_storerkey)
      BEGIN
         SET    @as_loadkey        = @as_storerkey
         SELECT @as_storerkey      = CHAR(9)
              , @as_wavekey        = ''
              , @as_pickslipno     = ''
              , @as_externorderkey = ''
              , @as_orderkey       = ''
              , @as_sortbyinputseq = ''
      END
   END

   IF OBJECT_ID('tempdb..#TEMP_PICKSLIPNO') IS NOT NULL
      DROP TABLE #TEMP_PICKSLIPNO
   IF OBJECT_ID('tempdb..#TEMP_ORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_ORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_EXTERNORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_EXTERNORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_FINALORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_FINALORDERKEY
   IF OBJECT_ID('tempdb..#TEMP_FINALPICKSLIPNO') IS NOT NULL
      DROP TABLE #TEMP_FINALPICKSLIPNO
   IF OBJECT_ID('tempdb..#TEMP_ORDERLINENUMBER') IS NOT NULL
      DROP TABLE #TEMP_ORDERLINENUMBER
   IF OBJECT_ID('tempdb..#TEMP_ORDET') IS NOT NULL
      DROP TABLE #TEMP_ORDET
   IF OBJECT_ID('tempdb..#TEMP_SSEQ') IS NOT NULL
      DROP TABLE #TEMP_SSEQ
   IF OBJECT_ID('tempdb..#TEMP_PAK') IS NOT NULL
      DROP TABLE #TEMP_PAK
   IF OBJECT_ID('tempdb..#TEMP_COPYDESCR') IS NOT NULL
      DROP TABLE #TEMP_COPYDESCR

   DECLARE @c_DataWidnow         NVARCHAR(40)
         , @c_BRAND_Logo_CodeExp NVARCHAR(MAX)
         , @c_ReportTitleExp     NVARCHAR(MAX)
         , @c_SplitPrintKeyExp   NVARCHAR(MAX)
         , @c_DeliveryDateExp    NVARCHAR(MAX)
         , @c_DocNumberExp       NVARCHAR(MAX)
         , @c_ExternOrderkeyExp  NVARCHAR(MAX)
         , @c_LFLRefNoExp        NVARCHAR(MAX)
         , @c_ReferenceNoExp     NVARCHAR(MAX)
         , @c_ReferenceNo2Exp    NVARCHAR(MAX)
         , @c_ReferenceNo3Exp    NVARCHAR(MAX)
         , @c_ReferenceNo4Exp    NVARCHAR(MAX)
         , @c_ReferenceNo5Exp    NVARCHAR(MAX)
         , @c_RemarkExp          NVARCHAR(MAX)
         , @c_BilltoKeyExp       NVARCHAR(MAX)
         , @c_B_CompanyExp       NVARCHAR(MAX)
         , @c_B_AddressExp       NVARCHAR(MAX)
         , @c_B_PhoneExp         NVARCHAR(MAX)
         , @c_B_FaxExp           NVARCHAR(MAX)
         , @c_B_ContactExp       NVARCHAR(MAX)
         , @c_ConsigneekeyExp    NVARCHAR(MAX)
         , @c_C_CompanyExp       NVARCHAR(MAX)
         , @c_C_AddressExp       NVARCHAR(MAX)
         , @c_C_PhoneExp         NVARCHAR(MAX)
         , @c_C_FaxExp           NVARCHAR(MAX)
         , @c_C_ContactExp       NVARCHAR(MAX)
         , @c_LineGroupingExp    NVARCHAR(MAX)
         , @c_DescrExp           NVARCHAR(MAX)
         , @c_LineRemarkExp      NVARCHAR(MAX)
         , @c_LineRef1Exp        NVARCHAR(MAX)
         , @c_LineRef2Exp        NVARCHAR(MAX)
         , @c_LineRef3Exp        NVARCHAR(MAX)
         , @c_LineRef4Exp        NVARCHAR(MAX)
         , @c_LineRef5Exp        NVARCHAR(MAX)
         , @c_LineRef6Exp        NVARCHAR(MAX)
         , @c_LineRef7Exp        NVARCHAR(MAX)
         , @c_LineRef8Exp        NVARCHAR(MAX)
         , @c_LineRef9Exp        NVARCHAR(MAX)
         , @c_UnitpriceExp       NVARCHAR(MAX)
         , @c_QtyExp             NVARCHAR(MAX)
         , @c_UOMExp             NVARCHAR(MAX)
         , @c_DiscountExp        NVARCHAR(MAX)
         , @c_AmountExp          NVARCHAR(MAX)
         , @c_GrossAmountExp     NVARCHAR(MAX)
         , @c_CurrencyExp        NVARCHAR(MAX)
         , @c_ShowFieldExp       NVARCHAR(MAX)
         , @c_OrderLineNoExp     NVARCHAR(MAX)
         , @c_ConsigneePrefix    NVARCHAR(15)
         , @c_CopyDescr          NVARCHAR(MAX)
         , @c_Storerkey          NVARCHAR(15)
         , @n_PickslipNoCnt      INT
         , @n_OrderkeyCnt        INT
         , @n_ExternOrderkeyCnt  INT
         , @b_UsePackDetail      INT
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(MAX)


   SELECT @c_DataWidnow = 'r_hk_delivery_note_10'

   CREATE TABLE #TEMP_ORDET (
        Orderkey         NVARCHAR(10)   NULL
      , Storerkey        NVARCHAR(15)   NULL
      , ReportTitle      NVARCHAR(500)  NULL
      , SplitPrintKey    NVARCHAR(500)  NULL
      , DeliveryDate     NVARCHAR(500)  NULL
      , DocNumber        NVARCHAR(500)  NULL
      , ExternOrderkey   NVARCHAR(500)  NULL
      , LFLRefNo         NVARCHAR(500)  NULL
      , ReferenceNo      NVARCHAR(500)  NULL
      , ReferenceNo2     NVARCHAR(500)  NULL
      , ReferenceNo3     NVARCHAR(500)  NULL
      , ReferenceNo4     NVARCHAR(500)  NULL
      , ReferenceNo5     NVARCHAR(500)  NULL
      , Remark           NVARCHAR(500)  NULL
      , PickSlipNo       NVARCHAR(10)   NULL
      , BilltoKey        NVARCHAR(4000) NULL
      , B_Company        NVARCHAR(4000) NULL
      , B_Address        NVARCHAR(4000) NULL
      , B_Phone          NVARCHAR(4000) NULL
      , B_Fax            NVARCHAR(4000) NULL
      , B_Contact        NVARCHAR(4000) NULL
      , Consigneekey     NVARChAR(4000) NULL
      , C_Company        NVARCHAR(4000) NULL
      , C_Address        NVARCHAR(4000) NULL
      , C_Phone          NVARCHAR(4000) NULL
      , C_Fax            NVARCHAR(4000) NULL
      , C_Contact        NVARCHAR(4000) NULL
      , LineGrouping     NVARCHAR(500)  NULL
      , OrderLineNumber  NVARCHAR(5 )   NULL
      , Sku              NVARCHAR(20)   NULL
      , Descr            NVARCHAR(500)  NULL
      , LineRemark       NVARCHAR(500)  NULL
      , LineRef1         NVARCHAR(500)  NULL
      , LineRef2         NVARCHAR(500)  NULL
      , LineRef3         NVARCHAR(500)  NULL
      , LineRef4         NVARCHAR(500)  NULL
      , LineRef5         NVARCHAR(500)  NULL
      , LineRef6         NVARCHAR(500)  NULL
      , LineRef7         NVARCHAR(500)  NULL
      , LineRef8         NVARCHAR(500)  NULL
      , LineRef9         NVARCHAR(500)  NULL
      , Unitprice        MONEY          NULL
      , Qty              FLOAT          NULL
      , Discount         FLOAT          NULL
      , Amount           MONEY          NULL
      , GrossAmount      MONEY          NULL
      , Currency         NVARCHAR(500)  NULL
      , ShowField        NVARCHAR(4000) NULL
      , UOM              NVARCHAR(10)   NULL
      , ConsigneePrefix  NVARCHAR(15)   NULL
      , BRAND_Logo_Code  NVARCHAR(500)  NULL
      , ConsolPick       NVARCHAR(1)    NULL
      , DocKey           NVARCHAR(10)   NULL
      , FirstOrderkey    NVARCHAR(10)   NULL
      , OrderLineNo      NVARCHAR(500)  NULL
   )

   CREATE TABLE #TEMP_COPYDESCR (
        Copies           INT
      , CopyDescr        NVARCHAR(4000) NULL
      , Storerkey        NVARCHAR(15)   NULL
   )


   -- PickslipNo List
   SELECT SeqNo    = MIN(SeqNo)
        , ColValue = LTRIM(RTRIM(ColValue))
     INTO #TEMP_PICKSLIPNO
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_pickslipno,CHAR(13)+CHAR(10),','))
    WHERE ColValue<>''
    GROUP BY LTRIM(RTRIM(ColValue))

   SET @n_PickslipNoCnt = @@ROWCOUNT

   -- ExternOrderkey List
   SELECT SeqNo    = MIN(SeqNo)
        , ColValue = LTRIM(RTRIM(ColValue))
     INTO #TEMP_EXTERNORDERKEY
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_externorderkey,CHAR(13)+CHAR(10),','))
    WHERE ColValue<>''
    GROUP BY LTRIM(RTRIM(ColValue))

   SET @n_ExternOrderkeyCnt = @@ROWCOUNT

   -- Orderkey List
   SELECT SeqNo    = MIN(SeqNo)
        , ColValue = LTRIM(RTRIM(ColValue))
     INTO #TEMP_ORDERKEY
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_orderkey,CHAR(13)+CHAR(10),','))
    WHERE ColValue<>''
    GROUP BY LTRIM(RTRIM(ColValue))

   SET @n_OrderkeyCnt = @@ROWCOUNT


   -- Final Orderkey, PickslipNo List
   CREATE TABLE #TEMP_FINALORDERKEY (
        Orderkey         NVARCHAR(10)  NULL
      , PickslipNo       NVARCHAR(10)  NULL
      , Loadkey          NVARCHAR(10)  NULL
      , ConsolPick       NVARCHAR(1)   NULL
      , DocKey           NVARCHAR(10)  NULL
      , Storerkey        NVARCHAR(15)  NULL
   )
   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        + ',@as_wavekey NVARCHAR(10)'
                        + ',@as_loadkey NVARCHAR(10)'
                        + ',@c_DataWidnow NVARCHAR(40)'

   -- Discrete Orders
   SET @c_ExecStatements = N'INSERT INTO #TEMP_FINALORDERKEY'
                         + ' SELECT Orderkey   = OH.Orderkey'
                         +       ', PickslipNo = MAX( PIKHD.PickheaderKey )'
                         +       ', Loadkey    = MAX( OH.Loadkey )'
                         +       ', ConsolPick = ''N'''
                         +       ', DocKey     = MAX( OH.Orderkey )'
                         +       ', Storerkey  = MAX( OH.Storerkey )'
                         +   ' FROM dbo.ORDERS        OH (NOLOCK)'
                         +   ' JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Orderkey = PIKHD.Orderkey AND OH.Orderkey<>'''''
                         +   ' LEFT JOIN ('
                         +      ' SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))'
                         +            ', SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'
                         +        ' FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''SHOWFIELD'' AND Long=@c_DataWidnow AND Short=''Y'''
                         +   ' ) RptCfg ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1'
                         +  ' WHERE OH.Status >= CASE WHEN RptCfg.ShowFields LIKE ''%,AllowOrderStatus<5,%'' THEN ''0'' ELSE ''5'' END AND OH.Status <= ''9'''

   IF (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'' OR @n_PickslipNoCnt>0 OR @n_ExternOrderkeyCnt>0 OR @n_OrderkeyCnt>0)
   BEGIN
      IF ISNULL(@as_storerkey,'')<>CHAR(9) AND ISNULL(@as_storerkey,'')<>''
         SET @c_ExecStatements += ' AND OH.Storerkey = @as_storerkey'
      IF ISNULL(@as_wavekey,'')<>''
         SET @c_ExecStatements += ' AND OH.Userdefine09 = @as_wavekey'
      IF ISNULL(@as_loadkey,'')<>''
         SET @c_ExecStatements += ' AND OH.LoadKey = @as_loadkey'
      IF @n_PickslipNoCnt>0
         SET @c_ExecStatements += ' AND PIKHD.PickheaderKey IN (SELECT ColValue FROM #TEMP_PICKSLIPNO)'
      IF @n_ExternOrderkeyCnt>0
         SET @c_ExecStatements += ' AND OH.ExternOrderKey IN (SELECT ColValue FROM #TEMP_EXTERNORDERKEY)'
      IF @n_OrderkeyCnt>0
         SET @c_ExecStatements += ' AND OH.OrderKey IN (SELECT ColValue FROM #TEMP_ORDERKEY)'
   END
   ELSE
   BEGIN
      SET @c_ExecStatements += ' AND (1=2)'
   END
   SET @c_ExecStatements += ' GROUP BY OH.Orderkey'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_wavekey
                    , @as_loadkey
                    , @c_DataWidnow

   -- Consol Orders
   SET @c_ExecStatements = N'INSERT INTO #TEMP_FINALORDERKEY'
                         + ' SELECT Orderkey   = OH.Orderkey'
                         +       ', PickslipNo = MAX( PIKHD.PickheaderKey )'
                         +       ', Loadkey    = MAX( OH.Loadkey )'
                         +       ', ConsolPick = MAX( CASE WHEN RptCfg.ShowFields LIKE ''%,PrintByOrder,%'' OR ISNULL(OH.Userdefine09,'''')='''' THEN ''N'' ELSE ''Y'' END )'
                         +       ', DocKey     = MAX( CASE WHEN RptCfg.ShowFields LIKE ''%,PrintByOrder,%'' OR ISNULL(OH.Userdefine09,'''')='''' THEN OH.Orderkey ELSE OH.Loadkey END )'
                         +       ', Storerkey  = MAX( OH.Storerkey )'
                         +   ' FROM dbo.ORDERS        OH (NOLOCK)'
                         +   ' JOIN dbo.PICKHEADER PIKHD (NOLOCK) ON OH.Loadkey = PIKHD.ExternOrderkey AND ISNULL(PIKHD.Orderkey,'''')='''''
                         +   ' LEFT JOIN #TEMP_FINALORDERKEY  FOK ON OH.Orderkey = FOK.Orderkey'
                         +   ' LEFT JOIN ('
                         +      ' SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))'
                         +            ', SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'
                         +        ' FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''SHOWFIELD'' AND Long=@c_DataWidnow AND Short=''Y'''
                         +   ' ) RptCfg ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1'
                         +  ' WHERE OH.Status >= CASE WHEN RptCfg.ShowFields LIKE ''%,AllowOrderStatus<5,%'' THEN ''0'' ELSE ''5'' END AND OH.Status <= ''9'''
                         +    ' AND OH.Loadkey<>'''''
                         +    ' AND FOK.Orderkey IS NULL'
   IF (ISNULL(@as_wavekey,'')<>'' OR ISNULL(@as_loadkey,'')<>'' OR @n_PickslipNoCnt>0 OR @n_ExternOrderkeyCnt>0 OR @n_OrderkeyCnt>0)
   BEGIN
      IF ISNULL(@as_storerkey,'')<>CHAR(9) AND ISNULL(@as_storerkey,'')<>''
         SET @c_ExecStatements += ' AND OH.Storerkey = @as_storerkey'
      IF ISNULL(@as_wavekey,'')<>''
         SET @c_ExecStatements += ' AND OH.Userdefine09 = @as_wavekey'
      IF ISNULL(@as_loadkey,'')<>''
         SET @c_ExecStatements += ' AND OH.LoadKey = @as_loadkey'
      IF @n_PickslipNoCnt>0
         SET @c_ExecStatements += ' AND PIKHD.PickheaderKey IN (SELECT ColValue FROM #TEMP_PICKSLIPNO)'
      IF @n_ExternOrderkeyCnt>0
         SET @c_ExecStatements += ' AND OH.ExternOrderKey IN (SELECT ColValue FROM #TEMP_EXTERNORDERKEY)'
      IF @n_OrderkeyCnt>0
         SET @c_ExecStatements += ' AND OH.OrderKey IN (SELECT ColValue FROM #TEMP_ORDERKEY)'
   END
   ELSE
   BEGIN
      SET @c_ExecStatements += ' AND (1=2)'
   END
   SET @c_ExecStatements += ' GROUP BY OH.Orderkey'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_wavekey
                    , @as_loadkey
                    , @c_DataWidnow

   SELECT DISTINCT
          PickslipNo     = FOK.PickslipNo
        , DocKey         = FOK.DocKey
        , Loadkey        = FOK.Loadkey
        , ConsolPick     = FOK.ConsolPick
        , Orderkey       = FIRST_VALUE(FOK.Orderkey) OVER(PARTITION BY FOK.DocKey ORDER BY FOK.Orderkey)
     INTO #TEMP_FINALPICKSLIPNO
     FROM #TEMP_FINALORDERKEY FOK


   SELECT DocKey          = X.DocKey
        , Storerkey       = X.Storerkey
        , Sku             = X.Sku
        , Orderkey        = LEFT(X.Sourcekey,10)
        , OrderLineNumber = SUBSTRING(X.Sourcekey,11,5)
     INTO #TEMP_ORDERLINENUMBER
     FROM (
      SELECT FOK.DocKey, OD.Storerkey, OD.Sku, Sourcekey=MIN(LEFT(OD.Orderkey+SPACE(10),10)+OD.OrderLineNumber)
        FROM #TEMP_FINALORDERKEY FOK
        JOIN ORDERDETAIL OD(NOLOCK) ON FOK.Orderkey=OD.Orderkey
       GROUP BY FOK.DocKey, OD.Storerkey, OD.Sku
     ) X


   -- Storerkey Loop
   DECLARE C_STORERKEY CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Storerkey
     FROM #TEMP_FINALORDERKEY
    ORDER BY 1

   OPEN C_STORERKEY

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_STORERKEY
       INTO @c_Storerkey

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT @c_BRAND_Logo_CodeExp = ''
           , @c_ReportTitleExp     = ''
           , @c_SplitPrintKeyExp   = ''
           , @c_DeliveryDateExp    = ''
           , @c_DocNumberExp       = ''
           , @c_ExternOrderkeyExp  = ''
           , @c_LFLRefNoExp        = ''
           , @c_ReferenceNoExp     = ''
           , @c_ReferenceNo2Exp    = ''
           , @c_ReferenceNo3Exp    = ''
           , @c_ReferenceNo4Exp    = ''
           , @c_ReferenceNo5Exp    = ''
           , @c_RemarkExp          = ''
           , @c_BilltoKeyExp       = ''
           , @c_B_CompanyExp       = ''
           , @c_B_AddressExp       = ''
           , @c_B_PhoneExp         = ''
           , @c_B_FaxExp           = ''
           , @c_B_ContactExp       = ''
           , @c_ConsigneekeyExp    = ''
           , @c_C_CompanyExp       = ''
           , @c_C_AddressExp       = ''
           , @c_C_PhoneExp         = ''
           , @c_C_FaxExp           = ''
           , @c_C_ContactExp       = ''
           , @c_LineGroupingExp    = ''
           , @c_DescrExp           = ''
           , @c_LineRemarkExp      = ''
           , @c_LineRef1Exp        = ''
           , @c_LineRef2Exp        = ''
           , @c_LineRef3Exp        = ''
           , @c_LineRef4Exp        = ''
           , @c_LineRef5Exp        = ''
           , @c_LineRef6Exp        = ''
           , @c_LineRef7Exp        = ''
           , @c_LineRef8Exp        = ''
           , @c_LineRef9Exp        = ''
           , @c_UnitpriceExp       = ''
           , @c_QtyExp             = ''
           , @c_UOMExp             = ''
           , @c_DiscountExp        = ''
           , @c_AmountExp          = ''
           , @c_GrossAmountExp     = ''
           , @c_CurrencyExp        = ''
           , @c_ShowFieldExp       = ''
           , @c_OrderLineNoExp     = ''
           , @c_ConsigneePrefix    = ''
           , @c_CopyDescr          = ''
           , @b_UsePackDetail      = 0
           , @c_JoinClause         = ''

      SELECT TOP 1
             @b_UsePackDetail      = CASE WHEN ','+RTRIM(Notes)+',' LIKE '%,UsePackDetail,%' THEN 1 ELSE 0 END
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_CopyDescr          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CopyDescr')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_JoinClause  = Notes
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SQLJOIN' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_BRAND_Logo_CodeExp = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='BrandLogoCode')), '' )
           , @c_ReportTitleExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReportTitle')), '' )
           , @c_SplitPrintKeyExp   = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SplitPrintKey')), '' )
           , @c_DeliveryDateExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDate')), '' )
           , @c_DocNumberExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='DocNumber')), '' )
           , @c_ExternOrderkeyExp  = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ExternOrderkey')), '' )
           , @c_LFLRefNoExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LFLRefNo')), '' )
           , @c_ReferenceNoExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReferenceNo')), '' )
           , @c_ReferenceNo2Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReferenceNo2')), '' )
           , @c_ReferenceNo3Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReferenceNo3')), '' )
           , @c_ReferenceNo4Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReferenceNo4')), '' )
           , @c_ReferenceNo5Exp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ReferenceNo5')), '' )
           , @c_RemarkExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Remark')), '' )
           , @c_BilltoKeyExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='BilltoKey')), '' )
           , @c_B_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Company')), '' )
           , @c_B_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Address')), '' )
           , @c_B_PhoneExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Phone')), '' )
           , @c_B_FaxExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Fax')), '' )
           , @c_B_ContactExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='B_Contact')), '' )
           , @c_ConsigneekeyExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Consigneekey')), '' )
           , @c_C_CompanyExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Company')), '' )
           , @c_C_AddressExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Address')), '' )
           , @c_C_PhoneExp         = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Phone')), '' )
           , @c_C_FaxExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Fax')), '' )
           , @c_C_ContactExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='C_Contact')), '' )
           , @c_LineGroupingExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineGrouping')), '' )
           , @c_DescrExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Descr')), '' )
           , @c_LineRemarkExp      = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRemark')), '' )
           , @c_LineRef1Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef1')), '' )
           , @c_LineRef2Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef2')), '' )
           , @c_LineRef3Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef3')), '' )
           , @c_LineRef4Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef4')), '' )
           , @c_LineRef5Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef5')), '' )
           , @c_LineRef6Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef6')), '' )
           , @c_LineRef7Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef7')), '' )
           , @c_LineRef8Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef8')), '' )
           , @c_LineRef9Exp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineRef9')), '' )
           , @c_UnitpriceExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Unitprice')), '' )
           , @c_QtyExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Qty')), '' )
           , @c_UOMExp             = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='UOM')), '' )
           , @c_DiscountExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Discount')), '' )
           , @c_AmountExp          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Amount')), '' )
           , @c_GrossAmountExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='GrossAmount')), '' )
           , @c_CurrencyExp        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Currency')), '' )
           , @c_ShowFieldExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShowField')), '' )
           , @c_OrderLineNoExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='OrderLineNo')), '' )
           , @c_ConsigneePrefix    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ConsigneePrefix')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      ----------
      INSERT INTO #TEMP_COPYDESCR (Copies, CopyDescr, Storerkey)
      SELECT SeqNo, ColValue, @c_Storerkey
        FROM dbo.fnc_DelimSplit(LEFT(@c_CopyDescr,1), RTRIM(SUBSTRING(@c_CopyDescr,2,LEN(@c_CopyDescr))) )

      IF @@ROWCOUNT = 0
         INSERT INTO #TEMP_COPYDESCR (Copies, CopyDescr, Storerkey) VALUES(1, '', @c_Storerkey)

      ----------
      SET @c_ExecStatements = N'INSERT INTO #TEMP_ORDET'
          +' (Orderkey, Storerkey, ReportTitle, SplitPrintKey, DeliveryDate, DocNumber, ExternOrderkey, LFLRefNo, ReferenceNo, ReferenceNo2'
          + ', ReferenceNo3, ReferenceNo4, ReferenceNo5, Remark, PickslipNo'
          + ', BilltoKey, B_Company, B_Address, B_Phone, B_Fax, B_Contact, Consigneekey, C_Company, C_Address, C_Phone, C_Fax, C_Contact'
          + ', LineGrouping, OrderLineNumber, Sku, Descr, LineRemark'
          + ', LineRef1, LineRef2, LineRef3, LineRef4, LineRef5, LineRef6, LineRef7, LineRef8, LineRef9'
          + ', Qty, UOM, Unitprice, Discount, Amount, GrossAmount, Currency, ShowField, OrderLineNo'
          + ', ConsigneePrefix, BRAND_Logo_Code, ConsolPick, DocKey, FirstOrderkey)'
          +' SELECT OH.OrderKey'
               + ', OH.Storerkey'
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_ReportTitleExp    ,'')<>'' THEN @c_ReportTitleExp     ELSE 'NULL' END
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SplitPrintKeyExp  ,'')<>'' THEN @c_SplitPrintKeyExp   ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DeliveryDateExp   ,'')<>'' THEN @c_DeliveryDateExp    ELSE 'CONVERT(NVARCHAR(10),OH.DeliveryDate,120)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocNumberExp      ,'')<>'' THEN @c_DocNumberExp       ELSE 'UPPER(IIF(FOK.ConsolPick=''Y'',FOK.DocKey,OH.ExternOrderkey))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderkeyExp ,'')<>'' THEN @c_ExternOrderkeyExp  ELSE 'UPPER(OH.ExternOrderkey)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LFLRefNoExp       ,'')<>'' THEN @c_LFLRefNoExp        ELSE 'UPPER(IIF(FOK.ConsolPick=''Y'', '''', OH.Orderkey))' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReferenceNoExp    ,'')<>'' THEN @c_ReferenceNoExp     ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReferenceNo2Exp   ,'')<>'' THEN @c_ReferenceNo2Exp    ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReferenceNo3Exp   ,'')<>'' THEN @c_ReferenceNo3Exp    ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReferenceNo4Exp   ,'')<>'' THEN @c_ReferenceNo4Exp    ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ReferenceNo5Exp   ,'')<>'' THEN @c_ReferenceNo5Exp    ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_RemarkExp         ,'')<>'' THEN @c_RemarkExp          ELSE 'ISNULL(LTRIM(RTRIM(OH.Notes)),'''')+'' ''+ISNULL(LTRIM(RTRIM(OH.Notes2)),'''')' END + '),'''')'
               + ', FOK.PickslipNo'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BilltoKeyExp      ,'')<>'' THEN @c_BilltoKeyExp       ELSE 'UPPER(OH.BilltoKey)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_CompanyExp      ,'')<>'' THEN @c_B_CompanyExp       ELSE 'OH.B_Company'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_AddressExp      ,'')<>'' THEN @c_B_AddressExp       ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_PhoneExp        ,'')<>'' THEN @c_B_PhoneExp         ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_FaxExp          ,'')<>'' THEN @c_B_FaxExp           ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_B_ContactExp      ,'')<>'' THEN @c_B_ContactExp       ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ConsigneekeyExp   ,'')<>'' THEN @c_ConsigneekeyExp    ELSE 'UPPER(OH.Consigneekey)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_CompanyExp      ,'')<>'' THEN @c_C_CompanyExp       ELSE 'OH.C_Company'        END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_AddressExp      ,'')<>'' THEN @c_C_AddressExp       ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_PhoneExp        ,'')<>'' THEN @c_C_PhoneExp         ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_FaxExp          ,'')<>'' THEN @c_C_FaxExp           ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_C_ContactExp      ,'')<>'' THEN @c_C_ContactExp       ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineGroupingExp   ,'')<>'' THEN @c_LineGroupingExp    ELSE ''''''                END + '),'''')'
               + ', OD.OrderLineNumber'
               + ', PD.Sku'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DescrExp          ,'')<>'' THEN @c_DescrExp           ELSE 'SKU.DESCR'           END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemarkExp     ,'')<>'' THEN @c_LineRemarkExp      ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef1Exp       ,'')<>'' THEN @c_LineRef1Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef2Exp       ,'')<>'' THEN @c_LineRef2Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef3Exp       ,'')<>'' THEN @c_LineRef3Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef4Exp       ,'')<>'' THEN @c_LineRef4Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef5Exp       ,'')<>'' THEN @c_LineRef5Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef6Exp       ,'')<>'' THEN @c_LineRef6Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef7Exp       ,'')<>'' THEN @c_LineRef7Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef8Exp       ,'')<>'' THEN @c_LineRef8Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef9Exp       ,'')<>'' THEN @c_LineRef9Exp        ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL('       + CASE WHEN ISNULL(@c_QtyExp            ,'')<>'' THEN @c_QtyExp             ELSE 'PD.Qty'              END + ',0)'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UOMExp            ,'')<>'' THEN @c_UOMExp             ELSE 'PACK.PackUOM3'       END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_UnitpriceExp      ,'')<>'' THEN @c_UnitpriceExp       ELSE 'OD.UnitPrice'        END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_DiscountExp       ,'')<>'' THEN @c_DiscountExp        ELSE 'NULL'                END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_AmountExp         ,'')<>'' THEN @c_AmountExp          ELSE 'NULL'                END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_GrossAmountExp    ,'')<>'' THEN @c_GrossAmountExp     ELSE 'NULL'                END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_CurrencyExp       ,'')<>'' THEN @c_CurrencyExp        ELSE 'NULL'                END
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShowFieldExp      ,'')<>'' THEN @c_ShowFieldExp       ELSE ''''''                END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_OrderLineNoExp    ,'')<>'' THEN @c_OrderLineNoExp     ELSE ''''''                END + '),'''')'
               + ', ISNULL(RTRIM(@c_ConsigneePrefix),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BRAND_Logo_CodeExp,'')<>'' THEN @c_BRAND_Logo_CodeExp ELSE ''''''                END + '),'''')'
               + ', FOK.ConsolPick'
               + ', FOK.DocKey'
               + ', FIRST_VALUE(FOK.Orderkey) OVER(PARTITION BY FOK.DocKey ORDER BY FOK.Orderkey)'
          +' FROM dbo.ORDERS      OH (NOLOCK)'
      SET @c_ExecStatements = @c_ExecStatements
          +CASE WHEN @b_UsePackDetail = 1 THEN
              ' JOIN #TEMP_FINALPICKSLIPNO FOK   ON OH.Orderkey=FOK.Orderkey'
             +' JOIN dbo.PACKHEADER  PH (NOLOCK) ON FOK.PickslipNo=PH.PickslipNo'
             +' JOIN dbo.PACKDETAIL  PD (NOLOCK) ON PH.PickslipNo=PD.PickslipNo'
             +' LEFT JOIN #TEMP_ORDERLINENUMBER ORDET ON FOK.DocKey=ORDET.DocKey AND PD.Storerkey=ORDET.Storerkey AND PD.Sku=ORDET.Sku'
             +' LEFT JOIN dbo.ORDERDETAIL OD (NOLOCK) ON ORDET.Orderkey=OD.Orderkey AND ORDET.OrderLineNumber=OD.OrderLineNumber'
           ELSE
              ' JOIN #TEMP_FINALORDERKEY FOK ON OH.Orderkey=FOK.Orderkey'
             +' JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OH.Orderkey=OD.Orderkey'
             +' JOIN dbo.PICKDETAIL  PD (NOLOCK) ON OD.Orderkey=PD.Orderkey AND OD.OrderLineNumber=PD.OrderLineNumber'
           END
          +' JOIN dbo.SKU        SKU (NOLOCK) ON PD.StorerKey=SKU.StorerKey AND PD.Sku=SKU.Sku'
          +' JOIN dbo.PACK      PACK (NOLOCK) ON SKU.Packkey=PACK.Packkey'
      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END
      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE PD.Qty > 0 AND OH.Storerkey=@c_Storerkey'

      SET @c_ExecArguments = N'@c_ConsigneePrefix   NVARCHAR(15)'
                           + ',@c_Storerkey         NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_ConsigneePrefix
                       , @c_Storerkey
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY


   -----------------------
   SELECT DocKey        = FOK.DocKey
        , Total_Carton  = COUNT(DISTINCT PD.LabelNo)
     INTO #TEMP_PAK
     FROM #TEMP_FINALORDERKEY FOK
     JOIN dbo.PACKDETAIL PD ON FOK.PickSlipNo=PD.PickSlipNo
    WHERE PD.Qty>0
    GROUP BY FOK.DocKey


   UPDATE a
      SET LFLRefNo      = b.LFLRefNo
        , ReferenceNo   = b.ReferenceNo
        , ReferenceNo2  = b.ReferenceNo2
        , ReferenceNo3  = b.ReferenceNo3
        , ReferenceNo4  = b.ReferenceNo4
        , ReferenceNo5  = b.ReferenceNo5
        , Remark        = b.Remark
     FROM #TEMP_ORDET a
     JOIN (
        SELECT *, SeqNo = ROW_NUMBER() OVER(PARTITION BY DocKey ORDER BY Orderkey)
          FROM #TEMP_ORDET
     ) b ON a.DocKey = b.DocKey AND b.SeqNo = 1



   ------------------------
   SELECT Storerkey         = UPPER( RTRIM ( ORDET.Storerkey ) )
        , DocKey            = ISNULL( RTRIM( ORDET.DocKey ), '' )
        , Orderkey          = MAX ( RTRIM ( ORDET.Orderkey ) )
        , DocNumber         = MAX ( ISNULL( RTRIM ( ORDET.DocNumber ), '') )
        , Externorderkey    = MAX ( ISNULL( RTRIM ( ORDET.ExternOrderKey ), '') )
        , Loadkey           = MAX ( ISNULL( RTRIM ( OH.Loadkey ), '') )
        , Deliverydate      = MAX ( RTRIM ( ORDET.DeliveryDate ) )
        , ReferenceNo       = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo ), '') )
        , S_Company         = MAX ( ISNULL( RTRIM ( STORER.Company ), '' ) )
        , S_Address1        = MAX ( ISNULL( STORER.Address1, '' ) )
        , S_Address2        = MAX ( ISNULL( STORER.Address2, '' ) )
        , S_Address3        = MAX ( ISNULL( STORER.Address3, '' ) )
        , S_Address4        = MAX ( ISNULL( STORER.Address4, '' ) )
        , S_Phone1          = MAX ( ISNULL( LTRIM(RTRIM(STORER.Phone1)),'' ) )
        , S_Phone2          = MAX ( ISNULL( LTRIM(RTRIM(STORER.Phone2)),'' ) )
        , S_Fax1            = MAX ( ISNULL( LTRIM(RTRIM(STORER.Fax1)), '' ) )
        , S_B_Company       = MAX ( ISNULL( RTRIM ( STORER.B_Company ), '' ) )
        , S_B_Address1      = MAX ( ISNULL( STORER.B_Address1, '' ) )
        , S_B_Address2      = MAX ( ISNULL( STORER.B_Address2, '' ) )
        , S_B_Address3      = MAX ( ISNULL( STORER.B_Address3, '' ) )
        , S_B_Address4      = MAX ( ISNULL( STORER.B_Address4, '' ) )
        , S_B_Phone1        = MAX ( ISNULL( LTRIM(RTRIM(STORER.B_Phone1)),'' ) )
        , S_B_Phone2        = MAX ( ISNULL( LTRIM(RTRIM(STORER.B_Phone2)),'' ) )
        , S_B_Fax1          = MAX ( ISNULL( LTRIM(RTRIM(STORER.B_Fax1)),'' ) )

        , BilltoKey         = RTRIM ( ISNULL( MAX( CASE WHEN LEFT(ORDET.BilltoKey, LEN(ORDET.ConsigneePrefix))=ORDET.ConsigneePrefix
                                           THEN SUBSTRING(ORDET.BilltoKey, LEN(ORDET.ConsigneePrefix)+1, LEN(ORDET.BillToKey))
                                           ELSE ORDET.BilltoKey END ), '' ) )
        , B_Company         = MAX( ISNULL( RTRIM ( ORDET.B_Company ), '') )
        , B_Address1        = MAX( ISNULL( IIF(@c_B_AddressExp<>'',ORDET.B_Address,OH.B_Address1), '' ) )
        , B_Address2        = MAX( ISNULL( IIF(@c_B_AddressExp<>'',''             ,OH.B_Address2), '' ) )
        , B_Address3        = MAX( ISNULL( IIF(@c_B_AddressExp<>'',''             ,OH.B_Address3), '' ) )
        , B_Address4        = MAX( ISNULL( IIF(@c_B_AddressExp<>'',''             ,OH.B_Address4), '' ) )
        , B_Country         = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_AddressExp<>'', ''             , OH.B_Country ) )), '' ) )
        , B_Contact1        = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_ContactExp<>'', ORDET.B_Contact, OH.B_Contact1) )), '' ) )
        , B_Phone1          = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_PhoneExp  <>'', ORDET.B_Phone  , OH.B_Phone1  ) )), '' ) )

        , ConsigneeKey      = RTRIM ( ISNULL( MAX( CASE WHEN LEFT(ORDET.ConsigneeKey, LEN(ORDET.ConsigneePrefix))=ORDET.ConsigneePrefix
                                           THEN SUBSTRING(ORDET.ConsigneeKey, LEN(ORDET.ConsigneePrefix)+1, LEN(ORDET.ConsigneeKey))
                                           ELSE ORDET.ConsigneeKey END ), '' ) )
        , C_Company         = MAX( ISNULL( RTRIM ( ORDET.C_Company ), '') )
        , C_Address1        = MAX( ISNULL( IIF(@c_C_AddressExp<>'', ORDET.C_Address, OH.C_Address1), '' ) )
        , C_Address2        = MAX( ISNULL( IIF(@c_C_AddressExp<>'', ''             , OH.C_Address2), '' ) )
        , C_Address3        = MAX( ISNULL( IIF(@c_C_AddressExp<>'', ''             , OH.C_Address3), '' ) )
        , C_Address4        = MAX( ISNULL( IIF(@c_C_AddressExp<>'', ''             , OH.C_Address4), '' ) )
        , C_Country         = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_AddressExp<>'', ''             , OH.C_Country ) )), '' ) )
        , C_Contact1        = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_ContactExp<>'', ORDET.C_Contact, OH.C_Contact1) )), '' ) )
        , C_Phone1          = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_PhoneExp  <>'', ORDET.C_Phone  , OH.C_Phone1  ) )), '' ) )

        , Notes             = MAX ( ISNULL( RTRIM ( OH.Notes ), '' ) )
        , Notes2            = MAX ( ISNULL( RTRIM ( OH.Notes2 ), '' ) )
        , Total_Carton      = MAX ( PAK.Total_Carton )

        , LineGrouping      = RTRIM ( ORDET.LineGrouping )
        , Line_No           = ROW_NUMBER() OVER(PARTITION BY ORDET.DocKey, COPY.Copies
                              ORDER BY ORDET.LineGrouping, ORDET.OrderLineNo, ORDET.Sku, ORDET.LineRef1, ORDET.LineRef2, ORDET.LineRef3, ORDET.LineRef4, ORDET.LineRef5
                                     , ORDET.LineRef6, ORDET.LineRef7, ORDET.LineRef8, ORDET.LineRef9, ORDET.Unitprice, ORDET.UOM )
        , Sku               = RTRIM ( ORDET.Sku )
        , LineRef1          = RTRIM ( ORDET.LineRef1 )
        , LineRef2          = RTRIM ( ORDET.LineRef2 )
        , LineRef3          = RTRIM ( ORDET.LineRef3 )
        , Descr             = MAX ( RTRIM ( ORDET.Descr ) )
        , Unitprice         = ORDET.Unitprice
        , Qty               = SUM ( ORDET.Qty )
        , UOM               = RTRIM ( ORDET.UOM )
        , Discount          = ORDET.Discount
        , Amount            = CASE WHEN RptCfg.ShowFields LIKE '%,SumAmount,%' THEN 0 ELSE ORDET.Amount END

        , STORER_Logo       = MAX ( RTRIM( CASE WHEN BL.Long<>'' THEN BL.Long ELSE
                                           CASE WHEN RL.Notes<>'' THEN RL.Notes ELSE STORER.Logo END END) )
        , ShowFields        = CASE WHEN ISNULL(MAX(RptCfg.ShowFields),'') = ''
                                   THEN ',' + MAX(LOWER(ORDET.ShowField)) + ','
                                   ELSE MAX(RptCfg.ShowFields) + ISNULL( MAX(LOWER(ORDET.ShowField)) + LEFT(MAX(RptCfg.ShowFields),1), '')
                              END
        , SortOrderkey      = MAX ( CASE WHEN @as_sortbyinputseq='Y' THEN '' ELSE RTRIM(ORDET.Storerkey)+'|'+RTRIM(ORDET.DocKey) END )
        , SeqPS             = MAX ( ISNULL( SelPS.SeqNo, 0 ) )
        , SeqEOK            = MAX ( ISNULL( SelEOK.SeqNo, 0 ) )
        , SeqOK             = MAX ( ISNULL( SelOK.SeqNo, 0 ) )
        , datawindow        = @c_DataWidnow

        , B_City            = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_AddressExp<>'', '', OH.B_City) )), '' ) )
        , C_City            = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_AddressExp<>'', '', OH.C_City) )), '' ) )
        , Type              = MAX ( ISNULL( RTRIM ( OH.Type ), '' ) )
        , ReferenceNo2      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo2 ), '') )
        , ReferenceNo3      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo3 ), '') )
        , ReferenceNo4      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo4 ), '') )
        , ReferenceNo5      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo5 ), '') )
        , Remark            = MAX ( RTRIM ( ORDET.Remark ) )
        , LineRemark        = MAX ( RTRIM ( ORDET.LineRemark ) )
        , ConsolPick        = MAX( ISNULL( RTRIM( ORDET.ConsolPick ), '' ) )

        , Lbl_ReportTitle   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReportTitle') ) AS NVARCHAR(500))
        , Lbl_DeliveryDate  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DeliveryDate') ) AS NVARCHAR(500))
        , Lbl_DocNumber     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_DocNumber') ) AS NVARCHAR(500))
        , Lbl_LFLRefNo      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LFLRefNo') ) AS NVARCHAR(500))
        , Lbl_ReferenceNo   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReferenceNo') ) AS NVARCHAR(500))
        , Lbl_ReferenceNo2  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReferenceNo2') ) AS NVARCHAR(500))
        , Lbl_ReferenceNo3  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReferenceNo3') ) AS NVARCHAR(500))
        , Lbl_ReferenceNo4  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReferenceNo4') ) AS NVARCHAR(500))
        , Lbl_ReferenceNo5  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReferenceNo5') ) AS NVARCHAR(500))
        , Lbl_Remark        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Remark') ) AS NVARCHAR(500))
        , Lbl_LineNo        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineNo') ) AS NVARCHAR(500))
        , Lbl_Sku           = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Sku') ) AS NVARCHAR(500))
        , Lbl_Descr         = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Descr') ) AS NVARCHAR(500))
        , Lbl_LineRemark    = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRemark') ) AS NVARCHAR(500))
        , Lbl_LineRef1      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef1') ) AS NVARCHAR(500))
        , Lbl_LineRef2      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef2') ) AS NVARCHAR(500))
        , Lbl_LineRef3      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef3') ) AS NVARCHAR(500))
        , Lbl_Qty           = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Qty') ) AS NVARCHAR(500))
        , Lbl_UOM           = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_UOM') ) AS NVARCHAR(500))
        , Lbl_UnitPrice     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_UnitPrice') ) AS NVARCHAR(500))
        , Lbl_PriceFormat   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_PriceFormat') ) AS NVARCHAR(500))
        , Lbl_Discount      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Discount') ) AS NVARCHAR(500))
        , Lbl_Amount        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Amount') ) AS NVARCHAR(500))
        , Lbl_ReceivedBy    = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ReceivedBy') ) AS NVARCHAR(500))
        , Lbl_TermsNCond1   = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TermsNCond1') ) AS NVARCHAR(500))
        , Lbl_TermsNCond2   = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TermsNCond2') ) AS NVARCHAR(500))
        , N_Xpos1           = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos1') ) AS NVARCHAR(50))
        , N_Xpos_LineNo     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineNo') ) AS NVARCHAR(50))
        , N_Xpos_Sku        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Sku') ) AS NVARCHAR(50))
        , N_Xpos_Descr      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Descr') ) AS NVARCHAR(50))
        , N_Xpos_LineRemark = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRemark') ) AS NVARCHAR(50))
        , N_Xpos_LineRef1   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef1') ) AS NVARCHAR(50))
        , N_Xpos_LineRef2   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef2') ) AS NVARCHAR(50))
        , N_Xpos_LineRef3   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef3') ) AS NVARCHAR(50))
        , N_Xpos_Qty        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Qty') ) AS NVARCHAR(50))
        , N_Xpos_UOM        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_UOM') ) AS NVARCHAR(50))
        , N_Xpos_UnitPrice  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_UnitPrice') ) AS NVARCHAR(50))
        , N_Xpos_Discount   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Discount') ) AS NVARCHAR(50))
        , N_Xpos_Amount     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Amount') ) AS NVARCHAR(50))
        , N_Xpos_TermsNCond1= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TermsNCond1') ) AS NVARCHAR(50))
        , N_Xpos_TermsNCond2= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TermsNCond2') ) AS NVARCHAR(50))
        , N_Xpos_ReceivedBy = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_ReceivedBy') ) AS NVARCHAR(50))
        , N_Xpos_TotalQty   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TotalQty') ) AS NVARCHAR(50))
        , N_Ypos_TermsNCond1= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_TermsNCond1') ) AS NVARCHAR(50))
        , N_Ypos_TermsNCond2 = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_TermsNCond2') ) AS NVARCHAR(50))
        , N_Ypos_ReceivedBy = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_ReceivedBy') ) AS NVARCHAR(50))
        , N_Width_LineNo    = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineNo') ) AS NVARCHAR(50))
        , N_Width_Sku       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Sku') ) AS NVARCHAR(50))
        , N_Width_Descr     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Descr') ) AS NVARCHAR(50))
        , N_Width_LineRemark= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRemark') ) AS NVARCHAR(50))
        , N_Width_LineRef1  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef1') ) AS NVARCHAR(50))
        , N_Width_LineRef2  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef2') ) AS NVARCHAR(50))
        , N_Width_LineRef3  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef3') ) AS NVARCHAR(50))
        , N_Width_Qty       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Qty') ) AS NVARCHAR(50))
        , N_Width_UOM       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_UOM') ) AS NVARCHAR(50))
        , N_Width_UnitPrice = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_UnitPrice') ) AS NVARCHAR(50))
        , N_Width_Discount  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Discount') ) AS NVARCHAR(50))
        , N_Width_Amount    = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Amount') ) AS NVARCHAR(50))
        , N_Width_TermsNCond1= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_TermsNCond1') ) AS NVARCHAR(50))
        , N_Width_TermsNCond2= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_TermsNCond2') ) AS NVARCHAR(50))
        , N_Width_ReceivedBy= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_ReceivedBy') ) AS NVARCHAR(50))
        , N_Width_TotalQty  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_TotalQty') ) AS NVARCHAR(50))

        , Copies            = COPY.Copies
        , CopyDescr         = CAST( MAX ( ISNULL( RTRIM ( COPY.CopyDescr ), '' ) ) AS NVARCHAR(500))

        , GrossAmount       = ORDET.GrossAmount
        , S_Fax2            = MAX ( ISNULL( LTRIM(RTRIM(STORER.Fax2)), '' ) )
        , S_B_Fax2          = MAX ( ISNULL( LTRIM(RTRIM(STORER.B_Fax2)),'' ) )
        , ReportTitle       = MAX ( RTRIM ( ORDET.ReportTitle ) )
        , LFLRefNo          = MAX ( ISNULL( RTRIM ( ORDET.LFLRefNo ), '') )
        , Lbl_BillTo        = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_BillTo') ) AS NVARCHAR(500))
        , Lbl_B_Phone       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_B_Phone') ) AS NVARCHAR(500))
        , Lbl_ShipTo        = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_ShipTo') ) AS NVARCHAR(500))
        , Lbl_C_Phone       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_C_Phone') ) AS NVARCHAR(500))
        , Lbl_GrossAmount   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_GrossAmount') ) AS NVARCHAR(500))
        , Lbl_TotalQty      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TotalQty') ) AS NVARCHAR(500))
        , Lbl_TotalAmount   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TotalAmount') ) AS NVARCHAR(500))
        , N_Xpos_GrossAmount = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_GrossAmount') ) AS NVARCHAR(50))
        , N_Xpos_TotalAmount = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TotalAmount') ) AS NVARCHAR(50))
        , N_Width_GrossAmount= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_GrossAmount') ) AS NVARCHAR(50))
        , N_Width_TotalAmount= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_TotalAmount') ) AS NVARCHAR(50))
        , SplitPrintKey     = MAX ( ISNULL( RTRIM ( ORDET.SplitPrintKey ), '') )

        , OrderLineNo       = ORDET.OrderLineNo
        , Amount_Sum        = SUM ( ORDET.Amount )
        , Lbl_TotalCarton   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_TotalCarton') ) AS NVARCHAR(500))
        , Total_Doc_Amount  = (SELECT SUM(Amount) FROM #TEMP_ORDET WHERE Dockey=ORDET.DocKey)
        , B_State           = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_AddressExp<>'', ''             , OH.B_State   ) )), '' ) )   -- v1.2
        , B_Zip             = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_AddressExp<>'', ''             , OH.B_Zip     ) )), '' ) )   -- v1.2
        , B_Fax1            = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_B_FaxExp    <>'', ORDET.B_Fax    , OH.B_Fax1    ) )), '' ) )   -- v1.2
        , C_State           = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_AddressExp<>'', ''             , OH.C_State   ) )), '' ) )   -- v1.2
        , C_Zip             = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_AddressExp<>'', ''             , OH.C_Zip     ) )), '' ) )   -- v1.2
        , C_Fax1            = MAX( ISNULL( LTRIM(RTRIM( IIF(@c_C_FaxExp    <>'', ORDET.C_Fax    , OH.C_Fax1    ) )), '' ) )   -- v1.2
        , N_Xpos_S_Company  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_S_Company') ) AS NVARCHAR(50))
        , N_Width_S_Company = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_S_Company') ) AS NVARCHAR(50))
        , LineRef4          = RTRIM ( ORDET.LineRef4 )
        , LineRef5          = RTRIM ( ORDET.LineRef5 )
        , LineRef6          = RTRIM ( ORDET.LineRef6 )
        , LineRef7          = RTRIM ( ORDET.LineRef7 )
        , LineRef8          = RTRIM ( ORDET.LineRef8 )
        , LineRef9          = RTRIM ( ORDET.LineRef9 )
        , Currency          = MAX( ORDET.Currency )
        , Lbl_LineRef4      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef4') ) AS NVARCHAR(500))
        , Lbl_LineRef5      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef5') ) AS NVARCHAR(500))
        , Lbl_LineRef6      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef6') ) AS NVARCHAR(500))
        , Lbl_LineRef7      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef7') ) AS NVARCHAR(500))
        , Lbl_LineRef8      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef8') ) AS NVARCHAR(500))
        , Lbl_LineRef9      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_LineRef9') ) AS NVARCHAR(500))
        , Lbl_Signature     = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Signature') ) AS NVARCHAR(500))
        , Lbl_CompanyStamp  = CAST( RTRIM( (select top 1 replace(b.ColValue, '\n', char(10))
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_CompanyStamp') ) AS NVARCHAR(500))
        , N_Xpos_Remark     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Remark') ) AS NVARCHAR(50))
        , N_Xpos_LineRef4   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef4') ) AS NVARCHAR(50))
        , N_Xpos_LineRef5   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef5') ) AS NVARCHAR(50))
        , N_Xpos_LineRef6   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef6') ) AS NVARCHAR(50))
        , N_Xpos_LineRef7   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef7') ) AS NVARCHAR(50))
        , N_Xpos_LineRef8   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef8') ) AS NVARCHAR(50))
        , N_Xpos_LineRef9   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_LineRef9') ) AS NVARCHAR(50))
        , N_Xpos_Signature  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Signature') ) AS NVARCHAR(50))
        , N_Xpos_CompanyStamp= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_CompanyStamp') ) AS NVARCHAR(50))
        , N_Ypos_LineRef1   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef1') ) AS NVARCHAR(50))
        , N_Ypos_LineRef2   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef2') ) AS NVARCHAR(50))
        , N_Ypos_LineRef3   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef3') ) AS NVARCHAR(50))
        , N_Ypos_LineRef4   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef4') ) AS NVARCHAR(50))
        , N_Ypos_LineRef5   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef5') ) AS NVARCHAR(50))
        , N_Ypos_LineRef6   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef6') ) AS NVARCHAR(50))
        , N_Ypos_LineRef7   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef7') ) AS NVARCHAR(50))
        , N_Ypos_LineRef8   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef8') ) AS NVARCHAR(50))
        , N_Ypos_LineRef9   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_LineRef9') ) AS NVARCHAR(50))
        , N_Ypos_Signature  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_Signature') ) AS NVARCHAR(50))
        , N_Ypos_CompanyStamp= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_CompanyStamp') ) AS NVARCHAR(50))
        , N_Width_Remark    = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Remark') ) AS NVARCHAR(50))
        , N_Width_LineRef4  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef4') ) AS NVARCHAR(50))
        , N_Width_LineRef5  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef5') ) AS NVARCHAR(50))
        , N_Width_LineRef6  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef6') ) AS NVARCHAR(50))
        , N_Width_LineRef7  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef7') ) AS NVARCHAR(50))
        , N_Width_LineRef8  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef8') ) AS NVARCHAR(50))
        , N_Width_LineRef9  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineRef9') ) AS NVARCHAR(50))
        , N_Width_Currency  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Currency') ) AS NVARCHAR(50))
        , N_Width_Signature = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Signature') ) AS NVARCHAR(50))
        , N_Width_CompanyStamp= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_CompanyStamp') ) AS NVARCHAR(50))
        , N_Height_LineHeading= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Height_LineHeading') ) AS NVARCHAR(50))
   FROM #TEMP_ORDET ORDET
   JOIN dbo.ORDERS     OH (NOLOCK) ON (ORDET.FirstOrderKey = OH.Orderkey)
   JOIN dbo.STORER STORER (NOLOCK) ON (OH.StorerKey = STORER.StorerKey)
   LEFT OUTER JOIN #TEMP_PAK   PAK ON (ORDET.DocKey = PAK.DocKey)
   LEFT OUTER JOIN dbo.CODELKUP BL (NOLOCK) ON (BL.Listname = 'BRAND_LOGO' AND BL.Storerkey = ORDET.Storerkey AND BL.Code = ORDET.BRAND_Logo_Code)
   LEFT OUTER JOIN dbo.CODELKUP RL (NOLOCK) ON (RL.Listname = 'RPTLOGO' AND RL.Code='LOGO' AND RL.Storerkey = ORDET.Storerkey AND RL.Long = @c_DataWidnow)

   LEFT JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWidnow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=ORDET.Storerkey AND RptCfg.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=ORDET.Storerkey AND RptCfg3.SeqNo=1

   LEFT JOIN #TEMP_PICKSLIPNO     SelPS  ON ORDET.PickSlipNo     = SelPS.ColValue
   LEFT JOIN #TEMP_EXTERNORDERKEY SelEOK ON ORDET.ExternOrderKey = SelEOK.ColValue
   LEFT JOIN #TEMP_ORDERKEY       SelOK  ON ORDET.Orderkey       = SelOK.ColValue
   LEFT JOIN #TEMP_COPYDESCR      COPY   ON ORDET.Storerkey      = COPY.Storerkey

   GROUP BY ORDET.Storerkey
          , ORDET.DocKey
          , COPY.Copies
          , ORDET.LineGrouping
          , ORDET.OrderLineNo
          , ORDET.Sku
          , ORDET.LineRef1
          , ORDET.LineRef2
          , ORDET.LineRef3
          , ORDET.LineRef4
          , ORDET.LineRef5
          , ORDET.LineRef6
          , ORDET.LineRef7
          , ORDET.LineRef8
          , ORDET.LineRef9
          , ORDET.Unitprice
          , ORDET.Discount
          , CASE WHEN RptCfg.ShowFields LIKE '%,SumAmount,%' THEN 0 ELSE ORDET.Amount END
          , ORDET.GrossAmount
          , ORDET.UOM

   ORDER BY SortOrderkey, SeqPS, SeqEOK, SeqOK, DocKey, Copies, Line_No

END

GO