SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPostReplen02                                         */
/* Creation Date: 20-Feb-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-12057 - [CN]Levis WMS Inventory Replenishment(CR)       */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispPostReplen02]
           @c_Replenishmentkey   NVARCHAR(10) 
         , @b_Success            INT            OUTPUT
         , @n_Err                INT            OUTPUT
         , @c_ErrMsg             NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @n_UCC_RowRef      INT          = 0
         , @c_Storerkey       NVARCHAR(15) = ''
         , @c_Lot             NVARCHAR(10) = ''
         , @c_Loc             NVARCHAR(10) = ''
         , @c_ID              NVARCHAR(18) = ''
         , @c_UOM             NVARCHAR(10) = ''
         , @c_Wavekey         NVARCHAR(10) = ''
         , @c_WaveType        NVARCHAR(10) = ''
         , @c_Datawindow      NVARCHAR(60) = ''
         , @c_Loadkey         NVARCHAR(10) = ''

         , @CUR_UCC           CURSOR

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   SELECT
         @c_Storerkey= R.Storerkey
      ,  @c_Lot = R.Lot
      ,  @c_Loc = R.FromLoc
      ,  @c_ID  = R.ID
      ,  @c_Wavekey = R.Wavekey
      ,  @c_WaveType = W.WaveType
   FROM REPLENISHMENT R (NOLOCK)  
   JOIN WAVE W (NOLOCK) ON R.Wavekey = W.Wavekey  
   WHERE R.Replenishmentkey = @c_Replenishmentkey  

   IF @c_WaveType <> 'B2B-P'
   BEGIN
      GOTO QUIT_SP
   END

   BEGIN TRAN

   -- UPDATE PackStation (UOM = '2') And Replenishment UCC.Status = '6'
   SET @CUR_UCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT UCC_RowRef, PD.UOM 
   FROM   PICKDETAIL PD WITH (NOLOCK)
   JOIN   WAVEDETAIL WD WITH (NOLOCK) ON PD.Orderkey = WD.Orderkey
   JOIN   UCC WITH (NOLOCK) ON UCC.UCCNo = PD.DropID AND UCC.[Status] = '5'
   WHERE  WD.Wavekey = @c_Wavekey
   AND    PD.UOM = '2'
   UNION     
   SELECT UCC_RowRef, UOM ='6,7'
   FROM UCC (NOLOCK)
   WHERE Storerkey = @c_Storerkey
   AND   Lot = @c_Lot
   AND   Loc = @c_Loc
   AND   ID  = @c_ID 
   AND   UserDefined10 = @c_Replenishmentkey
   AND   UCC.[Status] = '5'
   ORDER BY UOM, UCC_RowRef   

   OPEN @CUR_UCC
   
   FETCH NEXT FROM @CUR_UCC INTO @n_UCC_RowRef, @c_UOM 
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @n_UCC_RowRef > 0
      BEGIN
         UPDATE UCC  
         SET [Status] = '6' 
           , TrafficCop = NULL 
         WHERE UCC_RowRef = @n_UCC_RowRef
         AND [Status] = '5'

         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SET @n_continue = 3  
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
            SET @n_err = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispPostReplen02)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
         END 
      END

      FETCH NEXT FROM @CUR_UCC INTO @n_UCC_RowRef, @c_UOM 
   END
   CLOSE @CUR_UCC
   DEALLOCATE @CUR_UCC

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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPostReplen02'
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
END -- procedure

GO