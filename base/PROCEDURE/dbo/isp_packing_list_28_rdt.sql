SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Trigger: isp_Packing_List_28_rdt                                     */    
/* Creation Date: 30-AUG-2016                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by: YTWan                                                    */    
/*                                                                      */    
/* Purpose:                                                             */    
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
/* 05-Aug-2016  CSCHONG   1.0   WMS-2880 - Add logic to support RDT     */    
/*                              and ECOM EXCEED (CS01)                  */  
/* 10-May-2020  PAKYUEN   1.1   INC1137262 - extended from 20 to 30(PY01)*/     
/************************************************************************/    
CREATE PROC [dbo].[isp_Packing_List_28_rdt]     
            @c_PickSlipNo  NVARCHAR(10)    
          , @c_Orderkey    NVARCHAR(10) = ''    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
       
       
       
   /*CS01 Start*/    
       
   IF EXISTS (SELECT 1 FROM PackHeader WITH (NOLOCK)    
              WHERE PickSlipNo = @c_PickSlipNo)    
   BEGIN    
    --SET @c_getOrdKey = @c_PickSlipNo     
        
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
       
   /*CS01 END*/          
    
    
   --IF ISNULL(@c_Orderkey,'') = ''     
   --BEGIN    
   --   SELECT @c_Orderkey = Orderkey    
   --   FROM PACKHEADER (NOLOCK)    
   --   WHERE PickSlipNo = @c_PickSlipNo    
   --END    
    
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
   ,  DESCR          NVARCHAR(40)    
   ,  Qty            INT    
   ,  ExtOrdKey      NVARCHAR(30)                  --CS01  --PY01  
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
         ,DESCR      = ISNULL(RTRIM(ORDERDETAIL.UserDefine01),'')    
                     + ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')    
         ,Qty        = ISNULL(SUM(PICKDETAIL.Qty),0)    
         ,ExtOrdkey  = ORDERS.ExternOrderKey                              --CS01    
      FROM ORDERS      WITH (NOLOCK)    
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.Orderkey = ORDERDETAIL.Orderkey)    
      JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)    
                                     AND(ORDERDETAIL.Sku = SKU.Sku)    
      JOIN PICKDETAIL  WITH (NOLOCK) ON (ORDERDETAIL.Orderkey = PICKDETAIL.Orderkey)    
                                     AND(ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)    
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
            ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine01),'')    
            ,  ISNULL(RTRIM(ORDERDETAIL.UserDefine02),'')    
            , ORDERS.ExternOrderKey                              --CS01    
      ORDER BY ORDERDETAIL.Storerkey    
            ,  ORDERDETAIL.Sku    
       
          
    
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
      FROM #TMP_ORD    
      ORDER BY PageGroup    
            ,  RowRef    
    
   QUIT_SP:    
END -- procedure 

GO