SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPOA15                                           */
/* Creation Date: 05-Nov-2020                                           */
/* Copyright: LFL                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: WMS-XXXXX - TW Auto Allocation By Order Post Allocate       */
/*                      Update                                          */
/* Called By: nsp_OrderProcessing_Wrapper                               */
/*            StorerConfig.ConfigKey = PostAllocationSP                 */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/* 23-05-2022   Shong   1.1   Update Allocated SKU                      */
/************************************************************************/
CREATE   PROC [dbo].[ispPOA15]
     @c_OrderKey    NVARCHAR(10) = ''
   , @c_LoadKey     NVARCHAR(10) = ''
   , @c_Wavekey     NVARCHAR(10) = ''
   , @b_Success     INT           OUTPUT
   , @n_Err         INT           OUTPUT
   , @c_ErrMsg      NVARCHAR(250) OUTPUT
   , @b_debug       INT = 0
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_Continue              INT,
            @n_StartTCnt             INT, -- Holds the current transaction count
            @c_Pickdetailkey         NVARCHAR(10),
            @c_Status                NVARCHAR(10),
            @c_Putawayzone           NVARCHAR(4000),
            @n_RowRef                BIGINT,
            @n_AllocatedSKU          INT

   SELECT @n_StartTCnt=@@TRANCOUNT , @n_Continue=1, @b_Success=1, @n_Err=0, @c_ErrMsg=''

   SELECT TOP 1 @n_RowRef = RowRef
   FROM dbo.AutoAllocBatchDetail (NOLOCK)
   WHERE OrderKey = @c_OrderKey
   AND Status in ('0', '1')
   ORDER BY RowRef DESC

   IF @n_continue IN (1,2)
   BEGIN
      SET @c_Status = '0'

      SELECT @c_Status = [Status]
      FROM dbo.ORDERS WITH (NOLOCK)
      WHERE OrderKey = @c_OrderKey

      SET @n_AllocatedSKU = 0
      SELECT @n_AllocatedSKU = COUNT(DISTINCT SKU)  
      FROM dbo.ORDERDETAIL AS OD WITH (NOLOCK)  
      WHERE OD.OrderKey = @c_OrderKey    
      AND (OD.QtyAllocated + OD.QtyPicked) > 0

      UPDATE dbo.AutoAllocBatchDetail WITH (ROWLOCK)  
         SET SKUAllocated = @n_AllocatedSKU, 
             NoStockFound = CASE WHEN @n_AllocatedSKU = 0 THEN 1 ELSE 0 END,
             EditDate = GETDATE()
      WHERE RowRef = @n_RowRef  

      IF @c_Status IN ('1','2')
      BEGIN
         EXEC [dbo].[isp_UpdateAutoAllocBatchDetail_Status]
           @n_AABD_RowRef = @n_RowRef,
           @c_Status = '9',
           @n_Err    = @n_Err    OUTPUT,
           @c_ErrMsg = @c_ErrMsg OUTPUT
      END
   END


EXIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ispPOA15'
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

END -- Procedure

GO