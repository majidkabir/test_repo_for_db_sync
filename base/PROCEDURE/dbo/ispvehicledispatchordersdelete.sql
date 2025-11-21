SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispVehicleDispatchOrdersDelete                              */
/* Creation Date: 28-Sep-2014                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: BOL Dispatched Order delete                                 */
/*        : SOS#315679 - FBR315679 Vehicle Dispatcher v2 0.doc          */
/* Called By: n_cst_vehicledispatch.of_deleteinstance                   */
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
CREATE PROC [dbo].[ispVehicleDispatchOrdersDelete] 
            @c_VehicleDispatchKey   NVARCHAR(10)
         ,  @c_Orderkey             NVARCHAR(10) 
         ,  @b_Success              INT = 0  OUTPUT 
         ,  @n_err                  INT = 0  OUTPUT 
         ,  @c_errmsg               NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_SQL             NVARCHAR(4000)

         , @n_NoOfOrders      INT
         , @n_NoOfStops       INT
         , @n_NoOfCustomers   INT
    
         , @n_TotalCube       FLOAT   
         , @n_TotalWeight     FLOAT 
         , @n_TotalPallets    INT 
         , @n_TotalCartons    INT
         , @n_TotalDropIDs    INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
     
   BEGIN TRAN
   IF @n_Continue = 1 OR @n_Continue = 2
   BEGIN
      DELETE VEHICLEDISPATCHDETAIL WITH (ROWLOCK)
      WHERE VehicleDispatchKey = @c_VehicleDispatchKey 
      AND   Orderkey = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0     
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 81060   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Delete BOLDISPATCHDETAIL Failed. (ispVehicleDispatchOrdersDelete)' 
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
         GOTO QUIT
      END
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispVehicleDispatchOrdersDelete'
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