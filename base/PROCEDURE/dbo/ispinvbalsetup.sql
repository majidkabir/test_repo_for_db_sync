SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispInvBalSetup]
 AS
 BEGIN -- start of procedure
    DECLARE    	@n_continue    int      ,  
 		@n_starttcnt   int      , -- Holds the current transaction count
 		@n_cnt         int      , -- Holds @@ROWCOUNT after certain operations
 		@c_preprocess  NVARCHAR(250), -- preprocess
 		@c_pstprocess  NVARCHAR(250), -- post process
 		@n_err2        int      , -- For Additional Error Detection
 		@b_debug       int      ,  -- Debug 0 - OFF, 1 - Show ALL, 2 - Map
 		@b_success     int      ,
 		@n_err         int      ,   
 		@c_errmsg      NVARCHAR(250),
 		@errorcount    int		
    SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@n_cnt = 0,@c_errmsg="",@n_err2=0
    SELECT @b_debug = 0
    /* Start Main Processing */
    PRINT 'Upload Lot Balance begins at ' + convert(char(25), getdate(), 120)
    IF @n_continue = 1 OR @n_continue = 2
    BEGIN -- Begin IF 1
       DECLARE @c_breakloop NVARCHAR(1),
               @c_status	 NVARCHAR(5),
 	      @c_batch         NVARCHAR(10),
               @c_errrmk      NVARCHAR(250),
               @c_whcode	 NVARCHAR(2),
 	      @c_itemcode NVARCHAR(15),
               @c_lot            NVARCHAR(13),
               @c_storerkey      NVARCHAR(15),
               @c_loc	        NVARCHAR(10),
 	      @c_loc_exceed     NVARCHAR(10),
               @n_qty    	int,
               @d_expirydate     datetime,
               @n_expiryyear     int,
               @n_expirymth	int,
               @n_expiryday	int,
 	      @c_palletid       NVARCHAR(6),
               @c_sku            NVARCHAR(15),
               @c_packkey        NVARCHAR(10),
               @c_UOM            NVARCHAR(3),
               @c_newitrnkey     NVARCHAR(10),
 	      @c_aisles	 NVARCHAR(3),
 	      @c_zones	 NVARCHAR(3),
 	      @c_bins		int,
 	      @c_levels	 NVARCHAR(3),
               @c_exists         NVARCHAR(1),
 	      @d_receiptdate	datetime,
 	      @n_identityid     int
       SELECT @c_storerkey = ''
       SELECT @c_batch = convert(char(10),max(convert(int, batchno))+1) 
       FROM gdsmaster..conversion_error (nolock)
       WHILE 1=1
       BEGIN --While Begin
           SELECT @c_status = '9', @c_breakloop = 'Y', @c_errrmk = '', @n_continue = 1
           SET ROWCOUNT 1
           SELECT @c_breakloop = 'N', 
 		 @n_identityid = SEQNO,
                  @c_whcode = SWHS#S,
 	         @c_sku = ITEMS,
                  @c_lot = SRL#S,
 		 @c_zones = ZONES,
 		 @c_aisles = AISLS,
 		 @c_levels = LEVLS,
 		 @c_bins = BINS,
 		 @c_loc = EXLOCZ,
                  --@c_loc = RIGHT(dbo.fnc_LTRIM(SWHS#S),1)+Left(dbo.fnc_RTRIM(ZONES),2)+dbo.fnc_RTRIM(AISLS)+dbo.fnc_LTRIM(Str(BINS))+dbo.fnc_RTRIM(LEVLS),
                  @n_qty = QOHS,
 		 @n_expiryyear = EXP4YS,
 		 @n_expirymth = CASE EXPMMS WHEN 99 THEN 12 ELSE EXPMMS END,
 		 @n_expiryday = CASE EXPDDS WHEN 99 THEN 31 ELSE EXPDDS END,
 		 --@d_expirydate = CONVERT(DateTime, dbo.fnc_LTRIM(Str(EXP4YS))+Right(Replicate('0',2)+dbo.fnc_LTRIM(Str(EXPMMS)),2)+Right(Replicate('0',2)+dbo.fnc_LTRIM(Str(EXPDDS)),2), 112),
 		 @c_palletid = PLTID#,
 		 @d_receiptdate = CONVERT(DateTime, left(dbo.fnc_LTRIM(Str(ARRDTY)),4)+ substring(dbo.fnc_LTRIM(str(ARRDTY)),5,2)+ right(dbo.fnc_LTRIM(str(ARRDTY)), 2), 112)
           FROM  [GDSMASTER]..CVT019 (NOLOCK)
           WHERE status = 0
 	  SET ROWCOUNT 0
           IF @c_breakloop = 'Y' BREAK
 	  SELECT @d_expirydate = CONVERT(DateTime, dbo.fnc_LTRIM(Str(@n_expiryyear))+Right(Replicate('0',2)+dbo.fnc_LTRIM(Str(@n_expirymth)),2)+Right(Replicate('0',2)+dbo.fnc_LTRIM(Str(@n_expiryday)),2), 112)
 	  PRINT "@n_IdentityId = "+CONVERT(char(10), @n_IdentityId)
 	  PRINT "@c_loc = "+@c_loc
 	  PRINT "@c_sku = "+@c_sku
 	  PRINT "@c_lot = "+@c_lot
           PRINT "@d_expirydate = "+CONVERT(char(20), @d_expirydate, 120)   
 	  PRINT "@d_receiptdate = "+CONVERT(char(20), @d_receiptdate, 120)  
 	  IF @n_continue = 1 OR @n_continue = 2
           BEGIN
 	     SELECT @c_exists = 'N'
              SELECT @c_exists = 'Y', @c_StorerKey = storerkey, @c_packkey = packkey
              FROM SKU (nolock)
    WHERE sku = @c_sku
              IF @c_exists = 'N'
              BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_status   = '5'
                 SELECT @c_errrmk   = 'Invalid Sku: '+@c_sku
  		PRINT 'Invalid Sku: '+@c_sku
              END
           END 
 	  IF @n_continue = 1 OR @n_continue = 2
           BEGIN
 	     SELECT @c_exists = 'N'
              SELECT @c_exists = 'Y'
 	     FROM LOC (nolock)
 	     WHERE Loc = @c_loc	
              IF @c_exists = 'N'
              BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_status   = '5'
                 SELECT @c_errrmk   = 'Invalid Location for '+@c_loc
  		PRINT 'Invalid Location for '+@c_loc
              END
           END 
 	  IF @n_continue = 1 OR @n_continue = 2
           BEGIN
 	     SELECT @c_exists = 'N'
              SELECT @c_exists = 'Y'
 	     FROM PACK (NOLOCK)
 	     WHERE PACKKEY = @c_packkey
              IF @c_exists = 'N'
              BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_status   = '5'
                 SELECT @c_errrmk   = 'No Packkey in TABLE for '+@c_sku
  		PRINT 'No Packkey in TABLE for '+@c_sku
              END
           END 
 	  	
 	  IF @n_continue = 1 OR @n_continue = 2
           BEGIN
              SELECT @b_success = 0
    	     EXECUTE nspg_GetKey
      	             "ITRNKEY",
     		     10,
 	             @c_newitrnkey OUTPUT,
       		     @b_success    OUTPUT,
                      @n_err        OUTPUT,
                      @c_errmsg     OUTPUT
              IF NOT @b_success = 1
              BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_status = '5'
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                 SELECT @c_errrmk="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Inventory Balance" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
              END
              IF @n_continue = 1 OR @n_continue = 2
              BEGIN
                 INSERT INTO ITRN ( ItrnKey, 
                                             Storerkey,
                                             Sku,
 					    TranType,
                                             Lot,
 					    FromLoc,
 					    FromID,
                                             ToLoc,
                                             ToID,
 					    Lottable02,
 					    Lottable04,
 					    Lottable05,	
 					    SourceType,
 					    Qty,
                                             Status,
 					    Packkey,
 					    EditWho,
 		                            AddWho,
                                             AddDate)
               	 VALUES ( @c_newitrnkey, 
 			  @c_storerkey,
                           @c_sku, 'DP',
                           ' ', 
 			  ' ',
 			  ' ', 
 			  @c_loc,
                 	  @c_palletid,
 			  @c_lot,
 			  @d_expirydate,
 			  @d_receiptdate,	
 	                  'nspInvBalSetup',
         	          @n_qty,
                 	  'OK',
 			  @c_packkey,
                           'CONVERSION',
                           'CONVERSION',
  			  getdate())
                 SELECT @n_err = @@ERROR 
                 IF @n_err <> 0
                 BEGIN
                    SELECT @n_continue = 3
                    SELECT @c_status = '5'
                    SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                    SELECT @c_errrmk="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Inventory Balance" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
                 END
              END
           END
 	  IF @n_continue = 3 
           BEGIN
 	     INSERT INTO [GDSMASTER]..CONVERSION_Error (ProcessType, BatchNo, Key1, Key2, Key3, Key4, AddDate, Remark)
              VALUES('BALIMPORT', @c_batch, @c_storerkey, @c_sku , @c_loc, @n_identityid, getdate(), @c_errrmk ) 
 	     SELECT @n_err = @@ERROR
       	     IF @n_err <> 0
              BEGIN
                 SELECT @n_continue = 3
                 SELECT @c_status = '5'
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On ITF_ERROR. (nspPostPO)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
              END
           END
    	  Update_Status:
        	  UPDATE [GDSMASTER]..CVT019
           SET Status  = @c_status
           WHERE SWHS#S = @c_whcode
           AND   ITEMS = @c_sku
           AND   SRL#S   = @c_lot
 	  AND	ZONES = @c_zones
 	  AND	AISLS = @c_aisles
 	  AND	BINS = @c_bins
 	  AND	LEVLS = @c_levels
 	  AND   EXLOCZ = @c_loc
 	  AND	SEQNO = @n_IdentityId
           AND   Status  = '0'
           SELECT @n_err = @@ERROR
           IF @n_err <> 0
           BEGIN
              SELECT @n_continue = 3
              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed Status on CVT019" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTRIM(dbo.fnc_RTRIM(@c_errmsg)) + " ) "
           END
 	END
    END
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
       --RETURN
    END
    ELSE
    BEGIN
       SELECT @b_success = 1
       WHILE @@TRANCOUNT > @n_starttcnt
       BEGIN
          COMMIT TRAN
       END
       --RETURN
    END
    PRINT 'Upload Lot Balance ends at ' + convert(char(25), getdate(), 120)
    PRINT 'EXCEPTION REPORT'
    SELECT * from gdsmaster..conversion_error (nolock)
    where batchno = @c_batch
    SELECT '1', 'GDS Balance' Type, SUM(QOHS) Total FROM gdsmaster..cvt019 (nolock)
    UNION
    SELECT '2', 'Exceed Balance' Type, SUM(Qty) Total FROM ITRN (nolock)
    UNION
    SELECT '3', 'Difference' Type, SUM(QOHS) Total FROM gdsmaster..cvt019 (nolock)
    WHERE status = '5'
 END -- end of procedure

GO