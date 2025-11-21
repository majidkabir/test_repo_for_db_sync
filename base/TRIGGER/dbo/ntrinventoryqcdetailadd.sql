SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*******************************************************************************/
/* Trigger: ntrInventoryQCDetailAdd                                            */
/* Creation Date:                                                              */
/* Copyright: IDS                                                              */
/* Written by:                                                                 */
/*                                                                             */
/* Purpose:   InventoryQCDetail Add Trigger                                    */
/*                                                                             */
/* Usage:                                                                      */
/*                                                                             */
/* Called By: When records added into InventoryQCDetail                        */
/*                                                                             */
/* PVCS Version: 1.5                                                           */
/*                                                                             */
/* Version: 7.0                                                                */
/*                                                                             */
/* Data Modifications:                                                         */
/* Date         Author     Ver   Purposes                                      */
/* 20-May-2016  Leong      1.2   Include ArchiveCop.                           */
/* 22-Mar-2018  Wan01      1.5   WMS-4288 - [CN] UA Relocation Phase II -      */
/*                               Exceed Channel of IQC                         */
/*******************************************************************************/

CREATE TRIGGER ntrInventoryQCDetailAdd
ON InventoryQCDetail
FOR INSERT
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
     @b_success  INT           -- Populated by calls to stored procedures - was the proc successful?
   , @n_err      INT           -- Error number returned by stored procedure OR this trigger
   , @c_errmsg   NVARCHAR(250) -- Error message returned by stored procedure OR this trigger
   , @n_continue INT              /* continuation flag
                                     1=Continue
                                     2=failed but continue processsing
                                     3=failed do not continue processing
                                     4=successful but skip furthur processing */
   , @n_starttcnt INT          -- Holds the current transaction count
   , @n_cnt       INT          /* variable to hold @@ROWCOUNT */

SELECT @n_continue = 1, @n_starttcnt = @@TRANCOUNT

-- To Skip all the trigger process when Insert the history records from Archive as user request
IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
BEGIN
   SELECT @n_continue = 4
END

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
        @n_qty               INT,
        @n_toqty             INT,
        @c_itrnkey           NVARCHAR(10),
        @c_lottable01        NVARCHAR(18),
        @c_lottable02        NVARCHAR(18),
        @c_lottable03        NVARCHAR(18),
        @d_lottable04        DATETIME,
        @d_lottable05        DATETIME,
        @c_sourcekey         NVARCHAR(20),
        @c_FromLocFlag       NVARCHAR(10),    -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4)
        @c_ToLocFlag         NVARCHAR(10),       -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4)
        /*add by CSCHONG(CS01) on 22May2014 Add lottable06-lottable15 */
        @c_lottable06        NVARCHAR(30),
        @c_lottable07        NVARCHAR(30),
        @c_lottable08        NVARCHAR(30),
        @c_lottable09        NVARCHAR(30),
        @c_lottable10        NVARCHAR(30),
        @c_lottable11        NVARCHAR(30),
        @c_lottable12        NVARCHAR(30),
        @d_lottable13        DATETIME,
        @d_lottable14        DATETIME,
        @d_lottable15        DATETIME
        /*CS01 END*/
      , @c_Channel            NVARCHAR(20) = '' --(Wan01)
      , @n_Channel_ID         BIGINT = 0        --(Wan01)
SELECT @c_qc_key = '', @c_qclineno = ''

