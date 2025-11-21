SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/          
/* Stored Proc: isp_sales_invoice_ph_ncci_rpt                           */          
/* Creation Date: 24-SEP-2020                                           */          
/* Copyright: LF Logistics                                              */          
/* Written by: CSCHONG                                                  */          
/*                                                                      */          
/* Purpose: WMS-15196 - PH_Novateur_SalesInvoice_RCM_CR                 */          
/*                                                                      */          
/* Called By: r_dw_sales_invoice_ph_ncci_rpt                            */          
/*                                                                      */          
/* PVCS Version: 1.0                                                    */          
/*                                                                      */          
/* Version: 7.0                                                         */          
/*                                                                      */          
/* Data Modifications:                                                  */          
/*                                                                      */          
/* Updates:                                                             */          
/* Date       Author  Ver Purposes                                      */          
/* 2021-01-29 WLChooi 1.1 WMS-16171 Change UnitPrice Logic (WL01)       */          
/* 2021-02-11 WLChooi 1.2 Bug Fix for WMS-16171 (WL02)                  */          
/* 2021-02-16 CSCHONG 1.3 WMS-16211 revised field logic (CS01)          */          
/* 2021-05-26 CheeMun 1.4 INC1513007 - Extende variable length          */  
/* 2021-07-02 WLChooi 1.5 WMS-17421 - Change UnitPrice Logic (WL03)     */        
/************************************************************************/          
CREATE PROC [dbo].[isp_sales_invoice_ph_ncci_rpt]           
      @c_OrderKey   NVARCHAR(10)           
     ,@c_RePrint    NVARCHAR(5) = 'N'          
