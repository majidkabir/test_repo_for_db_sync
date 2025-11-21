SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPOReplenCfm02                                        */
/* Creation Date: 29-MAR-2022                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-19284 CN Loreal confirm replen update order status      */
/*                                                                      */ 
/* Called By: ispPostGenEOrderReplenWrapper                             */
/*          :                                                           */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 26-Apr-2022 NJOW     1.0   DEVOPS Combine script                     */
/* 02-Aug-2022 WLChooi  1.1   WMS-20378 Remove update TrafficCop (WL01) */
/************************************************************************/
CREATE PROC [dbo].[ispPOReplenCfm02]
           @c_ReplenishmentGroup NVARCHAR(10) 
         , @c_ReplenishmentKey   NVARCHAR(10) 
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt          INT
         , @n_Continue           INT 
         , @c_Orderkey           NVARCHAR(10)
         
   SELECT @b_Success = 1, @n_err = 0, @c_ErrMsg = '', @n_continue = 1, @n_StartTCnt = @@TRANCOUNT
   
   IF EXISTS(SELECT 1 FROM REPLENISHMENT R (NOLOCK) 
             WHERE R.ReplenishmentGroup = @c_ReplenishmentGroup
             AND R.Confirmed IN ('N', 'L'))
   BEGIN
   	 GOTO QUIT_SP
   END

   DECLARE CUR_REPLEN CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT PT.Orderkey
      FROM PACKTASK PT (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PT.Orderkey = O.Orderkey
      WHERE PT.ReplenishmentGroup = @c_ReplenishmentGroup
      AND O.Status < '3'

   OPEN CUR_REPLEN 

   FETCH NEXT FROM CUR_REPLEN INTO @c_Orderkey 

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
   BEGIN   
   	  UPDATE ORDERS WITH (ROWLOCK)
   	  SET Status = '3'--, Trafficcop = NULL   --WL01
   	  WHERE Orderkey = @c_Orderkey
        AND [Status] < '3'   --WL01

      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 62300
         SET @c_ErrMsg = 'NSQL' +CONVERT(CHAR(5), @n_Err) + ': Update Order Table Fail. (ispPOReplenCfm02)'
      END
   	  
      FETCH NEXT FROM CUR_REPLEN INTO @c_Orderkey 
   END
   CLOSE CUR_REPLEN
   DEALLOCATE CUR_REPLEN
   
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPOReplenCfm02'
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

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
   RETURN
END -- procedure

GO