WHILE @n_continue = 1 OR @n_continue = 2
BEGIN
   SET ROWCOUNT 1
   SELECT @c_qc_key           = qc_key,
          @c_qclineno         = qclineno,
          @c_storerkey        = storerkey,
          @c_sku              = sku,
          @c_packkey          = packkey,
          @c_uom              = uom,
          @c_fromlot          = fromlot,
          @c_fromloc          = fromloc,
          @c_fromid           = fromid,
          @n_toqty            = toqty,
          @c_toloc            = toloc,
          @c_toid             = toid
       ,  @c_Channel          = Channel         --(Wan01)
       ,  @n_Channel_ID       = Channel_ID      --(Wan01)
    FROM INSERTED
    WHERE qc_key + qclineno > @c_qc_key + @c_qclineno
    AND   toqty > 0
    AND   dbo.fnc_LTrim(dbo.fnc_RTrim(toloc)) IS NOT NULL
    ORDER BY qc_key, qclineno

   SELECT @n_cnt = @@Rowcount
   IF @n_cnt = 0
   BEGIN
      SET ROWCOUNT 0
      BREAK
   END
   ELSE
   BEGIN
      SET ROWCOUNT 0
      /* check from/to loc is not the same */

      -- 24 Sept 2004 YTWan - FBR_JAMO015-Finalize IQC - START
      IF EXISTS( SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_Storerkey
                 AND ConfigKey = 'FinalizeIQC' AND sValue = '1' )
      BEGIN
         BREAK
      END

      -- 24 Sept 2004 YTWan - FBR_JAMO015-Finalize IQC - END
      IF NOT (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NULL)
      BEGIN
         IF @c_fromid = @c_toid
         BEGIN
            CONTINUE
         END
      END
 /*
    -- Remark by June 28.Jan.02
    -- HK Phase II - FBR043
     IF @c_fromloc = @c_toloc
     BEGIN
       CONTINUE
     END
     ELSE
     BEGIN
        IF (SELECT LocationFlag from Loc where loc = @c_toloc) <> 'DAMAGE'
        BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90104
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err) +
                ": Location flag should be DAMAGE. (ntrInventoryQCDetailAdd)" +
                " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
          Break
        END
     END
 */
      /* get lottables for the lot */
      SELECT   @c_lottable01 = Lottable01,
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
     FROM LotAttribute (NOLOCK)
     WHERE Lot = @c_fromlot
     AND StorerKey = @c_storerkey
     AND Sku = @c_sku

     SELECT @n_err = @@Error, @n_cnt = @@Rowcount
     IF @n_err <> 0 OR @n_cnt = 0
     BEGIN
         SELECT @n_continue = 3
         /* Trap SQL Server Error */
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90101
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err) +
                            ": Get Lotattribute failed. (ntrInventoryQCDetailAdd)" +
                            " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* END Trap SQL Server Error */
         BREAK
     END

     SELECT @c_sourcekey = @c_qc_key + @c_qclineno
     SELECT @b_success = 1, @n_err = 0, @c_errmsg = ''
     /* Execute Move here */
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
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90102
         SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err) +
                            ": Execute Move Failed. (ntrInventoryQCDetailAdd)" +
                            " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         /* END Trap SQL Server Error */
      END
      ELSE
      BEGIN
         UPDATE    InventoryQCDetail
         SET       Status = '9',
                   TrafficCop = NULL
               ,   Channel_ID = @n_Channel_ID      --(Wan01)
         WHERE     qc_key = @c_qc_key
         AND       qclineno = @c_qclineno

         SELECT @n_err = @@Error, @n_cnt = @@Rowcount
         IF @n_err <> 0 OR @n_cnt = 0
         BEGIN
            SELECT @n_continue = 3
            /* Trap SQL Server Error */
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=90103
            SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err) +
                               ": Update Status failed . (ntrInventoryQCDetailAdd)" +
                               " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
            /* END Trap SQL Server Error */
         END
      END

      -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4) - Start
      IF @n_continue = 1 OR @n_continue = 2
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
                                       , @n_err OUTPUT
                                       , @c_errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62900   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                     SELECT @c_errmsg = "NSQL"+CONVERT(char(5),@n_err)+": Insert Into TransmitLog2 Table (C4IQCMOVE) Failed (ntrInventoryQCDetailUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                  END
               END
            END
         END
      END
      -- Added by MaryVong on 29Sept04 (SOS25798 IDSTH-C4) - END
    END
END

SET ROWCOUNT 0
SET NOCOUNT OFF

/* Return Statement */
IF @n_continue = 3  -- Error Occured - Process AND Return
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
   EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrInventoryQCDetailAdd"
   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   RETURN
END
ELSE
BEGIN
   /* Error Did Not Occur , Return Normally */
   WHILE @@TRANCOUNT > @n_starttcnt
   BEGIN
      COMMIT TRAN
   END
   RETURN
END
/* END Return Statement */

GO