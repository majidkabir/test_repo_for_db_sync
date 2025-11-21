SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Stored Proc: isp_delivery_note30_rdt                                 */    
/* Creation Date: 16-AUG-2019                                           */    
/* Copyright: LF Logistics                                              */    
/* Written by:                                                          */    
/*                                                                      */    
/* Purpose: WMS-10264 Fanatics ECOM Delivery Note                       */    
/*        : Copy from isp_delivery_note30_rdt                           */    
/*                                                                      */    
/* Called By: r_dw_delivery_note30_rdt                                  */    
/*          :                                                           */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 7.0                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date        Author   Ver   Purposes                                  */    
/* 21-NOV-2022 Mingle   1.1   WMS-21161 Add logic(ML01)                 */    
/************************************************************************/    
CREATE PROC [dbo].[isp_delivery_note30_rdt]    
      --   @c_Orderkey    NVARCHAR(10)     
      --,  @c_Loadkey     NVARCHAR(10)     
      --,  @c_Type        NCHAR(1) = ''    
           --@c_Storerkey     NVARCHAR(15)    
        --,      
        @c_Pickslipno    NVARCHAR(10)    
        --,  @c_StartCartonNo NVARCHAR(10)    
        --,  @c_EndCartonNo   NVARCHAR(10)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
   DECLARE @n_PageGroup       INT    
         , @n_NoOfLine        INT    
         , @n_NoOfLinePerPage INT    
         , @n_MaxSortID       INT     
                
         , @CUR_SKULINE       CURSOR    
    
         , @c_Orderkey    NVARCHAR(10)     
         , @c_Loadkey     NVARCHAR(10)     
         , @c_Type        NCHAR(1) = '' --Type = '1' - Single, Type = 2 - Multi    
			, @c_DIOrderkey   NVARCHAR(10) --ML01     
			, @c_OrderLineNumber    NVARCHAR(5)  --ML01     
			, @c_DISku       NVARCHAR(20)  --ML01     
			, @c_DIData       NVARCHAR(4000) --ML01     
			, @c_clshort         NVARCHAR(1)    
    
   --SET @n_NoOfLinePerPage = 34   
   SET @n_NoOfLinePerPage = 8	--ML01     
    
   CREATE TABLE #TMP_DN    
         (  RowRef         INT      IDENTITY(1,1)  PRIMARY KEY    
         ,  SortBy         INT    
         ,  PageGroup      INT    
         ,  L_Logo         NVARCHAR(30)   NULL      
         ,  L_DN           NVARCHAR(30)   NULL      
         ,  L_Customer     NVARCHAR(30)   NULL      
         ,  L_Address      NVARCHAR(30)   NULL      
         ,  L_OrderNo      NVARCHAR(30)   NULL      
         ,  L_OrderDate    NVARCHAR(30)   NULL      
         ,  L_Sku          NVARCHAR(30)   NULL      
         ,  L_SkuDesc      NVARCHAR(30)   NULL      
         ,  L_UnitPrice    NVARCHAR(30)   NULL      
         ,  L_Qty          NVARCHAR(30)   NULL      
         ,  L_TotalPaid    NVARCHAR(30)   NULL      
         ,  L_Notes1       NVARCHAR(250)  NULL      
         ,  L_Notes2       NVARCHAR(500)  NULL      
         ,  L_SubTotal     NVARCHAR(30)   NULL      
         ,  L_Discount     NVARCHAR(30)   NULL      
         ,  L_Postage      NVARCHAR(30)   NULL      
         ,  L_Total        NVARCHAR(30)   NULL      
         ,  L_VAT          NVARCHAR(30)   NULL      
         ,  L_SiteURL      NVARCHAR(255)  NULL    --WL01    
         ,  Storerkey      NVARCHAR(15)   NULL    
         ,  Loadkey        NVARCHAR(10)   NULL    
         ,  OrderKey       NVARCHAR(10)   NULL    
         ,  ExternOrderkey NVARCHAR(30)   NULL    
         ,  OrderDate      DATETIME      NULL    
         ,  C_Contact1     NVARCHAR(30)   NULL    
         ,  C_Address      NVARCHAR(190)  NULL    
         ,  PostageAmount  FLOAT          NULL    
         ,  Postage        NVARCHAR(30)   NULL    
         ,  Packing        NVARCHAR(30)   NULL    
         ,  InvoiceAmount  FLOAT          NULL    
         ,  TotalPaid      NVARCHAR(30)   NULL     
         ,  Total          NVARCHAR(30)   NULL    
         ,  SubTotal       NVARCHAR(30)   NULL       
         ,  Sku            NVARCHAR(20)   NULL    
         ,  SkuDescr       NVARCHAR(60)   NULL    
         ,  UnitPrice      FLOAT          NULL    
         ,  Qty            INT            NULL     
		   ,  DIData         NVARCHAR(4000) NULL --ML01     
			,  showDIData     NVARCHAR(1)    NULL --ML01     
         )      
    
   CREATE TABLE #TMP_ORDERS     
         (      
            Orderkey       NVARCHAR(10)   NOT NULL PRIMARY KEY    
         ,  Loadkey        NVARCHAR(10)   NULL DEFAULT ('')    
         )    
    
   CREATE TABLE #TMP_PICK    
         (  Rowref            INT      IDENTITY(1,1)  PRIMARY KEY     
         ,  SortID            INT        
         ,  PageGroup         INT             
         ,  Orderkey          NVARCHAR(10)   NULL     
         ,  Storerkey         NVARCHAR(15)   NULL        
         ,  Sku               NVARCHAR(20)   NULL    
         ,  SkuDescr          NVARCHAR(60)   NULL    
         ,  UnitPrice         FLOAT          NULL    
         ,  Qty               INT            NULL      
         ,  LogicalLocation   NVARCHAR(10)   NULL     
         ,  Loc               NVARCHAR(10)   NULL       
         )    
    
   SELECT @c_Type = CASE WHEN OH.ECOM_SINGLE_FLAG = 'S' THEN '1'    
                         WHEN OH.ECOM_SINGLE_FLAG = 'M' THEN '2'    
                         ELSE '' END    
   FROM ORDERS OH (NOLOCK)    
   JOIN PACKHEADER PH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY    
   WHERE PH.Pickslipno = @c_Pickslipno --AND PH.Storerkey = @c_Storerkey    
    
   --IF ISNULL(RTRIM(@c_Orderkey),'') = ''    
   --BEGIN    
   --   IF ISNULL(RTRIM(@c_Type),'') = ''    
   --   BEGIN    
   --      GOTO QUIT_SP    
   --   END    
     
    
   IF @c_Type = '1'    
   BEGIN    
      INSERT INTO #TMP_ORDERS    
         (      
            Orderkey    
         ,  Loadkey     
         )     
      SELECT DISTINCT    
            LPD.Orderkey    
         ,  LPD.Loadkey    
      FROM LOADPLAN LP WITH (NOLOCK)    
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.LoadKey = LPD.Loadkey)    
      JOIN ORDERS OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)    
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY    
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno    
      WHERE PH.Pickslipno = @c_Pickslipno        
      --AND PH.Storerkey = @c_Storerkey       
      --AND PD.CartonNo BETWEEN CAST(@c_StartCartonNo AS INT) AND    
                              --CAST(@c_EndCartonNo AS INT)    
      AND OH.ECOM_SINGLE_FLAG = 'S'    
   END    
       
   IF @c_Type = '2'    
   BEGIN    
      INSERT INTO #TMP_ORDERS    
         (      
            Orderkey    
         ,  Loadkey     
         )     
      SELECT DISTINCT        
            LPD.Orderkey        
         ,  LPD.Loadkey        
      FROM LOADPLAN LP WITH (NOLOCK)        
      JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.LoadKey = LPD.Loadkey)        
      JOIN ORDERS OH WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)        
      JOIN PACKHEADER PH WITH (NOLOCK) ON PH.ORDERKEY = OH.ORDERKEY    
      JOIN PACKDETAIL PD WITH (NOLOCK) ON PD.Pickslipno = PH.Pickslipno    
      WHERE PH.Pickslipno = @c_Pickslipno        
      --AND PH.Storerkey = @c_Storerkey       
      --AND PD.CartonNo BETWEEN CAST(@c_StartCartonNo AS INT) AND    
                        --CAST(@c_EndCartonNo AS INT)    
      AND OH.ECOM_SINGLE_FLAG = 'M'    
   END    
    
       
   --SELECT * FROM #TMP_ORDERS    
   --GOTO QUIT_SP    
    
   INSERT INTO #TMP_PICK    
         (      
            SortID    
         ,  PageGroup    
         ,  Orderkey         
         ,  Storerkey         
         ,  Sku      
         ,  SkuDescr               
         ,  UnitPrice           
         ,  Qty    
         ,  LogicalLocation    
         ,  Loc       
         )    
   SELECT  SortID = ROW_NUMBER() OVER (ORDER BY CASE WHEN @c_Type = '1' THEN '' ELSE OD.Orderkey END    
                                             ,  ISNULL(RTRIM(LOC.LogicalLocation),'')    
                                             ,  LOC.Loc    
                                             ,  CASE WHEN @c_Type = '1' THEN '' ELSE OD.Storerkey  END     
                                             ,  CASE WHEN @c_Type = '1' THEN '' ELSE RTRIM(OD.Sku) END     
                                             ,  OD.Orderkey    
                                       )    
         , PageGroup= RANK() OVER ( ORDER BY OD.Orderkey )    
         , OD.Orderkey    
         , OD.Storerkey    
         , Sku    = RTRIM(OD.Sku)    
         , Descr  = ISNULL(RTRIM(SKU.Descr),'')    
         , Price  = ISNULL(OD.UnitPrice, 0.00)     
         , Qty    = ISNULL(SUM(PD.Qty),0)    
         , LogicalLocation = ISNULL(RTRIM(LOC.LogicalLocation),'')    
         , LOC.Loc      
   FROM #TMP_ORDERS OH    
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)    
   JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)    
                                     AND(OD.OrderLineNumber = PD.OrderLineNumber)    
   JOIN LOC       LOC  WITH (NOLOCK) ON (PD.Loc = LOC.Loc)    
   JOIN SKU       SKU  WITH (NOLOCK) ON (OD.Storerkey= SKU.Storerkey)    
                                     AND(OD.Sku = SKU.Sku)    
   WHERE PD.Qty > 0    
   GROUP BY OD.Orderkey    
         ,  OD.Storerkey    
         ,  RTRIM(OD.Sku)    
         ,  ISNULL(RTRIM(SKU.Descr),'')    
         ,  ISNULL(OD.UnitPrice, 0.00)     
         ,  ISNULL(RTRIM(LOC.LogicalLocation),'')    
         ,  LOC.Loc        
    
   SET @CUR_SKULINE = CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT PD.PageGroup    
         ,PD.Orderkey    
         ,NoOfLine = COUNT(1)    
         ,MaxSortID = MAX(SortID)    
   FROM #TMP_PICK PD    
   GROUP BY PD.PageGroup    
         ,  PD.Orderkey    
     
   OPEN @CUR_SKULINE    
    
   FETCH NEXT FROM @CUR_SKULINE INTO @n_pageGroup, @c_Orderkey, @n_NoOfLine, @n_MaxSortID    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      SET @n_NoOfLine = @n_NoOfLine - ( FLOOR(@n_NoOfLine / @n_NoOfLinePerPage) * @n_NoOfLinePerPage )    
    
      WHILE @n_NoOfLine < @n_NoOfLinePerPage    
      BEGIN    
         INSERT INTO #TMP_PICK    
               (      
                  SortID    
               ,  PageGroup    
               ,  Orderkey         
               )    
         VALUES(      
                  @n_MaxSortID    
               ,  @n_PageGroup    
               ,  @c_Orderkey        
               )    
         SET @n_NoOfLine = @n_NoOfLine + 1    
      END    
      FETCH NEXT FROM @CUR_SKULINE INTO @n_pageGroup, @c_Orderkey, @n_NoOfLine, @n_MaxSortID    
   END    
    
   CLOSE @CUR_SKULINE    
   DEALLOCATE @CUR_SKULINE     
    
 ----START ML01    
 --DECLARE CUR_DOCINFO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
 --SELECT DISTINCT ORDERKEY,ORDERLINENUMBER,SKU    
 --FROM #TMP_PICK(NOLOCK)    
 --ORDER BY ORDERKEY,ORDERLINENUMBER,SKU    
    
    
 --OPEN CUR_DOCINFO      
    
 --  FETCH NEXT FROM CUR_DOCINFO INTO @c_DIOrderkey, @c_OrderLineNumber, @c_DISku    
 --  WHILE @@FETCH_STATUS <> -1    
 --  BEGIN    
 --     SELECT @c_DIData = Data    
 -- FROM DOCINFO(NOLOCK)     
 -- WHERE Key1 = @c_DIOrderkey    
 -- --AND Key2 = @c_OrderLineNumber    
 -- AND Key3 = @c_DISku    
 -- AND TableName = 'OrderDetail'    
    
 -- --SELECT @c_DIOrderkey, @c_OrderLineNumber, @c_DISku,@c_DIData    
      
 --  FETCH NEXT FROM CUR_DOCINFO INTO @c_DIOrderkey, @c_OrderLineNumber, @c_DISku    
 --END    
    
 --  CLOSE CUR_DOCINFO    
 --  DEALLOCATE CUR_DOCINFO     
 ----END ML01    
    
     
    
   INSERT INTO #TMP_DN    
         (    
            SortBy    
         ,  PageGroup    
         ,  L_Logo          
         ,  L_DN            
         ,  L_Customer      
         ,  L_Address       
         ,  L_OrderNo       
         ,  L_OrderDate     
         ,  L_Sku           
         ,  L_SkuDesc       
         ,  L_UnitPrice     
         ,  L_Qty           
         ,  L_TotalPaid     
         ,  L_Notes1        
         ,  L_Notes2        
         ,  L_SubTotal      
         ,  L_Discount      
         ,  L_Postage       
         ,  L_Total         
         ,  L_VAT           
         ,  L_SiteURL      
         ,  Storerkey     
         ,  Loadkey    
         ,  Orderkey            
         ,  ExternOrderkey     
         ,  OrderDate          
         ,  C_Contact1          
         ,  C_Address      
         ,  PostageAmount         
         ,  Postage             
         ,  Packing     
         ,  InvoiceAmount            
         ,  TotalPaid     
         ,  Total       
         ,  SubTotal       
         ,  Sku      
         ,  SkuDescr               
         ,  UnitPrice           
         ,  Qty    
			,  DIData --ML01     
			,  showDIData --ML01    
         )      
   SELECT  SortBy  = ROW_NUMBER() OVER (ORDER BY PD.SortID    
                                                ,PD.RowRef    
                                                ,PD.PageGroup    
                                     )    
         , PageGroup= PD.PageGroup--RANK() OVER (  ORDER BY OH.Orderkey    
                                  --  )    
         , L_Logo       = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '01' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.C_Company),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE ''    
                                           END),'')    
         , L_DN         = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '02' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Delivery Note'    
                                           END),'')    
         , L_Customer   = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '03' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Customer Details'    
                                           END),'')    
         , L_Address    = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '04' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Delivery Address'    
                                           END),'')    
         , L_OrderNo    = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '05' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Order No:'    
                                           END),'')    
         , L_OrderDate  = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '06' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Order Date:'    
                                           END),'')    
         , L_Sku        = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '07' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Product Code'    
                                           END),'')    
         , L_SkuDesc    = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '08' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Description'    
                                           END),'')    
         , L_UnitPrice  = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '09' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                          THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Unit Price'    
                                           END),'')    
         , L_Qty        = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '10' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Qty'    
                                           END),'')    
         , L_TotalPaid  = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '11' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Total Paid'    
                                           END),'')    
         , L_Notes1     = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '12' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Thank you for ordering from us.'    
                                           END),'')    
         , L_Notes2     = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '13' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'We are committed to total satisfaction for all our customers. '    
                                               +'For any queries surrounding your order please visit our online '    
                                               +'help section, or should you like to return any items please '    
                                               +'view the refunds & returns section of our website in order '    
                                               +'to view our full terms and conditions.'    
                                           END),'')    
         , L_SubTotal   = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '14' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Sub-total:'    
                                           END),'')    
         , L_Discount   = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '15' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Order Discount:'    
                                           END),'')    
         , L_Postage    = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '16' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Postage & Packing:'    
                                           END),'')    
         , L_Total      = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '17' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'Total:'    
                                           END),'')    
         , L_VAT        = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '18' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.M_ISOCntryCode),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                                           ELSE 'VAT Element:'    
                                           END),'')    
         , L_SiteURL    = ISNULL(MAX(CASE WHEN ISNULL(RTRIM(CL.UDF01),'') = '19' AND ISNULL(RTRIM(CL.UDF02),'') = ISNULL(RTRIM(OH.C_Company),'')    
                                           THEN ISNULL(RTRIM(CL.Notes),'')    
                      ELSE '<site url>'    
                                           END),'')    
         , OH.Storerkey    
         , OH.Loadkey    
         , OH.Orderkey    
         , ExternOrderkey = ISNULL(RTRIM(OH.ExternOrderkey),'')    
         , OH.OrderDate     
         , C_Contact1= ISNULL(RTRIM(OH.C_Contact1),'') + ' '      
         , C_Address = ISNULL(RTRIM(OH.C_State),'') + ' '      --(Wan01)    
                     + ISNULL(RTRIM(OH.C_City),'') + ' '       --(Wan01)    
                     + ISNULL(RTRIM(OH.C_Address1),'') + ' '    
                     + ISNULL(RTRIM(OH.C_Address2),'') + ' '        
                     --+ ISNULL(RTRIM(OH.C_Address3),'') + ' ' --(Wan01)        
                     --+ ISNULL(RTRIM(OH.C_Address4),'')       --(Wan01)    
         , PostageAmount = CASE WHEN ISNUMERIC( ISNULL(RTRIM(OH.UserDefine02),'') ) = 1     
                                THEN CONVERT( FLOAT, ISNULL(RTRIM(OH.UserDefine02),'') )    
                                ELSE 0.00    
                                END     
         , Postage   = '0.00'    
         , Packing   = ISNULL(RTRIM(OH.m_Country),'')    
         , InvoiceAmount =  ISNULL(OH.InvoiceAmount,0.00)    
         , TotalPaid     =  '0.00'    
         , Total         =  '0.00'    
         , SubTotal      =  '0.00'      
         , Sku    = PD.Sku    
         , Descr  = PD.SkuDescr     
         , Price  = PD.UnitPrice      
         , Qty    = PD.Qty    
			, DIData = (SELECT REPLACE(CAST(STUFF((SELECT DISTINCT '@' + RTRIM(data)     
							FROM docinfo(NOLOCK)     
							WHERE docinfo.key1 = oh.orderkey AND docinfo.key3 = pd.sku AND docinfo.storerkey = oh.storerkey AND docinfo.tablename = 'orderdetail'    
                     ORDER BY 1 FOR XML PATH('')),1,1,'' ) AS NVARCHAR(255)),'@',CHAR(13))) --ML01     
			, showdidata = ISNULL(CL1.Short,'') --ML01    
   FROM #TMP_ORDERS LP    
   JOIN ORDERS      OH WITH (NOLOCK) ON (LP.Orderkey = OH.Orderkey)    
   JOIN #TMP_PICK   PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)    
   LEFT JOIN CODELKUP  CL   WITH (NOLOCK) ON (CL.ListName = 'FJDN')    
                                          AND(CL.Storerkey= OH.Storerkey)    
   LEFT JOIN CODELKUP  CL1   WITH (NOLOCK) ON (CL1.ListName = 'REPORTCFG')    
                                          AND(CL1.Storerkey = OH.Storerkey)    
              AND(CL1.Code = 'showdocinfo')    
              AND(CL1.Code2 = OH.Facility)    
              AND(CL1.Long = 'r_dw_delivery_note30_rdt')    
   --WHERE PD.Qty > 0    
   GROUP BY PD.SortID    
         ,  PD.PageGroup    
         ,  PD.RowRef    
         ,  OH.Storerkey    
         ,  OH.Loadkey    
         ,  OH.Orderkey    
         ,  ISNULL(RTRIM(OH.ExternOrderkey),'')    
         ,  OH.OrderDate     
         ,  ISNULL(RTRIM(OH.C_Contact1),'')    
         ,  ISNULL(RTRIM(OH.C_State),'')     --(Wan01)    
         ,  ISNULL(RTRIM(OH.C_City),'')      --(Wan01)    
         ,  ISNULL(RTRIM(OH.C_Address1),'')      
         ,  ISNULL(RTRIM(OH.C_Address2),'')        
         --,  ISNULL(RTRIM(OH.C_Address3),'')--(Wan01)       
         --,  ISNULL(RTRIM(OH.C_Address4),'')--(Wan01)    
         ,  ISNULL(RTRIM(OH.UserDefine02),'')    
         ,  ISNULL(RTRIM(OH.m_Country),'')    
         ,  ISNULL(OH.InvoiceAmount,0.00)    
         ,  ISNULL(RTRIM(OH.C_Company),'')    
         ,  ISNULL(RTRIM(OH.C_ISOCntryCode),'')    
         ,  PD.Sku    
         ,  PD.SkuDescr     
         ,  PD.UnitPrice    
         ,  PD.Qty     
         ,  PD.LogicalLocation     
         ,  PD.Loc    
		   ,  ISNULL(CL1.Short,'') --ML01    
    
   UPDATE #TMP_DN    
      SET TotalPaid = CASE WHEN Qty IS NULL     
                           THEN ''    
                           WHEN (Qty * UnitPrice) - FLOOR(Qty * UnitPrice) = 0    
                           THEN FORMAT((Qty * UnitPrice), '#,###,###,##0') + ' ' + Packing    
                           ELSE FORMAT((Qty * UnitPrice), '##,###,##0.00') + ' ' + Packing    
                           END    
         ,  Postage = CASE WHEN PostageAmount - FLOOR(PostageAmount) = 0    
                           THEN FORMAT(PostageAmount, '#,###,###,##0') + ' ' + Packing    
                           ELSE FORMAT(PostageAmount, '##,###,##0.00') + ' ' + Packing    
                           END    
         ,  SubTotal= CASE WHEN InvoiceAmount - FLOOR(InvoiceAmount) = 0    
                           THEN FORMAT(InvoiceAmount, '#,###,###,##0') + ' ' + Packing    
                           ELSE FORMAT(InvoiceAmount, '##,###,##0.00') + ' ' + Packing    
                           END    
         ,  Total   = CASE WHEN InvoiceAmount - FLOOR(InvoiceAmount) = 0    
                           THEN FORMAT(InvoiceAmount, '#,###,###,##0') + ' ' + Packing    
                           ELSE FORMAT(InvoiceAmount, '##,###,##0.00') + ' ' + Packing    
                           END    
    
 --SELECT @c_clshort = showDIData,    
 --   @c_DIData  = DIData    
 --FROM #TMP_DN    
    
 --IF(@c_clshort = 'Y' AND @c_DIData <> '')    
 --BEGIN    
 -- SET @n_NoOfLinePerPage = '15'    
 --END    
 --ELSE    
 --BEGIN    
 -- SET @n_NoOfLinePerPage = '34'    
 --END    
    
 --SELECT @n_NoOfLinePerPage    
     
