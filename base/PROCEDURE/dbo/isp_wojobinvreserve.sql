SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store Procedure: isp_WOJobInvReserve                                    */
/* Creation Date: 07-Dec-2012                                              */
/* Copyright: LF                                                           */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose:  Reserve inv for Work Order Job                                */
/*                                                                         */
/* Called By: PB: Work ORder Job - RMC Reserve                             */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author   Ver. Purposes                                     */
/* 26-JAN-2016  YTWan    1.1  SOS#315603 - Project Merlion - VAP SKU       */
/*                            Reservation Strategy - MixSku in 1 Pallet    */
/*                            enhancement                                  */	
/***************************************************************************/
CREATE PROC [dbo].[isp_WOJobInvReserve]
           @c_JobKey          NVARCHAR(10) 
         , @b_Success         INT            OUTPUT            
         , @n_err             INT            OUTPUT          
         , @c_errmsg          NVARCHAR(255)  OUTPUT  
AS
BEGIN 
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue     INT                     
         , @n_StartTCnt    INT            -- Holds the current transaction count    

   DECLARE @c_WOMoveKey    NVARCHAR(10)
         , @c_JobLineNo    NVARCHAR(5)
         , @n_StepQty      INT
         , @n_QtyReserved  INT
         , @n_QtyToMove    INT
         , @n_JobStepQty   INT
         , @n_JobResvQty   INT

         , @c_JobStatus    NVARCHAR 
         , @c_SourceKey    NVARCHAR(20)

   SET @n_Continue         = 1
   SET @n_StartTCnt        = @@TRANCOUNT  
   SET @b_Success          = 1
   SET @n_Err              = 0
   SET @c_errmsg           = ''  

   SET @c_WOMoveKey        = ''
   SET @c_JobLineNo        = ''
   SET @n_StepQty          = 0
   SET @n_QtyReserved      = 0
   SET @n_QtyToMove        = 0
   SET @n_JobStepQty       = 0
   SET @n_JobResvQty       = 0

   SET @c_JobStatus        = '2'
   SET @c_SourceKey        = ''

   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END

   EXECUTE isp_WOInvReserveProcessing 
           @c_JobKey    
         , @b_Success   OUTPUT            
         , @n_err       OUTPUT          
         , @c_errmsg    OUTPUT  

   IF @b_Success = 0 
   BEGIN
      SET @n_continue= 3
      SET @n_err     = 63701  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Error Execute isp_WOInvReserveProcessing. (isp_WOJobInvReserve)' 
      GOTO QUIT
   END
/*
   IF NOT EXISTS (SELECT 1
                  FROM WORKORDERJOBMOVE WITH (NOLOCK)
                  WHERE JobKey = @c_JobKey
                  AND Status = '0')
   BEGIN
      GOTO QUIT
   END

   BEGIN TRAN
   DECLARE WOJO_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ISNULL(RTRIM(JobLine),'')
         ,ISNULL(StepQty,0)
         ,ISNULL(QtyReserved ,0)
   FROM WORKORDERJOBOPERATION WOJO WITH (NOLOCK)
   JOIN SKU                   SKU  WITH (NOLOCK) ON (WOJO.Storerkey = SKU.Storerkey)
                                                 AND(WOJO.Sku = SKU.Sku)
   WHERE Jobkey = @c_jobKey

   OPEN WOJO_CUR
   FETCH NEXT FROM WOJO_CUR INTO @c_JobLineNo
                              ,  @n_StepQty
                              ,  @n_QtyReserved 

   WHILE (@@FETCH_STATUS <> -1)
   BEGIN 
      SELECT @n_QtyToMove = ISNUll(SUM(Qty),0) 
      FROM WORKORDERJOBMOVE WITH (NOLOCK)
      WHERE Jobkey = @c_jobKey
      AND   JobLine= @c_JobLineNo
      AND   Status = '0'
  
      UPDATE WORKORDERJOBMOVE WITH (ROWLOCK)
      SET Status      = '9'
         ,EditWho     = SUSER_NAME()
         ,EditDate    = GETDATE()
         ,Trafficcop  = NULL  
      WHERE Jobkey = @c_jobKey
      AND   JobLine= @c_JobLineNo
      AND   Status = '0'

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63703  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBMOVE. (isp_WOJobInvReserve)' 
         GOTO QUIT
      END

      SET @n_QtyReserved= @n_QtyReserved + @n_QtyToMove
      SET @n_JobStepQty = @n_JobStepQty + @n_StepQty
      SET @n_JobResvQty = @n_JobResvQty + @n_QtyReserved
--      SET @c_JobStatus  = CASE WHEN @n_QtyReserved = 0 THEN '0'
--                               WHEN @n_StepQty >  @n_QtyReserved THEN '1' 
--                               WHEN @n_StepQty <= @n_QtyReserved THEN '2'
--                               END

      UPDATE WORKORDERJOBOPERATION WITH (ROWLOCK)
      SET QtyReserved = @n_QtyReserved
--         ,JobStatus   = @c_JobStatus
         ,EditWho     = SUSER_NAME()
         ,EditDate    = GETDATE()
--         ,Trafficcop  = NULL 
      WHERE JobKey = @c_JobKey
      AND   JobLine= @c_JobLineNo

      SET @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SET @n_continue= 3
         SET @n_err     = 63704  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBOPERATION. (isp_WOJobInvReserve)' 
         GOTO QUIT
      END

      FETCH NEXT FROM WOJO_CUR INTO @c_JobLineNo
                                 ,  @n_StepQty
                                 ,  @n_QtyReserved
   END 
   CLOSE WOJO_CUR
   DEALLOCATE WOJO_CUR

   
--   SET @c_JobStatus  = CASE WHEN @n_JobResvQty = 0 THEN '0'
--                            WHEN @n_JobStepQty >  @n_JobResvQty THEN '1' 
--                            WHEN @n_JobStepQty <= @n_JobResvQty THEN '2'
--                            END

--   UPDATE WORKORDERJOBDETAIL WITH (ROWLOCK)
--   SET JobStatus = @c_JobStatus
--      ,QtyItemsRes = @n_JobResvQty  
--      ,QtyItemsNeed= QtyItemsOrd - @n_JobResvQty
--      ,EditWho      = SUSER_NAME()
--      ,EditDate     = GETDATE()
--      ,Trafficcop   = NULL  
--   WHERE JobKey = @c_JobKey
--
--   SET @n_err = @@ERROR
--
--   IF @n_err <> 0
--   BEGIN
--      SET @n_continue= 3
--      SET @n_err     = 63706  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
--      SET @c_errmsg  = 'NSQL'+CONVERT(CHAR(5),ISNULL(@n_err,0))+': Update Failed On Table WORKORDERJOBDETAIL. (isp_WOJobInvReserve)' 
--      GOTO QUIT
--   END

   COMMIT TRAN
*/
   QUIT:

   WHILE @@TRANCOUNT < @n_StartTCnt 
   BEGIN
      BEGIN TRAN
   END 

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_WOJobInvReserve'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END  
END

GO