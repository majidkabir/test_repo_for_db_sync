SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure: nsp_smr_by_trxdate_pmtl                        		*/
/* Creation Date:                                     						*/
/* Copyright: IDS                                                       */
/* Written by:                                           					*/
/*                                                                      */
/* Purpose:  Create YORSOR Report by TrxDate (IDSTH-PMTL)					*/
/*                                                                      */
/* Input Parameters:  @StorerKey,      - Storerkey								*/
/*                    @SkuMin,         - Minimum Sku                    */
/*                    @SkuMax,         - Maximum Sku                    */
/*                    @DateStringMin,  - Minimum date range - Effective */
/*                                       date in ITRN table             */
/*                    @DateStringMax,  - Maximum date range - Effective */
/*                                       date in ITRN table             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                        			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.16                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                  	*/
/*	14-Feb-2005	 June		   Remark delete ADJ records doctype = '99'  	*/
/*                         (SOS30311)                                	*/
/* 18-Feb-2005  MaryVong	1)Change Orders.ExternOrderKey to         	*/
/*                           Orders.InvoiceNo                        	*/
/*                         2)If DocType like 'T%' and Itrn.TranType  	*/   
/*									  = 'AJ', set DocType = 'TFB'				   	*/
/*									(SOS32458)												*/
/*	26-Oct-2005	 MaryVong	SOS42111 Change DocType to new value			*/
/* 26-Nov-2013  TLTING     Change user_name() to SUSER_SNAME()          */
/*																								*/
/************************************************************************/

