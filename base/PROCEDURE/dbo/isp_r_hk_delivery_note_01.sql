SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_delivery_note_01                           */
/* Creation Date: 08-Aug-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Delivery note                                                */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_delivery_note_01            */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 16/09/2017   ML       1.1  Add printing FullSizeScale options         */
/* 02/11/2017   ML       1.2  Add new fields for Converse D/N            */
/* 23/11/2017   ML       1.3  Fix duplicate order issue                  */
/* 25/11/2017   ML       1.4  Add Codelkup.RPTLOGO config                */
/* 15/12/2017   ML       1.5  Add new Show Fields                        */
/* 22/01/2018   ML       1.6  - Performance tuning                       */
/*                            - Add fields S_Fax2, S_B_Fax2, ...         */
/* 05/02/2018   ML       1.7  Add new Show Fields                        */
/* 30/04/2018   ML       1.8  Add new field SplitPrintKey                */
/* 19/04/2021   ML       1.9  Performance tuning                         */
/* 04/11/2021   ML       1.10 Add SizeSeq logic for handling Size 99-99  */
/* 23/03/2022   ML       1.11 Add NULL to Temp Table                     */
/* 28/11/2022   ML       1.12 Fix decimal Qty issue                      */
/* 21/03/2023   ML       1.13 Add ShowField: AllowOrderStatus<5          */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_delivery_note_01] (
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
      BrandLogoCode, ReportTitle, SplitPrintKey, DocNumber, ExternOrderkey, LFLRefNo, ReferenceNo, ReferenceNo2, ReferenceNo3, ReferenceNo4, ReferenceNo5
      Remark, LineGrouping, Style, Color, Measurement
      Size, Descr, LineRemark, LineRef1, LineRef2, LineRef3, Qty, UOM, Unitprice, Discount, Amount, GrossAmount
      SizeScale_FieldName, SizeScale_ListName, ShowField
      ConsigneePrefix
   [MAPVALUE]
      T_CopyDescr, T_ReportTitle, T_BillTo, T_B_Phone, T_ShipTo, T_C_Phone
      T_DeliveryDate, T_DocNumber, T_LFLRefNo, T_ReferenceNo, T_ReferenceNo2, T_ReferenceNo3, T_ReferenceNo4, T_ReferenceNo5, T_Remark
      T_LineNo, T_Style, T_Color, T_Meas, T_Descr, T_LineRef1, T_LineRef2, T_LineRef3, T_Qty, T_UOM, T_UnitPrice, T_PriceFormat, T_Discount, T_Amount, T_GrossAmount
      T_TotalQty, T_TotalAmount, T_ReceivedBy, T_TermsNCond1, T_TermsNCond2
      N_Xpos1, N_Xpos_LineNo, N_Xpos_Style, N_Xpos_Color, N_Xpos_Meas, N_Xpos_Descr, N_Xpos_Size
      N_Xpos_LineRemark, N_Xpos_LineRef1, N_Xpos_LineRef2, N_Xpos_LineRef3
      N_Xpos_Qty, N_Xpos_UOM, N_Xpos_UnitPrice, N_Xpos_Discount, N_Xpos_Amount, N_Xpos_GrossAmount
      N_Xpos_ReceivedBy, N_Xpos_TotalQty, N_Xpos_TotalAmount, N_Ypos_ReceivedBy
      N_Width_LineNo, N_Width_Style, N_Width_Color, N_Width_Meas, N_Width_Descr, N_Width_Size, N_Width_SizeGap
      N_Width_LineRemark, N_Width_LineRef1, N_Width_LineRef2, N_Width_LineRef3
      N_Width_Qty, N_Width_UOM, N_Width_UnitPrice, N_Width_Discount, N_Width_Amount, N_Width_GrossAmount
      N_Width_TotalQty, N_Width_TotalAmount, N_Width_ReceivedBy
      N_NoOfSizeCol
   [SHOWFIELD]
      UseLFLogo, UseCode39, FullSizeScale, UsePackDetail
      Storer_B_ComAddr, AddressDirectConcate, City, Contact, Country, OrderType
      ReferenceNo, ReferenceNo2, ReferenceNo3, ReferenceNo4, ReferenceNo5
      HideLFLRefNo, HideStorerCompany, HideStorerAddress, HideBillToKey, HideBillToCompany, HideBillToAddress, HideBillToPhone
      HideConsigneeKey, HideShipToCompany, HideShipToAddress, HideShipToPhone, HideAddress4, HideC_Phone1, HideRemark
      HideStyle, HideColor, HideMeas, HideDescr, HideTotalQty, HideTotalCarton, HideReceivedBy, HideDataWindowName
      Remark_SFont, Dethdr_SFont, Detline_SFont, Detline_SFont2, Sizelb_SFont, Descr_SFont
      LineNo, ChineseDescr, LineRef1, LineRef2, LineRef3, ChineseLineRemark, UOM, UnitPrice, Discount, Amount, GrossAmount, TotalAmount
      LineGrouping_Separateline
      BoldDeliveryDate, BoldDocNumber, BoldLFLRefNo, BoldReferenceNo, BoldReferenceNo2, BoldReferenceNo3, BoldReferenceNo4, BoldReferenceNo5
      PrintByOrder, WaterMark, AllowOrderStatus<5
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
         , @c_SizeList           NVARCHAR(2000)
         , @c_BRAND_Logo_CodeExp NVARCHAR(4000)
         , @c_ReportTitleExp     NVARCHAR(4000)
         , @c_SplitPrintKeyExp   NVARCHAR(4000)
         , @c_DocNumberExp       NVARCHAR(4000)
         , @c_ExternOrderkeyExp  NVARCHAR(4000)
         , @c_LFLRefNoExp        NVARCHAR(4000)
         , @c_ReferenceNoExp     NVARCHAR(4000)
         , @c_ReferenceNo2Exp    NVARCHAR(4000)
         , @c_ReferenceNo3Exp    NVARCHAR(4000)
         , @c_ReferenceNo4Exp    NVARCHAR(4000)
         , @c_ReferenceNo5Exp    NVARCHAR(4000)
         , @c_RemarkExp          NVARCHAR(4000)
         , @c_LineGroupingExp    NVARCHAR(4000)
         , @c_StyleExp           NVARCHAR(4000)
         , @c_ColorExp           NVARCHAR(4000)
         , @c_MeasurementExp     NVARCHAR(4000)
         , @c_SizeExp            NVARCHAR(4000)
         , @c_DescrExp           NVARCHAR(4000)
         , @c_LineRemarkExp      NVARCHAR(4000)
         , @c_LineRef1Exp        NVARCHAR(4000)
         , @c_LineRef2Exp        NVARCHAR(4000)
         , @c_LineRef3Exp        NVARCHAR(4000)
         , @c_UnitpriceExp       NVARCHAR(4000)
         , @c_QtyExp             NVARCHAR(4000)
         , @c_UOMExp             NVARCHAR(4000)
         , @c_DiscountExp        NVARCHAR(4000)
         , @c_AmountExp          NVARCHAR(4000)
         , @c_GrossAmountExp     NVARCHAR(4000)
         , @c_ShowFieldExp       NVARCHAR(4000)
         , @c_SS_FieldNameExp    NVARCHAR(4000)
         , @c_SS_Listname        NVARCHAR(10)
         , @c_ConsigneePrefix    NVARCHAR(15)
         , @c_Orderkey           NVARCHAR(10)
         , @c_ReportTitle        NVARCHAR(500)
         , @c_SplitPrintKey      NVARCHAR(500)
         , @c_DocNumber          NVARCHAR(500)
         , @c_ExternOrderkey     NVARCHAR(500)
         , @c_LFLRefNo           NVARCHAR(500)
         , @c_ReferenceNo        NVARCHAR(500)
         , @c_ReferenceNo2       NVARCHAR(500)
         , @c_ReferenceNo3       NVARCHAR(500)
         , @c_ReferenceNo4       NVARCHAR(500)
         , @c_ReferenceNo5       NVARCHAR(500)
         , @c_Remark             NVARCHAR(500)
         , @c_PickSlipNo         NVARCHAR(18)
         , @c_LineGrouping       NVARCHAR(500)
         , @c_FullSizeScale      NVARCHAR(4000)
         , @c_Style              NVARCHAR(500)
         , @c_Color              NVARCHAR(500)
         , @c_Measurement        NVARCHAR(500)
         , @c_OrderLineNumber    NVARCHAR(5)
         , @c_Descr              NVARCHAR(500)
         , @c_LineRemark         NVARCHAR(500)
         , @c_LineRef1           NVARCHAR(500)
         , @c_LineRef2           NVARCHAR(500)
         , @c_LineRef3           NVARCHAR(500)
         , @n_Unitprice          FLOAT
         , @n_Discount           FLOAT
         , @n_Amount             FLOAT
         , @n_GrossAmount        FLOAT
         , @c_ShowField          NVARCHAR(4000)
         , @c_UOM                NVARCHAR(10)
         , @c_BRAND_Logo_Code    NVARCHAR(500)
         , @c_ConsolPick         NVARCHAR(1)
         , @c_DocKey             NVARCHAR(10)
         , @c_FirstOrderkey      NVARCHAR(10)
         , @c_CopyDescr          NVARCHAR(4000)
         , @c_NoOfSizeCol        NVARCHAR(4000)
         , @c_Storerkey          NVARCHAR(15)
         , @n_Col                INT
         , @n_Temp               INT
         , @n_PickslipNoCnt      INT
         , @n_OrderkeyCnt        INT
         , @n_ExternOrderkeyCnt  INT
         , @b_ShowFullSizeScale  INT
         , @b_UsePackDetail      INT
         , @c_ExecStatements     NVARCHAR(MAX)
         , @c_ExecArguments      NVARCHAR(MAX)
         , @c_JoinClause         NVARCHAR(4000)


   SELECT @c_DataWidnow = 'r_hk_delivery_note_01'
        , @c_SizeList   = N'|5XS|4XS|3XS|XXXS|2XS|XXS|XS|0XS|S|00S|YS|SM|0SM|S/M|M|00M|YM|ML|0ML|M/L|L|00L|YL|F|XL|0XL|XXL|2XL|XXXL|3XL|4XL|5XL|'
        , @n_Col        = 24

   CREATE TABLE #TEMP_ORDET (
        Orderkey        NVARCHAR(10)   NULL
      , Storerkey       NVARCHAR(15)   NULL
      , ReportTitle     NVARCHAR(500)  NULL
      , SplitPrintKey   NVARCHAR(500)  NULL
      , DocNumber       NVARCHAR(500)  NULL
      , ExternOrderkey  NVARCHAR(500)  NULL
      , LFLRefNo        NVARCHAR(500)  NULL
      , ReferenceNo     NVARCHAR(500)  NULL
      , ReferenceNo2    NVARCHAR(500)  NULL
      , ReferenceNo3    NVARCHAR(500)  NULL
      , ReferenceNo4    NVARCHAR(500)  NULL
      , ReferenceNo5    NVARCHAR(500)  NULL
      , Remark          NVARCHAR(500)  NULL
      , PickSlipNo      NVARCHAR(18)   NULL
      , LineGrouping    NVARCHAR(500)  NULL
      , OrderLineNumber NVARCHAR(5 )   NULL
      , Sku             NVARCHAR(20)   NULL
      , Style           NVARCHAR(500)  NULL
      , Color           NVARCHAR(500)  NULL
      , Measurement     NVARCHAR(500)  NULL
      , Size            NVARCHAR(10)   NULL
      , SizeScaleSeq    INT            NULL
      , Descr           NVARCHAR(500)  NULL
      , LineRemark      NVARCHAR(500)  NULL
      , LineRef1        NVARCHAR(500)  NULL
      , LineRef2        NVARCHAR(500)  NULL
      , LineRef3        NVARCHAR(500)  NULL
      , Unitprice       FLOAT          NULL
      , Qty             FLOAT          NULL
      , Discount        FLOAT          NULL
      , Amount          FLOAT          NULL
      , GrossAmount     FLOAT          NULL
      , ShowField       NVARCHAR(4000) NULL
      , UOM             NVARCHAR(10)   NULL
      , ConsigneePrefix NVARCHAR(15)   NULL
      , BRAND_Logo_Code NVARCHAR(500)  NULL
      , ConsolPick      NVARCHAR(1)    NULL
      , DocKey          NVARCHAR(10)   NULL
      , FirstOrderkey   NVARCHAR(10)   NULL
   )

   CREATE TABLE #TEMP_COPYDESCR (
        Copies          INT            NULL
      , CopyDescr       NVARCHAR(4000) NULL
      , Storerkey       NVARCHAR(15)   NULL
   )


   -- PickslipNo List
   SELECT SeqNo    = MIN(SeqNo)
        , ColValue = LTRIM(RTRIM(ColValue))
     INTO #TEMP_PICKSLIPNO
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_pickslipno,CHAR(13)+CHAR(10),','))
    WHERE ColValue<>''
    GROUP BY LTRIM(RTRIM(ColValue))

   SET @n_PickslipNoCnt = @@ROWCOUNT

   -- Orderkey List
   SELECT SeqNo    = MIN(SeqNo)
        , ColValue = LTRIM(RTRIM(ColValue))
     INTO #TEMP_ORDERKEY
     FROM dbo.fnc_DelimSplit(',',replace(@as_orderkey,char(13)+char(10),','))
    WHERE ColValue<>''
    GROUP BY LTRIM(RTRIM(ColValue))

   SET @n_OrderkeyCnt = @@ROWCOUNT

   -- ExternOrderkey List
   SELECT SeqNo    = MIN(SeqNo)
        , ColValue = LTRIM(RTRIM(ColValue))
     INTO #TEMP_EXTERNORDERKEY
     FROM dbo.fnc_DelimSplit(',',replace(@as_externorderkey,char(13)+char(10),','))
    WHERE ColValue<>''
    GROUP BY LTRIM(RTRIM(ColValue))

   SET @n_ExternOrderkeyCnt = @@ROWCOUNT


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


   SELECT DocKey        = FOK.DocKey
        , Total_Carton  = COUNT(DISTINCT PD.LabelNo)
     INTO #TEMP_PAK
     FROM #TEMP_FINALORDERKEY FOK
     JOIN dbo.PACKDETAIL PD ON FOK.PickSlipNo=PD.PickSlipNo
    WHERE PD.Qty>0
    GROUP BY FOK.DocKey


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
           , @c_DocNumberExp       = ''
           , @c_ExternOrderkeyExp  = ''
           , @c_LFLRefNoExp        = ''
           , @c_ReferenceNoExp     = ''
           , @c_ReferenceNo2Exp    = ''
           , @c_ReferenceNo3Exp    = ''
           , @c_ReferenceNo4Exp    = ''
           , @c_ReferenceNo5Exp    = ''
           , @c_RemarkExp          = ''
           , @c_LineGroupingExp    = ''
           , @c_StyleExp           = ''
           , @c_ColorExp           = ''
           , @c_MeasurementExp     = ''
           , @c_SizeExp            = ''
           , @c_DescrExp           = ''
           , @c_LineRemarkExp      = ''
           , @c_LineRef1Exp        = ''
           , @c_LineRef2Exp        = ''
           , @c_LineRef3Exp        = ''
           , @c_UnitpriceExp       = ''
           , @c_QtyExp             = ''
           , @c_UOMExp             = ''
           , @c_DiscountExp        = ''
           , @c_AmountExp          = ''
           , @c_GrossAmountExp     = ''
           , @c_ShowFieldExp       = ''
           , @c_SS_FieldNameExp    = ''
           , @c_SS_Listname        = ''
           , @c_ConsigneePrefix    = ''
           , @c_CopyDescr          = ''
           , @c_NoOfSizeCol        = ''
           , @b_ShowFullSizeScale  = 0
           , @b_UsePackDetail      = 0
           , @c_JoinClause         = ''

      SELECT TOP 1
             @b_ShowFullSizeScale  = CASE WHEN ','+RTRIM(Notes)+',' LIKE '%,FullSizeScale,%' THEN 1 ELSE 0 END
           , @b_UsePackDetail      = CASE WHEN ','+RTRIM(Notes)+',' LIKE '%,UsePackDetail,%' THEN 1 ELSE 0 END
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      SELECT TOP 1
             @c_CopyDescr          = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='T_CopyDescr')), '' )
           , @c_NoOfSizeCol        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='N_NoOfSizeCol')), '' )
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWidnow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2


      IF ISNULL(@c_NoOfSizeCol,'')<>'' AND ISNUMERIC(@c_NoOfSizeCol)=1
      BEGIN
         SET @n_Temp = CONVERT(INT, CONVERT(FLOAT, @c_NoOfSizeCol) )
         IF @n_Temp BETWEEN 1 AND 24
         BEGIN
            SET @n_Col = @n_Temp
         END
      END


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
           , @c_LineGroupingExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='LineGrouping')), '' )
           , @c_StyleExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Style')), '' )
           , @c_ColorExp           = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Color')), '' )
           , @c_MeasurementExp     = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Measurement')), '' )
           , @c_SizeExp            = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='Size')), '' )
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
           , @c_ShowFieldExp       = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='ShowField')), '' )
           , @c_SS_FieldNameExp    = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SizeScale_FieldName')), '' )
           , @c_SS_Listname        = ISNULL(RTRIM((select top 1 b.ColValue
                                     from dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes)) a, dbo.fnc_DelimSplit(LTRIM(RTRIM(UDF01)),RTRIM(Notes2)) b
                                     where a.SeqNo=b.SeqNo and a.ColValue='SizeScale_ListName')), '' )
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
          +' (Orderkey, Storerkey, ReportTitle, SplitPrintKey, DocNumber, ExternOrderkey, LFLRefNo, ReferenceNo, ReferenceNo2'
          + ', ReferenceNo3, ReferenceNo4, ReferenceNo5, Remark, PickslipNo'
          + ', LineGrouping, OrderLineNumber, Sku, Style, Color, Measurement, Size'
          + ', SizeScaleSeq, Descr, LineRemark, LineRef1, LineRef2, LineRef3'
          + ', Qty, UOM, Unitprice, Discount, Amount, GrossAmount, ShowField'
          + ', ConsigneePrefix, BRAND_Logo_Code'
          + ', ConsolPick, DocKey, FirstOrderkey)'
          +' SELECT OH.OrderKey'
               + ', OH.Storerkey'
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_ReportTitleExp    ,'')<>'' THEN @c_ReportTitleExp     ELSE 'NULL' END
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_SplitPrintKeyExp  ,'')<>'' THEN @c_SplitPrintKeyExp   ELSE '''''' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DocNumberExp      ,'')<>'' THEN @c_DocNumberExp       ELSE 'IIF(FOK.ConsolPick=''Y'',FOK.DocKey,OH.ExternOrderkey)' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ExternOrderkeyExp ,'')<>'' THEN @c_ExternOrderkeyExp  ELSE 'OH.ExternOrderkey' END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LFLRefNoExp       ,'')<>'' THEN @c_LFLRefNoExp        ELSE 'IIF(FOK.ConsolPick=''Y'', '''', OH.Orderkey)' END + '),'''')'
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
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineGroupingExp   ,'')<>'' THEN @c_LineGroupingExp    ELSE ''''''              END + '),'''')'
               + ', OD.OrderLineNumber'
               + ', PD.Sku'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_StyleExp          ,'')<>'' THEN @c_StyleExp           ELSE 'SKU.Style'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ColorExp          ,'')<>'' THEN @c_ColorExp           ELSE 'SKU.Color'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_MeasurementExp    ,'')<>'' THEN @c_MeasurementExp     ELSE 'SKU.Measurement'   END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(LTRIM(RTRIM(' + CASE WHEN ISNULL(@c_SizeExp     ,'')<>'' THEN @c_SizeExp            ELSE 'SKU.Size'          END + ')),'''')'
               + ', 0'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_DescrExp          ,'')<>'' THEN @c_DescrExp           ELSE 'SKU.DESCR'         END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRemarkExp     ,'')<>'' THEN @c_LineRemarkExp      ELSE ''''''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef1Exp       ,'')<>'' THEN @c_LineRef1Exp        ELSE ''''''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef2Exp       ,'')<>'' THEN @c_LineRef2Exp        ELSE ''''''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_LineRef3Exp       ,'')<>'' THEN @c_LineRef3Exp        ELSE ''''''              END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL('       + CASE WHEN ISNULL(@c_QtyExp            ,'')<>'' THEN @c_QtyExp             ELSE 'PD.Qty'            END + ',0)'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_UOMExp            ,'')<>'' THEN @c_UOMExp             ELSE 'PACK.PackUOM3'     END + '),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_UnitpriceExp      ,'')<>'' THEN @c_UnitpriceExp       ELSE 'OD.UnitPrice'      END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_DiscountExp       ,'')<>'' THEN @c_DiscountExp        ELSE 'NULL'              END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_AmountExp         ,'')<>'' THEN @c_AmountExp          ELSE 'NULL'              END
      SET @c_ExecStatements = @c_ExecStatements
               + ', '              + CASE WHEN ISNULL(@c_GrossAmountExp    ,'')<>'' THEN @c_GrossAmountExp     ELSE 'NULL'              END
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_ShowFieldExp      ,'')<>'' THEN @c_ShowFieldExp       ELSE ''''''              END + '),'''')'
               + ', ISNULL(RTRIM(@c_ConsigneePrefix),'''')'
      SET @c_ExecStatements = @c_ExecStatements
               + ', ISNULL(RTRIM(' + CASE WHEN ISNULL(@c_BRAND_Logo_CodeExp,'')<>'' THEN @c_BRAND_Logo_CodeExp ELSE '''''' END + '),'''')'
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
          +' LEFT JOIN dbo.SKU    SKU (NOLOCK) ON PD.StorerKey=SKU.StorerKey AND PD.Sku=SKU.Sku'
          +' LEFT JOIN dbo.PACK  PACK (NOLOCK) ON SKU.Packkey=PACK.Packkey'
          +' LEFT JOIN #TEMP_PAK  PAK          ON FOK.DocKey=PAK.DocKey'
      SET @c_ExecStatements = @c_ExecStatements
          + CASE WHEN ISNULL(@c_JoinClause,'')='' THEN '' ELSE ' ' + ISNULL(LTRIM(RTRIM(@c_JoinClause)),'') END
      SET @c_ExecStatements = @c_ExecStatements
          +' WHERE PD.Qty > 0 AND OH.Storerkey=@c_Storerkey'

      SET @c_ExecArguments = N'@c_ConsigneePrefix   NVARCHAR(15)'
                           + ',@b_UsePackDetail     INT'
                           + ',@c_Storerkey         NVARCHAR(15)'

      EXEC sp_ExecuteSql @c_ExecStatements
                       , @c_ExecArguments
                       , @c_ConsigneePrefix
                       , @b_UsePackDetail
                       , @c_Storerkey


      IF ISNULL(@c_LineGroupingExp,'')=''
      BEGIN
         UPDATE #TEMP_ORDET SET LineGrouping = Style +'|'+ Color +'|'+ Measurement
      END

      ----------
      -- Build Full Size Scale (SS) list
      IF ISNULL(@c_SS_Listname,'')<>'' AND ISNULL(@c_SS_FieldNameExp,'')<>''
      BEGIN
         SET @c_ExecStatements = N'DECLARE C_SIZESCALE CURSOR FAST_FORWARD READ_ONLY FOR'
                               + ' SELECT DISTINCT'
                               +        ' ORDET.DocKey'
                               +       ', ORDET.LineGrouping'
                               +       ', SS.Notes2'
                               +   ' FROM #TEMP_ORDET  ORDET'
                               +   ' JOIN dbo.SKU        SKU (NOLOCK) ON ORDET.Storerkey=SKU.Storerkey AND ORDET.Sku=SKU.Sku'
                               +   ' JOIN dbo.ORDERDETAIL OD (NOLOCK) ON ORDET.Orderkey=OD.Orderkey AND ORDET.OrderLineNumber=OD.OrderLineNumber'
                               +   ' JOIN dbo.ORDERS      OH (NOLOCK) ON ORDET.Orderkey=OH.Orderkey'
                               +   ' JOIN dbo.CodeLkup    SS (NOLOCK)'
                               +     ' ON SS.Listname=@c_SS_Listname AND ORDET.Storerkey=SS.Storerkey AND SS.Short=' + ISNULL(@c_SS_FieldNameExp,'')
                               +   ' WHERE ORDET.Storerkey = @c_Storerkey'

         EXEC sp_ExecuteSql @c_ExecStatements
                          , N'@c_Storerkey NVARCHAR(15), @c_SS_Listname NVARCHAR(10)'
                          , @c_Storerkey
                          , @c_SS_Listname

         OPEN C_SIZESCALE

         WHILE 1=1
         BEGIN
            FETCH NEXT FROM C_SIZESCALE
             INTO @c_DocKey, @c_LineGrouping, @c_FullSizeScale

            IF @@FETCH_STATUS<>0
               BREAK

            IF @b_ShowFullSizeScale = 1
            BEGIN
               SELECT @c_Orderkey        = ''
                    , @c_ReportTitle     = ''
                    , @c_SplitPrintKey   = ''
                    , @c_DocNumber       = ''
                    , @c_ExternOrderkey  = ''
                    , @c_LFLRefNo        = ''
                    , @c_ReferenceNo     = ''
                    , @c_ReferenceNo2    = ''
                    , @c_ReferenceNo3    = ''
                    , @c_ReferenceNo4    = ''
                    , @c_ReferenceNo5    = ''
                    , @c_Remark          = ''
                    , @c_PickSlipNo      = ''
                    , @c_OrderLineNumber = ''
                    , @c_Style           = ''
                    , @c_Color           = ''
                    , @c_Measurement     = ''
                    , @c_Descr           = ''
                    , @c_LineRemark      = ''
                    , @c_LineRef1        = ''
                    , @c_LineRef2        = ''
                    , @c_LineRef3        = ''
                    , @n_Unitprice       = NULL
                    , @n_Discount        = NULL
                    , @n_Amount          = NULL
                    , @n_GrossAmount     = NULL
                    , @c_ShowField       = ''
                    , @c_UOM             = ''
                    , @c_ConsigneePrefix = ''
                    , @c_BRAND_Logo_Code = ''
                    , @c_ConsolPick      = ''
                    , @c_FirstOrderkey   = ''

               SELECT TOP 1
                      @c_Orderkey        = Orderkey
                    , @c_ReportTitle     = ReportTitle
                    , @c_SplitPrintKey   = SplitPrintKey
                    , @c_DocNumber       = DocNumber
                    , @c_ExternOrderkey  = ExternOrderkey
                    , @c_LFLRefNo        = LFLRefNo
                    , @c_ReferenceNo     = ReferenceNo
                    , @c_ReferenceNo2    = ReferenceNo2
                    , @c_ReferenceNo3    = ReferenceNo3
                    , @c_ReferenceNo4    = ReferenceNo4
                    , @c_ReferenceNo5    = ReferenceNo5
                    , @c_Remark          = Remark
                    , @c_PickSlipNo      = PickSlipNo
                    , @c_OrderLineNumber = OrderLineNumber
                    , @c_Style           = Style
                    , @c_Color           = Color
                    , @c_Measurement     = Measurement
                    , @c_Descr           = Descr
                    , @c_LineRemark      = LineRemark
                    , @c_LineRef1        = LineRef1
                    , @c_LineRef2        = LineRef2
                    , @c_LineRef3        = LineRef3
                    , @n_Unitprice       = Unitprice
                    , @n_Discount        = Discount
                    , @n_Amount          = Amount
                    , @n_GrossAmount     = GrossAmount
                    , @c_ShowField       = ShowField
                    , @c_UOM             = UOM
                    , @c_ConsigneePrefix = ConsigneePrefix
                    , @c_BRAND_Logo_Code = BRAND_Logo_Code
                    , @c_ConsolPick      = ConsolPick
                    , @c_FirstOrderkey   = FirstOrderkey
                 FROM #TEMP_ORDET
                WHERE DocKey=@c_DocKey AND Storerkey=@c_Storerkey AND LineGrouping=@c_LineGrouping
                ORDER BY OrderLineNumber, Style, Color, Sku

               INSERT INTO #TEMP_ORDET
                     (Orderkey, Storerkey, ReportTitle, SplitPrintKey, DocNumber, ExternOrderkey, LFLRefNo, ReferenceNo, ReferenceNo2
                    , ReferenceNo3, ReferenceNo4, ReferenceNo5, Remark, OrderLineNumber
                    , Sku, LineGrouping, Style, Color, Measurement, Size, SizeScaleSeq
                    , Descr, LineRemark, LineRef1, LineRef2, LineRef3
                    , Qty, Unitprice, Discount, Amount, GrossAmount, ShowField, UOM
                    , ConsigneePrefix, BRAND_Logo_Code
                    , ConsolPick, DocKey, FirstOrderkey)
               SELECT @c_Orderkey, @c_Storerkey, @c_ReportTitle, @c_SplitPrintKey, @c_DocNumber, @c_ExternOrderkey, @c_LFLRefNo, @c_ReferenceNo, @c_ReferenceNo2
                    , @c_ReferenceNo3, @c_ReferenceNo4, @c_ReferenceNo5, @c_Remark
                    , @c_OrderLineNumber, '', @c_LineGrouping, @c_Style, @c_Color, @c_Measurement, LTRIM(RTRIM(a.ColValue)), 0
                    , @c_Descr, @c_LineRemark, @c_LineRef1, @c_LineRef2, @c_LineRef3
                    , 0, @n_Unitprice, @n_Discount, @n_Amount, @n_GrossAmount, @c_ShowField, @c_UOM
                    , @c_ConsigneePrefix, @c_BRAND_Logo_Code
                    , @c_ConsolPick, @c_DocKey, @c_FirstOrderkey
                 FROM dbo.fnc_DelimSplit(',', @c_FullSizeScale) a
                 LEFT JOIN #TEMP_ORDET b ON LTRIM(RTRIM(a.ColValue)) = b.Size
                       AND b.DocKey=@c_DocKey AND b.Storerkey=@c_Storerkey AND b.LineGrouping=@c_LineGrouping
                WHERE b.Size IS NULL
             END

             UPDATE b
                SET SizeScaleSeq = a.SeqNo
               FROM dbo.fnc_DelimSplit(',', @c_FullSizeScale) a
               JOIN #TEMP_ORDET b ON LTRIM(RTRIM(a.ColValue)) = b.Size
                     AND b.DocKey=@c_DocKey AND b.Storerkey=@c_Storerkey AND b.LineGrouping=@c_LineGrouping
         END

         CLOSE C_SIZESCALE
         DEALLOCATE C_SIZESCALE
      END
   END

   CLOSE C_STORERKEY
   DEALLOCATE C_STORERKEY


   ----------
   SELECT DocKey       = SL.DocKey
        , Storerkey    = SL.Storerkey
        , LineGrouping = SL.LineGrouping
        , Size         = SL.Size
        , SizeSeq      = ROW_NUMBER() OVER(PARTITION BY SL.Storerkey, SL.DocKey, SL.LineGrouping
                         ORDER BY CASE
                            WHEN SizeScaleSeq>0 THEN FORMAT(SizeScaleSeq,'000000.00')
                            WHEN ISNUMERIC(SL.Size)=1 AND LTRIM(SL.Size) NOT IN ('-','+','.',',') THEN FORMAT(CONVERT(FLOAT,SL.Size)+400000,'000000.00')
                            WHEN RTRIM(SL.Size) LIKE N'%[0-9]H' AND ISNUMERIC(LEFT(SL.Size,LEN(SL.Size)-1))=1 THEN FORMAT(CONVERT(FLOAT,LEFT(SL.Size,LEN(SL.Size)-1)+'.5')+400000,'000000.00')
                            WHEN TRIM(SL.Size) LIKE N'%[ -]%' THEN FORMAT(ISNULL(TRY_PARSE(ISNULL(LEFT(TRIM(SL.Size),PATINDEX('%[ -]%',TRIM(SL.Size))-1),'') AS FLOAT)+400000,
                                                                   CHARINDEX(N'|'+LTRIM(RTRIM(LEFT(TRIM(SL.Size),PATINDEX('%[ -]%',TRIM(SL.Size))-1)))+N'|', @c_SizeList)+800000),'000000.00')
                            ELSE FORMAT(CHARINDEX(N'|'+LTRIM(RTRIM(SL.Size))+N'|', @c_SizeList)+800000,'000000.00')
                         END +'-'+ SL.Size )
   INTO #TEMP_SSEQ

   FROM (
      SELECT DocKey
           , Storerkey
           , LineGrouping
           , Size
           , SizeScaleSeq = MAX( SizeScaleSeq )
      FROM #TEMP_ORDET
      GROUP BY DocKey
             , Storerkey
             , LineGrouping
             , Size
   ) SL


   -----------------------
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
        , Deliverydate      = MAX ( OH.DeliveryDate )
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

        , BilltoKey         = RTRIM ( ISNULL( MAX( CASE WHEN LEFT(OH.BilltoKey, LEN(ORDET.ConsigneePrefix))=ORDET.ConsigneePrefix
                                           THEN SUBSTRING(OH.BilltoKey, LEN(ORDET.ConsigneePrefix)+1, LEN(OH.BillToKey))
                                           ELSE OH.BilltoKey END ), '' ) )
        , B_Company         = MAX ( ISNULL( RTRIM ( OH.B_Company ), '' ) )
        , B_Address1        = MAX ( ISNULL( OH.B_Address1, '' ) )
        , B_Address2        = MAX ( ISNULL( OH.B_Address2, '' ) )
        , B_Address3        = MAX ( ISNULL( OH.B_Address3, '' ) )
        , B_Address4        = MAX ( ISNULL( OH.B_Address4, '' ) )
        , B_Country         = MAX ( ISNULL( RTRIM ( OH.B_Country ), '' ) )
        , B_Contact1        = MAX ( ISNULL( RTRIM ( OH.B_Contact1 ), '' ) )
        , B_Phone1          = MAX ( ISNULL( RTRIM ( OH.B_Phone1 ), '' ) )

        , ConsigneeKey      = RTRIM ( ISNULL( MAX( CASE WHEN LEFT(OH.ConsigneeKey, LEN(ORDET.ConsigneePrefix))=ORDET.ConsigneePrefix
                                           THEN SUBSTRING(OH.ConsigneeKey, LEN(ORDET.ConsigneePrefix)+1, LEN(OH.ConsigneeKey))
                                           ELSE OH.ConsigneeKey END ), '' ) )
        , C_Company         = MAX ( ISNULL( RTRIM ( OH.C_Company ), '' ) )
        , C_Address1        = MAX ( ISNULL( OH.C_Address1, '' ) )
        , C_Address2        = MAX ( ISNULL( OH.C_Address2, '' ) )
        , C_Address3        = MAX ( ISNULL( OH.C_Address3, '' ) )
        , C_Address4        = MAX ( ISNULL( OH.C_Address4, '' ) )
        , C_Country         = MAX ( ISNULL( RTRIM ( OH.C_Country ), '' ) )
        , C_Contact1        = MAX ( ISNULL( RTRIM ( OH.C_Contact1 ), '' ) )
        , C_Phone1          = MAX ( ISNULL( RTRIM ( OH.C_Phone1 ), '' ) )

        , Notes             = MAX ( ISNULL( RTRIM ( OH.Notes ), '' ) )
        , Notes2            = MAX ( ISNULL( RTRIM ( OH.Notes2 ), '' ) )
        , Total_Carton      = MAX ( PAK.Total_Carton )

        , LineGrouping      = RTRIM ( ORDET.LineGrouping )
        , Line_No           = ROW_NUMBER() OVER(PARTITION BY ORDET.DocKey, COPY.Copies
                              ORDER BY ORDET.LineGrouping, FLOOR((SSEQ.SizeSeq-1)/@n_Col), ORDET.Style, ORDET.Color, ORDET.Measurement, ORDET.Unitprice)
        , Style             = RTRIM ( ORDET.Style )
        , Color             = RTRIM ( ORDET.Color )
        , Measurement       = RTRIM ( ORDET.Measurement )
        , Descr             = MAX ( RTRIM ( ORDET.Descr ) )
        , Unitprice         = ORDET.Unitprice
        , UOM               = MAX ( RTRIM ( ORDET.UOM ) )
        , Discount          = ORDET.Discount
        , Amount            = ORDET.Amount
        , SizeLine          = FLOOR((SSEQ.SizeSeq-1)/@n_Col)

        , Size01            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 0 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size02            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 1 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size03            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 2 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size04            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 3 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size05            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 4 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size06            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 5 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size07            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 6 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size08            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 7 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size09            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 8 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size10            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 9 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size11            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=10 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size12            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=11 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size13            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=12 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size14            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=13 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size15            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=14 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size16            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=15 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size17            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=16 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size18            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=17 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size19            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=18 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size20            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=19 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size21            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=20 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size22            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=21 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size23            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=22 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )
        , Size24            = MAX ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=23 THEN LTRIM(RTRIM(ORDET.Size)) ELSE '' END )

        , Qty01             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 0 THEN ORDET.Qty ELSE 0 END)
        , Qty02             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 1 THEN ORDET.Qty ELSE 0 END)
        , Qty03             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 2 THEN ORDET.Qty ELSE 0 END)
        , Qty04             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 3 THEN ORDET.Qty ELSE 0 END)
        , Qty05             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 4 THEN ORDET.Qty ELSE 0 END)
        , Qty06             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 5 THEN ORDET.Qty ELSE 0 END)
        , Qty07             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 6 THEN ORDET.Qty ELSE 0 END)
        , Qty08             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 7 THEN ORDET.Qty ELSE 0 END)
        , Qty09             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 8 THEN ORDET.Qty ELSE 0 END)
        , Qty10             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col= 9 THEN ORDET.Qty ELSE 0 END)
        , Qty11             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=10 THEN ORDET.Qty ELSE 0 END)
        , Qty12             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=11 THEN ORDET.Qty ELSE 0 END)
        , Qty13             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=12 THEN ORDET.Qty ELSE 0 END)
        , Qty14             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=13 THEN ORDET.Qty ELSE 0 END)
        , Qty15             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=14 THEN ORDET.Qty ELSE 0 END)
        , Qty16             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=15 THEN ORDET.Qty ELSE 0 END)
        , Qty17             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=16 THEN ORDET.Qty ELSE 0 END)
        , Qty18             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=17 THEN ORDET.Qty ELSE 0 END)
        , Qty19             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=18 THEN ORDET.Qty ELSE 0 END)
        , Qty20             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=19 THEN ORDET.Qty ELSE 0 END)
        , Qty21             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=20 THEN ORDET.Qty ELSE 0 END)
        , Qty22             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=21 THEN ORDET.Qty ELSE 0 END)
        , Qty23             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=22 THEN ORDET.Qty ELSE 0 END)
        , Qty24             = SUM ( CASE WHEN (SSEQ.SizeSeq-1)%@n_Col=23 THEN ORDET.Qty ELSE 0 END)

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

        , B_City            = MAX ( ISNULL( RTRIM ( OH.B_City ), '' ) )
        , C_City            = MAX ( ISNULL( RTRIM ( OH.C_City ), '' ) )
        , Type              = MAX ( ISNULL( RTRIM ( OH.Type ), '' ) )
        , ReferenceNo2      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo2 ), '') )
        , ReferenceNo3      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo3 ), '') )
        , ReferenceNo4      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo4 ), '') )
        , ReferenceNo5      = MAX ( ISNULL( RTRIM ( ORDET.ReferenceNo5 ), '') )
        , PickSlipNo        = MAX ( ISNULL( RTRIM ( ORDET.PickSlipNo ), '') )
        , Remark            = MAX ( ISNULL( RTRIM ( ORDET.Remark ), '') )
        , LineRemark        = MAX ( ISNULL( RTRIM ( ORDET.LineRemark ), '') )
        , LineRef1          = RTRIM ( ORDET.LineRef1 )
        , LineRef2          = RTRIM ( ORDET.LineRef2 )
        , LineRef3          = RTRIM ( ORDET.LineRef3 )
        , ConsolPick        = MAX ( ISNULL( RTRIM ( ORDET.ConsolPick ), '' ) )

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
        , Lbl_Style         = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Style') ) AS NVARCHAR(500))
        , Lbl_Color         = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Color') ) AS NVARCHAR(500))
        , Lbl_Meas          = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Meas') ) AS NVARCHAR(500))
        , Lbl_Descr         = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_Descr') ) AS NVARCHAR(500))
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
        , N_Xpos_Style      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Style') ) AS NVARCHAR(50))
        , N_Xpos_Color      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Color') ) AS NVARCHAR(50))
        , N_Xpos_Meas       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Meas') ) AS NVARCHAR(50))
        , N_Xpos_Descr      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Descr') ) AS NVARCHAR(50))
        , N_Xpos_Size       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_Size') ) AS NVARCHAR(50))
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
        , N_Xpos_ReceivedBy = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_ReceivedBy') ) AS NVARCHAR(50))
        , N_Xpos_TotalQty   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Xpos_TotalQty') ) AS NVARCHAR(50))
        , N_Ypos_ReceivedBy = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Ypos_ReceivedBy') ) AS NVARCHAR(50))
        , N_Width_LineNo    = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_LineNo') ) AS NVARCHAR(50))
        , N_Width_Style     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Style') ) AS NVARCHAR(50))
        , N_Width_Color     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Color') ) AS NVARCHAR(50))
        , N_Width_Meas      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Meas') ) AS NVARCHAR(50))
        , N_Width_Descr     = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Descr') ) AS NVARCHAR(50))
        , N_Width_Size      = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_Size') ) AS NVARCHAR(50))
        , N_Width_SizeGap   = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_SizeGap') ) AS NVARCHAR(50))
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
        , N_Width_ReceivedBy= CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_ReceivedBy') ) AS NVARCHAR(50))
        , N_Width_TotalQty  = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='N_Width_TotalQty') ) AS NVARCHAR(50))

        , N_NoOfSizeCol     = @n_Col
        , Copies            = COPY.Copies
        , CopyDescr         = CAST( MAX ( ISNULL( RTRIM ( COPY.CopyDescr ), '' ) ) AS NVARCHAR(500))

        , GrossAmount       = ORDET.GrossAmount
        , S_Fax2            = MAX ( ISNULL( LTRIM(RTRIM(STORER.Fax2)), '' ) )
        , S_B_Fax2          = MAX ( ISNULL( LTRIM(RTRIM(STORER.B_Fax2)),'' ) )
        , ReportTitle       = MAX ( RTRIM ( ORDET.ReportTitle ) )
        , LFLRefNo          = MAX ( ISNULL( RTRIM ( ORDET.LFLRefNo ), '') )
        , Lbl_BillTo        = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_BillTo') ) AS NVARCHAR(500))
        , Lbl_B_Phone       = CAST( RTRIM( (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='T_B_Phone') ) AS NVARCHAR(500))
        , Lbl_ShipTo        = CAST( RTRIM( (select top 1 b.ColValue
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

   FROM #TEMP_ORDET ORDET
   JOIN dbo.ORDERS     OH (NOLOCK) ON (ORDET.FirstOrderKey = OH.Orderkey)
   JOIN dbo.STORER STORER (NOLOCK) ON (OH.StorerKey = STORER.StorerKey)
   LEFT OUTER JOIN #TEMP_SSEQ SSEQ ON (ORDET.Storerkey = SSEQ.Storerkey AND ORDET.DocKey = SSEQ.DocKey
                                   AND ORDET.LineGrouping = SSEQ.LineGrouping AND ORDET.Size = SSEQ.Size)
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
          , ORDET.Style
          , ORDET.Color
          , ORDET.Measurement
          , ORDET.LineRef1
          , ORDET.LineRef2
          , ORDET.LineRef3
          , ORDET.Unitprice
          , ORDET.Discount
          , ORDET.Amount
          , ORDET.GrossAmount
          , FLOOR((SSEQ.SizeSeq-1)/@n_Col)

   ORDER BY SortOrderkey, SeqPS, SeqEOK, SeqOK, DocKey, Copies, Line_No

END

GO