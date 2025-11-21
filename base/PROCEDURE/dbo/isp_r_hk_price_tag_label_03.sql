SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_price_tag_label_03                         */
/* Creation Date: 14-May-2019                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: Price Tag for Timberland                                     */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_price_tag_label_03          */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_price_tag_label_03] (
       @as_storerkey  NVARCHAR(15)
     , @as_labelno    NVARCHAR(4000)
     , @cMode         NVARCHAR(10) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cDataWidnow NVARCHAR(40)

   SET @cDataWidnow = IIF(@cMode='2', 'r_hk_price_tag_label_03b', 'r_hk_price_tag_label_03')

   IF OBJECT_ID('tempdb..#TEMP_LABELNO') IS NOT NULL
      DROP TABLE #TEMP_LABELNO
   IF OBJECT_ID('tempdb..#TEMP_PACKDET') IS NOT NULL
      DROP TABLE #TEMP_PACKDET

   SELECT LabelNo = LTRIM(ColValue)
     INTO #TEMP_LABELNO
     FROM dbo.fnc_DelimSplit(',',REPLACE(@as_labelno,CHAR(13)+CHAR(10),','))
    WHERE ColValue<>''

   CREATE TABLE #TEMP_PACKDET (
      Storerkey    NVARCHAR(15) NULL
    , Orderkey     NVARCHAR(10) NULL
    , LabelNo      NVARCHAR(20) NULL
    , Sku          NVARCHAR(20) NULL
    , Country      NVARCHAR(30) NULL
    , Userdefine05 NVARCHAR(18) NULL
    , Currency     NVARCHAR(18) NULL
    , CurrencyCode NVARCHAR(30) NULL
    , Price        MONEY        NULL
    , Price_outlet MONEY        NULL
    , TaxNote      NVARCHAR(30) NULL
    , Orderrefno   NVARCHAR(50) NULL
    , Style        NVARCHAR(15) NULL
    , Color        NVARCHAR(10) NULL
    , Size         NVARCHAR(10) NULL
    , Measurement  NVARCHAR(5)  NULL
    , Altsku       NVARCHAR(20) NULL
    , Qty          INT          NULL
   )


   INSERT INTO #TEMP_PACKDET(LabelNo, Sku, Storerkey, Orderkey, Country, Price_outlet, Orderrefno, Style, Color, Size, Measurement, Altsku, Qty)
   SELECT LabelNo      = RTRIM( PD.LabelNo )
        , Sku          = RTRIM( PD.Sku )
        , Storerkey    = RTRIM( MAX( OH.Storerkey ) )
        , Orderkey     = RTRIM( MAX( OH.Orderkey ) )
        , Country      = RTRIM( MAX( OH.C_Country ) )
        , Price_outlet = MAX( SKU.Price )
        , Orderrefno   = RTRIM( MAX( OH.ExternOrderKey ) )
        , Style        = RTRIM( MAX( CASE WHEN SUBSTRING(SKU.Style,5,1) = '0'
                              THEN SUBSTRING(SKU.Style,CHARINDEX('-',SKU.Style)+2,15)
                              ELSE SUBSTRING(SKU.Style,CHARINDEX('-',SKU.Style)+1,15)
                         END ) )
        , Color        = RTRIM( MAX( SKU.Color ) )
        , Size         = RTRIM( MAX( SKU.Size ) )
        , Measurement  = RTRIM( MAX( SKU.Measurement ) )
        , Altsku       = RTRIM( MAX( Sku.Altsku ) )
        , Qty          = SUM( PD.Qty )
    FROM dbo.ORDERS     OH (NOLOCK)
    JOIN dbo.PACKHEADER PH (NOLOCK) ON OH.Orderkey = PH.Orderkey
    JOIN dbo.PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno
    JOIN dbo.SKU       SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku
    JOIN #TEMP_LABELNO  LN ON PD.LabelNo=LN.LabelNo

   WHERE OH.Storerkey=@as_storerkey
     AND OH.Status<>'CANC'
     AND PD.Qty>0

   GROUP BY PD.LabelNo
          , PD.Sku

   -- Update Orderdetail Info
   UPDATE T
      SET Userdefine05 = X.Userdefine05
        , Currency     = X.Currency
        , Price        = X.Price
        , CurrencyCode = X.CurrencyCode
        , TaxNote      = X.TaxNote
   FROM #TEMP_PACKDET T
   JOIN (
      SELECT Orderkey     = T.Orderkey
           , Storerkey    = T.Storerkey
           , Sku          = T.Sku
           , Userdefine05 = RTRIM( MAX(OD.Userdefine05) )
           , Currency     = RTRIM( MAX(OD.Userdefine04) )
           , Price        = MAX(TRY_PARSE(ISNULL(OD.Userdefine02,'') AS MONEY))
           , CurrencyCode = RTRIM( CAST( ISNULL((select top 1 b.ColValue
                             from dbo.fnc_DelimSplit(MAX(RptCfg.Delim),MAX(RptCfg.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg.Delim),MAX(RptCfg.Notes2)) b
                             where a.SeqNo=b.SeqNo and a.ColValue=MAX(OD.Userdefine04) ), MAX(OD.Userdefine04)) AS NVARCHAR(30)) )
           , TaxNote      = RTRIM( CAST( ISNULL((select top 1 b.ColValue
                             from dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes)) a, dbo.fnc_DelimSplit(MAX(RptCfg2.Delim),MAX(RptCfg2.Notes2)) b
                             where a.SeqNo=b.SeqNo and a.ColValue=MAX(OD.Userdefine04) ), '') AS NVARCHAR(30)) )
      FROM #TEMP_PACKDET T
      JOIN dbo.ORDERDETAIL OD(NOLOCK) ON T.Orderkey=OD.Orderkey AND T.Storerkey=OD.Storerkey AND T.Sku=OD.Sku
      LEFT JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@cDataWidnow AND Short='Y' AND UDF02='Currency'
      ) RptCfg
      ON RptCfg.Storerkey=T.Storerkey AND RptCfg.SeqNo=1

      LEFT JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@cDataWidnow AND Short='Y' AND UDF02='TaxNote'
      ) RptCfg2
      ON RptCfg2.Storerkey=T.Storerkey AND RptCfg2.SeqNo=1

      GROUP BY T.Orderkey
             , T.Storerkey
             , T.Sku
   ) X ON T.Orderkey=X.Orderkey AND T.Storerkey=X.Storerkey AND T.Sku=X.Sku


   -- Result Set
   SELECT PrintSeqRev = Y.PrintSeq + POWER(-1, Y.PrintSeq + 1 + MAX(Y.PrintSeq) OVER(PARTITION BY ''))
        , Y.*
   FROM (
      SELECT PrintSeq  = ROW_NUMBER() OVER(ORDER BY LabelNo, SKU, Country, SeqNo)
           , X.*
      FROM (
         SELECT SeqNo = SeqTbl.Rowref, T.*
           FROM #TEMP_PACKDET T
           JOIN dbo.SEQKey  SeqTbl(NOLOCK) ON SeqTbl.Rowref <= T.Qty
         UNION ALL
         SELECT 0, * FROM #TEMP_PACKDET T
      ) X
   ) Y
   ORDER BY PrintSeqRev DESC
END

GO