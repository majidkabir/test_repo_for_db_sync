SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_price_tag_label_06_rdt                     */
/* Creation Date: 30-May-2023                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Tumi B2B price label                                         */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_price_tag_label_06_rdt      */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2023-06-06   Michael  v1.1 WMS-22721 Add Conso Order handling         */
/* 2023-07-10   Michael  v1.2 WMS-22721 Change Date from OH.Userdefine07 */
/*                            to OH.OrderDate in price searching         */
/* 2023-08-10   Michael  v1.3 Add field ALTSKU_BC                        */
/* 2023-08-15   Michael  v1.4 WMS-23424 Add parameters @as_pokey, @as_sku*/
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_price_tag_label_06_rdt] (
       @as_pickslipno       NVARCHAR(10)
     , @as_cartonnofrom     NVARCHAR(10)
     , @as_cartonnoto       NVARCHAR(10)
     , @as_pokey            NVARCHAR(10) = ''
     , @as_sku              NVARCHAR(20) = ''
)
AS
BEGIN
   SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_PickslipNo     NVARCHAR(10) = @as_pickslipno
         , @n_CartonNoFrom   INT = TRY_PARSE(ISNULL(@as_cartonnofrom,'') AS INT)
         , @n_CartonNoTo     INT = TRY_PARSE(ISNULL(@as_cartonnoto  ,'') AS INT)
         , @c_Orderkey       NVARCHAR(10)  = ''
         , @c_Loadkey        NVARCHAR(10)  = ''
         , @b_ConsoOrder     INT = 0
         , @c_ExecStatements NVARCHAR(MAX) = ''

   IF ISNULL(@as_pokey,'')<>''
   BEGIN
      SET @c_ExecStatements =
         N'SELECT PickslipNo         = ISNULL(RTRIM(PAK.PickslipNo),'''')'
        +      ', CartonNo           = CAST(0 AS INT)'
        +      ', LabelNo            = CAST('''' AS NVARCHAR(20))'
        +      ', Storerkey          = ISNULL(RTRIM(PAK.Storerkey),'''')'
        +      ', Sku                = ISNULL(RTRIM(PAK.Sku),'''')'
        +      ', TumiExpArrivalDate = PAK.TumiExpArrivalDate'
        +      ', ALTSKU             = ISNULL(RTRIM(PAK.ALTSKU),'''')'
        +      ', Descr              = ISNULL(RTRIM(PAK.Descr),'''')'
        +      ', Style              = ISNULL(RTRIM(PAK.Style),'''')'
        +      ', Color              = ISNULL(RTRIM(PAK.Color),'''')'
        +      ', TumiSKU            = ISNULL(RTRIM(PAK.TumiSKU),'''')'
        +      ', MaterialGrpDescr   = ISNULL(RTRIM(PAK.MaterialGrpDescr),'''')'
        +      ', Qty                = PAK.Qty'
        +' INTO #TEMP_PAK'
        +' FROM ('
        +   ' SELECT PickslipNo         = PH.POKey'
        +         ', Storerkey          = PD.Storerkey'
        +         ', Sku                = PD.Sku'
        +         ', TumiExpArrivalDate = MAX(CONVERT(DATE, PH.PODate))'
        +         ', ALTSKU             = MAX(SKU.ALTSKU)'
        +         ', Descr              = MAX(SKU.Descr)'
        +         ', Style              = MAX(SKU.Style)'
        +         ', Color              = MAX(SKU.Color)'
        +         ', TumiSKU            = MAX(SKU.BUSR2)'
        +         ', MaterialGrpDescr   = MAX(CL.Description)'
        +         ', Qty                = SUM(PD.QtyOrdered)'
        +   ' FROM dbo.PO             PH (NOLOCK)'
        +   ' JOIN dbo.PODETAIL       PD (NOLOCK) ON PH.POKey = PD.POKey'
        +   ' JOIN dbo.SKU            SKU(NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +   ' LEFT JOIN dbo.CODELKUP  CL (NOLOCK) ON CL.Listname = ''TUMATGRP'' AND SKU.Storerkey = CL.Storerkey AND SKU.SUSR5 = CL.Code'
        +   ' WHERE PH.POKey = ''' + REPLACE(@as_pokey, '''', '''''') + ''''

      IF ISNULL(@as_sku,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
           +  ' AND PD.Sku=''' + REPLACE(@as_sku, '''', '''''') + ''''

      SET @c_ExecStatements = @c_ExecStatements
        +   ' GROUP BY PH.POKey, PD.Storerkey, PD.SKU'
        + ') PAK'
   
   
      SET @c_ExecStatements = @c_ExecStatements
        +' SELECT PAK.*'
        +      ', RetailCurrency    = CASE WHEN RETAIL.Price IS NOT NULL THEN RTRIM(RETAIL.Currency)'
        +                                ' WHEN ORD.UnitPrice <> 0       THEN RTRIM(ORD.Currency)'
        +                           ' END'
        +      ', RetailPrice       = CASE WHEN RETAIL.Price IS NOT NULL THEN RETAIL.Price'
        +                                ' WHEN ORD.UnitPrice <> 0       THEN ORD.UnitPrice'
        +                           ' END'
        +      ', PromCurrency      = CASE WHEN PROM.Price IS NOT NULL   THEN RTRIM(PROM.Currency) END'
        +      ', PromPrice         = CASE WHEN PROM.Price IS NOT NULL   THEN PROM.Price END'
        +      ', SeqNo             = SQ.Rowref'
        +      ', ALTSKU_BC         = dbo.fn_Encode_IDA_Code128(PAK.ALTSKU)'
        +' FROM #TEMP_PAK PAK'
        +' LEFT JOIN ('
        +   ' SELECT PickslipNo     = PH.POKey'
        +         ', Storerkey      = PD.Storerkey'
        +         ', Sku            = PD.Sku'
        +         ', UnitPrice      = CONVERT(MONEY, 0)'
        +         ', Currency       = MAX(PH.POGroup)'
        +   ' FROM dbo.PO          PH (NOLOCK)'
        +   ' JOIN dbo.PODETAIL    PD (NOLOCK) ON PH.POKey = PD.POKey'
        +   ' WHERE PH.POKey = ''' + REPLACE(@as_pokey, '''', '''''') + ''''

      IF ISNULL(@as_sku,'')<>''
         SET @c_ExecStatements = @c_ExecStatements
           +  ' AND PD.Sku=''' + REPLACE(@as_sku, '''', '''''') + ''''

      SET @c_ExecStatements = @c_ExecStatements
        +   ' GROUP BY PH.POKey, PD.Storerkey, PD.Sku'
        + ') ORD ON PAK.PickslipNo = ORD.PickslipNo AND PAK.Storerkey = ORD.Storerkey AND PAK.Sku = ORD.Sku'
   
        +' OUTER APPLY ('
        +   ' SELECT TOP 1'
        +          ' Price    = TRY_PARSE( ISNULL(SC.UserDefine09,'''') AS MONEY)'
        +         ', Currency = SC.Userdefine13'
        +   ' FROM dbo.SKUCONFIG SC (NOLOCK)'
        +   ' WHERE SC.Storerkey    = PAK.Storerkey'
        +     ' AND SC.Sku          = PAK.Sku'
        +     ' AND SC.Userdefine01 = ''01'''
        +     ' AND SC.Userdefine13 = ORD.Currency'
        +     ' AND SC.Userdefine06 <= PAK.TumiExpArrivalDate'
        +     ' AND SC.Userdefine07 >= PAK.TumiExpArrivalDate'
        +   ' ORDER BY SC.Userdefine06 DESC'
        + ') RETAIL'
   
        +' OUTER APPLY ('
        +   ' SELECT TOP 1'
        +          ' Price    = TRY_PARSE( ISNULL(SC.UserDefine09,'''') AS MONEY)'
        +         ', Currency = SC.Userdefine13'
        +   ' FROM dbo.SKUCONFIG SC (NOLOCK)'
        +   ' WHERE SC.Storerkey    = PAK.Storerkey'
        +     ' AND SC.Sku          = PAK.Sku'
        +     ' AND SC.Userdefine01 = ''P1'''
        +     ' AND SC.Userdefine13 = ORD.Currency'
        +     ' AND SC.Userdefine06 <= PAK.TumiExpArrivalDate'
        +     ' AND SC.Userdefine07 >= PAK.TumiExpArrivalDate'
        +   ' ORDER BY SC.Userdefine06 DESC'
        + ') PROM'
   
        +' JOIN dbo.SEQKey SQ(NOLOCK) ON SQ.Rowref <= PAK.Qty'
   END
   ELSE
   BEGIN
      SELECT @c_Orderkey    = MAX(PH.Orderkey)
           , @c_Loadkey     = MAX(PH.Loadkey)
      FROM dbo.PACKHEADER PH(NOLOCK)
      WHERE PH.Pickslipno = @c_PickslipNo
   
      SET @b_ConsoOrder = CASE WHEN ISNULL(@c_Orderkey,'')<>'' THEN 0 ELSE 1 END
   
      SET @c_ExecStatements =
         N'SELECT PickslipNo         = ISNULL(RTRIM(PAK.PickslipNo),'''')'
        +      ', CartonNo           = PAK.CartonNo'
        +      ', LabelNo            = ISNULL(RTRIM(PAK.LabelNo),'''')'
        +      ', Storerkey          = ISNULL(RTRIM(PAK.Storerkey),'''')'
        +      ', Sku                = ISNULL(RTRIM(PAK.Sku),'''')'
        +      ', TumiExpArrivalDate = PAK.TumiExpArrivalDate'
        +      ', ALTSKU             = ISNULL(RTRIM(PAK.ALTSKU),'''')'
        +      ', Descr              = ISNULL(RTRIM(PAK.Descr),'''')'
        +      ', Style              = ISNULL(RTRIM(PAK.Style),'''')'
        +      ', Color              = ISNULL(RTRIM(PAK.Color),'''')'
        +      ', TumiSKU            = ISNULL(RTRIM(PAK.TumiSKU),'''')'
        +      ', MaterialGrpDescr   = ISNULL(RTRIM(PAK.MaterialGrpDescr),'''')'
        +      ', Qty                = PAK.Qty'
        +' INTO #TEMP_PAK'
        +' FROM ('
        +   ' SELECT PickslipNo         = PH.PickslipNo'
        +         ', Orderkey           = MAX(OH.Orderkey)'
        +         ', CartonNo           = PD.CartonNo'
        +         ', LabelNo            = PD.LabelNo'
        +         ', Storerkey          = PD.Storerkey'
        +         ', Sku                = PD.Sku'
        +         ', TumiExpArrivalDate = MAX(CONVERT(DATE, OH.OrderDate))'
        +         ', ALTSKU             = MAX(SKU.ALTSKU)'
        +         ', Descr              = MAX(SKU.Descr)'
        +         ', Style              = MAX(SKU.Style)'
        +         ', Color              = MAX(SKU.Color)'
        +         ', TumiSKU            = MAX(SKU.BUSR2)'
        +         ', MaterialGrpDescr   = MAX(CL.Description)'
        +         ', Qty                = SUM(PD.Qty)'
        +   ' FROM dbo.PACKHEADER     PH (NOLOCK)'
   
      IF @b_ConsoOrder=0
         SET @c_ExecStatements = @c_ExecStatements
           +' JOIN dbo.ORDERS  OH(NOLOCK) ON PH.Orderkey = OH.Orderkey'
      ELSE
         SET @c_ExecStatements = @c_ExecStatements
           +' JOIN dbo.ORDERS  OH(NOLOCK) ON PH.Loadkey = OH.Loadkey AND ISNULL(PH.Loadkey,'''')<>'''' AND ISNULL(PH.Orderkey,'''')='''''
   
      SET @c_ExecStatements = @c_ExecStatements
        +   ' JOIN dbo.PACKDETAIL     PD (NOLOCK) ON PH.PickslipNo = PD.PickslipNo'
        +   ' JOIN dbo.SKU            SKU(NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +   ' LEFT JOIN dbo.CODELKUP  CL (NOLOCK) ON CL.Listname = ''TUMATGRP'' AND SKU.Storerkey = CL.Storerkey AND SKU.SUSR5 = CL.Code'
        +   ' WHERE PH.PickslipNo = ''' + REPLACE(@c_PickslipNo, '''', '''''') + ''''
        +     ' AND PD.CartonNo  >= ' + ISNULL(CONVERT(NVARCHAR(10), @n_CartonNoFrom), 'NULL')
        +     ' AND PD.CartonNo  <= ' + ISNULL(CONVERT(NVARCHAR(10), @n_CartonNoTo  ), 'NULL')
        +   ' GROUP BY PH.PickSlipNo, PD.CartonNo, PD.LabelNo, PD.Storerkey, PD.SKU'
        + ') PAK'
   
   
      SET @c_ExecStatements = @c_ExecStatements
        +' SELECT PAK.*'
        +      ', RetailCurrency    = CASE WHEN RETAIL.Price IS NOT NULL THEN RTRIM(RETAIL.Currency)'
        +                                ' WHEN ORD.UnitPrice <> 0       THEN RTRIM(ORD.Currency)'
        +                           ' END'
        +      ', RetailPrice       = CASE WHEN RETAIL.Price IS NOT NULL THEN RETAIL.Price'
        +                                ' WHEN ORD.UnitPrice <> 0       THEN ORD.UnitPrice'
        +                           ' END'
        +      ', PromCurrency      = CASE WHEN PROM.Price IS NOT NULL   THEN RTRIM(PROM.Currency) END'
        +      ', PromPrice         = CASE WHEN PROM.Price IS NOT NULL   THEN PROM.Price END'
        +      ', SeqNo             = SQ.Rowref'
        +      ', ALTSKU_BC         = dbo.fn_Encode_IDA_Code128(PAK.ALTSKU)'
        +' FROM #TEMP_PAK PAK'
        +' LEFT JOIN ('
        +   ' SELECT PickslipNo     = PH.PickslipNo'
        +         ', Storerkey      = OD.Storerkey'
        +         ', Sku            = OD.Sku'
        +         ', UnitPrice      = CONVERT(MONEY, MAX(OD.UnitPrice))'
        +         ', Currency       = MAX(OD.Userdefine01)'
        +   ' FROM dbo.PACKHEADER     PH (NOLOCK)'
   
      IF @b_ConsoOrder=0
         SET @c_ExecStatements = @c_ExecStatements
           +' JOIN dbo.ORDERS  OH(NOLOCK) ON PH.Orderkey = OH.Orderkey'
      ELSE
         SET @c_ExecStatements = @c_ExecStatements
           +' JOIN dbo.ORDERS  OH(NOLOCK) ON PH.Loadkey = OH.Loadkey AND ISNULL(PH.Loadkey,'''')<>'''' AND ISNULL(PH.Orderkey,'''')='''''
   
      SET @c_ExecStatements = @c_ExecStatements
        +   ' JOIN dbo.ORDERDETAIL    OD (NOLOCK) ON OD.Orderkey = OH.Orderkey'
        +   ' WHERE PH.PickslipNo = ''' + REPLACE(@c_PickslipNo, '''', '''''') + ''''
        +   ' GROUP BY PH.PickslipNo, OD.Storerkey, OD.Sku'
        + ') ORD ON PAK.PickslipNo = ORD.PickslipNo AND PAK.Storerkey = ORD.Storerkey AND PAK.Sku = ORD.Sku'
   
        +' OUTER APPLY ('
        +   ' SELECT TOP 1'
        +          ' Price    = TRY_PARSE( ISNULL(SC.UserDefine09,'''') AS MONEY)'
        +         ', Currency = SC.Userdefine13'
        +   ' FROM dbo.SKUCONFIG SC (NOLOCK)'
        +   ' WHERE SC.Storerkey    = PAK.Storerkey'
        +     ' AND SC.Sku          = PAK.Sku'
        +     ' AND SC.Userdefine01 = ''01'''
        +     ' AND SC.Userdefine13 = ORD.Currency'
        +     ' AND SC.Userdefine06 <= PAK.TumiExpArrivalDate'
        +     ' AND SC.Userdefine07 >= PAK.TumiExpArrivalDate'
        +   ' ORDER BY SC.Userdefine06 DESC'
        + ') RETAIL'
   
        +' OUTER APPLY ('
        +   ' SELECT TOP 1'
        +          ' Price    = TRY_PARSE( ISNULL(SC.UserDefine09,'''') AS MONEY)'
        +         ', Currency = SC.Userdefine13'
        +   ' FROM dbo.SKUCONFIG SC (NOLOCK)'
        +   ' WHERE SC.Storerkey    = PAK.Storerkey'
        +     ' AND SC.Sku          = PAK.Sku'
        +     ' AND SC.Userdefine01 = ''P1'''
        +     ' AND SC.Userdefine13 = ORD.Currency'
        +     ' AND SC.Userdefine06 <= PAK.TumiExpArrivalDate'
        +     ' AND SC.Userdefine07 >= PAK.TumiExpArrivalDate'
        +   ' ORDER BY SC.Userdefine06 DESC'
        + ') PROM'
   
        +' JOIN dbo.SEQKey SQ(NOLOCK) ON SQ.Rowref <= PAK.Qty'
   END

   EXEC sp_ExecuteSql @c_ExecStatements
END

GO