SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/* 2014-Mar-21  TLTING    1.1   SQL20112 Bug                            */

CREATE PROC [dbo].[nspGenSerialNo] (@c_kitkey		 NVARCHAR(10) )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
	/*******************************************************************************/
   /* 1-OCt-2004 YTWan FBR 016 - Generate JAMO Serial #									 */
   /*******************************************************************************/

	DECLARE 	@n_err           int,
				@n_continue      int,
				@b_success       int,
				@c_errmsg        NVARCHAR(255),
				@n_StartTranCnt  int,
				@n_serialno      int,
				@c_sku			  NVARCHAR(20),
				@n_qty			  int,
				@n_cnt			  int,
				@n_keycount      int,
				@c_weekyear		  NVARCHAR(4)

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

 /* Start Modification */
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

	CREATE TABLE #tempserial
			( Sku NVARCHAR(20) NULL,
			  SerialNo NVARCHAR(10) NULL)
	
	SELECT @c_weekyear = RIGHT('0' + CAST(DATEPART(Week, GetDate()) as NVARCHAR(2)),2) +
								RIGHT(CAST(year(GetDate()) as NVARCHAR(4)),2)

	SELECT @n_keycount = KeyCount
	FROM   NCounter (NOLOCK)
	WHERE	 KeyName = 'JAMOSERIALNO'

   IF ISNULL(@n_keycount,0) <> 0 
	BEGIN
      -- SOS45074 start
      /* 
         JAMO serial no format = 92wwyy9999 (on report)
         92 = prefix
         ww = week no
         yy = year no
         9999 = running no. start from 1. Means report show 1 as the 1st serial no

         NOTE:
         JAMO serial no format = wwyy9999 (on DB)
         Stored in NCounter.KeyCount, int
         So when ww = 1,2...9, it wont store as 01,02...09
      */
		-- SELECT @n_serialno = CASE WHEN @c_weekyear = SUBSTRING(CAST(@n_keycount as NVARCHAR(10)), 1,4) 
		--								  THEN RIGHT(CAST(@n_keycount as NVARCHAR(10)),4)
		--								  ELSE 0
		--								  END

      -- Add '0' in front when week is 1..9. so it bcome 01, 02... then take the 1st 4 characters, wwyy
      DECLARE @c_OldWeekYear NVARCHAR( 8)
      SET @c_OldWeekYear = SUBSTRING( RIGHT( '0' + CAST( @n_keycount AS NVARCHAR( 8)), 8), 1, 4)

      -- Reset serial no when week or year changed
      IF @c_weekyear <> @c_OldWeekYear
         SELECT @n_serialno = 0
      ELSE
         SELECT @n_serialno = RIGHT(CAST(@n_keycount as NVARCHAR(10)),4)

      -- SOS45074 end
	END
   ELSE
	BEGIN
		SELECT @n_serialno = ISNULL(@n_keycount,0)
	END

	SELECT @c_sku = ' '
	WHILE (1=1) AND (@n_continue = 1)
	BEGIN
		SET ROWCOUNT 1

		SELECT @c_sku = KitDetail.SKU,
				 @n_qty = KitDetail.ExpectedQty
		FROM 	 KitDetail (NOLOCK),
				 SKU (NOLOCK)
		WHERE  SKU.BUSR7 = 'Y'
		AND    KitDetail.Type = 'T'
		AND    KitDetail.KitKey = @c_kitkey
		AND    KitDetail.SKU > @c_sku
		ORDER  BY KitDetail.SKU

		IF @@ROWCOUNT = 0  
		BEGIN
			 SET ROWCOUNT 0
			 BREAK
		END

		SET ROWCOUNT 0

		SELECT @n_cnt = 1
		WHILE (@n_cnt <= @n_Qty) AND (@n_continue = 1)
	   BEGIN
			SELECT @n_serialno = @n_serialno + 1

			INSERT INTO #tempserial (SKU, SerialNo)
			SELECT @c_sku,  '92' + dbo.fnc_RTrim(@c_weekyear) +
								 RIGHT('0000' + CAST ( @n_serialno AS NVARCHAR(4)), 4)
	
		
			SELECT @n_cnt = @n_cnt + 1
		END 
	END

	IF NOT EXISTS (SELECT 1 FROM  #tempserial)
	BEGIN
		SELECT @n_continue = 4
	END

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		IF ISNULL(@n_keycount,0) = 0 
		BEGIN
	
			INSERT INTO NCounter (KeyName, KeyCount)
			SELECT 'JAMOSERIALNO', (SELECT RIGHT(MAX(SerialNo),8) FROM #tempserial)
		END
		ELSE
		BEGIN
			UPDATE NCounter Set KeyCount = (SELECT RIGHT(MAX(SerialNo),8) FROM #tempserial)
	      WHERE KeyName = 'JAMOSERIALNO'
		END 
	
		IF @@ERROR <> 0 
		BEGIN
			SELECT @n_continue = 3
			SELECT @n_err = 63501
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert / Update Into NCounter Failed. (nspGenSerialNo)"
		END
	END
	

	SELECT KitDetail.SKU,
			 SKU.Descr,
			 SKU.StdNetWgt,
			 SKU.StdCube,
			 UPC.UPC,
			 TS.SerialNo,
		    KitDetail.KitKey,
			 CtnContent = 	CASE WHEN PACK.Casecnt > 0 
										THEN CAST (PACK.Casecnt as NVARCHAR(10) ) + ' PIECES'
										WHEN Casecnt = 1
										THEN CAST (PACK.Casecnt as NVARCHAR(10) ) + ' PIECE'
										ELSE ' '
										END
			FROM 	 KitDetail (NOLOCK)
                LEFT OUTER JOIN UPC (NOLOCK) ON (KitDetail.Storerkey = UPC.Storerkey
			                                 AND 	 KitDetail.Sku  		= UPC.Sku), 
					 SKU (NOLOCK), 
                PACK (NOLOCK),
                #tempserial TS
			WHERE  KitDetail.Storerkey = SKU.Storerkey
			AND 	 KitDetail.Sku  		= SKU.Sku
			AND 	 KitDetail.Packkey  	= PACK.Packkey
			AND    KitDetail.Sku  		= TS.Sku
			AND    KitDetail.Type 		= 'T'
			AND    KitDetail.KitKey 	= @c_kitkey
			GROUP BY KitDetail.SKU,
						 SKU.Descr,
						 SKU.StdNetWgt,
						 SKU.StdCube,
						 UPC.UPC,
						 TS.SerialNo,
					    KitDetail.KitKey,
						 PACK.Casecnt

	DROP TABLE #tempserial

	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
   	execute nsp_logerror @n_err, @c_errmsg, "nspGenSerialNo"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@TRANCOUNT > @n_StartTranCnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END /* main procedure */

GO