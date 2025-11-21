SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--https://jiralfl.atlassian.net/browse/WMS-14416
CREATE VIEW [BI].[V_JRPT_MHAP_MHDC_PackingSlip]
AS
SELECT ROW_NUMBER() OVER (PARTITION BY O.LoadKey ORDER BY PD.Sku) AS RowNo,
       O.LoadKey,
       O.MBOLKey,
       --REPLACE(LTRIM(REPLACE(O.externorderkey,'0',' ')),' ','0') AS TLBNo,
       --C.eta AS DATE, 
       --C.etadestination AS ETASH, 
       --C.bookingreference AS ContainerNo, 
       --C.seal01 AS SealNo,
       O.IntermodalVehicle AS MODE,
       PD.Sku AS SAPITEMCODE,
       sku.DESCR AS PRODUCTDESCRIPTION,
       SUM(PD.Qty) AS Qty,
       SUM(SUM(PD.Qty)) OVER (PARTITION BY O.LoadKey) AS TotalQty,
       (SELECT ISNULL(CODELKUP.Description, '') FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'MHAPBRAND' AND Code = sku.SKUGROUP) AS Brand,
       (SELECT ISNULL(CODELKUP.Description, '') FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'MHAPCOO' AND Code = sku.CountryOfOrigin) AS CountryOfOrigin,
       (sku.NetWgt * SUM(PD.Qty)) AS NetWeight,
       SUM(sku.NetWgt * SUM(PD.Qty)) OVER (PARTITION BY O.LoadKey) AS TotalNetWeight,
       (sku.AvgCaseWeight * SUM(PD.Qty)) AS GrossWeight,
       SUM(sku.AvgCaseWeight * SUM(PD.Qty)) OVER (PARTITION BY O.LoadKey) AS TotalGrossWeight,
       (sku.Length * SUM(PD.Qty)) AS Volume,
       SUM(sku.Length * SUM(PD.Qty)) OVER (PARTITION BY O.LoadKey) AS TotalVolume
FROM dbo.PICKDETAIL PD WITH (NOLOCK)
LEFT JOIN dbo.ORDERS O WITH (NOLOCK) ON O.OrderKey = PD.OrderKey AND PD.Storerkey = O.StorerKey
LEFT JOIN dbo.SKU      WITH (NOLOCK) ON sku.Sku = PD.Sku AND sku.StorerKey = O.StorerKey
--LEFT JOIN dbo.PACK   P WITH (NOLOCK) ON P.PackKey = PD.PackKey
--LEFT OUTER JOIN dbo.CONTAINER C WITH (NOLOCK) ON C.mbolkey = O.mbolkey
WHERE O.StorerKey in ('MHAP')
--AND O.loadkey in ('0001352071') 
--AND O.loadkey in ('0001386661')
GROUP BY O.LoadKey,
         O.MBOLKey,
         --O.externorderkey,
         --C.eta, 
         --C.etadestination, 
         --C.bookingreference, 
         --C.seal01,
         O.IntermodalVehicle,
         PD.Sku,
         sku.DESCR,  
         sku.SKUGROUP, 
         sku.CountryOfOrigin, 
         sku.NetWgt, 
         sku.AvgCaseWeight, 
         sku.Length

GO