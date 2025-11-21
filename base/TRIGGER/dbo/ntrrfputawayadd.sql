SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure:  ntrRFPutawayAdd                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modification log:                                                          */
/* Date         Author     Ver   Purposes                                     */
/* 16-Aug-2013  Ung        1.0   Created                                      */
/* 21-Nov-2013  Chee       1.1   Bug Fixes - Incorrect MaxPallet and          */
/*                               CommingleSku calculation checking (Chee01)   */
/* 07-Jan-2014  Chee       1.2   Added StorerConfig -                         */
/*                               UCCPutawayWithSinglePackSize to only allow   */
/*                               UCC putaway with single pack size in the     */
/*                               same location (Chee02)                       */
/* 12-SEP-2014  YTWan      1.3   Fixed to able to get error code in the       */
/*                               calling Program - (Wan01)                    */
/* 25-NOV-2014  Leong      1.4   SOS# 326708 - Enhance error msg.             */
/* 24-AUG-2016  Leong      1.5   Log @c_errmsg for RDT. (Leong01)             */
/* 17-Jul-2017  NJOW01     1.6   Fix. add config to skip checking max pallet  */
/*                               by id counting.                              */
/* 06-Aug-2017  Ung        1.7   Share LoseIdNoValidateMaxPltByID with RDT    */
/* 04-Oct-2019  Leong      1.8   INC0881047 - Revise error message.           */
/******************************************************************************/

CREATE TRIGGER [dbo].[ntrRFPutawayAdd]
ON  [dbo].[RFPUTAWAY]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug INT
   SELECT @b_debug = 0

   DECLARE
      @b_Success            INT           -- Populated by calls to stored procedures - was the proc successful?
     ,@n_err                INT           -- Error number returned by stored procedure or this trigger
     ,@n_err2               INT           -- For Additional Error Detection
     ,@c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
     ,@n_continue           INT
     ,@n_starttcnt          INT           -- Holds the current transaction count
     ,@c_preprocess         NVARCHAR(250) -- preprocess
     ,@c_pstprocess         NVARCHAR(250) -- post process
     ,@profiler             NVARCHAR(80)

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   -- To Skip all the trigger process when Insert the history records from Archive as user request
   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
      SELECT @n_continue = 4

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE
         @c_ToLoc                        NVARCHAR(10),
         @c_ToID                         NVARCHAR(18),
         @n_MaxPallet                    INT,
         @n_Count                        INT,
         @n_RowRef                       INT,
         @c_CommingleSku                 NVARCHAR(1),
         @n_CountLLI                     INT,
         @c_SKU                          NVARCHAR(20),   -- Chee01
         @c_StorerKey                    NVARCHAR(15),   -- Chee02
         @c_UCCPutawayWithSinglePackSize NVARCHAR(20),   -- Chee02
         @c_LoseIdNoValidateMaxPltByID   NVARCHAR(10),   -- NJOW01
         @c_LoseID                       NCHAR(1)        -- NJOW01

      -- NJOW01
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      DECLARE CURSOR_INSERTED CURSOR FAST_FORWARD READ_ONLY LOCAL FOR
      SELECT INSERTED.SuggestedLoc, INSERTED.Id,
             INSERTED.StorerKey  -- Chee02
      FROM INSERTED WITH (NOLOCK)
      GROUP BY INSERTED.SuggestedLoc, INSERTED.Id,
               INSERTED.StorerKey  -- Chee02

      OPEN CURSOR_INSERTED
      FETCH NEXT FROM CURSOR_INSERTED INTO @c_ToLoc, @c_ToID,
                                           @c_StorerKey -- Chee02

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         -- Chee02 Start
         SELECT @c_UCCPutawayWithSinglePackSize = SValue
         FROM StorerConfig WITH (NOLOCK)
         WHERE ConfigKey = 'UCCPutawayWithSinglePackSize'
           AND StorerKey = @c_StorerKey

         IF @c_UCCPutawayWithSinglePackSize = '1'
         BEGIN
            DECLARE CURSOR_SKUInLOC CURSOR FAST_FORWARD READ_ONLY LOCAL FOR
            SELECT DISTINCT SKU
            FROM RFPutaway WITH (NOLOCK)
            WHERE SuggestedLoc = @c_ToLoc
              AND StorerKey = @c_StorerKey
              AND ISNULL(CaseID, '') <> ''

            OPEN CURSOR_SKUInLOC
            FETCH NEXT FROM CURSOR_SKUInLOC INTO @c_SKU

            WHILE (@@FETCH_STATUS <> -1)
            BEGIN
               SELECT @n_Count = COUNT(DISTINCT QTY)
               FROM RFPutaway WITH (NOLOCK)
               WHERE SKU = @c_SKU
                 AND SuggestedLoc = @c_ToLoc
                 AND StorerKey = @c_StorerKey
                 AND ISNULL(CaseID, '') <> ''

               IF @n_Count > 1
               BEGIN
                  SELECT @n_continue = 3
                        ,@n_err = 82160
                  SELECT @c_errmsg = 'SuggestedLoc: ' + ISNULL(RTRIM(@c_ToLoc),'') + ' contains more than one sku pack size. (Current Sku: ' + ISNULL(RTRIM(@c_SKU),'') +
                                    ', Current Count: '+ CAST(ISNULL(@n_Count,0) AS NVARCHAR) + '). (ntrRFPutawayAdd)' +
                                    ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
                  GOTO QUIT
               END

               FETCH NEXT FROM CURSOR_SKUInLOC INTO @c_SKU
            END
            CLOSE CURSOR_SKUInLOC
            DEALLOCATE CURSOR_SKUInLOC
         END -- IF @c_UCCPutawayWithSinglePackSize <> '1'
         SET @c_SKU = ''
         -- Chee02 End

         SELECT @n_MaxPallet = MaxPallet,
                @c_LoseID = LoseId --NJOW01
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_ToLoc

         --NJOW01
         IF @c_LoseId = '1' -- AND @n_IsRDT <> 1
         BEGIN
            SET @c_LoseIdNoValidateMaxPltByID = dbo.fnc_GetRight('', @c_StorerKey, '', 'LoseIdNoValidateMaxPltByID')

            IF @c_LoseIdNoValidateMaxPltByID = '1'
               SET @n_MaxPallet = 0
         END

         IF @n_MaxPallet <> 0
         BEGIN
            SELECT @n_Count = COUNT(DISTINCT ID)
            FROM RFPutaway WITH (NOLOCK)
            WHERE SuggestedLoc = @c_ToLoc

            -- Chee01 Start
