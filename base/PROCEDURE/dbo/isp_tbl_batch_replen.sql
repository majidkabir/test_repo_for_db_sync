SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[isp_TBL_Batch_Replen]
	@c_facility NVARCHAR(5),
	@c_zone NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @n_rowkey INT,
			@c_lottable02 NVARCHAR(18),
			@n_replencase INT,
			@c_priority NVARCHAR(1),
			@n_casecnt INT,
			@c_storerkey NVARCHAR(18),
			@c_sku NVARCHAR(20),
			@c_pickloc NVARCHAR(10)

	CREATE TABLE #REPLEN (
		rowkey INT IDENTITY(1,1),
		storerkey NVARCHAR(18),
		sku NVARCHAR(20),
		loc NVARCHAR(10),
		availqty INT,
		minqty INT,
		maxqty INT,
		casecnt INT,
		lottable02 NVARCHAR(18)
	)

	-- retrieve candidate pick locations to be replenished
	-- lottable02 is included to distinguish AP - PRC stocks
	INSERT #REPLEN (storerkey, sku, loc, availqty, minqty, maxqty, casecnt, lottable02)
		SELECT SL.storerkey, SL.sku, SL.loc, SUM(SL.qty-SL.qtyallocated-SL.qtypicked), SL.qtylocationminimum, 
			SL.qtylocationlimit, S.innerpack, LA.lottable02
		FROM SKUxLOC SL (NOLOCK) JOIN SKU S (NOLOCK)
			ON SL.storerkey = S.storerkey
				AND SL.sku = S.sku 
		JOIN LOC L (NOLOCK) 
			ON SL.loc = L.loc
		JOIN LOTxLOCxID LLI (NOLOCK)
			ON SL.storerkey = LLI.storerkey 
				AND SL.sku = LLI.sku
				AND SL.loc = LLI.loc
		JOIN LOTATTRIBUTE LA (NOLOCK)
			ON LLI.lot = LA.lot 
      JOIN PACK P WITH (NOLOCK) ON P.PackKey = S.PackKey 
		WHERE SL.locationtype = 'CASE'
			AND L.facility = @c_facility
			AND L.putawayzone = @c_zone 
		GROUP BY SL.storerkey, SL.sku, SL.loc, SL.qtylocationminimum, SL.qtylocationlimit, 
               S.innerpack, LA.lottable02, P.CaseCnt
		HAVING SUM(SL.qty-SL.qtyallocated-SL.qtypicked) < (SL.qtylocationminimum * P.casecnt)

	IF EXISTS (SELECT 1 FROM #REPLEN)
	BEGIN -- if exists
		CREATE TABLE #RESULT (
			uccno NVARCHAR(20),
			sku NVARCHAR(20),
			putawayzone NVARCHAR(10),
			fromloc NVARCHAR(10),
			toloc NVARCHAR(10),
			logicallocation NVARCHAR(18),
			replenqty INT,
			priority NVARCHAR(1)
		)

		SELECT @n_rowkey = 0
		WHILE (1=1)
		BEGIN -- while (1=1)
			SELECT @n_rowkey = MIN(rowkey)
			FROM #REPLEN
			WHERE rowkey > @n_rowkey

			IF ISNULL(@n_rowkey, 0) = 0
				BREAK

			-- compute number of cases needed and priority
			SELECT @c_lottable02 = lottable02,
				@n_replencase = maxqty - (((casecnt * maxqty) - availqty) / casecnt),
				@c_priority = CASE
									WHEN (((casecnt * maxqty) - availqty) / casecnt) < 1 THEN '1'
								  	ELSE '2'
								  END,
				@n_casecnt = casecnt,
				@c_storerkey = storerkey,
				@c_sku = sku,
				@c_pickloc = loc
			FROM #REPLEN
			WHERE rowkey = @n_rowkey

			-- determine if stock is both AP and PRC : they have 2 pick locs
			IF (SELECT COUNT(loc)
				 FROM SKUxLOC (NOLOCK)
				 WHERE storerkey = @c_storerkey
					AND sku = @c_sku
					AND locationtype = 'CASE'
				 GROUP BY storerkey, sku) >= 2
			BEGIN
				-- suggest stock with the same lottable02				
				SET ROWCOUNT @n_replencase
				INSERT #RESULT (uccno, sku, putawayzone, fromloc, toloc, logicallocation, replenqty, priority)
					SELECT U.uccno, U.sku, L.putawayzone, U.loc, @c_pickloc, L.logicallocation, U.qty, @c_priority
					FROM UCC U (NOLOCK) JOIN LOTATTRIBUTE LA (NOLOCK)
						ON U.lot = LA.lot
							AND LA.lottable02 = @c_lottable02
					JOIN LOC L (NOLOCK)
						ON U.loc = L.loc
							AND L.status = 'OK'
					WHERE U.storerkey = @c_storerkey
						AND U.sku = @c_sku
						AND U.status BETWEEN '1' AND '2'
					ORDER BY LA.lottable05, L.logicallocation, L.loc
				SET ROWCOUNT 0
			END
			ELSE
			BEGIN
				-- suggest stock no matter what lottable02
				SET ROWCOUNT @n_replencase
				INSERT #RESULT (uccno, sku, putawayzone, fromloc, toloc, logicallocation, replenqty, priority)
					SELECT U.uccno, U.sku, L.putawayzone, U.loc, @c_pickloc, L.logicallocation, U.qty, @c_priority
					FROM UCC U (NOLOCK) JOIN LOC L (NOLOCK)
						ON U.loc = L.loc
							AND L.status = 'OK'
					WHERE U.storerkey = @c_storerkey
						AND U.sku = @c_sku
						AND U.status BETWEEN '1' AND '2'
					ORDER BY U.lot, L.logicallocation, L.loc
				SET ROWCOUNT 0
			END
		END -- while (1=1)
		-- return results
		SELECT * FROM #RESULT

		DROP TABLE #RESULT
	END -- if exists

	DROP TABLE #REPLEN	
END


GO