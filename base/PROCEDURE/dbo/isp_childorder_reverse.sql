SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ChildOrder_Reverse                                */
/* Creation Date: 06-DEC-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#294826- ANF Reverse Child Order                            */
/*        :                                                                */
/*                                                                         */
/* Called By: w_populate_mbol_child_order  - Function "R"                  */
/*            (RCM @ MBOL Screen -> Child Order -> Reverse)                */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 14-MAY-2013  YTWan   1.1   Dummy PickslipNo to child order(Wan01)       */
/* 30-JUN-2013  YTWan   1.1   SOS#314538 - Modify Child Order Reverse:Clean*/
/*                            Up RDTScanToTruck Table (Wan02)              */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length        */    
/* 15-Mar-2021  WLChooi 1.3   WMS-16338 - Add new logic for ANFQHW (WL01)  */
/* 15-Jul-2021  WLChooi 1.4   Fix Update Palletdetail with Storerkey (WL02)*/
/***************************************************************************/  
CREATE PROC [dbo].[isp_ChildOrder_Reverse]  
(     @c_MBOLKey           NVARCHAR(10)  
  ,   @c_Orderkey          NVARCHAR(10)   
  ,   @c_Store             NVARCHAR(30)
  ,   @c_pExternOrderkey   NVARCHAR(50)  --tlting_ext  
  ,   @c_CaseID            NVARCHAR(20) 
  ,   @b_Success           INT            OUTPUT
  ,   @n_Err               INT            OUTPUT
  ,   @c_ErrMsg            NVARCHAR(255)  OUTPUT 
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTranCount     INT 



   DECLARE @n_OrderCnt           INT
         , @n_OpenQty            INT 
         , @n_QtyPicked          INT  
 
         , @n_QtyAllocated       INT 

         , @n_TotalPallets       INT
         , @n_TotalCartons       INT 
         , @n_TotWeight          FLOAT  
         , @n_TotCube            FLOAT  

         , @n_LoadWeight         FLOAT
         , @n_LoadCube           FLOAT  

         , @c_PickdetailKey      NVARCHAR(10) 
         , @c_OrderLineNumber    NVARCHAR(5)
  
         , @c_POrderKey          NVARCHAR(10) 
         , @c_POrderLineNumber   NVARCHAR(5) 

         , @c_LoadKey            NVARCHAR(10) 
         , @c_LoadLineNumber     NVARCHAR(5) 

         , @c_MBOLLineNumber     NVARCHAR(5) 
       
         , @c_Facility           NVARCHAR(5)
         , @c_Storerkey          NVARCHAR(15)
         , @c_OrdType            NVARCHAR(10)

         , @c_PickSlipNo         NVARCHAR(10)
         , @c_PPickSlipNo        NVARCHAR(10)
         , @n_CartonNo           INT
         
         , @n_PCartonNo          INT            --(Wan01)
         , @c_PLoadkey           NVARCHAR(10)   --(Wan01)
         , @c_Sku                NVARCHAR(20)   --(Wan01)
         
         , @c_MBOLCreateChildOrdChkPallet   NVARCHAR(50)   --WL01

   SET @b_Success        = 1
   SET @c_ErrMsg         = ''
   SET @b_Debug          = '0'  
   SET @n_Continue       = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
  
   WHILE @@TRANCOUNT > 0  
      COMMIT TRAN  
  
   BEGIN TRAN  
  
   --Get Order Info
   SELECT @c_Facility  = Facility
         ,@c_Storerkey = Storerkey
         ,@c_Loadkey   = Loadkey
   FROM ORDERS (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   --(Wan01) - START Get Child PickSlipno 
   SET @c_PickSlipNo = ''
   SELECT @c_PickSlipNo = PickHeaderKey   
   FROM PICKHEADER WITH (NOLOCK) 
   WHERE ExternOrderKey = @c_LoadKey  
   AND   Zone = 'LP'
   --(Wan01) - END
   
   --WL01 S
   EXEC nspGetRight  
      @c_Facility  = @c_Facility,  
      @c_StorerKey = NULL,  
      @c_sku       = NULL,  
      @c_ConfigKey = 'MBOLCreateChildOrdChkPallet',  
      @b_Success   = @b_Success                     OUTPUT,  
      @c_authority = @c_MBOLCreateChildOrdChkPallet OUTPUT,  
      @n_err       = @n_err                         OUTPUT,  
      @c_errmsg    = @c_errmsg                      OUTPUT 
      
   IF @n_err <> 0  
   BEGIN
      SET @n_continue = 3    
      SET @n_err = 81085 
      SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Execute nspGetRight Failed. (isp_ChildOrder_CreateMBOL)' 
      GOTO QUIT_WITH_ERROR
   END
   --WL01 E
 
   DECLARE CUR_CASE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT Pickdetailkey    = PD.Pickdetailkey
         ,POrderkey        = OD.UserDefine09
         ,POrderLineNumber = OD.UserDefine10
         ,OrderLineNumber  = OD.OrderLineNumber 
         ,SKU              = PD.Sku
         ,QtyAllocated = ISNULL(CASE WHEN PD.Status IN ('0','1','2','3','4') THEN Qty ELSE 0 END,0)
         ,QtyPicked    = ISNULL(CASE WHEN PD.Status IN ('5','6','7','8')     THEN Qty ELSE 0 END,0) 
   FROM ORDERS      OH WITH (NOLOCK)
   JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   JOIN PICKDETAIL  PD WITH (NOLOCK) ON (OD.Orderkey = PD.Orderkey)           
                                     AND(OD.OrderLineNumber = PD.OrderLineNumber) 
   WHERE OH.Orderkey = @c_Orderkey  
   AND   OH.Consigneekey  = @c_Store
   AND   OD.ExternOrderkey= @c_pExternOrderkey
   AND   PD.CaseID        = @c_CaseID
   ORDER BY OD.OrderLineNumber
  
   OPEN CUR_CASE  
  
   FETCH NEXT FROM CUR_CASE INTO @c_PickdetailKey
                              ,  @c_POrderkey
                              ,  @c_POrderLineNumber
                              ,  @c_OrderLineNumber
                              ,  @c_Sku
                              ,  @n_QtyAllocated 
                              ,  @n_QtyPicked   
   WHILE @@FETCH_STATUS <> -1  
   BEGIN
      --(Wan01) Handle PickSlipNo - (START)
      --Get Parent PickSlipNo
      SET @c_PPickSlipNo = ''
      SET @c_PLoadkey    = ''
      SELECT @c_PPickSlipNo = PH.PickHeaderKey
            ,@c_PLoadkey    = PH.ExternOrderkey
      FROM ORDERS     OH WITH (NOLOCK)
      JOIN PICKHEADER PH WITH (NOLOCK) ON (OH.Userdefine09 = PH.Wavekey)
                                       AND(OH.Loadkey = PH.ExternORderkey)
                                       AND(PH.Zone = 'LP')
      WHERE OH.Orderkey = @c_POrderkey

      SELECT @n_CartonNo = CartonNo
            ,@n_PCartonNo= CONVERT(INT,SUBSTRING(RefNo2,11, CASE WHEN LEN(RefNo2) >= 10 THEN LEN(RefNo2)- 10 ELSE 0 END))
      FROM PACKDETAIL WITH (NOLOCK)
      WHERE PickSlipNo = @c_PickSlipNo
      AND   LabelNo    = @c_CaseID
      AND   Sku        = @c_Sku

      UPDATE PACKDETAIL WITH (ROWLOCK)
      SET  PickSlipNo = @c_PPickSlipNo
          ,CartonNo   = @n_PCartonNo
          ,EditWho = SUSER_NAME()  
          ,EditDate= GETDATE() 
          ,ArchiveCop = NULL
      WHERE PickSlipNo = @c_PickSlipNo
      AND   LabelNo    = @c_CaseID
      AND   Sku        = @c_Sku

      IF @@ERROR <> 0  
      BEGIN
         SET @n_continue = 3    
         SET @n_err = 80115 
         SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update PACKDETAIL Failed. (isp_ChildOrder_CreateMBOL)' 
         GOTO QUIT_WITH_ERROR
      END

      IF NOT EXISTS (SELECT 1  
                     FROM PACKDETAIL WITH (NOLOCK)
                     WHERE PickSlipNo = @c_PickSlipNo
                     AND   LabelNo    = @c_CaseID)
      BEGIN
         UPDATE PACKINFO WITH (ROWLOCK)
         SET PickSlipNo = @c_PPickSlipNo
            ,CartonNo   = @n_PCartonNo
            ,EditWho = SUSER_NAME()  
            ,EditDate= GETDATE() 
            ,Trafficcop = NULL
         WHERE PickSlipNo = @c_PickSlipNo
         AND   CartonNo   = @n_CartonNo

         IF @@ERROR <> 0  
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 80120
            SET @c_errmsg='NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update PACKINFO Failed. (isp_ChildOrder_CreateMBOL)'
            GOTO QUIT_WITH_ERROR
         END 
      END
      --(Wan01) Handle PickSlipNo - (END)

      --Handling Child ORDERS - START
      UPDATE REFKEYLOOKUP WITH (ROWLOCK)
      SET Orderkey = @c_POrderKey
         ,OrderLineNumber = @c_POrderLineNumber
         ,PickSlipNo      = @c_PPickSlipNo         -- (Wan01)
         ,Loadkey         = @c_PLoadkey            -- (Wan01)
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()  
         ,ArchiveCop= NULL
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3 
         SET @n_err = 81005 
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update RefKeyLookup Table Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END

      --UnALLOCATE CHILD ORDERS - Change Parent Pickdetail to Child Pickdetail
      UPDATE PICKDETAIL WITH (ROWLOCK)
      SET Orderkey = @c_POrderKey
         ,OrderLineNumber = @c_POrderLineNumber
         ,PickSlipNo      = @c_PPickSlipNo         -- (Wan01)
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()  
         ,TrafficCop= NULL
      WHERE PickDetailKey = @c_PickDetailKey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81010
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update PickDetail Table Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END

      --(Wan01) Handle Child PickSlipNo - (START) 
      IF NOT EXISTS (SELECT 1 FROM PACKDETAIL WITH (NOLOCK)     
                     WHERE PickSlipNo = @c_PickSlipNo)  
      BEGIN
         DELETE PACKHEADER WITH (ROWLOCK)     
         WHERE PickSlipNo = @c_PickSlipNo

         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 81080
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete PACKHEADER Failed. (isp_ChildOrder_Reverse)'  
            GOTO QUIT_WITH_ERROR  
         END

         DELETE PICKINGINFO WITH (ROWLOCK)     
         WHERE PickSlipNo = @c_PickSlipNo

         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 81085
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete PICKINGINFO Failed. (isp_ChildOrder_Reverse)'  
            GOTO QUIT_WITH_ERROR  
         END
         
         IF NOT EXISTS ( SELECT 1 FROM REFKEYLOOKUP WITH (NOLOCK)
                         WHERE PickSlipNo = @c_PickSlipNo)
         BEGIN
            DELETE PICKHEADER WITH (ROWLOCK)     
            WHERE PickHeaderKey = @c_PickSlipNo

            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @n_err = 81090
               SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete PICKHEADER Failed. (isp_ChildOrder_Reverse)'  
               GOTO QUIT_WITH_ERROR  
            END
         END
      END 
      --(Wan01) Handle Child PickSlipNo - (END)

      IF EXISTS ( SELECT 1
                  FROM ORDERDETAIL WITH (NOLOCK)
                  WHERE OrderKey = @c_Orderkey
                  AND   OrderLineNumber = @c_OrderLineNumber
                  AND   OriginalQty - (@n_QtyAllocated + @n_QtyPicked) <= 0 
                  )
      BEGIN

         DELETE ORDERDETAIL WITH (ROWLOCK)
         WHERE OrderKey = @c_Orderkey
         AND   OrderLineNumber = @c_OrderLineNumber
         AND   OriginalQty - (@n_QtyAllocated + @n_QtyPicked) <= 0 

         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 81015
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete OrderDetail Table Failed. (isp_ChildOrder_Reverse)'  
            GOTO QUIT_WITH_ERROR  
         END
      END
      ELSE
      BEGIN
         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET OriginalQty  = OriginalQty - (@n_QtyAllocated + @n_QtyPicked)
            ,OpenQty      = OpenQty     - (@n_QtyAllocated + @n_QtyPicked) 
            ,QtyAllocated = QtyAllocated - @n_QtyAllocated
            ,QtyPicked    = QtyPicked - @n_QtyPicked
            ,EditDate = GETDATE()
            ,EditWho  = SUSER_NAME()  
            ,TrafficCop= NULL
         WHERE OrderKey = @c_Orderkey
         AND   OrderLineNumber = @c_OrderLineNumber

         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 81020
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update OrderDetail Table Failed. (isp_ChildOrder_Reverse)'  
            GOTO QUIT_WITH_ERROR  
         END
      END
      --Handling Child ORDERS - END

      --Handling Parent Orders - START
      UPDATE ORDERDETAIL WITH (ROWLOCK)
      SET OriginalQty  = OriginalQty + (@n_QtyAllocated + @n_QtyPicked)
         ,OpenQty      = OpenQty     + (@n_QtyAllocated + @n_QtyPicked) 
         ,QtyAllocated = QtyAllocated + @n_QtyAllocated
         ,QtyPicked    = QtyPicked + @n_QtyPicked
--         ,[Status]     = CASE WHEN (QtyPicked - @n_QtyPicked) > 0 THEN '5'  
--                              WHEN (QtyPicked - @n_QtyPicked) + (QtyAllocated - @n_QtyAllocated) = 0  
--                              THEN '0'  
--                              WHEN (OpenQty - (@n_QtyPicked + @n_QtyAllocated)) =  
--                                   (QtyPicked - @n_QtyPicked) + (QtyAllocated - @n_QtyAllocated)  
--                              THEN '2'  
--                              ELSE '1'  
--                         END 
         ,[Status] = '5'
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()  
         ,TrafficCop= NULL
      WHERE OrderKey = @c_POrderkey
      AND   OrderLineNumber = @c_POrderLineNumber

      --Handling Parent Orders - END

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81025
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update Orders Table Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END

      FETCH NEXT FROM CUR_CASE INTO @c_PickdetailKey
                                 ,  @c_POrderkey
                                 ,  @c_POrderLineNumber 
                                 ,  @c_OrderLineNumber
                                 ,  @c_Sku
                                 ,  @n_QtyAllocated 
                                 ,  @n_QtyPicked  
   END
   CLOSE CUR_CASE
   DEALLOCATE CUR_CASE

   --Update Child Order - START
   SET @n_OrderCnt = 0
   SET @n_OpenQty  = 0
   SET @n_QtyAllocated  = 0
   SET @n_QtyPicked  = 0
   SELECT @n_OpenQty      = SUM(OpenQty)
         ,@n_QtyAllocated = SUM(QtyAllocated) 
         ,@n_QtyPicked    = SUM(QtyPicked)
         ,@n_OrderCnt= COUNT(1)
   FROM ORDERDETAIL WITH (NOLOCK)  
   WHERE Orderkey = @c_Orderkey

   IF @n_OrderCnt >= 1 --delete orders if ordercnt = 0
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
      SET OpenQty = @n_OpenQty
         ,[Status] = CASE WHEN @n_QtyPicked + @n_QtyAllocated = 0 THEN '0'  
                          WHEN @n_OpenQty = @n_QtyPicked          THEN '5'
                          ELSE '4'  
                          END 
         ,EditDate = GETDATE()
         ,EditWho  = SUSER_NAME()  
         ,TrafficCop= NULL
      FROM ORDERS 
      WHERE Orderkey = @c_Orderkey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81030
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update Orders Table Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END
   END 
   ELSE
   BEGIN
      DELETE ORDERS WITH (ROWLOCK)
      WHERE Orderkey = @c_Orderkey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81035
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete Orders Table Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END
   END
   --Update Child Order - END
   --Update Parent Order - START
   SELECT @n_OpenQty = SUM(OpenQty)
   FROM ORDERDETAIL WITH (NOLOCK)  
   WHERE Orderkey = @c_POrderkey

   UPDATE ORDERS WITH (ROWLOCK)
   SET OpenQty = @n_OpenQty
      --(Wan01) Remain Parent Order Status, do not update - START 
      --,[Status]  = '5'
      --(Wan01) Remain Parent Order Status, do not update - END 
      ,EditDate = GETDATE()
      ,EditWho  = SUSER_NAME()  
      ,TrafficCop= NULL
   FROM ORDERS 
   WHERE Orderkey = @c_POrderkey

   IF @@ERROR <> 0  
   BEGIN  
      SET @n_Continue = 3  
      SET @n_err = 81040
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update Orders Table Failed. (isp_ChildOrder_Reverse)'  
      GOTO QUIT_WITH_ERROR  
   END
   --Update Parent Order - END

   SET @n_OrderCnt = 0
   --Get TotalWeight, TotalCube, TotalCarton, TotalPallet for Child Order
   SELECT @n_TotWeight = SUM(PD.Qty * SKU.StdGrossWgt)
         ,@n_TotCube   = SUM(PD.Qty * SKU.StdCube)
         ,@n_TotalCartons = COUNT (DISTINCT PD.CaseID)
         ,@n_OrderCnt     = COUNT(1)
   FROM PICKDETAIL PD  WITH (NOLOCK)
   JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                     AND(PD.Sku = SKU.SKU)
   WHERE PD.Orderkey = @c_OrderKey

   IF @n_OrderCnt = 0
   BEGIN
      DELETE FROM LOADPLANDETAIL WITH (ROWLOCK)
      WHERE Loadkey = @c_Loadkey
      AND   Orderkey = @c_OrderKey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81045
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete LoadPlanDetail Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END

      DELETE FROM MBOLDETAIL WITH (ROWLOCK)
      WHERE MBOLKey  = @c_MBOLKey
      AND   Orderkey = @c_OrderKey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81050
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete MBOLDetail Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END
   END
   ELSE
   BEGIN
      UPDATE LOADPLANDETAIL WITH (ROWLOCK)  
      SET   Weight = @n_TotWeight   
        ,   Cube   = @n_TotCube  
        ,   EditDate = GETDATE() 
        ,   EditWho  = SUSER_NAME()     
        ,   TrafficCop = NULL  
      WHERE LoadKey = @c_LoadKey  
        AND OrderKey = @c_OrderKey  

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81055
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update LoadPlanDetail Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END  

      UPDATE MBOLDETAIL WITH (ROWLOCK)
      SET  Weight = @n_TotWeight    
        ,  Cube   = @n_TotCube  
        ,  TotalCartons = @n_TotalCartons  
        ,  EditDate = GETDATE() 
        ,  EditWho  = SUSER_NAME()     
        ,  TrafficCop = NULL  
      WHERE MBOLKey = @c_MBOLKey  
      AND OrderKey  = @c_OrderKey 
 
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81060
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update MBOLDetail Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END 

   END

   IF EXISTS (SELECT 1  
              FROM LOADPLANDETAIL WITH (NOLOCK)
              WHERE Loadkey = @c_LoadKey)
   BEGIN
      -- GET New Load Info
      SELECT @n_LoadWeight = SUM(PD.Qty * SKU.StdGrossWgt)
            ,@n_LoadCube   = SUM(PD.Qty * SKU.StdCube)
            ,@n_TotalPallets = COUNT (DISTINCT DPD.DropID)
      FROM LOADPLANDETAIL LPD  WITH (NOLOCK) 
      JOIN PICKDETAIL PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
      JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                        AND(PD.Sku = SKU.SKU)
      JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON (PD.CaseID = DPD.ChildID)
      WHERE LPD.Loadkey = @c_LoadKey
      AND   DPD.UserDefine01 = @c_MBOLKey
      
      --WL01 S
      IF @c_MBOLCreateChildOrdChkPallet = '1'
      BEGIN
         -- GET New Load Info
         SELECT @n_LoadWeight   = SUM(PD.Qty * SKU.StdGrossWgt)
               ,@n_LoadCube     = SUM(PD.Qty * SKU.StdCube)
               ,@n_TotalPallets = COUNT(DISTINCT PD.ID)
         FROM LOADPLANDETAIL LPD  WITH (NOLOCK) 
         JOIN PICKDETAIL PD  WITH (NOLOCK) ON (LPD.Orderkey = PD.Orderkey)
         JOIN SKU        SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                           AND(PD.Sku = SKU.SKU)
         JOIN PALLET      P WITH (NOLOCK) ON (PD.ID = P.Palletkey)
         JOIN PALLETDETAIL PLTD WITH (NOLOCK) ON (PLTD.Palletkey = P.Palletkey)
         --JOIN DROPIDDETAIL DPD WITH (NOLOCK) ON (PD.CaseID = DPD.ChildID)
         WHERE LPD.Loadkey = @c_LoadKey
         AND   PLTD.UserDefine01 = @c_MBOLKey
      END
      --WL01 E
      
      UPDATE LOADPLAN WITH (ROWLOCK) 
      SET   Weight = @n_LoadWeight   
        ,   Cube   = @n_LoadCube 
        ,   PalletCnt = @n_TotalPallets 
        ,   EditDate = GETDATE() 
        ,   EditWho  = SUSER_NAME()     
        ,   TrafficCop = NULL  
      WHERE LoadKey = @c_LoadKey  

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81065
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update LoadPlan Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END 
   END
   ELSE
   BEGIN
      DELETE LOADPLAN WITH (ROWLOCK)
      WHERE Loadkey = @c_Loadkey

      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81070
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete LoadPlan Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END
   END
   
   IF NOT EXISTS (SELECT 1 
                  FROM PICKDETAIL WITH (NOLOCK)
                  WHERE Orderkey = @c_Orderkey
                  AND   CaseID = @c_CaseID)
   BEGIN
   	--WL01 S
   	IF @c_MBOLCreateChildOrdChkPallet = '1'
   	BEGIN
   	   UPDATE PALLETDETAIL WITH (ROWLOCK)
         SET UserDefine01 = ''
           , EditDate = GETDATE() 
           , EditWho  = SUSER_NAME()     
           , TrafficCop = NULL 
         WHERE CaseID = @c_CaseID AND Storerkey = @c_Storerkey   --WL02
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 81075
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update PALLETDETAIL Failed. (isp_ChildOrder_Reverse)'  
            GOTO QUIT_WITH_ERROR  
         END
   	END
   	ELSE
   	BEGIN   --WL01 E
         UPDATE DROPIDDETAIL WITH (ROWLOCK)
         SET UserDefine01 = ''
           , EditDate = GETDATE() 
           , EditWho  = SUSER_NAME()     
           , TrafficCop = NULL 
         WHERE ChildID = @c_CaseID
         
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @n_err = 81075
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Update DROPIDDETAIL Failed. (isp_ChildOrder_Reverse)'  
            GOTO QUIT_WITH_ERROR  
         END
      END   --WL01
   END

   --(Wan02) - START
   IF EXISTS (SELECT 1 
              FROM rdt.RDTScantoTruck  WITH (NOLOCK)
              WHERE MBOLkey = @c_MBOLKey
              AND   UrnNo = @c_CaseID)
   BEGIN
      DELETE rdt.RDTScantoTruck WITH (ROWLOCK)
      WHERE MBOLkey = @c_MBOLKey
      AND   UrnNo = @c_CaseID
      
      IF @@ERROR <> 0  
      BEGIN  
         SET @n_Continue = 3  
         SET @n_err = 81080
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+ ': Delete rdt.RDTScantoTruck Failed. (isp_ChildOrder_Reverse)'  
         GOTO QUIT_WITH_ERROR  
      END
   END
   --(Wan02) - END
QUIT_NORMAL:  
  
WHILE @@TRANCOUNT > 0  
   COMMIT TRAN
  
GOTO QUIT
 
  
QUIT_WITH_ERROR:  
  
SET @b_Success = 0  
IF @@TRANCOUNT > 0
   ROLLBACK TRAN  
  
RAISERROR (N'SQL Error: %s ErrorNo: %d.',16, 1, @c_errmsg, @n_err) WITH SETERROR    -- SQL2012

QUIT:
   IF CURSOR_STATUS('LOCAL' , 'CUR_CASE') in (0 , 1)
   BEGIN
      CLOSE CUR_CASE
      DEALLOCATE CUR_CASE
   END

   WHILE @@TRANCOUNT < @n_StartTranCount  
      BEGIN TRAN  
  
   RETURN  
END

GO