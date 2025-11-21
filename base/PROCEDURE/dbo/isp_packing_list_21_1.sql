SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Packing_List_21_1                                       */
/* Creation Date: 15-DEC-2016                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: WMS-782 - Quiksilver - E-com Packing List                   */
/*        :                                                             */
/* Called By: r_dw_packing_list_27                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 15-Mar-2017  CSCHONG 1.0   WMS-1286 add filter by storerkey (CS01)   */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */  
/************************************************************************/
CREATE PROC [dbo].[isp_Packing_List_21_1] 
            @c_PickSlipNo  NVARCHAR(10)
          , @c_Orderkey    NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF ISNULL(@c_Orderkey,'') = '' 
   BEGIN
      SELECT @c_Orderkey = Orderkey
      FROM PACKHEADER (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
   END

   CREATE TABLE #TMP_ORD
   (  RowRef         INT         NOT NULL IDENTITY(1,1)   PRIMARY KEY
   ,  Orderkey       NVARCHAR(10)  
   ,  ExternOrderkey NVARCHAR(50)  --tlting_ext 
   ,  C_Address1     NVARCHAR(45)
   ,  C_Contact1     NVARCHAR(30) 
   ,  C_Phone1       NVARCHAR(18)
   ,  Orderdate      DATETIME
   ,  ShipMethod     NVARCHAR(60) 
   ,  CarrierCharges FLOAT
   ,  OtherCharges   FLOAT
   ,  ExternLineNo   NVARCHAR(20)
   ,  Storerkey      NVARCHAR(15)
   ,  Sku            NVARCHAR(20)
   ,  Color          NVARCHAR(10)
   ,  Size           NVARCHAR(10)
   ,  UnitPrice      FLOAT
   ,  Notes          NVARCHAR(500)
   ,  Qty            INT
   )        

   INSERT INTO #TMP_ORD
   (  Orderkey
   ,  ExternOrderkey
   ,  C_Address1 
   ,  C_Contact1 
   ,  C_Phone1 
   ,  Orderdate  
   ,  ShipMethod
   ,  CarrierCharges
   ,  OtherCharges
   ,  ExternLineNo
   ,  Storerkey 
   ,  Sku
   ,  Color
   ,  Size
   ,  UnitPrice     
   ,  Notes      
   ,  Qty
   )    
   SELECT ORDERS.Orderkey 
         ,ExternOrderkey = ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
         ,C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,C_Contact1 = ISNULL(RTRIM(ORDERS.C_Contact1),'')
         ,C_Phone1   = ISNULL(RTRIM(ORDERS.C_Phone1),'')
         ,Orderdate  = ISNULL(ORDERS.Orderdate,'1900-01-01')
         ,ShipMethod = ISNULL(RTRIM(CODELKUP.UDF04),'')
         ,CarrierCharges = ISNULL(ORDERINFO.CarrierCharges,0.00)
         ,OtherCharges   = ISNULL(ORDERINFO.OtherCharges,0.00)
         ,ExternLineNo = ISNULL(RTRIM(ORDERDETAIL.ExternLineNo),'')
         ,ORDERDETAIL.Storerkey
         ,ORDERDETAIL.Sku
         ,Color     = ISNULL(RTRIM(SKU.Color),'')
         ,Size      = ISNULL(RTRIM(SKU.Size),'')
         ,UnitPrice = ISNULL(ORDERDETAIL.UnitPrice,0.00)
         ,Notes     = ISNULL(RTRIM(ORDERDETAIL.Notes),'')
         ,Qty       = ISNULL(SUM(ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty),0)
      FROM ORDERS      WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                     AND(ORDERDETAIL.Sku = SKU.Sku)
      LEFT JOIN ORDERINFO   WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERINFO.Orderkey)                                       
      LEFT JOIN CODELKUP    WITH (NOLOCK) ON (CODELKUP.LISTNAME = 'TRACKNO')
                                          AND(CODELKUP.Code = ORDERS.ShipperKey)     
                                          AND  (CODELKUP.storerkey = ORDERS.StorerKey)           --(CS01)                                                                           
      WHERE ORDERS.Orderkey = @c_Orderkey
      AND   ORDERS.Type = 'ECOM'
      GROUP BY ORDERS.Orderkey
            ,  ISNULL(RTRIM(ORDERS.ExternOrderkey),'')
            ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
            ,  ISNULL(RTRIM(ORDERS.C_Contact1),'')
            ,  ISNULL(RTRIM(ORDERS.C_Phone1),'')
            ,  ISNULL(ORDERS.Orderdate,'1900-01-01')
            ,  ISNULL(RTRIM(CODELKUP.UDF04),'')
            ,  ISNULL(ORDERINFO.CarrierCharges,0.00)
            ,  ISNULL(ORDERINFO.OtherCharges,0.00)
            ,  ISNULL(RTRIM(ORDERDETAIL.ExternLineNo),'')
            ,  ORDERDETAIL.Storerkey
            ,  ORDERDETAIL.Sku
            ,  ISNULL(RTRIM(SKU.Color),'')
            ,  ISNULL(RTRIM(SKU.Size),'')
            ,  ISNULL(ORDERDETAIL.UnitPrice,0.00)
            ,  ISNULL(RTRIM(ORDERDETAIL.Notes),'')
      ORDER BY ORDERDETAIL.Storerkey
            ,  ORDERDETAIL.Sku
   
      

      SELECT 
         Orderkey
      ,  ExternOrderkey
      ,  C_Address1
      ,  C_Contact1 
      ,  C_Phone1   
      ,  Orderdate 
      ,  ShipMethod        
      ,  CarrierCharges
      ,  OtherCharges
      ,  ExternLineNo
      ,  Storerkey
      ,  Sku
      ,  Color
      ,  Size
      ,  UnitPrice     
      ,  Notes      
      ,  Qty
      FROM #TMP_ORD
      ORDER BY RowRef

   QUIT_SP:
END -- procedure

GO