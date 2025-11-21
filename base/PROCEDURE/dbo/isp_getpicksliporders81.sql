SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetPickSlipOrders81                                 */
/* Creation Date: 17-JUL-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5575 - CN_Shaklee_Pickup_Summary_Report                 */
/*        :                                                             */
/* Called By: r_dw_print_pickorder81                                    */
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
CREATE PROC [dbo].[isp_GetPickSlipOrders81]
            @c_Loadkey        NVARCHAR(10) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
            @n_StartTCnt      INT
         ,  @n_Continue       INT 
         ,  @b_Success        INT
         ,  @n_Err            INT
         ,  @c_Errmsg         NVARCHAR(250)

         ,  @n_OrderCnt       INT
         ,  @c_Facility       NVARCHAR(10) 
         ,  @c_Storerkey      NVARCHAR(15)
         ,  @c_Orderkey       NVARCHAR(10) 
         ,  @c_PickSlipNo     NVARCHAR(10) 
         ,  @c_PickHeaderKey  NVARCHAR(10)            

         ,  @cur_ORD          CURSOR

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
      ,  PickSlipNo     NVARCHAR(10)   NULL
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
      ,  Busr1     = CASE WHEN ISNULL(RTRIM(SKU.Busr1),'') = 'Y' 
                          THEN N'ÊÇ'  
                          ELSE '' 
                          END
   FROM LOADPLAN        LP WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
   JOIN ORDERDETAIL     OD WITH (NOLOCK) ON (LPD.Orderkey = OD.Orderkey)
   JOIN PICKDETAIL      PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)
                                         AND(OD.OrderLineNumber = PD.OrderLineNumber)
   JOIN SKU            SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                         AND(PD.Sku = SKU.Sku)
   JOIN LOTATTRIBUTE    LA WITH (NOLOCK) ON (PD.Lot = LA.Lot)
   WHERE LP.Loadkey = @c_Loadkey
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
      ,  PickSlipNo     
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
          Facility   = OH.Facility
         ,Storerkey  = OH.Storerkey
         ,PickSlipNo = ISNULL(RTRIM(PH.PickHeaderKey),'')
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
         ,ExpressNo  = ISNULL(RTRIM(OH.TrackingNo),'') --ISNULL(RTRIM(OH.UserDefine04),'')   --CS01
         ,[Type]     = OH.Type
        ,OrderType  = CASE WHEN OH.Type = 'Normal'  
                            THEN N'接口对接订单'    
                            WHEN OH.Type = 'TF'  
                            THEN N'调拨单'     
                            WHEN OH.Type = 'APY'  
                            THEN N'申请单'     
                            WHEN OH.Type = 'Add'  
                            THEN N'缺货补发订单'   
                            END  
         ,TotalOrderQty = 0
         ,PrintList  = ''         
   FROM #TMP_PICK TMP
   JOIN ORDERS   OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey)
   LEFT JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Orderkey = PH.Orderkey)

   UPDATE ORD
       SET PrintList = CASE WHEN ORD.[Type] = 'Normal'  
                           THEN N'清单打印：01购物清单' + CHAR(13) +   
                                N'        02欠货单'  
                           WHEN ORD.[Type] = 'Add'    
                           THEN N'清单打印：01还欠单' + CHAR(13) +   
                                N'        02欠货单'  
                           ELSE ''  
                           END  
   FROM #TMP_ORD  ORD
   JOIN #TMP_PICK PICK  ON (ORD.Orderkey = PICK.Orderkey)
   WHERE PICK.OpenQty > PICK.Qty

   UPDATE ORD
      SET PrintList =CASE WHEN ORD.[Type] = 'Normal'  
             THEN N'清单打印：01购物清单'   
                           WHEN ORD.[Type] = 'Add'    
                           THEN N'清单打印：01还欠单'  
                           ELSE ''  
                           END  
   FROM #TMP_ORD  ORD
   JOIN #TMP_PICK PICK  ON (ORD.Orderkey = PICK.Orderkey)
   WHERE PICK.OpenQty = PICK.Qty
   AND   ORD.[Type] IN ( 'Normal', 'Add' )
   AND   ORD.PrintList  = '' 

   UPDATE #TMP_ORD 
   SET TotalOrderQty = (SELECT SUM(PICK.Qty) 
                        FROM #TMP_PICK PICK
                        WHERE PICK.Orderkey = #TMP_ORD.Orderkey)

   SET @n_OrderCnt = 0

   SELECT @n_OrderCnt = COUNT(1)
   FROM #TMP_ORD OH
   WHERE OH.PickSlipNo = ''

   IF @n_OrderCnt = 0 
   BEGIN
      GOTO QUIT_SP
   END

   -- INSERT INTO PICKHEADER
   BEGIN TRAN
   EXECUTE dbo.nspg_GetKey   
            @KeyName    = 'PICKSLIP'
         ,  @fieldlength= 9
         ,  @keystring  = @c_PickHeaderKey   OUTPUT
         ,  @b_Success  = @b_Success         OUTPUT
         ,  @n_Err      = @n_Err             OUTPUT
         ,  @c_Errmsg   = @c_Errmsg          OUTPUT 
         ,  @n_batch    = @n_OrderCnt  

   IF @b_Success <> 1 
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 89010
      SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Executing nspg_GetKey. (isp_GetPickSlipOrders81)'
      GOTO QUIT_SP
   END

   SET @c_PickSlipNo = 'P' + @c_PickHeaderKey

   SET @cur_ORD = CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT OH.Orderkey   
         ,OH.Storerkey
   FROM #TMP_ORD OH
   WHERE OH.PickSlipNo = ''

   OPEN @cur_ORD
   
   FETCH NEXT FROM @cur_ORD INTO @c_Orderkey, @c_Storerkey
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      BEGIN TRAN
      SET @c_PickSlipNo = 'P' + @c_PickHeaderKey
      
      INSERT INTO PICKHEADER 
            (  PickHeaderKey
            ,  Storerkey
            ,  ExternOrderKey
            ,  Orderkey
            ,  PickType
            ,  Zone
            ,  Loadkey
            )    
      VALUES(  @c_Pickslipno 
            ,  @c_Storerkey
            ,  @c_Loadkey
            ,  @c_Orderkey
            ,  '0'
            ,  '3'
            ,  @c_Loadkey
            )                

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 89020
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Insert PICKHEADER Table. (isp_GetPickSlipOrders81)'
         GOTO QUIT_SP
      END

      UPDATE #TMP_ORD
      SET PickSlipNo = @c_Pickslipno
      WHERE Orderkey = @c_Orderkey

      IF @@ERROR <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 89030
         SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Error Insert #TMP_ORD Table. (isp_GetPickSlipOrders81)'
         GOTO QUIT_SP
      END

      WHILE @@TRANCOUNT > 0 
      BEGIN
         COMMIT TRAN
      END

      SET @c_PickHeaderKey = RIGHT('0000000000' + CONVERT(NVARCHAR(9), CONVERT( INT, @c_PickHeaderKey ) + 1),9)

      FETCH NEXT FROM @cur_ORD INTO @c_Orderkey, @c_Storerkey
   END
   CLOSE @cur_ORD
   DEALLOCATE @cur_ORD

QUIT_SP:
   IF @n_Continue = 3
   BEGIN
      IF @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK
      END

      TRUNCATE TABLE #TMP_ORD
      
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_GetPickSlipOrders81'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   SELECT   SortBy  = ROW_NUMBER() OVER (ORDER BY OH.PickSlipNo
                                                , PK.Loc
                                                , PK.Sku
                                        )
         ,  PageGroup = RANK() OVER (ORDER BY OH.PickSlipNo) 
         ,  PrintTime = GETDATE()  
         ,  OH.Facility           
         ,  OH.Storerkey          
         ,  OH.PickSlipNo         
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
         ,  RowNo = ROW_NUMBER() OVER (PARTITION BY OH.PickSlipNo
                                       ORDER BY OH.PickSlipNo
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
         ,  OH.PickSlipNo         
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