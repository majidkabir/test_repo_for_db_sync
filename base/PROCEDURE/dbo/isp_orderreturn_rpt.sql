SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_OrderReturn_Rpt                                     */
/* Creation Date: 17-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5577 - CN_Shaklee_Return_Owed_Report                    */
/*        :                                                             */
/* Called By: r_dw_order_return_rpt                                     */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2021-Apr-09 CSCHONG  1.1   WMS-16024 PB-Standardize TrackingNo (CS01)*/
/************************************************************************/
CREATE PROC [dbo].[isp_OrderReturn_Rpt]
            @c_Orderkey NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
            @n_StartTCnt      INT
         ,  @n_Continue       INT 

         ,  @c_Facility       NVARCHAR(10) 
         ,  @c_Storerkey      NVARCHAR(15)

         ,  @c_PickSlipNo     NVARCHAR(10) 
         ,  @c_PickHeaderKey  NVARCHAR(10)            


   CREATE TABLE #TMP_PICK
      (  RowRef         INT      IDENTITY(1,1)  PRIMARY KEY
      ,  OrderKey       NVARCHAR(10)   NULL
      ,  Loc            NVARCHAR(10)   NULL
      ,  Sku            NVARCHAR(30)   NULL
      ,  SkuDescr       NVARCHAR(60)   NULL
      ,  ShelfLife      DATETIME       NULL
      ,  Qty            INT            NULL
      ,  OpenQty        INT            NULL
      ,  Busr1          NVARCHAR(10)   NULL
      )  

   CREATE TABLE #TMP_ORD
      (  Facility       NVARCHAR(5)    NULL
      ,  Storerkey      NVARCHAR(15)   NULL
      ,  Loadkey        NVARCHAR(10)   NULL
      ,  OrderKey       NVARCHAR(10)   NOT NULL PRIMARY KEY
      ,  OrderNo        NVARCHAR(30)   NULL
      ,  SaleNo         NVARCHAR(45)   NULL
      ,  DestCity       NVARCHAR(95)   NULL
      ,  C_Address      NVARCHAR(190)  NULL
      ,  MobileTel      NVARCHAR(40)   NULL
      ,  Contact1       NVARCHAR(30)   NULL
      ,  OrderDate      DATETIME       NULL
      ,  Remarks        NVARCHAR(1000) NULL
      ,  ExpressNo      NVARCHAR(20)   NULL 
      ,  [Type]         NVARCHAR(10)   NULL    
      ,  OrderType      NVARCHAR(10)   NULL
      ,  TotalOrderQty  INT            NULL
      ,  PrintList      NVARCHAR(30)   NULL
      )  

   SET @n_Continue = 1
   SET @c_Facility = ''

   --SELECT @c_Facility = ISNULL(RTRIM(CL.Short),'')
   --FROM CODELKUP CL WITH (NOLOCK)
   --WHERE CL.ListName = 'SHAKLEEFAC'
   --AND   CL.Code = 'StorageName'


   INSERT INTO #TMP_PICK  
      (
         OrderKey       
      ,  Loc             
      ,  Sku             
      ,  SkuDescr        
      ,  ShelfLife       
      ,  Qty             
      ,  OpenQty
      ,  Busr1         
      )
   SELECT Orderkey = PD.OrderKey       
      ,  Loc       = PD.Loc             
      ,  Sku       = PD.Sku             
      ,  SkuDescr  = ISNULL(RTRIM(SKU.Descr),'')       
      ,  ShelfLife = LA.Lottable04       
      ,  Qty = SUM(PD.Qty)             
      ,  OpenQty   = OD.OpenQty 
      ,  Busr1     = CASE WHEN ISNULL(RTRIM(SKU.Busr1),'') = N'╩╟' 
                          THEN ISNULL(RTRIM(SKU.Busr1),'') 
                          ELSE '' 
                          END
   FROM ORDERS       OH WITH (NOLOCK)
   JOIN ORDERDETAIL  OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN PICKDETAIL   PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                      AND(OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                      AND(PD.Sku = SKU.Sku)
   JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   WHERE OH.Orderkey = @c_Orderkey
   GROUP BY
         PD.OrderKey       
      ,  PD.Loc             
      ,  PD.Sku             
      ,  ISNULL(RTRIM(SKU.Descr),'')       
      ,  LA.Lottable04      
      ,  OD.OpenQty 
      ,  ISNULL(RTRIM(SKU.Busr1),'') 

   INSERT INTO #TMP_ORD 
      (
         Facility        
      ,  Storerkey       
      ,  Loadkey         
      ,  OrderKey        
      ,  OrderNo         
      ,  SaleNo          
      ,  DestCity        
      ,  C_Address       
      ,  MobileTel       
      ,  Contact1        
      ,  OrderDate      
      ,  Remarks         
      ,  ExpressNo       
      ,  [Type]          
      ,  OrderType 
      ,  TotalOrderQty      
      ,  PrintList       
      )  
   SELECT DISTINCT 
          OH.Facility    
         ,Storerkey  = OH.Storerkey
         ,Loadkey    = OH.Loadkey
         ,LFWMSNo    = OH.Orderkey  
         ,OrderNo    = ISNULL(RTRIM(OH.ExternOrderkey),'')
         ,SaleNo     = ISNULL(RTRIM(OH.M_Company),'')
         ,DestCity   = ISNULL(RTRIM(OH.C_State),'') + ' ' + ISNULL(RTRIM(OH.C_City),'')
         ,C_Address  = ISNULL(RTRIM(OH.C_Address1),'') + ' ' + ISNULL(RTRIM(OH.C_Address2),'')
                     + ISNULL(RTRIM(OH.C_Address3),'') + ' ' + ISNULL(RTRIM(OH.C_Address4),'')
         ,MobileTel  = ISNULL(RTRIM(OH.C_Phone1),'') + ' ' + ISNULL(RTRIM(OH.C_Phone2),'')
         ,Contact    = ISNULL(RTRIM(OH.C_Contact1),'')
         ,OrderDate  = OH.OrderDate
         ,Remarks    = ISNULL(RTRIM(OH.Notes),'')
         ,ExpressNo  = ISNULL(RTRIM(OH.TrackingNo),'')--ISNULL(RTRIM(OH.UserDefine04),'')   --CS01
         ,[Type]     = OH.Type
         ,OrderType  = N'╚▒╗⌡▓╣╖ó╢⌐╡Ñ' 
         ,TotalOrderQty = 0
         ,PrintList  = ''         
   FROM #TMP_PICK TMP
   JOIN ORDERS   OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)

   UPDATE #TMP_ORD 
   SET TotalOrderQty = (SELECT SUM(PICK.Qty) 
                        FROM #TMP_PICK PICK
                        WHERE PICK.Orderkey = #TMP_ORD.Orderkey)


QUIT_SP:
   SELECT   SortBy  = ROW_NUMBER() OVER (ORDER BY OH.Orderkey
                                                , PK.Loc
                                                , PK.Sku
                                        )
         ,  PageGroup = RANK() OVER (ORDER BY OH.Orderkey) 
         ,  PrintTime = GETDATE()  
         ,  OH.Facility           
         ,  OH.Storerkey          
         ,  OH.Loadkey            
         ,  OH.OrderKey           
         ,  OH.OrderNo            
         ,  OH.SaleNo             
         ,  OH.DestCity           
         ,  OH.C_Address          
         ,  OH.MobileTel          
         ,  OH.Contact1           
         ,  OH.OrderDate          
         ,  OH.Remarks            
         ,  OH.ExpressNo          
         ,  OH.OrderType
         ,  OH.TotalOrderQty          
         ,  OH.PrintList  
         ,  RowNo = ROW_NUMBER() OVER (PARTITION BY OH.Orderkey
                                       ORDER BY OH.Orderkey
                                              , PK.Loc
                                              , PK.Sku
                                        )
         ,  PK.Loc             
         ,  PK.Sku             
         ,  PK.SkuDescr        
         ,  PK.ShelfLife       
         ,  Qty = SUM(PK.Qty) 
         ,  PK.Busr1 
   FROM #TMP_PICK PK
   JOIN #TMP_ORD  OH ON (PK.Orderkey = OH.OrderKey)
   GROUP BY OH.Facility           
         ,  OH.Storerkey          
         ,  OH.Loadkey            
         ,  OH.OrderKey           
         ,  OH.OrderNo            
         ,  OH.SaleNo             
         ,  OH.DestCity           
         ,  OH.C_Address          
         ,  OH.MobileTel          
         ,  OH.Contact1           
         ,  OH.OrderDate          
         ,  OH.Remarks            
         ,  OH.ExpressNo          
         ,  OH.[Type]             
         ,  OH.OrderType 
         ,  OH.TotalOrderQty          
         ,  OH.PrintList  
         ,  PK.Loc             
         ,  PK.Sku             
         ,  PK.SkuDescr        
         ,  PK.ShelfLife
         ,  PK.Busr1 
 
   DROP TABLE #TMP_ORD
   DROP TABLE #TMP_PICK

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO