SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_KioskASRSAlertSupv                             */
/* Creation Date: 28-Jan-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Confirm CC Task - Task Completed;                           */
/*        : SOS#315024 - Project Merlion - Exceed Call Out Inspection   */
/* Called By:                                                           */
/*          : w_gtm_kiosk.ue_alertsupv event                            */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 21-Dec-2015  TKLIM   1.0   Add Storerkey on the Email Title (TK01)   */
/************************************************************************/
CREATE PROC [dbo].[isp_KioskASRSAlertSupv] 
            @c_Jobkey         NVARCHAR(10)  
         ,  @c_id             NVARCHAR(18)
         ,  @b_hold           INT = 1
         ,  @c_alertcode      NVARCHAR(30) = 'SHORT/DMG'
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(255) = '' OUTPUT
         ,  @b_debug          INT = 0 
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_GTMWorkStation  NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_Taskdetailkey   NVARCHAR(10)
         , @c_TaskType        NVARCHAR(10)
        
         , @c_InvHoldStatus   NVARCHAR(10)   
         , @c_AlertMessage    NVARCHAR(255)
         , @c_Activity        NVARCHAR(60)

         , @c_Recipients      NVARCHAR(MAX)
         , @c_Subject         NVARCHAR(MAX)
         , @c_Body            NVARCHAR(255) 
         , @c_fromid          NVARCHAR(18)
         , @c_toid            NVARCHAR(18)

 

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_GTMWorkStation = ''
  
   DECLARE @tError TABLE(
      ErrMsg  NVARCHAR(255)
   )
   
   SET @c_TaskdetailKey = ''

   SELECT @c_TaskDetailKey = RefTaskkey
         ,@c_GTMWorkStation= UserPosition
         ,@c_fromid = FromID
         ,@c_toid = ToID
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailKey = @c_Jobkey
   AND   TaskType = 'GTMJOB'

   SELECT @c_TaskType  = TaskType
   FROM TASKDETAIL WITH (NOLOCK)
   WHERE TaskDetailKey = @c_TaskDetailKey

   SELECT @c_Activity = Description 
   FROM CODELKUP WITH (NOLOCK) 
   WHERE CODELKUP.ListName = 'Tasktype'
   AND   CODELKUP.Code = @c_TaskType
   
   SELECT @c_Storerkey = Storerkey
   FROM LOTxLOCxID WITH (NOLOCK)
   WHERE ID IN (@c_fromid, @c_toid)
   AND Qty > 0

   SET @c_AlertMessage = @c_errmsg

   BEGIN TRAN
   -- Hold the ID
   IF @b_hold = 1 
   BEGIN
      SET @c_InvHoldStatus = @c_alertcode 
      IF EXISTS (SELECT 1 FROM InventoryHold where id = @c_ID AND Hold = '1')
      BEGIN
         UPDATE INVENTORYHOLD WITH (ROWLOCK)
         SET Status = @c_InvHoldStatus
         ,   Trafficcop= NULL
         WHERE ID = @c_ID

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62005
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':  Update hold status Fail on Table INVENTORYHOLD. (isp_KioskASRSAlertSupv)' 
                                + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         EXEC nspInventoryHoldWrapper
                     '',               -- lot
                     '',               -- loc
                     @c_ID,            -- id
                     '',               -- storerkey
                     '',               -- sku
                     '',               -- lottable01
                     '',               -- lottable02
                     '',               -- lottable03
                     NULL,             -- lottable04
                     NULL,             -- lottable05
                     '',               -- lottable06
                     '',               -- lottable07    
                     '',               -- lottable08
                     '',               -- lottable09
                     '',               -- lottable10
                     '',               -- lottable11
                     '',               -- lottable12
                     NULL,             -- lottable13
                     NULL,             -- lottable14
                     NULL,             -- lottable15
                     @c_InvHoldStatus, -- status  
                     '1',              -- hold
                     @b_success OUTPUT,
                     @n_err OUTPUT,
                     @c_errmsg OUTPUT,
                     '' -- remark

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 62010
            SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+': Hold Inventory ID Fail. (isp_KioskASRSAlertSupv)' 
                                + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
            GOTO QUIT_SP
         END
      END
   END

   EXEC nspLogAlert
         @c_modulename       = 'isp_KioskASRSAlertSupv'
       , @c_AlertMessage     = @c_AlertMessage
       , @n_Severity         = '5'
       , @b_success          = @b_success    OUTPUT
       , @n_err              = @n_Err        OUTPUT
       , @c_errmsg           = @c_ErrMsg     OUTPUT
       , @c_Activity         = @c_Activity
       , @c_Storerkey        = @c_Storerkey
       , @c_SKU              = ''
       , @c_UOM              = ''
       , @c_UOMQty           = ''
       , @c_Qty              = 0
       , @c_Lot              = ''
       , @c_Loc              = ''
       , @c_ID               = @c_ID
       , @c_TaskDetailKey    = @c_TaskDetailKey 
       , @c_UCCNo            = ''

   IF @b_success <> 1 
   BEGIN
      SET @n_Continue=3
      SET @n_err = 62015
      SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Error executing nspLogAlert. (isp_KioskASRSAlertSupv)'
                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
      GOTO QUIT_SP
   END

   INSERT INTO @tERROR VALUES (@c_AlertMessage)
   IF @@ERROR <> 0
   BEGIN
      SET @n_Continue=3
      SET @n_err = 62020
      SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'INSERT INTO @tERROR Fail. (isp_KioskASRSAlertSupv)'
      GOTO QUIT_SP
   END

   IF @b_debug = 1 
   BEGIN
      SELECT @c_Storerkey '@c_Storerkey'
   END

   IF NOT EXISTS (SELECT 1
                  FROM CODELKUP WITH (NOLOCK)
                  WHERE ListName = 'EmailAlert'
                  AND   Code = 'isp_KioskASRSAlertSupv'
                  AND   StorerKey = @c_Storerkey
                 )
   BEGIN
      SET @c_Storerkey = ''
   END

   SELECT @c_Recipients = CASE WHEN ISNULL(UDF01,'') <> '' THEN RTRIM(UDF01) + ';' ELSE '' END 
                        + CASE WHEN ISNULL(UDF02,'') <> '' THEN RTRIM(UDF02) + ';' ELSE '' END  
                        + CASE WHEN ISNULL(UDF03,'') <> '' THEN RTRIM(UDF03) + ';' ELSE '' END  
                        + CASE WHEN ISNULL(UDF04,'') <> '' THEN RTRIM(UDF04) + ';' ELSE '' END 
                        + CASE WHEN ISNULL(UDF05,'') <> '' THEN RTRIM(UDF05) + ';' ELSE '' END 
   FROM CODELKUP WITH (NOLOCK)
   WHERE ListName = 'EmailAlert'
   AND   Code = 'isp_KioskASRSAlertSupv'
   AND   StorerKey = @c_Storerkey

   IF ISNULL(@c_Recipients, '') <> ''
   BEGIN
      SET @c_Subject = @c_Storerkey + ' - Kiosk Supervisor Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')    --(TK01)
      SET @c_Body = '<table border="1" cellspacing="0" cellpadding="5">' +
          '<tr bgcolor=silver><th>Error</th></tr>' + CHAR(13) +
          CAST ( ( SELECT td = ISNULL(ErrMsg,'')
                   FROM @tERROR 
              FOR XML PATH('tr'), TYPE
          ) AS NVARCHAR(MAX) ) + '</table>' ;

      IF @b_debug = 0 
      BEGIN
         EXEC msdb.dbo.sp_send_dbmail
            @recipients      = @c_Recipients,
            @copy_recipients = NULL,
            @subject         = @c_Subject,
            @body            = @c_Body,
            @body_format     = 'HTML' ;

         IF @@ERROR <> 0
         BEGIN
            SET @n_Continue=3
            SET @n_err = 62030
            SET @c_Errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+ 'Error executing sp_send_dbmail. (isp_KioskASRSAlertSupv)'
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         SELECT @c_Storerkey 'SEND Email'
      END
   END -- IF ISNULL(@cRecipients, '') <> ''

   UPDATE ID WITH (ROWLOCK)
   SET PalletFlag2 = 'ALERTSUPV'
      ,EditWho = SUSER_NAME()
      ,EditDate= GETDATE()
      ,Trafficcop = NULL
   WHERE ID = @c_ID

   SET @n_err = @@ERROR

   IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 62035
      SET @c_ErrMsg='NSQL'+CONVERT(char(5),@n_err)+':  Update hold status Fail on ID Table. (isp_KioskASRSAlertSupv)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + RTrim(@c_ErrMsg) + ' ) '
      GOTO QUIT_SP
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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_KioskASRSAlertSupv'
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