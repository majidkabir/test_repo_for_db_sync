SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspRFPH04                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

/*****************************************************************/
 /* Start Create Procedure Here                                   */
 /*****************************************************************/
 CREATE PROC    [dbo].[nspRFPH04]
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
 ,              @c_id               NVARCHAR(18)
 ,              @c_loc              NVARCHAR(18)
 ,              @n_qty              int
 ,              @c_uom              NVARCHAR(10)
 ,              @c_packkey          NVARCHAR(10)
 ,              @c_LOTTABLE01       NVARCHAR(18)
 ,              @c_LOTTABLE02       NVARCHAR(18)
 ,              @c_LOTTABLE03       NVARCHAR(18)
 ,              @c_LOTTABLE04       datetime
 ,              @c_LOTTABLE05       datetime
 ,              @c_team             NVARCHAR(1)
 ,              @c_inventorytag     NVARCHAR(18)
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
      DECLARE @b_hold NVARCHAR(10)
      SELECT @b_debug = 1 
      SELECT @b_hold = "0"
      IF @b_debug = 1
      BEGIN
           SELECT @c_storerkey, @c_lot, @c_sku, @c_id, @c_loc, @n_qty, @c_uom, @c_packkey, @c_LOTTABLE01, @c_LOTTABLE02, @c_LOTTABLE03, @c_LOTTABLE04, @c_LOTTABLE05, @c_team, @c_inventorytag
      END
      DECLARE        @n_continue int        ,  /* continuation flag 
                                 1=Continue
                                 2=failed but continue processsing 
                                 3=failed do not continue processing 
                                 4=successful but skip furthur processing */                                               
               @n_starttcnt int        , -- Holds the current transaction count                                                                                           
               @c_preprocess NVARCHAR(250) , -- preprocess
               @c_pstprocess NVARCHAR(250) , -- post process
               @n_err2 int             , -- For Additional Error Detection
               @n_cnt int               -- Holds row count of most recent SQL statement
      /* Declare RF Specific Variables */
      DECLARE @c_retrec NVARCHAR(2) /* Return Record "01" = Correct, "02" = Difference, "09" = Failure */
 --**ZY
      DECLARE @c_lottable01label NVARCHAR(5), @c_lottable02label NVARCHAR(5),@c_lottable03label NVARCHAR(5),
              @c_lottable04label NVARCHAR(5),@c_lottable05label NVARCHAR(5)
      /* Set default values for variables */
      SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
      SELECT @c_retrec = "01" /* Correct */
      /* Execute Preprocess */
      /* #INCLUDE <SPRFPH04_1.SQL> */     
      /* End Execute Preprocess */
      SELECT @c_packkey = dbo.fnc_LTrim(dbo.fnc_RTrim(@c_packkey))
      /* Start Main Processing */
      /* Set parameter "@c_team" default */
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_team)) IS NULL
      BEGIN
         SELECT @c_team = "A"
      END
      /* End Set parameter "@c_team" default */
      /* Calculate next Task ID */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
           SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
      END     
      /* End Calculate Next Task ID */
 /* Tomd Begin */
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lot)) IS NOT NULL
      BEGIN
      SELECT Lot FROM LOTATTRIBUTE
      WHERE Lot = @c_lot
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
        /* IF @n_err <> 0 */
      IF @n_cnt = 0
         BEGIN
           SELECT @n_continue = 3 
                 /* Trap SQL Server Error */
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70405   
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Invalid Lot. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                 /* End Trap SQL Server Error */
                execute nsp_logerror @n_err, @c_errmsg, "nspRFPH04"
                RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
                RETURN
          END
      /* If the user enters just the lot number and leaves the sku or storerkey blank
         then go out to the lotattribute table and retrieve the appropiate information. */
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL
      OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Sku)) IS NULL
      SELECT @c_StorerKey = StorerKey,
             @c_Sku = Sku 
      FROM LOTATTRIBUTE
      WHERE Lot = @c_Lot
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
           SELECT @n_continue = 3 
                 /* Trap SQL Server Error */
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70406   
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Select Failed On LOTATTRIBUTE. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                 /* End Trap SQL Server Error */
          END
      END
 /* Tomd End */
      /* Calculate Sku Supercession */
      IF (@n_continue=1 OR @n_continue=2) AND ISNULL(@c_sku,'') <> ''
      BEGIN
         SELECT @b_success = 0
           EXECUTE nspg_GETSKU1
                 @c_StorerKey  = @c_StorerKey,
                 @c_sku        = @c_sku     OUTPUT,
                 @b_success    = @b_success OUTPUT,
                 @n_err        = @n_err     OUTPUT,
                 @c_errmsg     = @c_errmsg  OUTPUT,
 		@c_packkey    = @c_packkey OUTPUT,
 	        @c_uom        = @c_uom     OUTPUT
           IF NOT @b_success = 1
           BEGIN
                 SELECT @n_continue = 3
           END
           ELSE IF @b_debug = 1
              BEGIN
                 SELECT @c_sku "@c_sku"
           END
      END 
 --**ZY Retrieve sku,storerkey,id,loc,lot base on input from LOTxLOCxID
      IF @n_continue = 1 OR @n_continue = 2
      BEGIN
 	IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL 
 		OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_loc)) IS NOT NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_id)) IS NOT NULL
 		OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_lot)) IS NOT NULL
 	BEGIN
 	  SELECT @n_cnt = COUNT(*)
 	    FROM LOTxLOCxID (NOLOCK)
 	   WHERE (StorerKey = @c_storerkey OR ISNULL(@c_storerkey,'') = '')
  	     AND (Sku = @c_sku OR ISNULL(@c_sku,'') = '')
  	     AND (Loc = @c_loc OR ISNULL(@c_loc,'') = '')
   	     AND (ID = @c_id OR ISNULL(@c_id,'') = '')
  	     AND (Lot = @c_lot OR ISNULL(@c_lot,'') = '')
 	     AND Qty > 0
 	  IF @n_cnt = 0
 	  BEGIN
 		SELECT @n_continue = 3 
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70407   
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": No record can be found. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
           END
 	  ELSE
           BEGIN
 	    IF @n_cnt > 1
 	    BEGIN
 		SELECT @n_continue = 3 
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70407   
                	SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Number of record is not unique. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 	    END
 	    ELSE
             BEGIN
 		SELECT @c_storerkey=Storerkey, @c_sku=Sku, @c_loc=Loc, @c_id=ID, @c_lot=Lot  
 	          FROM LOTxLOCxID (NOLOCK)
 	         WHERE (StorerKey = @c_storerkey OR ISNULL(@c_storerkey,'') = '')
  	           AND (Sku = @c_sku OR ISNULL(@c_sku,'') = '')
  	           AND (Loc = @c_loc OR ISNULL(@c_loc,'') = '')
         AND (ID = @c_id OR ISNULL(@c_id,'') = '')
  	           AND (Lot = @c_lot OR ISNULL(@c_lot,'') = '')
 	           AND Qty > 0
 	    END
           END
 	END
      END
 --**ZY END
 	
 --**ZY Retrieve lottable01^05 label from SKU base on storerkey and sku
      IF @n_continue=1 OR @n_continue=2
      BEGIN
        IF EXISTS ( SELECT * FROM SKU (NOLOCK) WHERE storerkey = @c_storerkey AND sku = @c_sku)
 		SELECT @c_lottable01label  = SUBSTRING(lottable01label,1,5),
 			@c_lottable02label = SUBSTRING(lottable02label,1,5),
 			@c_lottable03label = SUBSTRING(lottable03label,1,5),
 			@c_lottable04label = SUBSTRING(lottable04label,1,5),
 			@c_lottable05label = SUBSTRING(lottable05label,1,5)
 		  FROM SKU (NOLOCK) 
                  WHERE Storerkey = @c_storerkey AND Sku = @c_sku 
        ELSE
        BEGIN
 	 SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70407   
          SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Invalid Storer or Sku (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
        END
 			
      END
 --**ZY END
 --**ZY Retrieve lottable01^05 content from LotAttribute base on @c_lot
      IF @n_continue=1 OR @n_continue=2
      BEGIN
        IF EXISTS ( SELECT * from LotAttribute (NOLOCK) WHERE lot = @c_lot)
           SELECT @c_lottable01 = SUBSTRING(lottable01,1,18),
 	         @c_lottable02 = SUBSTRING(lottable02,1,18),
 	         @c_lottable03 = SUBSTRING(lottable03,1,18),
 	         @c_lottable04 = lottable04,
 	         @c_lottable05 = lottable05
             FROM LotAttribute (NOLOCK) WHERE Lot = @c_lot
        ELSE
        BEGIN
 	 SELECT @n_continue = 3 
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70407   
          SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": lot number not exists! (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
        END
      END
 --**ZY END
 	
 	
 /* Tomd */
      /* Call stored procedure to validate the packkey if the user has sent in a packkey.
      If the user has not sent in a packkey then it will find the appropiate packkey 
      and return it to the us.  */
 IF @n_continue=1 OR @n_continue=2
 BEGIN  
    SELECT @b_success = 0
        EXECUTE nspGetPack 
                     @c_storerkey        = @c_storerkey,     
                     @c_sku              = @c_sku, 
                     @c_lot              = @c_lot,
                     @c_loc              = @c_loc,     
                     @c_id               = @c_id,  
                     @c_packkey          = @c_packkey      OUTPUT, 
                     @b_success          = @b_success      OUTPUT, 
                     @n_err              = @n_err          OUTPUT, 
                     @c_errmsg           = @c_errmsg       OUTPUT
           IF NOT @b_success = 1
           BEGIN
                 SELECT @n_continue = 3
           END
           ELSE IF @b_debug = 1
              BEGIN
                 SELECT @c_id "@c_id"
                 SELECT @c_lot "@c_lot"
                 SELECT @c_loc "@c_loc"
           END
  /* Tomd, End validate/retreive packkey. */
      /* Tomd, Begin- If the uom is not provided then calculate the uom from PackUOM3 */
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_uom)) IS NULL
      SELECT @c_uom = PackUOM3 FROM PACK
      WHERE packkey = @c_packkey
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
          SELECT @n_continue = 3 
                 /* Trap SQL Server Error */
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70407   
                 SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Select Failed On PACK. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                 /* End Trap SQL Server Error */
          END
 END
      /* Tomd, End- If the uom is not provided then calculate the uom from PackUOM3 */
      /* Calculate qty based on unit of measure */
 /*     IF @n_continue=1 or @n_continue=2
      BEGIN
           DECLARE @n_UOMQty int
           SELECT @n_UOMQty = 0
           SELECT @n_UOMQty = @n_Qty
           SELECT @b_success = 1
           EXECUTE nspUOMConv
                @n_fromqty = @n_qty,
                @c_fromuom = @c_uom,
                @c_touom   = NULL,
                @c_packkey = @c_packkey,
                @n_toqty   = @n_qty      OUTPUT,
                @b_success = @b_success  OUTPUT,
                @n_err     = @n_err      OUTPUT,
                @c_errmsg  = @c_errmsg   OUTPUT
           IF NOT @b_success = 1
           BEGIN
                SELECT @n_continue = 3
           END
      END
      IF @b_debug = 1
      BEGIN
           SELECT @n_qty
      END */ --ZY
      /* End Calculate qty based on unit of measure */
 --ZY
 /*     IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_InventoryTag)) IS NULL
      AND @n_continue <> 3
      BEGIN
         UPDATE PHYSICAL
                SET   Qty = @n_Qty,
             UOM = @c_uom,
             PackKey = @c_packkey 
                WHERE StorerKey = @c_StorerKey
                AND Sku = @c_Sku
                AND Loc = @c_Loc
                AND Id = @c_Id
             AND (Lot = @c_Lot
           OR Lot = " ")
                AND Team = @c_team
           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
           IF @n_err <> 0
           BEGIN
                SELECT @n_continue = 3 
                -- Trap SQL Server Error 
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70401   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update1 Failed On PHYSICAL. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                -- End Trap SQL Server Error 
           END
           ELSE IF @n_cnt = 0 AND @n_continue <> 3
           BEGIN
                 INSERT PHYSICAL (
                                 Team,
                                 InventoryTag,
                                 StorerKey,
                                 Sku,
                                 Loc, 
                     Lot,
                                 Id,
                                 Qty,
                                 PackKey,
                                 UOM
                 )
                 VALUES (
                                 @c_Team,
                                 @c_InventoryTag,
                                 @c_StorerKey,
                                 @c_Sku,
                                 @c_Loc,
                     @c_Lot,
                                 @c_Id,
                                 @n_Qty,
                                 @c_PackKey,
                                 @c_UOM
                     )
                   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                   IF @n_err <> 0
                   BEGIN
                        SELECT @n_continue = 3 
                        -- Trap SQL Server Error 
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70402   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Insert Failed On PHYSICAL. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 --                        End Trap SQL Server Error 
                   END
           END
      END
      ELSE
      BEGIN
           IF @n_continue <> 3
           UPDATE PHYSICAL
           SET    Qty = @n_Qty,
        UOM = @c_uom,
        PackKey = @c_packkey, 
        ID = @c_id,
        sku = @c_sku,
        storerkey = @c_storerkey,
        loc = @c_loc, 
        lot = @c_lot
           WHERE  InventoryTag = @c_InventoryTag
           AND Team = @c_team          
           SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
           IF @n_err <> 0
           BEGIN
                SELECT @n_continue = 3 
                 Trap SQL Server Error 
                SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70403   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Update Failed On PHYSICAL. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                 End Trap SQL Server Error 
           END
           ELSE IF @n_cnt = 0 AND @n_continue <> 3
           BEGIN
                 INSERT PHYSICAL (
                                 Team,
                                 InventoryTag,
                                 StorerKey,
                                 Sku,
                                 Loc, 
                     Lot,
                                 Id,
                                 Qty,
                                 PackKey,
                                 UOM
                 )
                 VALUES (
                                 @c_Team,
                                 @c_InventoryTag,
                                 @c_StorerKey,
                                 @c_Sku,
                                 @c_Loc,
                     @c_Lot,
                                 @c_Id,
                                 @n_Qty,
                                 @c_PackKey,
                                 @c_UOM
                     )
                   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                   IF @n_err <> 0
                   BEGIN
                        SELECT @n_continue = 3 
                         Trap SQL Server Error 
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=70404   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
                        SELECT @c_errmsg="NSQL"+CONVERT(char(5), @n_err)+": Insert Failed On PHYSICAL. (nspRFPH04)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
                         End Trap SQL Server Error 
                   END
           END
      END  */ --ZY
 	
         /* End Update table "PHYSICAL" */
      /* Set RF Return Record */
      IF @n_continue=3 
      BEGIN
           IF @c_retrec="01"
           BEGIN
                SELECT @c_retrec="09"
           END 
      END 
      /* End Set RF Return Record */
      /* Construct RF Return String */
      SELECT @c_outstring =
             @c_ptcid               + @c_senddelimiter
           + dbo.fnc_RTrim(@c_userid)       + @c_senddelimiter
           + dbo.fnc_RTrim(@c_taskid)       + @c_senddelimiter
           + dbo.fnc_RTrim(@c_databasename) + @c_senddelimiter
           + dbo.fnc_RTrim(@c_appflag)      + @c_senddelimiter
           + dbo.fnc_RTrim(@c_retrec)       + @c_senddelimiter
           + dbo.fnc_RTrim(@c_server)       + @c_senddelimiter
  		 + dbo.fnc_RTrim(@c_packkey)   + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_uom)       + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable01label) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable02label) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable03label) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable04label) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable05label) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable01) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable02) + @c_senddelimiter
 		 + dbo.fnc_RTrim(@c_lottable03) + @c_senddelimiter
 		 + dbo.fnc_RTrim(convert(char(12), @c_lottable04, 103) ) + @c_senddelimiter
  		 + dbo.fnc_RTrim(Convert(char(12), @c_lottable05, 103) ) + @c_senddelimiter
           + dbo.fnc_RTrim(@c_errmsg)  
      SELECT dbo.fnc_RTrim(@c_outstring)
      /* End Construct RF Return String */
      /* End Main Processing */
      /* Post Process Starts */
      /* #INCLUDE <SPRFPH04_2.SQL> */
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
        execute nsp_logerror @n_err, @c_errmsg, "nspRFPH04"
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