QUIT_SP:    
   SELECT   SortBy    
         ,  PageGroup    
         ,  L_Logo             
         ,  L_DN               
         ,  L_Customer         
         ,  L_Address          
         ,  L_OrderNo          
         ,  L_OrderDate        
         ,  L_Sku              
         ,  L_SkuDesc          
         ,  L_UnitPrice        
         ,  L_Qty              
         ,  L_TotalPaid        
         ,  L_Notes1           
         ,  L_Notes2           
         ,  L_SubTotal         
         ,  L_Discount         
         ,  L_Postage          
         ,  L_Total            
         ,  L_VAT              
         ,  L_SiteURL     
         ,  Storerkey         
         ,  Loadkey    
         ,  Orderkey            
         ,  ExternOrderkey     
         ,  OrderDate          
         ,  C_Contact1          
         ,  C_Address           
         ,  Postage             
         ,  Packing     
         ,  InvoiceAmount            
         ,  TotalPaid      
         ,  Total     
         ,  SubTotal        
         ,  Sku      
         ,  SkuDescr               
         ,  UnitPrice = CASE WHEN UnitPrice - FLOOR(UnitPrice) = 0     
                             THEN FORMAT(UnitPrice, '#,###,###,##0')    
                             ELSE FORMAT(UnitPrice, '##,###,##0.00')    
                             END        
         ,  Qty    
			,  DIData --ML01    
			,  showDIData --ML01     
   FROM #TMP_DN    
   ORDER BY SortBy    
    
   DROP TABLE #TMP_DN    
   DROP TABLE #TMP_ORDERS    
   DROP TABLE #TMP_PICK    
END -- procedure 

GO