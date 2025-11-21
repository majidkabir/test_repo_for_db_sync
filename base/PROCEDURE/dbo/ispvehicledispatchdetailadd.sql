SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispVehicleDispatchDetailAdd                                 */
/* Creation Date: 01-Oct-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Add VehicleDispatchdetai ;                                  */
/*        : SOS#315679 - FBR315679 Vehicle Dispatcher v2 0.doc          */
/* Called By: n_cst_boldispatch.of_deleteinstance                       */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */
/************************************************************************/
CREATE PROC [dbo].[ispVehicleDispatchDetailAdd] 
            @c_VehicleDispatchKey   NVARCHAR(10)
         ,  @c_Docname              NVARCHAR(10)
         ,  @c_Dockey               NVARCHAR(10) 
         ,  @c_Orderkey             NVARCHAR(10) 
         ,  @c_Orderlinenumber      NVARCHAR(10)
         ,  @b_Success              INT = 0  OUTPUT 
         ,  @n_err                  INT = 0  OUTPUT 
         ,  @c_errmsg               NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   
   DECLARE  
           @n_StartTCnt                   INT
         , @n_Continue                    INT 

         , @n_Cnt                         INT
         , @n_Qty                         INT
         , @c_ExternOrderkey              NVARCHAR(50)  --tlting_ext
         , @c_OrderNo                     NVARCHAR(10)
         , @c_OrderLineNo                 NVARCHAR(5)
         , @c_VehicleDispatchLineNumber   NVARCHAR(5)

         , @n_NoOfOrders                  INT
         , @n_NoOfStops                   INT
         , @n_NoOfCustomers               INT
    
         , @n_TotalCube                   FLOAT   
         , @n_TotalWeight                 FLOAT 
         , @n_TotalPallets                INT 
         , @n_TotalCartons                INT
         , @n_TotalDropIDs                INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
     
   DECLARE CUR_ORDDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT
            OD.Orderkey
         ,  OD.ExternOrderkey
         ,  OD.OrderLineNumber
         ,  OD.QtyPicked + OD.ShippedQty 
   FROM ORDERS      OH  WITH (NOLOCK)
   JOIN ORDERDETAIL OD  WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
   WHERE ISNULL(OH.MBOLKey,'') = CASE WHEN @c_Docname = 'MBOL' THEN @c_Dockey ELSE ISNULL(OH.MBOLKey,'') END
   AND   ISNULL(OH.Loadkey,'') = CASE WHEN @c_Docname = 'LOAD' THEN @c_Dockey ELSE ISNULL(OH.Loadkey,'') END
   AND   ISNULL(OH.UserDefine09,'') = CASE WHEN @c_Docname = 'WAVE' THEN @c_Dockey ELSE ISNULL(OH.UserDefine09,'') END
   AND   OH.Orderkey = CASE WHEN @c_Docname = 'ORDERS' AND @c_Dockey <> '' THEN @c_Dockey 
                            WHEN @c_Docname = 'ORDERS' AND @c_Orderkey <> '' THEN @c_Orderkey
                            ELSE ISNULL(OH.Orderkey,'') END
   AND   OD.OrderLineNumber = CASE WHEN @c_OrderLineNumber <> '' THEN @c_OrderLineNumber ELSE ISNULL(OD.OrderLineNumber,'') END
   AND   OD.QtyPicked + OD.ShippedQty > 0
   
   OPEN CUR_ORDDET

   FETCH NEXT FROM CUR_ORDDET INTO @c_OrderNo
                                 , @c_ExternOrderkey
                                 , @c_OrderLineNo
                                 , @n_Qty

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
   BEGIN
      SET @n_Cnt = 0
      SELECT @n_Qty = @n_Qty - ISNULL(SUM(Qty),0)
            ,@n_Cnt = 1
      FROM VEHICLEDISPATCHDETAIL WITH (NOLOCK)
      WHERE Orderkey = @c_OrderNo
      AND   OrderLineNumber = @c_OrderLineNo

      IF @n_Cnt = 1        -- Order Line Exists in VehicleDispatch Detail 
      BEGIN
         IF @n_Qty = 0     -- If All Qty in Orderdetail populated to VehicleDispatch Detail, No to populate again
         BEGIN
            GOTO NEXT_REC  
         END 
      END 

      SELECT @c_VehicleDispatchLineNumber = RIGHT('00000' 
                                          + CONVERT(NVARCHAR(5), 
                                                CONVERT(INT, ISNULL(MAX(VehicleDispatchLineNumber),0)) + 1
                                                ),5)
      FROM VEHICLEDISPATCHDETAIL WITH (NOLOCK)
      WHERE VehicleDispatchKey = @c_VehicleDispatchKey

      INSERT INTO VEHICLEDISPATCHDETAIL
         (  VehicleDispatchKey
         ,  VehicleDispatchLineNumber
         ,  ExternOrderkey
         ,  Orderkey
         ,  OrderLineNumber
         ,  Storerkey
         ,  Sku
         ,  Qty
         ,  Cube
         ,  Weight
         ,  NoOfPallet
         ,  NoOfCarton
         )
      SELECT @c_VehicleDispatchKey
         ,  @c_VehicleDispatchLineNumber
         ,  @c_ExternOrderkey
         ,  @c_OrderNo
         ,  @c_OrderLineNo
         ,  PD.Storerkey
         ,  PD.Sku
         ,  @n_Qty
         ,  @n_Qty * SKU.StdCube
         ,  @n_Qty * SKU.StdGrossWgt
