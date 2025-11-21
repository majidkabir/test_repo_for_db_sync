SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/  
/* Stored Procedure: isp_delivery_note34_rdt                             */  
/* Creation Date: 2019-03-08                                             */  
/* Copyright: IDS                                                        */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose: WMS-8242 - CN HM Other Stories Delivery Note Report          */  
/*                                                                       */  
/* Called By: r_dw_delivery_note34_rdt                                   */  
/*                                                                       */  
/* PVCS Version: 1.1                                                     */  
/*                                                                       */  
/* Version: 5.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */  
/* 13-08-2019   CSCHONG 1.1   WMS-8242 - revised field mapping (CS01)    */  
/* 16-08-2019   WLChooi 1.2   WMS-10254 - Add M_Company (WL01)           */
/*************************************************************************/  
  
CREATE PROC [dbo].[isp_delivery_note34_rdt]   
         (  @c_Orderkey    NVARCHAR(10)  
         ,  @c_Loadkey     NVARCHAR(10)= ''  
         ,  @c_Type        NVARCHAR(1) = ''  
         )             
AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_DEFAULTS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_NoOfLine        INT  
         , @n_TotDetail       INT  
         , @n_LineNeed        INT  
         , @n_SerialNo        INT  
         , @b_debug           INT  
         , @c_DelimiterSign   NVARCHAR(1)  
         , @n_Count           int  
         , @c_GetOrdkey       NVARCHAR(20)  
         , @c_sku             NVARCHAR(20)  
         , @c_ODUDF0102       NVARCHAR(120)  
         , @n_seqno           INT  
         , @c_ColValue        NVARCHAR(20)     
         , @c_SStyle          NVARCHAR(50)  
         , @c_SColor          NVARCHAR(50)  
         , @c_SSize           NVARCHAR(50)  
         , @n_maxLine         INT  
     
    SET @n_NoOfLine = 10  
    SET @n_TotDetail= 0  
    SET @n_LineNeed = 0  
    SET @n_SerialNo = 0  
    SET @b_debug    = 0  
    SET @c_DelimiterSign = '|'  
    SET @n_Count         = 0  
    SET @n_maxLine = 10  
  
  
      CREATE TABLE #TMP_ORD31  
            (  SeqNo          INT IDENTITY (1,1)  
            ,  Orderkey       NVARCHAR(10) DEFAULT ('')  
            ,  SKU            NVARCHAR(20) DEFAULT ('')  
            ,  TotalShipped   INT          DEFAULT (0)  
            ,  OrdLinenumber  NVARCHAR(10) DEFAULT('')  
            ,  RecGrp         INT          DEFAULT(0)  
            
            )  
  
      CREATE TABLE #TMP_HDR31  
            (  SeqNo         INT              
            ,  Orderkey      NVARCHAR(10)  
            ,  Storerkey     NVARCHAR(15)  
            ,  C_Contact1    NVARCHAR(30)  
            ,  SStyle        NVARCHAR(50)  
            ,  SScolor       NVARCHAR(50)  
            ,  SSize         NVARCHAR(50)  
            ,  SKU           NVARCHAR(20)  
            ,  UnitPrice     FLOAT  
            ,  OriQty        INT  
            ,  OrderDate     DATETIME  
            ,  PQty          INT   
            ,  InvAmt        FLOAT   
            ,  RecGrp        INT                 
            ,  ExtOrdKey     NVARCHAR(50)  
            ,  M_Company     NVARCHAR(45)
            ,  ORDUDF01      NVARCHAR(30))  
  
      IF ISNULL(RTRIM(@c_Orderkey),'') = ''  
      BEGIN  
  
         INSERT INTO #TMP_ORD31  
            (      Orderkey  
                ,  SKU  
                ,  TotalShipped  
                ,  OrdLinenumber  
                ,  RecGrp  
            )  
         SELECT DISTINCT PD.Orderkey  
                        ,PD.sku  
                        ,SUM(PD.Qty)  
                        ,PD.Orderlinenumber  
                        ,(Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.Orderkey,PD.sku Asc)-1)/@n_maxLine + 1 AS recgrp  
         FROM LOADPLANDETAIL LPD WITH (NOLOCK)  
         JOIN PICKDETAIL     PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)  
         WHERE LPD.Loadkey = @c_Loadkey  
         GROUP BY PD.Orderkey ,PD.sku,PD.Orderlinenumber  
         ORDER BY   PD.Orderkey ,PD.sku  
  
      END   
      ELSE  
      BEGIN  
         INSERT INTO #TMP_ORD31  
            (  Orderkey  
            ,  SKU  
            ,  TotalShipped  
            ,  OrdLinenumber  
            ,  RecGrp  
            )  
         SELECT PD.Orderkey  
               ,PD.sku
               ,SUM(PD.Qty)  
               ,PD.Orderlinenumber  
               ,(Row_Number() OVER (PARTITION BY PD.Orderkey ORDER BY PD.Orderkey,PD.sku Asc)-1)/@n_maxLine + 1 AS recgrp  
         FROM PICKDETAIL     PD  WITH (NOLOCK)  
         WHERE PD.Orderkey = @c_Orderkey  
         GROUP BY PD.Orderkey  ,PD.sku,PD.Orderlinenumber  
   ORDER BY   PD.Orderkey ,PD.sku  
      END  
  
      INSERT INTO #TMP_HDR31  
            (   SeqNo     
             ,  Orderkey       
             ,  Storerkey      
             ,  C_Contact1     
             ,  SStyle         
             ,  SScolor         
             ,  SSize           
             ,  SKU            
             ,  UnitPrice       
             ,  OriQty          
             ,  OrderDate       
             ,  PQty         
             ,  InvAmt     
             ,  RecGrp    
             ,  ExtOrdkey 
             ,  M_Company  
             ,  ORDUDF01    
             )  
      SELECT DISTINCT   
             TMP.SeqNo  
            ,OH.orderkey  
            ,OH.Storerkey  
            ,C_Contact1 = OH.C_contact1  
            ,SStyle     = ''  
            ,SSize      = ''  
            ,SSize      = ''  
            ,SKU        = TMP.SKU  
            ,UnitPrice  = OD.UnitPrice   
            ,Oriqty     =  OD.OriginalQty  
            ,OrderDate  = ISNULL(RTRIM(OH.OrderDate),'')   
            ,ShipQty    = TMP.TotalShipped  
            ,InvAmt     = OH.InvoiceAmount  
            ,RecGrp     = TMP.Recgrp  
            ,ExtOrdkey  = OH.Externorderkey   --CS01   --WL01  
            ,M_Company  = OH.M_Company        --CS01   --WL01  
            ,ORDUDF01   = OH.UserDefine01   
      FROM #TMP_ORD31 TMP  
      JOIN ORDERS      OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)  
      JOIN STORER      ST WITH (NOLOCK) ON (OH.Storerkey = ST.Storerkey)  
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey) AND (OD.Orderlinenumber=TMP.OrdLinenumber)  
                                    and OD.sku = TMP.sku  
      GROUP BY TMP.SeqNo  
            ,OH.Orderkey  
            ,OH.Storerkey  
            ,TMP.SKU  
            ,OD.UnitPrice  
            ,OD.OriginalQty  
            ,ISNULL(RTRIM(OH.OrderDate),'')   
            ,TMP.TotalShipped  
            ,OH.InvoiceAmount  
            ,OH.C_contact1  
            ,TMP.Recgrp  
            ,OH.Externorderkey     --CS01   --WL01
            ,OH.M_Company          --CS01   --WL01  
            ,OH.UserDefine01   
      ORDER BY TMP.SeqNo  
  
    
    SET @c_SStyle = ''  
    SET @c_SColor = ''  
    SET @c_SSize  = ''  
  
    DECLARE C_orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT DISTINCT OrderKey,sku  
    FROM #TMP_ORD31 WITH (NOLOCK)  
    --WHERE Orderkey = @c_Orderkey  
  
    OPEN C_orderkey  
    FETCH NEXT FROM C_orderkey INTO @c_getOrdKey,@c_sku  
    
    WHILE (@@FETCH_STATUS=0)   
    BEGIN  
  
  
       SET @c_ODUDF0102 = ''  
       SET @c_SStyle = ''  
       SET @c_SColor = ''  
       SET @c_SSize  = ''  
         
       SELECT @c_ODUDF0102 = ISNULL(RTRIM(OD.Userdefine01),'') + ISNULL(RTRIM(OD.Userdefine02),'')  
       FROM ORDERDETAIL OD WITH (NOLOCK)  
       WHERE OD.Orderkey = @c_getOrdKey AND OD.SKU =  @c_sku 
        
       -- select @c_ODUDF0102 '@c_ODUDF0102'  
       
       DECLARE C_DelimSplit CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
       SELECT SeqNo, ColValue       
       FROM dbo.fnc_DelimSplit(@c_DelimiterSign,@c_ODUDF0102)      
       
       OPEN C_DelimSplit      
       FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue      
       
       WHILE (@@FETCH_STATUS=0)       
       BEGIN
       
          SELECT @n_Count = @n_Count + 1
          
          SELECT @c_SStyle = CASE @n_Count WHEN 1 THEN @c_ColValue ELSE @c_SStyle END      
          SELECT @c_SColor = CASE @n_Count WHEN 2 THEN @c_ColValue ELSE @c_SColor END      
          SELECT @c_SSize =   CASE @n_Count WHEN 3 THEN @c_ColValue ELSE @c_SSize END 
               
       FETCH NEXT FROM C_DelimSplit INTO @n_SeqNo, @c_ColValue      
       END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3      
       
       CLOSE C_DelimSplit      
       DEALLOCATE C_DelimSplit      
       
       UPDATE #TMP_HDR31  
       SET SStyle = @c_SStyle  
          ,SScolor = @c_SColor  
          ,SSize = @c_SSize  
       WHERE Orderkey = @c_getOrdKey  
       AND SKU  =  @c_sku  
       
       SET @n_Count = 0  
       
       FETCH NEXT FROM C_orderkey INTO @c_getOrdKey,@c_sku    
    END -- WHILE (@@FETCH_STATUS <> -1) AND @n_Continue <> 3      
    
    CLOSE C_orderkey      
    DEALLOCATE C_orderkey      
        
    SELECT    Orderkey       
           ,  Storerkey      
           ,  C_Contact1     
           ,  SStyle         
           ,  SScolor         
           ,  SSize           
           ,  SKU            
           ,  UnitPrice       
           ,  OriQty          
           ,  OrderDate       
           ,  PQty         
           ,  InvAmt    
           ,  Recgrp  
           ,  ExtOrdkey  
           ,  M_Company    --WL01
           ,  ORDUDF01  
    FROM #TMP_HDR31  
    ORDER BY SeqNo                      
  
   
    DROP TABLE #TMP_ORD31  
    DROP TABLE #TMP_HDR31  
    GOTO QUIT_SP  
  
  
QUIT_SP:    
END         

GO