CREATE PROC [dbo].[nsp_smr_by_trxdate_pmtl](
  @StorerKey      NVARCHAR(15),
  @SkuMin    	 NVARCHAR(10),
  @SkuMax    	 NVARCHAR(10),
  @DateStringMin  NVARCHAR(10),
  @DateStringMax  NVARCHAR(10)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
  DECLARE @DateMin datetime
  DECLARE @DateMax datetime
  DECLARE @b_debug int
  DECLARE @n_continue int        ,  /* continuation flag
                                1=Continue
                                2=failed but continue processsing
                                3=failed do not continue processing
                                4=successful but skip furthur processing */
	@n_starttcnt int        , -- Holds the current transaction count
	@c_preprocess NVARCHAR(250) , -- preprocess
	@c_pstprocess NVARCHAR(250) , -- post process
	@n_err2 int,              -- For Additional Error Detection
	@n_err int,
	@c_errmsg NVARCHAR(250)

  DECLARE @BFdate DATETIME
  DECLARE @d_end_date DATETIME
  DECLARE @d_begin_date datetime
  DECLARE @n_num_recs int
  DECLARE @n_num_recs_bb  int

  SET NOCOUNT ON
  SELECT @b_debug = 0

	/* String to date convertion */
  SELECT @datemin = CAST (
						  substring(@datestringmin, 4, 2) + "/"+           --month
						  substring(@datestringmin, 1, 2) +"/"+            --day
                    substring(@datestringmin, 7, 4) AS DATETIME) --year

  SELECT @datemax = CAST ( substring(@datestringmax, 4, 2) + "/"+        --month
						  substring(@datestringmax, 1, 2) +"/"+    --day
                    substring(@datestringmax, 7, 4) AS DATETIME) --year

	/* Set default values for variables */
	SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0
	SELECT @d_begin_date = Convert( datetime, @DateMin )
	SELECT @BFdate = DATEADD(day, -1, @datemin)
	SELECT @d_end_date = DATEADD(day, 1, @datemax)

  IF @b_debug = 1
  BEGIN
    SELECT 'REPORT PARM..', 	
			  @StorerKey,
			  @SkuMin, 
			  @SkuMax,
           @DateMin,
           @DateMax,
			  @d_begin_date,
			  @d_end_date
  END

  -- OB + Current Stock Movement from ITRN 
  IF @n_continue=1 or @n_continue=2
  BEGIN
	SELECT @n_num_recs = -100 /* initialize */

   SELECT a.StorerKey
      , a.sku
      , a.qty
      , a.TranType
		, convert(datetime, CONVERT(CHAR, CONVERT(DATETIME, a.Adddate , 101), 101), 101) As EffectiveDate
      , a.ItrnKey
      , sourcekey = CASE SUBSTRING(Sourcetype, 1, 16) 
							WHEN 'ntrReceiptDetail' THEN SUBSTRING(a.Sourcekey, 1, 10) 
							WHEN 'ntrPickDetailUpd' 
								THEN (SELECT ORDERKEY FROM PICKDETAIL (NOLOCK) WHERE Pickdetailkey = a.sourcekey)
							ELSE Sourcekey 
						  END 
      , a.SourceType
      , 0 as distinct_sku
   INTO #ITRN_CUT_BY_SKU_ITT
   FROM itrn a(nolock), sku b(nolock)
   WHERE a.Storerkey = b.Storerkey
	  AND a.sku = b.sku	   
     AND a.StorerKey = @StorerKey
     AND b.sku between @SkuMin AND @SkuMax
     AND a.Adddate < @d_end_date
     AND a.TranType IN ("DP", "WD", "AJ")


   /* This section is pertaining to transfer process, if the from sku and the to sku happen to be the same,
      exclude it out of the report. If the from sku and the to sku is different, include it in the report.
   */
   DECLARE @ikey NVARCHAR(10), @skey NVARCHAR(20), @dd_d int
   DECLARE itt_cursor CURSOR FAST_FORWARD READ_ONLY FOR
     select ItrnKey, Sourcekey from #ITRN_CUT_BY_SKU_ITT where sourcetype = 'ntrTransferDetailUpdate'

   OPEN itt_cursor
   FETCH NEXT FROM itt_cursor INTO @ikey, @skey

   WHILE @@FETCH_STATUS = 0
   BEGIN
			SELECT @dd_d = count(DISTINCT sku)
			FROM itrn (NOLOCK)
			WHERE sourcetype = 'ntrTransferDetailUpdate'
			AND substring(sourcekey, 1, 10) = substring(@skey, 1, 10)

        UPDATE #ITRN_CUT_BY_SKU_ITT
        set   distinct_sku = @dd_d
        WHERE ITRNKEY = @ikey

        FETCH NEXT FROM itt_cursor INTO @ikey, @skey
   END
   CLOSE itt_cursor
   DEALLOCATE itt_cursor

   /* this is to remove the moving transaction within the same sku */
   DELETE FROM #ITRN_CUT_BY_SKU_ITT where distinct_sku = 1

   -- #15891 (Exclude Cycle Count trx)
   DELETE FROM #ITRN_CUT_BY_SKU_ITT where Sourcetype like 'CC%'

   SELECT storerkey,
          sku,
          qty,
          trantype,
          effectiveDate,
	       ItrnKey,
      	 Sourcekey,
      	 SourceType
   INTO #ITRN_CUT_BY_SKU
   FROM #ITRN_CUT_BY_SKU_ITT

   SELECT @n_err = @@ERROR
   SELECT @n_num_recs = (SELECT count(*) FROM #ITRN_CUT_BY_SKU)
   IF NOT @n_err = 0
   BEGIN
        SELECT @n_continue = 3
        /* Trap SQL Server Error */
        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On #ITRN_CUT_BY_SKU (BSM) (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
        /* End Trap SQL Server Error */
   END

	IF @b_debug = 1
	BEGIN
		SELECT '--- #ITRN_CUT_BY_SKU --- '
		SELECT 'ITRN OB', sku, sum(qty) FROM #ITRN_CUT_BY_SKU where EffectiveDate < @d_begin_date group by sku
		SELECT 'ITRN CURR', sku, sum(qty) FROM #ITRN_CUT_BY_SKU where (EffectiveDate >= @d_begin_date and EffectiveDate <= @d_end_date) group by sku
	END
END  /* continue and stuff */
-- End - Current Stock Movement by Trx Line

-- OB Archive Qty from SKU
IF @n_continue=1 or @n_continue=2
BEGIN
	 IF ( @n_num_recs > 0)
	 BEGIN
      INSERT #ITRN_CUT_BY_SKU
      SELECT
              a.StorerKey
            , a.Sku
            , a.ArchiveQty
            , TranType = "OB"
            , @BFDate,
				'',
				'',
				''
      FROM sku a (nolock)
      WHERE a.archiveqty > 0
        AND EXISTS
      (SELECT * FROM #ITRN_CUT_BY_SKU B
      WHERE a.storerkey = b.storerkey
		  AND a.sku = b.sku )

		 IF @b_debug = 1
			select 'SKU Archive qty ', * from #itrn_cut_By_sku where trantype = 'OB'
    END
END

-- Start : SOS30311 
-- Get 'NoTran' Sku details, for date = reportdate - 1 (OB)
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT a.Storerkey, a.SKU, a.ArchiveQty
   INTO  #TEMPSKUa
   FROM  SKU a (NOLOCK)
   WHERE a.StorerKey = @StorerKey
   AND   a.Sku between @SkuMin AND @SkuMax   
	AND   NOT EXISTS
	(SELECT b.SKU 
	 FROM   #ITRN_CUT_BY_SKU b
	 WHERE  a.storerkey = b.storerkey
	 AND     a.sku = b.sku )

	IF @b_debug = 1
	BEGIN
		SELECT 'NoTran', * FROM #TEMPSKUa
	END

   INSERT #ITRN_CUT_BY_SKU
   SELECT a.StorerKey
         , a.Sku
         , a.ArchiveQty
         , TranType = "OB"
         , @BFDate,
			'',
			'',
			''
   FROM #TEMPSKUa a (nolock)	
END
-- End : SOS30311

IF @n_continue=1 or @n_continue=2
BEGIN
	/* Calc the OB = ITrn OB + Archive Qty */
	/* sum up everything before the @datemin including archive qtys */
	SELECT
	       StorerKey
		  , SKU = SKU
	     , QTY = SUM(Qty)
	     , EffectiveDate = @BFDate
	     , Flag = "AA"
	     , TranType = "  "
	     , RunningTotal = sum(qty)
	     , Record_number = 0
		  , Sourcekey =  SPACE(20) 
		  , SourceType = SPACE(30) 
	INTO   #BF
	FROM   #ITRN_CUT_BY_SKU
	WHERE  EffectiveDate < @d_begin_date
	GROUP BY storerkey, sku /**/
	
	SELECT @n_num_recs = @@rowcount
	IF @b_debug = 1
	BEGIN
		SELECT '(AA = ITRN OB + ArchiveQty )', * FROM #BF 
	END 
END


/* if this is a new product */
/* or the data does not exist for the lower part of the date range */
/* this is to set the opening balance to 0 */
IF @n_continue=1 or @n_continue=2
BEGIN
	IF (@n_num_recs = 0)
	BEGIN
		INSERT #BF
		SELECT  StorerKey
				, SKU
		      , QTY= 0
		      , EffectiveDate = @BFDate
		      , Flag = "AA"
		      , TranType = "  "
		      , RunningTotal = 0
		      , record_number = 0
			   , Sourcekey =  SPACE(20) 
			   , SourceType = SPACE(30) 
		FROM #ITRN_CUT_BY_SKU
		GROUP by StorerKey, SKU
	END /* numrecs = 0 */
END /* for n_continue etc. */

 
IF @n_continue=1 or @n_continue=2
BEGIN
 /* pick up the unique set of records which are in the in between period */
 IF (@n_num_recs > 0)
 BEGIN
  SELECT StorerKey
		  , sku
        , qty = 0
        , EffectiveDate = @BFDate
        , flag="BB"
        , TranType 
        , RunningTotal = 0
		  , '' as Sourcekey -- Sourcekey
  INTO  #BF_TEMP3
  FROM  #ITRN_CUT_BY_SKU
  WHERE (EffectiveDate >= @d_begin_date and EffectiveDate <= @d_end_date)
  GROUP BY StorerKey, sku, Trantype, Sourcekey
  SELECT @n_num_recs = @@rowcount

   SELECT @n_err = @@ERROR
   IF NOT @n_err = 0
   BEGIN
        SELECT @n_continue = 3
        /* Trap SQL Server Error */
        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
        SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3 (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
        /* End Trap SQL Server Error */
   END
 END /* if @n_num_recs > 0 */
END /* continue and stuff */


   /*
   add only those storerkey, sku and lot combinations which do not exist in #BF
   i.e. there might be some new records after the begin period.
        However do not add
        storerkey, sku and lot combo which exist before and after the begin period
   */

  IF @n_continue=1 or @n_continue=2
  BEGIN
    /* pick up the unique set of records which are in the in between period
       which do not exist in the past period */

    /* BB means those unique lot records which fall in between begin_date and end_date
       which do not have history */
    IF (@n_num_recs > 0)
    BEGIN
         SELECT
                 StorerKey
					, sku 
               , qty = 0
               , EffectiveDate = @BFDate
               , flag="AA"    /* was BB */
               , TranType  
               , RunningTotal = 0
					, Sourcekey 
         INTO #BF_TEMP3a
         FROM #BF_TEMP3 a
         WHERE NOT exists
         (SELECT * from #BF b
          WHERE a.StorerKey = b.StorerKey
			 AND 	 a.Sku = b.Sku
          )
          SELECT @n_err = @@ERROR
          SELECT @n_num_recs_bb = (SELECT COUNT(*) FROM #BF_TEMP3a)

         IF NOT @n_err = 0
         BEGIN
              SELECT @n_continue = 3
              /* Trap SQL Server Error */
              SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
              SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
              /* End Trap SQL Server Error */
         END	
    END /* if @n_num_recs > 0 */
  END /* continue and stuff */

  IF @n_continue=1 or @n_continue=2
  BEGIN
    IF ( @n_num_recs_bb > 0)
    BEGIN
      INSERT #BF
      SELECT StorerKey
				, SKU
            , qty
            , EffectiveDate
			   , flag
            , TranType
				, RunningTotal
            , Record_number = 0
				, Sourcekey 
				, SPACE(30)  
      FROM #BF_TEMP3a

      SELECT @n_err = @@ERROR
      IF NOT @n_err = 0
      BEGIN
           SELECT @n_continue = 3
           /* Trap SQL Server Error */
           SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=74802   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
           SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Summary Insert Failed On #BF_TEMP3a (nsp_smr_by_trxdate_pmtl)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
           /* End Trap SQL Server Error */
      END
    END	
  END /* continue and stuff */
	
  /* ...then add all the data between the requested dates. */
  SELECT
          StorerKey
		  , SKU
        , Qty
        , TrxDate = EffectiveDate
        , Flag = "  "
        , TranType
        , RunningTotal = 0
        , record_number = 0
		  , ISNULL(Sourcekey, "") As Sourcekey 
 	     , ISNULL(SourceType, "") As SourceType   
  INTO #BF2
  FROM #ITRN_CUT_BY_SKU
  WHERE EffectiveDate >= @d_begin_date

  INSERT #BF
  SELECT StorerKey
		  , SKU
        , SUM(Qty)
        , TrxDate
        , flag
        , TranType
        , RunningTotal = 0
        , Record_number = 0
		  , dbo.fnc_LTrim(dbo.fnc_RTrim(Sourcekey)) 
		  , dbo.fnc_LTrim(dbo.fnc_RTrim(Sourcetype))
  FROM #BF2
  GROUP BY
          StorerKey
        , TrxDate
        , TranType
		  , SKU 
		  , Sourcetype 
		  , Sourcekey 
		  , flag

  IF (@b_debug = 1)
  BEGIN
    SELECT	'BF - In between trx - ', *
	 FROM #BF2
	 ORDER BY StorerKey
  END


  /* put the cursor in here for running totals */
  /* declare cursor vars */
	 DECLARE @sku					 NVARCHAR(20)
	 DECLARE @sourcekey			 NVARCHAR(30)
	 DECLARE @sourceline			 NVARCHAR(5)
	 DECLARE @sourcetype			 NVARCHAR(30)
	 DECLARE @Qty						int
	 DECLARE @EffectiveDate			datetime
	 DECLARE @Flag					 NVARCHAR(2)
	 DECLARE @TranType			 NVARCHAR(10)
	 DECLARE @RunningTotal			int
	 DECLARE @prev_StorerKey	 NVARCHAR(15)
	 DECLARE @prev_sku			 NVARCHAR(20)
	 DECLARE @prev_Qty				int
	 DECLARE @prev_EffectiveDate	datetime
	 DECLARE @prev_Flag			 NVARCHAR(2)
	 DECLARE @prev_TranType		 NVARCHAR(10)
	 DECLARE @prev_RunningTotal	int
	 DECLARE @record_number			int 
	 DECLARE @DocType				 NVARCHAR(12) 
	 DECLARE @DocRef				 NVARCHAR(20)
    DECLARE @Label               NVARCHAR(20) -- vicky
    DECLARE @ProcessType         NVARCHAR(20) -- vicky
    DECLARE @type                NVARCHAR(5)
	
	 SELECT @record_number = 0
    SELECT @RunningTotal = 0

	 DELETE FROM #BF2

    EXECUTE('DECLARE cursor_for_running_total CURSOR FAST_FORWARD READ_ONLY 
         FOR  SELECT
           StorerKey
			, SKU
         , Qty
         , EffectiveDate
         , Flag
         , TranType
			, Sourcekey 
			, SourceType 
         FROM #BF
         ORDER BY StorerKey, SKU, EffectiveDate, Trantype')
    OPEN cursor_for_running_total

    FETCH NEXT FROM cursor_for_running_total	
    INTO  @StorerKey,
          @sku,
          @Qty,
          @EffectiveDate,
          @Flag,
          @TranType,
			 @Sourcekey, 
			 @Sourcetype 

    WHILE (@@fetch_status <> -1)
    BEGIN       
         IF (dbo.fnc_RTrim(@TranType) = 'DP' or dbo.fnc_RTrim(@TranType) = 'WD' or
             dbo.fnc_RTrim(@TranType) = 'AJ')
         BEGIN
              SELECT @RunningTotal = @RunningTotal + @qty
         END

         IF (dbo.fnc_RTrim(@Flag) = 'AA' or dbo.fnc_RTrim(@Flag) = 'BB')
         BEGIN
         /* first calculated  total */
              SELECT @RunningTotal = @qty
				  SELECT @Trantype = 'OB'
         END

			IF (@b_debug = 2)
         BEGIN
         select @StorerKey,"|",
                @sku,"|",
                @Qty,"|",
                @EffectiveDate,"|",
                @Flag,"|",
					@TranType,"|",
					CONVERT(NCHAR(20), @Sourcekey), "|",
					@RunningTotal,"|",
					@record_number,"|"
         END

			IF @sourcekey IS NULL SELECT @sourcekey = ""

         INSERT #BF2
              values(
              @StorerKey,
              @sku,
              @Qty,
              @EffectiveDate,
              @Flag,
              @TranType,
              @RunningTotal,
              @record_number,
				  @Sourcekey, 
				  @Sourcetype)

         SELECT @prev_StorerKey = @StorerKey
         select @prev_sku = @sku
         SELECT @prev_qty =  @Qty
         SELECT @prev_flag = @Flag
         SELECT @prev_EffectiveDate = @EffectiveDate
         SELECT @prev_TranType =  @TranType
         SELECT @prev_RunningTotal = @RunningTotal

         FETCH NEXT FROM cursor_for_running_total
         INTO
               @StorerKey,
               @sku,
               @Qty,
               @EffectiveDate,
               @Flag,
               @TranType,
					@Sourcekey, 
					@Sourcetype 

         --SELECT @record_number = @record_number + 1
         IF (@storerkey <> @prev_storerkey)
         BEGIN
              IF (@b_debug = 2)
              BEGIN
					  select 'prev_storerkey', @prev_storerkey,'prev_sku', @prev_sku
              END
              select @runningtotal = 0
         END
    END /* while loop */

    close cursor_for_running_total
    deallocate cursor_for_running_total


	/* Output the data collected. */
	/* summarizing the qty into opening balance, in_qty, out_qty and ending_balance */
	-- Start - SOS15891
	/*
	SELECT a.StorerKey
		  , a.sku
		  , c.RetailSKU   -- SOS15891 
		  , SUBSTRING(c.BUSR1, 1, 2) as BUSRGroup -- SOS15891
		  , c.descr
		  , a.TrxDate as TrxDate
		  -- , CONVERT(CHAR, CONVERT(DATETIME, TrxDate , 101), 101) As TrxDate2
	     , 0 as o_qty
	     , 0 as in_qty
	     , 0 as out_qty
	     , 0 as bal_qty
		  , a.TranType
		  , a.Sourcekey
		  , a.Sourcetype 
		  , SPACE(12) DocType  
		  , SPACE(20) DocRef 
		  , a.record_number
        , SPACE(20) Label -- vicky
        , SPACE(5) as type 
	INTO #RESULT
	FROM #BF2 a, storer b, sku c (NOLOCK)
	WHERE a.storerkey = b.storerkey
	AND   a.Storerkey = c.Storerkey
	AND	a.Sku = c.Sku
	group by a.storerkey, a.SKU, a.TrxDate, a.TranType, a.Sourcetype, a.Sourcekey, c.Descr, record_number	
			 , c.RetailSKU, c.BUSR1  -- SOS15891
	*/

	SELECT a.StorerKey
	  -- , c.SKU as sku  : SOS30311 
	  , c.RetailSKU   -- SOS15891 
	  , SUBSTRING(c.BUSR1, 1, 2) as BUSRGroup -- SOS15891
	  , MIN(c.Descr) as descr
	  , a.TrxDate as TrxDate
	  , CASE WHEN Trantype = 'OB' THEN SUM(qty) ELSE 0 END as o_qty
	  , CASE WHEN Trantype IN ('DP', 'AJ') AND SUM(qty) > 0  THEN SUM(qty) ELSE 0 END as in_qty
	  , CASE WHEN Trantype IN ('WD', 'AJ') AND SUM(qty) < 0 THEN SUM(qty) * -1 ELSE 0 END as out_qty
	  , 0 as bal_qty
	  , a.TranType
	  , a.Sourcekey
	  , a.Sourcetype 
	  , SPACE(12) DocType  
	  , SPACE(20) DocRef 
	  , 0 AS record_number -- a.record_number
	  , SPACE(20) Label -- vicky
	  , SPACE(5) as type 
	INTO #RESULT
	FROM #BF2 a, sku c (NOLOCK)
	WHERE a.Storerkey = c.Storerkey
	AND	a.Sku = c.Sku
	group by a.storerkey, a.TrxDate, a.TranType, a.Sourcetype, a.Sourcekey --, record_number	
		 , c.RetailSKU, c.BUSR1  -- SOS15891
	-- End - SOS15891

   /*
	  Assign document reference & label
	*/
   Declare @retailsku NVARCHAR(20)
	Declare Docref_cur CURSOR FAST_FORWARD READ_ONLY FOR 
	SELECT   StorerKey,
				retailsku, -- SOS30311
				TranType,
				SUBSTRING(Sourcekey, 1, 10) As Sourcekey, 
				SUBSTRING(Sourcekey, 11, 15) As SourceLine, 
				SourceType, 
				record_number
				from #RESULT
				order by storerkey, retailsku, record_number

	OPEN Docref_cur 
	
	FETCH NEXT FROM Docref_cur INTO  
	    		 @StorerKey,
	          @retailsku,
	          @TranType,
				 @Sourcekey,
				 @sourceline, 
				 @Sourcetype, 
			    @record_number 

	WHILE (@@fetch_status <> -1)
   BEGIN 
		SELECT @DocType = '', @DocRef = '' , @Label = '', @type = ''

		IF @TranType = 'DP'
		BEGIN
			-- processing 
			IF SUBSTRING(@Sourcetype,1,10) = 'ntrReceipt'
			BEGIN
           -- Modify by Vicky 30 June 2003
            SELECT @ProcessType = RECEIPT.ProcessType
            FROM RECEIPT (NOLOCK)
            WHERE Receiptkey = @Sourcekey

				IF @ProcessType = 'I'
            BEGIN
              SELECT @DocRef = REPLACE(dbo.fnc_LTrim(replace(RECEIPT.WarehouseReference,'0',' ')),' ', '0'), @DocType = ''
              FROM RECEIPT (NOLOCK)
   			 WHERE Receiptkey = @Sourcekey              
            END
--            ELSE           /* Modified by Tuk 14 Nov 2003*/
				IF @ProcessType = 'R'
--                                /* Modified by Tuk 14 Nov 2003*/
            BEGIN
              SELECT DISTINCT @DocType = PO.POType, @DocRef = REPLACE(dbo.fnc_LTrim(replace(PO.ExternPOKey,'0',' ')),' ', '0') 
              FROM PO (NOLOCK)
              JOIN RECEIPTDETAIL (NOLOCK) ON (PO.POkey = RECEIPTDETAIL.POKey)
  			     WHERE Receiptkey = @Sourcekey
            END
			END
			ELSE 
			BEGIN
				IF SUBSTRING(@Sourcetype,1,10) = 'CC Deposit'
				BEGIN
					SELECT @DocType = '', @DocRef = REPLACE(dbo.fnc_LTrim(replace(CCSheetNo,'0',' ')),' ', '0')  
					  FROM CCDETAIL (Nolock) 
					 WHERE CCDetailKey = @Sourcekey
				END
				ELSE
				BEGIN
					IF SUBSTRING(@Sourcetype,1,11) = 'ntrTransfer'
					BEGIN	
						SELECT @DocType = TYPE, @DocRef = ''  
						  FROM TRANSFER (Nolock) 
						 WHERE TransferKey = @Sourcekey
					END	
				END
			END		
		END
		ELSE	
		BEGIN
			IF @TranType = 'WD'
			BEGIN
				-- processing 
				IF SUBSTRING(@Sourcetype,1,7) = 'ntrPick'
				BEGIN
					-- Modified by MaryVong on 18Feb2005 (SOS32458) - (1)
					-- Changed EXTERNORDERKEY to INVOICENO
					-- SELECT @DocType = TYPE, @DocRef = REPLACE(dbo.fnc_LTrim(replace(EXTERNORDERKEY,'0',' ')),' ', '0')
					SELECT @DocType = TYPE, @DocRef = REPLACE(dbo.fnc_LTrim(replace(INVOICENO,'0',' ')),' ', '0')    
					  FROM ORDERS (Nolock) 
					 WHERE ORDERKEY = @Sourcekey
				END
				ELSE 
				BEGIN
					IF SUBSTRING(@Sourcetype,1,13) = 'CC Withdrawal'
					BEGIN
						SELECT @DocType = '', @DocRef = REPLACE(dbo.fnc_LTrim(replace(CCSheetNo,'0',' ')),' ', '0')    
						  FROM CCDETAIL (Nolock) 
						 WHERE CCDetailKey = @Sourcekey
					END
					ELSE
					BEGIN
						IF SUBSTRING(@Sourcetype,1,11) = 'ntrTransfer'
						BEGIN	
							SELECT @DocType = TYPE, @DocRef = ''  
							  FROM TRANSFER (Nolock) 
							 WHERE TransferKey = @Sourcekey
						END	
					END
				END
			END
		END
   
       IF @TranType = 'AJ'
       BEGIN 
          SELECT @DocRef = REPLACE(dbo.fnc_LTrim(replace(ADJUSTMENT.CustomerRefNo,'0',' ')),' ', '0'),
          		  @DocType = AdjustmentType  -- SOS15891
          FROM ADJUSTMENT (NOLOCK)
          WHERE AdjustmentKey = @Sourcekey
       END

-- SOS42111
-- Added By Vicky 30th June 2003
--      IF @DocType like 'OR-92%' 
--       BEGIN
--         SELECT @Label = 'Invoice #', @type = 'OR'
--       END
--       ELSE
--       IF @DocType like 'ZRQB-RQ%'
--       BEGIN
--         SELECT @Label = 'RQB #', @type = 'ZR'
--       END
--       ELSE
--       IF @DocType like 'RE-92%'
--       BEGIN
--         SELECT @Label = 'CN #', @Type = 'RE'
--       END
--       ELSE
--       IF @DocType like 'CR-RQ%' and @ProcessType <> 'I'
--       BEGIN
--         SELECT @Label = 'RQB #', @type = 'CR'
--       END
		IF @DocType like 'ZOR-92%' 
      BEGIN
        SELECT @Label = 'Invoice #', @type = 'OR'
      END
      ELSE
      IF @DocType like 'ZRQB-RQ%'
      BEGIN
        SELECT @Label = 'RQB #', @type = 'ZR'
      END
      ELSE
      IF @DocType like 'ZRE-92%'
      BEGIN
        SELECT @Label = 'CN #', @Type = 'RE'
      END
      ELSE
      IF @DocType like 'ZCRM-RQ%' and @ProcessType <> 'I'
      BEGIN
        SELECT @Label = 'RQB #', @type = 'CR'
      END      

      IF @TranType = 'AJ'
      BEGIN
   		-- Modified by MaryVong on 18Feb2005 (SOS32458) - (2)
         IF @DocType like 'T%'
         BEGIN
           SELECT @Label = 'TFB #', @type = 'AJ'
         END
   		-- End of SOS32458 (2)         
         ELSE
         BEGIN               
            SELECT @Label = 'ADJ #', @type = 'AJ'
         END   
      END

      IF @ProcessType = 'I' and @TranType = 'DP'
      BEGIN
        SELECT @Label = 'RR #', @type = 'I'
      END

		-- SOS15891
      IF @TranType = 'OB'
      BEGIN
        SELECT @Label = 'OB'
      END	

-- END Add

		UPDATE #RESULT 
		   SET DocType = @DocType, 
				 DocRef =  @DocRef ,
             Label = ISNULL(@Label,''), -- vicky,
             Type = ISNULL(@type, '') 
		 WHERE Storerkey = @storerkey
			AND retailSku = @retailsku
			AND Sourcekey = Substring(@sourcekey,1,10) + Substring(@sourceline,1,5)
			AND Sourcetype = @sourcetype
			AND Trantype = @trantype 
			-- AND Record_number = @record_number 

		FETCH NEXT FROM Docref_cur INTO  
		          @StorerKey,
		          @retailsku,
		          @TranType,
					 @Sourcekey,
					 @sourceline, 
					 @Sourcetype, 
				    @record_number 

	END -- While loop for searching Doctype, Docref	
	CLOSE Docref_cur
	DEALLOCATE Docref_cur
	
	-- SOS15891
  	-- DELETE FROM #RESULT WHERE Label = '' 

	-- SOS30311, remark by June 14.Feb.2005, this cause Openning Bal <> Closing Bal
	--   /* Modified by Tuk 14 Nov 2003*/
	DELETE FROM #RESULT WHERE TranType = 'DP' AND Label = ''
	-- DELETE FROM #RESULT WHERE TranType = 'AJ' AND DocType = '99'
	DELETE FROM #RESULT WHERE TranType = 'WD' AND Label = ''
	--   /* Modified by Tuk 14 Nov 2003*/


	if @b_debug = 3
	begin	
		select * into tmpbfresult from #result
	end


	/* -Start Report_cursor
		The previous RunningTotal is SUM by SKU
		Recalculate the OB bal & Closing bal according to how records are presented in the report
		i.e Shown by BUSRGroup, RetailSKU & sorting seq
	*/
	DECLARE @company NVARCHAR(45)
	DECLARE @acc_ob int, @upd_ob int, @BalQty as int 
	
	SELECT @acc_ob = 0	
	SELECT @prev_storerkey = SPACE(15)
	SELECT @prev_sku = SPACE(20)

	DECLARE report_cursor CURSOR  FAST_FORWARD READ_ONLY FOR
	   select a.StorerKey,
				 a.RetailSKU,
	          SUM(a.o_qty + a.in_qty - a.out_qty) as balqty, -- SOS30311 - add SUM
	          a.trantype,
				 a.TrxDate,
				 a.Sourcekey
		from  #RESULT a, storer b (NOLOCK)
	   where a.storerkey = b.storerkey
	   GROUP BY a.StorerKey, a.RetailSKU, a.trantype, a.TrxDate, a.Sourcekey, a.BusrGroup, a.label, a.DocRef -- SOS30311
		ORDER BY a.Storerkey, a.BusrGroup, a.RetailSKU, a.TrxDate, a.trantype, a.label, a.DocRef

	    OPEN report_cursor
	
	    FETCH NEXT FROM report_cursor
	    INTO  @StorerKey,
	          @sku,
	          @BalQty,
	          @TranType,
			    @EffectiveDate,
				 @Sourcekey
				 
	 SELECT @record_number = 0	
	 SELECT @acc_ob = 0	
	 SELECT @upd_ob = 0	

    WHILE (@@fetch_status <> -1)
    BEGIN			
			SELECT @record_number = @record_number + 1

			IF @prev_storerkey <> @storerkey OR @prev_sku <> @sku
			BEGIN
				SELECT @upd_ob = @Balqty
				SELECT @acc_ob = @Balqty
				SELECT @Prev_storerkey = @storerkey
				SELECT @prev_sku = @sku
			END
			ELSE
			BEGIN
				SELECT @upd_ob = @acc_ob
				SELECT @acc_ob = @acc_ob + @Balqty 
			END

			IF @b_debug = 1
			begin
				select 'rec#', @record_number, 'sku', @sku, 'TranType', @Trantype, 'Balqty', @Balqty, '@upd_ob', @upd_ob, '@acc_ob ', @acc_ob
			end

			update #RESULT			
			set   o_qty = @upd_ob,
					bal_qty = @acc_ob,
					record_number = @record_number
   		where storerkey = @storerkey
			and   Retailsku = @sku
			and   Trantype  = @TranType
			and   Trxdate   = @EffectiveDate
			and   Sourcekey = @Sourcekey	
					
         FETCH NEXT FROM report_cursor
         INTO	@StorerKey,
               @sku,
               @BalQty,
               @TranType,
					@EffectiveDate,
					@Sourcekey
		END /* while loop */
		CLOSE report_cursor
		DEALLOCATE report_cursor
	 -- End - SOS15891

    -- SOS15891
    -- DELETE #RESULT WHERE Trantype = 'OB'

	if @b_debug = 3
	begin	
		select * into tmpafresult from #result
	end

	-- SOS30311
	SELECT DISTINCT * INTO #FINAL_RESULT FROM #RESULT


	-- Get 'NoTran' SKU details, for date = reportdate
   Declare @c_noretailsku NVARCHAR(20), @n_cnt int , @c_noretailsku1 NVARCHAR(20), @n_archiveqty int, @d_date datetime, @date datetime
   Declare @c_nosretailku2 NVARCHAR(20), @b_qty int, @trxdate datetime, @sdescr NVARCHAR(60), @sdescr2 NVARCHAR(60)
	-- SOS30311 
	Declare @sGroup NVARCHAR(30), @sGroup2 NVARCHAR(30)
   
   SELECT Storerkey, RetailSku, Descr = MIN(Descr), 
			 BusrGroup = SUBSTRING(BUSR1, 1, 2), -- SOS30311
			 0 as cnt
   INTO  #TEMPSKU 
   FROM  SKU (NOLOCK)
   WHERE StorerKey = @StorerKey
   AND   Sku between @SkuMin AND @SkuMax   
	GROUP BY Storerkey, RetailSku, BUSR1 -- SOS30311, add Busr1

   Create Table #TEMPCNT ( Storerkey NVARCHAR(15) NULL, 
                          RetailSku NVARCHAR(20) NULL, 
                          Descr NVARCHAR(60) NULL, 
								  BusrGroup NVARCHAR(30) NULL, -- SOS30311, 
                          Adddate datetime, 
                          Cnt int, 
                          rowid int )

	Create Table #RESULTA 
	( Storerkey NVARCHAR(15) NULL, 
	 RetailSku NVARCHAR(20) NULL, 
	 TrxDate datetime, O_qty int, 
	 in_qty int, out_qty int,
	 bal_qty int, Trantype NVARCHAR(10) NULL, 
	 Sourcekey NVARCHAR(30) NULL, Sourceline NVARCHAR(5) NULL, 
	 Sourcetype NVARCHAR(30) NULL, Doctype NVARCHAR(12) NULL, 
	 DocRef NVARCHAR(20) NULL, Daterange NVARCHAR(50) NULL,
	 userid NVARCHAR(20) NULL, record_number int , 
	 descr NVARCHAR(60) NULL, busrgroup NVARCHAR(30) NULL, label NVARCHAR(20) NULL, -- SOS30311, add BusrGroup
	 type NVARCHAR(5) NULL, rowid int)
	
	Create Table #RESULTB
	( storerkey NVARCHAR(15) NULL, retailsku NVARCHAR(20) NULL, bal_qty int)
	
	declare @ncount int, @nrowid int  
   select @nrowid = 1
    
  SELECT @c_noretailsku = ''
  WHILE(1=1)
  BEGIN 
    SELECT @c_noretailsku = MIN(retailsku)
    FROM  #TEMPSKU
    WHERE retailsku > @c_noretailsku 
    
    IF @c_noretailsku = '' or @c_noretailsku IS NULL BREAK
 
     SELECT @d_date = @d_begin_date

     WHILE @d_date < @d_end_date
     BEGIN
       SELECT @n_cnt = COUNT(*) 
       FROM  ITRN (NOLOCK), SKU (NOLOCK)
       WHERE SKU.StorerKey = @StorerKey
		   AND SKU.retailsku = @c_noretailsku
         AND ITRN.Adddate >= @d_date and ITRN.Adddate < DATEADD(day,1, @d_date)
         AND TranType IN ("DP", "WD", "AJ")
			AND ITRN.Storerkey = SKU.Storerkey
			AND ITRN.SKU = SKU.SKU

      SELECT @sdescr = MIN(Descr),
				 @sGroup = MIN(BusrGroup) -- SOS30311 
      FROM  #TEMPSKU
      Where retailsku =  @c_noretailsku
        AND Storerkey = @StorerKey     

      SELECT @ncount = COUNT(*)
      FROM  #FINAL_RESULT (NOLOCK) -- SOS30311, User #Final_result instead of #RESULT
      WHERE Retailsku = @c_noretailsku
        AND storerkey = @StorerKey
        AND trxdate = @d_date 

     IF @ncount = 0
     BEGIN    
      	select @n_cnt = 0	  
     END
              
		-- SOS30311, add @sGroup
      INSERT INTO #TEMPCNT 
      SELECT @StorerKey, @c_noretailsku , @sdescr, @sGroup, @d_date , @n_cnt, @nrowid

      SELECT @nrowid = @nrowid + 1

      SELECT @d_date = DATEADD(day,1, @d_date)
     
     END -- date
   END -- while

   declare @n_rowid int
   SELECT @n_rowid = ''
   WHILE(1=1)
   BEGIN 
    SELECT @n_rowid = Min(rowid)     
    FROM  #TEMPCNT
    WHERE rowid > @n_rowid 
     AND  Cnt = 0

    IF @n_rowid = '' or @n_rowid IS NULL BREAK  
   
     SELECT @c_noretailsku1 = retailSku
     FROM  #TEMPCNT
     WHERE rowid = @n_rowid

		-- SOS30311, add @sGroup2
      SELECT @date = Adddate, @sdescr2 = Descr, @sGroup2 = BusrGroup
      FROM  #TEMPCNT
      WHERE RetailSku = @c_noretailsku1
        AND Storerkey = @StorerKey
        AND Cnt = 0
        AND rowid = @n_rowid

		-- SOS30311, add @sGroup2
      INSERT INTO #RESULTA
      SELECT  @StorerKey , @c_noretailsku1 , @date , 0 , 0 , 0 , 0 ,  'NoTran' ,
              '', '' , '' ,'' ,'', "From " + @DateStringMin + " To "+ @DateStringMax,
              Convert(NVARCHAR(20), Suser_Sname()),0 ,@sdescr2 , @sGroup2, '' ,'' , @n_rowid
  END -- while

   -- Get ArchiveQty for 'NoTran' records
	Declare @ncnt int, @narchiveqty int, @n_rowid1 int, @n_minrecord int

	SELECT @n_rowid1 = ''
	WHILE(1=1)
	BEGIN 
		SELECT @n_rowid1 = Min(rowid)     
		FROM  #RESULTA
		WHERE rowid > @n_rowid1 
	
		IF @n_rowid1 = '' or @n_rowid1 IS NULL BREAK  
	
		SELECT @c_nosretailku2 = RetailSku
		FROM  #RESULTA
		WHERE rowid = @n_rowid1
	
		SELECT @trxdate = Trxdate
		FROM  #RESULTA
		WHERE retailSku =  @c_nosretailku2
		AND   Storerkey = @storerkey
		AND   rowid = @n_rowid1
	
		SELECT @ncnt = COUNT(*)
		FROM  #FINAL_RESULT -- SOS30311, User #Final_result instead of #RESULT
		WHERE RetailSku = @c_nosretailku2
		AND   Storerkey = @StorerKey
		AND   Trxdate < @trxdate

		IF @ncnt = 0
		BEGIN 
			 SELECT @n_minrecord = Min(record_number)
			 FROM  #FINAL_RESULT  -- SOS30311, User #Final_result instead of #RESULT
			 WHERE retailSku = @c_nosretailku2
			   AND Storerkey = @StorerKey
			   AND TrxDate = dateadd(day,1,@trxdate) 
			
			 SELECT @narchiveqty = o_qty
			 FROM  #FINAL_RESULT -- SOS30311, User #Final_result instead of #RESULT
			 WHERE RetailSku = @c_nosretailku2
			   AND Storerkey = @StorerKey
			   AND Record_number = @n_minrecord
			   AND TrxDate = dateadd(day,1,@trxdate) 
			
			IF @@ROWCOUNT = 0 
			BEGIN
				Select @narchiveqty = 0
			END
			
			UPDATE #RESULTA
			SET O_qty = @narchiveqty, bal_qty = @narchiveqty
			WHERE RetailSku = @c_nosretailku2
			AND Storerkey = @StorerKey
	  END

    INSERT INTO #RESULTB 
    SELECT tr.storerkey, tr.retailsku, sum(bal_qty)
	 from   #FINAL_RESULT tr -- SOS30311, User #Final_result instead of #RESULT
	 join (select retailsku, max(record_number) as rowid from #FINAL_RESULT (nolock) group by retailsku) tempsku -- SOS30311, User #Final_result instead of #RESULT
			on (tr.retailsku = tempsku.retailsku and tr.record_number = tempsku.rowid)
    WHERE tr.retailSku = @c_nosretailku2
      AND tr.Storerkey = @StorerKey
      AND tr.Trxdate = dateadd(day,-1,@trxdate)
    GROUP BY Storerkey, tr.retailSku, Trxdate
    order BY Storerkey, tr.retailSku, Trxdate

    UPDATE #RESULTA
    SET   a.O_qty = b.bal_qty, a.bal_qty = b.bal_qty
    FROM  #RESULTA a , #RESULTB b
    WHERE a.storerkey = b.storerkey
    AND   a.retailsku = b.retailsku
    AND   a.retailsku = @c_nosretailku2
    AND   a.rowid = @n_rowid1
   END -- sku2

	 -- SOS15891, do not show ADJ where doc type = '99'	
	 -- DELETE FROM #RESULT WHERE Type = 'AJ' AND DocType = '99'     /* Modified by Tuk 14 Nov 2003*/

    SET NOCOUNT OFF

	 -- Output RESULT HERE
 	 SELECT  StorerKey,
				-- sku, --SOS30311
				RetailSKU, -- SOS15891
				BUSRGroup, -- SOS15891
				TrxDate As TrxDate, 
				o_qty,
				in_qty,
				out_qty,
				bal_qty,
				TranType,
				SUBSTRING(Sourcekey, 1, 10) As Sourcekey, 
				SUBSTRING(Sourcekey, 11, 15) As SourceLine, 
				SourceType, 
				DocType, 
				DocRef, 
				DateRange = "From " + @DateStringMin + " To "+ @DateStringMax,
				userid = Convert(NVARCHAR(20), Suser_Sname()),
				Descr  ,
				record_number,
            Label, -- vicky
            Type
	FROM  #FINAL_RESULT 	-- SOS30311, User #Final_result instead of #RESULT
   UNION ALL
	SELECT   Storerkey,
				RetailSKU, -- SOS15891
				BUSRGroup,	-- SOS15891
				TrxDate As TrxDate, 
				o_qty,
				in_qty,
				out_qty,
				bal_qty,
				TranType,
				Sourcekey, 
				SourceLine, 
				SourceType, 
				DocType, 
				DocRef, 
				DateRange = "From " + @DateStringMin + " To "+ @DateStringMax,
				userid = Convert(NVARCHAR(20), user_name()),
				Descr,
				record_number,
            Label, -- vicky
				Type
	FROM  #RESULTA 
 	ORDER BY Storerkey, BusrGroup, RetailSKU, TrxDate, trantype, label, DocRef

	
	DROP TABLE #ITRN_CUT_BY_SKU_ITT
	DROP TABLE #ITRN_CUT_BY_SKU
	DROP TABLE #BF
	DROP TABLE #BF2
	DROP TABLE #RESULT
	DROP TABLE #FINAL_RESULT 	-- SOS30311
	DROP TABLE #TEMPSKUa
	DROP TABLE #TEMPSKU
	DROP TABLE #TEMPCNT
	DROP TABLE #RESULTA
	DROP TABLE #RESULTB
	IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE NAME = '#BF_TEMP3') DROP TABLE #BF_TEMP3
	IF EXISTS (SELECT 1 FROM dbo.sysobjects WHERE NAME = '#BF_TEMP3a') DROP TABLE #BF_TEMP3a
END

GO