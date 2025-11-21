SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Stored Procedure: isp_r_hk_picking_control_list_02                    */
/* Creation Date: 15-Sep-2017                                            */
/* Copyright: LFL                                                        */
/* Written by: Michael Lam (HK LIT)                                      */
/*                                                                       */
/* Purpose: RDT Picking Control List                                     */
/*                                                                       */
/* Called By: Report Module. Datawidnow r_hk_picking_control_list_02     */
/*                                                                       */
/* PVCS Version: 1.0                                                     */
/*                                                                       */
/* Version: 7.0                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author   Ver  Purposes                                   */
/* 2022-07-22   Michael  1.1  WMS-20311 SAP S4 upgrade - Add new fields  */
/*                            GOH, CITIE, Lbl_ItemGroup                  */
/* 2023-01-30   Michael  1.2  WMS-21659 Change KPIStartDateTime logic    */
/*************************************************************************/

CREATE PROCEDURE [dbo].[isp_r_hk_picking_control_list_02] (
       @as_storerkey NVARCHAR(15),
       @as_wavekey   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF OBJECT_ID('tempdb..#TEMP_ORDERDETAIL') IS NOT NULL
      DROP TABLE #TEMP_ORDERDETAIL

   DECLARE @cDataWidnow NVARCHAR(40)

   SET @cDataWidnow = 'r_hk_picking_control_list_02'

   SELECT Wavekey        = ORD.Wavekey
        , OrderKey       = ORD.OrderKey
        , OrderLineNumber= ORD.OrderLineNumber
        , Storerkey      = ORD.Storerkey
        , Sku            = ORD.Sku
        , Style          = ORD.Style
        , StdCube        = ORD.STDCUBE
        , Pickdetailkey  = ORD.Pickdetailkey
        , ItemGroup      = ORD.ItemGroup
        , Lottable02     = ORD.Lottable02
        , Seq_OrdLine    = ORD.Seq_OrdLine
        , Seq_WaveSku    = ORD.Seq_WaveSku
        , OriginalQty    = ORD.OriginalQty
        , ShortQty       = ORD.ShortQty
        , PutawayZone    = ORD.PutawayZone
        , Picked_Qty     = ORD.Picked_Qty
        , FCP_Qty        = ORD.FCP_Qty
        , PP_Qty         = ORD.PP_Qty
        , FCP_CTN        = ORD.FCP_CTN
        , Replen_Qty     = CASE WHEN MAX(ISNULL(REPLEN.qty,0)) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku)
                                > SUM(ORD.ShortQty) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku ORDER BY ORD.Wavekey, ORD.Sku, ORD.Orderkey, ORD.Pickdetailkey)
                               THEN ORD.ShortQty
                               ELSE ORD.ShortQty + MAX(ISNULL(REPLEN.qty,0)) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku)
                                  - SUM(ORD.ShortQty) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku ORDER BY ORD.Wavekey, ORD.Sku, ORD.Orderkey, ORD.Pickdetailkey)
                           END
        , ShortAllocate  = CASE WHEN MAX(ISNULL(REPLEN.qty,0)) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku)
                                   > SUM(ORD.ShortQty) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku ORDER BY ORD.Wavekey, ORD.Sku, ORD.orderkey, ORD.pickdetailkey)
                                THEN 0
                                ELSE SUM(ORD.ShortQty) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku ORDER BY ORD.Wavekey, ORD.Sku, ORD.orderkey, ORD.pickdetailkey)
                                   - MAX(ISNULL(REPLEN.qty,0)) OVER (PARTITION BY ORD.Wavekey, ORD.Storerkey, ORD.Sku)
                           END
        , PPDP_CTN       = ISNULL( CASE WHEN Seq_WaveSku = 1 THEN REPLEN.PPDP_CTN ELSE 0 END, 0)
        , Replened_Qty   = ORD.Replened_Qty
        , ShortPickQty   = ORD.ShortPickQty
        , OutstandingQty = CASE WHEN ISNULL(ORD.OH_Status,'')='0' THEN ORD.OriginalQty
                                WHEN ISNULL(ORD.PD_Status,'')='0' THEN ORD.PD_Qty
                                ELSE 0
                           END
        , PD_Qty         = ORD.PD_Qty
        , GOH            = ORD.GOH
        , CITIE          = ORD.CITIE

   INTO #TEMP_ORDERDETAIL

   FROM (
      SELECT Wavekey        = RTRIM( OH.UserDefine09 )
           , OrderKey       = RTRIM( OH.OrderKey )
           , Storerkey      = RTRIM( OH.Storerkey )
           , OrderLineNumber= RTRIM( OD.OrderLineNumber )
           , Sku            = RTRIM( OD.Sku )
           , Style          = ISNULL( RTRIM( SKU.Style ), '' )
           , StdCube        = ISNULL( SKU.STDCUBE, 0 )
           , Pickdetailkey  = ISNULL( RTRIM( PD.Pickdetailkey ), '' )
           , ItemGroup      = ISNULL( RTRIM(
                              CASE (select top 1 b.ColValue
                                        from dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes) a, dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes2) b
                                        where a.SeqNo=b.SeqNo and a.ColValue='ItemGroup')
                                 WHEN 'SKUGROUP'  THEN SKU.SKUGROUP
                                 WHEN 'CLASS'     THEN SKU.CLASS
                                 WHEN 'ITEMCLASS' THEN SKU.ITEMCLASS
                                 WHEN 'SUSR1'     THEN SKU.SUSR1
                                 WHEN 'SUSR2'     THEN SKU.SUSR2
                                 WHEN 'SUSR3'     THEN SKU.SUSR3
                                 WHEN 'SUSR4'     THEN SKU.SUSR4
                                 WHEN 'SUSR5'     THEN SKU.SUSR5
                                 WHEN 'BUSR1'     THEN SKU.BUSR1
                                 WHEN 'BUSR2'     THEN SKU.BUSR2
                                 WHEN 'BUSR3'     THEN SKU.BUSR3
                                 WHEN 'BUSR4'     THEN SKU.BUSR4
                                 WHEN 'BUSR5'     THEN SKU.BUSR5
                                 WHEN 'BUSR6'     THEN SKU.BUSR6
                                 WHEN 'BUSR7'     THEN SKU.BUSR7
                                 WHEN 'BUSR8'     THEN SKU.BUSR8
                                 WHEN 'BUSR9'     THEN SKU.BUSR9
                                 WHEN 'BUSR10'    THEN SKU.BUSR10
                              END ), '' )
           , Lottable02     = ISNULL( RTRIM( OD.Lottable02 ), '' )
           , Seq_OrdLine    = ROW_NUMBER() OVER (PARTITION BY OD.OrderKey, OD.OrderLineNumber ORDER BY OD.OrderKey, OD.OrderLineNumber, PD.PickDetailKey )
           , Seq_WaveSku    = ROW_NUMBER() OVER (PARTITION BY OH.Userdefine09, OD.Storerkey, OD.Sku ORDER BY OH.Userdefine09, OD.Storerkey, OD.Sku, OD.OrderKey, PD.PickDetailKey)
           , OriginalQty    = CASE WHEN ROW_NUMBER() OVER (PARTITION BY OD.OrderKey, OD.OrderLineNumber ORDER BY OD.OrderKey, OD.OrderLineNumber, PD.PickDetailKey ) = 1
                                   THEN OD.OriginalQty ELSE 0 END
           , ShortQty       = CASE WHEN ROW_NUMBER() OVER (PARTITION BY OD.OrderKey, OD.OrderLineNumber ORDER BY OD.OrderKey, OD.OrderLineNumber, PD.PickDetailKey ) = 1
                                   THEN OD.OriginalQty - OD.QtyAllocated - OD.QtyPicked - OD.ShippedQty ELSE 0 END
           , PutawayZone    = ISNULL( RTRIM( LOC.PutawayZone ), '' )
           , Picked_Qty     = ISNULL( CASE WHEN PD.Status >= '5' THEN PD.Qty ELSE 0 END, 0 )
           , FCP_Qty        = ISNULL( CASE WHEN PD.Cartontype = 'FCP'             THEN PD.Qty ELSE 0      END, 0 )
           , PP_Qty         = ISNULL( CASE WHEN PD.Cartontype IN ('Replen','FCP') THEN 0      ELSE PD.Qty END, 0 )
           , FCP_CTN        = ISNULL( CASE WHEN PD.CartonType = 'FCP'             THEN 1      ELSE 0      END, 0 )
           , Replened_Qty   = ISNULL( CASE WHEN PD.Cartontype = 'Replen'          THEN PD.Qty ELSE 0      END, 0 )
           , ShortPickQty   = ISNULL( CASE WHEN ISNULL(PD.Status,'')='4'          THEN PD.Qty ELSE 0      END, 0 )
           , OH_Status      = ISNULL( RTRIM( OH.Status ), '' )
           , PD_Status      = ISNULL( RTRIM( PD.Status ), '' )
           , PD_Qty         = ISNULL( PD.Qty, 0 )
           , GOH            = CASE WHEN SKU.Packkey='TB-GOH' THEN 'Y' ELSE '' END
           , CITIE          = CASE WHEN SKU.BUSR8='Y' THEN 'Y' ELSE '' END

      FROM dbo.ORDERS      OH (NOLOCK)
      JOIN dbo.ORDERDETAIL OD (NOLOCK) ON OH.OrderKey=OD.OrderKey
      JOIN dbo.SKU        SKU (NOLOCK) ON OD.StorerKey=SKU.StorerKey AND OD.Sku=SKU.Sku
      LEFT OUTER JOIN dbo.PICKDETAIL PD (NOLOCK) ON OD.OrderKey=PD.OrderKey AND OD.OrderLineNumber=PD.OrderLineNumber AND PD.Qty>0
      LEFT OUTER JOIN dbo.LOC       LOC (NOLOCK) ON PD.Loc = LOC.Loc
      LEFT OUTER JOIN (
         SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
              , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
           FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@cDataWidnow AND Short='Y'
      ) RptCfg
      ON RptCfg.Storerkey=OH.Storerkey AND RptCfg.SeqNo=1

      WHERE OH.UserDefine09<>''
        AND OH.Storerkey = @as_storerkey
        AND OH.UserDefine09 = @as_wavekey
   ) ORD
   LEFT OUTER JOIN (
      SELECT ReplenNo  = a.ReplenNo
           , Storerkey = a.Storerkey
           , Sku       = a.Sku
           , Qty       = SUM ( CASE b.LocationType
                                 WHEN 'CASE'      THEN a.QtyInPickLoc
                                 WHEN 'DYNAMICPK' THEN a.Qty
                                 ELSE 0
                              END )
           , PPDP_CTN  = COUNT (DISTINCT a.Refno)
      FROM dbo.REPLENISHMENT a (NOLOCK)
      JOIN dbo.LOC           b (NOLOCK) ON a.ToLoc=b.Loc
      WHERE a.Storerkey = @as_storerkey
     AND a.ReplenNo  = @as_wavekey
        AND a.Confirmed <> 'Y'
        AND b.LocationType IN ('CASE', 'DYNAMICPK')
      GROUP BY a.ReplenNo, a.Storerkey, a.Sku
   ) REPLEN ON (REPLEN.replenno=ORD.Wavekey AND REPLEN.Storerkey=ORD.Storerkey AND REPLEN.sku=ORD.Sku)


   UPDATE #TEMP_ORDERDETAIL
      SET Replen_Qty = 0
    WHERE Replen_Qty < 0


   SELECT Wavekey        = ORD.Wavekey
        , OrderKey       = ORD.OrderKey
        , Storerkey      = ORD.Storerkey
        , ExternOrderKey = RTRIM( OH.ExternOrderKey )
        , PickHeaderKey  = RTRIM( PH.PickHeaderKey )
        , Type           = RTRIM( OH.Type )
        , ConsigneeKey   = RTRIM( OH.ConsigneeKey )
        , C_Company      = RTRIM( OH.C_Company )
        , C_Address1     = RTRIM( OH.C_Address1 )
        , C_Address2     = RTRIM( OH.C_Address2 )
        , C_Address3     = RTRIM( OH.C_Address3 )
        , C_Address4     = RTRIM( OH.C_Address4 )
        , C_Country      = RTRIM( OH.C_Country )
        , Route          = RTRIM( UPPER( CASE WHEN LEFT(OH.Route,2) IN ('MC', 'LT') THEN OH.Route ELSE LEFT(OH.Route,2) END ) )
        , DeliveryDate   = CASE WHEN (select top 1 b.ColValue
                              from dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes) a, dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes2) b
                             where a.SeqNo=b.SeqNo and a.ColValue='DeliveryDateWithTime') = 'Y'
                           THEN CONVERT(DATETIME, CONVERT(VARCHAR(16), OH.DeliveryDate, 120))
                           ELSE CONVERT(DATETIME, CONVERT(VARCHAR(10), OH.DeliveryDate, 120))
                           END
        , OrderLineNumber= ORD.OrderLineNumber
        , Sku            = ORD.Sku
        , Style          = ORD.Style
        , Pickdetailkey  = ORD.Pickdetailkey
        , ItemGroup      = ORD.ItemGroup
        , ItemGroups     = CAST( SUBSTRING(
                         ( SELECT DISTINCT ', ', RTRIM(ItemGroup)
                           FROM #TEMP_ORDERDETAIL WHERE Orderkey = ORD.Orderkey AND ItemGroup<>''
                           ORDER BY 2
                           FOR XML PATH('') ), 3, 30) AS NVARCHAR(30) )
        , OriginalQty    = ORD.OriginalQty
        , ShortQty       = ORD.ShortQty
        , CBM            = ORD.STDCUBE * ORD.OriginalQty
        , FCP_Qty        = ORD.FCP_Qty
        , PP_Qty         = ORD.PP_Qty
        , Replen_Qty     = ORD.Replen_Qty
        , FCP_CTN        = ORD.FCP_CTN
        , ShortAllocate  = ORD.ShortAllocate
        , PPDP_CTN       = ORD.PPDP_CTN
        , PutawayZone    = ORD.PutawayZone
        , Putawayzones   = ISNULL( RTRIM( CAST( (
                            SELECT TOP 5
                                   CONVERT(NCHAR(10),Putawayzone)
                                 + CONVERT(NCHAR(10),ISNULL(FORMAT(SUM(FCP_Qty)   ,'#'),''))
                                 + CONVERT(NCHAR(10),ISNULL(FORMAT(SUM(PP_Qty)    ,'#'),''))
                                 + CONVERT(NCHAR(10),ISNULL(FORMAT(SUM(Replen_Qty),'#'),''))
                            FROM #TEMP_ORDERDETAIL
                            WHERE Orderkey=ORD.Orderkey GROUP BY Putawayzone HAVING ISNULL(SUM(FCP_Qty),0)>0 OR ISNULL(SUM(PP_Qty),0)>0 OR ISNULL(SUM(Replen_Qty),0)>0 ORDER BY 1
                            FOR XML PATH('') ) AS NVARCHAR(200) ) ), '')
        , Company        = RTRIM( ST.Company )
        , KPIStartDateTime = DATEADD(d, CASE WHEN FORMAT(OH.AddDate,'HH:mm') < ISNULL( (select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(RptCfg5.Delim,RptCfg5.Notes) a, dbo.fnc_DelimSplit(RptCfg5.Delim,RptCfg5.Notes2) b
                                  where a.SeqNo=b.SeqNo and a.ColValue=OH.Type), ISNULL(RptCfg5.DftValue,'10:00') ) THEN 0 ELSE 1 END, OH.AddDate )
        , VAS            = CAST( ISNULL( (select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(RptCfg2.Delim,RptCfg2.Notes) a, dbo.fnc_DelimSplit(RptCfg2.Delim,RptCfg2.Notes2) b
                                  where a.SeqNo=b.SeqNo and a.ColValue=OH.Consigneekey)
                                , '' ) AS NVARCHAR(50))
        , Barcode        = CAST( RTRIM( CASE (select top 1 b.ColValue
                                   from dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes) a, dbo.fnc_DelimSplit(RptCfg.Delim,RptCfg.Notes2) b
                                   where a.SeqNo=b.SeqNo and a.ColValue='Barcode')
                             WHEN 'PICKSLIPNO'      THEN PH.PickHeaderKey
                             WHEN 'EXTERNORDERKEY'  THEN OH.ExternOrderkey
                             WHEN 'TRACKINGNO'      THEN OH.TrackingNo
                             ELSE                        OH.Orderkey
                          END ) AS NVARCHAR(30))
        , Lbl_Barcode    = CAST( RTRIM( (select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='T_Barcode') ) AS NVARCHAR(50))
        , Lottable02     = ORD.Lottable02
        , Picked_Qty     = ORD.Picked_Qty
        , Replened_Qty   = ORD.Replened_Qty
        , ShortPickQty   = ORD.ShortPickQty
        , OutstandingQty = ORD.OutstandingQty
        , Outstand       = ORD.OutstandingQty + ORD.Replen_Qty + IIF( ISNULL(OH.Status,'')='0',  0, ORD.ShortAllocate )
        , InterfaceDate  = OH.AddDate
        , ShowFields     = RptCfg4.ShowFields
        , datawindow     = @cDataWidnow
        , GOH            = ORD.GOH
        , CITIE          = ORD.CITIE
        , Lbl_ItemGroup  = CAST( RTRIM( (select top 1 b.ColValue
                                  from dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes) a, dbo.fnc_DelimSplit(RptCfg3.Delim,RptCfg3.Notes2) b
                                  where a.SeqNo=b.SeqNo and a.ColValue='T_ItemGroup') ) AS NVARCHAR(50))

   FROM #TEMP_ORDERDETAIL ORD
   LEFT OUTER JOIN dbo.ORDERS      OH (NOLOCK) ON ORD.OrderKey=OH.OrderKey
   LEFT OUTER JOIN dbo.PICKHEADER  PH (NOLOCK) ON ORD.OrderKey=PH.OrderKey
   LEFT OUTER JOIN dbo.STORER      ST (NOLOCK) ON ORD.StorerKey=ST.StorerKey

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPFIELD' AND Long=@cDataWidnow AND Short='Y'
   ) RptCfg
   ON RptCfg.Storerkey=ORD.Storerkey AND RptCfg.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@cDataWidnow AND Short='Y' AND UDF02='Consigneekey'
   ) RptCfg2
   ON RptCfg2.Storerkey=ORD.Storerkey AND RptCfg2.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPVALUE' AND Long=@cDataWidnow AND Short='Y'
   ) RptCfg3
   ON RptCfg3.Storerkey=ORD.Storerkey AND RptCfg3.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, ShowFields = LTRIM(RTRIM(UDF01)) + LOWER(LTRIM(RTRIM(Notes))) + LTRIM(RTRIM(UDF01))
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='SHOWFIELD' AND Long=@cDataWidnow AND Short='Y'
   ) RptCfg4
   ON RptCfg4.Storerkey=OH.Storerkey AND RptCfg4.SeqNo=1

   LEFT JOIN (
      SELECT Storerkey, Notes = RTRIM(Notes), Notes2 = RTRIM(Notes2), Delim = LTRIM(RTRIM(UDF01)), DftValue = TRIM(UDF03)
           , SeqNo=ROW_NUMBER() OVER(PARTITION BY Storerkey ORDER BY Code2)
        FROM dbo.CodeLkup (NOLOCK) WHERE Listname='REPORTCFG' AND Code='MAPCODE' AND Long=@cDataWidnow AND Short='Y' AND UDF02='KPIStartDateTime'
   ) RptCfg5
   ON RptCfg5.Storerkey=ORD.Storerkey AND RptCfg5.SeqNo=1

   ORDER BY Wavekey, Type, ConsigneeKey, ExternOrderKey, ItemGroup, Lottable02, Sku

END

GO