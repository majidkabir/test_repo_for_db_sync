SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure: isp_EDRsg_deliverylabel                             */  
/* Creation Date: 04-MAR-2019                                           */  
/* Copyright: IDS                                                       */  
/* Written by: WLCHOOI                                                  */  
/*                                                                      */  
/* Purpose: WMS-8168 - SG - EDR - Order Label copied from               */ 
/*          isp_diageosg_deliverylabel                                  */ 
/*                                                                      */  
/* Called By: r_dw_caselabel_edr copied from r_dw_caselabel_diageo      */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date           Author      Purposes                                  */  
/************************************************************************/  
CREATE PROC [dbo].[isp_EDRsg_deliverylabel] (  
            @c_orderkey   NVARCHAR(15)  
            ,@c_SKU       NVARCHAR(40)  
            ,@c_fromlabel NVARCHAR(5)  
            ,@c_tolabel   NVARCHAR(5)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE  
    @n_continue         INT = 1
   ,@b_debug            INT = 0
   ,@n_MaxLineno        INT = 5
   ,@n_intFlag          INT = 1
   ,@n_TTLpage          INT = 1         
   ,@n_CurrentPage      INT = 1 
   ,@n_MaxLine          INT = 5

   DECLARE
    @c_SKU01            NVARCHAR(80) = '',           
    @c_SKU02            NVARCHAR(80) = '',     
	 @c_SKU03            NVARCHAR(80) = '',            
	 @c_SKU04            NVARCHAR(80) = '', 
	 @c_SKU05            NVARCHAR(80) = '',              
	 @c_SKUQty01         NVARCHAR(10) = '',     
	 @c_SKUQty02         NVARCHAR(10) = '', 
	 @c_SKUQty03         NVARCHAR(10) = '',     
	 @c_SKUQty04         NVARCHAR(10) = '', 
	 @c_SKUQty05         NVARCHAR(10) = '',  
    @c_Descr01          NVARCHAR(40) = '',  
    @c_Descr02          NVARCHAR(40) = '',   
    @c_Descr03          NVARCHAR(40) = '',   
    @c_Descr04          NVARCHAR(40) = '',   
    @c_Descr05          NVARCHAR(40) = '',      
    @n_skuqty           INT = 0 ,
    @n_CntRec           INT = 0 ,
    @c_Descr            NVARCHAR(40)

   CREATE TABLE #RESULT1 (
   [ID]    [INT] IDENTITY(1,1) NOT NULL, 
   [Route]       NVARCHAR(20) NULL,
   OrderNo       NVARCHAR(60) NULL,
   CCompany      NVARCHAR(45) NULL,
   CAddress1     NVARCHAR(250) NULL,
   CAddress2     NVARCHAR(250) NULL,
   CAddress3     NVARCHAR(250) NULL,
   CCountry      NVARCHAR(20) NULL,
   CZip          NVARCHAR(20) NULL,
   SKU01         NVARCHAR(100) NULL,
   DESCR01       NVARCHAR(40) NULL,
   QTY01         INT,
   SKU02         NVARCHAR(100) NULL,
   DESCR02       NVARCHAR(40) NULL,
   QTY02         INT,
   SKU03         NVARCHAR(100) NULL,
   DESCR03       NVARCHAR(40) NULL,
   QTY03         INT,
   SKU04         NVARCHAR(100) NULL,
   DESCR04       NVARCHAR(40) NULL,
   QTY04         INT,
   SKU05         NVARCHAR(100) NULL,
   DESCR05       NVARCHAR(40) NULL,
   QTY05         INT,
   TotalPIDQty   INT           
   )

   CREATE TABLE #TEMPSKU (
   [ID]          [INT] IDENTITY(1,1) NOT NULL,
   Orderkey      NVARCHAR(20),
   SKU           NVARCHAR(100) NULL,
   Descr         NVARCHAR(40) NULL,
   QTY           INT,           
   )

   INSERT INTO #RESULT1 ([Route], OrderNo,  CCompany, CAddress1, CAddress2, CAddress3, CCountry, CZip, TotalPIDQty  )    
   SELECT ORD.ROUTE
          ,ORD.ExternOrderkey
          ,ORD.C_COMPANY
          ,ORD.C_Address1
          ,ORD.C_Address2
          ,ORD.C_Address3
          ,ORD.C_Country
          ,ORD.C_Zip
          ,(SELECT SUM(PICKDETAIL.QTY) FROM PICKDETAIL (NOLOCK) WHERE PICKDETAIL.ORDERKEY = @c_Orderkey)
   FROM ORDERS ORD (NOLOCK)
   WHERE ORD.Orderkey = @c_Orderkey
   GROUP BY ORD.ROUTE
          ,ORD.ExternOrderkey
          ,ORD.C_COMPANY
          ,ORD.C_Address1
          ,ORD.C_Address2
          ,ORD.C_Address3
          ,ORD.C_Country
          ,ORD.C_Zip

   INSERT INTO #TEMPSKU      
   SELECT ORD.Orderkey
          ,ORDET.SKU
          ,SKU.Descr
          ,SUM(PID.QTY)
   FROM ORDERS ORD (NOLOCK)
   JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORDET.OrderKey=ORD.OrderKey  
   JOIN PICKDETAIL PID WITH (NOLOCK) ON (ORDET.Orderkey    = PID.Orderkey        
                                     AND PID.OrderLineNumber = ORDET.OrderLineNumber) 
   JOIN SKU (NOLOCK) ON SKU.SKU = PID.SKU AND SKU.STORERKEY = PID.STORERKEY
   WHERE ORD.Orderkey = @c_Orderkey
   GROUP BY ORD.Orderkey
           ,ORDET.SKU
           ,SKU.Descr
   
   IF @c_sku <> '?' AND @c_sku > ''
   BEGIN
	 	DELETE FROM #TEMPSKU	WHERE SKU <> @c_sku
   END

   SELECT @n_CntRec = COUNT (1)  
   FROM #TEMPSKU   
   WHERE orderkey = @c_orderkey   

   SET @n_TTLpage =  FLOOR(@n_CntRec / @n_MaxLine ) + CASE WHEN @n_CntRec % @n_MaxLine > 0 THEN 1 ELSE 0 END 

   WHILE @n_intFlag <= @n_CntRec             
     BEGIN    
          
      IF @n_intFlag > @n_MaxLine AND (@n_intFlag%@n_MaxLine) = 1 --AND @c_LastRec = 'N'  
      BEGIN  
      
      SET @n_CurrentPage = @n_CurrentPage + 1  
        
      IF (@n_CurrentPage>@n_TTLpage)   
      BEGIN  
         BREAK;  
       END     
      
      INSERT INTO #RESULT1 ([Route], OrderNo,  CCompany, CAddress1, CAddress2, CAddress3, CCountry, CZip, TotalPIDQty  ) 
      SELECT TOP 1 [Route],OrderNo,CCompany,CAddress1,CAddress2,CAddress3,CCountry,CZip,TotalPIDQty
      FROM  #Result1     
      

        SET @c_SKU01 = ''  
        SET @c_SKU02 = ''  
        SET @c_SKU03 = ''  
        SET @c_SKU04 = ''  
        SET @c_SKU05 = ''  

        SET @c_SKUQty01 = ''  
        SET @c_SKUQty02 = ''  
        SET @c_SKUQty03 = ''  
        SET @c_SKUQty04 = ''  
        SET @c_SKUQty05 = ''   
        
        SET @c_Descr01 = ''  
        SET @c_Descr02 = ''  
        SET @c_Descr03 = ''  
        SET @c_Descr04 = ''  
        SET @c_Descr05 = ''           
       
   END      
              
        
      SELECT @c_sku = SKU,  
             @n_skuqty = SUM(Qty),
             @c_Descr = Descr  
      FROM #TEMPSKU   
      WHERE ID = @n_intFlag  
      GROUP BY SKU, Descr        

      IF (@n_intFlag%@n_MaxLine) = 1 --AND @n_recgrp = @n_CurrentPage  
       BEGIN   
        --SELECT '1'      
        SET @c_sku01 = @c_sku  
        SET @c_Descr01 = @c_Descr
        SET @c_SKUQty01 = CONVERT(NVARCHAR(10),@n_skuqty)        
       END          
         
       ELSE IF (@n_intFlag%@n_MaxLine) = 2  --AND @n_recgrp = @n_CurrentPage  
       BEGIN      
        --SELECT '2'
        SET @c_sku02 = @c_sku  
        SET @c_Descr02 = @c_Descr
        SET @c_SKUQty02 = CONVERT(NVARCHAR(10),@n_skuqty)           
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 3  --AND @n_recgrp = @n_CurrentPage  
       BEGIN      
        --SELECT '3'      
        SET @c_sku03 = @c_sku  
        SET @c_Descr03 = @c_Descr
        SET @c_SKUQty03 = CONVERT(NVARCHAR(10),@n_skuqty)           
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 4  --AND @n_recgrp = @n_CurrentPage  
       BEGIN      
        --SELECT '4'       
        SET @c_sku04 = @c_sku  
        SET @c_Descr04 = @c_Descr
        SET @c_SKUQty04 = CONVERT(NVARCHAR(10),@n_skuqty)           
       END    
       ELSE IF (@n_intFlag%@n_MaxLine) = 0 --AND @n_recgrp = @n_CurrentPage  
       BEGIN      
        --SELECT '5'        
        SET @c_sku05 = @c_sku  
        SET @c_Descr05 = @c_Descr
        SET @c_SKUQty05 = CONVERT(NVARCHAR(10),@n_skuqty)           
       END    

  UPDATE #Result1                    
  SET SKU01   = @c_sku01,
      DESCR01 = @c_Descr01,           
      QTY01   = @c_SKUQty01,  
      SKU02   = @c_sku02,  
      DESCR02 = @c_Descr02,                 
      QTY02   = @c_SKUQty02,          
      SKU03   = @c_sku03,
      DESCR03 = @c_Descr03,            
      QTY03   = @c_SKUQty03,        
      SKU04   = @c_sku04,
      DESCR04 = @c_Descr04,           
      QTY04   = @c_SKUQty04,         
      SKU05   = @c_sku05,  
      DESCR05 = @c_Descr05,        
      QTY05   = @c_SKUQty05 
    WHERE ID = @n_CurrentPage   
          
     SET @n_intFlag = @n_intFlag + 1    
  
     IF @n_intFlag > @n_CntRec  
     BEGIN  
       BREAK;  
     END        
     END

     SELECT * FROM #RESULT1
          
END  

GO