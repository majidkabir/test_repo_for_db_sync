SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*****************************************************************/
/* Start Create Procedure Here                                   */
/*****************************************************************/
 CREATE PROC    [dbo].[nspRFRC04]
                @c_sendDelimiter    NVARCHAR(1)    
 ,              @c_ptcid            NVARCHAR(5) 
 ,              @c_userid           NVARCHAR(10)    
 ,              @c_taskId           NVARCHAR(10)   
 ,              @c_databasename     NVARCHAR(30)    
 ,              @c_appflag          NVARCHAR(2)    
 ,              @c_recordType       NVARCHAR(2)    
 ,              @c_server           NVARCHAR(30)
 ,              @c_receiptkey       NVARCHAR(10)
 ,              @c_storerkey        NVARCHAR(15)
 ,              @c_prokey           NVARCHAR(10)
 ,              @c_ref          NVARCHAR(20)
 ,              @c_sku              NVARCHAR(30)
 ,              @c_pokey            NVARCHAR(20)       -- 06/24/2001 CS Added
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
   IF @c_taskId = 'DS1'
   BEGIN
        SELECT @b_debug = 1
   END

 DECLARE
                @c_lottable01       NVARCHAR(18)
 ,              @c_lottable02       NVARCHAR(18)
 ,              @c_lottable03       NVARCHAR(18)
 ,              @d_lottable04       NVARCHAR(30)
 ,              @d_lottable05       NVARCHAR(30)
 ,              @c_lot              NVARCHAR(10)
 ,              @n_qty              int
 ,              @c_uom              NVARCHAR(10)
 ,              @c_packkey          NVARCHAR(10)
 ,              @c_sku_1            NVARCHAR(30)
 ,              @c_desc             NVARCHAR(20)
 ,              @c_loc              NVARCHAR(10)
 ,              @c_id               NVARCHAR(18)
 ,              @c_holdflag         NVARCHAR(10)
 ,              @c_other1           NVARCHAR(20)
 ,              @c_other2           NVARCHAR(20)
 ,              @c_other3           NVARCHAR(20)
 ,              @c_rowcnt     int
 ,              @c_lottable01label  NVARCHAR(5)
 ,              @c_lottable02label  NVARCHAR(5)
 ,              @c_lottable03label  NVARCHAR(5)
 ,              @c_lottable04label  NVARCHAR(5)
 ,              @c_lottable05label  NVARCHAR(5)
 ,              @c_found_storerkey  NVARCHAR(15)

   IF @b_debug = 1
   BEGIN
      SELECT @c_receiptkey "@c_receiptkey",  @c_storerkey "@c_storerkey", 
              @c_prokey "@c_prokey",         @c_sku "@c_sku", 
              @c_lottable01 "@c_lottable01", @c_lottable02 "@c_lottable02", 
              @c_lottable03 "@c_lottable03", @d_lottable04 "@d_lottable04", 
              @d_lottable05 "@d_lottable05", @c_lot "@c_lot", 
              @c_pokey "@c_pokey",           @n_qty "@n_qty", 
              @c_uom "@c_uom",               @c_packkey "@c_packkey", 
              @c_loc "@c_loc",               @c_id "@c_id", 
              @c_holdflag "@c_holdflag"
   END
      DECLARE  @n_continue int        ,  /* continuation flag 
                                              1=Continue
                                              2=failed but continue processsing 
                                              3=failed do not continue processing 
                                              4=successful but skip furthur processing */                                               
               @n_starttcnt int        , -- Holds the current transaction count                                                                                           
               @c_preprocess NVARCHAR(250) , -- preprocess
               @c_pstprocess NVARCHAR(250) , -- post process
               @n_err2 int               -- For Additional Error Detection

      /* Declare RF Specific Variables */
      DECLARE @c_retrec NVARCHAR(2) -- Return Record "01" = Success, "09" = Failure
      DECLARE @c_dbnamestring NVARCHAR(255)
      DECLARE @n_cqty int, @n_returnrecs int

      /* Set default values for variables */
      SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
      SELECT @c_retrec = "04"     
      SELECT @n_returnrecs=1

      /* RC01 Specific Variables */
      DECLARE @c_itrnkey NVARCHAR(10), @n_toqty int, @c_NoDuplicateIdsAllowed NVARCHAR(10), 
              @c_tariffkey NVARCHAR(10), @c_ReceiptLineNumber NVARCHAR(5),
              @c_prevlinenumber NVARCHAR(5), @c_multiline NVARCHAR(1)
      SELECT  @c_prevlinenumber = master.dbo.fnc_GetCharASCII(14), @c_multiline = '0'

      /* Execute Preprocess */
      /* #INCLUDE <SPRFRC01_1.SQL> */     
      /* End Execute Preprocess */
      /* Validate Storer */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
        IF NOT EXISTS (SELECT * FROM STORER (NOLOCK) WHERE StorerKey = @c_storerkey)
        BEGIN
             SELECT @n_continue=3
             SELECT @n_err=65105
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid Storer (nspRFRC04)"
        END
      END
      /* Calculate Sku Supercession */
      IF @n_continue=1 OR @n_continue=2
      BEGIN
           IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_sku)) IS NOT NULL AND dbo.fnc_LTrim(dbo.fnc_RTrim(@c_storerkey)) IS NOT NULL
           BEGIN     
                SELECT @b_success = 0
                EXECUTE nspg_GETSKU1
                      @c_StorerKey  = @c_StorerKey,
                      @c_sku        = @c_sku     OUTPUT,
                      @b_success    = @b_success OUTPUT,
                      @n_err        = @n_err     OUTPUT,
                      @c_errmsg     = @c_errmsg  OUTPUT,
                      @c_uom        = @c_uom     OUTPUT,
                      @c_packkey    = @c_packkey OUTPUT

                IF NOT @b_success = 1
                BEGIN
                     SELECT @n_continue = 3
                END

                IF @b_debug = 1
                BEGIN
                     SELECT @c_sku "@c_sku after nspGetSku"
                END
           END               
      END
     /*Get SKU Descr*/
     IF @n_continue=1 OR @n_continue=2
      BEGIN
         --select @c_desc=SUBSTRING(ISNULL(descr,''),1,20) 
         -- 06/26/2001 CS Remove "'" from it 'coz it will make us in trouble
         --select @c_desc=descr
         SELECT @c_desc=replace(descr, "'", "")
         FROM SKU (NOLOCK) 
         WHERE Storerkey = @c_storerkey 
         AND   SKU = @c_SKU
      END

      /* Calculate next Task ID */
      IF @n_continue=1 OR @n_continue=2
      BEGIN
           SELECT @c_taskid = CONVERT(char(18), CONVERT(int,( RAND() * 2147483647)) )
      END     
      /* End Calculate Next Task ID */
      /* Validate Storer&Sku or Lot */
      IF @n_continue=1 OR @n_continue=2
      BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Lot)) IS NULL 
        BEGIN
             IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_StorerKey)) IS NULL OR dbo.fnc_LTrim(dbo.fnc_RTrim(@c_Sku)) IS NULL
             BEGIN
                  SELECT @n_continue=3
                  SELECT @n_err=65102
                  SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Storer or Sku (nspRFRC04)"
             END
        END
        ELSE
        BEGIN
          Declare @c_StorerFromLot NVARCHAR(15), @c_SkuFromLot NVARCHAR(20)
          SELECT @c_StorerFromLot = StorerKey, @c_SkuFromLot = Sku
           FROM LotAttribute (nolock) 
           WHERE Lot = @c_Lot
          IF @@ROWCOUNT = 0 OR @c_StorerFromLot <> @c_StorerKey OR @c_SkuFromLot <> @c_Sku
          BEGIN
               SELECT @n_continue=3
               SELECT @n_err=65103
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad Lot (nspRFRC04)"
          END
        END
      END
      /* End Validate Storer&Sku or Lot */
      /* Validate Packkey*/
      IF @n_continue=1 OR @n_continue=2
      BEGIN
           SELECT @b_success = 0
           EXECUTE nspGetPack
                   @c_storerkey   = @c_storerkey,
                   @c_sku         = @c_sku,
                   @c_lot         = @c_lot,
                   @c_loc         = @c_loc,
                   @c_id          = @c_id,
                   @c_packkey     = @c_packkey      OUTPUT,
                   @b_success     = @b_success      OUTPUT,
                   @n_err         = @n_err          OUTPUT,
                   @c_errmsg      = @c_errmsg       OUTPUT
            IF NOT @b_success = 1
            BEGIN
                 SELECT @n_continue = 3
            END
      END
      /* End Validate Packkey */
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
        IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_uom)) IS NULL
        BEGIN
           SELECT @c_uom = PackUOM3 FROM PACK (NOLOCK) WHERE PackKey = @c_packkey
           IF @@ROWCOUNT = 0
           BEGIN
                SELECT @n_continue=3
                SELECT @n_err=65114
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid PackKey (nspRFRC04)"
           END
        END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
        IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_prokey)) IS NULL) AND (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ref)) IS NULL)
        BEGIN
           BEGIN
                SELECT @n_continue=3
                SELECT @n_err=65114
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ASN or REF Required (nspRFRC04)"
           END
        END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
        IF (@c_prokey = 'RGR') AND (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_ref)) IS NULL)
        BEGIN
           BEGIN
                SELECT @n_continue=3
                SELECT @n_err=65114
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": REF Required (nspRFRC04)"
           END
        END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
        IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_prokey)) IS NOT NULL) AND ISNULL(@c_prokey,'') <> 'RGR'
        BEGIN
          -- 1 Feb 2005 YTWAN - Enquiry Sku without Verify ASN# For C4MY - START
          IF NOT EXISTS (SELECT * FROM RECEIPT (NOLOCK) WHERE ReceiptKey = @c_prokey)
				 AND NOT EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_storerkey AND
                	          ConfigKey = 'C4RFXDOCK' AND sValue = '1')
          BEGIN
             SELECT @n_continue=3
             SELECT @n_err=65114
             SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Invalid ASN# (nspRFRC04)"
          END
          -- 1 Feb 2005 YTWAN - Enquiry Sku without Verify ASN# For C4MY - END
        END
      END
      IF @n_continue = 1 or @n_continue = 2
      BEGIN
         IF (dbo.fnc_LTrim(dbo.fnc_RTrim(@c_prokey)) IS NULL) OR (@c_prokey = 'RGR')
         BEGIN
             SELECT @c_found_storerkey = StorerKey, 
                    @c_prokey = ReceiptKey
             FROM RECEIPT (NOLOCK) 
             WHERE ExternReceiptKey = @c_ref
         
             SELECT @c_rowcnt = @@ROWCOUNT
         
             IF @c_rowcnt = 0
             BEGIN
                SELECT @n_continue=3
                SELECT @n_err=65114
                SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": ASN not Found (nspRFRC04)"
             END
             ELSE
             BEGIN
                IF @c_rowcnt > 1
                BEGIN
                   SELECT @n_continue=3
                   SELECT @n_err=65114
                   SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Dupliate ASN Found (nspRFRC04)"
                END
                ELSE
                  IF @c_found_storerkey <> @c_storerkey
                  BEGIN
                     SELECT @n_continue=3
                     SELECT @n_err=65114
                     SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": StorerKey Mismatched (nspRFRC04)"
                  END
               END
            END
         END         
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE StorerKey = @c_storerkey AND Sku = @c_sku)
            BEGIN
               SELECT @c_Lottable01Label = SUBSTRING(ISNULL(Lottable01Label,''),1,5),
                      @c_Lottable02Label = SUBSTRING(ISNULL(Lottable02Label,''),1,5),
                      @c_Lottable03Label = SUBSTRING(ISNULL(Lottable03Label,''),1,5),
                      @c_Lottable04Label = SUBSTRING(ISNULL(Lottable04Label,''),1,5),
                      @c_Lottable05Label = SUBSTRING(ISNULL(Lottable05Label,''),1,5)
               FROM SKU (NOLOCK)
               WHERE  Storerkey = @c_storerkey AND Sku = @c_sku
            END
            ELSE
            BEGIN
               SELECT @n_continue=3
               SELECT @n_err=65114
               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Bad SKU Code (nspRFRC04)"
            END
         END

         /* Added By SHONG - Don't display this cause not user input require */
         IF dbo.fnc_RTrim(@c_Lottable04Label) = 'GENEX'
         BEGIN
            SELECT @c_Lottable04Label = ''
         END


			/* 29-Nov-2004 YTWan RF Xdock Receiving - START */
			IF (@n_continue=1 OR @n_continue=2 ) AND
            EXISTS(SELECT 1 FROM StorerConfig (NOLOCK) WHERE StorerKey = @c_storerkey AND
                	 ConfigKey = 'C4RFXDOCK' AND sValue = '1')
    		BEGIN
				IF @n_continue=1 OR @n_continue=2 
				BEGIN 
               -- 01 Feb 2004 YTWan - For Sku Enquiry - START
               -- Ignore ASN# IF = 'NOASN'
					IF @c_prokey <> 'NOASN' AND NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL (NOLOCK) WHERE Receiptkey = @c_prokey
										             AND Storerkey = @c_storerkey AND Sku = @c_sku)
					BEGIN 
						SELECT @n_continue=3
	               SELECT @n_err=65115
	               SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": XDOCk Sku Not Found (nspRFRC04)"
					END 
					-- 01 Feb 2004 YTWan - For Sku Enquiry - END
				END 

				IF @n_continue=1 OR @n_continue=2 
				BEGIN 
					SELECT @c_Lottable01Label = ''
					SELECT @c_Lottable02Label = ''
					SELECT @c_Lottable03Label = ''
					--SELECT @c_Lottable04Label = ''
				END
			END 	
			/* 29-Nov-2004 YTWan RF Xdock Receiving - END */

         /* Set RF Return Record */
         IF @n_continue=3 
         BEGIN
            SELECT @c_retrec="09"
         END 
         /* End Set RF Return Record */
         /* Construct RF Return String */
         SELECT @c_outstring =   @c_ptcid        + @c_senddelimiter
               + dbo.fnc_RTrim(@c_userid)           + @c_senddelimiter
               + dbo.fnc_RTrim(@c_taskid)           + @c_senddelimiter
               + dbo.fnc_RTrim(@c_databasename)     + @c_senddelimiter
               + dbo.fnc_RTrim(@c_appflag)          + @c_senddelimiter
               + dbo.fnc_RTrim(@c_retrec)           + @c_senddelimiter
               + dbo.fnc_RTrim(@c_server)           + @c_senddelimiter
               + dbo.fnc_RTrim(@c_prokey)           + @c_senddelimiter
               + dbo.fnc_RTrim(@c_ReceiptLineNumber)+ @c_senddelimiter
               + dbo.fnc_RTrim(@c_errmsg)           + @c_senddelimiter 
               + dbo.fnc_RTrim(@c_packkey)          + @c_senddelimiter
               + dbo.fnc_RTrim(@c_uom)              + @c_senddelimiter    
               + dbo.fnc_RTrim(@c_sku)              + @c_senddelimiter
               + dbo.fnc_RTrim(@c_desc)             + @c_senddelimiter    
               + dbo.fnc_RTrim(@c_Lottable01label)  + @c_senddelimiter
               + dbo.fnc_RTrim(@c_Lottable02label)  + @c_senddelimiter
               + dbo.fnc_RTrim(@c_Lottable03label)  + @c_senddelimiter
               + dbo.fnc_RTrim(@c_Lottable04label)
               /* 06/24/2001 CS Added pokey to the return string for it is needed - START */
               + @c_senddelimiter
               + dbo.fnc_RTrim(@c_pokey)
               /* 06/24/2001 CS Added pokey to the return string for it is needed - END */
               SELECT dbo.fnc_RTrim(@c_outstring)
               /* End Main Processing */
               /*     
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
      execute nsp_logerror @n_err, @c_errmsg, "nspRFRC04"
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
   */
END

GO