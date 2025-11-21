SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/      
/* Stored Procedure: isp_invoice_02                                      */      
/* Creation Date: 11-AUG-2014                                            */      
/* Copyright: IDS                                                        */      
/* Written by: YTWan                                                     */      
/*                                                                       */      
/* Purpose: SOS#316925 - JackWills - Alshaya Commercial Invoice          */      
/*                                                                       */      
/* Called By: wave                                                       */      
/*                                                                       */      
/* PVCS Version: 1.0                                                     */      
/*                                                                       */      
/* Version: 5.4                                                          */      
/*                                                                       */      
/* Data Modifications:                                                   */      
/*                                                                       */      
/* Updates:                                                              */      
/* Date         Author   Ver  Purposes                                   */ 
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */ 
/*************************************************************************/       
    
CREATE PROCEDURE [dbo].[isp_invoice_02]          
           @c_Orderkey        NVARCHAR(10)
         , @c_ProductType     NVARCHAR(18)
         , @n_NoOfCarton      INT
AS BEGIN

   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF   

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_err             INT
         , @c_ErrMsg          NVARCHAR(255)

   DECLARE @c_CS_City         NVARCHAR(45)
         , @c_CS_InvPF        NVARCHAR(2)
         , @c_InvNo           NVARCHAR(10)
         , @c_InvoiceNo       NVARCHAR(20)

         , @c_ExternOrderkey  NVARCHAR(50)  --tlting_ext
         , @d_DeliveryDate    DATETIME
         , @c_C_Contact1      NVARCHAR(30)
         , @c_C_Address1      NVARCHAR(45)
         , @c_C_Address2      NVARCHAR(45)
         , @c_C_City          NVARCHAR(45)
         , @c_C_Country       NVARCHAR(30)


         , @c_Sku             NVARCHAR(20)
         , @c_Style           NVARCHAR(60)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_Gender          NVARCHAR(60)
         , @c_CommodityCode   NVARCHAR(30)
         , @c_Lottable02      NVARCHAR(18)
         , @n_UnitPrice       FLOAT
         , @n_Qty             INT
         , @n_TotalPrice      FLOAT
         , @n_NetWgt          FLOAT
         , @n_TotalNetWgt     FLOAT
         , @n_TotalGrossWgt   FLOAT

         , @c_ReceiptKey      NVARCHAR(10)
         , @c_ReceiptLineNo   NVARCHAR(5)
         , @c_GoodsDescr      NVARCHAR(30)
         , @c_Season          NVARCHAR(30)
         , @c_FabricComp      NVARCHAR(30)
         , @c_OrigOfCountry   NVARCHAR(18)
         , @c_Supplier        NVARCHAR(30)
         , @c_FactoryName     NVARCHAR(30)
         , @c_Knitted         NVARCHAR(30)   

         , @c_SQL             NVARCHAR(4000)
         , @c_SQLParms        NVARCHAR(4000)    
         , @c_DBName          NVARCHAR(20)
         , @c_ArchiveDBName   NVARCHAR(20)

   SET @n_StartTCnt  = @@TRANCOUNT
   SET @n_Continue   = 1
   SET @b_Success    = 1
   SET @n_err        = 0
   SET @c_ErrMsg     = ''
   SET @c_ArchiveDBName = ''

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_INV
           ( ProductType      NVARCHAR(18)  
           , NoOfCarton       INT  
           , InvoiceNo        NVARCHAR(20)
           , CS_City          NVARCHAR(45)                              
           , CS_Prefix        NVARCHAR(2) 
           , Orderkey         NVARCHAR(10)                                 
           , ExternOrderkey   NVARCHAR(50)  --tlting_ext
           , DeliveryDate     DATETIME    
           , C_Contact1       NVARCHAR(30)
           , C_Address1       NVARCHAR(45)
           , C_Address2       NVARCHAR(45)                                                                          
           , C_City           NVARCHAR(45)                                                
           , C_Country        NVARCHAR(30)                                                                                             
           , Sku              NVARCHAR(20) 
           , Style            NVARCHAR(60)                                                              
           , SkuDescr         NVARCHAR(60)                                                               
           , Gender           NVARCHAR(60)                                                               
           , CommodityCode    NVARCHAR(30)                                                
           , GoodsDescr       NVARCHAR(30)      
           , Season           NVARCHAR(30)      
           , FabricComp       NVARCHAR(30) 
           , OrigOfCountry    NVARCHAR(18) 
           , Supplier         NVARCHAR(30) 
           , FactoryName      NVARCHAR(30) 
           , Knitted          NVARCHAR(30)     
           , Qty              INT   
           , UnitPrice        FLOAT
           )

   SELECT @c_ArchiveDBName = ISNULL(RTRIM(NSQLValue),'')   
   FROM NSQLCONFIG WITH (NOLOCK)
   WHERE ConfigKey = 'ArchiveDBName'

   SET @n_TotalNetWgt   = 0.00
   SET @n_TotalGrossWgt = 0.00
   SET @c_InvoiceNo     = ''

   DECLARE CUR_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT PD.Sku
         ,ISNULL(RTRIM(SKU.Descr),'')
         ,ISNULL(RTRIM(CL.Description),'')
         ,ISNULL(RTRIM(SKU.Busr4),'')
         ,ISNULL(RTRIM(LA.Lottable02),'')
         ,SUM(PD.Qty)
         ,ISNULL(OD.UnitPrice,0.00)
         ,ISNULL(SUM(SKU.NetWgt * PD.Qty),0.00) 
         ,ISNULL(RTRIM(OD.UserDefine09),'')
         ,ISNULL(RTRIM(OD.UserDefine10),'')
   FROM PICKDETAIL   PD  WITH (NOLOCK)
   JOIN ORDERDETAIL  OD  WITH (NOLOCK) ON (PD.Orderkey = OD.Orderkey)
                                       AND(PD.OrderLineNumber = OD.OrderLineNumber)
   JOIN SKU          SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                       AND(PD.Sku = SKU.Sku)
   JOIN LOTATTRIBUTE  LA WITH (NOLOCK) ON (PD.Lot = LA.Lot) 
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'SKUGROUP')
                                       AND(CL.Code = SKU.ItemClass)
   WHERE PD.Orderkey = @c_Orderkey
   AND   ISNULL(RTRIM(OD.UserDefine09),'') = @c_ProductType
   AND   PD.Status >= '5'
   GROUP BY PD.Sku
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RTRIM(CL.Description),'')
         ,  ISNULL(RTRIM(SKU.Busr4),'')
         ,  ISNULL(RTRIM(LA.Lottable02),'')
         ,  ISNULL(OD.UnitPrice,0.00)
         ,  ISNULL(RTRIM(OD.UserDefine09),'')
         ,  ISNULL(RTRIM(OD.UserDefine10),'')

   OPEN CUR_DET 
   FETCH NEXT FROM CUR_DET INTO @c_Sku 
                              , @c_SkuDescr
                              , @c_Gender
                              , @c_CommodityCode
                              , @c_Lottable02     
                              , @n_Qty
                              , @n_UnitPrice
                              , @n_NetWgt
                              , @c_ProductType
                              , @c_InvoiceNo

   WHILE @@FETCH_STATUS = 0     
   BEGIN 

      SET @c_Style = ''
      SET @c_Style = LEFT(@c_SkuDescr, CHARINDEX(',', @c_SkuDescr, 1) - 1)
      SET @n_TotalPrice = @n_Qty * @n_UnitPrice
      SET @n_TotalNetWgt= @n_TotalNetWgt + @n_NetWgt

      SET @c_DBName = ''
      SET @c_ReceiptKey = SUBSTRING(@c_Lottable02,1,10)
      SET @c_ReceiptLineNo = SUBSTRING(@c_Lottable02,12,5)

      IF NOT EXISTS ( SELECT 1
                      FROM RECEIPTDETAIL RD WITH (NOLOCK)
                      WHERE RD.ReceiptKey = @c_ReceiptKey
                      AND RD.ReceiptLineNumber = @c_ReceiptLineNo
                     )

      BEGIN 
         SET @c_DBName = @c_ArchiveDBName + '.'
      END
      SET @c_GoodsDescr    = ''
      SET @c_Season        = ''
      SET @c_FabricComp    = ''
      SET @c_OrigOfCountry = ''
      SET @c_Supplier      = ''
      SET @c_FactoryName   = ''
      SET @c_Knitted       = ''

      SET @c_Sql = N'SELECT @c_GoodsDescr = ISNULL(RTRIM(RD.Userdefine04),'''')'
                 +  ' ,@c_Season     = ISNULL(RTRIM(RD.Userdefine01),'''')'
                 +  ' ,@c_FabricComp = ISNULL(RTRIM(RD.Userdefine02),'''')'
                 +  ' ,@c_OrigOfCountry =  ISNULL(RTRIM(RD.VesselKey),'''')'
                 +  ' ,@c_Supplier   =  ISNULL(RTRIM(RD.Userdefine09),'''')'
                 +  ' ,@c_FactoryName=  ISNULL(RTRIM(RD.Userdefine10),'''')'
                 +  ' ,@c_Knitted    =  ISNULL(RTRIM(RD.Userdefine03),'''')'
                 +  ' FROM ' + @c_DBName + 'dbo.RECEIPTDETAIL RD WITH (NOLOCK)'
                 +  ' WHERE RD.ReceiptKey = @c_ReceiptKey'
                 +  ' AND RD.ReceiptLineNumber = @c_ReceiptLineNo'

      SET @c_SqlParms = N'@c_ReceiptKey      NVARCHAR(30)'  
                      + ',@c_ReceiptLineNo   NVARCHAR(30)' 
                      + ',@c_GoodsDescr      NVARCHAR(30)   OUTPUT'
                      + ',@c_Season          NVARCHAR(30)   OUTPUT' 
                      + ',@c_FabricComp      NVARCHAR(30)   OUTPUT'  
                      + ',@c_OrigOfCountry   NVARCHAR(18)   OUTPUT'  
                      + ',@c_Supplier        NVARCHAR(30)   OUTPUT'  
                      + ',@c_FactoryName     NVARCHAR(30)   OUTPUT'  
                      + ',@c_Knitted         NVARCHAR(30)   OUTPUT'  

      EXEC sp_ExecuteSql  @c_Sql
                        , @c_SqlParms
                        , @c_ReceiptKey   
                        , @c_ReceiptLineNo  
                        , @c_GoodsDescr      OUTPUT 
                        , @c_Season          OUTPUT  
                        , @c_FabricComp      OUTPUT   
                        , @c_OrigOfCountry   OUTPUT  
                        , @c_Supplier        OUTPUT  
                        , @c_FactoryName     OUTPUT 
                        , @c_Knitted         OUTPUT
 
   
      INSERT INTO #TMP_INV
           ( ProductType
           , NoOfCarton
           , InvoiceNo
           , CS_City
           , CS_Prefix 
           , Orderkey
           , ExternOrderkey
           , DeliveryDate
           , C_Contact1
           , C_Address1
           , C_Address2
           , C_City
           , C_Country
           , Sku 
           , Style
           , SkuDescr
           , Gender
           , CommodityCode
           , GoodsDescr       
           , Season           
           , FabricComp       
           , OrigOfCountry    
           , Supplier         
           , FactoryName      
           , Knitted             
           , Qty
           , UnitPrice
           )
      SELECT @c_ProductType
           , @n_NoOfCarton
           , @c_InvoiceNo
           , CS.City
           , CS.Susr5 
           , OH.Orderkey
           , OH.ExternOrderkey
	  	     , OH.DeliveryDate
	  	     , CASE WHEN ISNULL(RTRIM(OH.B_Contact1),'') = '' THEN OH.C_Contact1 ELSE OH.B_Contact1 END
	  	     , CASE WHEN ISNULL(RTRIM(OH.B_Address1),'') = '' THEN OH.C_Address1 ELSE OH.B_Address1 END
	  	     , CASE WHEN ISNULL(RTRIM(OH.B_Address2),'') = '' THEN OH.C_Address2 ELSE OH.B_Address2 END
	  	     , CASE WHEN ISNULL(RTRIM(OH.B_City),'')     = '' THEN OH.C_City     ELSE OH.B_City END
           , CASE WHEN ISNULL(RTRIM(OH.B_Country),'')  = '' THEN OH.C_Country  ELSE OH.B_Country END
           , @c_Sku 
           , @c_Style
           , @c_SkuDescr
           , @c_Gender
           , @c_CommodityCode
           , @c_GoodsDescr       
           , @c_Season           
           , @c_FabricComp       
           , @c_OrigOfCountry    
           , @c_Supplier         
           , @c_FactoryName      
           , @c_Knitted               
           , @n_Qty
           , @n_UnitPrice
      FROM ORDERS OH WITH (NOLOCK)
      JOIN STORER CS WITH (NOLOCK) ON (OH.Consigneekey = CS.Storerkey)
      WHERE OH.Orderkey = @c_Orderkey

      FETCH NEXT FROM CUR_DET INTO @c_Sku 
                                 , @c_SkuDescr
                                 , @c_Gender
                                 , @c_CommodityCode
                                 , @c_Lottable02     
                                 , @n_Qty
                                 , @n_UnitPrice
                                 , @n_NetWgt 
                                 , @c_ProductType
                                 , @c_InvoiceNo 
   END
   CLOSE CUR_DET
   DEALLOCATE CUR_DET    

   SET @n_TotalGrossWgt = @n_TotalNetWgt + (0.5 * @n_NoOfCarton)

   IF EXISTS ( SELECT 1 FROM #TMP_INV GROUP BY Orderkey HAVING COUNT(1) > 0 AND
               SUM(CASE WHEN InvoiceNo = '' OR InvoiceNo IS NULL THEN 1 ELSE 0 END) > 0 )
   BEGIN
      SELECT TOP 1 @c_InvoiceNo = InvoiceNo
      FROM #TMP_INV
      WHERE InvoiceNo <> '' AND InvoiceNo IS NOT NULL

      BEGIN TRAN
      IF @c_InvoiceNo = ''
      BEGIN
         -- GET Invoice #
         SELECT TOP 1 @c_CS_InvPF = CS_Prefix
         FROM #TMP_INV 
         WHERE Orderkey = @c_Orderkey 

         SET @c_InvNo = ''
         EXECUTE nspg_GetKey       
                  @c_CS_InvPF    
               ,  6    
               ,  @c_InvNo       OUTPUT    
               ,  @b_Success     OUTPUT    
               ,  @n_err         OUTPUT    
               ,  @c_errmsg      OUTPUT        

         IF @b_Success = 1 
         BEGIN   
            SET @c_InvoiceNo = 'JW / ' + @c_CS_InvPF  + ' / ' + CONVERT(NVARCHAR(6), CONVERT(INT, @c_InvNo))
         END
      END

      UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET Userdefine10 =  @c_InvoiceNo
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,Trafficcop = NULL
      WHERE Orderkey = @c_Orderkey
      AND ( Userdefine10 = '' OR Userdefine10 IS NULL )

      SET @n_err = @@ERROR    
      IF @n_err <> 0    
      BEGIN    
         SET @n_continue = 3    
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
         SET @n_err = 81010 -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Invoice To ORDERDETAIL Failed (isp_invoice_02)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) ' 
         GOTO QUIT     
      END  

      UPDATE #TMP_INV SET InvoiceNo = @c_InvoiceNo
      WHERE (InvoiceNo = '' OR InvoiceNo IS NULL)
   END


   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
   QUIT:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN 
      IF @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END 
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_invoice_02'  
   END

   SELECT NoOfCarton
        , ProductType
        , CONVERT(NVARCHAR(5), NoOfCarton) + ' box to ' + CS_City + ' - ' + ProductType
        , InvoiceNo
        , Orderkey
        , ExternOrderkey
        , DeliveryDate
        , C_Contact1
        , C_Address1
        , C_Address2
        , C_City
        , C_Country
        , Sku
        , Style 
        , SkuDescr
        , Gender
        , CommodityCode
        , GoodsDescr       
        , Season           
        , FabricComp       
        , OrigOfCountry    
        , Supplier         
        , FactoryName      
        , Knitted             
        , SUM(Qty)
        , UnitPrice 
        , @n_TotalNetWgt
        , @n_TotalGrossWgt
   FROM #TMP_INV
   GROUP BY NoOfCarton
         ,  ProductType
         ,  InvoiceNo
         ,  CONVERT(NVARCHAR(5), NoOfCarton) + ' box to ' + CS_City + ' - ' + ProductType
         ,  Orderkey
         ,  ExternOrderkey
         ,  DeliveryDate
         ,  C_Contact1
         ,  C_Address1
         ,  C_Address2
         ,  C_City
         ,  C_Country
         ,  Sku
         ,  Style 
         ,  SkuDescr
         ,  Gender
         ,  CommodityCode
         ,  GoodsDescr       
         ,  Season           
         ,  FabricComp       
         ,  OrigOfCountry    
         ,  Supplier         
         ,  FactoryName      
         ,  Knitted             
         ,  UnitPrice 
   ORDER BY Orderkey
         ,  ProductType
         ,  Sku  

   DROP TABLE #TMP_INV


   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   RETURN
END

GO