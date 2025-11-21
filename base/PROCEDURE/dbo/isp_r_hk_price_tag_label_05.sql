SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_price_tag_label_05                         */
/* Creation Date: 07-Apr-2022                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Price Tag for Bath & Body Works (BBW)                        */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_price_tag_label_05a,b,c     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2022-06-06   Michael  1.1  Add SHOWFIELD: DisableLabelSizeMatch       */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_price_tag_label_05] (
        @as_Storerkey NVARCHAR(15)
      , @as_LabelNo   NVARCHAR(20)
      , @as_Sku       NVARCHAR(20)
      , @as_Qty       NVARCHAR(10)
      , @as_LabelSize NVARCHAR(10)   -- (1 = 4.8 x 2.5 cm), (2 = 3.8 x 2.0 cm), (3 = 3.5 x 1.8 cm)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

/* CODELKUP.REPORTCFG
   [MAPVALUE]
      Currency

   [SHOWFIELD]
      DisableLabelSizeMatch
*/
   DECLARE @c_DataWindow            NVARCHAR(40) = 'r_hk_price_tag_label_05'
         , @n_Qty                   INT          = ISNULL(TRY_PARSE(ISNULL(@as_Qty,'') AS INT),0)
         , @c_ExecStatements        NVARCHAR(MAX)
         , @c_StorerKey             NVARCHAR(15)
         , @c_SkuGroup              NVARCHAR(10)
         , @c_UDF02                 NVARCHAR(60)
         , @b_DisableLabelSizeMatch INT

   IF OBJECT_ID('tempdb..#TEMP_PACKDET') IS NOT NULL
      DROP TABLE #TEMP_PACKDET

   CREATE TABLE #TEMP_PACKDET (
      Orderkey        NVARCHAR(10)  NULL
    , LabelNo         NVARCHAR(20)  NULL
    , Storerkey       NVARCHAR(15)  NULL
    , Sku             NVARCHAR(20)  NULL
    , ManufacturerSku NVARCHAR(20)  NULL
    , Descr           NVARCHAR(60)  NULL
    , Size            NVARCHAR(10)  NULL
    , Color           NVARCHAR(10)  NULL
    , BUSR1           NVARCHAR(30)  NULL
    , Qty             INT           NULL
    , Currency        NVARCHAR(10)  NULL
    , UnitPrice       FLOAT         NULL
    , Barcode         NVARCHAR(100) NULL
   )

   DECLARE C_CURSOR_SKU CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
          StorerKey = RTRIM(PD.StorerKey)
        , SkuGroup  = RTRIM(SKU.SkuGroup)
        , UDF02     = RTRIM(CLK.UDF02)
   FROM dbo.PACKDETAIL PD (NOLOCK)
   JOIN dbo.SKU        SKU(NOLOCK) ON PD.StorerKey = SKU.StorerKey AND PD.Sku = SKU.Sku
   JOIN dbo.CODELKUP   CLK(NOLOCK) ON CLK.ListName='BBWSKUGRP' AND SKU.Storerkey=CLK.Storerkey AND SKU.SKUGROUP=CLK.Code AND CLK.UDF01='Y'
   WHERE PD.Storerkey = @as_Storerkey
     AND PD.LabelNo   = @as_LabelNo
     AND (ISNULL(@as_Sku,'')='' OR PD.Sku = @as_Sku)
     AND ISNULL(SKU.BUSR1,'')<>''
   ORDER BY 1,2

   OPEN C_CURSOR_SKU

   WHILE 1=1
   BEGIN
      FETCH NEXT FROM C_CURSOR_SKU INTO @c_StorerKey, @c_SkuGroup, @c_UDF02

      IF @@FETCH_STATUS<>0
         BREAK

      SELECT TOP 1
             @b_DisableLabelSizeMatch = CASE WHEN ','+RTRIM(Notes)+',' LIKE '%,DisableLabelSizeMatch,%' THEN 1 ELSE 0 END
        FROM dbo.CodeLkup (NOLOCK)
       WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@c_DataWindow AND Short='Y'
         AND Storerkey = @c_Storerkey
       ORDER BY Code2

      SET @c_ExecStatements =
         N'INSERT INTO #TEMP_PACKDET(OrderKey, LabelNo, Storerkey, Sku, ManufacturerSku, Descr, Size, Color, BUSR1, Qty, Barcode)'
        +' SELECT OrderKey        = RTRIM( PH.OrderKey )'
        +      ', LabelNo         = RTRIM( PD.LabelNo )'
        +      ', StorerKey       = RTRIM( PD.StorerKey )'
        +      ', Sku             = RTRIM( PD.Sku )'
        +      ', ManufacturerSku = RTRIM( MAX(SKU.ManufacturerSku) )'
        +      ', Descr           = RTRIM( MAX(SKU.Descr) )'
        +      ', Size            = RTRIM( MAX(SKU.Size) )'
        +      ', Color           = RTRIM( MAX(SKU.Color) )'
        +      ', BUSR1           = RTRIM( MAX(SKU.BUSR1) )'
        +      ', Qty             = ' + CASE WHEN ISNULL(@as_Sku,'')='' THEN 'SUM(PD.Qty)' ELSE CONVERT(NVARCHAR(10),@n_Qty) END
        +      ', Barcode         = dbo.fn_Encode_IDA_Code128(RTRIM(MAX(SKU.ManufacturerSku)))'
        +' FROM dbo.PACKHEADER PH (NOLOCK)'
        +' JOIN dbo.PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo'
        +' JOIN dbo.SKU        SKU(NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku'
        +' JOIN dbo.CODELKUP   CLK(NOLOCK) ON CLK.ListName = ''BBWSKUGRP'' AND SKU.Storerkey = CLK.Storerkey AND SKU.SkuGroup = CLK.Code AND CLK.UDF01 = ''Y'''
        +' WHERE PD.Storerkey = ''' + REPLACE(ISNULL(@c_StorerKey,''),'''','''''') + ''''
        +  ' AND PD.LabelNo = ''' + REPLACE(ISNULL(@as_LabelNo,''),'''','''''') + ''''
        +  CASE WHEN ISNULL(@as_Sku,'')='' THEN '' ELSE ' AND PD.Sku='''+REPLACE(ISNULL(@as_Sku,''),'''','''''')+'''' END
        +  CASE WHEN @b_DisableLabelSizeMatch=1 OR ISNULL(@as_LabelSize,'')='' THEN '' ELSE ' AND SKU.BUSR1=''' + REPLACE(ISNULL(@as_LabelSize,''),'''','''''') + '''' END
        +  ' AND SKU.SkuGroup = ''' + REPLACE(ISNULL(@c_SkuGroup,''),'''','''''') + ''''
        +  CASE WHEN ISNULL(@c_UDF02,'')='' THEN '' ELSE ' AND (' + ISNULL(@c_UDF02,'') + ')' END
        +' GROUP BY PH.OrderKey'
        +        ', PD.LabelNo'
        +        ', PD.StorerKey'
        +        ', PD.Sku'

      EXEC sp_ExecuteSQL @c_ExecStatements
   END
   CLOSE C_CURSOR_SKU
   DEALLOCATE C_CURSOR_SKU


   -- Update Orderdetail Info
   UPDATE T
      SET UnitPrice    = X.UnitPrice
        , Currency     = ISNULL(X.Currency, 'HKD')
   FROM #TEMP_PACKDET T
   JOIN (
      SELECT Orderkey     = T.Orderkey
           , Storerkey    = T.Storerkey
           , Sku          = T.Sku
           , UnitPrice    = MAX(OD.UnitPrice)
           , Currency     = CAST( RTRIM( (select top 1 b.ColValue
                             from dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg3.Delim),MAX(RptCfg3.Notes2)) b
                             where a.SeqNo=b.SeqNo and a.ColValue='Currency') ) AS NVARCHAR(10))

      FROM #TEMP_PACKDET T
      JOIN dbo.ORDERDETAIL OD(NOLOCK) ON T.Orderkey=OD.Orderkey AND T.Storerkey=OD.Storerkey AND T.Sku=OD.Sku

      LEFT JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@c_DataWindow AND Short='Y'
      ) RptCfg3
      ON RptCfg3.Storerkey=T.Storerkey AND RptCfg3.SeqNo=1

      GROUP BY T.Orderkey
             , T.Storerkey
             , T.Sku
   ) X ON T.Orderkey=X.Orderkey AND T.Storerkey=X.Storerkey AND T.Sku=X.Sku


   -- Result Set
   SELECT PrintSeqRev = Y.PrintSeq + POWER(-1, Y.PrintSeq + 1 + MAX(Y.PrintSeq) OVER(PARTITION BY ''))
        , Y.*
   FROM (
      SELECT PrintSeq  = ROW_NUMBER() OVER(ORDER BY LabelNo, SKU, SeqNo)
           , X.*
      FROM (
         SELECT SeqNo = SeqTbl.Rowref
              , T.Orderkey
              , T.LabelNo
              , T.Storerkey
              , T.Sku
              , T.ManufacturerSku
              , T.Descr
              , T.Size
              , T.Color
              , T.BUSR1
              , T.Qty
              , T.Currency
              , T.UnitPrice
              , T.Barcode
         FROM #TEMP_PACKDET T
         JOIN dbo.SEQKey  SeqTbl(NOLOCK) ON SeqTbl.Rowref <= T.Qty + T.Qty % 2
      ) X
   ) Y
   ORDER BY PrintSeqRev DESC
END

GO