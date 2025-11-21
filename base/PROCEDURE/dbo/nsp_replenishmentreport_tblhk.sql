SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_ReplenishmentReport_TBLHK                		*/
/* Creation Date:  24-Apr-2003                                          */
/* Copyright: IDS                                                       */
/* Written by:  ONGGB                                                   */
/*                                                                      */
/* Purpose:  Pick Summary Report														*/
/*                                                                      */
/* Input Parameters:  @c_wavekey  - (WaveKey)                         	*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  r_replenishment_report_tblhk                             */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver   Purposes                                */
/* 18-Apr2003   WANYT           FBR10229 TBL Total Short Picked Report  */
/* 05-May-2003  YokeBeen        (SOS#10229) - (YokeBeen01)              */
/* 09-May-2003  YokeBeen        (SOS#11114) - (YokeBeen02)              */
/* 02-Jun-2003  YokeBeen        (SOS#11538) - (YokeBeen03)              */
/* 03-Jun-2003  YokeBeen        (SOS#11569) - (YokeBeen04)              */
/*                              - Changed all the Temp table to #Temp   */
/*                                and moved the Drop Table to the bottom*/
/*                                and Select Statement in the BEGIN and */
/*                                END                                   */
/*                              - Changed from OR to AND                */
/* 10-May-2006  ONG		  1.1   SOS49890 - Include (NOLOCK)					*/
/************************************************************************/

CREATE PROC [dbo].[nsp_ReplenishmentReport_TBLHK] (@c_wavekey NVARCHAR(10))
 AS
 BEGIN
    SET NOCOUNT ON
    DECLARE	@n_continue	    int,
				@c_errmsg 	    NVARCHAR(255),
				@b_success	    int,
				@n_err	  	    int,
		-- (YokeBeen01) - Start
				@n_totalrow		 int,
				@n_rowcount		 int,
				@n_linecount	 int,
				@n_pagelinecnt	 int,
				@c_storerkey	 NVARCHAR(10),
				@n_SeqNum		 int,
				@c_ReplenishmentType NVARCHAR(10),
				@c_PutawayZone	 NVARCHAR(10),
				@c_Facility		 NVARCHAR(5),
				@c_ReplenishmentType_last NVARCHAR(10),
				@c_PutawayZone_last		 NVARCHAR(10),
				@c_Facility_last			 NVARCHAR(5)


		CREATE TABLE #Temp_Rep1 (
			[STORERKEY] [CHAR] (15) NULL,
			[WaveKey] [CHAR] (10) NULL,		-- (YokeBeen02)
-- ONG BEGIN
-- 			[SKU] [CHAR] (20) NULL,
			[Material] [CHAR] (15) NULL,
			[Quality] [CHAR] (1) NULL,
			[Size] [CHAR] (5) NULL,
-- ONG END
			[SkuDescr] [CHAR] (60) NULL,
			[LOT] [CHAR] (10) NULL,
			[LOC] [CHAR] (10) NULL,
			[ID] [CHAR] (18) NULL,
			[ToLoc] [CHAR] (10) NULL,
			[LocAisle] [CHAR] (10) NULL,
			[PickFace] [CHAR] (10) NULL,
			[RecommendedQty] [INT] NULL,
			[FromLocQtyOnHand] [INT] NULL,
			[Lottable02] [CHAR] (18) NULL,
			[Facility] [CHAR] (5) NULL,
			[PutawayZone] [CHAR] (10) NULL,
			[ReplenishmentType] [CHAR] (10) NULL,
			[Lottable02Label] [CHAR] (20) NULL,
			[Remark] [CHAR] (25) NULL,
			[SeqNum] [INT] NULL,
			[RowBreak] [CHAR] (1) NULL,
			[Logicallocation] [CHAR] (18) NULL ) 		-- ONG
		-- (YokeBeen01) - End


       SELECT PICKDETAIL.STORERKEY,
			WAVEDETAIL.WaveKey AS WaveKey,		-- (YokeBeen02)
