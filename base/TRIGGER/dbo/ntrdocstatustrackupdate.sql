SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*******************************************************************************/
/* Store Procedure:  ntrDocStatusTrackUpdate                                   */
/* Creation Date:                                                              */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:  DocStatusTrack Update Trigger                                     */
/*                                                                             */
/* Input Parameters:                                                           */
/*                                                                             */
/* Output Parameters:  None                                                    */
/*                                                                             */
/* Return Status:  None                                                        */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Local Variables:                                                            */
/*                                                                             */
/* Called By:                                                                  */
/*                                                                             */
/* PVCS Version: 1.5                                                           */
/*                                                                             */
/* Version: 6.0                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/*                                                                             */
/* Updates:                                                                    */
/* Date         Author       Ver.   Purposes                                   */
/* 28-Jul-2016  MCTang       1.0    Add ITFTriggerConfig for MBOL (MC01)       */
/*******************************************************************************/

CREATE TRIGGER [dbo].[ntrDocStatusTrackUpdate]
ON  [dbo].[DocStatusTrack]
FOR UPDATE
AS
BEGIN
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END
   SET NOCOUNT ON
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @b_Success            INT            -- Populated by calls to stored procedures - was the proc successful?
         , @n_Err                INT            -- Error number returned by stored procedure or this trigger
         , @c_ErrMsg             NVARCHAR(250)  -- Error message returned by stored procedure or this trigger
         , @n_Continue           INT
         , @n_StarttCnt          INT            -- Holds the current transaction count
         , @n_Cnt                INT

   DECLARE @c_StorerKey          NVARCHAR(15) 
         , @c_TriggerName        NVARCHAR(120)
         , @c_SourceTable        NVARCHAR(60)
         , @n_RowRef             INT
         , @c_FinalizeDeleted    NCHAR(1)
         , @c_DeletedValue       NVARCHAR(250)

   SELECT @n_Continue=1, @n_StarttCnt=@@TRANCOUNT

   SET @c_TriggerName    = 'ntrDocStatusTrackUpdate'
   SET @c_SourceTable    = 'DocStatusTrack'

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_Continue = 4
   END

   DECLARE @b_ColumnsUpdated VARBINARY(1000)       
   SET @b_ColumnsUpdated = COLUMNS_UPDATED()       
   
   IF ( @n_Continue = 1 or @n_Continue = 2 ) AND NOT UPDATE(EditDate) 
   BEGIN
      UPDATE DocStatusTrack WITH (ROWLOCK)
      SET    EditDate   = GetDate()
           , EditWho    = Suser_Sname()
           , TrafficCop = NULL
      FROM  DocStatusTrack, INSERTED
      WHERE DocStatusTrack.RowRef = INSERTED.RowRef 

      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
      IF @n_Err <> 0
      BEGIN
         SELECT @n_Continue = 3
         SELECT @c_ErrMsg = CONVERT(CHAR(250),@n_Err) --, @n_Err=63805   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_ErrMsg='NSQL'+CONVERT(char(5),@n_Err)+': Update Failed On Table DocStatusTrack. (ntrDocStatusTrackUpdate) ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ErrMsg)) + ' ) '
      END
   END
   
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_Continue = 4
   END

   /* #INCLUDE <TRRHU1.SQL> */
   IF @n_Continue = 1 OR @n_Continue = 2 
   BEGIN 

      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT  INS.RowRef 
            , INS.Storerkey 
            , INS.Finalized
      FROM  INSERTED INS 
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = INS.StorerKey  
      WHERE ITC.SourceTable = 'DocStatusTrack'  
      AND   ITC.sValue      = '1' 
      AND   INS.TableName   <> 'MBOL'                --(MC01)

      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey, @c_FinalizeDeleted

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         -- Execute SP - isp_ITF_ntrDocStatusTrack
         EXECUTE dbo.isp_ITF_ntrDocStatusTrack 
                  @c_TriggerName
                , @c_SourceTable
                , @c_StorerKey
                , @n_RowRef
                , @b_ColumnsUpdated
                , @b_Success  OUTPUT
                , @n_Err      OUTPUT
                , @c_ErrMsg   OUTPUT

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey, @c_FinalizeDeleted
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints

      --(MC01) - S
      DECLARE Cur_Itf_TriggerPoints CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      SELECT DISTINCT INS.RowRef 
                    , OH.Storerkey 
                    , INS.Finalized
      FROM  INSERTED INS 
      JOIN  MbolDetail MD WITH (NOLOCK) ON INS.DocumentNo = MD.MbolKey
      JOIN  Orders OH WITH (NOLOCK) ON MD.OrderKey = OH.OrderKey       
      JOIN  ITFTriggerConfig ITC WITH (NOLOCK) ON ITC.StorerKey = OH.StorerKey  
      WHERE ITC.SourceTable = 'DocStatusTrack'               
      AND   ITC.sValue      = '1' 
      AND   INS.TableName   = 'MBOL'                

      OPEN Cur_Itf_TriggerPoints
      FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey, @c_FinalizeDeleted

      WHILE @@FETCH_STATUS <> -1
      BEGIN

         -- Execute SP - isp_ITF_ntrDocStatusTrack
         EXECUTE dbo.isp_ITF_ntrDocStatusTrack 
                  @c_TriggerName
                , @c_SourceTable
                , @c_StorerKey
                , @n_RowRef
                , @b_ColumnsUpdated
                , @b_Success  OUTPUT
                , @n_Err      OUTPUT
                , @c_ErrMsg   OUTPUT

         FETCH NEXT FROM Cur_Itf_TriggerPoints INTO @n_RowRef, @c_StorerKey, @c_FinalizeDeleted
      END -- WHILE @@FETCH_STATUS <> -1
      CLOSE Cur_Itf_TriggerPoints
      DEALLOCATE Cur_Itf_TriggerPoints
      --(MC01) - E

   END -- IF @n_Continue = 1 OR @n_Continue = 2 

   /* #INCLUDE <TRRHU2.SQL> */
   IF @n_Continue=3  -- Error Occured - Process AND Return
   BEGIN
      -- To support RDT - start
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1
      BEGIN
         -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
         -- Instead we commit and raise an error back to parent, let the parent decide

         -- Commit until the level we begin with
         WHILE @@TRANCOUNT > @n_StarttCnt
            COMMIT TRAN

         -- Raise error with severity = 10, instead of the default severity 16. 
         -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
         RAISERROR (@n_Err, 10, 1) WITH SETERROR 

         -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
      -- To support RDT - end
         IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StarttCnt
         BEGIN
            ROLLBACK TRAN
         END
         ELSE
         BEGIN
            WHILE @@TRANCOUNT > @n_StarttCnt
            BEGIN
               COMMIT TRAN
            END
         END
         EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ntrDocStatusTrackUpdate'
         RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012 
         RETURN
      END
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StarttCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO