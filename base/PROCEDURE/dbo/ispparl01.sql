SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispPARL01                                          */
/* Creation Date: 18-Sep-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#255755 - Release PA Tasks                               */
/*                                                                      */
/* Input Parameters:  @c_ReceiptKey                                     */
/*                                                                      */
/* Output Parameters:  @b_Success                                       */
/*                   , @n_err                                           */
/*                   , @c_errmsg                                        */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: isp_ASNReleasePATask_Wrapper                              */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 30-Aug-2013  Shong    1.1  Default Priority to 5 instead of 9        */
/* 14-Sep-2021  SYChua   1.2  JSM-20558: Fix Performance issue (SY01)   */
/************************************************************************/

CREATE PROC [dbo].[ispPARL01]
   @c_ReceiptKey  NVARCHAR(10),
   @b_Success     INT OUTPUT,
   @n_err         INT OUTPUT,
   @c_errmsg      NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON       -- SQL 2005 Standard
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue        INT
         , @n_StartTCnt       INT
         , @n_NoOfTasks       INT
         , @c_TaskDetailKey   NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)
         , @c_SourceKey       NVARCHAR(30)
         , @c_PickMethod      NVARCHAR(10)
         , @c_ToID            NVARCHAR(18)
         , @c_ToLoc           NVARCHAR(10)
         , @c_ToLogicalLoc    NVARCHAR(18)

   SET @n_StartTCnt     =  @@TRANCOUNT
   SET @n_continue      = 1
   SET @n_NoOfTasks     = 0
   SET @c_TaskDetailKey = ''
   SET @c_Storerkey     = ''
   SET @c_SourceKey     = ''
   SET @c_PickMethod    = ''
   SET @c_ToID          = ''
   SET @c_ToLoc         = ''
   SET @c_ToLogicalLoc  = ''

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END

   DECLARE CursorASNDetail CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT RTRIM(RD.Storerkey)
         ,MIN(RTRIM(RD.ReceiptKey) + RTRIM(RD.ReceiptLineNumber))
         ,CASE WHEN COUNT(DISTINCT CASE WHEN UCC.UCCNo IS NULL THEN RD.SKU ELSE UCC.SKU END) <= 1 AND
                    COUNT(DISTINCT CASE WHEN UCC.UCCNo IS NULL THEN 0 ELSE UCC.QTY END)  <= 1 THEN 'FP' ELSE 'PP' END
         ,CASE WHEN UCC.UCCNo IS NULL THEN RTRIM(RD.ToID) ELSE RTRIM(UCC.ID) END
         ,CASE WHEN UCC.UCCNo IS NULL THEN RTRIM(RD.ToLoc) ELSE RTRIM(UCC.Loc) END
         ,ISNULL(RTRIM(LOC.LogicalLocation),'')
   FROM ReceiptDetail RD WITH (NOLOCK)
   JOIN LOC LOC  WITH (NOLOCK) ON (RD.Toloc = LOC.Loc)
--   JOIN ITRN     WITH (NOLOCK) ON (RD.ReceiptKey + RD.ReceiptLineNumber = ITRN.SourceKey)
--                               AND(RD.ToLoc = ITRN.ToLoc)
--                               AND(RD.ToID  = ITRN.ToID)
--                               AND(ITRN.TranType = 'DP')
--                               AND(ITRN.SourceType Like 'ntrReceiptDetail%')
--   LEFT JOIN UCC WITH (NOLOCK) ON (UCC.Lot= ITRN.Lot)
--                               AND(UCC.Loc= RD.ToLoc)
--                               AND(UCC.ID = RD.ToID)
   LEFT JOIN UCC WITH (NOLOCK) ON (UCC.UCCNo = RD.UserDefine01 AND ISNULL(RTRIM(RD.UserDefine01),'') <> '')
   WHERE RD.ReceiptKey = @c_ReceiptKey
   AND   RD.FinalizeFlag = 'Y'
   AND   RD.QtyReceived > 0
   AND   ((UCC.UCCNo IS NOT NULL AND RTRIM(UCC.ID) <> '' AND UCC.ID IS NOT NULL) OR
          (UCC.UCCNo IS NULL AND RTRIM(RD.ToID) <> '' AND RD.ToID IS NOT NULL))
   AND   NOT EXISTS (SELECT 1 FROM TASKDETAIL WITH (NOLOCK) WHERE --SourceKey like RTRIM(RD.ReceiptKey) + '%'  --(SY01)
                     LEFT(RTRIM(SourceKey), 10) = RTRIM(RD.ReceiptKey)   --(SY01)
                     AND FromID = CASE WHEN UCC.UCCNo IS NULL THEN RTRIM(RD.ToID) ELSE RTRIM(UCC.ID) END
                     AND TaskType = 'PAF')
   GROUP BY RTRIM(RD.Storerkey)
         ,  CASE WHEN UCC.UCCNo IS NULL THEN RTRIM(RD.ToID) ELSE RTRIM(UCC.ID) END
         ,  CASE WHEN UCC.UCCNo IS NULL THEN RTRIM(RD.ToLoc) ELSE RTRIM(UCC.Loc) END
         ,  ISNULL(RTRIM(LOC.LogicalLocation),'')

   OPEN CursorASNDetail

   FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      EXECUTE nspg_GetKey
             'TaskDetailKey'
            ,10
            ,@c_TaskDetailKey OUTPUT
            ,@b_success       OUTPUT
            ,@n_err           OUTPUT
            ,@c_errmsg        OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 30101
         SET @c_Errmsg = 'NSQL'+CONVERT(CHAR(5),@n_err)+': Error Getting New TaskDetailKey. (ispPARL01)'
         GOTO QUIT_SP
      END

      INSERT INTO TASKDETAIL
             (    TaskDetailKey
               ,  Storerkey
               ,  TaskType
               ,  Fromloc
               ,  LogicalFromLoc
               ,  FromID
               ,  PickMethod
               ,  Status
               ,  Priority
               ,  SourcePriority
               ,  SourceType
               ,  SourceKey
             )
      VALUES (    @c_TaskdetailKey
               ,  @c_Storerkey
               ,  'PAF'
               ,  @c_Toloc
               ,  @c_ToLogicalLoc
               ,  @c_ToID
               ,  @c_PickMethod
               ,  '0'
               ,  '5'
               ,  '9'
               ,  'ispPARL01'
               ,  @c_Sourcekey
             )

      SET @n_NoOfTasks = @n_NoOfTasks + 1
      FETCH NEXT FROM CursorASNDetail INTO @c_Storerkey, @c_SourceKey, @c_PickMethod, @c_ToID, @c_ToLoc, @c_ToLogicalLoc
   END
   QUIT_SP:
   CLOSE CursorASNDetail
   DEALLOCATE CursorASNDetail

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
      execute nsp_logerror @n_err, @c_errmsg, 'ispPARL01'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      IF @n_NoOfTasks > 0
      BEGIN
         SET @c_errmsg = 'Total ' +CONVERT(NVARCHAR(5), @n_NoOfTasks)+ ' Putaway From tasks released sucessfully.'
      END
      ELSE
      BEGIN
         SET @c_errmsg = 'No Putaway From tasks released.'
      END

      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO