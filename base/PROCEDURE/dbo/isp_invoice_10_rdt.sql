SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/      
/* Store Procedure:  isp_invoice_10_rdt                                 */      
/* Creation Date: 18-JUN-2021                                           */      
/* Copyright: IDS                                                       */      
/* Written by: CSCHONG                                                  */      
/*                                                                      */      
/* Purpose: WMS-16914 [IN] - H&M - Invoice Label PB Report              */      
/*                                                                      */      
/*                                                                      */      
/* Input Parameters: (GUI.Externorderkey)                               */      
/*                                                                      */      
/*                                                                      */      
/* Output Parameters:                                                   */      
/*                                                                      */      
/* Usage:                                                               */      
/*                                                                      */      
/* Called By:  r_dw_invoice_10_rdt                                      */      
/*                                                                      */      
/* PVCS Version: 1.1                                                    */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/* 06-OCT-2021  CSCHONG  1.0  Devops scripts combine                    */
/* 17-NOV-2021  CSCHONG  1.1  WMS-18242 add additional parameter (CS01) */
/* 21-Nov-2021  CSCHONG  1.2  WMS-18242 revised field logic (CS02)      */
/* 18-Feb-2022  CSCHONG  1.3  WMS-18242 remove invoiceno parameter      */
/*                           and performance tunning  (CS03)            */
/* 16-Aug-2022  MINGLE   1.4  WMS-20474 change url (ML01)               */
/************************************************************************/      
      
