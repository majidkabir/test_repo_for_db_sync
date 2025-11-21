SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure:  nspg_GetKey                                       */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  Generate TriganticLogKey                                   */
/*                                                                      */
/* 27-May-2013  TLTING     1.1  Use table Identity to generate running  */
/*                              Key# to reduce blocking                 */
/* 27-Oct-2013  TLTING     1.2  Add LOT table Identity getkey           */
/* 09-Jun-2014  TLTING     1.3  Add TCPOUTLog table Identity getkey     */
/* 03-Dec-2014  TLTING     1.4  Add PICKSLIP  table Identity getkey     */
/* 07-Dec-2014  TLTING     1.5  Add WCSKey  table Identity getkey       */
/* 12-Aug-2015  TLTING     1.6  Add MoveRefKey  table Identity getkey   */
/* 21-Oct-2015  TLTING     1.7  Add OrderKey  table Identity getkey     */
/* 29-Jul-2016  TLTING     1.8  Add BatchNo, Loadkey Sequance getkey    */
/* 14-Sep-2016  TLTING     1.9  Add ORDBATCHNO Sequance getkey          */
/* 14-Sep-2016  TLTING     1.9  Add DC74 Sequance getkey                */
/* 16-Jun-2017  TLTING     1.10 Add Seq getkey-SerialNo,REPLENISHKEY    */
/*                              ,REPLENISHGROUP                         */
/* 23-Jun-2017  tlting01   1.11 Reset Ncounter bug                      */
/* 25-Sep-2017  tlting01   1.12 Add Seq OPRUN, PREOPRUN                 */
/* 13-Nov-2017  tlting     1.13 Add ANFLabelNo                          */
/* 22-May-2018  tlting     1.14 Add PackNo                              */
/* 26-APR-2018  Wan01      1.15 Add ChannelTranRefNo,ChannelTransferKey */
/* 22-May-2018  tlting     1.16 Add receipt,ID,WavedetailKey,LogEvent,  */
/*                          CCDetailKey,AEOLabelNo                      */
/* 18-Feb-2019  tlting     1.17 NewGetKeySeq Entry                      */
/* 17-Jun-2019  Shong      1.18 Add EditDate column                     */
/* 21-Jan-2023  Leong      1.19 JSM-123320 - Revise sequence batch key  */
/************************************************************************/

CREATE   PROC [dbo].[nspg_GetKey]
     @KeyName       NVARCHAR(18)
   , @fieldlength   INT
   , @keystring     NVARCHAR(25)   OUTPUT
   , @b_Success     INT            OUTPUT
   , @n_err         INT            OUTPUT
   , @c_errmsg      NVARCHAR(250)  OUTPUT
   , @b_resultset   INT       = 0
   , @n_batch       INT       = 1
AS

SET NOCOUNT ON
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @n_count     INT /* next key */
DECLARE @n_ncnt      INT
DECLARE @n_starttcnt INT /* Holds the current transaction count */
DECLARE @n_continue  INT /* Continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip furthur processing */
DECLARE @n_cnt       INT /* Variable to record if @@ROWCOUNT=0 after UPDATE */
DECLARE @keystring2  NVARCHAR(25)
DECLARE @n_batchCnt  INT
SET @keystring2 = ''
SET @n_batchCnt = 0

SELECT @n_starttcnt=@@TRANCOUNT, @n_continue = 1, @b_success = 0, @n_err = 0, @c_errmsg = ''

BEGIN TRANSACTION

IF EXISTS ( SELECT 1 FROM sys.sequences (NOLOCK) WHERE name = @KeyName  )
BEGIN
   GOTO NewGetKeySeq
END

IF @KeyName IN ( 'ITRNKEY', 'TRIGANTICKEY','PICKDETAILKEY', 'PREALLOCATEPICKDET', 'TASKDETAILKEY'
               ,'TRANSMITLOGKEY','TRANSMITLOGKEY2','TRANSMITLOGKEY3', 'LOT' )
BEGIN
   GOTO NewGetKey
END

IF @KeyName IN ( 'TCPOUTLog', 'PICKSLIP','WCSKEY','MoveRefKey','Order' ,'REPLENISHKEY','receipt', 'ID', 'SerialNo' )
BEGIN
   GOTO NewGetKey
END

IF @KeyName IN ('PTRACEHEADKEY', 'PTRACEDETAILKEY')
   UPDATE nCountertrace WITH (ROWLOCK) SET KeyCount = KeyCount WHERE KeyName = @KeyName

-- Added By YokeBeen on 16-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
ELSE IF @KeyName IN ('NSCKEY', 'INTERFACEKEY')
   UPDATE nCounterNSC WITH (ROWLOCK) SET KeyCount = KeyCount WHERE KeyName = @KeyName
-- End of Added for NSC Project

ELSE
   UPDATE nCounter WITH (ROWLOCK) SET KeyCount = KeyCount, EditDate = GETDATE() WHERE KeyName = @KeyName

SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

IF @n_err <> 0
BEGIN
   SELECT @n_continue = 3
END

IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @n_cnt > 0
   BEGIN
      -- Start - Added by YokeBeen on 7-Apr-2003 for HongKong Timberland's Project.
      -- To reset the Counter.
      IF @fieldlength < 10
      BEGIN
         IF EXISTS ( SELECT 1 FROM nCounter (NOLOCK) WHERE KeyName = @KeyName And KeyCount =
                     RIGHT(REPLICATE('9', @fieldlength), @fieldlength) )
         BEGIN
            UPDATE nCounter WITH (ROWLOCK) SET KeyCount = 0, EditDate = GETDATE()  WHERE KeyName = @KeyName    -- tlting01
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         END
      END
      -- Ended on 7-Apr-2003 for HongKong Timberland's Project.

      IF @KeyName IN ('PTRACEHEADKEY', 'PTRACEDETAILKEY')
         UPDATE nCountertrace WITH (ROWLOCK) SET KeyCount = KeyCount + @n_batch WHERE KeyName = @KeyName

      -- Added By YokeBeen on 16-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
      ELSE IF @KeyName  IN ('NSCKEY', 'INTERFACEKEY')
         UPDATE nCounterNSC WITH (ROWLOCK) SET KeyCount = KeyCount + @n_batch WHERE KeyName = @KeyName
      -- End of Added for NSC Project
      
      ELSE
         UPDATE nCounter WITH (ROWLOCK) SET KeyCount = KeyCount + @n_batch WHERE KeyName = @KeyName
      
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On nCounter:'+@KeyName+'. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      ELSE IF @n_cnt = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err=61901
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update To Table nCounter:'+@KeyName+' Returned Zero Rows Affected. (nspg_GetKey)'
      END
   END
   ELSE
   BEGIN
      IF @KeyName IN ('PTRACEHEADKEY', 'PTRACEDETAILKEY')
         INSERT nCountertrace (KeyName, KeyCount) VALUES (@KeyName, @n_batch)

      -- Added By YokeBeen on 16-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
      ELSE IF @KeyName  IN ('NSCKEY', 'INTERFACEKEY')
         INSERT nCounterNSC (KeyName, KeyCount) VALUES (@KeyName, @n_batch)
      -- End of Added for NSC Project
      ELSE
         INSERT nCounter (KeyName, KeyCount) VALUES (@KeyName, @n_batch)

      SELECT @n_err = @@ERROR

      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61902   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Failed On nCounter:'+@KeyName+'. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
   END

   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      IF @KeyName IN ('PTRACEHEADKEY', 'PTRACEDETAILKEY')
         SELECT @n_count = KeyCount - @n_batch FROM nCountertrace WITH (NOLOCK) WHERE KeyName = @KeyName

      -- Added By YokeBeen on 16-Feb-2004 For NIKE Regional (NSC) Project - (SOS#20000)
      ELSE IF @KeyName  IN ('NSCKEY', 'INTERFACEKEY')
         SELECT @n_count = KeyCount - @n_batch FROM nCounterNSC WITH (NOLOCK) WHERE KeyName = @KeyName
      -- End of Added for NSC Project
      ELSE
         SELECT @n_count = KeyCount - @n_batch FROM nCounter WITH (NOLOCK) WHERE KeyName = @KeyName

      SELECT @keystring = RTRIM(LTRIM(CONVERT(CHAR(18),@n_count + 1)))

      DECLARE @bigstring NVARCHAR(50)
      SELECT @bigstring = RTRIM(@keystring)
      SELECT @bigstring = REPLICATE('0',25) + @bigstring
      SELECT @bigstring = RIGHT(RTRIM(@bigstring), @fieldlength)
      SELECT @keystring = RTRIM(@bigstring)

      IF @b_resultset = 1
      BEGIN
         SELECT @keystring 'c_keystring', @b_Success 'b_success', @n_err 'n_err', @c_errmsg 'c_errmsg'
      END
   END
END

GOTO QUIT_Process

NewGetKeySeq:
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   EXEC dbo.[nspg_GetKey2]
        @KeyName
      , ''
      , @fieldlength
      , @keystring OUTPUT
      , @b_Success OUTPUT
      , @n_err     OUTPUT
      , @c_errmsg  OUTPUT
      , @b_resultset
      , 1
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61935   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
   END

   -- For Batch key
   IF @n_batch > 1
   BEGIN
      SET @n_batchCnt = @n_batch - 1
      WHILE @n_batchCnt > 0
      BEGIN
         IF @KeyName = 'GroupKey'-- JSM-123320
         BEGIN
            EXEC dbo.[nspg_GetKey2]
              @KeyName
            , ''
            , @fieldlength
            , @keystring2 OUTPUT
            , @b_Success  OUTPUT
            , @n_err      OUTPUT
            , @c_errmsg   OUTPUT
            , @b_resultset
            , 1
         END
         ELSE
         BEGIN
            EXEC dbo.[nspg_GetKey2]
              @KeyName
            , ''
            , @fieldlength
            , @keystring OUTPUT
            , @b_Success OUTPUT
            , @n_err     OUTPUT
            , @c_errmsg  OUTPUT
            , @b_resultset
            , 1
         END
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61936   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
         END
         SELECT @n_batchCnt = @n_batchCnt -1
      END
   END

   GOTO QUIT_Process
  -- NewGetKeySeq
END

NewGetKey:
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   IF @KeyName = 'ITRNKEY'
   BEGIN
      EXECUTE isp_GetITRNKey
           10
         , @keystring OUTPUT
         , @b_success OUTPUT
         , @n_err     OUTPUT
         , @c_errmsg  OUTPUT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61903   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetITRNKey
                   10
                 , @keystring2 OUTPUT
                 , @b_success  OUTPUT
                 , @n_err      OUTPUT
                 , @c_errmsg   OUTPUT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61904   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'TRIGANTICKEY'
   BEGIN
      EXECUTE isp_GetTriganticKey
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61905   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetTriganticKey
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61906   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'PICKDETAILKEY'
   BEGIN
      EXECUTE isp_GetPICKDETAILKey
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61907   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetPICKDETAILKey
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61908   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'PREALLOCATEPICKDET'
   BEGIN
      EXECUTE isp_GetPreallocatePICKDETAILKey
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61909   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetPreallocatePICKDETAILKey
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61910   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'TASKDETAILKEY'
   BEGIN
      EXECUTE isp_GetTaskdetailKey
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61911   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetTaskdetailKey
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61912   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'TRANSMITLOGKEY'
   BEGIN
      EXECUTE isp_GetTRANSMITLOGKEY
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61913   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetTRANSMITLOGKEY
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61914   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'TRANSMITLOGKEY2'
   BEGIN
      EXECUTE isp_GetTRANSMITLOGKEY2
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61915   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetTRANSMITLOGKEY2
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61916   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'TRANSMITLOGKEY3'
   BEGIN
      EXECUTE isp_GetTRANSMITLOGKEY3
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61917   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetTRANSMITLOGKEY3
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61918   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   ELSE IF @KeyName = 'LOT'
   BEGIN
      EXECUTE isp_GetLOTKey
             10
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61919   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END
      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN
            EXECUTE isp_GetLOTKey
                   10
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61920   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   IF @KeyName = 'TCPOUTLog'
   BEGIN
      EXECUTE isp_GetTCPOUTLogKey
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61921   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetTCPOUTLogKey
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61922   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END
   IF @KeyName = 'PICKSLIP'
   BEGIN
      EXECUTE isp_GetPICKSLIPKey
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61923   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetPICKSLIPKey
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61924   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END  -- END PICKSLIP
   IF @KeyName = 'WCSKey'
   BEGIN
      EXECUTE isp_GetWCSKey
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61925   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetWCSKey
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61926   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- WCSKey
   IF @KeyName = 'MoveRefKey'
   BEGIN
      EXECUTE isp_GetMoveRefKey
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61927   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetMoveRefKey
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61928   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- MoveRefKey
   IF @KeyName = 'Order'
   BEGIN
      EXECUTE isp_GetOrderKey
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61929   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetOrderKey
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61930   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- Order
   IF @KeyName = 'SerialNo'
   BEGIN
      EXECUTE isp_GetSerialNoKey
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61929   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetSerialNoKey
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61930   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- Serialno
   IF @KeyName = 'REPLENISHKEY'
   BEGIN
      EXECUTE isp_GetREPLENISHKEY
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61931   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetREPLENISHKEY
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61932   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- REPLENISHKEY
   IF @KeyName = 'Receipt'
   BEGIN
      EXECUTE isp_GetReceiptKEY
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61933   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetReceiptKEY
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61934   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- ReceiptKEY
   IF @KeyName = 'ID'
   BEGIN
      EXECUTE isp_GetIDKEY
             @fieldlength
           , @keystring OUTPUT
           , @b_success OUTPUT
           , @n_err OUTPUT
           , @c_errmsg OUTPUT
      IF @n_err <> 0
      BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61933   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
      END

      -- For Batch key
      IF @n_batch > 1
      BEGIN
         SET @n_batchCnt = @n_batch - 1
         WHILE @n_batchCnt > 0
         BEGIN

            EXECUTE isp_GetIDKEY
                   @fieldlength
                 , @keystring2 OUTPUT
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT
            IF @n_err <> 0
            BEGIN
                SELECT @n_continue = 3
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=61934   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Generate '+@KeyName+' Failed. (nspg_GetKey)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '
            END
            SELECT @n_batchCnt = @n_batchCnt -1
         END
      END
   END   -- IDKEY
END

QUIT_Process:
IF @n_continue = 3  -- Error Occured - Process And Return
BEGIN
   SELECT @b_success = 0
   IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspg_GetKey'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   SELECT @b_success = 1
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO