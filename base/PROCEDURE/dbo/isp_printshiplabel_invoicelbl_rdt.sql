SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Proc: isp_PrintshipLabel_invoicelbl_rdt                       */  
/* Creation Date: 12-AUG-2022                                           */  
/* Copyright: LF Logistics                                              */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-20338 VN –JASPAL_Create Invoice Paperdatawindows report */  
/*        :                                                             */  
/* Called By: r_dw_print_shiplabel_invoicelbl_rdt                       */  
/*          :                                                           */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author   Ver   Purposes                                  */  
/* 12-AUG-2022 CSCHONG  1.1   Devops Scripts combine                    */  
/* 21-Sep-2023 CSCHONG  1.2   WMS-23617 revised footer (CS01)           */
/* 28-Sep-2023 CSCHONG  1.3   WMS-23617 Fix footer remark (CS02)        */
/************************************************************************/  
CREATE    PROC [dbo].[isp_PrintshipLabel_invoicelbl_rdt]  
            @c_externOrderKey     NVARCHAR(50)  
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
           @n_StartTCnt       INT  
         , @n_Continue        INT  
  
         , @c_moneysymbol    NVARCHAR(5)  
         , @c_VATSymbol      NVARCHAR(5)  
        -- , @n_    DATETIME  
         , @n_TTLUnitPrice   DECIMAL(10,2)  
         , @n_TTLTax01       DECIMAL(10,2)  
         , @n_TTLPrice       DECIMAL(10,2)  
         , @c_footerRemarks  NVARCHAR(500)  
  
         , @n_Leadtime        INT  
         , @n_Leadtime1       INT  
         , @n_Leadtime2       INT  
         , @n_MaxLine         INT  
  
   SET @n_StartTCnt = @@TRANCOUNT  
   SET @n_Continue = 1  
  
   SET @n_Maxline = 17  
   SET @c_moneysymbol = N'VND'  
   SET @c_VATSymbol = 'VAT'  
   SET @n_TTLUnitPrice = 0.00  
   SET @n_TTLTax01     = 0.00  
   SET @n_TTLPrice     = 0.00  
   SET @c_footerRemarks = 'If you have any questions, please send an email to hello@skechers.co.th'  
  
  
   CREATE TABLE #PRNSHIPINVLBLRPT  
      (  CCtext            NVARCHAR(30)  
      ,  CarrierCharges   NVARCHAR(30)  
      --,  money          NVARCHAR(30)  
      ,  C_phone1         NVARCHAR(45) NULL   
      ,  moneysymbol      NVARCHAR(5)  
      ,  Orderkey         NVARCHAR(10)  
      ,  ExternOrderkey   NVARCHAR(50)  
      ,  c_city           NVARCHAR(45)  
      ,  c_country        NVARCHAR(45)  
      ,  PmtTerm          NVARCHAR(10)  
      ,  C_Address1       NVARCHAR(45)  
      ,  C_Address2       NVARCHAR(45)  
      ,  C_Address3       NVARCHAR(45)  
      ,  C_Address4       NVARCHAR(45)  
      ,  C_contact1       NVARCHAR(45)  
      ,  c_zip            NVARCHAR(45)   
      ,  B_Address4       NVARCHAR(45)  
      ,  B_city           NVARCHAR(45)  
      ,  B_Contact1       NVARCHAR(45)  
      ,  B_zip            NVARCHAR(45)  
      ,  B_country        NVARCHAR(45)  
      ,  C_phone2         NVARCHAR(45)  
    --  ,  ST_VAT            NVARCHAR(36)  
      ,  B_Phone1         NVARCHAR(45)  
      ,  OHNotes          NVARCHAR(100)    
      ,  Storerkey        NVARCHAR(15)  
      ,  Sku              NVARCHAR(80)  
      ,  StyleColor       NVARCHAR(30)  
     -- ,  ODTax01          DECIMAL(10,2)  
      ,  UNITPRICE        NVARCHAR(20)    
      ,  INVAmt           NVARCHAR(20)  
      ,  PQTY             INT  
   --   ,  EcomOrderId       NVARCHAR(45)  
      ,  B_Address1      NVARCHAR(45)  
      ,  B_Address2       NVARCHAR(45)  
      ,  B_Address3       NVARCHAR(45)  
      ,  Pageno           INT  
      ,  totalPaid        NVARCHAR(20)  
      ,  OrderDate        NVARCHAR(50)      NULL   
      ,  shipperContact   NVARCHAR(50)    NULL  
      ,  shipperCompany   NVARCHAR(80)    NULL  
      ,  shipperAdd       NVARCHAR(150)   NULL  
      ,  shipperEmail     NVARCHAR(100)   NULL  
      ,  shipperPhone     NVARCHAR(50)    NULL  
      ,  Unitqty         INT  
      )  
  
  INSERT INTO #PRNSHIPINVLBLRPT  
  (  
      CCtext,  
      CarrierCharges,  
      C_phone1,  
      moneysymbol,  
      Orderkey,  
      ExternOrderkey,  
      c_city,  
      c_country,  
      PmtTerm,  
      C_Address1,  
      C_Address2,  
      C_Address3,  
      C_Address4,  
      C_contact1,  
      c_zip,  
      B_Address4,  
      B_city,  
      B_Contact1,  
      B_zip,  
      B_country,  
      C_phone2,  
      B_Phone1,  
      OHNotes,  
      Storerkey,  
      Sku,  
      StyleColor,  
      UNITPRICE,  
      INVAmt,  
      PQTY,  
      B_Address1,  
      B_Address2,  
      B_Address3,  
      Pageno,  
      totalPaid,  
      OrderDate,  
      shipperContact,  
      shipperCompany,  
      shipperAdd,  
      shipperEmail,  
      shipperPhone,Unitqty)  
  SELECT CASE WHEN OIF.CarrierCharges = 0 THEN 'Free Delivery' ELSE CAST(OIF.CarrierCharges AS NVARCHAR(30)) + 'd' END,    -- CCtext - nvarchar(30)  
   @c_moneysymbol +  SPACE(1) + REPLACE(CAST(FORMAT(ABS(OIF.CarrierCharges), 'C0', 'en-us') AS NVARCHAR(10)),'$',''),       -- CarrierCharges - float  
    ISNULL(OH.c_phone1,''),       -- C_phone1 - nvarchar(45)  
    @c_moneysymbol,  
    OH.Orderkey,       -- Orderkey - nvarchar(10)  
    OH.Externorderkey,       -- ExternOrderkey - nvarchar(50)  
    ISNULL(OH.c_city,''),       -- c_city - nvarchar(45)  
    ISNULL(OH.c_country,''),       -- c_country - nvarchar(45)  
    CASE WHEN OH.PmtTerm = 'CC' THEN 'PAID' ELSE 'COD' END AS PmtTerm,       -- PmtTerm - nvarchar(10)  
    ISNULL(OH.c_address1,''),       -- C_Address1 - nvarchar(45)  
    ISNULL(OH.c_address2,''),       -- C_Address2 - nvarchar(45)  
    ISNULL(OH.c_address3,''),       -- C_Address3 - nvarchar(45)  
    ISNULL(OH.c_address4,''),       -- C_Address4 - nvarchar(45)  
    ISNULL(OH.c_contact1,''),       -- C_contact1 - nvarchar(45)  
    ISNULL(OH.c_zip,''),       -- c_zip - nvarchar(45)  
    ISNULL(OH.b_address4,''),       -- B_Address4 - nvarchar(45)  
    ISNULL(OH.b_city,''),       -- B_city - nvarchar(45)  
    ISNULL(OH.b_contact1,''),       -- B_Contact1 - nvarchar(45)  
    ISNULL(OH.b_zip,''),       -- B_zip - nvarchar(45)  
    ISNULL(OH.b_country,''),       -- B_country - nvarchar(45)  
    ISNULL(OH.c_phone1,''),       -- C_phone2 - nvarchar(45)  
    ISNULL(OH.b_phone1,''),       -- B_Phone1 - nvarchar(45)  
    ISNULL(OH.notes,''),       -- OHNotes - nvarchar(4000)  
    OH.storerkey,       -- Storerkey - nvarchar(15)  
    ISNULL(S.ProductModel,'') + SPACE(1) + ISNULL(S.BUSR2,''),       -- Sku - nvarchar(80)  
    ISNULL(S.style,'') + SPACE(1) + ISNULL(S.color,''),       -- StyleColor - nvarchar(30)  
    @c_moneysymbol + SPACE(1) +REPLACE(CAST(FORMAT(ABS(OD.unitprice), 'C0', 'en-us') AS NVARCHAR(20)),'$',''),         -- UNITPRICE - int  
    @c_moneysymbol + SPACE(1) +REPLACE(CAST(FORMAT(ABS(OH.InvoiceAmount), 'C0', 'en-us') AS NVARCHAR(20)),'$',''),         -- INVAmt - int  
    OD.originalqty,         -- PQTY - int  
    ISNULL(OH.b_address1,''),       -- B_Address1 - nvarchar(45)  
    ISNULL(OH.b_address2,''),       -- B_Address2 - nvarchar(45)  
    ISNULL(OH.b_address3,''),       -- B_Address3 - nvarchar(45)  
    0,         -- Pageno - int  
    CASE WHEN OH.PmtTerm = 'CC' THEN  @c_moneysymbol + SPACE(1) +'0'   
    ELSE @c_moneysymbol +  SPACE(1) + REPLACE(CAST(FORMAT(ABS(OH.InvoiceAmount), 'C0', 'en-us') AS NVARCHAR(20)),'$','') END,       -- totalPaid - nvarchar(20)  
    CONVERT(NVARCHAR(11),OH.Orderdate,113) + SPACE(1) +  CONVERT(NVARCHAR(30),OH.Orderdate,14), -- OrderDate - datetime  
    ISNULL(C.short,''),       -- shipperContact - nvarchar(50)  
    ISNULL(C.long,''),       -- shipperCompany - nvarchar(80)  
    ISNULL(C.udf01,'')+ISNULL(C.udf02,'')+ISNULL(C.udf03,'')+ISNULL(C.udf04,'')+ISNULL(C.udf05,''),       -- shipperAdd - nvarchar(150)  
    ISNULL(C.notes2,''),       -- shipperEmail - nvarchar(100)  
    ISNULL(C.notes,''),        -- shipperPhone - nvarchar(50)  
    (OD.UnitPrice * OD.OriginalQty) AS unitqty  