CREATE PROC [dbo].[isp_invoice_10_rdt] (        
      @c_ExternOrderKey        NVARCHAR(50) = '', 
      @c_Orderkey              NVARCHAR(20) = ''
      --@c_invoiceno             NVARCHAR(20) = ''     
)      
AS      
BEGIN      
      
 SET NOCOUNT ON      
 SET ANSI_DEFAULTS OFF      
 SET QUOTED_IDENTIFIER OFF      
 SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_Continue        INT = 1      
          , @b_debug           INT = 0      
          , @c_EditWho         NVARCHAR(50) = ''      
          , @d_EditDate        DATETIME      
          , @nSumPackQty       INT = 0      
          , @c_GetPickslipno   NVARCHAR(20) = ''      
          , @nCartonNo         INT      
          , @c_pickslipno      NVARCHAR(10) = ''   
          , @n_MaxLineno       INT = 5              
          , @n_CurrentRec      INT             
          , @n_MaxRec          INT             
          , @n_cartonno        INT
          , @n_TTLGDTTY        INT
          , @c_TTLUPrice       NVARCHAR(20) 
          , @n_TTLCGST_AMOUNT  DECIMAL(10,2)               

 --START CS03  
   CREATE TABLE #TMP_GUIORDERS ( 
    Storerkey          NVARCHAR(20),
    GExternOrderKey    NVARCHAR(50),   
    ORDERKEY           NVARCHAR(10), 
    GInvoiceNo         NVARCHAR(20)   
   )    
   
  
  IF ISNULL(@c_ExternOrderKey,'') <> '' AND EXISTS (SELECT 1 FROM GUI WITH (NOLOCK)    
              WHERE ExternOrderKey = @c_ExternOrderKey   )
   BEGIN 
     IF NOT EXISTS (SELECT 1 FROM #TMP_GUIORDERS WHERE GExternOrderKey = @c_ExternOrderKey)
     BEGIN     

      INSERT INTO #TMP_GUIORDERS(Storerkey,GExternOrderKey,orderkey,GInvoiceNo)  
      SELECT DISTINCT G.Storerkey,G.ExternOrderKey,OH.OrderKey,G.InvoiceNo  
      FROM GUI G WITH (NOLOCK)
      JOIN ORDERS OH WITH (NOLOCK) ON 'a' +  G.ExternOrderKey = OH.externorderkey
      WHERE G.ExternOrderKey = @c_ExternOrderKey   

    END
   END               
   ELSE IF ISNULL(@c_Orderkey,'') <> '' AND EXISTS (SELECT 1 FROM Orders WITH (NOLOCK)    
              WHERE OrderKey = @c_Orderkey   )   
   BEGIN  
     IF NOT EXISTS (SELECT 1 FROM #TMP_GUIORDERS WHERE orderkey = @c_OrderKey)
     BEGIN   
         INSERT INTO #TMP_GUIORDERS(Storerkey,GExternOrderKey,orderkey,GInvoiceNo)  
         SELECT DISTINCT G.Storerkey,G.ExternOrderKey,OH.OrderKey,G.InvoiceNo  
         FROM ORDERS OH  WITH (NOLOCK)
         JOIN GUI G WITH (NOLOCK)  ON G.EXTERNORDERKEY = SUBSTRING( OH.EXTERNORDERKEY , 2,LEN(RTRIM(OH.EXTERNORDERKEY)) -1)
         WHERE OH.OrderKey = @c_OrderKey 
     END
   END    
   
   --END CS03  
       
           
   CREATE TABLE #INV10RDT_1(      
      rowid              INT NOT NULL IDENTITY(1,1) PRIMARY KEY,       
      GBillToName        NVARCHAR(80) NULL,
      GBillToAddr1       NVARCHAR(45) NULL,
      GBillToAddr2       NVARCHAR(45) NULL,
      GShipToAddr1       NVARCHAR(45) NULL,
      GShipToAddr2       NVARCHAR(45) NULL,
      GBillToName2       NVARCHAR(80) NULL,
      GAddDate           DATETIME NULL, 
      GInvoiceNo         NVARCHAR(10),   
      GExternOrderKey    NVARCHAR(50),
      GUserdefine01      NVARCHAR(80) NULL,
      GUserdefine06      DATETIME NULL,
      GSalesArea         NVARCHAR(20) NULL,
      GNotes             NVARCHAR(60) NULL,  
      GRemarks           NVARCHAR(20) NULL,
      GDSKU              NVARCHAR(20) NULL,
      GDSKUDesc          NVARCHAR(60) NULL, 
      GDUserdefine01     NVARCHAR(80) NULL,  
      SBUSR7             NVARCHAR(80) NULL,
      SBUSR6             NVARCHAR(80) NULL,
      GDQty              INT,
      GDUnitPrice        NVARCHAR(80) NULL,
      GDDiscAmount       DECIMAL(10,2),
      CGST               NVARCHAR(80) NULL,
      CGST_AMOUNT        NVARCHAR(80) NULL,
      SGST               NVARCHAR(80) NULL,
      SGST_AMOUNT        NVARCHAR(80) NULL,      
      GUserDefine03      NVARCHAR(80) NULL,
      GDAmount           DECIMAL(10,2),
      GUserDefine02      NVARCHAR(80) NULL,
      GUserDefine04      NVARCHAR(80) NULL,
      GUserDefine09      NVARCHAR(80) NULL,
      TTLCGST_AMOUNT     NVARCHAR(80) NULL,
      GTotalSalesAmt     DECIMAL(10,2),
      GTotDiscAmount     DECIMAL(10,2),
      CPCompany          NVARCHAR(45)  NULL,  
      CPAddress1         NVARCHAR(45)  NULL,  
      CPAddress2         NVARCHAR(200) NULL, 
      CPContact          NVARCHAR(90)  NULL, 
      CPCustURL          NVARCHAR(150) NULL,
      CPCompanyURL       NVARCHAR(150) NULL,
      CPCompanyRN        NVARCHAR(80)  NULL,     
      SHIPBYCompany      NVARCHAR(45)  NULL,
      SHIPBYAdd1         NVARCHAR(45)  NULL,
      SHIPBYAdd2         NVARCHAR(45)  NULL,
      SHIPBYAdd3         NVARCHAR(45)  NULL,
      SHIPBYAdd4         NVARCHAR(45)  NULL,
      SHIPBYCountry      NVARCHAR(45)  NULL,
      SHIPBYVAT          NVARCHAR(45)  NULL,
      QRcode1            NVARCHAR(100) NULL,
      AmtInWord          NVARCHAR(250) NULL,
      MoneySymbol        NVARCHAR(10)  NULL,  
      IGSTCGSTH          NVARCHAR(50)  NULL,
      IGSTCGSTHA         NVARCHAR(50)  NULL,
      SGSTH              NVARCHAR(50)  NULL,
      SGSTHA             NVARCHAR(50)  NULL,
      HMRefNoH           NVARCHAR(50)  NULL,
      GUserdefine10      NVARCHAR(250)  NULL
    )      
    
  INSERT INTO #INV10RDT_1
  (
      GBillToName,
      GBillToAddr1,
      GBillToAddr2,
      GShipToAddr1,
      GShipToAddr2,
      GBillToName2,
      GAddDate,
      GInvoiceNo,
      GExternOrderKey,
      GUserdefine01,
      GUserdefine06,
      GSalesArea,
      GNotes,
      GRemarks,
      GDSKU,
      GDSKUDesc,
      GDUserdefine01,
      SBUSR7,
      SBUSR6,
      GDQty,
      GDUnitPrice,
      GDDiscAmount,
      CGST,
      CGST_AMOUNT,
      SGST,
      SGST_AMOUNT,
      GUserDefine03,
      GDAmount,
      GUserDefine02,
      GUserDefine04,
      GUserDefine09,
      TTLCGST_AMOUNT,
      GTotalSalesAmt,
      GTotDiscAmount,
      CPCompany,
      CPAddress1,
      CPAddress2,
      CPContact,
      CPCustURL,
      CPCompanyURL,
      CPCompanyRN,
      SHIPBYCompany,
      SHIPBYAdd1,
      SHIPBYAdd2,
      SHIPBYAdd3,
      SHIPBYAdd4,
      SHIPBYCountry,
      SHIPBYVAT,
      QRcode1,
      AmtInWord,
      MoneySymbol,
      IGSTCGSTH,
      IGSTCGSTHA,
      SGSTH,
      SGSTHA,
      HMRefNoH,
      GUserdefine10

  )
  SELECT       GBillToName      = G.BillToName      , 
               GBillToAddr1     = G.BillToAddr1     , 
               GBillToAddr2     = G.BillToAddr2     , 
               GShipToAddr1     = G.ShipToAddr1     , 
               GShipToAddr2     = G.ShipToAddr2     , 
               GBillToName2     = G.BillToName2     , 
               GAddDate         = CASE WHEN G.Userdefine04  = '' OR G.Userdefine04 = '00000000' THEN PH.AddDate 
                                  ELSE CASE WHEN ISDATE(G.Userdefine04) = 1  THEN CAST(G.Userdefine04 AS DATE) END END  ,   --CS02
               GInvoiceNo       = G.InvoiceNo       , 
               GExternOrderKey  = G.ExternOrderKey  , 
               GUserdefine01    = CASE WHEN ISNULL(OH.Type,'')<>'Myntra' THEN ISNULL(G.ExternOrderKey,'')  ELSE ISNULL(G.UserDefine02,'') END    , 
               GUserdefine06    = OH.AddDate    , 
               GSalesArea       = G.SalesArea       , 
               GNotes           = G.Notes           , 
               GRemarks         = G.Remarks         , 
               GDSKU            = GD.sku            , 
               GDSKUDesc        = S.DESCR         , 
               GDUserdefine01   = ISNULL(GD.Remarks,'')   , 
               SBUSR7           = ISNULL(S.BUSR7,'')   , 
               SBUSR6           = ISNULL(S.BUSR6,'')   , 
               GDQty            = GD.Qty            , 
               GDUnitPrice      = GD.UnitPrice      , 
               GDDiscAmount     = CASE WHEN ISNUMERIC(GD.userdefine10) = 1 THEN CAST(GD.userdefine10 AS DECIMAL(10,2)) ELSE 0.00 END     , 
               CGST             = CASE WHEN ISNULL(GD.Userdefine03,'0.00') <>'0.00' THEN GD.Userdefine03
                                   ELSE GD.Userdefine01 END, 
               CGST_AMOUNT      = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') <>'0.00' THEN GD.Userdefine08
                                   ELSE GD.Userdefine06 END  , 
               SGST             = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN GD.Userdefine02
                                   ELSE '' END  , 
               SGST_AMOUNT      = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN GD.Userdefine07
                                   ELSE '' END   ,   
               GUserDefine03    = ISNULL(G.UserDefine03,'')  , 
               GDAmount         = GD.Amount       , 
               GUserDefine02    = CASE WHEN ISNULL(OH.Type,'')='Myntra' THEN ISNULL(G.ExternOrderKey,'')  ELSE '' END, 
               GUserDefine04    = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN G.ATMBankAcc
                                   ELSE '' END,--ISNULL(G.UserDefine04,'')  , 
               GUserDefine09    = ISNULL(G.UserDefine09,'')  , 
               TTLCGST_AMOUNT   = CASE WHEN ISNULL(GD.Userdefine03,'0.00') <>'0.00' THEN ISNULL(G.GUICheckNo,'0.00')
                                   ELSE ISNULL(G.TTBankAcc,'0.00') END  , 
               GTotalSalesAmt   = G.TotalSalesAmt          , 
               GTotDiscAmount   = G.TotDiscAmount         , 
               CPCompany        = ISNULL(ST.B_Company,'') , 
               CPAddress1       = ISNULL(ST.B_Address1,'') , 
               CPAddress2       = ISNULL(ST.B_Address2,'')  + ISNULL(ST.B_City,'')  
                                   + ISNULL(ST.B_State,'') + ISNULL(ST.B_Zip,'')  + ISNULL(ST.B_Country,''), 
               CPContact        = ISNULL(ST.B_Phone1,'') +  ISNULL(ST.SUSR1,'') , 
               CPCustURL        = ISNULL(ST.email1,'') , 
               CPCompanyURL     = ISNULL(ST.notes2,'') , 
               CPCompanyRN      = ISNULL(ST.notes1,'') , 
               SHIPBYCompany    = ISNULL(ST.Company,'')  , 
               SHIPBYAdd1       = ISNULL(ST.Address1,'')  , 
               SHIPBYAdd2       = ISNULL(ST.Address2,'')  , 
               SHIPBYAdd3       = ISNULL(ST.Address3,'') , 
               SHIPBYAdd4       = ISNULL(ST.Address4,'') , 
               SHIPBYCountry    = ISNULL(St.Country,'') , 
               SHIPBYVAT        = ISNULL(ST.VAT,''), 
               --QRcode1          ='https://hm-india.return-my.delivery/en' , 
			   QRcode1          ='https://returns.parcellab.com/hm/in/en/#/',	--ML01
               AmtInWord        = '' , 
               MoneySymbol      = ISNULL(ST.susr2,'Rs'),     
               IGSTCGSTH        = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN 'CGST'
                                   ELSE 'IGST' END ,
               IGSTCGSTHA       = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN 'CGST AMOUNT'
                                   ELSE 'IGST AMOUNT' END,
               SGSTH            = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN 'SGST'
                                   ELSE '' END,
               SGSTHA           = CASE WHEN  ISNULL(GD.Userdefine03,'0.00') = '0.00' THEN 'SGST AMOUNT'
                                   ELSE '' END,
               HMRefNoH         =  CASE WHEN ISNULL(OH.Type,'')='Myntra' THEN 'HM Reference Number' ELSE '' END,
               GUserdefine10    = CONCAT(LTRIM(RTRIM(G.UserDefine01)),LTRIM(RTRIM(G.UserDefine08)),LTRIM(RTRIM(G.UserDefine10)),LTRIM(RTRIM(G.CustServTel)))--ISNULL(G.Userdefine10,'')
FROM GUI G WITH (NOLOCK)
JOIN dbo.GUIDetail GD WITH (NOLOCK) ON GD.InvoiceNo = G.InvoiceNo AND GD.ExternOrderkey = G.ExternOrderKey
JOIN dbo.STORER ST WITH (NOLOCK) ON ST.StorerKey=G.Storerkey
JOIN ORDERS OH WITH (NOLOCK)  ON OH.buyerpo = G.ExternOrderKey 
JOIN SKU S WITH (NOLOCK) ON GD.SKU = S.SKU AND S.STORERKEY = GD.StorerKey
LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY
--CS03 S
JOIN #TMP_GUIORDERS GOH ON GOH.Storerkey=G.Storerkey AND GOH.GExternOrderKey =G.ExternOrderKey AND GOH.GInvoiceNo =G.InvoiceNo
--WHERE G.ExternOrderKey = CASE WHEN ISNULL(@c_ExternOrderKey,'') <> '' THEN @c_ExternOrderKey ELSE G.ExternOrderKey END   --CS01
--AND OH.OrderKey = CASE WHEN ISNULL(@c_Orderkey,'') <> '' THEN @c_Orderkey ELSE OH.orderkey END   --CS01
--AND G.invoiceno = CASE WHEN ISNULL(@c_invoiceno,'') <> '' THEN @c_invoiceno ELSE G.invoiceno END   --CS01
--CS03 E
ORDER BY G.ExternOrderKey,GD.SKU
                          
   SET @c_TTLUPrice = ''
   SET @n_TTLCGST_AMOUNT = 0.00
   SET @n_TTLGDTTY = 0

   SELECT  @n_TTLGDTTY = SUM(gdqty)
       --   ,@n_TTLCGST_AMOUNT = SUM(CAST(CGST_AMOUNT AS DECIMAL(10,2)))
   FROM #INV10RDT_1
   --WHERE GExternOrderKey = @c_ExternOrderKey     --CS01
        
 --SELECT @n_TTLCGST_AMOUNT '@n_TTLCGST_AMOUNT'
              
   SELECT   GBillToName,
            GBillToAddr1,
            GBillToAddr2,
            GShipToAddr1,
            GShipToAddr2,
            GBillToName2,
            GAddDate,
            GInvoiceNo,
            GExternOrderKey,
            GUserdefine01,
            GUserdefine06,
            GSalesArea,
            GNotes,
            GRemarks,
            GDSKU,
            GDSKUDesc,
            GDUserdefine01,
            SBUSR7,
            SBUSR6,
            GDQty,
            ISNULL(MoneySymbol,'Rs') + SPACE(2) + CONVERT(NVARCHAR(80),CAST(GDUnitPrice AS DECIMAL(10,2))) AS GDUnitPrice,
            GDDiscAmount,
            CASE WHEN ISNUMERIC(CGST) = 1 THEN CONVERT(NVARCHAR(80),CAST(CGST AS DECIMAL(10,2))) ELSE CGST END AS CGST,
            ISNULL(MoneySymbol,'Rs') + SPACE(2) + CGST_AMOUNT AS CGST_AMOUNT,
            CASE WHEN SGSTH <> '' THEN CASE WHEN SGST <> '' THEN CONVERT(NVARCHAR(80),CAST(SGST AS DECIMAL(10,2))) ELSE '0.00' END ELSE '' END AS SGST,
            CASE WHEN SGSTHA <> '' THEN CASE WHEN SGST_AMOUNT <> '' THEN ISNULL(MoneySymbol,'Rs') + SPACE(2) + CONVERT(NVARCHAR(80),CAST(SGST_AMOUNT AS DECIMAL(10,2))) 
            ELSE 'Rs  0.00' END ELSE '' END AS SGST_AMOUNT,
            ISNULL(MoneySymbol,'Rs') + SPACE(2) +  CONVERT(NVARCHAR(80),CAST(GDAmount AS DECIMAL(10,2))) AS GUserDefine03,
            GDAmount,
            GUserDefine02,
            CASE WHEN SGSTHA <> '' THEN CASE WHEN GUserDefine04 <> '' THEN  ISNULL(MoneySymbol,'Rs') + SPACE(2) + CONVERT(NVARCHAR(80),CAST(GUserDefine04 AS DECIMAL(10,2))) ELSE 'Rs  0.00' END ELSE '' END AS GUserDefine04,
            GUserDefine09,--CASE WHEN GUserDefine09 <> '' THEN CONVERT(NVARCHAR(80),CAST(GUserDefine09 AS DECIMAL(10,2))) ELSE '0.00' END AS GUserDefine09,--TTLSGSTAMT,
            ISNULL(MoneySymbol,'Rs') + SPACE(2) + CAST(TTLCGST_AMOUNT AS NVARCHAR(20)) AS TTLCGST_AMOUNT,
            ISNULL(MoneySymbol,'Rs') + SPACE(2) + CONVERT(NVARCHAR(80),CAST(GTotalSalesAmt AS DECIMAL(10,2))) AS GTotalSalesAmt,
            CONVERT(NVARCHAR(80),CAST(GTotDiscAmount AS DECIMAL(10,2))) AS GTotDiscAmount,
            CPCompany,
            CPAddress1,
            CPAddress2,
            CPContact,
            CPCustURL,
            CPCompanyURL,
            CPCompanyRN,
            SHIPBYCompany,
            SHIPBYAdd1,
            SHIPBYAdd2,
            SHIPBYAdd3,
            SHIPBYAdd4,
            SHIPBYCountry,
            SHIPBYVAT,
            QRcode1,
            (dbo.fnc_NumberToWords(GTotalSalesAmt,'Rupees','','','')) AS AmtInWord,
            @n_TTLGDTTY AS TTLGDQTY,
            ISNULL(MoneySymbol,'Rs') + SPACE(2) + GUserDefine03 AS TTLUnitPrice ,
            IGSTCGSTH,
            IGSTCGSTHA,
            SGSTH,
            SGSTHA,
            HMRefNoH,
            GUserdefine10               
   FROM #INV10RDT_1                       
   ORDER BY GExternOrderKey,GDSKU             
    
     
   IF OBJECT_ID('tempdb..#INV10RDT_1 ','u') IS NOT NULL       
   DROP TABLE #INV10RDT_1      
   

        
   IF OBJECT_ID('tempdb..#TMP_GUIORDERS ','u') IS NOT NULL       
   DROP TABLE #TMP_GUIORDERS   
END 


GO