SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
CREATE PROC    [dbo].[nspRFPA01]
/*
             @c_sendDelimiter    NVARCHAR(1)  = ""
,              @c_ptcid            NVARCHAR(5)  = ""
,              @c_userid           NVARCHAR(10) = ""
,              @c_taskId           NVARCHAR(10) = ""
,              @c_databasename     NVARCHAR(5)  = ""
,              @c_appflag          NVARCHAR(2)  = ""
,              @c_recordType       NVARCHAR(2)  = ""
,              @c_server           NVARCHAR(30) = ""
,              @c_storerkey        NVARCHAR(15) = ""
,              @c_lot              NVARCHAR(10) = ""
,              @c_sku              NVARCHAR(20) = ""       
,              @c_id               NVARCHAR(18) = ""
,              @c_fromloc          NVARCHAR(10) = ""
,              @n_qty              int      = 0
,              @c_uom              NVARCHAR(10) = ""
,              @c_packkey          NVARCHAR(10) = ""
,              @c_outstring        NVARCHAR(255) = NULL    OUTPUT
,              @b_Success          int      = 0        OUTPUT
,              @n_err              int      = 0        OUTPUT
,              @c_errmsg           NVARCHAR(250) = ""      OUTPUT
*/
             @c_sendDelimiter    NVARCHAR(1)  
,              @c_ptcid            NVARCHAR(5)  
,              @c_userid           NVARCHAR(10) 
,              @c_taskId           NVARCHAR(10) 
,              @c_databasename     NVARCHAR(5)  
,              @c_appflag          NVARCHAR(2)  
,              @c_recordType       NVARCHAR(2)  
,              @c_server           NVARCHAR(30) 
,              @c_storerkey        NVARCHAR(15)
,              @c_lot              NVARCHAR(10)
,              @c_sku              NVARCHAR(20)
,              @c_id               NVARCHAR(18)
,              @c_fromloc          NVARCHAR(10)
,              @n_qty              int
,              @c_uom              NVARCHAR(10)
,              @c_packkey          NVARCHAR(10)
,              @c_reference        NVARCHAR(10)
,              @c_outstring        NVARCHAR(255) OUTPUT
,              @b_Success          int       OUTPUT
,              @n_err              int       OUTPUT
,              @c_errmsg           NVARCHAR(250) OUTPUT
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE        @n_continue int        ,  /* continuation flag 
                              1=Continue
                              2=failed but continue processsing 
                              3=failed do not continue processing 
                              4=successful but skip furthur processing */                                               
            @n_starttcnt int        , -- Holds the current transaction count                                                                                           
            @c_preprocess NVARCHAR(250) , -- preprocess
            @c_pstprocess NVARCHAR(250) , -- post process
            @n_err2 int,              -- For Additional Error Detection
            @b_debug int,             -- Debug Flag
            @n_cnt int                -- Holds @@RECCOUNT
   /* Declare variables to check RFPUTAWAY cursor for PendingMoveIn updates */ 
   DECLARE  @c_checkstorerkey    NVARCHAR(15),
            @c_checklot          NVARCHAR(10),
            @c_checkFromloc      NVARCHAR(10),
            @c_checkSuggestedloc NVARCHAR(10),
            @c_checkid           NVARCHAR(18),
            @c_checkptcid        NVARCHAR(10),
            @n_checkqty          int,
            @n_convqty           int,
            @c_packuom1          NVARCHAR(10),
            @f_packcasecnt       float,
            @c_packuom2          NVARCHAR(10),
            @f_packinnerpack     float,
            @c_packuom3          NVARCHAR(10),
            @f_packqty           float,
            @c_packuom4          NVARCHAR(10),
            @f_packpallet        float,
            @d_checkadddate      datetime
   /* Declare RF Specific Variables */
   DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
   /* Set default values for variables */
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   SELECT @c_retrec = "01"     
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN 
        SELECT @c_storerkey "@c_storerkey", @c_lot "@c_lot", @c_sku "@c_sku", @c_id "@c_id", @c_fromloc "@c_fromloc", @n_qty "@n_qty", @c_uom "@c_uom", @c_packkey "@c_packkey"
   END     
    -- Added By SHONG
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
    	SELECT @c_packkey= SKU.PACKKEY,
              @c_uom = CASE WHEN dbo.fnc_RTrim(dbo.fnc_LTrim(@c_uom)) IS NULL THEN PACK.PackUOM3
                            ELSE @c_uom
                       END
    	FROM SKU (NOLOCK), PACK (NOLOCK)
    	WHERE SKU = @c_sku
    	AND STORERKEY = @c_storerkey
       AND SKU.PACKKEY = PACK.PACKKEY
       IF @b_debug = 1 SELECT 'packkey' = @c_packkey
    END
    -- End
