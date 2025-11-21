SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Purpose: print TRU-ECOM pick slip and courier report https://jiralfl.atlassian.net/browse/WMS-21883  */
/* Updates:                                                                */
/* Date         Author      Ver.  Purposes                                 */
/* 08/05/2013   wwang       1.0    Created                                 */
/* 06/03/2023   KSheng      1.1    Revised to Best Practice                */
/***************************************************************************/
-- Test: EXEC BI.nsp_ECOM_Report_TRU '0','0009137431','0'
CREATE   PROCEDURE [BI].[nsp_ECOM_Report_TRU]
   @type    INT, /*0 : print by loadkey, 1: print by orderkey, 2: test*/
   @loadkey NVARCHAR(10),
   @Qty     NVARCHAR(1)
AS

   DECLARE @Debug	BIT = 0
		 , @LogId   INT
       , @LinkSrv   NVARCHAR(128)
       , @Schema    NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
       , @Proc      NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'') --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "type":"'+CAST(@type AS NVARCHAR(10))+'"'
                                    + '"@loadkey":"'+@loadkey+'"'
                                    + '"@Qty":"'+@Qty+'"'
                                    + ' }'

   EXEC BI.dspExecInit @ClientId = 'TRU'
   , @Proc = @Proc
   , @ParamIn = @cParamIn
   , @LogId = @LogId OUTPUT
   , @Debug = @Debug OUTPUT
   , @Schema = @Schema;

	DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

--CREATE TABLE #CartonType (
--   Orderkey   CHAR(10),
--   CartonType CHAR(50)
--)
--DELETE #CartonType
SELECT @loadkey = ISNULL(@loadkey,'')

IF @Qty=1
BEGIN
SELECT t1.OrderKey
     , RTRIM(t1.ExternOrderKey) AS 'ExternOrderkey'
     , '*' + t1.OrderKey + '*'  AS 'BarCode'
     , t1.LoadKey
     , CASE WHEN t1.StorerKey='18359' THEN LTRIM(ISNULL(t1.C_contact1,'')) ELSE RTRIM(ISNULL(t1.C_contact1,'')) END AS 'Contact'
     , RTRIM(ISNULL(t1.C_Company,'')) AS 'Company'
     , RTRIM(ISNULL(t1.C_Address1,'')) AS District, RTRIM(ISNULL(t1.C_Address2,'')) + RTRIM(ISNULL(t1.C_Address3,'')) + RTRIM(ISNULL(t1.C_Address4,'')) AS 'Address'
     , RTRIM(ISNULL(t1.C_State,'')) AS'Province'
     , RTRIM(ISNULL(t1.C_City,''))  AS 'City'
     , t2.Sku, RTRIM(t3.DESCR) AS 'DESCR'
     , CASE WHEN t3.BUSR7='0' THEN '' ELSE N'有电池' END AS 'BatteryType'
     , t2.Loc, SUM(t2.Qty) AS 'Qty'
     , t3.ALTSKU
     , t3.BUSR6
     , t3.BUSR8
     , RTRIM(ISNULL(t1.C_Phone1,''))+ CASE ISNULL(t1.C_Phone2,'') WHEN '' THEN '' ELSE '/' END + RTRIM(ISNULL(t1.C_Phone2,'')) AS 'Phone'
     , RTRIM(ISNULL(t1.C_Zip,'')) AS ZIP,RTRIM(ISNULL(t1.C_Country,'')) AS Country
     , RTRIM(ISNULL(t1.BuyerPO,'')) AS ID, CASE WHEN ISNULL(t1.PmtTerm,'1')='1' THEN N'在线支付' ELSE N'货到付款' END AS 'payment'
     , t1.InvoiceAmount
     , CASE WHEN t1.UserDefine01='1' THEN N'周末配送' WHEN t1.UserDefine01='2' THEN N'工作日配送' ELSE N'均可' END AS 'DeliveryTime'
     , t1.ShipperKey
     , t1.UserDefine05
     , t4.Unitprice
     , CASE WHEN t1.StorerKey='18359' THEN N'鞋服配' ELSE N'玩具' END AS 'SKUGroup'
     , CAST(t1.Notes AS NCHAR(100)) AS 'Notes'
     , CAST(t1.Notes2 AS NCHAR(100)) AS 'Notes2'
     , CONVERT(CHAR(10),t1.AddDate,121) AS 'AddDate'
     , t5.Contact1 AS 'WH_Contact', t5.Address1 AS 'WH_District',t5.Address2 AS 'WH_Address', t5.Phone1 AS 'WH_Phone',t5.Phone2 AS 'WH_Mobile'
     , CASE WHEN t1.UserDefine01='360BUY' AND t1.StorerKey='18359' THEN t5.B_Company ELSE t5.Company END AS 'Storer'
     , t6.Long AS 'CourierMap'
     , RTRIM(ISNULL(t1.M_Company,'')) AS 'Company(Mark For)'