-- ONG BEGIN
-- 	      LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,1,8))) + '-' +
-- 	      LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,9,3))) + '-' +
-- 	      LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,12,3))) + '-' +
-- 	      LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,15,1))) + '-' +
-- 			LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,16,4))) AS SKU,		-- (YokeBeen01)
		 ISNULL( REPLACE( RTRIM(Substring(SKU.SKU, 1 ,14)), '-', ''), '' ) As Material,
		 ISNULL( REPLACE( RTRIM(Substring(SKU.SKU, 15, 1)), '-', ''), '') AS Quality,
		 ISNULL( REPLACE( LTRIM(Substring(SKU.SKU, 16, 5)), '-', '') ,'') As Size,
-- 			SKU.SKU AS Sku,
-- ONG  END
	      ISNULL(SKU.Descr,'') AS SkuDescr,
	      PICKDETAIL.LOT,
	      PICKDETAIL.LOC,
	      PICKDETAIL.ID,
         'FPA' AS ToLoc,
			PickFaceList.LocAisle AS LocAisle,		-- (YokeBeen01)
			PickFaceList.Loc AS PickFace,				-- (YokeBeen01)
	      SUM(PICKDETAIL.Qty) AS RecommendedQty,
         (SELECT (LotxLocxid.Qty - LotxLocxid.QtyPicked)
				FROM  LOTxLOCxID (NOLOCK)
				WHERE PICKDETAIL.Lot = LOTxLOCxID.Lot
				AND PICKDETAIL.Loc = LOTxLOCxID.Loc
				AND PICKDETAIL.Id = LOTxLOCxID.Id) AS FromLocQtyOnHand,
	      LOTATTRIBUTE.Lottable02,
	      LOC.Facility,
	      LOC.PutawayZone,
-- 	      CASE WHEN PICKDETAIL.ID <> '' AND SUM(PICKDETAIL.Qty) = ( SELECT LotxLocxid.Qty
-- 									FROM  LOTxLOCxID (NOLOCK)
-- 									WHERE PICKDETAIL.Lot = LOTxLOCxID.Lot
-- 									AND PICKDETAIL.Loc = LOTxLOCxID.Loc
-- 									AND PICKDETAIL.Id = LOTxLOCxID.Id ) THEN 'Pallet'
-- 				  WHEN PICKDETAIL.ID = '' AND SUM(PICKDETAIL.Qty) >= PACK.Pallet THEN 'Pallet'
-- 				  ELSE 'Case'
-- 				  END ReplenishmentType,
			ReplenishmentType =  '',
	      SKU.Lottable02Label,
	      '_________________________' AS Remark,
	-- (YokeBeen01) - Start
			RowBreak = '',
			LOC.Logicallocation 				-- ONG
	INTO #Temp_Rep
	-- (YokeBeen01) - End
	FROM PICKDETAIL (NOLOCK)