FROM ORDERS OH WITH (NOLOCK)  
JOIN ORDERDETAIL OD WITH (NOLOCK) ON oh.OrderKey = OD.OrderKey  
JOIN OrderInfo OIF WITH (NOLOCK) ON OIF.OrderKey = OH.OrderKey  
JOIN SKU S WITH (NOLOCK) ON S.StorerKey=OD.StorerKey AND S.Sku=OD.Sku  
JOIN CODELKUP C WITH (NOLOCK) ON C.listname='JPLINVPP' AND C.storerkey = OH.storerkey AND C.code='1'  
WHERE OH.ExternOrderKey = @c_externOrderKey  
ORDER BY OH.OrderKey,od.Sku  
  
  
   --SELECT @n_TTLTax01 = SUM(ODTax01)  
   --    --  ,@n_TTLPrice = SUM(  
   --FROM #PRNSHIPINVRPT  
  
   SELECT  
            CCtext,  
            CarrierCharges,  
            PmtTerm,  
            C_phone1,  
            Orderkey,  
            ExternOrderkey,  
            c_city,  
            c_country,  
            B_Address4,  
            C_Address1,  
            C_Address2,  
            C_Address3,  
            C_Address4,  
            C_contact1,  
            c_zip,  
            B_Contact1,  
            B_city,  
            B_zip,  
            B_country,  
            StyleColor,  
            C_phone2,  
            OHNotes,  
            Storerkey,  
            Sku,  
            B_Phone1,  
            INVAmt,  
            UNITPRICE,  
            PQTY,  
            B_Address1,  
            B_Address2,  
            B_Address3,  
            Pageno,  
            totalPaid,  
            OrderDate,  
            moneysymbol,  
            shipperContact,  
            shipperCompany,  
            shipperAdd,  
            shipperEmail,  
            shipperPhone,  
            Unitqty,  
            @c_moneysymbol + SPACE(1) + REPLACE(CAST(FORMAT(ABS(Unitqty), 'C0', 'en-us') AS NVARCHAR(10)),'$','') AS msunitqty,  
            INVAmt AS subttl,  
            INVAmt AS ttlvat,  
            ExternOrderkey AS Receipt,  
            OHNotes AS BillToEmail,  
            RtnNotes1 = N'-If you want to return your purchase, you may request to return the product on website and return your product within 14 days from the date',  
            RtnNotes2 =' of receiving order (include Sat, Sun and public holiday).',  
            RtnNotes3 = '- The product must be in original condition, including product label, price tag, and necessary delivery order document. If your return request  ',  
            RtnNotes4 = 'acceptable conditions, we will process within 14 working days after receiving your returned product.',  
            FooterNote1 =N'- Nếu bạn muốn hoàn trả sản phẩm đã mua, bạn có thể yêu cầu trả lại sản phẩm trên trang web trong vòng 14 ngày kể từ ngày nhận được đơn '  +
                         N' hàng (bao gồm cả thứ bảy, chủ nhật và ngày lễ).',
            Footernotes2 =N'- Tất cả sản phẩm phải trong tình trạng hoàn hảo, còn nguyên vẹn, chưa qua sử dụng cùng với đầy đủ nhãn giá và hóa đơn mua hàng.Nếu yêu cầu ' +  
                          N' hoàn trả của bạn đáp ứng đủ các điều kiện quy định, chúng tôi sẽ xử lý trong vòng 14 ngày làm việc sau khi nhận được sản phẩm của bạn.',
           Footernotes3 =N'- Vui lòng xem chính sách hoàn trả của chúng tôi tại www.lynvn.com',  
           Paymentmtd = PmtTerm,     
           AMtdue     = INVAmt ,   
           RTNHeader = 'RETURN POLICY:',
           RemarksHeader = 'REMARK:',
           RNotes1 = '- Please check our return policy at www.lynvn.com',
           RNotes2 ='- Contact our customer service via email contactus@lynvn.com or via hotline 0283.620.9544 with any questions regarding your return request.',
           FN1Header = N'QUY ĐỊNH ĐỔI TRẢ:',
           FN2Header = N'LƯU Ý:',
           Footernotes4 =N'- Liên hệ bộ phận chăm sóc khách hàng qua email contactus@lynvn.com hoặc qua hotline 0283.620.9544 nếu có bất kỳ thắc mắc nào liên quan' +
                         N' đến yêu cầu đổi trả hàng của bạn.'   --CS02
    FROM #PRNSHIPINVLBLRPT  
    ORDER BY Orderkey  
  
QUIT:  
  
END -- procedure  


GO