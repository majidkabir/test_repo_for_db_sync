SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspInventoryHoldStatusRpt_01                       */
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
/* Date         Author   ver  Purposes                                  */
/* 14-09-2009   TLTING   1.1  ID field length	(tlting01)                */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspInventoryHoldStatusRpt_01] (
    @c_Facility    NVARCHAR(10),
    @d_StartDate   datetime,
    @d_EndDate     datetime,
    @c_StorerMin   NVARCHAR(10),
    @c_StorerMax   NVARCHAR(10),
    @c_SKUMin      NVARCHAR(20),
    @c_SKUMax      NVARCHAR(20),
    @c_BatchMin    NVARCHAR(10),  --Added by Shong 28/11/03 SOS#17491
    @c_BatchMax    NVARCHAR(10),
    @c_status      NVARCHAR(10)
 )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
 DECLARE @c_storerkey NVARCHAR(18),
   @c_sku       NVARCHAR(20),
 	 @c_descr     NVARCHAR(60),
   @n_Qty       int,
   @c_loc       NVARCHAR(10),
   @c_lot       NVARCHAR(10),
   @c_id        NVARCHAR(18),				--tlting01
   @c_reason    NVARCHAR(10),
   @d_ExpiryDate datetime,
   @d_ReceiptDate datetime,
   @d_DateOn      datetime,
   @c_WhoOn       NVARCHAR(18),
   @c_HoldKey     NVARCHAR(10),
   @c_BatchNo     NVARCHAR(10),  -- Added by Shong 28/11/03 SOS#17491--
	@c_PackUOM1	 NVARCHAR(10),  -- Added by MaryVong on 23-Apr-2004 (NZMM)
	@n_CaseCnt		int,
	@c_PackUOM3	 NVARCHAR(10),
	@n_QtyCases		int,
	@n_QtyEaches	int
  
   
 CREATE TABLE #RESULT 
 (
    Holdkey     NVARCHAR(10) NOT NULL,
    LOT         NVARCHAR(10) NOT NULL,
    Location    NVARCHAR(10) NULL,
    ID          NVARCHAR(18) NULL,			--tlting01
    Facility    NVARCHAR(10) NOT NULL,
    StorerKey   NVARCHAR(15) NULL,
    SKU         NVARCHAR(20) NULL,
    DESCR       NVARCHAR(60) NULL,
    Qty         int NULL,
    Reason      NVARCHAR(10) NULL,
    Expirydate  datetime NULL,
    ReceiptDate datetime NULL,
    addwho      NVARCHAR(18) NULL,
    adddate     datetime NULL,
    holdby      NVARCHAR(18) NULL,
    holddate    datetime NULL,
    BatchNo     NVARCHAR(10) NULL,
    PackUOM1	 NVARCHAR(10) NULL,  	-- Added by MaryVong on 23-Apr-2004 (NZMM)
    CaseCnt		 float NULL,
    PackUOM3	 NVARCHAR(10) NULL,
	 QtyCases	 int NULL,
	 QtyEaches	 int NULL
 )
 
 IF dbo.fnc_RTrim(@c_status) IS NULL OR dbo.fnc_RTrim(@c_Status) = '' 
 BEGIN
    DECLARE CUR1 CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT InventoryHoldKey,
              Lot,
              ID,
              Loc,
              Status,
              DateOn,
              WhoOn
       FROM   InventoryHold (NOLOCK)
       WHERE  DateOn BETWEEN @d_StartDate AND DATEADD(day, 1, @d_EndDate)
       AND    Hold = '1'
       AND   (Lot <> '' OR LOC <> '' OR ID <> '') 
 END
 ELSE
 BEGIN
    DECLARE CUR1 CURSOR  FAST_FORWARD READ_ONLY FOR
       SELECT InventoryHoldKey,
              Lot,
              ID,
              Loc,
              Status,
              DateOn,
              WhoOn
       FROM   InventoryHold (NOLOCK)
       WHERE  DateOn BETWEEN @d_StartDate AND DATEADD(day, 1, @d_EndDate)
       AND    Hold = '1'
       AND    Status = @c_Status 
       AND   (Lot <> '' OR LOC <> '' OR ID <> '') 
 END 
         
 OPEN CUR1
 FETCH NEXT FROM CUR1 INTO
    @c_HoldKey,
    @c_Lot,
    @c_id,
    @c_loc,
    @c_Reason,
    @d_DateOn,
    @c_WhoOn
 WHILE @@FETCH_STATUS <> -1
 BEGIN
    IF @c_id IS NOT NULL and @c_id <> ''
    BEGIN
       DECLARE CUR2 CURSOR  FAST_FORWARD READ_ONLY FOR
       SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.ID, 
              LOTxLOCxID.LOC, LOTxLOCxID.LOT,
              LOTxLOCxID.SKU, SKU.DESCR,
              LOTxLOCxID.Qty, LOTATTRIBUTE.LOTTABLE04,
              LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.LOTTABLE02--Added by Shong 28/11/03 SOS#17491
       FROM   LOTxLOCxID (NOLOCK),
              LOTATTRIBUTE (NOLOCK),
              SKU (NOLOCK),
              LOC (NOLOCK) 
       WHERE  LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
       AND    LOTxLOCxID.ID = @c_id
       AND    LOTxLOCxID.STORERKEY BETWEEN @c_StorerMin AND @c_StorerMax
       AND    LOTxLOCxID.SKU BETWEEN @c_SKUMin AND @c_SKUMax
       AND    LOTATTRIBUTE.LOTTABLE02 BETWEEN @c_BatchMin AND @c_BatchMax --Added by Shong 28/11/03 SOS#17491
       AND    LOTxLOCxID.StorerKey = SKU.StorerKey
       AND    LOTxLOCxID.SKU = SKU.SKU
       AND    LOTxLOCxID.Qty > 0
       AND    LOTxLOCxID.LOC = LOC.LOC
       AND    LOC.Facility = @c_Facility
    END
    ELSE IF @c_loc IS NOT NULL and @c_loc <> ''
    BEGIN
       DECLARE CUR2 CURSOR  FAST_FORWARD READ_ONLY FOR
       SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.ID, 
              LOTxLOCxID.LOC, LOTxLOCxID.LOT,
              LOTxLOCxID.SKU, SKU.DESCR,
              LOTxLOCxID.Qty, LOTATTRIBUTE.LOTTABLE04,
              LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.LOTTABLE02 --Added by Shong 28/11/03 SOS#17491
       FROM   LOTxLOCxID (NOLOCK),
             LOTATTRIBUTE (NOLOCK),
              SKU (NOLOCK)
       WHERE  LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
       AND    LOTxLOCxID.LOC = @c_loc
       AND    LOTxLOCxID.STORERKEY BETWEEN @c_StorerMin AND @c_StorerMax
       AND    LOTxLOCxID.SKU BETWEEN @c_SKUMin AND @c_SKUMax
       AND    LOTATTRIBUTE.LOTTABLE02 BETWEEN @c_BatchMin AND @c_BatchMax --Added by Shong 28/11/03 SOS#17491
       AND    LOTxLOCxID.StorerKey = SKU.StorerKey
       AND    LOTxLOCxID.SKU = SKU.SKU
       AND    LOTxLOCxID.Qty > 0
    END
    ELSE IF @c_Lot IS NOT NULL and @c_Lot <> ''
    BEGIN
       DECLARE CUR2 CURSOR  FAST_FORWARD READ_ONLY FOR
       SELECT LOTxLOCxID.StorerKey, LOTxLOCxID.ID, 
              LOTxLOCxID.LOC, LOTxLOCxID.LOT,
              LOTxLOCxID.SKU, SKU.DESCR,
              LOTxLOCxID.Qty, LOTATTRIBUTE.LOTTABLE04,
              LOTATTRIBUTE.LOTTABLE05, LOTATTRIBUTE.LOTTABLE02  --Added by Shong 28/11/03 SOS#17491
       FROM   LOTxLOCxID (NOLOCK),
              LOTATTRIBUTE (NOLOCK),
              SKU (NOLOCK)
       WHERE  LOTxLOCxID.LOT = LOTATTRIBUTE.LOT
       AND    LOTxLOCxID.LOT = @c_lot
       AND    LOTxLOCxID.STORERKEY BETWEEN @c_StorerMin AND @c_StorerMax
       AND    LOTxLOCxID.SKU BETWEEN @c_SKUMin AND @c_SKUMax
       AND    LOTATTRIBUTE.LOTTABLE02 BETWEEN @c_BatchMin AND @c_BatchMax --Added by Shong 28/11/03 SOS#17491
       AND    LOTxLOCxID.StorerKey = SKU.StorerKey
       AND    LOTxLOCxID.SKU = SKU.SKU
       AND    LOTxLOCxID.Qty > 0
    END
    OPEN CUR2
    FETCH NEXT FROM CUR2 INTO
       @c_StorerKey,
       @c_Id,
       @c_loc,
       @c_lot,
       @c_sku,
       @c_descr,
       @n_Qty,
       @d_ExpiryDate,
       @d_ReceiptDate,
       @c_BatchNo
    WHILE @@FETCH_STATUS <> -1
    BEGIN

		 -- Added by MaryVong on 23-Apr-2004 (NZMM)
       SELECT @c_PackUOM1 = PACK.PackUOM1, 
				  @n_CaseCnt = PACK.CaseCnt, 
				  @c_PackUOM3 = PACK.PackUOM3
       FROM	  PACK (NOLOCK), 
				  SKU (NOLOCK)
       WHERE  PACK.PackKey = SKU.PackKey
       AND	  SKU.Sku = @c_Sku  

		 SELECT @n_QtyCases = FLOOR (@n_Qty/@n_CaseCnt) 
		 SELECT @n_QtyEaches = @n_Qty % @n_CaseCnt    		 

       INSERT INTO #RESULT 
             ( Holdkey, LOT, ID, SKU, DESCR, Qty, Reason, Expirydate, ReceiptDate, Location,
               addwho, adddate, holdby, holddate, Facility, StorerKey, BatchNo, 
					PackUOM1, CaseCnt, PackUOM3, QtyCases, QtyEaches )
       VALUES
             ( @c_HoldKey, @c_LOT, @c_ID, @c_SKU, @c_DESCR, @n_Qty, @c_Reason, @d_Expirydate, @d_ReceiptDate, @c_LOC,
               @c_WhoOn, @d_DateOn, @c_WhoOn, @d_DateOn, @c_Facility, @c_StorerKey, @c_Batchno, 
					@c_PackUOM1, @n_CaseCnt, @c_PackUOM3, @n_QtyCases, @n_QtyEaches )
       FETCH NEXT FROM CUR2 INTO
          @c_StorerKey,
          @c_Id,
          @c_loc,
          @c_lot,
          @c_sku,
          @c_descr,
          @n_Qty,
          @d_ExpiryDate,
          @d_ReceiptDate,
          @c_BatchNo
    END -- while cur2 fetch status
    DEALLOCATE CUR2
    select @c_lot = ""
    select @c_id = ""
    select @c_loc = ""
    FETCH NEXT FROM CUR1 INTO
       @c_HoldKey,
       @c_Lot,
       @c_id,
       @c_loc,
       @c_Reason,
       @d_DateOn,
       @c_WhoOn
 END -- cur1 fetch status
 DEALLOCATE CUR1
 SELECT *, @d_StartDate, @d_EndDate  FROM #RESULT
 DROP TABLE #RESULT
 END -- Procedure

GO