-- Added By SHONG
-- Check is the pallet qty available?
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN
       DECLARE @c_script NVARCHAR(512)
       SELECT @c_script = SPACE(1)
       CREATE TABLE #ROW
          ( NoOfRow int NULL)
       IF @n_Qty IS NOT NULL AND @n_Qty > 0
       BEGIN
          SELECT @c_script = dbo.fnc_RTrim(@c_script) + ' WHERE Qty >= ' + dbo.fnc_RTrim( CAST(@n_Qty AS NVARCHAR(10) )) + ' '
       END
       ELSE
       BEGIN
          SELECT @c_script = dbo.fnc_RTrim(@c_script) + ' WHERE Qty > 0'
       END
       IF dbo.fnc_RTrim(@c_lot) IS NOT NULL 
       BEGIN
          SELECT @c_script = dbo.fnc_RTrim(@c_script) + ' AND LOT = N''' + dbo.fnc_RTrim(@c_lot) + ''' '      
       END
       IF dbo.fnc_RTrim(@c_fromloc) IS NOT NULL 
       BEGIN
          SELECT @c_script = dbo.fnc_RTrim(@c_script) + ' AND LOC = N''' + dbo.fnc_RTrim(@c_fromloc) + ''' '      
       END
       IF dbo.fnc_RTrim(@c_id) IS NOT NULL 
       BEGIN
          SELECT @c_script = dbo.fnc_RTrim(@c_script) + ' AND ID = N''' + dbo.fnc_RTrim(@c_id) + ''' '      
       END  
       INSERT INTO #ROW
       EXEC( 'SELECT COUNT(*) FROM LOTxLOCxID (NOLOCK) ' + @c_script )
       IF NOT EXISTS( SELECT 1 FROM #ROW WHERE NoOfRow > 0)
       BEGIN
          SELECT @n_continue = 3 
          SELECT @n_err = 66203
          SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
       END
       DROP TABLE #ROW
    End
-- End
   /* Execute Preprocess */
   /* #INCLUDE <SPRFPA01_1.SQL> */     
   /* End Execute Preprocess */
   /* Start Main Processing */
   /* Calculate Sku Supercession */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
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
             END
             ELSE IF @b_debug = 1
                BEGIN
                   SELECT @c_sku "@c_sku"
             END
        END         
   END
   /* Calculate next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
   END     
   /* End Calculate Next Task ID */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        /* retrieve using id */
        IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NULL
        BEGIN
             SELECT    @c_lot = lot,
                       @c_storerkey = storerkey,
                       @c_sku = sku,
                       @n_qty = (CASE WHEN (@n_qty IS NULL OR @n_qty = 0) THEN qty - qtypicked
                                     ELSE @n_qty
                                END)
                  FROM LOTxLOCxID (NOLOCK)
                  WHERE id = @c_id
                       AND qty - qtypicked > 0
             SELECT @n_cnt = @@ROWCOUNT          
             IF NOT @n_cnt = 1
             BEGIN
                  /* retrieve using id & loc */
                  IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) IS NULL
                  BEGIN
                       SELECT    @c_lot = lot,
                                 @c_storerkey = storerkey,
                                 @c_sku = sku
                            FROM LOTxLOCxID (nolock)
                            WHERE id = @c_id
                                 AND loc = @c_fromloc
                                 AND qty - qtypicked > 0
                       SELECT @n_cnt = @@ROWCOUNT          
                       IF NOT @n_cnt = 1
                       BEGIN
                            SELECT @n_continue = 3 
                            SELECT @n_err = 66201
                            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
                       END
                  END
                  ELSE
                  BEGIN
                       SELECT @n_continue = 3 
                       SELECT @n_err = 66202
                       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
                  END
             END
        END     
        /* retrieve using lot */
        ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NULL
        BEGIN
             SELECT    @c_storerkey = storerkey,
                       @c_sku = sku
                  FROM LOTxLOCxID (nolock)
                  WHERE lot = @c_lot
                       AND qty - qtypicked > 0
             SELECT @n_cnt = @@ROWCOUNT          
             IF NOT @n_cnt = 1
             BEGIN
                  /* retrieve using lot & loc & id */
                  IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) IS NULL
                  BEGIN
                       SELECT    @c_id = id,
                                 @c_storerkey = storerkey,
                                 @c_sku = sku
                            FROM LOTxLOCxID (nolock)
                            WHERE lot = @c_lot
                                 AND loc = @c_fromloc
                                 AND id = @c_id
                                 AND qty - qtypicked > 0
                       SELECT @n_cnt = @@ROWCOUNT          
                       IF NOT @n_cnt = 1
                       BEGIN
                            SELECT @n_continue = 3 
                            SELECT @n_err = 66203
                            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
                       END
                  END
                  ELSE
                  BEGIN
                       SELECT @n_continue = 3 
                       SELECT @n_err = 66204
                       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
                  END
             END
        END     
        /* retrieve using sku */
        ELSE IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NULL AND NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NULL
        BEGIN
             SELECT    @c_lot = lot,
                       @c_id = id
                  FROM LOTxLOCxID (nolock)
                  WHERE storerkey = @c_storerkey
                       AND sku = @c_sku
                       AND qty - qtypicked > 0
             SELECT @n_cnt = @@ROWCOUNT          
       IF NOT @n_cnt = 1
             BEGIN
                  /* retrieve using sku & loc & id */
                  IF NOT dbo.fnc_LTrim(dbo.fnc_RTrim(@c_fromloc)) IS NULL
                  BEGIN
                       SELECT    @c_lot = lot,
                                 @c_id = id
                            FROM LOTxLOCxID (nolock)
                            WHERE storerkey = @c_storerkey
                                 AND sku = @c_sku
                                 AND loc = @c_fromloc
                                 AND id = @c_id
                                 AND qty - qtypicked > 0
                       SELECT @n_cnt = @@ROWCOUNT          
                       IF NOT @n_cnt = 1
                       BEGIN
                            SELECT @n_continue = 3 
                            SELECT @n_err = 66204
                            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
                       END
                  END
                  ELSE
                  BEGIN
                       SELECT @n_continue = 3 
                       SELECT @n_err = 66205
                       SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
                  END
             END
        END     
        ELSE
        /* error: bad input parameter(s) */
        BEGIN
             SELECT @n_continue = 3 
             SELECT @n_err = 66206
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Input. (nspRFPA01)"
        END
   END     
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        -- We need to make sure that no old rows exist in the RFPUTAWAY table which would indicate the RF Server/unit failed
        -- after the LOTxLOCxID.PendingMoveIn was updated.  Thus we need to subtract old roes qty value to rectify the
        -- situation.
        select @c_checkptcid = SPACE(5)
        WHILE (1=1)
        BEGIN
             SET ROWCOUNT 1
             SELECT @c_checkstorerkey = storerkey,
                    @c_checklot = lot,
                    @c_checkFromLoc = FromLoc,
                    @c_checkSuggestedLoc = SuggestedLoc,
                    @c_checkid = id,
                    @c_checkptcid = ptcid,
                    @n_checkqty = qty,
                    @d_checkadddate = adddate
             FROM RFPUTAWAY (nolock)
                 WHERE adddate   < DateAdd(mi, -60, getdate())
                 AND   ptcid    >= @c_checkptcid
             ORDER BY ptcid, adddate
             IF @@ROWCOUNT = 0
             BEGIN
                  BREAK
             END
             DELETE FROM RFPUTAWAY
                 WHERE ptcid = @c_checkptcid
                   AND adddate = @d_checkadddate
             SELECT @n_cnt = @@ROWCOUNT          
             IF NOT @n_cnt = 1
             BEGIN
                  SELECT @n_continue = 3 
                  SELECT @n_err = 66207
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Delete RFPutaway. (nspRFPA01)"
                  BREAK
             END
             if @b_debug = 1
                select @c_checklot '@c_checklot', @c_checkSuggestedLoc '@c_checkSuggestedLoc', @c_checkid '@c_checkid'
             UPDATE LOTxLOCxID SET PendingMoveIn = PendingMoveIn - @n_checkqty
                 WHERE LOT = @c_checklot
                 AND   LOC = @c_checkSuggestedLoc
                 AND   ID  = @c_checkid
             SELECT @n_cnt = @@ROWCOUNT          
             IF NOT @n_cnt = 1
             BEGIN
                  SELECT @n_continue = 3 
                  SELECT @n_err = 66208
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOTxLOCxID. (nspRFPA01)"
                  BREAK
             END
        END
   END
IF @n_continue=1 OR @n_continue=2
   BEGIN
        /* calculate Put Away Capacity & get Put Away Logic */
        DECLARE @n_putawaycapacity int,
             @c_putcode NVARCHAR(30),
             @c_thputcode NVARCHAR(1)
        SELECT @n_putawaycapacity = @n_qty * StdCube,
               @c_putcode = PutCode
        FROM SKU (nolock)
        WHERE StorerKey = @c_storerkey
        AND Sku = @c_sku
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_putcode)) IS NULL
        BEGIN
             EXECUTE nspGetRight null,	-- facility
               @c_storerkey, 				-- Storerkey
               null,							-- Sku
               'PUTAWAY_IDSTH',		   	   -- Configkey
               @b_success output,
               @c_thputcode output, 
               @n_err output,
               @c_errmsg output
            
             if @c_thputcode = '1'
               SELECT @c_putcode = 'nspASNPASTDth'
             else
                SELECT @c_putcode = "nspPASTD"
        END
        /* execute PutCode */
        if @b_debug = 1
           select "EXECUTE "+@c_putcode +" @c_userid= "+"N'"+dbo.fnc_RTrim(@c_userid)+"'"+","+ "@c_storerkey=N'"+
               dbo.fnc_RTrim(@c_storerkey)+"',@c_lot=N'"+dbo.fnc_RTrim(@c_lot)+"',@c_sku=N'"+dbo.fnc_RTrim(@c_sku)+"',@c_id=N'"+dbo.fnc_RTrim(@c_id)+
               "',@c_fromloc=N'"+dbo.fnc_RTrim(@c_fromloc)+"',@n_qty="+dbo.fnc_RTrim(CONVERT(char(15),@n_qty))+",@c_uom=N'"+
               dbo.fnc_RTrim(@c_uom)+"',@c_packkey=N'"+dbo.fnc_RTrim(@c_packkey)+"',@n_putawaycapacity="+
               dbo.fnc_RTrim(CONVERT(char(15),@n_putawaycapacity))
        
        DECLARE @c_command NVARCHAR(255)
        SELECT @c_command = "EXECUTE "+@c_putcode +" @c_userid= "+"N'"+dbo.fnc_RTrim(@c_userid)+"'"+","+ "@c_storerkey=N'"+
            dbo.fnc_RTrim(@c_storerkey)+"',@c_lot=N'"+dbo.fnc_RTrim(@c_lot)+"',@c_sku=N'"+dbo.fnc_RTrim(@c_sku)+"',@c_id=N'"+dbo.fnc_RTrim(@c_id)+
            "',@c_fromloc=N'"+dbo.fnc_RTrim(@c_fromloc)+"',@n_qty="+dbo.fnc_RTrim(CONVERT(char(15),@n_qty))+",@c_uom=N'"+dbo.fnc_RTrim(@c_uom)+
            "',@c_packkey=N'"+dbo.fnc_RTrim(@c_packkey)+"',@n_putawaycapacity="+dbo.fnc_RTrim(CONVERT(char(15),@n_putawaycapacity))
        EXEC(@c_command)
        IF NOT @@ERROR = 0
        BEGIN
             SELECT @n_continue = 3 
             SELECT @n_err = 66209
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad PutCode. (nspRFPA01)"

        END
   END
   DECLARE @c_toloc NVARCHAR(30)
   SELECT @c_toloc = SPACE(30)
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        /* fetch target location */
        OPEN CURSOR_TOLOC
        IF ABS(@@CURSOR_ROWS) = 0 
        BEGIN
             CLOSE CURSOR_TOLOC
             DEALLOCATE CURSOR_TOLOC
             SELECT @n_continue = 3 
             SELECT @n_err = 66210
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Cursor. (nspRFPA01)"
        END
        ELSE
        BEGIN
             FETCH NEXT
                  FROM CURSOR_TOLOC
                  INTO @c_toloc
            IF NOT @@FETCH_STATUS = 0
            BEGIN
                 SELECT @n_continue = 3 
                 SELECT @n_err = 66211
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Location. (nspRFPA01)"
            END
            ELSE IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_toloc)) IS NULL
            BEGIN
                 SELECT @n_continue = 3 
                 SELECT @n_err = 66211
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": No Suggested Location, Check With Supervisor. (nspRFPA01)"
            END
             CLOSE CURSOR_TOLOC
             DEALLOCATE CURSOR_TOLOC
        END
   END
   /* confirm current packkey */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        EXEC nspGetPack @c_checkstorerkey,              
              @c_sku,
              @c_lot,              
              @c_fromloc,
              @c_id,
              @c_packkey OUTPUT,
              @b_success OUTPUT,
              @n_err OUTPUT,
              @c_errmsg OUTPUT
        IF @b_success = 0
        BEGIN
             SELECT @n_continue = 3 
             SELECT @n_err = 66212
        END
   END
   /* select packkey quantity to eaches conversion columns */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
       SELECT @c_packuom1 = packuom1,
               @f_packcasecnt  = casecnt,
               @c_packuom2 = packuom2,
               @f_packinnerpack = innerpack,
               @c_packuom3 = packuom3,
               @f_packqty      = qty,
               @c_packuom4 = packuom4,
               @f_packpallet   = pallet
        FROM PACK (nolock)
        WHERE packkey = @c_packkey
        IF @@ROWCOUNT = 0
        BEGIN
             SELECT @n_continue = 3 
             SELECT @n_err = 66213
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Missing Pack. (nspRFPA01)"
        END
        ELSE
        BEGIN
             select @n_convqty = 0
             IF UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_uom))) = UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_packuom3)))
             BEGIN
                  select @n_convqty = @n_qty * @f_packqty
             END
             IF UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_uom))) = UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_packuom1)))
             BEGIN
                  select @n_convqty = @n_qty * @f_packcasecnt         
             END
             IF UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_uom))) = UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_packuom2)))
             BEGIN
                  select @n_convqty = @n_qty * @f_packinnerpack
             END
             IF UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_uom))) = UPPER(dbo.fnc_RTrim(dbo.fnc_LTrim(@c_packuom4)))
             BEGIN
                  select @n_convqty = @n_qty * @f_packpallet
             END
        END
   END
   /* Insert a record to provide LOTxLOCxID.PendingMoveIn consitency on a RF failure */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        INSERT RFPUTAWAY (storerkey,
           sku,
           lot,
           Fromloc,             /* Original From Location */
           SuggestedLoc,        /* Location suggested by the PA process */
           id,
           ptcid,
           qty,
           adddate,
           addwho,
           trafficcop,
           archivecop)
        VALUES (@c_storerkey,
           @c_sku,
           @c_lot,
           @c_fromloc,
           @c_toloc,            /* Location suggested by the PA process */
           @c_id,
           @c_ptcid,
           @n_convqty,
           getdate(),
           @c_userid,
           'N',
           'N')
        SELECT @n_cnt = @@ROWCOUNT          
        IF NOT @n_cnt = 1
        BEGIN
             SELECT @n_continue = 3 
             SELECT @n_err = 66214
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert RFPutaway. (nspRFPA01)"
        END
   END
   /* If record does not exist in LOTxLOCxID Then Create it! */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
        if @b_debug = 1
           select @c_storerkey '@c_storerkey', @c_sku '@c_sku', @c_lot '@c_lot',@c_toloc '@c_toloc',@c_id '@c_id'
        IF NOT EXISTS(SELECT * FROM LOTxLOCxID (nolock)
                      WHERE LOT = @c_lot AND LOC = @c_toloc and ID = @c_id)
        BEGIN
             INSERT LOTxLOCxID (STORERKEY,SKU,LOT,LOC,ID)
                        VALUES (@c_storerkey, @c_sku, @c_lot,@c_toloc,@c_id)
             SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
             IF @n_err <> 0
             BEGIN
                  SELECT @n_continue = 3 
                  SELECT @n_err = 66215
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed To LOTxLOCxID. (nspRFPA01)"
             END               
        END
   END
   /* Update LOTxLOCxID.PendingMoveIn quantity */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
     UPDATE LOTxLOCxID SET PendingMoveIn = PendingMoveIn + @n_convqty
 		WHERE LOT = @c_lot
 		AND   LOC = @c_toloc
 		AND   ID  = @c_id
        SELECT @n_cnt = @@ROWCOUNT          
        IF NOT @n_cnt = 1
        BEGIN
             SELECT @n_continue = 3 
             SELECT @n_err = 66216
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update LOTxLOCxID. (nspRFPA01)"
        END
   END
   /* Set RF Return Record */
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
   /* End Set RF Return Record */
   /* Construct RF Return String */
   SELECT @c_outstring =   @c_ptcid     + @c_senddelimiter
            + dbo.fnc_RTrim(@c_userid)    + @c_senddelimiter
            + dbo.fnc_RTrim(@c_taskid)    + @c_senddelimiter
            + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
            + dbo.fnc_RTrim(@c_appflag)   + @c_senddelimiter
            + dbo.fnc_RTrim(@c_retrec)    + @c_senddelimiter
            + dbo.fnc_RTrim(@c_server)    + @c_senddelimiter
            + dbo.fnc_RTrim(@c_errmsg)  + @c_senddelimiter
            + dbo.fnc_RTrim(@c_toloc)
   SELECT dbo.fnc_RTrim(@c_outstring)
   /* End Construct RF Return String */
   /* End Main Processing */
   /* Post Process Starts */
   /* #INCLUDE <SPRFPA01_2.SQL> */
   /* Post Process Ends */
   /* Return Statement */
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
     execute nsp_logerror @n_err, @c_errmsg, "nspRFPA01"
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
     RETURN
   END
   ELSE
   BEGIN
     /* Error Did Not Occur , Return Normally */
     SELECT @b_success = 1
     WHILE @@TRANCOUNT > @n_starttcnt 
     BEGIN
          COMMIT TRAN
     END          
     RETURN
    END
   /* End Return Statement */     
END

GO