FROM BI.V_ORDERS t1 (NOLOCK)
JOIN BI.V_PickDetail t2 (NOLOCK) ON t1.OrderKey = t2.OrderKey
JOIN BI.V_SKU t3 (NOLOCK) ON t2.Storerkey = t3.StorerKey AND t2.Sku = t3.Sku
JOIN (SELECT OrderKey, Sku, MAX(UnitPrice) AS Unitprice FROM BI.V_ORDERDetail(NOLOCK) WHERE StorerKey IN('18359','18417') GROUP BY OrderKey, Sku) AS t4 ON t2.OrderKey=t4.OrderKey AND t2.Sku=t4.Sku
JOIN BI.V_STORER AS t5 ON t1.StorerKey=t5.StorerKey
LEFT JOIN BI.V_CODELKUP AS t6 ON t6.LISTNAME='COURIERMAP' AND LTRIM(RTRIM(t6.Short)) = LTRIM(RTRIM(t1.ShipperKey)) AND LTRIM(RTRIM(CAST(t6.Notes AS NVARCHAR(100)))) = LTRIM(RTRIM(t1.C_State)) 
                             AND LTRIM(RTRIM(CAST(t6.Notes2 AS NVARCHAR(100)))) = LTRIM(RTRIM(t1.C_City)) AND LTRIM(RTRIM(t6.Description)) = LTRIM(RTRIM(t1.C_Address1))
WHERE t1.StorerKey IN ('18359','18417')
AND ( (@type = 0 AND t1.LoadKey = @loadkey AND t1.Status IN ('1','2','3','5','9') ) OR
  (@type = 1 AND t1.OrderKey = @loadkey AND t1.Status IN ('2','3','5','9')))
AND (CASE WHEN @Qty='1' AND t1.OpenQty=1 THEN 1 WHEN @Qty='0' THEN 1 WHEN @Qty>'1' AND t1.OpenQty>1 THEN 1 ELSE 0 END)=1
GROUP BY  t1.OrderKey,RTRIM(t1.ExternOrderKey),t1.LoadKey, t1.StorerKey,
         RTRIM(ISNULL(t1.C_Company,'')),
         RTRIM(ISNULL(t1.C_Address1,'')), RTRIM(ISNULL(t1.C_Address2,'')) +
         RTRIM(ISNULL(t1.C_Address3,'')) + RTRIM(ISNULL(t1.C_Address4,'')),
         RTRIM(ISNULL(t1.C_State,'')),RTRIM(ISNULL(t1.C_City,'')),
         t2.Sku, t3.ALTSKU,t3.BUSR6,t3.BUSR8,t3.BUSR7,RTRIM(t3.DESCR), t2.Loc,
         RTRIM(ISNULL(t1.C_Phone1,''))+ CASE ISNULL(t1.C_Phone2,'') WHEN '' THEN '' ELSE '/' END + RTRIM(ISNULL(t1.C_Phone2,'')),
         RTRIM(ISNULL(t1.C_Zip,'')),
         RTRIM(ISNULL(t1.C_Country,'')),RTRIM(ISNULL(t1.BuyerPO,'')),
         RTRIM(ISNULL(t1.BuyerPO,'')), CASE WHEN ISNULL(t1.PmtTerm,'1')='1' THEN N'在线支付' ELSE N'货到付款' END,
         t1.InvoiceAmount, CASE WHEN t1.UserDefine01='1' THEN N'周末配送' WHEN t1.UserDefine01='2' THEN N'工作日配送' ELSE N'均可' END,
         t1.ShipperKey,t1.UserDefine05, t4.Unitprice, t1.C_contact1,
         CAST(t1.Notes AS NCHAR(100)),
         CAST(t1.Notes2 AS NCHAR(100)),
         CONVERT(CHAR(10),t1.AddDate,121),
         t5.Contact1, t5.Address1,t5.Address2, t5.Phone1,t5.Phone2, t5.B_Company,t5.Company,t6.Long,t1.UserDefine01,RTRIM(ISNULL(t1.M_Company,''))
ORDER BY  t2.Loc,t1.OrderKey
END
ELSE
BEGIN
SELECT t1.OrderKey, RTRIM(t1.ExternOrderKey) AS ExternOrderkey, '*' + t1.OrderKey +'*' AS BarCode, t1.LoadKey,
         CASE WHEN t1.StorerKey='18359' THEN LTRIM(ISNULL(t1.C_contact1,'')) ELSE RTRIM(ISNULL(t1.C_contact1,'')) END AS Contact,
       RTRIM(ISNULL(t1.C_Company,'')) AS Company,
       RTRIM(ISNULL(t1.C_Address1,'')) AS District, RTRIM(ISNULL(t1.C_Address2,'')) +
       RTRIM(ISNULL(t1.C_Address3,'')) + RTRIM(ISNULL(t1.C_Address4,'')) AS Address,
       RTRIM(ISNULL(t1.C_State,'')) AS Province,
       RTRIM(ISNULL(t1.C_City,''))  AS City,
       t2.Sku, RTRIM(t3.DESCR) AS DESCR, CASE WHEN t3.BUSR7='0' THEN '' ELSE N'有电池' END AS BatteryType,t2.Loc, SUM(t2.Qty) AS Qty,
       t3.ALTSKU,t3.BUSR6, t3.BUSR8,
       RTRIM(ISNULL(t1.C_Phone1,''))+ CASE ISNULL(t1.C_Phone2,'') WHEN '' THEN '' ELSE '/' END + RTRIM(ISNULL(t1.C_Phone2,'')) AS Phone,
       RTRIM(ISNULL(t1.C_Zip,'')) AS ZIP,RTRIM(ISNULL(t1.C_Country,'')) AS Country,
       RTRIM(ISNULL(t1.BuyerPO,'')) AS ID, CASE WHEN ISNULL(t1.PmtTerm,'1')='1' THEN N'在线支付' ELSE N'货到付款' END AS payment,
       t1.InvoiceAmount, CASE WHEN t1.UserDefine01='1' THEN N'周末配送' WHEN t1.UserDefine01='2' THEN N'工作日配送' ELSE N'均可' END AS DeliveryTime,
       t1.ShipperKey,t1.UserDefine05, t4.Unitprice, CASE WHEN t1.StorerKey='18351' THEN N'鞋服配' ELSE N'玩具' END AS SKUGroup,
       CAST(t1.Notes AS NCHAR(100)) AS Notes,CAST(t1.Notes2 AS NCHAR(100)) AS Notes2,
       CONVERT(CHAR(10), t1.AddDate,121) AS AddDate,
       t5.Contact1 AS WH_Contact, t5.Address1 AS WH_District,t5.Address2 AS WH_Address, t5.Phone1 AS WH_Phone,t5.Phone2 AS WH_Mobile,CASE WHEN t1.UserDefine01='360BUY' AND t1.StorerKey='18359' THEN t5.B_Company ELSE t5.Company END AS Storer,
       t6.Long AS CourierMap, RTRIM(ISNULL(t1.M_Company,'')) AS 'Company(Mark For)'
