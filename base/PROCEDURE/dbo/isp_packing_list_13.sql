SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/      
/* Stored Procedure: isp_Packing_List_13                                 */      
/* Creation Date: 11-AUG-2014                                            */      
/* Copyright: IDS                                                        */      
/* Written by: YTWan                                                     */      
/*                                                                       */      
/* Purpose: SOS#316818 - RCM - Alshaya Packing List Print                */      
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
/*************************************************************************/       
    
CREATE PROCEDURE [dbo].[isp_Packing_List_13]
           @c_Storerkey       NVARCHAR(15)          
         , @c_Orderkey        NVARCHAR(10)
         , @c_ProductType     NVARCHAR(18)
         , @n_NoOfCarton      INT
AS BEGIN
   SET NOCOUNT ON       
   SET QUOTED_IDENTIFIER OFF       
   SET ANSI_NULLS OFF       
   SET CONCAT_NULL_YIELDS_NULL OFF   


   DECLARE @c_LabelNo         NVARCHAR(20)
         , @c_Sku             NVARCHAR(20)
         , @c_SkuDescr        NVARCHAR(60)
         , @c_Color           NVARCHAR(30)
         , @c_Size            NVARCHAR(30)
         , @c_CommodityCode   NVARCHAR(30)
         , @c_Lottable02      NVARCHAR(18)
         , @n_Qty             INT
         , @n_Dimensions      FLOAT
         , @n_TotalDimensions FLOAT
         , @n_GrossWgt        FLOAT
         , @n_TotalNetWgt     FLOAT
         , @n_TotalGrossWgt   FLOAT

         , @c_ReceiptKey      NVARCHAR(10)
         , @c_ReceiptLineNo   NVARCHAR(5)
         , @c_Knitted         NVARCHAR(30)
         , @c_FabricComp      NVARCHAR(30)
         , @c_OrigOfCountry   NVARCHAR(18)  
         , @c_GoodsDescr      NVARCHAR(30)

         , @c_SQL             NVARCHAR(4000)
         , @c_SQLParms        NVARCHAR(4000)    
         , @c_DBName          NVARCHAR(20)
         , @c_ArchiveDBName   NVARCHAR(20)

   CREATE TABLE #TMP_PACK
           ( NoOfCarton       INT
           , Orderkey         NVARCHAR(10)
           , ProductType      NVARCHAR(18)
           , LabelNo          NVARCHAR(20) 
           , Sku              NVARCHAR(20)                                 
           , SkuDescr         NVARCHAR(60)  
           , Color            NVARCHAR(30)                                                                
           , Size             NVARCHAR(30)                                                               
           , CommodityCode    NVARCHAR(30)  
           , Knitted          NVARCHAR(30)  
           , FabricComp       NVARCHAR(30) 
           , OrigOfCountry    NVARCHAR(18)                                              
           , GoodsDescr       NVARCHAR(30)      
           , Qty              INT   
           , Dimensions       FLOAT
           , GrossWgt         FLOAT
           )

   SET @c_ArchiveDBName = ''

   SELECT @c_ArchiveDBName = ISNULL(RTRIM(NSQLValue),'')   
   FROM NSQLCONFIG WITH (NOLOCK)
   WHERE ConfigKey = 'ArchiveDBName'

   SET @n_TotalDimensions = 0.00
   SET @n_TotalNetWgt     = 0.00
   SET @n_TotalGrossWgt   = 0.00

   DECLARE CUR_DET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
   SELECT ISNULL(RTRIM(OD.UserDefine09),'')
         ,PACD.LabelNo
         ,PICD.Sku
         ,Descr = ISNULL(RTRIM(SKU.Descr),'')
         ,Color = ISNULL(RTRIM(SKU.Busr6),'')
         ,Size  = ISNULL(RTRIM(SKU.Busr2),'')
         ,CommodityCode = ISNULL(RTRIM(SKU.Busr4),'')
         ,Lottable02    = ISNULL(RTRIM(LA.Lottable02),'')
         ,Qty = ISNULL(SUM(PACD.Qty),0)
         ,Dimensions    = ISNULL(SUM(SKU.Height * SKU.Length * SKU.Width * PICD.Qty),0.00)
         ,GrossWgt      = ISNULL(SUM(SKU.GrossWgt * PACD.Qty),0.00) 
   FROM PICKDETAIL   PICD  WITH (NOLOCK)
   JOIN ORDERDETAIL  OD    WITH (NOLOCK) ON (PICD.Orderkey = OD.Orderkey) 
                                         AND(PICD.OrderLineNumber = OD.OrderLineNumber)
   JOIN PACKDETAIL   PACD  WITH (NOLOCK) ON (PICD.PickSlipNo = PACD.PickSlipNo)
                                         AND(PICD.Storerkey = PACD.Storerkey)
                                         AND(PICD.Sku = PACD.Sku)
   JOIN SKU          SKU   WITH (NOLOCK) ON (PICD.Storerkey = SKU.Storerkey)
                                         AND(PICD.Sku = SKU.Sku)
   JOIN LOTATTRIBUTE  LA   WITH (NOLOCK) ON (PICD.Lot = LA.Lot) 
   WHERE PICD.Storerkey = @c_Storerkey
   AND   PICD.Orderkey = @c_Orderkey
   AND   PICD.Status >= '5'
   AND   ISNULL(RTRIM(OD.UserDefine09),'') = @c_ProductType
   GROUP BY ISNULL(RTRIM(OD.UserDefine09),'')
         ,  PACD.LabelNo
         ,  PICD.Sku
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RTRIM(SKU.Busr6),'')
         ,  ISNULL(RTRIM(SKU.Busr2),'')
         ,  ISNULL(RTRIM(SKU.Busr4),'')
         ,  ISNULL(RTRIM(LA.Lottable02),'')


   OPEN CUR_DET 
   FETCH NEXT FROM CUR_DET INTO @c_ProductType
                              , @c_LabelNo
                              , @c_Sku
                              , @c_SkuDescr
                              , @c_Color
                              , @c_Size
                              , @c_CommodityCode
                              , @c_Lottable02     
                              , @n_Qty
                              , @n_Dimensions
                              , @n_GrossWgt

   WHILE @@FETCH_STATUS = 0     
   BEGIN 
      SET @n_TotalDimensions = @n_TotalDimensions + @n_Dimensions
      SET @n_TotalGrossWgt   = @n_TotalGrossWgt + @n_GrossWgt

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

      SET @c_Knitted       = ''
      SET @c_FabricComp    = ''
      SET @c_OrigOfCountry = ''
      SET @c_GoodsDescr    = ''

      SET @c_Sql = N'SELECT @c_Knitted    =  ISNULL(RTRIM(RD.Userdefine03),'''')'
                 +  ' ,@c_FabricComp = ISNULL(RTRIM(RD.Userdefine02),'''')'
                 +  ' ,@c_OrigOfCountry =  ISNULL(RTRIM(RD.VesselKey),'''')'
                 +  ' ,@c_GoodsDescr = ISNULL(RTRIM(RD.Userdefine04),'''')'
                 +  ' FROM ' + @c_DBName + 'dbo.RECEIPTDETAIL RD WITH (NOLOCK)'
                 +  ' WHERE RD.ReceiptKey = @c_ReceiptKey'
                 +  ' AND RD.ReceiptLineNumber = @c_ReceiptLineNo'

      SET @c_SqlParms = N'@c_ReceiptKey      NVARCHAR(30)'  
                      + ',@c_ReceiptLineNo   NVARCHAR(30)' 
                      + ',@c_Knitted         NVARCHAR(30)   OUTPUT' 
                      + ',@c_FabricComp      NVARCHAR(30)   OUTPUT' 
                      + ',@c_OrigOfCountry   NVARCHAR(18)   OUTPUT' 
                      + ',@c_GoodsDescr      NVARCHAR(30)   OUTPUT'

      EXEC sp_ExecuteSql  @c_Sql
                        , @c_SqlParms
                        , @c_ReceiptKey   
                        , @c_ReceiptLineNo  
                        , @c_Knitted         OUTPUT 
                        , @c_FabricComp      OUTPUT   
                        , @c_OrigOfCountry   OUTPUT  
                        , @c_GoodsDescr      OUTPUT
  

   
      INSERT INTO #TMP_PACK
           ( Orderkey
           , ProductType
           , NoOfCarton
           , LabelNo
           , Sku
           , SkuDescr
           , Color
           , Size
           , CommodityCode
           , Knitted           
           , FabricComp       
           , OrigOfCountry  
           , GoodsDescr   
           , Qty
           , Dimensions
           , GrossWgt
           )
      VALUES
           ( @c_Orderkey
           , @c_ProductType
           , @n_NoOfCarton
           , @c_LabelNo
           , @c_Sku
           , @c_SkuDescr
           , @c_Color
           , @c_Size
           , @c_CommodityCode
           , @c_Knitted   
           , @c_FabricComp       
           , @c_OrigOfCountry
           , @c_GoodsDescr     
           , @n_Qty
           , @n_Dimensions
           , @n_GrossWgt 
           )

      FETCH NEXT FROM CUR_DET INTO @c_ProductType
                                 , @c_LabelNo
                                 , @c_Sku
                                 , @c_SkuDescr
                                 , @c_Color
                                 , @c_Size
                                 , @c_CommodityCode
                                 , @c_Lottable02     
                                 , @n_Qty
                                 , @n_Dimensions
                                 , @n_GrossWgt  
   END
   CLOSE CUR_DET
   DEALLOCATE CUR_DET    

   --SET @n_TotalGrossWgt = @n_TotalNetWgt + (0.5 * @n_NoOfCarton)
   SET @n_TotalNetWgt = @n_TotalGrossWgt

   SELECT NoOfCarton 
        , Orderkey
        , ProductType
        , LabelNo
        , SkuDescr
        , Color 
        , Size
        , CommodityCode
        , Knitted
        , FabricComp       
        , OrigOfCountry    
        , GoodsDescr       
        , SUM(Qty)
        , @n_TotalDimensions
        , @n_TotalNetWgt
        , @n_TotalGrossWgt
   FROM #TMP_PACK
   GROUP BY NoOfCarton
         ,  Orderkey
         ,  ProductType
         ,  LabelNo
         ,  SkuDescr
         ,  Color 
         ,  Size
         ,  CommodityCode
         ,  Knitted
         ,  FabricComp       
         ,  OrigOfCountry    
         ,  GoodsDescr 
   ORDER BY Orderkey
         ,  ProductType
         ,  MIN(Sku)


   DROP TABLE #TMP_PACK
END

GO