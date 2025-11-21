SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/      
/* Stored Procedure: ISP_ORD_INV_PUMA_RPT_RDT                              */      
/* Creation Date: 03-OCT-2022                                              */    
/* Copyright: LF Logistics                                                 */    
/* Written by: CHONGCS                                                     */    
/*                                                                         */    
/* Purpose:WMS-20872 ID–PUMA-B2C Order Invoice (New Format )               */     
/*                                                                         */      
/* Called By: R_DW_ORD_INV_PUMA_RPT_RDT                                    */      
/*                                                                         */      
/* GitLab Version: 1.0                                                     */      
/*                                                                         */      
/* Version: 1.0                                                            */      
/*                                                                         */      
/* Data Modifications:                                                     */      
/*                                                                         */      
/* Updates:                                                                */      
/* Date         Author  Ver   Purposes                                     */  
/* 03-OCT-2022  CHONGCS  1.0  DevOps Combine Script                        */   
/* 21-OCT-2022  CHONGCS  1.1  WMS-20872 revised field logic (CS01)         */
/***************************************************************************/          
CREATE   PROC [dbo].[ISP_ORD_INV_PUMA_RPT_RDT] (  
      @c_orderkey    NVARCHAR(10)  ,
      @c_Type        NVARCHAR(5) = 'H',  
      @c_RptLanguage NVARCHAR(5) ='EN'
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE  @c_Storerkey   NVARCHAR(15)                                              
         ,  @c_RetVal      NVARCHAR(255)    
         ,  @c_validate    NVARCHAR(1) = 'Y'
         ,  @c_valid       NVARCHAR(1) = 'Y'

   DECLARE  @n_totalpick INTEGER = 0,
            @n_totalorder INTEGER = 0 


   SELECT TOP 1 @c_validate =  Short 
   FROM CODELKUP WITH (NOLOCK) 
   WHERE LISTNAME = 'REPORTCFG' AND CODE = 'VALIDATESHORT' AND Storerkey = 'PUMA' AND Code2 = 'r_dw_ord_inv_puma_rpt_rdt' 

   SELECT @n_totalpick = SUM(Qty) 
   FROM PICKDETAIL WITH (NOLOCK) 
   WHERE OrderKey = @c_orderkey

   SELECT @n_totalorder = SUM(OriginalQty) 
   FROM ORDERDETAIL WITH (NOLOCK) 
   WHERE OrderKey = @c_orderkey

   SET @c_valid =case when @n_totalpick = @n_totalorder then 'Y' else 'N' end

CREATE TABLE #TMPORDINVPUMARPT
(
  InvoiceNo                 NVARCHAR(30) ,
  Contact                   NVARCHAR(45) ,
  [address]                 NVARCHAR(150),
  invoicedate               NVARCHAR(12),
  orderno                   NVARCHAR(45),
  sku                       NVARCHAR(20),
  productname               NVARCHAR(60),
  currencycode              NVARCHAR(20),
  unitprice                 DECIMAL(10,2) NULL DEFAULT(0.00),
  discount                  DECIMAL(10,2) NULL DEFAULT(0.00),
  totalprice                DECIMAL(10,2) NULL DEFAULT(0.00),
  totalpricebeforediscount  DECIMAL(10,2) NULL DEFAULT(0.00),
  totaldiscount             DECIMAL(10,2) NULL DEFAULT(0.00),
  totalafterdiscount        DECIMAL(10,2) NULL DEFAULT(0.00),
  qty                       INT NULL DEFAULT(0),
  shippingfee               DECIMAL(10,2) NULL DEFAULT(0.00),
  totalamountdue            DECIMAL(10,2) NULL DEFAULT(0.00),
  scolor                    NVARCHAR(10),
  ssize                     NVARCHAR(10),
  vatablesales              DECIMAL(10,2),
  vatamount                 DECIMAL(10,2),
  totalinclvat              DECIMAL(10,2),
  rptheader1                NVARCHAR(200),
  rptheader2                NVARCHAR(200),
  rptheader3                NVARCHAR(200),
  rpttitle                  NVARCHAR(200),
  companyname               NVARCHAR(200),
  companyadd1               NVARCHAR(200),
  companyadd2               NVARCHAR(200),
  companyadd3               NVARCHAR(200),
  companyadd4               NVARCHAR(200),
  companyadd5               NVARCHAR(200),
  invoicetitle              NVARCHAR(200),
  invoicedettitle           NVARCHAR(200),
  salesinvoicetitle         NVARCHAR(200),
  invoicedatetitle          NVARCHAR(200),
  ordnotitle                NVARCHAR(200),
  skutitle                  NVARCHAR(200),
  ssizetitle                NVARCHAR(200),
  scolortitle               NVARCHAR(200),
  prdnametitle              NVARCHAR(200),
  unitpricetitle            NVARCHAR(200),
  distitle                  NVARCHAR(200),
  totaltitle                NVARCHAR(200),
  bfdistitle                NVARCHAR(200),
  subdistitle               NVARCHAR(200),
  afdistitle                NVARCHAR(200),
  shipfeetitle              NVARCHAR(200),
  ttlamtduetitle            NVARCHAR(200),
  vatsstitle                NVARCHAR(200),
  ppntitle                  NVARCHAR(200),   
  ttlppntitle               NVARCHAR(200),
  qtytitle                  NVARCHAR(50)  
  )

CREATE TABLE #TMPORDINVPUMARPTRESULT
(
  InvoiceNo                 NVARCHAR(30) ,
  Contact                   NVARCHAR(45) ,
  [address]                 NVARCHAR(150),
  invoicedate               NVARCHAR(12),
  orderno                   NVARCHAR(45),
  sku                       NVARCHAR(20),
  productname               NVARCHAR(60),
  currencycode              NVARCHAR(20),
  unitprice                 NVARCHAR(20) NULL DEFAULT(0.00),
  discount                  NVARCHAR(20) NULL DEFAULT(0.00),
  totalprice                NVARCHAR(20) NULL DEFAULT(0.00),
  totalpricebeforediscount  NVARCHAR(20),
  totaldiscount             NVARCHAR(20),
  totalafterdiscount        NVARCHAR(20),
  qty                       INT NULL DEFAULT(0),
  shippingfee               NVARCHAR(20) DEFAULT ('0'),
  totalamountdue            NVARCHAR(20),
  scolor                    NVARCHAR(10),
  ssize                     NVARCHAR(10),
  vatablesales              NVARCHAR(20),
  vatamount                 NVARCHAR(20),
  totalinclvat              NVARCHAR(20),
  rptheader1                NVARCHAR(200),
  rptheader2                NVARCHAR(200),
  rptheader3                NVARCHAR(200),
  rpttitle                  NVARCHAR(200),
  companyname               NVARCHAR(200),
  companyadd1               NVARCHAR(200),
  companyadd2               NVARCHAR(200),
  companyadd3               NVARCHAR(200),
  companyadd4               NVARCHAR(200),
  companyadd5               NVARCHAR(200),
  invoicetitle              NVARCHAR(200),
  invoicedettitle           NVARCHAR(200),
  salesinvoicetitle         NVARCHAR(200),
  invoicedatetitle          NVARCHAR(200),
  ordnotitle                NVARCHAR(200),
  skutitle                  NVARCHAR(200),
  ssizetitle                NVARCHAR(200),
  scolortitle               NVARCHAR(200),
  prdnametitle              NVARCHAR(200),
  unitpricetitle            NVARCHAR(200),
  distitle                  NVARCHAR(200),
  totaltitle                NVARCHAR(200),
  bfdistitle                NVARCHAR(200),
  subdistitle               NVARCHAR(200),
  afdistitle                NVARCHAR(200),
  shipfeetitle              NVARCHAR(200),
  ttlamtduetitle            NVARCHAR(200),
  vatsstitle                NVARCHAR(200),
  ppntitle                  NVARCHAR(200),   
  ttlppntitle               NVARCHAR(200),
  qtytitle                  NVARCHAR(50)  
  )

IF @c_valid='N'
BEGIN
     GOTO QUIT_SP
END

IF @c_Type ='H'
BEGIN
      SELECT @c_orderkey AS orderkey
END
ELSE
BEGIN

  INSERT INTO #TMPORDINVPUMARPT
  (
      InvoiceNo,
      Contact,
      address,
      invoicedate,
      orderno,
      sku,
      productname,
      currencycode,
      unitprice,
      discount,
      totalprice,
      totalpricebeforediscount,
      totaldiscount,
      totalafterdiscount,
      qty,
      shippingfee,
      totalamountdue,
      scolor,
      ssize,
      vatablesales,
      vatamount,
      totalinclvat,
      rptheader1,
      rptheader2,
      rptheader3,
      rpttitle,
      companyname,
      companyadd1,
      companyadd2,
      companyadd3,
      companyadd4,
      companyadd5,
      invoicetitle,
      invoicedettitle,
      salesinvoicetitle,
      invoicedatetitle,
      ordnotitle,
      skutitle,
      ssizetitle,
      scolortitle,
      prdnametitle,
      unitpricetitle,
      distitle,
      totaltitle,
      bfdistitle,
      subdistitle,
      afdistitle,
      shipfeetitle,
      ttlamtduetitle,
      vatsstitle,
      ppntitle,
      ttlppntitle,
      qtytitle
  )

       SELECT
     'SI' + ORD.OrderKey as [InvoiceNo]
   , ORD.C_contact1 AS  [Contact]
   ,  CASE WHEN IsNull(ORD.C_Address2, '') <> '' THEN ORD.C_Address2 + CHAR(10) ELSE '' END
     + CASE WHEN IsNull(ORD.C_Address3, '') <> '' THEN ORD.C_Address3 + CHAR(10) ELSE '' END
     + CASE WHEN IsNull(ORD.C_City, '') <> '' THEN ORD.C_City ELSE '' END  
     + CASE WHEN IsNull(ORD.C_Address1, '') <> '' THEN ORD.C_Address1 + CHAR(10) ELSE '' END
     + CASE WHEN IsNull(ORD.C_zip, '') <> '' THEN ORD.C_zip + CHAR(10) ELSE '' END AS [Address]   
   , REPLACE(CONVERT(NVARCHAR(11),ISNULL(PIF.AddDate,'1900-01-01'),106),' ','-')  AS [InvoiceDate]   --CS01
   , OIF.EcomOrderId  AS [OrderNo]
   , OD.Sku  AS sku
   , S.DESCR  AS [ProductName]
   , ORD.CurrencyCode AS currencycode
   , CONVERT(DECIMAL(10,2),OD.ExtendedPrice)*PD.QtyPicked  AS  [UnitPrice]            --CS01a
   , CASE WHEN ISNUMERIC(OD.UserDefine01) = 1 THEN CONVERT(DECIMAL(10,2), OD.UserDefine01/OD.OriginalQty) * PD.QtyPicked ELSE 0.00 END AS [Discount]   --CS01a
   , CONVERT(DECIMAL(10,2),OD.UnitPrice/OD.OriginalQty) * PD.QtyPicked  AS [TotalPrice]  --CS01a
   , SUM(OD.ExtendedPrice * PD.QtyPicked) OVER (PARTITION BY OD.OrderKey) AS [TotalPriceBeforeDiscount] --AR01
   , SUM((Try_Convert(DECIMAL(10,2), OD.UserDefine01)/OD.OriginalQty) * PD.QtyPicked) OVER (PARTITION BY OD.OrderKey) [TotalDiscount] --AR01
   , SUM(OD.ExtendedPrice * PD.QtyPicked) OVER (PARTITION BY OD.OrderKey)  
     - SUM((Try_Convert(DECIMAL(10,2), OD.UserDefine01)/OD.OriginalQty) * PD.QtyPicked) OVER (PARTITION BY OD.OrderKey) [TotalAfterDiscount] --AR01
   , PD.QtyPicked  AS [Qty]                                               --CS01    --CS01a
   , CONVERT(DECIMAL(10,2), OIF.CarrierCharges) AS  [ShippingFee]
   , SUM(OD.ExtendedPrice * PD.QtyPicked) OVER (PARTITION BY OD.OrderKey)
     - SUM((Try_Convert(DECIMAL(10,2), OD.UserDefine01)/OD.OriginalQty) * PD.QtyPicked) OVER (PARTITION BY OD.OrderKey)
     + Try_Convert(DECIMAL(10,2), OIF.CarrierCharges) AS [TotalAmountDue] --AR01
   , S.BUSR1  AS [SColor]    --CS01a
   , S.Size  AS  SSize
   , 0.00  AS [VatableSales] --CONVERT(DECIMAL(10,2),(ORD.InvoiceAmount + OIF.CarrierCharges) / 1.11)  AS [VatableSales]
   , (CONVERT(DECIMAL(10,2), ORD.InvoiceAmount) + CONVERT(DECIMAL(10,2), OIF.CarrierCharges)) - 
     ((CONVERT(DECIMAL(10,2), ORD.InvoiceAmount) + CONVERT(DECIMAL(10,2), OIF.CarrierCharges))/1.11) / 1.11  AS [VatAmount]
   , ((CONVERT(DECIMAL(10,2), ORD.InvoiceAmount) + CONVERT(DECIMAL(10,2), OIF.CarrierCharges))/1.11) + ((CONVERT(DECIMAL(10,2), ORD.InvoiceAmount) 
    + CONVERT(DECIMAL(10,2), OIF.CarrierCharges)) - ((CONVERT(DECIMAL(10,2), ORD.InvoiceAmount) + CONVERT(DECIMAL(10,2), OIF.CarrierCharges))/1.11)) AS  [TotalInclVAT]
   ,  'Got any question? Please contact our Customer Service Team:' AS RptHeader1
   , '1800 1322 0382 (Monday-Friday 9am-6pm)' AS Rptheader2
   , 'service@sea.puma.com' AS Rptheader3
   , CASE WHEN @c_RptLanguage='EN' THEN 'SALES INVOICE' ELSE 'FAKTUR PENJUALAN' END AS RptTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'PT. Puma Sports Indonesia' ELSE 'PT. Puma Sports Indonesia' END AS CompanyName
   , 'Menara DEA Tower 1, 7 Floor Suite 703'  AS CompanyAdd1
   , 'Kawasan Mega Kuningan'  AS CompanyAdd2
   , 'Jl. Mega Kuningan Barat Kav. E4.3 No.1-2'  AS CompanyAdd3
   , 'Jakarta Selatan 12950'  AS CompanyAdd4
   , 'NPWP: 53.386.326.2-063.0000'  AS CompanyAdd5
   , CASE WHEN @c_RptLanguage='EN' THEN 'Invoice to:' ELSE 'Kepada:' END AS InvoiceTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Invoice Details:' ELSE 'Rincian Faktur:' END AS InvoiceDetTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Sales Invoice No.' ELSE 'No. Faktur Penjualan' END AS SalesInvoiceTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Invoice Date' ELSE 'Tanggal Invoice' END AS InvoiceDateTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Order No' ELSE 'No. Order' END AS OrdNoTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'SKU No.' ELSE 'No. SKU' END AS SKUTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Size' ELSE 'Ukuran' END AS SSizeTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Color' ELSE 'Warna' END AS ScolorTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Product Name' ELSE 'Nama Product' END AS PrdNameTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Unit Price'  + CHAR(10)  + '(Gross)' + CHAR(10)  +  '(' +ORD.CurrencyCode   +')' 
             ELSE 'Harga per Unit'  + CHAR(10)  + '(Bruto)' + CHAR(10)  + '(' + ORD.CurrencyCode  +')'   END AS UnitPriceTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Discount'  + CHAR(10) + '(' + ORD.CurrencyCode +')'  
             ELSE 'Potongan Harga'  + CHAR(10)  + '(' + ORD.CurrencyCode  +')'   END AS DisTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Total Price '   + CHAR(10)  + '(Net)' + CHAR(10)  +  '(' +ORD.CurrencyCode   +')' 
             ELSE 'Total Harga'  + CHAR(10)  + '(Bersih)' + CHAR(10)  + '(' + ORD.CurrencyCode  +')'   END AS TotalTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Total Price Before Discount:' ELSE 'Jumlah Sebelum Potongan Harga:' END AS BfDisTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Discounts:' ELSE 'Potongan Harga:' END AS subDisTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Total After Discounts:' ELSE 'Jumlah Setelah Potongan Harga:' END AS AfDisTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Shipping Fee:' ELSE 'Biaya Pengiriman:' END AS ShipfeeTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Total Amount Due:' ELSE 'Jumlah Tertagih:' END AS ttlamtdueTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'VAT-able Sales:' ELSE 'Penjualan Sebelum PPN:' END AS vatssTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'VAT Amount (11.00%):' ELSE 'PPN (11.00%):' END AS PPNTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Total Including VAT:' ELSE 'Jumlah Setelah PPN:' END AS TTLPPNTitle
   , CASE WHEN @c_RptLanguage='EN' THEN 'Qty' ELSE 'Jumlah' END AS QtyTitle
 FROM ORDERS ORD WITH (NOLOCK)
 JOIN ORDERDETAIL OD WITH (NOLOCK) ON ORD.OrderKey = OD.OrderKey
 CROSS APPLY (SELECT SUM(Qty) [QtyPicked] FROM PICKDETAIL WITH (NOLOCK) WHERE OrderKey = OD.OrderKey AND OrderLineNumber = OD.OrderLineNumber) AS PD  --CS01a
 JOIN SKU S WITH (NOLOCK) ON OD.StorerKey = S.StorerKey and OD.Sku = S.Sku
 --JOIN MBOL MB WITH (NOLOCK) ON ORD.MBOLKey = MB.MbolKey
 LEFT JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey=ORD.OrderKey                       --CS01
 LEFT JOIN PACKINFO PIF on PIF.PickSlipNo = PH.PickSlipNo                           --CS01 
 LEFT JOIN ORDERinfo OIF WITH (NOLOCK) ON ORD.OrderKey = OIF.OrderKey 
 WHERE ORD.OrderKey = @c_orderkey 

INSERT INTO #TMPORDINVPUMARPTRESULT
(
    InvoiceNo,
    Contact,
    address,
    invoicedate,
    orderno,
    sku,
    productname,
    currencycode,
    unitprice,
    discount,
    totalprice,
    totalpricebeforediscount,
    totaldiscount,
    totalafterdiscount,
    qty,
    shippingfee,
    totalamountdue,
    scolor,
    ssize,
    vatablesales,
    vatamount,
    totalinclvat,
    rptheader1,
    rptheader2,
    rptheader3,
    rpttitle,
    companyname,
    companyadd1,
    companyadd2,
    companyadd3,
    companyadd4,
    companyadd5,
    invoicetitle,
    invoicedettitle,
    salesinvoicetitle,
    invoicedatetitle,
    ordnotitle,
    skutitle,
    ssizetitle,
    scolortitle,
    prdnametitle,
    unitpricetitle,
    distitle,
    totaltitle,
    bfdistitle,
    subdistitle,
    afdistitle,
    shipfeetitle,
    ttlamtduetitle,
    vatsstitle,
    ppntitle,
    ttlppntitle,
    qtytitle
)
SELECT       InvoiceNo,
      Contact,
      address,
      invoicedate,
      orderno,
      sku,
      productname,
      currencycode,
      --REPLACE(FORMAT((unitprice), '#,###_#0'),',','.') END unitprice,
      CAST(format(unitprice, 'N', 'de-DE') as NVARCHAR(20)) AS unitprice,
      CAST(format(discount, 'N', 'de-DE') as NVARCHAR(20))   discount,
      CAST(format(totalprice, 'N', 'de-DE') as NVARCHAR(20))   totalprice,
      CAST(format(totalpricebeforediscount, 'N', 'de-DE') as NVARCHAR(20))   totalpricebeforediscount,
      CAST(format(totaldiscount, 'N', 'de-DE') as NVARCHAR(20))   totaldiscount,
      CAST(format(totalafterdiscount, 'N', 'de-DE') as NVARCHAR(20))   totalafterdiscount,    --cS01a
      qty,
      CAST(format(shippingfee, 'N', 'de-DE') as NVARCHAR(20))  shippingfee,
      CAST(format((totalafterdiscount + shippingfee), 'N', 'de-DE') as NVARCHAR(20))  totalamountdue,    --CS01a
      scolor,
      ssize,
      CAST(format((totalafterdiscount + shippingfee)/1.11, 'N', 'de-DE') as NVARCHAR(20))   vatablesales,   --CS01a
      CAST(format(((totalafterdiscount + shippingfee)/1.11)*0.11, 'N', 'de-DE') as NVARCHAR(20))  vatamount,
      CAST(FORMAT((((totalafterdiscount + shippingfee)/1.11) + (((totalafterdiscount + shippingfee)/1.11)*0.11)) , 'N', 'de-DE') as NVARCHAR(20))   totalinclvat,
      rptheader1,
      rptheader2,
      rptheader3,
      rpttitle,
      companyname,
      companyadd1,
      companyadd2,
      companyadd3,
      companyadd4,
      companyadd5,
      invoicetitle,
      invoicedettitle,
      salesinvoicetitle,
      invoicedatetitle,
      ordnotitle,
      skutitle,
      ssizetitle,
      scolortitle,
      prdnametitle,
      unitpricetitle,
      distitle,
      totaltitle,
      bfdistitle,
      subdistitle,
      afdistitle,
      shipfeetitle,
      ttlamtduetitle,
      vatsstitle,
      ppntitle,
      ttlppntitle,
      qtytitle--,totalafterdiscount --, unitprice AS oridiscount,CHARINDEX('.',unitprice)
FROM #TMPORDINVPUMARPT


SELECT --distinct  FORMAT((unitprice), '#.###,#0') AS unitpriceconvert,   
InvoiceNo,
    Contact,
    address,
    invoicedate,
    orderno,
    sku,
    productname,
    currencycode,
    CASE WHEN unitprice <> '' THEN unitprice ELSE '0' END unitprice,
    CASE WHEN discount <> '' THEN discount ELSE '0' END discount,
    CASE WHEN totalprice <> '' THEN totalprice ELSE '0' END totalprice,
    CASE WHEN totalpricebeforediscount <> '' THEN totalpricebeforediscount ELSE '0' END totalpricebeforediscount,
    CASE WHEN totaldiscount <> '' THEN totaldiscount ELSE '0' END totaldiscount,
    CASE WHEN totalafterdiscount <> '' THEN totalafterdiscount ELSE '0' END totalafterdiscount,
    qty,
     CASE WHEN shippingfee <> '' THEN shippingfee ELSE '0' END shippingfee,
    CASE WHEN totalamountdue <> '' THEN totalamountdue ELSE '0' END  totalamountdue,
    scolor,
    ssize,
    CASE WHEN vatablesales <> '' THEN vatablesales ELSE '0' END vatablesales,
    CASE WHEN vatamount <> '' THEN vatamount ELSE '0' END vatamount,
    CASE WHEN totalinclvat <> '' THEN totalinclvat ELSE '0' END totalinclvat,
    rptheader1,
    rptheader2,
    rptheader3,
    rpttitle,
    companyname,
    companyadd1,
    companyadd2,
    companyadd3,
    companyadd4,
    companyadd5,
    invoicetitle,
    invoicedettitle,
    salesinvoicetitle,
    invoicedatetitle,
    ordnotitle,
    skutitle,
    ssizetitle,
    scolortitle,
    prdnametitle,
    unitpricetitle,
    distitle,
    totaltitle,
    bfdistitle,
    subdistitle,
    afdistitle,
    shipfeetitle,
    ttlamtduetitle,
    vatsstitle,
    ppntitle,
    ttlppntitle,
    qtytitle 
FROM #TMPORDINVPUMARPTRESULT

END

QUIT_SP: 

   IF OBJECT_ID('tempdb..#TMPORDINVPUMARPT') IS NOT NULL  
      DROP TABLE #TMPORDINVPUMARPT  


   IF OBJECT_ID('tempdb..#TMPORDINVPUMARPTRESULT') IS NOT NULL  
      DROP TABLE #TMPORDINVPUMARPTRESULT  



END  

GO