SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store Procedure: ispConsoPickList33_3                                   */
/* Creation Date: 07-JUN-2013                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Normal PickSlip                                               */
/*           SOS#280007-MY Project Starlight-Loading Sheet Sorting Sequence*/
/*           Print after Normal & Cluster Pickslip                         */
/* Called By: PB: r_dw_consolidated_pick_33_3                              */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author    Ver.  Purposes                                   */
/* 23-Sep-2013  YTWan     1.1   SOS#289942 - LFA - Pick Slip Generation    */
/*                              Process Improvement (Wan01)                */
/* 23-Apr-2014  YTWan     1.2   SOS#308966 - Amend Normal and Cluster Pick */
/*                              Pickslip.(Wan02)                           */
/* 28-Jan-2019  TLTING_ext 1.3  enlarge externorderkey field length        */
/***************************************************************************/
CREATE PROC [dbo].[ispConsoPickList33_3]
           @c_Loadkey NVARCHAR(10) 
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTCnt       INT            -- Holds the current transaction count    
         , @n_Err             INT
         , @b_Success         INT
         , @c_errmsg          INT

   DECLARE @n_BoxNo           INT
         , @c_Orderkey        NVARCHAR(10)
         , @c_PickSlipNo      NVARCHAR(10)
         , @c_PickSlipNoP     NVARCHAR(10)

	DECLARE @c_ExternOrderKey	NVARCHAR(50)   --tlting_ext
         , @c_ConsigneeKey  	NVARCHAR(15)
         , @c_Company       	NVARCHAR(45)
         , @c_Addr1         	NVARCHAR(45)
         , @c_Addr2         	NVARCHAR(45)
         , @c_Addr3         	NVARCHAR(45)
         , @c_Addr4         	NVARCHAR(45)
         , @c_PostCode      	NVARCHAR(45)
         , @c_Notes1        	NVARCHAR(60)
         , @c_Notes2        	NVARCHAR(60)
         , @c_InvoiceNo     	NVARCHAR(20)
         , @c_Stop          	NVARCHAR(10)
         , @c_DeliveryMode  	NVARCHAR(10)
         , @c_RouteDescr   	NVARCHAR(60)
         , @d_OrderDate      	DATETIME    
         , @d_DeliveryDate    DATETIME    
         , @c_Carrierkey     	NVARCHAR(15)
         , @c_TrfRoom        	NVARCHAR(10)
         , @c_Route          	NVARCHAR(10)
         , @c_VehicleNo      	NVARCHAR(10)
         , @c_RouteDescrr 		NVARCHAR(60)


   SET @n_StartTCnt     = @@TRANCOUNT
   SET @n_Err           = 0
   SET @b_Success       = 1
   SET @c_errmsg        = ''

   SET @n_BoxNo         = ''
   SET @c_Orderkey      = ''
   SET @c_PickSlipNo    = ''


   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   CREATE TABLE #TMP_ORD 
         (  Orderkey          NVARCHAR(10) NOT NULL
         ,  LoadKey           NVARCHAR(10) NOT NULL
         ,  PickSlipNo        NVARCHAR(10) NOT NULL
         ,  BoxNo             INT 
         ,  Type              NVARCHAR(1)
         )

   CREATE INDEX IDX_#ORD ON #TMP_ORD (PickSlipNo, Orderkey)
 
   CREATE TABLE #TMP_LOADSHEET
         (  SeqNo          INT      IDENTITY(1,1)  NOT NULL
         ,  PickSlipNo     NVARCHAR(10)
         ,  Loadkey        NVARCHAR(10)
         ,  Orderkey       NVARCHAR(10)
         ,  BoxNo          INT
         ,  ExternOrderKey	NVARCHAR(50)   --tlting_ext
         ,  ConsigneeKey  	NVARCHAR(15)
         ,  Company       	NVARCHAR(45)
         ,  Addr1         	NVARCHAR(45)
         ,  Addr2         	NVARCHAR(45)
         ,  Addr3         	NVARCHAR(45)
         ,  Addr4         	NVARCHAR(45)
         ,  PostCode      	NVARCHAR(45)
         ,  Notes1        	NVARCHAR(60)
         ,  Notes2        	NVARCHAR(60)
         ,  InvoiceNo     	NVARCHAR(20)
         ,  DeliveryMode  	NVARCHAR(10)
         ,  OrderDate      DATETIME    
         ,  DeliveryDate   DATETIME    
         ,  Carrierkey     NVARCHAR(15)
         ,  VehicleNo      NVARCHAR(10)
         ,  Storerkey      NVARCHAR(15)
         ,  Sku            NVARCHAR(20)
         ,  Qty            INT
         ,  Lottable01     NVARCHAR(18)
         ,  Lottable02     NVARCHAR(18)
         ,  Lottable03     NVARCHAR(18)
         ,  Lottable04     DATETIME
         ,  SkuDescr       NVARCHAR(60)
         ,  SerialNo       NVARCHAR(18)
         ,  CaseCnt        FLOAT
         ,  PackUOM1       NVARCHAR(10)
         ,  PackUOM3       NVARCHAR(10) 
         ,  OrderSize      FLOAT                      --(Wan01)
         ,  OrderGrossWgt  FLOAT                      --(Wan01)
         ,  OVAS           NVARCHAR(10)               --(Wan02)
         )  

   -- Normal Pickslip 
   INSERT INTO #TMP_ORD
         (  Orderkey
         ,  Loadkey
         ,  PickSlipNo
         ,  BoxNo
         ,  Type
         )
   SELECT   Orderkey
         ,  ExternOrderkey
         ,  PickHeaderKey
         ,  ''
         ,  'N'
   FROM PICKHEADER WITH (NOLOCK)
   WHERE ExternOrderkey = @c_Loadkey
   AND   Zone = '3' 
      

   -- Cluster PickSlip
   DECLARE CUR_CLUSTERORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT   RL.Orderkey
         ,  RL.PickSlipNo
   FROM PICKHEADER   PH  WITH (NOLOCK)
   JOIN REFKEYLOOKUP RL  WITH (NOLOCK) ON (PH.PickHeaderKey = RL.PickSlipNo)
                                       AND(PH.ExternOrderkey = RL.Loadkey)
   JOIN PICKDETAIL   PD  WITH (NOLOCK) ON (RL.PickDetailKey = PD.PickDetailKey)
   JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (PD.Lot = LA.Lot)  
   JOIN LOC          LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
   WHERE PH.ExternOrderkey = @c_LoadKey 
   AND   Zone = 'LP' 
   ORDER BY PH.PickHeaderKey  
        ,   ISNULL(RTRIM(LOC.PickZone),'')  
        ,   CASE ISNULL(RTRIM(LOC.LocationType),'') WHEN 'OTHER' THEN 3  
                                                    WHEN 'CASE'  THEN 2  
                                                    WHEN 'PICK'  THEN 1  
                                                    END   
        ,   ISNULL(RTRIM(LOC.LogicalLocation),'')  
        ,   ISNULL(RTRIM(PD.Storerkey),'')  
        ,   ISNULL(RTRIM(PD.Sku),'')     
        ,   ISNULL(RTRIM(LA.Lottable02),'')
        ,   RL.Orderkey 
   OPEN CUR_CLUSTERORD  
   
   FETCH NEXT FROM CUR_CLUSTERORD INTO @c_Orderkey  
                                    ,  @c_PickSlipNo  
          
   WHILE @@FETCH_STATUS <> -1    
   BEGIN 
      IF NOT EXISTS (SELECT 1 FROM #TMP_ORD WHERE PickSlipNo = @c_PickSlipNo AND Orderkey = @c_Orderkey)
      BEGIN 
         IF @c_PickSlipNoP <> @c_PickSlipNo
         BEGIN
            SET @n_BoxNo = 0
         END
         SET @n_BoxNo = @n_BoxNo + 1
         INSERT INTO #TMP_ORD
               (  Orderkey
               ,  Loadkey
               ,  PickSlipNo
               ,  BoxNo
               ,  Type
               )
         VALUES 
               (  @c_Orderkey
               ,  @c_Loadkey
               ,  @c_PickSlipNo
               ,  @n_BoxNo
               ,  'C'
               )
      END
      SET @c_PickSlipNoP = @c_PickSlipNo
      FETCH NEXT FROM CUR_CLUSTERORD INTO @c_Orderkey  
                                       ,  @c_PickSlipNo   
   END
   CLOSE CUR_CLUSTERORD 
   DEALLOCATE CUR_CLUSTERORD 

   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT PickSlipNo       = TMP.PickSlipNo
         ,Orderkey         = TMP.Orderkey
         ,BoxNo            = TMP.BoxNo
         ,c_ExternOrderKey = ISNULL(RTRIM(OH.ExternOrderKey),'')
         ,c_ConsigneeKey   = ISNULL(RTRIM(OH.BillToKey),'')
         ,c_Company        = ISNULL(RTRIM(OH.c_Company),'')
         ,c_Addr1          = ISNULL(RTRIM(OH.C_Address1),'')
         ,c_Addr2          = ISNULL(RTRIM(OH.C_Address2),'')
         ,c_Addr3          = ISNULL(RTRIM(OH.C_Address3),'')
         ,c_Addr4          = ISNULL(RTRIM(OH.C_Address4),'')      
         ,c_PostCode       = ISNULL(RTRIM(OH.C_Zip),'')
         ,c_Notes1         = CONVERT(NVARCHAR(60), ISNULL(OH.Notes,'')) 
         ,c_Notes2         = CONVERT(NVARCHAR(60), ISNULL(OH.Notes2,'')) 
         ,c_InvoiceNo      = ISNULL(RTRIM(OH.InvoiceNo),'')     
         ,c_DeliveryMode   = ISNULL(OH.Route, '') 
         ,d_OrderDate      = OH.OrderDate 
         ,d_DeliveryDate   = OH.DeliveryDate
         ,c_VehicleNo      = ISNULL(RTRIM(LP.TruckSize),'')   
         ,c_Carrierkey     = ISNULL(RTRIM(LP.CarrierKey),'')   
   FROM #TMP_ORD TMP
   JOIN ORDERS       OH WITH (NOLOCK) ON (TMP.Orderkey = OH.Orderkey) 
   JOIN LOADPLAN     LP WITH (NOLOCK) ON (TMP.Loadkey = LP.Loadkey)
   ORDER BY TMP.Type DESC
         ,  TMP.PickSlipNO
         ,  TMP.BoxNo 

   OPEN CUR_ORD  
   
   FETCH NEXT FROM CUR_ORD INTO @c_PickSlipNo
                              , @c_OrderKey 
                              , @n_BoxNo
                              , @c_ExternOrderKey 
                              , @c_ConsigneeKey   
                              , @c_Company        
                              , @c_Addr1          
                              , @c_Addr2          
                              , @c_Addr3          
                              , @c_Addr4           
                              , @c_PostCode       
                              , @c_Notes1         
                              , @c_Notes2         
                              , @c_InvoiceNo      
                              , @c_DeliveryMode 
                              , @d_OrderDate      
                              , @d_DeliveryDate   
                              , @c_VehicleNo      
                              , @c_Carrierkey     

          
   WHILE @@FETCH_STATUS <> -1    
   BEGIN
      INSERT INTO #TMP_LoadSheet
            ( PickSlipNo
            , Loadkey
            , Orderkey
            , BoxNo
            , ExternOrderKey 
            , ConsigneeKey   
            , Company        
            , Addr1          
            , Addr2          
            , Addr3          
            , Addr4           
            , PostCode       
            , Notes1         
            , Notes2         
            , InvoiceNo      
            , DeliveryMode
            , OrderDate      
            , DeliveryDate   
            , VehicleNo      
            , Carrierkey     
            , Storerkey      
            , Sku             
            , Qty             
            , Lottable01      
            , Lottable02      
            , Lottable03      
            , Lottable04      
            , SkuDescr      
            , SerialNo        
            , CaseCnt         
            , PackUOM1        
            , PackUOM3 
            , OrderSize                            --(Wan01)
            , OrderGrossWgt                        --(Wan01)
            , OVAS                                 --(Wan02)
            )
      
      SELECT @c_PickSlipNo
            ,@c_Loadkey
            ,@c_Orderkey
            ,@n_BoxNo
            ,@c_ExternOrderKey 
            ,@c_ConsigneeKey   
            ,@c_Company        
            ,@c_Addr1          
            ,@c_Addr2          
            ,@c_Addr3          
            ,@c_Addr4           
            ,@c_PostCode       
            ,@c_Notes1         
            ,@c_Notes2         
            ,@c_InvoiceNo      
            ,@c_DeliveryMode 
            ,@d_OrderDate      
            ,@d_DeliveryDate   
            ,@c_VehicleNo      
            ,@c_Carrierkey     
            ,PD.Storerkey
            ,PD.Sku
            ,SUM(PD.Qty)
            ,ISNULL(RTRIM(LA.Lottable01),'')
            ,ISNULL(RTRIM(LA.Lottable02),'')
            ,ISNULL(RTRIM(LA.Lottable03),'')
            ,ISNULL(LA.Lottable04,CONVERT(DATETIME,'1900-01-01'))
            ,ISNULL(RTRIM(SKU.Descr),'')
            ,ISNULL(RTRIM(SL.SerialNo),'')
            ,ISNULL(PACK.CaseCnt,0)
            ,ISNULL(RTRIM(PACK.PackUOM1),'')
            ,ISNULL(RTRIM(PACK.PackUOM3),'')
            ,SUM(PD.Qty * SKU.StdCube)             --(Wan01)
            ,SUM(PD.Qty * SKU.StdGrossWgt)         --(Wan01)
            ,ISNULL(RTRIM(SKU.OVas), '')           --(Wan02)
      FROM PICKDETAIL   PD   WITH (NOLOCK)
      JOIN LOTATTRIBUTE LA   WITH (NOLOCK) ON (PD.Lot = LA.Lot)
      JOIN SKU          SKU  WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey) AND (PD.Sku = SKU.Sku)
      JOIN PACK         PACK WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      LEFT JOIN SERIALNO SL  WITH (NOLOCK) ON (PD.Orderkey = SL.Orderkey) AND (PD.OrderLineNumber = SL.OrderLineNumber)
                                           AND(PD.Sku = SKU.Sku)
      WHERE PD.Orderkey = @c_Orderkey
      GROUP BY PD.Storerkey
            ,  PD.Sku
            ,  ISNULL(RTRIM(LA.Lottable01),'')
            ,  ISNULL(RTRIM(LA.Lottable02),'')
            ,  ISNULL(RTRIM(LA.Lottable03),'')
            ,  ISNULL(LA.Lottable04,CONVERT(DATETIME,'1900-01-01'))
            ,  ISNULL(RTRIM(SKU.Descr),'')
            ,  ISNULL(RTRIM(SL.SerialNo),'')
            ,  ISNULL(PACK.CaseCnt,0)
            ,  ISNULL(RTRIM(PACK.PackUOM1),'')
            ,  ISNULL(RTRIM(PACK.PackUOM3),'')
            ,  ISNULL(RTRIM(SKU.OVas), '')           --(Wan02)        

      FETCH NEXT FROM CUR_ORD INTO @c_PickSlipNo
                                 , @c_OrderKey 
                                 , @n_BoxNo
                                 , @c_ExternOrderKey 
                                 , @c_ConsigneeKey   
                                 , @c_Company        
                                 , @c_Addr1          
                                 , @c_Addr2          
                                 , @c_Addr3          
                                 , @c_Addr4           
                                 , @c_PostCode       
                                 , @c_Notes1         
                                 , @c_Notes2         
                                 , @c_InvoiceNo      
                                 , @c_DeliveryMode
                                 , @d_OrderDate      
                                 , @d_DeliveryDate   
                                 , @c_VehicleNo      
                                 , @c_Carrierkey     
  
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD

   --(Wan01) - START
   UPDATE #TMP_LOADSHEET
      SET   OrderSize     = T.TotalSize
         ,  OrderGrossWgt = T.TotalGrossWgt
   FROM #TMP_LOADSHEET
   JOIN (SELECT Orderkey 
               ,TotalSize     = SUM(OrderSize)
               ,TotalGrossWgt = SUM(OrderGrossWgt)
         FROM #TMP_LOADSHEET
         GROUP BY Orderkey ) T ON (#TMP_LOADSHEET.Orderkey = T.Orderkey)
   --(Wan01) - END      

   SELECT   PickSlipNo
         ,  Loadkey 
         ,  Orderkey       
         ,  BoxNo = CASE WHEN BoxNo = 0 THEN '' ELSE RIGHT('00' + CONVERT(VARCHAR(2), BoxNo),2) END      
         ,  ExternOrderKey	
         ,  ConsigneeKey  	
         ,  Company       	
         ,  Addr1         	
         ,  Addr2         	
         ,  Addr3         	
         ,  Addr4         	
         ,  PostCode      	
         ,  Notes1        	
         ,  Notes2        	
         ,  InvoiceNo     	
         ,  DeliveryMode 
         ,  OrderDate      
         ,  DeliveryDate   
         ,  Carrierkey     
         ,  VehicleNo      
         ,  Storerkey      
         ,  Sku            
         ,  Qty            
         ,  Lottable01     
         ,  Lottable02     
         ,  Lottable03     
         ,  Lottable04 = CASE WHEN CONVERT(NVARCHAR(10),Lottable04, 112) = '19000101' THEN NULL ELSE Lottable04 END  
         ,  SkuDescr       
         ,  CaseCnt   
         ,  PackUOM1       
         ,  PackUOM3 
         ,  QtyCS = CASE WHEN CaseCnt > 0 THEN FLOOR(Qty/CaseCnt) ELSE 0 END
         ,  QtyEA = CASE WHEN CaseCnt = 0 THEN Qty ELSE Qty % CONVERT(INT, CaseCnt) END
         --(Wan01) - START
         ,  OrderSize     
         ,  OrderGrossWgt 
         --(Wan01) - END
         ,  OVAS                             --(Wan02)
   FROM #TMP_LOADSHEET  

   ORDER BY SeqNo
         
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END

SET QUOTED_IDENTIFIER OFF 

GO