AS            
BEGIN            
   SET NOCOUNT ON             
   SET ANSI_NULLS OFF           
   SET QUOTED_IDENTIFIER OFF            
   SET CONCAT_NULL_YIELDS_NULL OFF            
   DECLARE             
       @n_StartTCnt           INT            
     , @n_Continue            INT            
             
     --  , @c_Orderkey    NVARCHAR(10)            
     , @c_Consigneekey        NVARCHAR(15)            
     , @c_Rptsku              NVARCHAR(5)            
     , @n_MaxLine             INT            
     , @c_Destination         NVARCHAR(30)          
     , @c_CUDF01              NVARCHAR(60)           
     , @c_CUDF02              NVARCHAR(60)          
     , @n_CUDF02              FLOAT           
     , @c_GetOrderkey         NVARCHAR(20)          
     , @c_GetSKU              NVARCHAR(20)          
     , @n_unitprice           DECIMAL(12,4)          
     , @n_tax01               FLOAT          
     , @n_PriceAmt            FLOAT          
     , @n_uomqty              FLOAT          
     , @c_ODlinenum           NVARCHAR(10)           
     , @n_SODTerms            FLOAT = 0.00          
     , @c_AmtINWord           NVARCHAR(150)          
     , @n_TTLPriceAmt         DECIMAL(12,4)   --WL03          
     , @n_VATSales            DECIMAL(12,4) = 0.00  --M33          --INC1513007   --WL03           
     , @n_VATExSales          DECIMAL(12,4) = 0.00  --M34          --INC1513007   --WL03           
     , @n_VATZRSales          DECIMAL(12,4) = 0.00  --M35          --INC1513007   --WL03           
     , @n_VATAMT              DECIMAL(12,4) = 0.00  --M36,M38,M42  --INC1513007   --WL03           
     , @n_TTLSVAT             DECIMAL(12,4) = 0.00  --M37          --INC1513007   --WL03           
     , @n_NetAmtVAT           DECIMAL(12,4) = 0.00  --M39          --INC1513007   --WL03           
     , @n_AmtDue              DECIMAL(12,4) = 0.00  --M41          --INC1513007   --WL03           
     , @n_FinalPriceAmt       DECIMAL(12,4) = 0.00  --M43          --INC1513007   --WL03           
     , @n_CntLine             INT          
     , @n_MaxPage             INT          
     , @n_OrdLine             INT           
     , @c_OrdLine             NVARCHAR(10)          
     , @n_ExtPrice            DECIMAL(12,4)  --WL01                --INC1513007          
     , @c_OHUDF10             NVARCHAR(20)  --CS01  
     , @c_OHUDF04             NVARCHAR(50)  --WL03        
          
   SET @n_StartTCnt = @@TRANCOUNT            
   SET @n_Continue = 1           
               
   SET @c_Rptsku = ''              
   SET @n_Maxline = 17             
   SET @n_CntLine = 1          
   SET @n_MaxPage = 1          
             
   SET @c_Destination = ''          
   SET @c_CUDF01 = ''          
   SET @c_CUDF02 = ''          
            
   CREATE TABLE #SALESINVRPT           
   ( Facility            NVARCHAR(5)              
   , BizUnit             NVARCHAR(50)             
   , OHUDF03             NVARCHAR(30)           
   , AmtINWord           NVARCHAR(150) NULL           
    -- ,  ShipDate     DATETIME   NULL            
   , VATSales            DECIMAL(12,2) NULL DEFAULT(0.00) --INC1513007            
   , Orderkey            NVARCHAR(10)            
   , ExternOrderkey      NVARCHAR(50)          
   , ExternPOkey         NVARCHAR(20)           
   --,  OrderDate     DATETIME   NULL            
   --,  DeliveryDate    DATETIME   NULL            
   , VATZRSales          DECIMAL(12,2) NULL DEFAULT(0.00) --INC1513007           
   , C_Company           NVARCHAR(45)           
   , C_Address1          NVARCHAR(45)            
   , C_Address2          NVARCHAR(45)           
   , C_Address3          NVARCHAR(45)           
   , C_Address4          NVARCHAR(45)           
   , C_contact1          NVARCHAR(45)           
   , c_vat               NVARCHAR(30)           
   , Salesman            NVARCHAR(30)          
   , UOM                 NVARCHAR(10) NULL DEFAULT('')             
   , B_Address1          NVARCHAR(45)           
   , B_Address2          NVARCHAR(45)           
   , B_Address3          NVARCHAR(45)           
   , B_Address4          NVARCHAR(45)           
   , ST_VAT              NVARCHAR(36)           
   , ST_Phone1           NVARCHAR(45)           
   , VATAMT              DECIMAL(12,2) NULL DEFAULT(0.00) --INC1513007          
   , Storerkey           NVARCHAR(15)            
   , Sku                 NVARCHAR(20)           
   , SKUDescr            NVARCHAR(60)  NULL DEFAULT('')            
   , UOMQTY              INT DEFAULT (0)          
   , TAXQTY              DECIMAL(12,2) NULL DEFAULT(0.00)   --INC1513007          
   , UNITPRICE           DECIMAL(12,4) NULL DEFAULT(0.00)   --WL01   --WL02    --INC1513007          
   , PQTY                INT            
   , TTLSVAT             DECIMAL(12,2) NULL                 --INC1513007          
   , ST_Address1         NVARCHAR(45)           
   , ST_Address2         NVARCHAR(45)           
   , ST_Address3         NVARCHAR(45)           
   , Pageno              INT          
   , ODLineNum           NVARCHAR(10)          
   , OIUDF01             DECIMAL(12,2) NULL DEFAULT(0.00)            --INC1513007          
   , PriceAmt            DECIMAL(12,4) NULL DEFAULT(0.00)    --WL01  --INC1513007          
   , FinalPriceAmt       DECIMAL(12,2) NULL DEFAULT(0.00)            --INC1513007          
   , NetAmtVAT           DECIMAL(12,2) NULL DEFAULT(0.00)            --INC1513007          
   , AmtDue              DECIMAL(12,2) NULL DEFAULT(0.00)            --INC1513007          
   , VATExSales          DECIMAL(12,2) NULL DEFAULT(0.00)            --INC1513007          
   , ExtPrice            DECIMAL(12,4) NULL --WL01                   --INC1513007    
   , OHUDF04             NVARCHAR(50)  NULL --WL03      
   )           
            
   SELECT  @c_Destination = SOD.Destination          
          ,@n_SODTerms = CASE WHEN ISNUMERIC(SOD.Terms) = 1 THEN SOD.Terms ELSE 1.00 END          
   FROM StorerSODefault SOD WITH (NOLOCK)          
   JOIN ORDERS OH WITH (NOLOCK) ON OH.consigneekey = SOD.Storerkey          
   WHERE OH.orderkey = @c_OrderKey          
            
   SELECT @c_CUDF01 = ISNULL(C.udf01,'')          
         ,@c_CUDF02 = ISNULL(C.udf02,'')          
         ,@n_CUDF02 = CASE WHEN ISNUMERIC(C.udf02) = 1 THEN CAST(C.udf02 as FLOAT) ELSE 0 END          
   FROM ORDERS OH WITH (NOLOCK)          
   LEFT JOIN  codelkup C WITH (NOLOCK) ON C.listname = 'TAXDEF'          
   AND OH.storerkey = c.Storerkey AND C.code=OH.Userdefine04          
   WHERE OH.orderkey = @c_OrderKey          
            
   --IF ISNULL(@c_CUDF01,'') = '' AND ISNULL(@c_CUDF02,'') = ''          
   --BEGIN          
   --   GOTO QUIT          
   --END          
          
   INSERT INTO #SALESINVRPT            
   (  Facility                
    , BizUnit             
    , OHUDF03            
    , AmtINWord               
    --  ,  ShipDate            
    , VATSales             
    , VATExSales                
    , Orderkey                
    , ExternOrderkey              
    , ExternPOkey               
    --,  OrderDate           
    --,  DeliveryDate              
    , VATZRSales             
    , C_Company               
    , C_Address1               
    , C_Address2             
    , C_Address3             
    , C_Address4               
    , C_contact1                
    , c_vat                
    , Salesman               
    , UOM               
    , B_Address1               
    , B_Address2            
    , B_Address3              
    , B_Address4               
    , ST_VAT               
    , ST_Phone1              
    , VATAMT                
    , Storerkey               
    , Sku                 
    , SKUDescr                
    , UOMQTY              
    , TAXQTY               
    , UNITPRICE             
    , PQTY            
    , TTLSVAT            
    , ST_Address1              
    , ST_Address2               
    , ST_Address3              
    , Pageno            
    , ODLineNum          
    , OIUDF01             
    , PriceAmt           
    , FinalPriceAmt           
    , NetAmtVAT           
    , AmtDue            
    , ExtPrice   --WL01
    , OHUDF04    --WL03          
   )           
   SELECT ORDERS.Facility           
        , BizUnit = ISNULL(RTRIM(orders.BizUnit),'')            
        , OHUDF03 = ISNULL(RTRIM(orders.userdefine03),'')           
        , AmtINWord = ''           
        --  , ShipDate = MBOL.ShipDate            
        , VATSales = 0          
        , VATExSales= 0          
        , ORDERS.Orderkey            
        , ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')           
        , ExternPOkey =  ISNULL(RTRIM(ORDERS.ExternPOkey),'')              
        --, ORDERS.OrderDate            
        --, ORDERS.DeliveryDate            
        , VATZRSales = 0          
        , C_Company = ISNULL(RTRIM(ORDERS.C_Company),'')            
        , C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')            
        , C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')            
        , C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')            
        , C_Address4= ISNULL(RTRIM(ORDERS.C_Address4),'')           
        , C_contact1 = ISNULL(RTRIM(ORDERS.C_contact1),'')            
        , c_vat= ISNULL(RTRIM(ORDERS.c_vat),'')            
        , Salesman = ''          
        , UOM = ISNULL(RTRIM(ORDERDETAIL.UOM),'')            
        , B_Address1 = ISNULL(RTRIM(ORDERS.B_Address1),'')            
        , B_Address2 = ISNULL(RTRIM(ORDERS.B_Address2),'')            
        , B_Address3 = ISNULL(RTRIM(ORDERS.B_Address3),'')            
        , B_Address4= ISNULL(RTRIM(ORDERS.B_Address4),'')           
        , ST_VAT = ISNULL(RTRIM(ST.VAT),'')            
        , ST_Phone1= ISNULL(RTRIM(ST.Phone1),'')           
        , VATAMT = 0.00          
        , ORDERS.Storerkey            
        , PICKDETAIL.Sku AS sku             
        , SKUDescr = ISNULL(RTRIM(SKU.Descr),'')           
        , UOMQty = CASE WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM1 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.CASECNT,0)           
              WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'')= PACK.PACKUOM2 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.INNERPACK,0)            
              WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM3 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.Qty,0)           
              WHEN  ISNULL(RTRIM(ORDERDETAIL.UOM),'') = PACK.PACKUOM4 THEN SUM(PICKDETAIL.Qty)/NULLIF(PACK.Pallet,0) ELSE 0 END           
        , TAXQTY  = CASE WHEN @c_Destination = 'H' THEN 0 Else Orderdetail.Tax01 END           
        --, UNITPRICE = CASE WHEN @c_Destination = 'H' THEN CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'0') AS FLOAT) ELSE 1 END   --WL01           
        --      ELSE ORDERDETAIL.UnitPrice END                                                    --WL01   
        --WL03 S
        , UnitPrice = CASE WHEN ORDERDETAIL.OriginalQty > 0 THEN CASE WHEN @c_Destination = 'H' AND ORDERS.UserDefine04 = 'OUTPUT-V'  THEN CAST(CAST((ISNULL(ORDERDETAIL.ExtendedPrice,0.0000) / ORDERDETAIL.OriginalQty) AS DECIMAL(12,4)) * 1.12 AS DECIMAL(12,4))  --WL01
                                                                      WHEN @c_Destination <> 'H' AND ORDERS.UserDefine04 = 'OUTPUT-V' THEN CAST((CAST((ISNULL(ORDERDETAIL.ExtendedPrice,0.0000) / ORDERDETAIL.OriginalQty) AS DECIMAL(12,4)) * 1.12) / 
                                                                                                                                           CASE WHEN ISNUMERIC(ORDERDETAIL.Tax01) = 1 THEN ((100 - ORDERDETAIL.Tax01) / 100) ELSE 1 END /
                                                                                                                                           1.12 AS DECIMAL(12,4))
                                                                      ELSE CAST(CAST((ISNULL(ORDERDETAIL.ExtendedPrice,0.00) / ORDERDETAIL.OriginalQty) AS DECIMAL(12,4)) / 
                                                                           CASE WHEN ISNUMERIC(ORDERDETAIL.Tax01) = 1 THEN ((100 - ORDERDETAIL.Tax01) / 100) ELSE 1 END AS DECIMAL(12,4)) END
                                                            ELSE 0 END   --WL01
        --WL03 E  
        , SUM(PICKDETAIL.Qty)          
        , TTLSVAT = 0.00          
        , ST_Address1 = ISNULL(RTRIM(ST.Address1),'')           
        , ST_Address2 = ISNULL(RTRIM(ST.Address2),'')          
        , ST_Address3 = ISNULL(RTRIM(ST.Address3),'')          
        , pageno = (Row_Number() OVER (PARTITION BY ORDERS.Orderkey ORDER BY ORDERS.Orderkey,ORDERDETAIL.OrderLineNumber,PICKDETAIL.Sku Asc)-1)/@n_maxLine + 1           
        , ODLineNum = ORDERDETAIL.OrderLineNumber           
        , OIUDF01 = CASE WHEN ISNUMERIC(ISNULL(RTRIM(OIF.OrderInfo01),'')) = 1 THEN CAST(ISNULL(RTRIM(OIF.OrderInfo01),'0') AS float) ELSE 0 END          
        , PriceAmt = 0.00          
        , FinalPriceAmt = 0.00          
        , NetAmtVAT = 0.00          
        , AmtDue  = 0.00          
        , ISNULL(ORDERDETAIL.ExtendedPrice,0.00)  --WL01 
        , ISNULL(ORDERS.UserDefine04,'')   --WL03         
   FROM ORDERS   WITH (NOLOCK)           
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = PICKDETAIL.Orderkey)            
   JOIN ORDERDETAIL (NOLOCK) ON PICKDETAIL.orderkey = ORDERDETAIL.orderkey and          
                                PICKDETAIL.orderlinenumber = ORDERDETAIL.orderlinenumber           
   -- JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot= LOTATTRIBUTE.Lot)            
   JOIN SKU    WITH (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey)            
                             AND(PICKDETAIL.Sku = SKU.Sku)            
   JOIN PACK   WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)            
   LEFT JOIN  STORER ST WITH (NOLOCK) ON ST.Storerkey = ORDERS.StorerKey           
   LEFT JOIN ORDERINFO OIF WITH (NOLOCK) ON OIF.orderkey = ORDERS.Orderkey          
   LEFT JOIN PACKHEADER PH WITH (NOLOCK) ON PH.Orderkey = ORDERS.Orderkey          
   WHERE ORDERS.Orderkey = @c_Orderkey            
   --AND PICKDETAIL.Status >= '5'            
   AND PH.ManifestPrinted = CASE WHEN @c_Reprint = 'Y' THEN 'Y' ELSE '0' END          
   GROUP BY ORDERS.Facility            
          , ISNULL(RTRIM(orders.BizUnit),'')             
          , ISNULL(RTRIM(orders.userdefine03),'')          
          -- , ISNULL(RTRIM(orders.shipperkey),'')            
          --  , MBOL.ShipDate             
          --, ISNULL(orders.PmtTerm,'')            
          -- , ISNULL(RTRIM(orders.BuyerPO),'')            
          , ORDERS.Orderkey            
          , ISNULL(RTRIM(ORDERS.ExternOrderkey),'')            
          , ISNULL(RTRIM(ORDERS.ExternPOkey),'')            
          --, ORDERS.OrderDate            
          --, ORDERS.DeliveryDate            
          --, ISNULL(RTRIM(orders.userdefine05),'')          
          , ISNULL(RTRIM(ORDERS.C_Company),'')           
          , ISNULL(RTRIM(ORDERS.C_Address1),'')            
          , ISNULL(RTRIM(ORDERS.C_Address2),'')            
          , ISNULL(RTRIM(ORDERS.C_Address3),'')            
          , ISNULL(RTRIM(ORDERS.C_Address4),'')            
          , ISNULL(RTRIM(ORDERS.C_contact1),'')            
          , ISNULL(RTRIM(ORDERS.c_vat),'')            
          --, ISNULL(RTRIM(ORDERS.Salesman),'')            
          , ISNULL(RTRIM(ORDERDETAIL.UOM),'')          
          , ISNULL(RTRIM(ORDERS.B_Address1),'')            
          , ISNULL(RTRIM(ORDERS.B_Address2),'')            
          , ISNULL(RTRIM(ORDERS.B_Address3),'')            
          , ISNULL(RTRIM(ORDERS.B_Address4),'')            
          , ISNULL(RTRIM(ST.VAT),'')           
          , ISNULL(RTRIM(ST.Phone1),'')            
          --  , ISNULL(RTRIM(ORDERS.Notes),'')           
          , ORDERS.Storerkey           
          --, PICKDETAIL.Sku           
          , ISNULL(RTRIM(SKU.Descr),'')            
          , ISNULL(PACK.CaseCnt,0)           
          --, CASE WHEN @c_Destination = 'H' THEN CASE WHEN ISNUMERIC(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'')) = 1 THEN CAST(ISNULL(RTRIM(ORDERDETAIL.userdefine03),'0') AS FLOAT) ELSE 1 END  --WL01          
          --           ELSE ORDERDETAIL.UnitPrice END                                         --WL01     
          --WL03 S     
          , CASE WHEN ORDERDETAIL.OriginalQty > 0 THEN CASE WHEN @c_Destination = 'H' AND ORDERS.UserDefine04 = 'OUTPUT-V'  THEN CAST(CAST((ISNULL(ORDERDETAIL.ExtendedPrice,0.0000) / ORDERDETAIL.OriginalQty) AS DECIMAL(12,4)) * 1.12 AS DECIMAL(12,4))   --WL01
                                                            WHEN @c_Destination <> 'H' AND ORDERS.UserDefine04 = 'OUTPUT-V' THEN CAST((CAST((ISNULL(ORDERDETAIL.ExtendedPrice,0.0000) / ORDERDETAIL.OriginalQty) AS DECIMAL(12,4)) * 1.12) / 
                                                                                                                                 CASE WHEN ISNUMERIC(ORDERDETAIL.Tax01) = 1 THEN ((100 - ORDERDETAIL.Tax01) / 100) ELSE 1 END /
                                                                                                                                 1.12 AS DECIMAL(12,4))
                                                            ELSE CAST(CAST((ISNULL(ORDERDETAIL.ExtendedPrice,0.00) / ORDERDETAIL.OriginalQty) AS DECIMAL(12,4))/ 
                                                                 CASE WHEN ISNUMERIC(ORDERDETAIL.Tax01) = 1 THEN ((100 - ORDERDETAIL.Tax01) / 100) ELSE 1 END AS DECIMAL(12,4)) END
                                                  ELSE 0 END   --WL01
          --WL03 E    
          -- , ISNULL(OIF.EcomOrderId,'')            
          , PICKDETAIL.Sku           
          ,ISNULL(RTRIM(ST.Address1),'')           
          ,ISNULL(RTRIM(ST.Address2),'')           
          ,ISNULL(RTRIM(ST.Address3),'')           
          , ORDERDETAIL.OrderLineNumber , Orderdetail.Tax01          
          , PACK.PACKUOM1,PACK.PACKUOM2,PACK.PACKUOM3,PACK.PACKUOM4          
          , PACK.CASECNT,PACK.INNERPACK,PACK.qty,PACK.Pallet          
          , CASE WHEN ISNUMERIC(ISNULL(RTRIM(OIF.OrderInfo01),'')) = 1 THEN CAST(ISNULL(RTRIM(OIF.OrderInfo01),'0') AS float) ELSE 0 END          
          , ISNULL(ORDERDETAIL.ExtendedPrice,0.00)   --WL01 
          , ISNULL(ORDERS.UserDefine04,'')   --WL03             
           
   --select * from #SALESINVRPT          
 
   DECLARE CUR_StartRecLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
   SELECT DISTINCT orderkey,sku,UNITPRICE,TAXQTY,UOMQTY,ODLineNum,ExtPrice,OHUDF04   --WL01   --WL03        
   FROM #SALESINVRPT          
   WHERE Orderkey = @c_OrderKey          
           
   OPEN CUR_StartRecLoop              
             
   FETCH NEXT FROM CUR_StartRecLoop INTO @c_getorderkey,@c_getsku,@n_unitprice,@n_tax01,@n_uomqty,@c_odlinenum,@n_ExtPrice,@c_OHUDF04  --WL01   --WL03         
             
   WHILE @@FETCH_STATUS <> -1              
   BEGIN           
      SET @n_PriceAmt = 0.00          
          
      IF @n_unitprice = 0          
      BEGIN          
         SET @n_unitprice = 0.00           
      END           
          
      IF @n_tax01 = 0          
      BEGIN          
         SET @n_tax01 = 0.00           
      END           

      --SET @n_PriceAmt = (@n_uomqty * @n_unitprice) - ((@n_uomqty * @n_unitprice) * (@n_tax01 / 100))   --WL01          
      --WL02 S          
      --IF @c_Destination = 'H'          
      --   SET @n_PriceAmt = (@n_ExtPrice - (@n_ExtPrice * (@n_tax01/100))) * 1.12          
      --ELSE          
      --   SET @n_PriceAmt = @n_ExtPrice - (@n_ExtPrice * (@n_tax01/100))   --WL01          
      --WL02 E   

      --WL03 S
      IF @c_OHUDF04 = 'OUTPUT-V' AND @c_Destination = 'H'
      BEGIN
         SET @n_PriceAmt =  @n_ExtPrice * 1.12
      END
      ELSE
      BEGIN
         SET @n_PriceAmt = @n_ExtPrice
      END
      --WL03 E

      UPDATE #SALESINVRPT          
      SET PriceAmt = @n_PriceAmt          
      WHERE Orderkey = @c_GetOrderkey          
      AND sku = @c_GetSKU          
      AND ODLineNum = @c_ODlinenum          
          
      FETCH NEXT FROM CUR_StartRecLoop INTO @c_getorderkey,@c_getsku,@n_unitprice,@n_tax01,@n_uomqty,@c_odlinenum,@n_ExtPrice,@c_OHUDF04   --WL01   --WL03     
          
   END -- While               
   CLOSE CUR_StartRecLoop               
   DEALLOCATE CUR_StartRecLoop          
          
   --, @c_AmtINWord    NVARCHAR(150)          
   --, @n_VATSales    FLOAT = 0.00  --M33          
   --, @n_VATExSales    FLOAT = 0.00  --M34          
   --, @n_VATZRSales    FLOAT = 0.00  --M35           
   --, @n_VATAMT     FLOAT = 0.00  --M36,M38,M42          
   --, @n_TTLSVAT     FLOAT = 0.00  --M37          
   --, @n_NetAmtVAT    FLOAT = 0.00  --M39          
   --, @n_AmtDue     FLOAT          
   --@n_FinalPriceAmt       --M43          
       
   SET @n_TTLPriceAmt = 0.00          
   SET @c_AmtINWord = ''            
   SET @c_OHUDF10 = ''          
   SET @n_FinalPriceAmt =0.00          
            
   SELECT @n_TTLPriceAmt = SUM(priceamt)          
   FROM #SALESINVRPT          
   WHERE Orderkey = @c_OrderKey          
 
   -- select @n_TTLPriceAmt '@n_TTLPriceAmt', @c_CUDF01 '@c_CUDF01', @c_Destination '@c_Destination', @n_CUDF02 '@n_CUDF02'          
            
   IF @c_CUDF01 <> '' AND @c_CUDF01 <> 'Y'          
   BEGIN          
      SET @n_VATSales = 0.00          
   END          
   ELSE          
   --BEGIN          
     --select 'chk'          
      IF @c_Destination = 'H'         
      BEGIN           
         SET @n_VATSales = @n_TTLPriceAmt / @n_SODTerms          
      END          
      ELSE          
      BEGIN          
         SET @n_VATSales = @n_TTLPriceAmt          
      END          
   --  END          
            
   IF @c_CUDF01 <> '' AND @c_CUDF01 <> 'N'          
   BEGIN          
      SET @n_VATExSales = 0.00          
   END          
   ELSE          
   BEGIN           
      SET @n_VATExSales = @n_TTLPriceAmt          
   END          
            
   IF @c_CUDF01 <> '' AND @c_CUDF01 <> 'Z'          
   BEGIN          
      SET @n_VATZRSales = 0.00          
   END          
   ELSE          
   BEGIN           
      SET @n_VATZRSales = @n_TTLPriceAmt          
   END          
            
   IF @n_CUDF02 = '' AND @n_CUDF02 = 0          
   BEGIN          
      SET @n_VATAMT = 0.00          
   END          
   ELSE          
   BEGIN           
      SET @n_VATAMT = (@n_VATSales*@n_CUDF02)          
   END          
              
   --select @n_VATAMT '@n_VATAMT'          
   --IF @c_Destination = 'H'          
   --BEGIN          
   --  SET @n_TTLSVAT = (@n_VATSales + @n_VATExSales + @n_VATZRSales)          
   --END          
   --ELSE          
   --BEGIN          
   SET @n_TTLSVAT = (@n_VATSales + @n_VATExSales + @n_VATZRSales+@n_VATAMT)          
   --END          
          
   UPDATE #SALESINVRPT          
   SET VATSales  = @n_VATSales          
      ,VATExSales  = @n_VATExSales          
      ,VATZRSales  = @n_VATZRSales          
      ,VATAMT   = @n_VATAMT          
      ,TTLSVAT   = @n_TTLSVAT          
      ,NetAmtVAT  = (@n_TTLSVAT - @n_VATAMT)          
      ,AmtDue   = (@n_TTLSVAT - @n_VATAMT) - OIUDF01          
      ,FinalPriceAmt = ((@n_TTLSVAT - @n_VATAMT) - OIUDF01) + @n_VATAMT            
   -- ,     = select '(' +(UPPER(dbo.fnc_NumberToWords(246.00,'','','',' PESOS ONLY)')))           
   WHERE Orderkey = @c_Orderkey          
          
   --CS01 START          
          
   SELECT @n_FinalPriceAmt = FinalPriceAmt          
   FROM #SALESINVRPT          
   WHERE Orderkey = @c_Orderkey          
            
   UPDATE ORDERS WITH (ROWLOCK)          
   SET Userdefine10 = CAST(@n_FinalPriceAmt as NVARCHAR(20))          
   WHERE  Orderkey = @c_Orderkey          
            
   --CS01 END          
            
   SET @n_MaxPage = 1          
   SET @n_OrdLine = 1          
   SET @c_OrdLine = '1'          
             
   SELECT @n_MaxPage = MAX(pageno)          
   FROM #SALESINVRPT            
   WHERE Orderkey = @c_OrderKey          
             
   SELECT @n_CntLine = COUNT(1)          
         ,@c_OrdLine = MAX(ODLineNum)          
   FROM #SALESINVRPT          
   WHERE Orderkey = @c_OrderKey          
   AND Pageno = @n_MaxPage          
             
   --select @n_CntLine '@n_CntLine', @c_OrdLine '@c_OrdLine'          
             
   SET @n_OrdLine = CAST(@c_OrdLine as INT) + 1          
             
   WHILE @n_CntLine < @n_MaxLine          
   BEGIN          
      --SET @n_OrdLine = 1          
      INSERT INTO #SALESINVRPT (Facility               
      , BizUnit             
      , OHUDF03             
      , AmtINWord               
      , VATSales                
      , Orderkey                
      , ExternOrderkey              
      , ExternPOkey               
      , VATZRSales             
      , C_Company               
      , C_Address1               
      , C_Address2             
      , C_Address3             
      , C_Address4               
      , C_contact1                
      , c_vat                
      , Salesman               
      , UOM               
      , B_Address1               
      , B_Address2            
      , B_Address3              
      , B_Address4               
      , ST_VAT               
      , ST_Phone1              
      , VATAMT                
      , Storerkey               
      , Sku                 
      , SKUDescr                
      , UOMQTY                    
      , UNITPRICE           
      , TAXQTY           
      , PQTY              
      , TTLSVAT            
      , ST_Address1              
      , ST_Address2               
      , ST_Address3              
      , Pageno             
      , OIUDF01          
      , PriceAmt          
      , FinalPriceAmt          
      , NetAmtVAT          
      , AmtDue          
      , VATExSales           
      , ODLineNum          
      , ExtPrice) --WL01          
      SELECT TOP 1          
           Facility                
         , BizUnit             
         , OHUDF03             
         , AmtINWord               
         , VATSales                
         , Orderkey                
         , ExternOrderkey              
         , ExternPOkey               
         , VATZRSales              
         , C_Company               
         , C_Address1               
         , C_Address2             
         , C_Address3             
         , C_Address4               
         , C_contact1                
         , c_vat                
         , Salesman          
         , ''               
         , B_Address1               
         , B_Address2            
         , B_Address3              
         , B_Address4               
         , ST_VAT               
         , ST_Phone1              
         , VATAMT               
         , Storerkey               
         , ''                 
         , ''                
         , 0.00                     
         , 0.00            
         , 0.00           
         , 0.00              
         , TTLSVAT           
         , ST_Address1              
         , ST_Address2               
         , ST_Address3              
         , @n_MaxPage              
         , OIUDF01          
         , 0.00          
         , FinalPriceAmt          
         , NetAmtVAT          
         , AmtDue          
         , VATExSales           
         , RIGHT('00000'+CAST(@n_OrdLine AS VARCHAR(5)),5)          
         , ExtPrice   --WL01          
      FROM #SALESINVRPT             
      ORDER BY Orderkey           
             , ODLineNum           
             , Storerkey             
             , Sku            
          
      SET @n_OrdLine = @n_OrdLine + 1           
      SET @n_CntLine = @n_CntLine + 1          
          
   END          
          
   SELECT           
         Facility                
       , BizUnit             
       , OHUDF03             
       , UPPER(dbo.fnc_NumberToWords(FinalPriceAmt,'','PESOS','centavos only','')) as AmtINWord               
       --  ,  ShipDate           
       , VATSales                
       , Orderkey                
       , ExternOrderkey              
       , ExternPOkey               
       , VATZRSales             
       , C_Company               
       , C_Address1               
       , C_Address2             
       , C_Address3             
       , C_Address4               
       , C_contact1                
       , c_vat                
       , Salesman               
       , UOM               
       , B_Address1               
       , B_Address2            
       , B_Address3              
       , B_Address4               
       , ST_VAT               
       , ST_Phone1              
       , VATAMT                
       , Storerkey               
       , Sku                 
       , SKUDescr                
       , UOMQTY                    
       , CAST(UNITPRICE AS DECIMAL(10,2)) AS UNITPRICE --WL01          
       , TAXQTY           
       , PQTY              
       , TTLSVAT            
       , ST_Address1              
       , ST_Address2               
       , ST_Address3              
       , Pageno             
       , OIUDF01          
       , CAST(PriceAmt AS DECIMAL(10,2)) AS PriceAmt  --WL01          
       , FinalPriceAmt          
       , NetAmtVAT          
       , AmtDue          
       , VATExSales           
       , ODLineNum          
       , ExtPrice   --WL01          
   FROM #SALESINVRPT             
   ORDER BY Orderkey           
          , CAST(ODLineNum AS INT)           
          , Storerkey             
          , Sku            
           
QUIT:            
            
END -- procedure


GO