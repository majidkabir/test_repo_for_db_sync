SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: ntrInventoryQCDetailUpdate                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: InventoryQCDetail UPDATE Transaction                        */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records UPDATE                                       */
/*                                                                      */
/* PVCS Version: 1.7                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Ver   Purposes                               */
/* 17-Mar-2009  TLTING           Change user_name() to SUSER_SNAME()    */
/* 28-Dec-2010  Leong      1.2   SOS# 200797 - Remove verification for  */
/*                                             FromId = ToId            */
/* 25 May2012   TLTING02   1.3   DM integrity - add update editdate B4  */
/*                               TrafficCop for status < '9'            */
/* 28-Oct-2013  TLTING     1.4   Review Editdate column update          */
/* 22-May-2014  CSCHONG    1.5   Added Lottables 06-15 (CS01)           */
/* 28-Oct-2013  TLTING     1.4   NOLOCK                                 */
/* 22-Mar-2018  Wan01      1.7   WMS-4288 - [CN] UA Relocation Phase II-*/
/*                               Exceed Channel of IQC                  */
/************************************************************************/

CREATE TRIGGER ntrInventoryQCDetailUpdate
ON InventoryQCDetail
FOR UPDATE
AS
   IF @@ROWCOUNT = 0
   BEGIN
      RETURN
   END  
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE @b_success   int       -- Populated by calls to stored procedures - was the proc successful?
       , @n_err       int       -- Error number returned by stored procedure or this trigger
       , @c_errmsg    NVARCHAR(250) -- Error message returned by stored procedure or this trigger
       , @n_continue  int       /* continuation flag
                                  1=Continue
                                  2=failed but continue processsing
                                  3=failed do not continue processing
                                  4=successful but skip furthur processing */
       , @n_starttcnt int       -- Holds the current transaction count
       , @n_cnt       int       -- variable to hold @@ROWCOUNT

 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

 DECLARE @c_qc_key            NVARCHAR(10),
         @c_qclineno          NVARCHAR(5),
         @c_reason            NVARCHAR(10),
         @c_status            NVARCHAR(10),
         @c_sku               NVARCHAR(20),
         @c_packkey           NVARCHAR(10),
         @c_uom               NVARCHAR(10),
         @c_storerkey         NVARCHAR(15),
         @c_fromlot           NVARCHAR(10),
         @c_fromloc           NVARCHAR(10),
         @c_fromid            NVARCHAR(18),
         @c_toloc             NVARCHAR(10),
         @c_toid              NVARCHAR(18),
         @n_qty               int,
         @n_toqty             int,
         @c_itrnkey           NVARCHAR(10),
         @c_lottable01        NVARCHAR(18),
         @c_lottable02        NVARCHAR(18),
         @c_lottable03        NVARCHAR(18),
         @d_lottable04        datetime,
         @d_lottable05        datetime,
         /*CS01 Start*/
         @c_lottable06        NVARCHAR(30),
         @c_lottable07        NVARCHAR(30),
         @c_lottable08        NVARCHAR(30),
         @c_lottable09        NVARCHAR(30),
         @c_lottable10        NVARCHAR(30),
         @c_lottable11        NVARCHAR(30),
         @c_lottable12        NVARCHAR(30),
         @d_lottable13        datetime,
         @d_lottable14        datetime,
         @d_lottable15        datetime,
         /*CS01 END*/
         @c_sourcekey         NVARCHAR(20),
         @c_FromLocFlag       NVARCHAR(10),      -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4)
         @c_ToLocFlag         NVARCHAR(10)       -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4)
      , @c_Channel            NVARCHAR(20) = '' --(Wan01)
      , @n_Channel_ID         BIGINT = 0        --(Wan01)

   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4     -- No Error But Skip Processing
   END
   
   -- tlting01
   IF EXISTS ( SELECT 1 FROM INSERTED, DELETED 
               WHERE INSERTED.QC_Key = DELETED.QC_Key AND INSERTED.qclineno = DELETED.qclineno
               AND ( INSERTED.[STATUS] < '9' OR DELETED.[STATUS] < '9' ) ) 
         AND (@n_continue = 1 or @n_continue = 2)
         AND NOT UPDATE(EditDate)
   BEGIN
    UPDATE InventoryQCDetail with (ROWLOCK)
    SET EditDate   = GETDATE(),
        EditWho    = SUSER_SNAME(),
        TrafficCop = NULL
    FROM InventoryQCDetail, INSERTED
    WHERE InventoryQCDetail.QC_Key = INSERTED.QC_Key
    AND InventoryQCDetail.qclineno = INSERTED.qclineno
    AND InventoryQCDetail.Status < '9'
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90206   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': UPDATE Editdate/User Failed On Table InventoryQCDetail. (ntrInventoryQCDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    END
   END
 
   -- called FROM trinventoryqcdetailadd
   IF UPDATE(TrafficCop)
   BEGIN
      SELECT @n_continue = 4
   END

   SELECT @c_qc_key = '', @c_qclineno = ''

 WHILE @n_continue = 1 or @n_continue = 2
 BEGIN
   SET ROWCOUNT 1
   SELECT @c_qc_key    = Inserted.qc_key,
          @c_qclineno  = Inserted.qclineno,
          @c_storerkey = Inserted.storerkey,
          @c_sku       = Inserted.sku,
          @c_packkey   = Inserted.packkey,
          @c_uom       = Inserted.uom,
          @c_fromlot   = Inserted.fromlot,
          @c_fromloc   = Inserted.fromloc,
          @c_fromid    = Inserted.fromid,
          @n_toqty     = Inserted.toqty,
          @c_toloc     = Inserted.toloc,
          @c_toid      = Inserted.toid
       ,  @c_Channel   = Inserted.Channel       --(Wan01)
       ,  @n_Channel_ID= Inserted.Channel_ID    --(Wan01)
   FROM Inserted, Deleted
   WHERE  Inserted.qc_key = Deleted.qc_key
   AND    Inserted.qclineno = Deleted.qclineno
   AND    Inserted.qc_key + Inserted.qclineno > @c_qc_key + @c_qclineno
   AND    Inserted.toqty > 0
   AND    ISNULL(RTRIM(Inserted.toloc),'') <> ''
   AND    deleted.Status <> '9'
   ORDER BY Inserted.qc_key, Inserted.qclineno

   SELECT @n_cnt = @@ROWCOUNT

   IF @n_cnt = 0
   BEGIN
      SET ROWCOUNT 0
      BREAK
   END
   ELSE
   BEGIN
      SET ROWCOUNT 0
      /* check FROM/to loc is not the same */
      -- 24 Sept 2004 YTWan - FBR_JAMO015-Finalize IQC - START
      IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_Storerkey
                AND ConfigKey = 'FinalizeIQC' AND sValue = '1')
      BEGIN
         IF NOT UPDATE(FinalizeFlag)
         BEGIN
            BREAK
         END
      END
      --ELSE -- SOS# 200797
      -- 24 Sept 2004 YTWan - FBR_JAMO015-Finalize IQC - END

      -- SOS# 200797 (Start)
      -- IF NOT (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NULL)
      -- BEGIN
      --    IF @c_fromid = @c_toid
      --    BEGIN
      --       CONTINUE
      --    END
      -- END
      -- SOS# 200797 (END)
      /*
      -- Remark by June 28.Jan.02
      -- HK Phase II - FBR043
        IF @c_fromloc = @c_toloc
        BEGIN
              CONTINUE
        END
        ELSE
        BEGIN
       IF (SELECT LocationFlag FROM Loc where loc = @c_toloc) <> 'DAMAGE'
              BEGIN
                   SELECT @n_continue = 3
                   SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90204
                   SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) +
                         ': Location flag should be DAMAGE. (ntrInventoryQCDetailUpdate)' +
                         ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
                   BREAK
              END
        END
      */
      /* get lottables for the lot */
      SELECT @c_lottable01 = Lottable01,
             @c_lottable02 = Lottable02,
             @c_lottable03 = Lottable03,
             @d_lottable04 = Lottable04,
             @d_lottable05 = Lottable05,
             @c_lottable06 = Lottable06,     --(CS01)
             @c_lottable07 = Lottable07,     --(CS01)
             @c_lottable08 = Lottable08,     --(CS01)
             @c_lottable09 = Lottable09,     --(CS01)
             @c_lottable10 = Lottable10,     --(CS01)
             @c_lottable11 = Lottable11,     --(CS01)
             @c_lottable12 = Lottable12,     --(CS01)
             @d_lottable13 = Lottable13,     --(CS01)
             @d_lottable14 = Lottable14,     --(CS01)
             @d_lottable15 = Lottable15      --(CS01)
      FROM   LotAttribute  WITH (NOLOCK)
      WHERE  Lot = @c_fromlot
      AND    StorerKey = @c_storerkey
      AND    SKU = @c_sku

      SELECT @n_err = @@Error, @n_cnt = @@ROWCOUNT

      IF @n_err <> 0 or @n_cnt = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90201
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err) +
                          ': Get Lotattribute failed. (ntrInventoryQCDetailUpdate)' +
                          ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         BREAK
      END

      SELECT @c_sourcekey = @c_qc_key + @c_qclineno
      SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''

      EXECUTE nspItrnAddMove
               @n_ItrnSysId    = NULL                                                                                                                                                                                                                                      
            ,  @c_StorerKey    = @c_StorerKey                                                                                                                                                                                                                              
            ,  @c_Sku          = @c_Sku                                                                                                                                                                                                                                    
            ,  @c_Lot          = @c_fromLot                                                                                                                                                                                                                                
            ,  @c_FromLoc      = @c_FromLoc                                                                                                                                                                                                                                
            ,  @c_FromID       = @c_FromID                                                                                                                                                                                                                                 
            ,  @c_ToLoc        = @c_ToLoc                                                                                                                                                                                                                                  
            ,  @c_ToID         = @c_ToID                                                                                                                                                                                                                                   
            ,  @c_Status       = NULL                                                                                                                                                                                                                                      
            ,  @c_lottable01   = @c_lottable01                                                                                                                                                                                                                             
            ,  @c_lottable02   = @c_lottable02                                                                                                                                                                                                                             
            ,  @c_lottable03   = @c_lottable03                                                                                                                                                                                                                             
            ,  @d_lottable04   = @d_lottable04                                                                                                                                                                                                                             
            ,  @d_lottable05   = @d_lottable05                                                                                                                                                                                                                             
            ,  @c_lottable06   = @c_lottable06      --(CS01)                                                                                                                                                                                                               
            ,  @c_lottable07   = @c_lottable07      --(CS01)                                                                                                                                                                                                               
            ,  @c_lottable08   = @c_lottable08      --(CS01)                                                                                                                                                                                                               
            ,  @c_lottable09   = @c_lottable09      --(CS01)                                                                                                                                                                                                               
            ,  @c_lottable10   = @c_lottable10      --(CS01)                                                                                                                                                                                                               
            ,  @c_lottable11   = @c_lottable11      --(CS01)                                                                                                                                                                                                               
            ,  @c_lottable12   = @c_lottable12      --(CS01)                                                                                                                                                                                                               
            ,  @d_lottable13   = @d_lottable13      --(CS01)                                                                                                                                                                                                               
            ,  @d_lottable14   = @d_lottable14      --(CS01)                                                                                                                                                                                                               
            ,  @d_lottable15   = @d_lottable15      --(CS01)                                                                                                                                                                                                               
            ,  @n_casecnt      = 0                                                                                                                                                                                                                                         
            ,  @n_innerpack    = 0                                                                                                                                                                                                                                         
            ,  @n_qty          = @n_toqty                                                                                                                                                                                                                                  
            ,  @n_pallet       = 0                                                                                                                                                                                                                                         
            ,  @f_cube         = 0                                                                                                                                                                                                                                         
            ,  @f_grosswgt     = 0                                                                                                                                                                                                                                         
            ,  @f_netwgt       = 0                                                                                                                                                                                                                                         
            ,  @f_otherunit1   = 0                                                                                                                                                                                                                                         
            ,  @f_otherunit2   = 0                                                                                                                                                                                                                                         
            ,  @c_SourceKey    = @c_sourcekey                                                                                                                                                                                                                              
            ,  @c_SourceType   = 'ntrInventoryQCDetailUpdate'                                                                                                                                                                                                              
            ,  @c_PackKey      = @c_PackKey                                                                                                                                                                                                                                
            ,  @c_UOM          = @c_UOM                                                                                                                                                                                                                                    
            ,  @b_UOMCalc      = 0                                                                                                                                                                                                                                         
            ,  @d_EffectiveDate= NULL                                                                                                                                                                                                                                      
            ,  @c_itrnkey      = @c_itrnkey    OUTPUT                                                                                                                                                                                                                      
            ,  @b_Success      = @b_Success    OUTPUT                                                                                                                                                                                                                      
            ,  @n_err          = @n_err        OUTPUT                                                                                                                                                                                                                      
            ,  @c_errmsg       = @c_errmsg     OUTPUT                                                                                                                                                                                                                      
            ,  @c_MoveRefKey   = ''                                                                                                                                                                                                                                        
            ,  @c_Channel      = @c_Channel                                                                                                                                                                                                                                
            ,  @n_Channel_ID   = @n_Channel_ID  OUTPUT                                                                                                                                                                                                                     

      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 90202
         SELECT @c_errmsg ='NSQL'+CONVERT(char(5),@n_err) +
                           ': Execute Move Failed. (ntrInventoryQCDetailUpdate)' +
                           ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
      END
      ELSE
      BEGIN
         UPDATE InventoryQCDetail WITH (ROWLOCK)
         SET    Status     = '9',
                TrafficCop = NULL,
                EditDate = GETDATE(),   --tlting
                EditWho = SUSER_SNAME()
            ,   Channel_ID = @n_Channel_ID      --(Wan01)
         WHERE  qc_key     = @c_qc_key
         AND    qclineno   = @c_qclineno

         SELECT @n_err = @@Error, @n_cnt = @@ROWCOUNT

         IF @n_err <> 0 or @n_cnt = 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 90203
            SELECT @c_errmsg ='NSQL'+CONVERT(char(5),@n_err) +
                              ': UPDATE Status failed . (ntrInventoryQCDetailUpdate)' +
                              ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
         END

         -- SOS# 21779 Date: 27-May-2004
         -- Added By SHONG
         -- ULP/ CMC interface for IQC transactions
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_StorerKey AND
                      ConfigKey = 'ULPITF' AND sValue = '1')
            BEGIN
               IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)
                         JOIN InventoryQC (NOLOCK) ON (InventoryQC.Reason = CODELKUP.Code AND
                                                       InventoryQC.QC_Key = @c_qc_key)
                         WHERE ListName = 'IQCTYPE' )
               BEGIN
                  EXEC ispGenTransmitLog 'ULPICQ', @c_qc_key, @c_qclineno, '', ''
                     , @b_success OUTPUT
                     , @n_err     OUTPUT
                     , @c_errmsg  OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg ="NSQL"+CONVERT(char(5),@n_err)+": Insert Into TransmitLog Table (ULPICQ) Failed (ntrInventoryQCDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  END
               END
            END
         END

         -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4) - Start
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_StorerKey AND
                                     ConfigKey = 'C4ITF' AND sValue = '1')
            BEGIN
               IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK)
                         JOIN InventoryQC (NOLOCK) ON (InventoryQC.Reason = CODELKUP.Code AND
                                                       InventoryQC.QC_Key = @c_qc_key)
                         WHERE ListName = 'IQCTYPE')
               BEGIN
                  -- Get LocationFlag
                  SELECT @c_FromLocFlag = LocationFlag FROM LOC (NOLOCK) WHERE Loc = @c_fromloc
                  SELECT @c_ToLocFlag = LocationFlag FROM LOC (NOLOCK) WHERE Loc = @c_toloc

                  IF (@c_FromLocFlag <> @c_ToLocFlag) AND (@c_ToLocFlag = 'DAMAGE')
                  BEGIN
                     EXEC ispGenTransmitLog2 'C4IQCMOVE', @c_qc_key, @c_qclineno, @c_storerkey, ''
                        , @b_success OUTPUT
                        , @n_err     OUTPUT
                        , @c_errmsg  OUTPUT

                     IF NOT @b_success = 1
                     BEGIN
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg ="NSQL"+CONVERT(char(5),@n_err)+": Insert Into TransmitLog2 Table (C4IQCMOVE) Failed (ntrInventoryQCDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                     END
                  END
               END
            END
         END
         -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4) - END
      END
    END
 END

 IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
 BEGIN
    UPDATE InventoryQCDetail with (ROWLOCK)
    SET EditDate   = GETDATE(),
        EditWho    = SUSER_SNAME(),
        TrafficCop = NULL
    FROM InventoryQCDetail, INSERTED
    WHERE InventoryQCDetail.QC_Key = INSERTED.QC_Key
    AND InventoryQCDetail.qclineno = INSERTED.qclineno
    AND InventoryQCDetail.Status = '9'                -- tlting01
    SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
    IF @n_err <> 0
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90205   -- Should Be SET To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg ='NSQL'+CONVERT(char(5),@n_err)+': UPDATE Editdate/User Failed On Table InventoryQCDetail. (ntrInventoryQCDetailUpdate)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
    END
 END
 SET ROWCOUNT 0
 SET NOCOUNT OFF

IF @n_continue = 3  -- Error Occured - Process And Return
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, 'ntrInventoryQCDetailUpdate'
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END

GO