--         ,  SUM(PD.Qty * SKU.StdCube)
--         ,  SUM(PD.Qty * SKU.StdGrossWgt)
         ,  COUNT( DISTINCT PD.ID )
         ,  COUNT( DISTINCT PD.DropID) --CASE WHEN PK.CaseCnt > 0 THEN SUM(PD.Qty) / PK.CaseCnt ELSE 0 END
      FROM PICKDETAIL  PD  WITH (NOLOCK) 
      JOIN SKU         SKU WITH (NOLOCK) ON (PD.Storerkey = SKU.Storerkey)
                                         AND(PD.Sku       = SKU.Sku)
      JOIN PACK        PK  WITH (NOLOCK) ON (SKU.Packkey = PK.Packkey)
      WHERE PD.Orderkey = @c_OrderNo
      AND   PD.OrderLineNumber = @c_OrderLineNo
      GROUP BY PD.Storerkey
            ,  PD.Sku
            ,  PK.CaseCnt
            ,  SKU.StdCube
            ,  SKU.StdGrossWgt

      SET @n_err = @@ERROR
      IF @n_err <> 0     
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert VEHICLEDISPATCHDETAIL Failed. (ispVehicleDispatchDetailAdd)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '

      END

      NEXT_REC:
      FETCH NEXT FROM CUR_ORDDET INTO @c_OrderNo
                                    , @c_ExternOrderkey
                                    , @c_OrderLineNo
                                    , @n_Qty
   END 
   CLOSE CUR_ORDDET
   DEALLOCATE CUR_ORDDET

   SET @n_NoOfOrders = 0
   SET @n_NoOfStops = 0
   SET @n_NoOfCustomers = 0
   SET @n_TotalCube = 0.00
   SET @n_TotalWeight = 0.00

   SELECT @n_NoOfOrders   = ISNULL(COUNT( DISTINCT VDD.Orderkey ),0)
      ,   @n_NoOfStops    = ISNULL(COUNT( DISTINCT OH.Stop ),0)
      ,   @n_NoOfCustomers= ISNULL(COUNT( DISTINCT OH.ConsigneeKey ),0)
      ,   @n_TotalCube    = ISNULL(SUM(VDD.Cube),0.00) 
      ,   @n_TotalWeight  = ISNULL(SUM(VDD.Weight),0.00)
   FROM VEHICLEDISPATCHDETAIL VDD WITH (NOLOCK)  
   JOIN ORDERS                OH  WITH (NOLOCK) ON (VDD.Orderkey = OH.Orderkey)
   WHERE VDD.VehicleDispatchKey = @c_VehicleDispatchKey

   SET @n_TotalPallets = 0
   SET @n_TotalCartons = 0
   SELECT  @n_TotalPallets = ISNULL(COUNT(DISTINCT PD.ID),0)
         , @n_TotalCartons = ISNULL(COUNT(DISTINCT PD.DropID),0)
        -- , @n_TotalDropIDs = COUNT(DISTINCT PD.DropID) 
   FROM VEHICLEDISPATCHDETAIL VDD WITH (NOLOCK) 
   JOIN PICKDETAIL        PD   WITH (NOLOCK) ON (VDD.Orderkey = PD.ORderkey) 
   WHERE VDD.VehicleDispatchKey = @c_VehicleDispatchKey
   AND PD.Status >= '5'

   UPDATE VEHICLEDISPATCH WITH (ROWLOCK)
   SET NoOfOrders    = @n_NoOfOrders
      ,NoOfStops     = @n_NoOfStops
      ,NoOfCustomers = @n_NoOfCustomers   
      ,TotalCube     = @n_TotalCube 
      ,TotalWeight   = @n_TotalWeight        
      ,TotalPallets  = @n_TotalPallets            
      ,TotalCartons  = @n_TotalCartons           
    --  ,TotalDropIDs  = @n_TotalDropIDs
      ,Trafficcop    = NULL
      ,EditDate      = GETDATE()
      ,EditWho       = SUSER_NAME()
   WHERE VehicleDispatchKey = @c_VehicleDispatchKey
 
   SET @n_err = @@ERROR
   IF @n_err <> 0     
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert VEHICLEDISPATCHDETAIL Failed. (ispVehicleDispatchDetailAdd)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      GOTO QUIT
   END

QUIT:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispVehicleDispatchDetailAdd'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END   
END -- procedure

GO