-- 	     JOIN ORDERS (NOLOCK)
-- 				 ON PICKDETAIL.Orderkey = ORDERS.Orderkey
-- 			AND ORDERS.UserDefine08 = 'Y'  // doesn't matter as it has been filtered during build wave
	     JOIN WAVEDETAIL (NOLOCK) ON (PICKDETAIL.Orderkey = WAVEDETAIL.Orderkey)   	-- ONG
        JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
	     JOIN SKU (NOLOCK) ON (PICKDETAIL.Storerkey = SKU.Storerkey AND PICKDETAIL.Sku = SKU.Sku)
	     JOIN SKUxLOC (NOLOCK) ON (PICKDETAIL.Loc = SKUxLOC.Loc AND PICKDETAIL.Storerkey = SKUxLOC.Storerkey
										AND PICKDETAIL.Sku = SKUxLOC.Sku)
	     JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.Loc)
        JOIN PACK (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
			-- (YokeBeen01) - Start
		  LEFT OUTER JOIN (SELECT SKUxLOC.Storerkey, SKUxLOC.Sku, SKUxLOC.Loc, LOC.LocAisle FROM SKUxLOC (NOLOCK)
					 JOIN LOC (NOLOCK) ON (SKUxLOC.Loc = LOC.Loc)
					WHERE (SKUxLOC.LocationType = 'CASE' OR SKUxLOC.LocationType = 'PICK')) PickFaceList ON
				 (SKU.Storerkey = PickFaceList.StorerKey AND SKU.Sku = PickFaceList.Sku)
			-- (YokeBeen01) - End
	WHERE (PICKDETAIL.Status < '5')
   AND   (PICKDETAIL.PickMethod = '8' OR PICKDETAIL.PickMethod = '')
	AND   (SKUxLOC.LocationType <> 'PICK' AND SKUxLOC.LocationType <> 'CASE')	-- (YokeBeen04)
	AND   (WAVEDETAIL.Wavekey = @c_wavekey)
	GROUP BY PICKDETAIL.STORERKEY,
			WAVEDETAIL.WaveKey,			-- (YokeBeen02)
-- ONG BEGIN
-- 			LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,1,8))) + '-' +
-- 			LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,9,3))) + '-' +
-- 			LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,12,3))) + '-' +
-- 			LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,15,1))) + '-' +
-- 			LTRIM(RTRIM(SUBSTRING(SKU.BUSR1,16,4))),		-- (YokeBeen01)
		 ISNULL( REPLACE( RTRIM(Substring(SKU.SKU, 1 ,14)), '-', ''), '' ) ,
		 ISNULL( REPLACE( RTRIM(Substring(SKU.SKU, 15, 1)), '-', ''), '') ,
		 ISNULL( REPLACE( LTRIM(Substring(SKU.SKU, 16, 5)), '-', '') ,'') ,
-- 			SKU.SKU,
-- ONG  END
			ISNULL(SKU.Descr,''),
			PICKDETAIL.LOT,
			PICKDETAIL.LOC,
			PICKDETAIL.ID,
			PickFaceList.LocAisle,		-- (YokeBeen01)
			PickFaceList.Loc,				-- (YokeBeen01)
			LOTATTRIBUTE.Lottable02,
			LOC.Facility,
			LOC.PutawayZone,
			LOC.Logicallocation,			-- ONG
			PACK.Pallet,
			SKU.Lottable02Label
	-- (YokeBeen01) - Start
	ORDER BY LOC.Facility,
			WAVEDETAIL.WaveKey,			-- (YokeBeen02)
			LOC.PutawayZone,
			ReplenishmentType,
			LOC.Logicallocation,
	      PICKDETAIL.LOC,
			PICKDETAIL.STORERKEY,
-- ONG BEGIN
		 ISNULL( REPLACE( RTRIM(Substring(SKU.SKU, 1 ,14)), '-', ''), '' ) ,
		 ISNULL( REPLACE( RTRIM(Substring(SKU.SKU, 15, 1)), '-', ''), '') ,
		 ISNULL( REPLACE( LTRIM(Substring(SKU.SKU, 16, 5)), '-', '') ,'')
-- ONG END
	-- (YokeBeen01) - End
END


-- (YokeBeen01) - Start
-- To separate the records in every 5 lines for ease view.
SELECT @n_totalrow = @@ROWCOUNT

SET NOCOUNT ON