--            SELECT @n_Count = @n_Count + COUNT(DISTINCT ID)
--            FROM LotxLocxID WITH (NOLOCK)
--            WHERE LOC = @c_ToLoc
--              AND (Qty - QtyPicked) > 0

            IF @n_Count > @n_MaxPallet
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82151
               SELECT @c_errmsg = 'OverMaxPallet for SuggestedLoc: ' + ISNULL(RTRIM(@c_ToLoc),'') +
                                  ' (MaxPallet: ' + CAST(ISNULL(@n_MaxPallet,0) AS NVARCHAR) +
                                  ', Current Count: '+ CAST(ISNULL(@n_Count,0) AS NVARCHAR) + '). (ntrRFPutawayAdd)' +
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END

            SELECT @n_Count = @n_Count + COUNT(DISTINCT ID)
            FROM LotxLocxID WITH (NOLOCK)
            WHERE LOC = @c_ToLoc
              AND (Qty - QtyPicked) > 0
              AND ID NOT IN (
                 SELECT DISTINCT ID
                 FROM RFPutaway WITH (NOLOCK)
                 WHERE SuggestedLoc = @c_ToLoc
              )

            IF @n_Count > @n_MaxPallet
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82152
               SELECT @c_errmsg = 'OverMaxPallet for SuggestedLoc: ' + ISNULL(RTRIM(@c_ToLoc),'') +
                                  ' (MaxPallet: ' + CAST(ISNULL(@n_MaxPallet,0) AS NVARCHAR) +
                                  ', Current Count: '+ CAST(ISNULL(@n_Count,0) AS NVARCHAR) + '). (ntrRFPutawayAdd)' +
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END
            -- Chee01 End
         END -- IF @n_MaxPallet <> 0

         SELECT @c_CommingleSku = CommingleSku
         FROM LOC WITH (NOLOCK)
         WHERE LOC = @c_ToLoc

         IF @c_CommingleSku <> '1'
         BEGIN
            SELECT @n_Count = COUNT(DISTINCT SKU)
            FROM RFPutaway WITH (NOLOCK)
            WHERE SuggestedLoc = @c_ToLoc

            -- Chee01 Start
