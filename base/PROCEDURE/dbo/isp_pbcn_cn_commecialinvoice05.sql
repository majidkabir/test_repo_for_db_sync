SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PBCN_CN_CommecialInvoice05                     */
/* Creation Date: 08-OCT-2019                                           */
/* Copyright:                                                           */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-10711 - CN_PVH QHW_Invoice report                       */
/*                                                                      */
/* Called By: report dw = r_dw_cn_commercialinvoice05                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 23-JAN-2020  CSCHONG   1.1   WMS-11885 revised field logic (CS01)    */
/* 29-Apr-2020  WLChooi   1.2   WMS-13130 - Revised field logic (WL01)  */
/************************************************************************/

CREATE PROC [dbo].[isp_PBCN_CN_CommecialInvoice05](
  @cmbolkey NVARCHAR(21)  
) 
AS 
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET ANSI_DEFAULTS OFF

   DECLARE @c_DataWidnow         NVARCHAR(40)
      , @as_storerkey         NVARCHAR(15)
      , @as_mbolkey           NVARCHAR(4000)
      , @as_loadkey           NVARCHAR(4000)
      , @as_deliverydate      NVARCHAR(4000)
      , @as_consigneekey      NVARCHAR(4000)
      , @as_orderkey          NVARCHAR(4000)
      , @c_SizeList           NVARCHAR(2000)

SELECT @c_DataWidnow    = 'r_dw_cn_commercialinvoice05'
     , @as_storerkey    = 'PVH'
     --, @as_mbolkey      = :as_mbolkey
     --, @as_loadkey      = :as_loadkey
     --, @as_deliverydate = :as_deliverydate
     --, @as_consigneekey = :as_consigneekey
     --, @as_orderkey     = :as_orderkey
     , @c_SizeList      = N'|5XS|4XS|3XS|XXXS|2XS|XXS|XS|0XS|S|00S|YS|SM|0SM|S/M|M|00M|YM|ML|0ML|M/L|L|00L|YL|F|XL|0XL|XXL|2XL|XXXL|3XL|4XL|5XL|'

