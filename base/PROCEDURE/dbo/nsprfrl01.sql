SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC    [dbo].[nspRFRL01]
@c_sendDelimiter    NVARCHAR(1)
,              @c_ptcid            NVARCHAR(5)
,              @c_userid           NVARCHAR(10)
,              @c_taskId           NVARCHAR(10)
,              @c_databasename     NVARCHAR(5)
,              @c_appflag          NVARCHAR(2)
,              @c_recordType       NVARCHAR(2)
,              @c_server           NVARCHAR(30)
,              @c_storerkey        NVARCHAR(30)
,              @c_lot              NVARCHAR(10)
,              @c_sku              NVARCHAR(30)
,              @c_fromloc          NVARCHAR(18)
,              @c_fromid           NVARCHAR(18)
,              @c_toloc            NVARCHAR(18)
,              @c_toid             NVARCHAR(18)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @c_reference        NVARCHAR(10)
,              @c_outstring        NVARCHAR(255)  OUTPUT
,              @b_Success          int        OUTPUT
,              @n_err              int        OUTPUT
,              @c_errmsg           NVARCHAR(250)  OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE @b_debug int
SELECT @b_debug = 0
DECLARE        @n_continue int        ,  
@n_starttcnt int        , -- Holds the current transaction count
@c_preprocess NVARCHAR(250) , -- preprocess
@c_pstprocess NVARCHAR(250) , -- post process
@n_err2 int               -- For Additional Error Detection
DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
DECLARE @c_dbnamestring NVARCHAR(255)
DECLARE @n_cqty int, @n_returnrecs int
SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
SELECT @c_retrec = "01"
SELECT @n_returnrecs=1
declare @n_count int
declare @n_opencursor int
   /* #INCLUDE <SPRFRL01_1.SQL> */     
-- Added By Shong
-- Date: 06-Mar-2002
-- Project: PFCHK02
-- FBR: FBR072
-- Purpose: Reject/Prompt Error Message to the RF device when the From Facility doesn't match to the
--          To Facility
-- Begin
IF @n_continue = 1 OR @n_continue = 2
BEGIN
	DECLARE @c_FromFacility NVARCHAR(5),
			  @c_ToFacility   NVARCHAR(5)
	SELECT @c_FromFacility = FACILITY
	FROM   LOC (NOLOCK)
	WHERE  LOC = @c_fromloc
	SELECT @c_ToFacility = FACILITY
	FROM   LOC (NOLOCK)
	WHERE  LOC = @c_ToLoc
	IF dbo.fnc_RTrim(@c_FromFacility) <> dbo.fnc_RTrim(@c_ToFacility) 
	BEGIN
    SELECT @n_continue = 3
    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62261   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Moves between Facilities is NOT ALLOW (nspRFRL01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
	END
END	
-- End
DECLARE @n_QtyNeedToMove int
DECLARE @c_cursor_statement NVARCHAR(516)
SELECT @n_opencursor = 0

-- commented by Wally: no need to check here since nspg_GETSKU below will do the checking
/*
-- validates the sku + storerkey combination - by Jeff
IF @n_continue = 1 OR @n_continue = 2
BEGIN
 IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
 BEGIN
    IF NOT EXISTS (SELECT 1 FROM SKU (NOLOCK) WHERE SKU = @c_sku and STORERKEY = @c_storerkey)
    BEGIN
       SELECT @n_continue = 3
       SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62243   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Wrong Storerkey and SKU combination (nspRFRL01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
    END
 END
END
--
*/

IF @n_continue=1 OR @n_continue=2
BEGIN
	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL -- A blank sku is legal for moves since it could be a full pallet move.
	BEGIN
		SELECT @b_success = 0
		EXECUTE nspg_GETSKU
		@c_StorerKey   = @c_StorerKey,
		@c_sku         = @c_sku     OUTPUT,
		@b_success     = @b_success OUTPUT,
		@n_err         = @n_err     OUTPUT,
		@c_errmsg      = @c_errmsg  OUTPUT
		IF NOT @b_success = 1
		BEGIN
			SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62243   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Wrong Storerkey and SKU combination (nspRFRL01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
		END
		ELSE IF @b_debug = 1
		BEGIN
			SELECT @c_sku "@c_sku"
		END
	END
END
IF @n_continue = 1 or @n_continue = 2
BEGIN
	SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
END
/* check for products and make sure it's not allocated or picked. */
IF @n_continue = 1 OR @n_continue = 2
BEGIN
 -- Modify by SHONG 17th Nov 2001
 -- Only check the specified id plus sku, plus
 SELECT @c_cursor_statement = 'DECLARE CURSOR_CANDIDATES SCROLL CURSOR FOR ' +
                              'SELECT STORERKEY, SKU, LOT, LOC, ID, QTY  ' + 
                              'FROM LOTxLOCxID (NOLOCK) WHERE Qty > 0 ' + 
                              'AND ( QTYALLOCATED > 0 OR QTYPICKED > 0) ' 
 IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_fromid)) IS NOT NULL
 BEGIN
    SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND ID = N''' + dbo.fnc_RTrim(@c_fromid) + ''' '
 END
 IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sku)) IS NOT NULL
 BEGIN
    SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND STORERKEY = N''' + dbo.fnc_RTrim(@c_storerkey) + ''' '
    SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND SKU = N''' + dbo.fnc_RTrim(@c_SKU) + ''' '
 END
 IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_lot)) IS NOT NULL
 BEGIN
    SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND LOT = N''' + dbo.fnc_RTrim(@c_lot) + ''' '
 END
 IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_fromloc)) IS NOT NULL
 BEGIN
    SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND LOC = N''' + dbo.fnc_RTrim(@c_fromloc) + ''' '
 END
 EXECUTE (@c_cursor_statement)
 SELECT @n_err = @@ERROR
 IF @n_err = 16915 
 BEGIN
    CLOSE CURSOR_CANDIDATES
    DEALLOCATE CURSOR_CANDIDATES
 END
 OPEN CURSOR_CANDIDATES
 SELECT @n_err = @@ERROR
 IF @n_err = 16905 
 BEGIN
    CLOSE CURSOR_CANDIDATES
    DEALLOCATE CURSOR_CANDIDATES
 END
 IF @n_err <> 0
 BEGIN
    SELECT @n_continue = 3
    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62243   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
    SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation/Opening of Candidate Cursor Failed! (nspRFRL01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
 ELSE
 BEGIN
    IF @@CURSOR_ROWS > 0
		BEGIN
      	SELECT @b_success = 0, @n_continue = 3 , @n_err = 62243
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Cannot Move Allocated/Picked Qty (nspRFRL01)"
		END      
    CLOSE CURSOR_CANDIDATES
    DEALLOCATE CURSOR_CANDIDATES
 END
END
/* check for to location */
-- Added By Shong
-- Date: 13th Nov 2001
IF @n_continue = 1 OR @n_continue = 2
BEGIN
	IF NOT dbo.fnc_LTrim(RTRIM (@c_toloc) ) IS NULL
	BEGIN
		IF NOT EXISTS (SELECT 1 
                   FROM LOC (NOLOCK) 
                   WHERE LOC = @c_toloc )
		BEGIN
      	SELECT @b_success = 0, @n_continue = 3 , @n_err = 62246
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Location (nspRFRL01)"
		END
	END
   ELSE
   BEGIN
      SELECT @b_success = 0, @n_continue = 3 , @n_err = 62247
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Blank Location is not allow(nspRFRL01)"
   END
END
-- Added By SHONG on 03-Oct-2004 
IF @n_continue = 1 OR @n_continue = 2
BEGIN
   DECLARE @nPalletCnt int, 
           @nMaxPallet int
          
	IF NOT dbo.fnc_LTrim(RTRIM (@c_toloc) ) IS NULL
	BEGIN
      IF NOT dbo.fnc_LTrim(RTRIM (@c_fromid) ) IS NULL
      BEGIN
   		SELECT @nPalletCnt = COUNT(DISTINCT ID) FROM LOTxLOCxID (NOLOCK) 
         WHERE LOC = @c_toloc 
           AND ID <> @c_fromid 
           AND QTY > 0 
           AND dbo.fnc_RTrim(ID) IS NOT NULL AND dbo.fnc_RTrim(ID) <> '' 

         IF @nPalletCnt IS NULL
            SELECT @nPalletCnt = 0 

         SELECT @nMaxPallet = MaxPallet
         FROM   LOC (NOLOCK)
         WHERE  LOC = @c_toloc

         IF @nPalletCnt + 1 > @nMaxPallet
   		BEGIN
         	SELECT @b_success = 0, @n_continue = 3 , @n_err = 62246
            SELECT @c_errmsg='NSQL '+CONVERT(char(5),@n_err)+': Location Already have Pallet, Maximum Pallet Allow = ' +
                  dbo.fnc_RTrim(CAST(@nMaxPallet as NVARCHAR(5))) + ' (nspRFRL01)'
   		END
      END 
	END
END

/* modified by jeff, to cater for multisku in one pallet */
IF @n_continue = 1 or @n_continue = 2
BEGIN
	IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromid) )  IS NULL -- if fromid is not blank
	BEGIN
		SELECT @n_count = COUNT(*) FROM LOTXLOCXID (NOLOCK) WHERE ID = @c_fromid
	END 
	ELSE
	BEGIN
		SELECT @n_count = 1
	END
	IF @n_count = 1
	BEGIN	
		SELECT @b_success = 1
		EXECUTE nspItrnAddMove
		@n_ItrnSysId    = NULL,  
		@c_itrnkey      = NULL,
		@c_StorerKey    = @c_storerkey,
		@c_Sku          = @c_sku,
		@c_Lot          = @c_lot,
		@c_FromLoc      = @c_fromloc,
		@c_FromID       = @c_fromid, 
		@c_ToLoc        = @c_toloc, 
		@c_ToID         = @c_toid,  
		@c_Status       = "",
		@c_lottable01   = "",
		@c_lottable02   = "",
		@c_lottable03   = "",
		@d_lottable04   = NULL,
		@d_lottable05   = NULL,
		@n_casecnt      = 0,
		@n_innerpack    = 0,      
		@n_qty          = @n_qty,
		@n_pallet       = 0,
		@f_cube         = 0,
		@f_grosswgt     = 0,
		@f_netwgt       = 0,
		@f_otherunit1   = 0,
		@f_otherunit2   = 0,
		@c_SourceKey    = @c_reference,
		@c_SourceType   = "nspRFRL01",
		@c_PackKey      = @c_packkey,
		@c_UOM          = @c_uom,
		@b_UOMCalc      = 1,
		@d_EffectiveDate = NULL,
		@b_Success      = @b_Success  OUTPUT,
		@n_err          = @n_err      OUTPUT,
		@c_errmsg       = @c_errmsg   OUTPUT
		IF NOT @b_success=1
		BEGIN
			SELECT @n_continue = 3
		END
	END
	ELSE
	BEGIN -- n_count > 1
		declare @c_originalid NVARCHAR(18)
		select @c_originalid = @c_fromid
    -- Check is the id is exist in more then 1 location
    IF EXISTS(SELECT 1 FROM LOTxLOCxID (NOLOCK)
              WHERE LOC <> @c_fromloc
              AND   ID = @c_originalid
              AND   Qty > 0)
    BEGIN
       SELECT @b_success = 0, @n_continue = 3 , @n_err = 62248
       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ID exists in more then 1 location (nspRFRL01)"
    END
    IF @n_continue = 1 or @n_continue = 2
    BEGIN
       SELECT @c_cursor_statement = ''
       SELECT @c_cursor_statement = 'DECLARE CURSOR_ID SCROLL CURSOR FOR ' +
                                    'SELECT STORERKEY, SKU, LOT, LOC, ID, QTY  ' + 
                                    'FROM LOTxLOCxID (NOLOCK) WHERE Qty > 0 ' 
         IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_fromid)) IS NOT NULL
       BEGIN
          SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND ID = N''' + dbo.fnc_RTrim(@c_fromid) + ''' '
       END
       IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_sku)) IS NOT NULL
       BEGIN
          SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND STORERKEY = N''' + dbo.fnc_RTrim(@c_storerkey) + ''' '
          SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND SKU = N''' + dbo.fnc_RTrim(@c_SKU) + ''' '
       END
       IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_lot)) IS NOT NULL
       BEGIN
          SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND LOT = N''' + dbo.fnc_RTrim(@c_lot) + ''' '
       END
       IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_fromloc)) IS NOT NULL
       BEGIN
          SELECT @c_cursor_statement = dbo.fnc_RTrim(@c_cursor_statement) + ' AND LOC = N''' + dbo.fnc_RTrim(@c_fromloc) + ''' '
       END
-- select @c_cursor_statement
       EXECUTE (@c_cursor_statement)
       SELECT @n_err = @@ERROR
       IF @n_err = 16915 
       BEGIN
          CLOSE CURSOR_ID
          DEALLOCATE CURSOR_ID
       END
       OPEN CURSOR_ID
       SELECT @n_opencursor = 1
       SELECT @n_err = @@ERROR
       IF @n_err = 16905 
       BEGIN
          CLOSE CURSOR_ID
          DEALLOCATE CURSOR_ID
          SELECT @n_opencursor = 0
       END
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 62243   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Creation/Opening of ID Cursor Failed! (nspRFRL01)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
       END
       ELSE
       BEGIN
          IF @@CURSOR_ROWS = 0
          BEGIN
          	SELECT @b_success = 0, @n_continue = 3 , @n_err = 62243
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Id not found (nspRFRL01)"
          END
          -- if more then 1 rows returned and qty was provided
          SELECT @n_QtyNeedToMove = 0
          IF @@CURSOR_ROWS > 1
          BEGIN
             -- if specify qty to move, I don't know which sku or lot to move
             IF (NOT @n_qty IS NULL) AND @n_qty > 0
             BEGIN
                SELECT @b_success = 0, @n_continue = 3 , @n_err = 62250
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": System Found more then 1 SKU in the pallet (nspRFRL01)"
             END
             -- if not moving all the sku or lots in the pallet to next location
             -- the to id should be the new id and not allow to blank
             IF @@CURSOR_ROWS <> (SELECT COUNT(*) 
                                  FROM LOTxLOCxID (NOLOCK) 
                                  WHERE ID = @c_FromID 
                                    AND LOC = @c_fromloc 
                                    AND Qty > 0) AND
                (@c_fromid = @c_toid OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NULL )
             BEGIN
                SELECT @b_success = 0, @n_continue = 3 , @n_err = 62250
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": New ID is require when moving partial pallet (nspRFRL01)"
             END
          END
          ELSE IF @@CURSOR_ROWS = 1
          BEGIN
             -- Check Whether the to location is lose id or not, if not disallow to move
             -- if partial move or moving single sku from multiple sku pallet..
             IF NOT EXISTS(SELECT 1 FROM LOC (NOLOCK) WHERE LOC = @c_toloc AND LoseId = '1') 
                AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toid)) IS NULL
                AND (SELECT COUNT(*) 
                                  FROM LOTxLOCxID (NOLOCK) 
                                  WHERE ID = @c_FromID 
                                    AND LOC = @c_fromloc 
                                    AND Qty > 0) > 1
             BEGIN
                SELECT @b_success = 0, @n_continue = 3 , @n_err = 62251
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+': Cannot move partial pallet ID to next location (nspRFRL01)'
             END
             SELECT @n_QtyNeedToMove = @n_qty 
          END
       END -- IF @n_continue = 1 OR @n_continue = 2
 		IF @n_continue = 1 OR @n_continue = 2
 		BEGIN
          FETCH NEXT FROM cursor_id INTO @c_storerkey, @c_sku, @c_lot, @c_fromloc, @c_fromid, @n_qty
 		   WHILE @@FETCH_STATUS = 0
 		   BEGIN
             SELECT @b_success = 1
             IF @n_QtyNeedToMove > 0 
                SELECT @n_qty = @n_QtyNeedToMove
             ELSE IF @n_QtyNeedToMove > @n_Qty
             BEGIN
                SELECT @b_success = 0, @n_continue = 3 , @n_err = 62250
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+
                      ": Try to move quantity more then system quantity (nspRFRL01)"
                BREAK
             END
             EXECUTE nspItrnAddMove
             	@n_ItrnSysId    = NULL,  
                @c_itrnkey      = NULL,
                @c_StorerKey    = @c_storerkey,
                @c_Sku          = @c_sku,
                @c_Lot          = @c_lot,
                @c_FromLoc      = @c_fromloc,
                @c_FromID       = @c_fromid, 
                @c_ToLoc        = @c_toloc, 
                @c_ToID         = @c_toid,  
                @c_Status       = "",
                @c_lottable01   = "",
                @c_lottable02   = "",
                @c_lottable03   = "",
                @d_lottable04   = NULL,
                @d_lottable05   = NULL,
                @n_casecnt      = 0,
                @n_innerpack    = 0,      
                @n_qty          = @n_qty,
                @n_pallet       = 0,
                @f_cube         = 0,
                @f_grosswgt     = 0,
                @f_netwgt       = 0,
                @f_otherunit1   = 0,
                @f_otherunit2   = 0,
                @c_SourceKey    = @c_reference,
                @c_SourceType   = "nspRFRL01",
                @c_PackKey      = @c_packkey,
                @c_UOM          = @c_uom,
                @b_UOMCalc      = 1,
                @d_EffectiveDate = NULL,
                @b_Success      = @b_Success  OUTPUT,
                @n_err          = @n_err      OUTPUT,
                @c_errmsg       = @c_errmsg   OUTPUT
             IF NOT @b_success=1
             BEGIN
                SELECT @n_continue = 3
                BREAK
             END
             FETCH NEXT FROM cursor_id INTO @c_storerkey, @c_sku, @c_lot, @c_fromloc, @c_fromid, @n_qty
 			END -- while
       END
		END -- if n_continue = 1
    IF @n_opencursor = 1
    BEGIN
 		CLOSE CURSOR_ID
 		DEALLOCATE CURSOR_ID
    END
	END -- n_count > 1
END -- if @n_continue = 1
IF @n_continue=3
BEGIN
 IF @c_retrec="01"
 BEGIN
    SELECT @c_retrec="09"
 END
END
ELSE
BEGIN
 SELECT @c_retrec="01"
END
IF @n_continue=1 OR @n_continue=4
BEGIN
 SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
 + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
 + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
 + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
 + dbo.fnc_RTrim(@c_errmsg)
 SELECT dbo.fnc_RTrim(@c_outstring)
END
ELSE
BEGIN
SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
+ dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
+ dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
+ dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
+ dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
+ dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
+ dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
+ dbo.fnc_RTrim(@c_errmsg)
SELECT dbo.fnc_RTrim(@c_outstring)
END
   /* #INCLUDE <SPRFRL01_2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
SELECT @b_success = 0
IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
execute nsp_logerror @n_err, @c_errmsg, "nspRFRL01"
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
END

GO