--            SELECT @n_Count = @n_Count + COUNT(DISTINCT SKU)
--            FROM LotxLocxID WITH (NOLOCK)
--            WHERE LOC = @c_ToLoc
--              AND (Qty - QtyPicked) > 0

            IF @n_Count > 1
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82159
               SELECT @c_errmsg = 'SuggestedLoc: ' + ISNULL(RTRIM(@c_ToLoc),'') +
                                  ' Only Allow One Sku. (Current Count: ' + CAST(ISNULL(@n_Count,0) AS NVARCHAR) + '). (ntrRFPutawayAdd)' +-- SOS# 326708
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END

            SELECT @c_SKU = SKU
            FROM RFPutaway WITH (NOLOCK)
            WHERE SuggestedLoc = @c_ToLoc

            IF ISNULL(@c_SKU, '') = ''
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82158
               SELECT @c_errmsg = 'SuggestedLoc: ' + ISNULL(RTRIM(@c_ToLoc),'') + ', Sku is Empty. (ntrRFPutawayAdd)' +
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END

            SELECT @n_Count = COUNT(DISTINCT SKU)
            FROM LotxLocxID WITH (NOLOCK)
            WHERE LOC = @c_ToLoc
              AND (Qty - QtyPicked) > 0
              AND SKU <> @c_SKU

            IF @n_Count > 0
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82157
               SELECT @c_errmsg = 'SuggestedLoc: ' + ISNULL(RTRIM(@c_ToLoc),'') + ' Only Allow One Sku. (Current Sku: ' + ISNULL(RTRIM(@c_SKU),'') +
                                  ', Current Count: ' + CAST(ISNULL(@n_Count,0) AS NVARCHAR) + '). (ntrRFPutawayAdd)' +-- SOS# 326708
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END
            -- Chee01 End
         END -- IF @c_CommingleSku <> '1'

         FETCH NEXT FROM CURSOR_INSERTED INTO @c_ToLoc, @c_ToID,
                                              @c_StorerKey -- Chee02
      END -- END WHILE FOR CURSOR_INSERTED
      CLOSE CURSOR_INSERTED
      DEALLOCATE CURSOR_INSERTED
   END
   GOTO QUIT

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_INSERTED')) >= 0
   BEGIN
      CLOSE CURSOR_INSERTED
      DEALLOCATE CURSOR_INSERTED
   END

   -- Chee02
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_SKUInLOC')) >= 0
   BEGIN
      CLOSE CURSOR_SKUInLOC
      DEALLOCATE CURSOR_SKUInLOC
   END

   /* #INCLUDE <TRRDA2.SQL> */
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      --DECLARE @n_IsRDT INT
      --EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         EXECUTE nsp_LogError @n_err, @c_errmsg, "ntrRFPutawayAdd" -- (Leong01)
         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

        -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_starttcnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_starttcnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrRFPutawayAdd"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
         --(Wan01) - Fixed to able to get error code in the calling Program - START
--         IF @b_debug = 2
--         BEGIN
--             SELECT @profiler = 'PROFILER,637,00,9,ntrRFPutawayAdd Tigger                       ,' + CONVERT(char(12), getdate(), 114)
--             PRINT @profiler
--         END
         --(Wan01) - Fixed to able to get error code in the calling Program - END
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      --(Wan01) - Fixed to able to get error code in the calling Program - START
      --IF @b_debug = 2
      --BEGIN
      --   SELECT @profiler = 'PROFILER,637,00,9,ntrRFPutawayAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114) PRINT @profiler
      --END
      --(Wan01) - Fixed to able to get error code in the calling Program - END
      RETURN
   END
END

GO