SELECT Y.*
FROM (
   SELECT Storerkey    = RTRIM( OH.Storerkey )
        , MBOLKey      = RTRIM( OH.MBOLKey )
        , Company      = ISNULL( MAX( RTRIM( ST.Company ) ), '')
        , Address1     = ISNULL( MAX( RTRIM( ST.Address1 ) ), '')
        , Address2     = ISNULL( MAX( RTRIM( ST.Address2 ) ), '')
        , Address3     = ISNULL( MAX( RTRIM( ST.Address3 ) ), '')
        , City         = ISNULL( MAX( RTRIM( ST.City ) ), '')
        , Country      = ISNULL( MAX( RTRIM( ST.Country ) ), '')
        --WL01 START
        , B_Company    = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_Company ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.Company ) ), '') END
        , B_Address1   = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_Address1 ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.Address1 ) ), '') END
        , B_Address2   = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_Address2 ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.Address2 ) ), '') END
        , B_Address3   = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_Address3 ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.Address3 ) ), '') END
        , B_Address4   = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_Address4 ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.Address4 ) ), '') END
        , B_City       = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_City ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.City ) ), '') END
        , B_Country    = CASE WHEN ISNULL( MAX( RTRIM( SR.Fax1 ) ), '') = '' THEN ISNULL( MAX( RTRIM( FOH.B_Country ) ), '') 
                                                                             ELSE ISNULL( MAX( RTRIM( SR.Country ) ), '') END
        --WL01 END
        , BillToKey    = ISNULL( MAX( RTRIM( FOH.BillToKey ) ), '')
        , HTS_CODES    = SubString(SI.Data,1,6)--SubString(SKU.BUSR3,1,6)   --(CS01)
        , Style        = RTRIM( SKU.Style )
        , Color        = RTRIM( SKU.Color )
        , Measurement  = RTRIM( SKU.Measurement )
        , Descr        = ISNULL( MAX( RTRIM( DI.Data ) ), '')
        , BUSR1        = ISNULL(RTRIM( SKU.BUSR1 ),'')
        , COO          = RTRIM( ISO.Description )
        , Qty          = SUM( PD.Qty )
        , UnitPrice    = SUM(OD.Unitprice*PD.QTY)/SUM( PD.Qty )--OD.Tax01    --(CS01)
        , FiberContent = ISNULL( MAX( RTRIM( SI.Userdefine10 ) ), '')
        , Sizes        = RTRIM((SELECT e.Size+'  '
                                FROM dbo.ORDERS       a (NOLOCK)
                                JOIN dbo.ORDERDETAIL  b (NOLOCK) ON a.Orderkey = b.Orderkey
                                JOIN dbo.PICKDETAIL   c (NOLOCK) ON b.Orderkey = c.Orderkey AND b.OrderLineNumber = c.OrderLineNumber
                                JOIN dbo.SKU          e (NOLOCK) ON c.Storerkey = e.Storerkey AND c.Sku = e.Sku
                        JOIN dbo.LOTATTRIBUTE  LA (NOLOCK) ON c.Lot = LA.Lot                           --CS01
                                WHERE a.Storerkey=OH.Storerkey AND a.MBOLKey=OH.MBOLKey
                                --AND SubString(e.BUSR3,1,6)=SubString(SKU.BUSR3,1,6)
                                AND e.Style=SKU.Style AND e.Color=SKU.Color AND e.Measurement=SKU.Measurement --AND e.BUSR1=SKU.BUSR1
                                --AND b.Tax01=OD.Tax01
                        AND LA.lottable01 = ISO.Code    --CS01
                                GROUP BY e.Size
                                ORDER BY MAX( CASE
                                 WHEN ISNUMERIC(e.Size)=1 AND LTRIM(e.Size) NOT IN ('-','+','.',',') THEN FORMAT(CONVERT(FLOAT,e.Size)+400000,'000000.00')
                                 WHEN RTRIM(e.Size) LIKE N'%[0-9]H' AND ISNUMERIC(LEFT(e.Size,LEN(e.Size)-1))=1 THEN FORMAT(CONVERT(FLOAT,LEFT(e.Size,LEN(e.Size)-1)+'.5')+400000,'000000.00')
                                 ELSE FORMAT(CHARINDEX(N'|'+LTRIM(RTRIM(e.Size))+N'|', @c_SizeList)+800000,'000000.00')
                              END +'-'+ e.Size )
                           FOR XML PATH('')) )
        , Storer_Logo  = MAX( RTRIM( CASE WHEN RL.Notes<>'' THEN RL.Notes ELSE ST.Logo END) )
        , MBOL_EditDate= MAX( MBOL.EditDate )
        , PaymentTerms = ISNULL( MAX( RTRIM( PVHRPT.UDF01 ) ), '' )
        , IncoTerms    = ISNULL( MAX( RTRIM( PVHRPT.UDF02 ) ), '' )
        , TCImg_Path   = MAX( RTRIM( TC.Notes ) )
        , SeqNo        = ROW_NUMBER() OVER(PARTITION BY OH.Storerkey, OH.MBOLKey, SN.Section ORDER BY SKU.Style, ISNULL(RTRIM( SKU.BUSR1 ),''), SKU.Color, SKU.Measurement)
        , Section      = SN.Section
   FROM (
      SELECT Storerkey = OH.Storerkey
           , MBOLKey   = OH.MBOLKey
           , Orderkey  = MIN(OH.Orderkey)
      FROM dbo.ORDERS OH (NOLOCK)
      WHERE OH.MBOLKey <> ''
      --  AND OH.Storerkey = 'PVH'
      --  AND ( @as_loadkey<>'' OR @as_mbolkey<>'' OR @as_deliverydate<>'' OR @as_consigneekey<>'' OR @as_orderkey<>'' )
        AND ( OH.MBOLKey = @cmbolkey )
        --AND ( ISNULL(@as_loadkey,'')='' OR OH.Loadkey IN (SELECT DISTINCT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',',REPLACE(@as_loadkey,CHAR(13)+CHAR(10),',')) WHERE ColValue<>'') )
        --AND ( ISNULL(@as_deliverydate,'')='' OR ( ISDATE(@as_deliverydate)=1 AND OH.DeliveryDate = @as_deliverydate ) )
        --AND ( ISNULL(@as_consigneekey,'')='' OR OH.ConsigneeKey IN (SELECT DISTINCT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',',REPLACE(@as_consigneekey,CHAR(13)+CHAR(10),',')) WHERE ColValue<>'') )
        --AND ( ISNULL(@as_orderkey,'')='' OR OH.OrderKey IN (SELECT DISTINCT LTRIM(ColValue) FROM dbo.fnc_DelimSplit(',',REPLACE(@as_orderkey,CHAR(13)+CHAR(10),',')) WHERE ColValue<>'') )
      GROUP BY OH.Storerkey, OH.MBOLKey
   ) FOK

   JOIN dbo.ORDERS       FOH (NOLOCK) ON FOK.Orderkey = FOH.OrderKey
   JOIN dbo.MBOL        MBOL (NOLOCK) ON FOH.MbolKey = MBOL.MbolKey
   JOIN dbo.STORER        ST (NOLOCK) ON FOH.Storerkey = ST.Storerkey

   JOIN dbo.ORDERS        OH (NOLOCK) ON FOK.Storerkey = OH.Storerkey AND FOK.MBOLKey = OH.MBOLKey
   JOIN dbo.ORDERDETAIL   OD (NOLOCK) ON OH.Orderkey = OD.Orderkey
   JOIN dbo.PICKDETAIL    PD (NOLOCK) ON OD.Orderkey = PD.Orderkey AND OD.OrderLineNumber = PD.OrderLineNumber
   JOIN dbo.LOTATTRIBUTE  LA (NOLOCK) ON PD.Lot = LA.Lot
   JOIN dbo.SKU          SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku

   LEFT JOIN dbo.SKUconfig  SI (NOLOCK) ON PD.Storerkey = SI.Storerkey AND PD.Sku = SI.Sku
   LEFT JOIN dbo.CODELKUP RL (NOLOCK) ON RL.Listname = 'RPTLOGO' AND RL.Code='LOGO' AND RL.Storerkey = OH.Storerkey AND RL.Long = @c_DataWidnow
   LEFT JOIN dbo.CODELKUP TC (NOLOCK) ON TC.Listname = 'RPTLOGO' AND TC.Code='TCImg' AND TC.Storerkey = OH.Storerkey AND TC.Long = @c_DataWidnow
   LEFT JOIN dbo.STORER   BT (NOLOCK) ON FOH.BillToKey = BT.Storerkey
   LEFT JOIN dbo.STORER   SR (NOLOCK) ON SR.Storerkey = 'QHW-' + LTRIM(RTRIM(FOH.BillToKey)) AND SR.ConsigneeFor = 'PVHQHW' AND SR.[Type] = '2'   --WL01
   LEFT JOIN (
      SELECT Code        = X.Code
           , Description = MAX(X.Description)
      FROM (
         SELECT Code , Description FROM dbo.CODELKUP (NOLOCK) WHERE Listname = 'PVHCountry' AND Code<>'' AND Description<>''   --WL01
         UNION
         SELECT Short, Description FROM dbo.CODELKUP (NOLOCK) WHERE Listname = 'PVHCountry' AND Short<>'' AND LEN(Short)=2 AND Description<>''   --WL01
      ) X
      GROUP BY X.Code
   ) ISO ON ISO.Code = LA.Lottable01
   
   LEFT JOIN (
      SELECT Storerkey = Storerkey
           , Key1      = Key1
           , Data      = MAX(Data)
        FROM dbo.DOCInfo (NOLOCK)
       WHERE Tablename in ('SKU','SKUCONFIG')
       GROUP BY Storerkey, Key1
   ) DI ON DI.Storerkey = SI.Storerkey AND SI.data = DI.Key1

   LEFT JOIN dbo.CodeLkup PVHRPT(NOLOCK) ON PVHRPT.Listname='PVHREPORT' AND PVHRPT.Storerkey=FOH.Storerkey AND PVHRPT.Code='PAYMENT' AND PVHRPT.Code2=''

   , (SELECT Section = 1 UNION SELECT 2) SN

   WHERE PD.Qty > 0
     --AND OH.Status = '9'
   -- AND SN.Section = 1

   GROUP BY OH.Storerkey
          , OH.MBOLKey
          , SN.Section
          --, SubString(SKU.BUSR3,1,6)   --(CS01)
        , SubString(SI.Data,1,6)       --(CS01)
          , SKU.Style
          , SKU.Color
          , SKU.Measurement
          , ISNULL(RTRIM( SKU.BUSR1 ),'')
          , ISO.Description
          --, OD.Tax01                   --(CS01)
        ,ISO.Code
) Y
WHERE (Y.Section = 1 OR Y.SeqNo = 1)

ORDER BY Storerkey, MBOLKey, Section, SeqNo

END


GO