IF @n_totalrow > 0
BEGIN
    SELECT STORERKEY, WaveKey, Material, Quality, Size, SkuDescr, LOT, LOC, ID, 				-- ONG
			ToLoc, LocAisle, PickFace, RecommendedQty,
			FromLocQtyOnHand, Lottable02, Facility, PutawayZone, ReplenishmentType, Lottable02Label, Remark,
			IDENTITY(INT, 1, 1) AS SeqNum,
			RowBreak
	INTO #Temp_Rep2
	FROM #Temp_Rep (NOLOCK)
	ORDER BY Facility, WaveKey, PutawayZone, ReplenishmentType, Logicallocation, Loc, Storerkey, Material, Quality, Size

	SELECT @n_rowcount = 1
	SELECT @n_linecount = 0
	SELECT @n_pagelinecnt = 0
	SELECT @n_SeqNum = 0
	SELECT @c_ReplenishmentType_last = ''
	SELECT @c_PutawayZone_last = ''
	SELECT @c_Facility_last = ''
	SELECT @c_storerkey = MIN(StorerKey) FROM #Temp_Rep2

	WHILE (@n_rowcount <= @n_totalrow)
	BEGIN
		SELECT @n_SeqNum = MIN(SeqNum)
		  FROM #Temp_Rep2 (NOLOCK)
		 WHERE SeqNum > @n_SeqNum

		SELECT @c_ReplenishmentType = ReplenishmentType,
				 @c_PutawayZone = PutawayZone,
				 @c_Facility = Facility
		  FROM #Temp_Rep2 (NOLOCK)
		 WHERE SeqNum = @n_SeqNum

		-- Checking for the Page Break on Data Window.
		-- Lines setting for the Page length - max 29 lines.
		IF (@c_Facility <> @c_Facility_last) OR (@c_PutawayZone <> @c_PutawayZone_last)
			OR (@c_ReplenishmentType <> @c_ReplenishmentType_last) OR (@n_pagelinecnt >= 29)
			BEGIN
				SELECT @n_linecount = 0
				SELECT @n_pagelinecnt = 0
			END

		-- Separate line after 5 records.
		IF (@n_linecount < 5)
			BEGIN
				INSERT INTO #Temp_Rep1 (STORERKEY, WaveKey, Material, Quality, Size, SkuDescr, LOT, LOC, ID, -- ONG
												ToLoc, LocAisle, PickFace, RecommendedQty, FromLocQtyOnHand, Lottable02,
												Facility, PutawayZone, ReplenishmentType,
												Lottable02Label, Remark, SeqNum, RowBreak)
				(SELECT STORERKEY, WaveKey, Material, Quality, Size, SkuDescr, LOT, LOC, ID, 		-- ONG
							ToLoc, LocAisle, PickFace, RecommendedQty, FromLocQtyOnHand, Lottable02,
							Facility, PutawayZone, ReplenishmentType,
							Lottable02Label, Remark, SeqNum, RowBreak FROM #Temp_Rep2 WHERE SeqNum = @n_rowcount)
				UPDATE #Temp_Rep1 SET RowBreak = 'D' WHERE SeqNum = @n_SeqNum

				SELECT @n_linecount = @n_linecount + 1
				SELECT @n_rowcount = @n_rowcount + 1
			END
		ELSE
			BEGIN
				INSERT INTO #Temp_Rep1 (STORERKEY, WaveKey, Material, Quality, Size, SkuDescr, LOT, LOC, ID, -- ONG
												ToLoc, LocAisle, PickFace, Lottable02, Facility, PutawayZone, ReplenishmentType,
												Lottable02Label, SeqNum, RowBreak)
				(SELECT STORERKEY, WaveKey, Material, Quality, Size, SkuDescr, LOT, LOC, ID, -- ONG
							ToLoc, LocAisle, PickFace, Lottable02, Facility, PutawayZone, ReplenishmentType,
							Lottable02Label, SeqNum, 'B'
					FROM #Temp_Rep2 WHERE SeqNum = @n_rowcount - 1)

				SELECT @n_linecount = 0
				SELECT @n_SeqNum = @n_SeqNum - 1
			END
		-- End checking @n_linecount

		-- Initial previous values
		SELECT @c_ReplenishmentType_last = @c_ReplenishmentType
		SELECT @c_PutawayZone_last = @c_PutawayZone
		SELECT @c_Facility_last = @c_Facility
		SELECT @n_pagelinecnt = @n_pagelinecnt + 1

	END -- End WHILE - End Looping @n_totalrow

	SELECT * FROM #Temp_Rep1
	ORDER BY SeqNum, Facility, WaveKey, PutawayZone, ReplenishmentType, Loc, Storerkey, Material, Quality, Size 	-- ONG
	DROP TABLE #Temp_Rep
	DROP TABLE #Temp_Rep1
	DROP TABLE #Temp_Rep2
END
-- (YokeBeen01) - End

GO