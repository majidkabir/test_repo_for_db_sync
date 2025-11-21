SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispMBPRF02                                                  */
/* Creation Date: 25-JUN-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: MBOL Recalculate;                                           */
/*        : SOS#346256 - Project Merlion - Mbol Case Count Add On       */
/* Called By: ispPreRefreshWrapper                                      */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispMBPRF02] 
            @c_MBOLKey     NVARCHAR(10) 
         ,  @b_Success     INT = 0  OUTPUT 
         ,  @n_err         INT = 0  OUTPUT 
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_CustCnt         INT
         , @n_Casecnt         FLOAT
         , @n_PalletCnt       FLOAT
         , @n_StdGrossWgt     FLOAT
         , @n_TotalWeight     FLOAT
         , @n_TotalCube       FLOAT

         , @n_Weight          FLOAT
         , @n_Cube            FLOAT

         , @c_Orderkey        NVARCHAR(10)
         , @c_MBOLLineNumber  NVARCHAR(5)
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
  
   BEGIN TRAN

   SET @n_CustCnt = 0
   SET @n_Casecnt = 0.00
   SET @n_PalletCnt = 0.00
   SELECT @n_CustCnt = COUNT(DISTINCT ORDERS.ConsigneeKey)
        , @n_Casecnt = ISNULL(SUM((ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / 
                       CASE WHEN PACK.Casecnt = 0 THEN NULL ELSE PACK.Casecnt END ),0)
        , @n_PalletCnt=ISNULL(SUM((ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) / 
                    CASE WHEN PACK.Pallet = 0 THEN 1 ELSE PACK.Pallet END),0)
   FROM MBOLDETAIL  WITH (NOLOCK)
   JOIN ORDERS      WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERDETAIL.Orderkey)
   JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                  AND(ORDERDETAIL.Sku = SKU.Sku)
   JOIN PACK        WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey  

   DECLARE CUR_OD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT MBOLDETAIL.Orderkey
         ,MBOLDETAIL.MBOLLineNumber 
   FROM MBOLDETAIL  WITH (NOLOCK)
   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey 

   OPEN CUR_OD

   FETCH NEXT FROM CUR_OD INTO @c_Orderkey
                              ,@c_MBOLLineNumber

   WHILE @@FETCH_STATUS <> -1 AND @n_continue = 1
   BEGIN
      SET @n_Weight = 0
      SET @n_Cube   = 0

      SELECT @n_Weight = ISNULL(SUM((ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) * SKU.StdGrossWgt),0) 
            ,@n_Cube   = ISNULL(SUM((ORDERDETAIL.ShippedQty + ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked) * SKU.StdCube),0)
      FROM ORDERDETAIL WITH (NOLOCK)  
 JOIN SKU         WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)
                                     AND(ORDERDETAIL.Sku = SKU.Sku)
      WHERE ORDERDETAIL.Orderkey = @c_Orderkey

      UPDATE MBOLDETAIL WITH (ROWLOCK)
      SET Weight = @n_Weight
         ,Cube   = @n_Cube
         ,Trafficcop = NULL
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
      WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey 
      AND   MBOLDETAIL.MBOLLineNumber = @c_MBOLLineNumber

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert MBOLDETAIL Failed. (ispMBPRF02)' 
         GOTO QUIT
      END 

      FETCH NEXT FROM CUR_OD INTO @c_Orderkey
                               ,  @c_MBOLLineNumber
   END
   CLOSE CUR_OD
   DEALLOCATE CUR_OD

   SET @n_TotalWeight = 0
   SET @n_TotalCube   = 0
   SELECT @n_TotalWeight = ISNULL(SUM(Weight),0)
         ,@n_TotalCube   = ISNULL(SUM(Cube),0)
   FROM MBOLDETAIL  WITH (NOLOCK)
   WHERE MBOLDETAIL.MBOLKey = @c_MBOLKey 

   UPDATE MBOL WITH (ROWLOCK)
   SET CustCnt   = @n_CustCnt
      ,CaseCnt   = @n_Casecnt
      ,PalletCnt = @n_PalletCnt
      ,Weight    = @n_TotalWeight
      ,Cube      = @n_TotalCube
      ,Trafficcop = NULL
      ,EditWho    = SUSER_NAME()
      ,EditDate   = GETDATE()
   WHERE MBOLKey = @c_MBOLKey   


   SET @n_err = @@ERROR   

   IF @n_err <> 0    
   BEGIN  
      SET @n_continue = 3    
      SET @n_err = 61010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert MBOL Failed. (ispMBPRF02)' 
      GOTO QUIT
   END 
   
QUIT:
   IF CURSOR_STATUS( 'LOCAL', 'CUR_OD') in (0 , 1)  
   BEGIN
      CLOSE CUR_OD
      DEALLOCATE CUR_OD
   END

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispMBPRF02'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO