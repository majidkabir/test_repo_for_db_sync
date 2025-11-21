SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispValidateVehicleDispatch                                  */
/* Creation Date: 06-Oct-2014                                           */
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
/************************************************************************/
CREATE PROC [dbo].[ispValidateVehicleDispatch] 
            @c_VehicleDispatchKey   NVARCHAR(10)
         ,  @b_Success              INT = 0  OUTPUT 
         ,  @n_err                  INT = 0  OUTPUT 
         ,  @c_errmsg               NVARCHAR(4000) = '' OUTPUT
AS
BEGIN
   DECLARE  
            @n_StartTCnt               INT
         ,  @n_Continue                INT 

         ,  @c_Orderkey                NVARCHAR(10)
         ,  @c_OrderLineNumber         NVARCHAR(10)

         ,  @c_VEHDispatchKey          NVARCHAR(10)
         ,  @c_VEHDispatchLineNumber   NVARCHAR(10)
         ,  @n_VEHDispatchQty          INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @b_Success  = 1
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
     
   IF EXISTS (
               SELECT 1
               FROM VEHICLEDISPATCHDETAIL VDD WITH (NOLOCK)  
               JOIN ORDERS                OH  WITH (NOLOCK) ON (VDD.Orderkey = OH.Orderkey)
               WHERE VDD.VehicleDispatchKey = @c_VehicleDispatchKey
               AND  OH.Status <> '9'
             )
   BEGIN
      SET @n_Continue = 3
      SET @c_errmsg = 'There is not shipped orders. Unable to complete vehicle dispatch.'
      GOTO QUIT
   END

   BEGIN TRAN
   -- Check loaded qty tally with orderdetail shippedqty
   DECLARE CUR_CHKQTY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT VDD.Orderkey
         ,VDD.OrderLineNumber
   FROM VEHICLEDISPATCHDETAIL VDD WITH (NOLOCK)
   WHERE VDD.VehicleDispatchKey = @c_VehicleDispatchKey

   OPEN CUR_CHKQTY
   FETCH NEXT FROM CUR_CHKQTY INTO @c_OrderKey
                                  ,@c_OrderLineNumber
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF EXISTS(  SELECT 1 
                  FROM  VEHICLEDISPATCHDETAIL VDD WITH (NOLOCK)
                  WHERE VDD.Orderkey = @c_OrderKey 
                  AND VDD.OrderLineNumber = @c_OrderLineNumber
                  GROUP BY VDD.Orderkey   
                        ,  VDD.OrderLineNumber
                  HAVING EXISTS ( SELECT 1
                                  FROM ORDERDETAIL WITH (NOLOCK)
                                  WHERE ORDERDETAIL.Orderkey = VDD.Orderkey
                                  AND ORDERDETAIL.OrderLineNumber = VDD.OrderLineNumber
                                  AND ShippedQty <> SUM(VDD.Qty))
               )
      BEGIN
         DECLARE CUR_QTYONVEH CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT VDD.VehicleDispatchKey
             ,  VDD.VehicleDispatchLineNumber
             ,  VDD.Qty
         FROM  VEHICLEDISPATCHDETAIL VDD WITH (NOLOCK)
         WHERE VDD.Orderkey = @c_OrderKey 
         AND   VDD.OrderLineNumber = @c_OrderLineNumber

         OPEN CUR_QTYONVEH
         FETCH NEXT FROM CUR_QTYONVEH INTO @c_VEHDispatchKey
                                          ,@c_VEHDispatchLineNumber
                                          ,@n_VEHDispatchQty
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @n_Continue = 3
            SET @c_errmsg = @c_errmsg + CHAR(9) 
                          + 'VD #: ' + @c_VEHDispatchKey + ', ' 
                          + 'VD Line#: ' + @c_VEHDispatchLineNumber + ', '  
                          + 'VD Qty: ' + CONVERT(NVARCHAR(10), @n_VEHDispatchQty) +  CHAR(13) + CHAR(10)

            FETCH NEXT FROM CUR_QTYONVEH INTO @c_VEHDispatchKey
                                             ,@c_VEHDispatchLineNumber
                                             ,@n_VEHDispatchQty
         END
         CLOSE CUR_QTYONVEH
         DEALLOCATE CUR_QTYONVEH
      END 
      IF @c_errmsg <> ''
      BEGIN
         SET @c_errmsg = 'Order #: ' + @c_OrderKey + ', Order Line #: ' + @c_OrderLineNumber + CHAR(13) + CHAR(10)
                       + @c_errmsg
      END
      FETCH NEXT FROM CUR_CHKQTY INTO @c_OrderKey
                                     ,@c_OrderLineNumber
   END

   IF @c_errmsg <> ''
   BEGIN
      SET @c_errmsg = 'There are not tally dispatch qty on below Vehicle Dispatcher. Please check.' + CHAR(13) + CHAR(10)
                    + @c_errmsg
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