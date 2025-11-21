SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_delivery_note_02                           */
/* Creation Date: 06-Mar-2018                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: NIKE Delivery Note (Conso)                                   */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_delivery_note_02            */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 06/03/2018   ML       1.1  18012-CR - Add total qty per order in      */
/*                            section 2                                  */
/* 30/04/2018   ML       1.2  Add ExternOrderkey barcode in section 1 & 2*/
/* 23/07/2020   ML       1.3  Performance tunning                        */
/* 01/02/2021   ML       1.4  WMS-16288 - Add Parm DeliveryDate          */
/* 25/11/2021   ML       1.5  WMS-18440 - Nike SEC - change the delivery */
/*                                        note layout                    */
/* 23/03/2022   ML       1.6  Add NULL to Temp Table                     */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_delivery_note_02] (
       @as_storerkey     NVARCHAR(18)
     , @as_wavekey       NVARCHAR(4000) = ''
     , @as_loadkey       NVARCHAR(4000) = ''
     , @as_deliverydate  NVARCHAR(20)   = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_WARNINGS OFF

   DECLARE @b_FromRCMRpt     INT
         , @c_ExecStatements NVARCHAR(MAX)
         , @c_ExecArguments  NVARCHAR(MAX)

   IF @as_wavekey='0' AND @as_loadkey = 'ZZZZZZZZZZ'
   AND LEN(@as_storerkey)=10 AND @as_storerkey LIKE '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
   BEGIN
      SELECT @b_FromRCMRpt  = 1
           , @as_wavekey    = @as_storerkey
           , @as_storerkey  = CHAR(9)
           , @as_loadkey    = ''
   END


   DECLARE @n_Col         INT
         , @n_Col2        INT
         , @c_DataWindow  NVARCHAR(40) = 'r_hk_delivery_note_02'

   SELECT @n_Col  = 22
        , @n_Col2 = 6    -- ML01

   IF OBJECT_ID('tempdb..#TEMP_WAVEKEY') IS NOT NULL
      DROP TABLE #TEMP_WAVEKEY
   IF OBJECT_ID('tempdb..#TEMP_LOADKEY') IS NOT NULL
      DROP TABLE #TEMP_LOADKEY
   IF OBJECT_ID('tempdb..#TEMP_ORDERKEY') IS NOT NULL
      DROP TABLE #TEMP_ORDERKEY

   SELECT DISTINCT value = LTRIM(RTRIM(value))
   INTO #TEMP_WAVEKEY
   FROM STRING_SPLIT(REPLACE(ISNULL(@as_wavekey,''),CHAR(13)+CHAR(10),','),',')
   WHERE value<>''

   SELECT DISTINCT value = LTRIM(RTRIM(value))
   INTO #TEMP_LOADKEY
   FROM STRING_SPLIT(REPLACE(ISNULL(@as_loadkey,''),CHAR(13)+CHAR(10),','),',')
   WHERE value<>''

   CREATE TABLE #TEMP_ORDERKEY (
        Orderkey         NVARCHAR(10) NULL
      , ExternOrderkey   NVARCHAR(50) NULL
      , Loadkey          NVARCHAR(10) NULL
      , DeliveryDate     DATE         NULL
      , RptVersion       NVARCHAR(10) NULL
   )

   -- Get Orderkey
   SET @c_ExecStatements =
       N'INSERT INTO #TEMP_ORDERKEY (Orderkey, ExternOrderkey, Loadkey, DeliveryDate, RptVersion)'
     + ' SELECT *'
     + ' FROM ('
     +    ' SELECT DISTINCT'
     +           ' Orderkey       = OH.Orderkey'
     +          ', ExternOrderkey = OH.ExternOrderkey'
     +          ', Loadkey        = OH.Loadkey'
     +          ', DeliveryDate   = CONVERT(DATE, FIRST_VALUE(OH.DeliveryDate) OVER(PARTITION BY OH.Loadkey ORDER BY OH.ExternOrderkey))'
     +          ', RptVersion     = CASE WHEN OH.AddDate >='
     +                                ' (select top 1 TRY_PARSE(ISNULL(b.ColValue,'''') AS DATETIME) from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b'
     +                                 ' where a.SeqNo=b.SeqNo and a.ColValue=''V2_EffectiveDate'')'
     +                            ' THEN ''V2'' ELSE ''V1'' END'
     +    ' FROM dbo.ORDERS OH WITH (NOLOCK)'
     +    ' LEFT JOIN ('
     +       ' SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))'
     +             ', SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)'
     +         ' FROM dbo.CodeLkup (NOLOCK) WHERE Listname=''REPORTCFG'' AND Code=''MAPVALUE'' AND Long=@c_DataWindow AND Short=''Y'''
     +     ') RptCfg3'
     +    ' ON RptCfg3.Storerkey=OH.StorerKey AND RptCfg3.SeqNo=1'
     +    ' WHERE OH.Loadkey <> '''''
   SET @c_ExecStatements = @c_ExecStatements
     +    CASE WHEN @as_storerkey = CHAR(9)   THEN '' ELSE ' AND OH.Storerkey = @as_storerkey' END
   SET @c_ExecStatements = @c_ExecStatements +
     +    CASE WHEN ISNULL(@as_wavekey,'')='' AND ISNULL(@as_loadkey,'')='' THEN ' AND 1=2' ELSE '' END
   SET @c_ExecStatements = @c_ExecStatements
     +    CASE WHEN ISNULL(@as_wavekey,'')='' THEN '' ELSE ' AND OH.Orderkey IN (SELECT a.Orderkey FROM dbo.WAVEDETAIL a(NOLOCK), #TEMP_WAVEKEY b WHERE a.Wavekey=b.value)' END
   SET @c_ExecStatements = @c_ExecStatements
     +    CASE WHEN ISNULL(@as_loadkey,'')='' THEN '' ELSE ' AND OH.Loadkey IN (SELECT value FROM #TEMP_LOADKEY)' END
   SET @c_ExecStatements = @c_ExecStatements
     + ' ) X'
   IF ISNULL(@as_deliverydate,'')<>''
   BEGIN
      SET @c_ExecStatements = @c_ExecStatements
        +  CASE WHEN ISDATE(@as_deliverydate)=1 THEN ' WHERE X.DeliveryDate=CONVERT(DATE, @as_deliverydate)' ELSE ' WHERE 1=2' END
   END

   SET @c_ExecArguments = N'@as_storerkey NVARCHAR(15)'
                        + ',@as_deliverydate NVARCHAR(10)'
                        + ',@c_DataWindow  NVARCHAR(40)'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @as_deliverydate
                    , @c_DataWindow


   -- Final Result
   SET @c_ExecStatements = ''

   SET @c_ExecStatements = @c_ExecStatements
     + 'SELECT *'
     +      ', DeliveryDate_1st  = FIRST_VALUE( Y.DeliveryDate ) OVER(PARTITION BY Y.Loadkey ORDER BY Y.Section, Y.ExternOrderkey )'
     +      ', Route_1st         = FIRST_VALUE( Y.Route        ) OVER(PARTITION BY Y.Loadkey ORDER BY Y.Section, Y.ExternOrderkey )'
     + 'FROM ('
     +   ' SELECT Orderkey       = X.Orderkey'
     +         ', WaveKey        = X.WaveKey'
     +         ', Loadkey        = X.Loadkey'
     +         ', ExternOrderkey = X.ExternOrderkey'
     +         ', ExtOrderkey_BC = CASE WHEN (ROW_NUMBER() OVER(PARTITION BY X.Loadkey, X.ExternOrderkey ORDER BY X.Material, X.Lottable02 ))=1 THEN X.ExternOrderkey END'
     +         ', ExternPOKey    = MAX( X.ExternPOKey )'
     +         ', DeliveryDate   = MAX( X.DeliveryDate )'
     +         ', ST_Company     = MAX( X.ST_Company )'
     +         ', ST_Address1    = MAX( X.ST_Address1 )'
     +         ', ST_Address2    = MAX( X.ST_Address2 )'
     +         ', ST_Address3    = MAX( X.ST_Address3 )'
     +         ', ST_Address4    = MAX( X.ST_Address4 )'
     +         ', ST_Phone       = MAX( X.ST_Phone1 )'
     +         ', ST_Fax         = MAX( X.ST_Fax1 )'
     +         ', Logo_Path      = MAX( X.Logo_Path )'
     +         ', C_Company      = MAX( X.C_Company )'
     +         ', C_Address1     = MAX( X.C_Address1 )'
     +         ', C_Address2     = MAX( X.C_Address2 )'
     +         ', C_Address3     = MAX( X.C_Address3 )'
     +         ', C_Address4     = MAX( X.C_Address4 )'
     +         ', C_City         = MAX( X.C_City )'
     +         ', C_Country      = MAX( X.C_Country )'
     +         ', Route          = MAX( X.Route )'
     +         ', PrintedBy      = RTRIM( SUSER_SNAME() )'
     +         ', Line_No        = ROW_NUMBER() OVER(PARTITION BY X.Loadkey ORDER BY X.ExternOrderkey, X.Material, X.Lottable02 )'
     +         ', Material       = X.Material'
     +         ', Lottable02     = X.Lottable02'
     +         ', Descr          = MAX( X.Descr )'
     +         ', SizeLine       = FLOOR((X.SizeSeq-1)/@n_Col)'
     +         ', Qty            = SUM( X.Qty )'
     +         ', UOM            = MAX( X.UOM )'
   SET @c_ExecStatements = @c_ExecStatements
     +         ', Size01         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 0 THEN X.Size ELSE '''' END )'
     +         ', Size02         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 1 THEN X.Size ELSE '''' END )'
     +         ', Size03         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 2 THEN X.Size ELSE '''' END )'
     +         ', Size04         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 3 THEN X.Size ELSE '''' END )'
     +         ', Size05         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 4 THEN X.Size ELSE '''' END )'
     +         ', Size06         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 5 THEN X.Size ELSE '''' END )'
     +         ', Size07         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 6 THEN X.Size ELSE '''' END )'
     +         ', Size08         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 7 THEN X.Size ELSE '''' END )'
     +         ', Size09         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 8 THEN X.Size ELSE '''' END )'
     +         ', Size10         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col= 9 THEN X.Size ELSE '''' END )'
     +         ', Size11         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=10 THEN X.Size ELSE '''' END )'
     +         ', Size12         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=11 THEN X.Size ELSE '''' END )'
     +         ', Size13         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=12 THEN X.Size ELSE '''' END )'
     +         ', Size14         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=13 THEN X.Size ELSE '''' END )'
     +         ', Size15         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=14 THEN X.Size ELSE '''' END )'
     +         ', Size16         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=15 THEN X.Size ELSE '''' END )'
     +         ', Size17         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=16 THEN X.Size ELSE '''' END )'
     +         ', Size18         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=17 THEN X.Size ELSE '''' END )'
     +         ', Size19         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=18 THEN X.Size ELSE '''' END )'
     +         ', Size20         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=19 THEN X.Size ELSE '''' END )'
     +         ', Size21         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=20 THEN X.Size ELSE '''' END )'
     +         ', Size22         = MAX ( CASE WHEN (X.SizeSeq-1)%@n_Col=21 THEN X.Size ELSE '''' END )'
   SET @c_ExecStatements = @c_ExecStatements
     +         ', Qty01          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 0 THEN X.Qty ELSE 0 END)'
     +         ', Qty02          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 1 THEN X.Qty ELSE 0 END)'
     +         ', Qty03          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 2 THEN X.Qty ELSE 0 END)'
     +         ', Qty04          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 3 THEN X.Qty ELSE 0 END)'
     +         ', Qty05          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 4 THEN X.Qty ELSE 0 END)'
     +         ', Qty06          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 5 THEN X.Qty ELSE 0 END)'
     +         ', Qty07          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 6 THEN X.Qty ELSE 0 END)'
     +         ', Qty08          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 7 THEN X.Qty ELSE 0 END)'
     +         ', Qty09          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 8 THEN X.Qty ELSE 0 END)'
     +         ', Qty10          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col= 9 THEN X.Qty ELSE 0 END)'
     +         ', Qty11          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=10 THEN X.Qty ELSE 0 END)'
     +         ', Qty12          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=11 THEN X.Qty ELSE 0 END)'
     +         ', Qty13          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=12 THEN X.Qty ELSE 0 END)'
     +         ', Qty14          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=13 THEN X.Qty ELSE 0 END)'
     +         ', Qty15          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=14 THEN X.Qty ELSE 0 END)'
     +         ', Qty16          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=15 THEN X.Qty ELSE 0 END)'
     +         ', Qty17          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=16 THEN X.Qty ELSE 0 END)'
     +         ', Qty18          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=17 THEN X.Qty ELSE 0 END)'
     +         ', Qty19          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=18 THEN X.Qty ELSE 0 END)'
     +         ', Qty20          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=19 THEN X.Qty ELSE 0 END)'
     +         ', Qty21          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=20 THEN X.Qty ELSE 0 END)'
     +         ', Qty22          = SUM ( CASE WHEN (X.SizeSeq-1)%@n_Col=21 THEN X.Qty ELSE 0 END)'
   SET @c_ExecStatements = @c_ExecStatements
     +         ', ExtOrdKey01    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey02    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey03    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey04    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey05    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey06    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey07    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey08    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey09    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey10    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey11    = CAST( '''' AS NVARCHAR(50) )'
     +         ', ExtOrdKey12    = CAST( '''' AS NVARCHAR(50) )'
     +         ', Remark         = CAST( '''' AS NVARCHAR(50) )'
     +         ', Section        = ''1'''
   SET @c_ExecStatements = @c_ExecStatements
     +   ' FROM ('
     +      ' SELECT Orderkey       = OH.Orderkey'
     +            ', WaveKey        = ISNULL( RTRIM( OH.Userdefine09 ), '''' )'
     +            ', Loadkey        = ISNULL( RTRIM( OH.Loadkey ), '''' )'
     +            ', ExternOrderkey = ISNULL( RTRIM( OH.ExternOrderkey ), '''' )'
     +            ', ExternPOKey    = ISNULL( RTRIM( MAX( OH.ExternPOKey ) ), '''' )'
     +            ', DeliveryDate   = MAX( ORD.DeliveryDate )'
     +            ', ST_Company     = ISNULL( RTRIM( MAX( ST.B_Company ) ), '''' )'
     +            ', ST_Address1    = ISNULL( RTRIM( MAX( ST.B_Address1 ) ), '''' )'
     +            ', ST_Address2    = ISNULL( RTRIM( MAX( ST.B_Address2 ) ), '''' )'
     +            ', ST_Address3    = ISNULL( RTRIM( MAX( ST.B_Address3 ) ), '''' )'
     +            ', ST_Address4    = ISNULL( RTRIM( MAX( ST.B_Address4 ) ), '''' )'
     +            ', ST_Phone1      = ISNULL( RTRIM( MAX( ST.B_Phone1 ) ), '''' )'
     +            ', ST_Fax1        = ISNULL( RTRIM( MAX( ST.B_Fax1 ) ), '''' )'
     +            ', Logo_Path      = RTRIM( MAX( ST.Logo ) )'
     +            ', C_Company      = ISNULL( RTRIM( MAX( OH.C_Company ) ), '''' )'
     +            ', C_Address1     = ISNULL( RTRIM( MAX( CASE WHEN ORD.RptVersion=''V2'' THEN ''''          ELSE OH.C_Address1 END ) ), '''' )'
     +            ', C_Address2     = ISNULL( RTRIM( MAX( CASE WHEN ORD.RptVersion=''V2'' THEN OH.C_Address3 ELSE OH.C_Address2 END ) ), '''' )'
     +            ', C_Address3     = ISNULL( RTRIM( MAX( CASE WHEN ORD.RptVersion=''V2'' THEN OH.C_Address1 ELSE OH.C_Address3 END ) ), '''' )'
     +            ', C_Address4     = ISNULL( RTRIM( MAX( CASE WHEN ORD.RptVersion=''V2'' THEN OH.C_Address2 ELSE OH.C_Address4 END ) ), '''' )'
     +            ', C_City         = ISNULL( RTRIM( MAX( OH.C_City ) ), '''' )'
     +            ', C_Country      = ISNULL( RTRIM( MAX( OH.C_Country ) ), '''' )'
     +            ', Route          = ISNULL( RTRIM( MAX( OH.Route ) ), '''' )'
     +            ', Sku            = PD.Sku'
     +            ', Descr          = ISNULL( RTRIM( MAX( SKU.Descr ) ), '''' )'
     +            ', Material       = RTRIM( MAX( LEFT(PD.Sku,9) ) )'
     +            ', Lottable02     = RTRIM(LA.Lottable02)'
     +            ', Size           = RTRIM( MAX( LTRIM(RTRIM(SUBSTRING(PD.Sku, 10, 5))) ) )'
     +            ', SizeSort       = RTRIM( SKU.BUSR6 )'
     +            ', Qty            = SUM(PD.Qty)'
     +            ', UOM            = ISNULL( RTRIM( MAX( PACK.PackUOM3 ) ), '''' )'
     +            ', SizeSeq        = ROW_NUMBER() OVER(PARTITION BY OH.Orderkey, LEFT(PD.Sku,9), LA.Lottable02 ORDER BY SKU.BUSR6, SUBSTRING(PD.Sku, 10, 5))'
   SET @c_ExecStatements = @c_ExecStatements
     +      ' FROM #TEMP_ORDERKEY  ORD'
     +      ' JOIN dbo.ORDERS       OH WITH (NOLOCK) ON ORD.Orderkey = OH.Orderkey'
     +      ' JOIN dbo.PICKHEADER   PH WITH (NOLOCK) ON OH.Loadkey = PH.ExternOrderkey AND OH.Loadkey<>'''' AND ISNULL(PH.Orderkey,'''')='''' AND OH.Userdefine09<>'''''
     +      ' JOIN dbo.STORER       ST WITH (NOLOCK) ON OH.Storerkey = ST.Storerkey'
     +      ' JOIN dbo.PICKDETAIL   PD WITH (NOLOCK) ON OH.Orderkey = PD.Orderkey'
     +      ' JOIN dbo.SKU         SKU WITH (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKu.Sku'
     +      ' JOIN dbo.PACK       PACK WITH (NOLOCK) ON SKU.Packkey = PACK.Packkey'
     +      ' JOIN dbo.LOTATTRIBUTE LA WITH (NOLOCK) ON PD.Lot = LA.Lot'
     +      ' WHERE OH.Loadkey <> '''''
     +      ' AND PD.Qty > 0'
     +      ' GROUP BY OH.Userdefine09, OH.Loadkey, OH.Orderkey, OH.ExternOrderkey, OH.DeliveryDate, OH.Route, PD.Sku, LA.Lottable02, SKU.BUSR6'
     +    ') X'
     +   ' GROUP BY X.WaveKey, X.Loadkey, X.Orderkey, X.ExternOrderkey, X.Route, X.Material, X.Lottable02, FLOOR((X.SizeSeq-1)/@n_Col)'

   SET @c_ExecStatements = @c_ExecStatements
     +   ' UNION'
     +   ' SELECT Orderkey       = '''''
     +         ', WaveKey        = '''''
     +         ', Loadkey        = X.Loadkey'
     +         ', ExternOrderkey = '''''
     +         ', ExtOrderkey_BC = '''''
     +         ', ExternPOKey    = '''''
     +         ', DeliveryDate   = NULL'
     +         ', ST_Company     = '''''
     +         ', ST_Address1    = '''''
     +         ', ST_Address2    = '''''
     +         ', ST_Address3    = '''''
     +         ', ST_Address4    = '''''
     +         ', ST_Phone       = '''''
     +         ', ST_Fax         = '''''
     +         ', Logo_Path      = '''''
     +         ', C_Company      = '''''
     +         ', C_Address1     = '''''
     +         ', C_Address2     = '''''
     +         ', C_Address3     = '''''
     +         ', C_Address4     = '''''
     +         ', C_City         = '''''
     +         ', C_Country      = '''''
     +         ', Route          = '''''
     +         ', PrintedBy      = '''''
     +         ', Line_No        = FLOOR((X.SeqNo-1) / @n_Col2) + 100000000'
     +         ', Material       = '''''
     +         ', Lottable02     = '''''
     +         ', Descr          = '''''
     +         ', SizeLine       = '''''
     +         ', Qty            = '''''
     +         ', UOM            = '''''
   SET @c_ExecStatements = @c_ExecStatements
     +         ', Size01='''', Size02='''', Size03='''', Size04='''', Size05='''', Size06='''', Size07='''', Size08='''', Size09='''', Size10='''''
     +         ', Size11='''', Size12='''', Size13='''', Size14='''', Size15='''', Size16='''', Size17='''', Size18='''', Size19='''', Size20='''''
     +         ', Size21='''', Size22='''''
     +         ', Qty01 = 0, Qty02 = 0, Qty03 = 0, Qty04 = 0, Qty05 = 0, Qty06 = 0, Qty07 = 0, Qty08 = 0, Qty09 = 0, Qty10 = 0'
     +         ', Qty11 = 0, Qty12 = 0, Qty13 = 0, Qty14 = 0, Qty15 = 0, Qty16 = 0, Qty17 = 0, Qty18 = 0, Qty19 = 0, Qty20 = 0'
     +         ', Qty21 = 0, Qty22 = 0'
     +         ', ExtOrdKey01    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 0 THEN X.ExternOrderKey2 ELSE '''' END )'
     +         ', ExtOrdKey02    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 1 THEN X.ExternOrderKey2 ELSE '''' END )'
     +         ', ExtOrdKey03    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 2 THEN X.ExternOrderKey2 ELSE '''' END )'
     +         ', ExtOrdKey04    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 3 THEN X.ExternOrderKey2 ELSE '''' END )'
     +         ', ExtOrdKey05    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 4 THEN X.ExternOrderKey2 ELSE '''' END )'
     +         ', ExtOrdKey06    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 5 THEN X.ExternOrderKey2 ELSE '''' END )'
     +         ', ExtOrdKey07    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 0 THEN X.ExternOrderKey ELSE '''' END )'
     +         ', ExtOrdKey08    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 1 THEN X.ExternOrderKey ELSE '''' END )'
     +         ', ExtOrdKey09    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 2 THEN X.ExternOrderKey ELSE '''' END )'
     +         ', ExtOrdKey10    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 3 THEN X.ExternOrderKey ELSE '''' END )'
     +         ', ExtOrdKey11    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 4 THEN X.ExternOrderKey ELSE '''' END )'
     +         ', ExtOrdKey12    = MAX( CASE WHEN (X.SeqNo-1) % @n_Col2 = 5 THEN X.ExternOrderKey ELSE '''' END )'
     +         ', Remark         = '''''
     +         ', Section        = ''2'''
   SET @c_ExecStatements = @c_ExecStatements
     +   ' FROM ('
     +      ' SELECT Loadkey        = a.Loadkey'
     +            ', ExternOrderkey2= RTRIM(a.ExternOrderkey) + ''  ( '' + ISNULL(CONVERT(VARCHAR(10),SUM(b.Qty)),'''') + ISNULL('' ''+ RTRIM(MAX(e.PackUOM3)), '''') +'' )'''
     +            ', ExternOrderkey = RTRIM(a.ExternOrderkey)'
     +            ', SeqNo          = ROW_NUMBER() OVER(PARTITION BY a.Loadkey ORDER BY a.ExternOrderkey)'
     +      ' FROM #TEMP_ORDERKEY ORD'
     +      ' JOIN dbo.ORDERS     a WITH (NOLOCK) ON ORD.Orderkey = a.Orderkey'
     +      ' JOIN dbo.PICKDETAIL b WITH (NOLOCK) ON a.Orderkey = b.Orderkey'
     +      ' JOIN dbo.PICKHEADER c WITH (NOLOCK) ON a.Loadkey = c.ExternOrderkey AND a.Loadkey<>'''' AND ISNULL(c.Orderkey,'''')='''' AND a.Userdefine09<>'''''
     +      ' JOIN dbo.SKU        d WITH (NOLOCK) ON b.Storerkey = d.Storerkey AND b.Sku = d.Sku'
     +      ' JOIN dbo.PACK       e WITH (NOLOCK) ON d.Packkey = e.Packkey'
     +      ' WHERE a.Loadkey <> '''''
     +      ' AND b.Qty > 0'
     +      ' AND a.ExternOrderkey <> '''''
     +      ' GROUP BY a.Loadkey, a.ExternOrderkey'
     +    ') X'
     +   ' GROUP BY X.Loadkey, FLOOR((X.SeqNo-1) / @n_Col2)'

   SET @c_ExecStatements = @c_ExecStatements
     +   ' UNION'
     +   ' SELECT Orderkey       = '''''
     +         ', WaveKey        = '''''
     +         ', Loadkey        = X.Loadkey'
     +         ', ExternOrderkey = X.ExternOrderkey'
     +         ', ExtOrderkey_BC = '''''
     +         ', ExternPOKey    = '''''
     +         ', DeliveryDate   = NULL'
     +         ', ST_Company     = '''''
     +         ', ST_Address1    = '''''
     +         ', ST_Address2    = '''''
     +         ', ST_Address3    = '''''
     +         ', ST_Address4    = '''''
     +         ', ST_Phone       = '''''
     +         ', ST_Fax         = '''''
     +         ', Logo_Path      = '''''
     +         ', C_Company      = '''''
     +         ', C_Address1     = '''''
     +         ', C_Address2     = '''''
     +         ', C_Address3     = '''''
     +         ', C_Address4     = '''''
     +         ', C_City         = '''''
     +         ', C_Country      = '''''
     +         ', Route          = '''''
     +         ', PrintedBy      = '''''
     +         ', Line_No        = X.SeqNo - 1 + 200000000'
     +         ', Material       = '''''
     +         ', Lottable02     = '''''
     +         ', Descr          = '''''
     +         ', SizeLine       = '''''
     +         ', Qty            = '''''
     +         ', UOM            = '''''
   SET @c_ExecStatements = @c_ExecStatements
     +         ', Size01='''', Size02='''', Size03='''', Size04='''', Size05='''', Size06='''', Size07='''', Size08='''', Size09='''', Size10='''''
     +         ', Size11='''', Size12='''', Size13='''', Size14='''', Size15='''', Size16='''', Size17='''', Size18='''', Size19='''', Size20='''''
     +         ', Size21='''', Size22='''''
     +         ', Qty01 = 0, Qty02 = 0, Qty03 = 0, Qty04 = 0, Qty05 = 0, Qty06 = 0, Qty07 = 0, Qty08 = 0, Qty09 = 0, Qty10 = 0'
     +         ', Qty11 = 0, Qty12 = 0, Qty13 = 0, Qty14 = 0, Qty15 = 0, Qty16 = 0, Qty17 = 0, Qty18 = 0, Qty19 = 0, Qty20 = 0'
     +         ', Qty21 = 0, Qty22 = 0'
     +         ', ExtOrdKey01='''', ExtOrdKey02='''', ExtOrdKey03='''', ExtOrdKey04='''', ExtOrdKey05='''', ExtOrdKey06='''''
     +         ', ExtOrdKey07='''', ExtOrdKey08='''', ExtOrdKey09='''', ExtOrdKey10='''', ExtOrdKey11='''', ExtOrdKey12='''''
     +         ', Remark         = X.Remark'
     +         ', Section        = ''3'''
   SET @c_ExecStatements = @c_ExecStatements
     +   ' FROM ('
     +      ' SELECT Loadkey        = a.Loadkey'
     +            ', ExternOrderkey = a.ExternOrderkey'
     +            ', Remark         = ISNULL(RTRIM(a.C_Address1),'''')'
     +            ', SeqNo          = ROW_NUMBER() OVER(PARTITION BY a.Loadkey ORDER BY a.ExternOrderkey)'
     +      ' FROM #TEMP_ORDERKEY ORD'
     +      ' JOIN dbo.ORDERS     a WITH (NOLOCK) ON ORD.Orderkey = a.Orderkey'
     +      ' JOIN dbo.PICKDETAIL b WITH (NOLOCK) ON a.Orderkey = b.Orderkey'
     +      ' JOIN dbo.PICKHEADER c WITH (NOLOCK) ON a.Loadkey = c.ExternOrderkey AND a.Loadkey<>'''' AND ISNULL(c.Orderkey,'''')='''' AND a.Userdefine09<>'''''
     +      ' WHERE a.Loadkey <> '''''
     +      ' AND b.Qty > 0'
     +      ' AND a.C_Address1 <> '''''
     +      ' AND ORD.RptVersion=''V1'''
     +      ' GROUP BY a.Loadkey, a.ExternOrderkey, a.C_Address1'
     +    ') X'
     +   ' GROUP BY X.Loadkey, X.ExternOrderkey, X.Remark, X.SeqNo'
     +') Y,'
     +'('
     +   ' SELECT Copies = Rowref FROM dbo.SEQKey (NOLOCK) WHERE Rowref<=2'
     + ') Z'
     +' ORDER BY DeliveryDate_1st, Route_1st, Loadkey, Copies, Section, Line_No, SizeLine'


   SET @c_ExecArguments = N'@as_storerkey  NVARCHAR(18)'
                        + ',@n_Col         INT'
                        + ',@n_Col2        INT'

   EXEC sp_ExecuteSql @c_ExecStatements
                    , @c_ExecArguments
                    , @as_storerkey
                    , @n_Col
                    , @n_Col2
END

GO