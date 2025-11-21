SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ispBatPA01                                                  */
/* Creation Date: 28-OCT-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 26-Apr-2016  Leong         IN00026886 - TraceInfo.                   */
/* 17-Jan-2017  TLTING        performance tune                          */
/************************************************************************/

CREATE PROC [dbo].[ispBatPA01]
            @c_ReceiptKey  NVARCHAR(10)
         ,  @b_Success     INT = 0  OUTPUT
         ,  @n_err         INT = 0  OUTPUT
         ,  @c_errmsg      NVARCHAR(215) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

   DECLARE
            @n_StartTCnt         INT
         ,  @n_Continue          INT
         ,  @c_Facility          NVARCHAR(5)
         ,  @c_ReceiptLineNumber NVARCHAR(5)
         ,  @c_Storerkey         NVARCHAR(15)
         ,  @c_Sku               NVARCHAR(20)
         ,  @c_Packkey           NVARCHAR(10)
         ,  @c_Lottable01        NVARCHAR(18)
         ,  @c_PutawayZone       NVARCHAR(10)
         ,  @c_PutawayLoc        NVARCHAR(10)
         ,  @n_NoOfPallet        INT
         ,  @n_NoOfPAPallet      INT
         ,  @n_NoOfPalletInLoc   INT
         ,  @n_LocPalletLimit    INT

         ,  @n_MaxPallet         FLOAT

         ,  @b_debug             INT
         ,  @c_ptraceheadkey     NVARCHAR(10)
         ,  @c_ptracedetailkey   NVARCHAR(10)
         ,  @c_PALine            NVARCHAR(5)
         ,  @c_Reason            NVARCHAR(255)
         ,  @c_UserID            NVARCHAR(20)
         ,  @d_Starttime         DATETIME
         ,  @n_LocsReviewed      INT

         ,  @c_TaskdetailKey     NVARCHAR(10)
         ,  @c_LogicalToLoc      NVARCHAR(10)
         ,  @c_LogicalPALoc      NVARCHAR(10)
         ,  @c_ToLoc             NVARCHAR(10)
         ,  @c_ToID              NVARCHAR(18)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''

   IF NOT EXISTS( SELECT 1
                  FROM RECEIPTDETAIL WITH (NOLOCK)
                  WHERE ReceiptKey = @c_Receiptkey
                  AND   FinalizeFlag = 'Y'
                )
   BEGIN
      SET @n_continue = 3
      SET @n_Err    = 65000
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                    + ': ASN Must be finalized.( ispBatPA01 )'

      GOTO QUIT
   END

   IF  EXISTS( SELECT 1
               FROM RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @c_Receiptkey
               AND   BeforeReceivedQty > QtyReceived
             )
   BEGIN
      SET @n_continue = 3
      SET @n_Err    = 65005
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                    + ': There are records pending finalized.( ispBatPA01 )'

      GOTO QUIT
   END

   IF EXISTS(  SELECT 1
               FROM RECEIPTDETAIL WITH (NOLOCK)
            WHERE ReceiptKey = @c_Receiptkey
               AND   FinalizeFlag = 'Y'
               AND   ToId = ''
            )
   BEGIN
      SET @n_continue = 3
      SET @n_Err    = 65010
      SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                    + ': ASN has not exploded packkey yet.( ispBatPA01 )'

      GOTO QUIT
   END

   SET @b_debug = 0
   SELECT @b_debug = CONVERT(INT,NSQLValue)
   FROM NSQLCONFIG WITH (NOLOCK)
   WHERE ConfigKey = 'PutawayTraceReport'

   SET @c_Facility = ''
   SELECT @c_Facility = Facility
   FROM RECEIPT WITH (NOLOCK)
   WHERE ReceiptKey = @c_ReceiptKey

   BEGIN TRAN -- Optional if PB Transaction is AUTOCOMMIT = FALSE. No harm to always start BEGIN TRAN in begining of SP

   DECLARE CUR_PA CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Storerkey
         ,Sku
         ,Lottable01
         ,NoOfPallet = COUNT(1)
   FROM RECEIPTDETAIL WITH (NOLOCK)
   WHERE ReceiptKey = @c_Receiptkey
   AND PutawayLoc = ''
   AND QtyReceived > 0
   GROUP BY Storerkey
         ,  Sku
         ,  Lottable01
   ORDER BY Storerkey
         ,  Sku
         ,  Lottable01

   OPEN CUR_PA

   FETCH NEXT FROM CUR_PA INTO   @c_Storerkey
                              ,  @c_Sku
                              ,  @c_Lottable01
                              ,  @n_NoOfPallet

   WHILE @@FETCH_STATUS <> -1 AND  (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN

      SELECT @c_PutawayZone = SKU.PutawayZone
            ,@c_Packkey     = SKU.Packkey
      FROM SKU WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey
      AND   Sku = @c_Sku

      SET @n_LocsReviewed = 0
      -- insert records into PTRACEHEAD table
      IF @b_debug = 1
      BEGIN
         SET @c_UserID   = SUSER_NAME()
         SET @d_starttime= GETDATE()
         EXEC nspPTH @c_PTracetype  = 'ispBatPA01'
                  ,  @c_userid      = @c_UserID
                  ,  @c_StorerKey   = @c_Storerkey
                  ,  @c_sku         = @c_Sku
                  ,  @c_lot         = ''
                  ,  @c_id          = ''
                  ,  @c_Packkey     = @c_Packkey
                  ,  @n_qty         = @n_NoOfPallet
                  ,  @b_pa_multiproduct  = 0
                  ,  @b_pa_multilot      = 0
                  ,  @d_Starttime        = @d_Starttime
                  ,  @d_endtime          = NULL
                  ,  @n_pa_locsreviewed  = 0
                  ,  @c_pa_locfound      = ''
                  ,  @n_ptraceheadkey    = @c_ptraceheadkey OUTPUT
      END

      WHILE @n_NoOfPallet > 0 AND (@n_Continue = 1 OR @n_Continue = 2)
      BEGIN
         SET @n_MaxPallet = 0
         SET @n_NoOfPalletInLoc = 0
         SET @c_putawayloc = ''
         -- 1)  Find Friend
         SET @c_PALine = '00001'
         IF @b_debug = 1
         BEGIN
            -- Insert records into PTRACEDETAIL table
            SET @c_reason = 'Find Friends. Remain ' + CONVERT(NVARCHAR(5), @n_NoOfPallet) + ' Pallet to PA.'
            EXEC nspPTD @c_ptracetype                 = 'ispBatPA01'
                     ,  @n_ptraceheadkey              = @c_ptraceheadkey
                     ,  @c_pa_putawaystrategykey      = 'Custom'
                     ,  @c_pa_putawaystrategylinenmbr = @c_PALine
                     ,  @n_ptracedetailkey            = ''
                     ,  @c_lockey                     = ''
                     ,  @c_reason                     = @c_reason
         END

         SET @n_NoOfPAPallet = 0
         SELECT TOP 1
              @n_NoOfPalletInLoc = ISNULL(COUNT(DISTINCT LOTxLOCxID.ID),0)
            , @c_PutawayLoc = LOC.Loc
            , @n_MaxPallet  = LOC.MaxPallet
         FROM LOTxLOCxID   WITH (NOLOCK)
         JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTxLOCxID.Lot = LOTATTRIBUTE.Lot)
         JOIN LOC          WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
         WHERE LOTATTRIBUTE.Storerkey = @c_Storerkey
         AND   LOTATTRIBUTE.Sku       = @c_Sku
         AND   LOTATTRIBUTE.Lottable01= @c_Lottable01
         AND   LOC.PutawayZone = @c_PutawayZone
         AND   LOC.Facility    = @c_Facility
         AND   LOC.LocationRoom= @c_Storerkey                        --(Wan)
         AND   ((LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated) > 0 OR
                 LOTxLOCxID.PendingMoveIn > 0 )
         AND   EXISTS ( SELECT 1
                        FROM LOTxLOCxID   LLI  WITH (NOLOCK)
                        JOIN LOTATTRIBUTE LA   WITH (NOLOCK) ON (LLI.Lot = LA.Lot)
                        WHERE LLI.Loc = LOC.Loc
                        GROUP BY LLI.Loc
                        HAVING COUNT( DISTINCT LA.Storerkey ) = 1
                           AND COUNT( DISTINCT LA.Sku ) = 1
                           AND COUNT( DISTINCT LA.Lottable01 ) = 1
                       )
         GROUP BY LOC.LOC
               ,  LOC.PALogicalLoc
               ,  LOC.MaxPallet
         HAVING LOC.MaxPallet > ISNULL(COUNT(DISTINCT LOTxLOCxID.ID),0)
         ORDER BY LOC.PALogicalLoc
               ,  LOC.Loc

         IF @c_PutawayLoc <> ''
         BEGIN
            SET @c_reason = 'Found Same Friends. PutawayLoc: ' + @c_PutawayLoc
            SET @c_PALine = '00001'
         END

         -- 2)  Find 10/5 deep from empty Loc defined in sku PA Zone
         IF @c_PutawayLoc = ''
         BEGIN
            SET @c_PALine = '00002'
            IF @b_debug = 1
            BEGIN
               -- Insert records into PTRACEDETAIL table
               SET @c_reason = 'Find 10/6 deep or regular from empty Loc. '
                             + 'Remain ' + CONVERT(NVARCHAR(5), @n_NoOfPallet) + ' Pallet to PA.'
               EXEC nspPTD @c_ptracetype                 = 'ispBatPA01'
                        ,  @n_ptraceheadkey              = @c_ptraceheadkey
                        ,  @c_pa_putawaystrategykey      = 'Custom'
                        ,  @c_pa_putawaystrategylinenmbr = @c_PALine
                        ,  @n_ptracedetailkey            = ''
                        ,  @c_lockey                     = ''
                        ,  @c_reason                     = @c_reason
            END

            SELECT TOP 1
              @n_NoOfPalletInLoc = 0
            , @c_PutawayLoc = LOC.Loc
            , @n_MaxPallet  = LOC.MaxPallet
            FROM LOC              WITH (NOLOCK)
            LEFT JOIN LOTxLOCxID  WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
            WHERE LOC.PutawayZone = @c_PutawayZone
            AND   LOC.Facility    = @c_Facility
            AND   LOC.LocationRoom= @c_Storerkey                        --(Wan)
            GROUP BY LOC.LOC
               ,  LOC.PALogicalLoc
               ,  LOC.MaxPallet
            HAVING SUM(ISNULL(LOTxLOCxID.Qty,0) - ISNULL(LOTxLOCxID.QtyAllocated,0)) = 0
            AND    SUM(ISNULL(LOTxLOCxID.PendingMoveIn,0)) = 0
            ORDER BY CASE WHEN @n_NoOfPallet > 6 AND LOC.MaxPallet = 10 THEN 10
                          WHEN @n_NoOfPallet <=6 AND LOC.MaxPallet = 6  THEN 20
                          WHEN @n_NoOfPallet <=6 AND LOC.MaxPallet = 10 THEN 30
                          WHEN @n_NoOfPallet > 6 AND LOC.MaxPallet = 6  THEN 40
                          ELSE 50
                          END
                  ,  LOC.PALogicalLoc
                  ,  LOC.Loc
         END

         IF @c_PutawayLoc <> ''
         BEGIN
            -- Insert records into PTRACEDETAIL table
            SET @c_reason = 'Found '
                          + CASE WHEN @n_MaxPallet IN (5,10) THEN CONVERT(NVARCHAR(2), @n_MaxPallet) + ' deep '
                                 ELSE 'regular '
                                 END
                          + 'Putaway Location.'
         END

         --No Loc Found
         IF @c_PutawayLoc = ''
         BEGIN
            SET @n_NoOfPallet = 0
         END
         ELSE
         BEGIN
            SET @n_LocsReviewed = @n_LocsReviewed + 1

            SET @n_LocPalletLimit = @n_MaxPallet - @n_NoOfPalletInLoc

            SET @n_NoOfPAPallet = CASE WHEN @n_NoOfPallet > @n_LocPalletLimit
                                       THEN @n_LocPalletLimit
                                       ELSE @n_NoOfPallet
                                       END

            SET @c_Reason = @c_reason
                          + ' Locatiom Limit: ' + CONVERT(NVARCHAR(5), @n_LocPalletLimit) + ' Pallet.'
                          + ' Putaway ' + CONVERT(NVARCHAR(5), @n_NoOfPAPallet) + ' Pallet.'

            IF @b_debug = 1
            BEGIN
               -- Insert records into PTRACEDETAIL table
               EXEC nspPTD @c_ptracetype                 = 'ispBatPA01'
                        ,  @n_ptraceheadkey              = @c_ptraceheadkey
                        ,  @c_pa_putawaystrategykey      = 'Custom'
                        ,  @c_pa_putawaystrategylinenmbr = @c_PALine
                        ,  @n_ptracedetailkey            = ''
                        ,  @c_lockey                     = @c_PutawayLoc
                        ,  @c_reason                     = @c_reason
            END

            IF @n_MaxPallet = 0
            BEGIN
               SET @n_continue = 3
               SET @n_Err    = 65010
               SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                             + ': Putaway Loc: ' + RTRIM(@c_PutawayLoc) + ' MaxPallet setup as 0 Found.( ispBatPA01 )'
            END

            IF @n_Continue = 1 OR @n_Continue = 2
            BEGIN
   --            SET @n_NoOfPallet = @n_NoOfPallet - @n_NoOfPAPallet

               DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT ReceiptLineNumber
                     ,ToLoc
                     ,ToID
               FROM RECEIPTDETAIL WITH (NOLOCK)
               WHERE ReceiptKey = @c_Receiptkey
               AND   Storerkey  = @c_Storerkey
               AND   Sku        = @c_Sku
               AND   Lottable01 = @c_Lottable01
               AND PutawayLoc = ''
               AND QtyReceived > 0
               ORDER BY ReceiptLineNumber

               OPEN CUR_RD

               FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber
                                          ,@c_ToLoc
                                          ,@c_ToID

               WHILE @@FETCH_STATUS <> -1 AND @n_NoOfPAPallet > 0 AND (@n_Continue = 1 OR @n_Continue = 2)
               BEGIN
                  UPDATE RECEIPTDETAIL WITH (ROWLOCK)
                  SET PutAwayLoc = @c_PutawayLoc
                  WHERE ReceiptKey = @c_ReceiptKey
                  AND   ReceiptLineNumber  = @c_ReceiptLineNumber

                  SET @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @c_errmsg = CONVERT(CHAR(250),@n_err)
                     SET @n_err = 65015
                     SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                         + ': Update failed on table RECEIPTDETAIL. (ispBatPA01)'
                         + ' ( ' + ' SQLSvr MESSAGE = ' + LTrim(RTrim(@c_errmsg)) + ' ) '
                  END

                  SET @n_NoOfPAPallet = @n_NoOfPAPallet - 1
                  SET @n_NoOfPallet   = @n_NoOfPallet - 1



                  SET @b_success = 1
                  EXECUTE   nspg_getkey
                           'TaskDetailKey'
                          , 10
                          , @c_TaskdetailKey OUTPUT
                          , @b_success       OUTPUT
                          , @n_err           OUTPUT
                          , @c_errmsg        OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 61020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispBatPA01)'

                  END

                  SET @c_LogicalToLoc = ''
                  SELECT @c_LogicalToLoc = ISNULL(LogicalLocation,'')
                  FROM LOC WITH (NOLOCK)
                  WHERE Loc = @c_ToLoc

                  SET @c_LogicalPALoc = ''
                  SELECT @c_LogicalPALoc = ISNULL(LogicalLocation,'')
                  FROM LOC WITH (NOLOCK)
                  WHERE Loc = @c_PutawayLoc

                  INSERT INTO TASKDETAIL
                     (
                        TaskDetailKey
                     ,  TaskType
                     ,  Storerkey
                     ,  Sku
                     ,  UOM
                     ,  UOMQty
                     ,  Qty
                     ,  SystemQty
                     ,  Lot
                     ,  FromLoc
                     ,  FromID
                     ,  ToLoc
                     ,  ToID
                     ,  LogicalFromLoc
                     ,  LogicalToLoc
                     ,  FinalLoc
                     ,  SourceKey
                     ,  SourceType
                     ,  Priority
                     ,  [Status]
                     ,  PickMethod
                     )
                  VALUES
                     (
                        @c_Taskdetailkey
                     ,  'ASTMV'              -- Tasktype
                     ,  @c_Storerkey         -- Storerkey
                     ,  ''                   -- Sku
                     ,  ''                   -- UOM,
                     ,  0                    -- UOMQty
                     ,  0                    -- SystemQty
                     ,  0                    -- systemqty
                     ,  ''                   -- Lot
                     ,  @c_Toloc             -- from loc
                     ,  @c_ToID              -- from id
                     ,  @c_PutawayLoc        -- To Loc
                     ,  ''                   -- to id
                     ,  @c_LogicalToLoc      -- Logical from loc
                     ,  @c_LogicalPALoc      -- Logical to loc
                     ,  ''
                     ,  @c_ReceiptKey
                     ,  'ispBatPA01'         -- Sourcetype
                     ,  '5'                  -- Priority
                     ,  '0'                  -- Status
                     ,  'MV'                 -- PickMethod
                     )

                  SET @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SET @n_continue = 3
                     SET @n_err = 65025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispBatPA01)'
                  END

                  FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber
                                             ,@c_ToLoc
                                             ,@c_ToID
               END
               CLOSE CUR_RD
               DEALLOCATE CUR_RD
            END
         END
      END

      IF @b_debug = 1
      BEGIN
         UPDATE PTRACEHEAD WITH (ROWLOCK)
         SET EndTime = GetDate()
            ,PA_LocsReviewed = @n_LocsReviewed
         WHERE PTRACEHEADKey = @c_pTraceHeadKey

         SET @n_err = @@ERROR

         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(CHAR(250),@n_err)
            SET @n_err = 65030
            SET @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)
                + ': Insert failed onto table PTRACEHEAD. (ispBatPA01)'
                + ' ( ' + ' SQLSvr MESSAGE = ' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END

      FETCH NEXT FROM CUR_PA INTO   @c_Storerkey
                                 ,  @c_Sku
                                 ,  @c_Lottable01
                                 ,  @n_NoOfPallet
   END
   CLOSE CUR_PA
   DEALLOCATE CUR_PA
QUIT:

   IF CURSOR_STATUS( 'LOCAL', 'CUR_PA') in (0 , 1)
   BEGIN
      CLOSE CUR_PA
      DEALLOCATE CUR_PA
   END

   IF CURSOR_STATUS( 'LOCAL', 'CUR_RD') in (0 , 1)
   BEGIN
      CLOSE CUR_RD
      DEALLOCATE CUR_RD
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispBatPA01'
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