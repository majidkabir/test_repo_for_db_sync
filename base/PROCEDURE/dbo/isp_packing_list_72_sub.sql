SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_Packing_List_72_SUB                                     */
/* Creation Date: 09-Dec-2019                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  WMS-11391 - Pandora B2C Packing List                       */
/*           Copy from isp_Packing_List_28_rdt and modify               */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/************************************************************************/

CREATE PROC [dbo].[isp_Packing_List_72_SUB] 
            @c_PickSlipNo  NVARCHAR(10)
          , @c_Orderkey    NVARCHAR(10) = ''
          , @c_Type        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_cartonno   INT, @n_MaxLineno INT = 23, @n_MaxRec INT = 0
   DECLARE @n_CurrentRec INT, @n_PrintCount INT = 2  

   IF @c_Type = 'H'
   BEGIN
      SELECT @c_PickSlipNo, @c_Orderkey, 'D','1'
      UNION ALL
      SELECT @c_PickSlipNo, @c_Orderkey, 'D','2'
      GOTO QUIT_SP
   END

   IF EXISTS (SELECT 1 FROM PackHeader WITH (NOLOCK)
              WHERE PickSlipNo = @c_PickSlipNo)
   BEGIN
      IF ISNULL(@c_Orderkey,'') = '' 
      BEGIN
         SELECT @c_Orderkey = Orderkey
         FROM PACKHEADER (NOLOCK)
         WHERE PickSlipNo = @c_PickSlipNo
      END
   END       
   ELSE
   BEGIN
      SET @c_orderkey = @c_PickSlipNo
   END 	

   CREATE TABLE #TMP_ORD
   (  RowRef         INT         NOT NULL IDENTITY(1,1)   PRIMARY KEY
   ,  Orderkey       NVARCHAR(10)  
   ,  COTitle        NVARCHAR(30)
   ,  COTitle2       NVARCHAR(30)
   ,  C_Address1     NVARCHAR(45)
   ,  C_Address2     NVARCHAR(45)
   ,  C_Address3     NVARCHAR(45)
   ,  C_Address4     NVARCHAR(45)
   ,  C_Zip          NVARCHAR(18)
   ,  C_City         NVARCHAR(18)    
   ,  C_State        NVARCHAR(18)
   ,  C_Contact1     NVARCHAR(30) 
   ,  C_Phone1       NVARCHAR(18)
   ,  Orderdate      DATETIME
   ,  M_Company      NVARCHAR(45) 
   ,  Storerkey      NVARCHAR(15)
   ,  Sku            NVARCHAR(20)
   ,  AltSku         NVARCHAR(20)
   ,  DESCR          NVARCHAR(255)
   ,  Qty            INT
   ,  ExtOrdKey      NVARCHAR(50)                  --CS01
   ,  Cartonno        NVARCHAR(20)                 --mingle01
   )    

      CREATE TABLE #TMP_ORD_Final
   (  RowRef         INT         NOT NULL IDENTITY(1,1)   PRIMARY KEY
   ,  Orderkey       NVARCHAR(10)  
   ,  COTitle        NVARCHAR(30)
   ,  COTitle2       NVARCHAR(30)
   ,  C_Address1     NVARCHAR(45)
   ,  C_Address2     NVARCHAR(45)
   ,  C_Address3     NVARCHAR(45)
   ,  C_Address4     NVARCHAR(45)
   ,  C_Zip          NVARCHAR(18)
   ,  C_City         NVARCHAR(18)    
   ,  C_State        NVARCHAR(18)
   ,  C_Contact1     NVARCHAR(30) 
   ,  C_Phone1       NVARCHAR(18)
   ,  Orderdate      DATETIME
   ,  M_Company      NVARCHAR(45) 
   ,  Storerkey      NVARCHAR(15)
   ,  Sku            NVARCHAR(20)
   ,  AltSku         NVARCHAR(20)
   ,  DESCR          NVARCHAR(255)
   ,  Qty            INT
   ,  ExtOrdKey      NVARCHAR(50)             
   ,  Cartonno       NVARCHAR(20)
   ,  RecGroup       INT NULL
   ,  ShowNo         NVARCHAR(10)
   )    

   INSERT INTO #TMP_ORD
   (  Orderkey
   ,  COTitle
   ,  COTitle2
   ,  C_Address1
   ,  C_Address2
   ,  C_Address3
   ,  C_Address4
   ,  C_Zip      
   ,  C_City     
   ,  C_State    
   ,  C_Contact1 
   ,  C_Phone1   
   ,  Orderdate  
   ,  M_Company 
   ,  Storerkey 
   ,  Sku
   ,  AltSku     
   ,  DESCR      
   ,  Qty
   ,  ExtOrdKey                    --CS01
   ,  Cartonno                      --mingle01
   )    
   SELECT ORDERS.Orderkey 
         ,COTitle    = ISNULL(RTRIM(CODELKUP.UDF01),'')
         ,COTitle2   = ISNULL(RTRIM(CODELKUP.UDF02),'')
         ,C_Address1 = ISNULL(RTRIM(ORDERS.C_Address1),'')
         ,C_Address2 = ISNULL(RTRIM(ORDERS.C_Address2),'')
         ,C_Address3 = ISNULL(RTRIM(ORDERS.C_Address3),'')
         ,C_Address4 = ISNULL(RTRIM(ORDERS.C_Address4),'')
         ,C_Zip      = ISNULL(RTRIM(ORDERS.C_Zip),'')
         ,C_City     = ISNULL(RTRIM(ORDERS.C_City),'')
         ,C_State    = ISNULL(RTRIM(ORDERS.C_State),'')
         ,C_Contact1 = ISNULL(RTRIM(ORDERS.C_Contact1),'')
         ,C_Phone1   = ISNULL(RTRIM(ORDERS.C_Phone1),'')
         ,Orderdate  = ISNULL(ORDERS.Orderdate,'1900-01-01')
         ,M_Company  = ISNULL(RTRIM(ORDERS.M_Company),'')
         ,ORDERDETAIL.Storerkey
         ,ORDERDETAIL.Sku
         ,AltSku     = ISNULL(RTRIM(SKU.AltSku),'')
         ,DESCR      = LTRIM(RTRIM(ISNULL(SKU.Descr,'')))--ISNULL(RTRIM(ORDERDETAIL.UserDefine01),'')
                     --+ ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')
         ,Qty        = ISNULL(SUM(PACKDETAIL.Qty),0)
         ,ExtOrdkey  = ORDERS.ExternOrderKey                              --CS01
         ,Packdetail.Cartonno                                            --mingle01
      FROM ORDERS      WITH (NOLOCK)
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)
      JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                     AND(ORDERDETAIL.Sku = SKU.Sku)
      --JOIN PICKDETAIL  WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)
                                     --AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
      JOIN PACKHEADER WITH (NOLOCK) ON (ORDERS.ORDERKEY = PACKHEADER.ORDERKEY)
      JOIN PACKDETAIL WITH (NOLOCK) ON (PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno) AND (PACKDETAIL.SKU = ORDERDETAIL.SKU)
      JOIN CODELKUP    WITH (NOLOCK) ON (CODELKUP.LISTNAME = 'PDAEPL')
                                     AND(CODELKUP.Storerkey = ORDERS.Storerkey)
                                     AND(CODELKUP.Long = ORDERS.UserDefine03)
      WHERE ORDERS.Orderkey = @c_Orderkey
      AND NOT EXISTS (SELECT 1 
                      FROM CODELKUP CL WITH (NOLOCK)
                      WHERE CL.ListName = 'SKUDIV'
                      AND CL.Code = SKU.SkuGroup)
      GROUP BY ORDERS.Orderkey
            ,  ISNULL(RTRIM(CODELKUP.UDF01),'')
            ,  ISNULL(RTRIM(CODELKUP.UDF02),'')
            ,  ISNULL(RTRIM(ORDERS.C_Address1),'')
            ,  ISNULL(RTRIM(ORDERS.C_Address2),'')
            ,  ISNULL(RTRIM(ORDERS.C_Address3),'')
            ,  ISNULL(RTRIM(ORDERS.C_Address4),'')
            ,  ISNULL(RTRIM(ORDERS.C_Zip),'')
            ,  ISNULL(RTRIM(ORDERS.C_City),'')
            ,  ISNULL(RTRIM(ORDERS.C_State),'')
            ,  ISNULL(RTRIM(ORDERS.C_Contact1),'')
            ,  ISNULL(RTRIM(ORDERS.C_Phone1),'')
            ,  ISNULL(ORDERS.Orderdate,'1900-01-01')
            ,  ISNULL(RTRIM(ORDERS.M_Company),'')
            ,  ORDERDETAIL.Storerkey
            ,  ORDERDETAIL.Sku
            ,  ISNULL(RTRIM(SKU.AltSku),'')
            ,  LTRIM(RTRIM(ISNULL(SKU.Descr,'')))
         --   ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine01),'')
         --   ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')
            , ORDERS.ExternOrderKey                              --CS01
            , Packdetail.Cartonno                                --mingle01
      ORDER BY ORDERDETAIL.Storerkey
            ,  PACKDETAIL.CartonNo
            ,  ORDERDETAIL.Sku
   
     /*DECLARE CUR_psno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
     SELECT DISTINCT CAST(CartonNo AS INT)             
     FROM #TMP_ORD   
     WHERE Orderkey = @c_Orderkey        
     ORDER BY CAST(CartonNo AS INT) ASC     
                   
     OPEN CUR_PSNO                 
                   
     FETCH NEXT FROM CUR_PSNO INTO @n_cartonno                
     WHILE @@FETCH_STATUS <> -1                
     BEGIN           
        INSERT INTO #TMP_ORD_Final
        (  Orderkey
        ,  COTitle
        ,  COTitle2
        ,  C_Address1
        ,  C_Address2
        ,  C_Address3
        ,  C_Address4
        ,  C_Zip      
        ,  C_City     
        ,  C_State    
        ,  C_Contact1 
        ,  C_Phone1   
        ,  Orderdate  
        ,  M_Company 
        ,  Storerkey 
        ,  Sku
        ,  AltSku     
        ,  DESCR      
        ,  Qty
        ,  ExtOrdKey            
        ,  Cartonno  
        ,  RecGroup
        ,  ShowNo 
        )                   
   SELECT  Orderkey
        ,  COTitle
        ,  COTitle2
        ,  C_Address1
        ,  C_Address2
        ,  C_Address3
        ,  C_Address4
        ,  C_Zip      
        ,  C_City     
        ,  C_State    
        ,  C_Contact1 
        ,  C_Phone1   
        ,  Orderdate  
        ,  M_Company 
        ,  Storerkey 
        ,  Sku
        ,  AltSku     
        ,  DESCR      
        ,  Qty
        ,  ExtOrdKey   
        ,  Cartonno  
        ,  (Row_Number() OVER (PARTITION BY Orderkey, CartonNo ORDER BY Orderkey, CartonNo Asc) - 1)/@n_MaxLineno + 1 AS recgroup                
        ,  'Y'                
        FROM  #TMP_ORD            
        WHERE Orderkey = @c_Orderkey                
          AND CartonNo = @n_cartonno                
        ORDER BY Orderkey, CartonNo, SKU, AltSku                

     SELECT @n_MaxRec = COUNT(RowRef)                 
     FROM #TMP_ORD
      WHERE Orderkey = @c_Orderkey  
        AND CartonNo = @n_cartonno                

     SET @n_CurrentRec = @n_MaxRec % @n_MaxLineno                
                   
     WHILE(@n_MaxRec % @n_MaxLineno <> 0 AND @n_CurrentRec < @n_MaxLineno)             
     BEGIN
        INSERT INTO #TMP_ORD_Final  
        (  Orderkey
        ,  COTitle
        ,  COTitle2
        ,  C_Address1
        ,  C_Address2
        ,  C_Address3
        ,  C_Address4
        ,  C_Zip      
        ,  C_City     
        ,  C_State    
        ,  C_Contact1 
        ,  C_Phone1   
        ,  Orderdate  
        ,  M_Company 
        ,  Storerkey 
        ,  Sku
        ,  AltSku     
        ,  DESCR      
        ,  Qty
        ,  ExtOrdKey     
        ,  Cartonno  
        ,  RecGroup
        ,  ShowNo 
        )                
        SELECT  TOP 1 
                Orderkey
             ,  COTitle
             ,  COTitle2
             ,  C_Address1
             ,  C_Address2
             ,  C_Address3
             ,  C_Address4
             ,  C_Zip      
             ,  C_City     
             ,  C_State    
             ,  C_Contact1 
             ,  C_Phone1   
             ,  Orderdate  
             ,  M_Company 
             ,  Storerkey 
             ,  NULL
             ,  NULL     
             ,  NULL      
             ,  0
             ,  ExtOrdKey   
             ,  Cartonno  
             ,  0              
             ,  'N'
        FROM #TMP_ORD_Final                 
        WHERE Orderkey = @c_Orderkey  
          AND CartonNo = @n_cartonno               
        ORDER BY RowRef DESC                
                   
        SET @n_CurrentRec = @n_CurrentRec + 1                
                   
   END                 
                   
     SET @n_MaxRec = 0                
     SET @n_CurrentRec = 0                
                   
     FETCH NEXT FROM CUR_psno INTO @n_cartonno                
     END
     
     SELECT  Orderkey
          ,  COTitle
          ,  COTitle2
          ,  C_Address1
          ,  C_Address2
          ,  C_Address3
          ,  C_Address4
          ,  C_Zip      
          ,  C_City     
          ,  C_State    
          ,  C_Contact1 
          ,  C_Phone1   
          ,  Orderdate  
          ,  M_Company 
          ,  Sku
          ,  AltSku     
          ,  DESCR      
          ,  Qty
          ,  PageGroup = (RowRef - 1) / 20
          ,  ExtOrdKey   
          ,  Cartonno  
          ,  RecGroup             
          ,  ShowNo
     FROM #TMP_ORD_Final 
     ORDER BY Orderkey, CartonNo, CASE WHEN ISNULL(SKU,'') = '' THEN 1 ELSE 0 END, SKU, AltSKU         */        

         SELECT
            Orderkey
         ,  COTitle
         ,  COTitle2
         ,  C_Address1
         ,  C_Address2
         ,  C_Address3
         ,  C_Address4
         ,  C_Zip      
         ,  C_City     
         ,  C_State    
         ,  C_Contact1 
         ,  C_Phone1   
         ,  Orderdate  
         ,  M_Company  
         ,  Sku
         ,  AltSku     
         ,  DESCR      
         ,  Qty
         ,  PageGroup = (RowRef - 1) / 20
         ,  ExtOrdKey                          --CS01
         ,  Cartonno                           --mingle01
         ,  @n_PrintCount
         FROM #TMP_ORD
         ORDER BY PageGroup
               ,  RowRef 



   QUIT_SP:
END -- procedure

GO