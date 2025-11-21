SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: isp_EPackVas_Update                                */  
/* Creation Date: 12-JUL-2016                                           */  
/* Copyright: LF                                                        */  
/* Written by: Wan                                                      */  
/*                                                                      */  
/* Purpose: WMS-2306 - CN-Nike SDC WMS ECOM Packing CR                  */  
/*                                                                      */  
/* Called By: nep_n_cst_packvas.of_update                               */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_EPackVas_Update] 
      @c_Orderkey          NVARCHAR(10) 
   ,  @c_OrderLineNumber   NVARCHAR(15)  
   ,  @n_Qty               INT = 1
   ,  @b_Success           INT = 0           OUTPUT 
   ,  @n_err               INT = 0           OUTPUT 
   ,  @c_errmsg            NVARCHAR(255) = ''OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF 
   
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
      
         , @n_RowRef          BIGINT
         , @n_QtyToUpdate     INT

         , @c_Facility        NVARCHAR(5)
         , @c_StorerKey       NVARCHAR(15)

         , @cur_ODR           CURSOR   
       
         , @c_EPACKVASActivity   NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
     
   IF @c_Orderkey = ''
   BEGIN
      GOTO QUIT_SP
   END    
   
   SET @c_Facility = ''
   SET @c_StorerKey= ''
   SELECT  @c_Facility = Facility
         , @c_StorerKey= StorerKey
   FROM ORDERS OH (NOLOCK) 
   WHERE Orderkey = @c_Orderkey

   SET @c_EPACKVASActivity = ''
   EXEC nspGetRight      
         @c_Facility  = @c_Facility     
      ,  @c_StorerKey = @c_StorerKey      
      ,  @c_sku       = NULL      
      ,  @c_ConfigKey = 'EPACKVASActivity'      
      ,  @b_Success   = @b_Success           OUTPUT      
      ,  @c_authority = @c_EPACKVASActivity  OUTPUT      
      ,  @n_err       = @n_err               OUTPUT      
      ,  @c_errmsg    = @c_errmsg            OUTPUT

   IF @b_Success = 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 60010
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (isp_EPackVas_Update)' 
      GOTO QUIT_SP
   END

   IF @c_EPACKVASActivity <> '1'
   BEGIN
      GOTO QUIT_SP
   END

   IF @c_OrderLineNumber = ''
   BEGIN
      SET @cur_ODR = CURSOR FAST_FORWARD READ_ONLY FOR      
         SELECT RowRef = ODR.RowRef
             ,  QtyToUpdate = (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) - ODR.PackCnt 
         FROM ORDERDETAIL    OD  WITH (NOLOCK)
         JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey = ODR.Orderkey)
                                               AND(OD.OrderLineNumber = ODR.OrderLineNumber)
         WHERE ODR.Orderkey  = @c_Orderkey
         AND   ODR.RefType  = 'PI'
         AND  (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) - ODR.PackCnt > 0
   END
   ELSE
   BEGIN
      SET @cur_ODR = CURSOR FAST_FORWARD READ_ONLY FOR      
         SELECT RowRef = ODR.RowRef
             ,  QtyToUpdate = @n_Qty 
         FROM ORDERDETAIL    OD  WITH (NOLOCK)
         JOIN ORDERDETAILREF ODR WITH (NOLOCK) ON (OD.Orderkey = ODR.Orderkey)
                                               AND(OD.OrderLineNumber = ODR.OrderLineNumber)
         WHERE ODR.Orderkey  = @c_Orderkey
         AND   ODR.OrderLineNumber = @c_OrderLineNumber
         AND   ODR.RefType  = 'PI'
         AND  (OD.QtyAllocated + OD.QtyPicked + OD.ShippedQty) - ODR.PackCnt > 0
   END

   OPEN @cur_ODR
   FETCH NEXT FROM @cur_ODR INTO @n_RowRef
                              ,  @n_QtyToUpdate

   WHILE @@FETCH_STATUS <> -1 
   BEGIN

      UPDATE ORDERDETAILREF WITH (ROWLOCK)
         SET PackCnt  = PackCnt + @n_QtyToUpdate
            ,EditWho  = SUSER_SNAME()
            ,EditDate = GETDATE()
            ,TrafficCop = NULL
      WHERE RowRef = @n_RowRef

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 60020
         SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAILREF Table. (isp_EPackVas_Update)' 
         GOTO QUIT_SP
      END

      FETCH NEXT FROM @cur_ODR INTO @n_RowRef
                                 ,  @n_QtyToUpdate
   END
QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_EPackVas_Update'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END  

GO