FROM BI.V_ORDERS t1 (NOLOCK)
JOIN BI.V_PickDetail t2 (NOLOCK) ON t1.OrderKey = t2.OrderKey
JOIN BI.V_SKU t3 (NOLOCK) ON t2.Storerkey = t3.StorerKey AND t2.Sku = t3.Sku
JOIN (SELECT OrderKey, Sku, MAX(UnitPrice) AS Unitprice FROM BI.V_ORDERDetail(NOLOCK) WHERE StorerKey IN('18359','18417') GROUP BY OrderKey, Sku) AS t4 ON t2.OrderKey=t4.OrderKey AND t2.Sku=t4.Sku
JOIN BI.V_STORER (NOLOCK) AS t5 ON t1.StorerKey=t5.StorerKey
LEFT JOIN BI.V_CODELKUP (NOLOCK) AS t6 ON t6.LISTNAME='COURIERMAP' AND LTRIM(RTRIM(t6.Short))=LTRIM(RTRIM(t1.ShipperKey)) AND LTRIM(RTRIM(CAST(t6.Notes AS NVARCHAR(100))))=LTRIM(RTRIM(t1.C_State))
                                      AND LTRIM(RTRIM(CAST(t6.Notes2 AS NVARCHAR(100))))=LTRIM(RTRIM(t1.C_City)) AND LTRIM(RTRIM(t6.Description))=LTRIM(RTRIM(t1.C_Address1))
WHERE t1.StorerKey IN('18359','18417')
AND ((@type = 0 AND t1.LoadKey = @loadkey AND t1.Status IN ('1','2','3','5','9') ) OR
  (@type = 1 AND t1.OrderKey = @loadkey AND t1.Status IN ('2','3','5','9')))
AND (CASE WHEN @Qty='1' AND t1.OpenQty=1 THEN 1 WHEN @Qty='0' THEN 1 WHEN @Qty>'1' AND t1.OpenQty>1 THEN 1 ELSE 0 END)=1
GROUP BY t1.OrderKey,RTRIM(t1.ExternOrderKey),t1.LoadKey, t1.StorerKey,
         RTRIM(ISNULL(t1.C_Company,'')),
         RTRIM(ISNULL(t1.C_Address1,'')), RTRIM(ISNULL(t1.C_Address2,'')) +
         RTRIM(ISNULL(t1.C_Address3,'')) + RTRIM(ISNULL(t1.C_Address4,'')),
         RTRIM(ISNULL(t1.C_State,'')),RTRIM(ISNULL(t1.C_City,'')),
         t2.Sku, t3.ALTSKU,t3.BUSR7,t3.BUSR6,t3.BUSR8,RTRIM(t3.DESCR), t2.Loc,
         RTRIM(ISNULL(t1.C_Phone1,''))+ CASE ISNULL(t1.C_Phone2,'') WHEN '' THEN '' ELSE '/' END + RTRIM(ISNULL(t1.C_Phone2,'')),
         RTRIM(ISNULL(t1.C_Zip,'')),
         RTRIM(ISNULL(t1.C_Country,'')),RTRIM(ISNULL(t1.BuyerPO,'')),
         RTRIM(ISNULL(t1.BuyerPO,'')), CASE WHEN ISNULL(t1.PmtTerm,'1')='1' THEN N'在线支付' ELSE N'货到付款' END,
         t1.InvoiceAmount, CASE WHEN t1.UserDefine01='1' THEN N'周末配送' WHEN t1.UserDefine01='2' THEN N'工作日配送' ELSE N'均可' END,
         t1.ShipperKey,t1.UserDefine05, t4.Unitprice,
         CAST(t1.Notes AS NCHAR(100)),
         CAST(t1.Notes2 AS NCHAR(100)),
         CONVERT(CHAR(10),t1.AddDate,121),t1.C_contact1,
         t5.Contact1, t5.Address1,t5.Address2, t5.Phone1,t5.Phone2, t5.B_Company,t5.Company,t6.Long,t1.UserDefine01,RTRIM(ISNULL(t1.M_Company,''))
ORDER BY t1.OrderKey,t2.Loc,t2.Sku
END

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LinkSrv = @LinkSrv
   , @LogId = @LogId
   , @Debug = @Debug;

GO