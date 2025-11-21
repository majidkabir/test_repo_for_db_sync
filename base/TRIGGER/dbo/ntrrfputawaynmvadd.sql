SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure:  ntrRFPutawayNMVAdd                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Modification log:                                                          */
/* Date         Author     Ver   Purposes                                     */
/* 19-May-2014  Ung        1.0   Created                                      */
/******************************************************************************/
CREATE TRIGGER ntrRFPutawayNMVAdd
ON  [dbo].[RFPutawayNMV]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_debug int
   SELECT @b_debug = 0

   DECLARE
      @b_Success            int           -- Populated by calls to stored procedures - was the proc successful?
     ,@n_err                int           -- Error number returned by stored procedure or this trigger
     ,@n_err2               int           -- For Additional Error Detection
     ,@c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
     ,@n_continue           int
     ,@n_starttcnt          int           -- Holds the current transaction count
     ,@c_preprocess         NVARCHAR(250) -- preprocess
     ,@c_pstprocess         NVARCHAR(250) -- post process
     ,@profiler             NVARCHAR(80)  

   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
  
   IF @n_continue = 1 OR @n_continue=2  
   BEGIN  
      DECLARE 
         @c_ToLoc        NVARCHAR(10),
         @c_ToID         NVARCHAR(18),
         @n_MaxPallet    INT,
         @n_Count        INT

      DECLARE CURSOR_INSERTED CURSOR FAST_FORWARD READ_ONLY FOR 
      SELECT INSERTED.SuggestedLoc, INSERTED.FromID
      FROM INSERTED WITH (NOLOCK)
      GROUP BY INSERTED.SuggestedLoc, INSERTED.FromID

      OPEN CURSOR_INSERTED               
      FETCH NEXT FROM CURSOR_INSERTED INTO @c_ToLoc, @c_ToID

      WHILE (@@FETCH_STATUS <> -1)          
      BEGIN 
         SELECT @n_MaxPallet = MaxPallet
         FROM LOC WITH (NOLOCK)
         WHERE Loc = @c_ToLoc

         IF @n_MaxPallet <> 0
         BEGIN 
            SELECT @n_Count = COUNT(DISTINCT FromID)
            FROM RFPutawayNMV WITH (NOLOCK)
            WHERE SuggestedLoc = @c_ToLoc 

            IF @n_Count > @n_MaxPallet 
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82151
               SELECT @c_errmsg = 'OverMaxPallet  for SuggestedLoc: ' + @c_ToLoc + ' (MaxPallet=' + CAST(@n_MaxPallet AS NVARCHAR) + '). (ntrRFPutawayNMVAdd)' +
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END

            SELECT @n_Count = @n_Count + COUNT( DISTINCT DropID)
            FROM DropID WITH (NOLOCK)
            WHERE DropLOC = @c_ToLoc
               AND Status <> '9'
               AND DropID NOT IN (
                  SELECT DISTINCT FromID
                  FROM RFPutawayNMV WITH (NOLOCK)
                  WHERE SuggestedLoc = @c_ToLoc)

            IF @n_Count > @n_MaxPallet 
            BEGIN
               SELECT @n_continue = 3
                     ,@n_err = 82152
               SELECT @c_errmsg = 'OverMaxPallet  for SuggestedLoc: ' + @c_ToLoc + ' (MaxPallet=' + CAST(@n_MaxPallet AS NVARCHAR) + '). (ntrRFPutawayNMVAdd)' +
                                  ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'
               GOTO QUIT
            END
         END

         FETCH NEXT FROM CURSOR_INSERTED INTO @c_ToLoc, @c_ToID       
      END          
      CLOSE CURSOR_INSERTED          
      DEALLOCATE CURSOR_INSERTED
   END
   GOTO QUIT

QUIT:
   IF (SELECT CURSOR_STATUS('LOCAL','CURSOR_INSERTED')) >=0 
   BEGIN
      CLOSE CURSOR_INSERTED           
      DEALLOCATE CURSOR_INSERTED      
   END  

   /* #INCLUDE <TRRDA2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_starttcnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16.
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_err, 10, 1) WITH SETERROR

        -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
         IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
         execute nsp_logerror @n_err, @c_errmsg, "ntrRFPutawayNMVAdd"
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
         IF @b_debug = 2
         BEGIN
             SELECT @profiler = 'PROFILER,637,00,9,ntrRFPutawayNMVAdd Tigger                       ,' + CONVERT(char(12), getdate(), 114)
             PRINT @profiler
         END
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
      IF @b_debug = 2
      BEGIN
         SELECT @profiler = 'PROFILER,637,00,9,ntrRFPutawayNMVAdd Trigger                       ,' + CONVERT(char(12), getdate(), 114)
         PRINT @profiler
      END
      RETURN
   END
END

GO