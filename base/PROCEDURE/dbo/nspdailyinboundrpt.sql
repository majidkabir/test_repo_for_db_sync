SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspDailyInboundRpt                                 */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[nspDailyInboundRpt] (
@StorerKey	        NVARCHAR(15),
@DateMin	        NVARCHAR(10),
@DateMax	        NVARCHAR(10)
) AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE	@ReceiptDate		DateTime,
   @Sku		 NVARCHAR(20),
   @CaseCnt		Int,
   @ProdCat	 NVARCHAR(10),
   @STDCUBE		Float,
   @ProdQty		Int,
   @Day		 NVARCHAR(3),
   @ShipMode	 NVARCHAR(20),
   @ShipMode_s	 NVARCHAR(20),
   @preDocRef	 NVARCHAR(18),
   @DocRef		 NVARCHAR(18),
   @ETA_TAT	 NVARCHAR(10),
   @ETA_Port	 NVARCHAR(18),
   @Doc_Rel	 NVARCHAR(20),
   @FW			Int,
   @APP			Int,
   @BSSA			Int,
   @EQ			Int,
   @ACC			Int,
   @TotalCase		Int,
   @CBM		 NVARCHAR(10),
   @TotalQty		Int,
   @ReceiptNumber	 NVARCHAR(10),
   @Remarks	 NVARCHAR(30),
   @Ops_staff	 NVARCHAR(20),
   @Hours		 NVARCHAR(5)
   SELECT @TotalQty = 0, @FW = 0, @APP = 0, @BSSA = 0, @EQ = 0, @CBM = '0', @ACC = 0
   CREATE TABLE #RESULT
   (Week		 NVARCHAR(10) NULL,
   ReceiptDate		DateTime NULL,
   Day		 NVARCHAR(3) NULL,
   ShipMode	 NVARCHAR(20) NULL,
   DocRef		 NVARCHAR(30) NULL,
   ETA_TAT	 NVARCHAR(10) NULL,
   ETA_Port	 NVARCHAR(18) NULL,
   Doc_Rel	 NVARCHAR(20) NULL,
   FW			Int NULL,
   APP			Int NULL,
   BSSA			Int NULL,
   EQ			Int NULL,
   ACC			Int NULL,
   TotalCase		Int NULL,
   CBM		 NVARCHAR(10) NULL,
   TotalQty		Int NULL,
   ReceiptNumber	 NVARCHAR(10) NULL,
   Remarks	 NVARCHAR(30) NULL,
   Ops_staff	 NVARCHAR(20) NULL,
   Hours		 NVARCHAR(5) NULL )
   DECLARE CUR_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT Distinct convert(char(10), Receiptdate, 121) As Receiptdate
   FROM Receipt (nolock)
   WHERE Receipt.StorerKey = @StorerKey
   AND Receipt.ReceiptDate >= @DateMin AND Receipt.ReceiptDate < DATEADD(dd, 1, @DateMax)
   and receipt.processtype in ('L','I') and receipt.status = '9'
   ORDER BY Receiptdate
   OPEN CUR_1
   FETCH NEXT FROM CUR_1 INTO @ReceiptDate

   WHILE (@@fetch_status <> -1)
   BEGIN
      /*  1. Get the day of week */
      SELECT @Day = case datepart(dw, @ReceiptDate)
      When 1 Then 'SUN'
      When 2 Then 'MON'
      When 3 Then 'TUE'
      When 4 Then 'WED'
      When 5 Then 'THU'
      When 6 Then 'FRI'
      When 7 Then 'SAT'
   End
   DECLARE Container_Cur CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT Distinct Containertype
   FROM Receipt (nolock)
   WHERE Receipt.StorerKey = @StorerKey
   AND Receipt.ReceiptDate >= @ReceiptDate AND Receipt.ReceiptDate < DATEADD(dd, 1, @ReceiptDate)
   and receipt.processtype in ('L','I') and receipt.status = '9'
   ORDER BY Containertype

   OPEN Container_Cur
   FETCH NEXT FROM Container_Cur INTO @ShipMode

   WHILE (@@fetch_status <> -1)
   BEGIN
      SELECT @ShipMode_S = Short FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'CONTAINERT'
      AND CODE = @ShipMode
      DECLARE DOCREF_Cur CURSOR FAST_FORWARD READ_ONLY
      FOR
      --???SELECT WarehouseReference, Receiptkey, Placeofloading, Vehicledate, SUBSTRING(Containerkey, 1, 5)
      SELECT WarehouseReference, Receiptkey, Placeofloading, Vehicledate, substring(ContainerKey,1,3)
      FROM Receipt (nolock)
      WHERE Receipt.StorerKey = @StorerKey
      AND Receipt.ReceiptDate >= @ReceiptDate AND Receipt.ReceiptDate < DATEADD(dd, 1, @ReceiptDate)
      AND ContainerType = @ShipMode
      and receipt.processtype in ('L','I') and receipt.status = '9'
      ORDER BY WarehouseReference, ReceiptKey

      OPEN DOCREF_Cur
      FETCH NEXT FROM DOCREF_Cur INTO @DocRef, @ReceiptNumber, @Doc_Rel, @ETA_Port, @ETA_TAT

      WHILE (@@fetch_status <> -1)
      BEGIN
         select @cbm = substring(containerkey,5,10)
         from receipt (nolock) where receiptkey = @ReceiptNumber
         DECLARE Sku_Cur CURSOR FAST_FORWARD READ_ONLY
         FOR
         SELECT Distinct Sku
         FROM Receiptdetail (nolock), Receipt (nolock)
         WHERE Receiptdetail.Receiptkey = Receipt.ReceiptKey
         AND Receipt.StorerKey = @StorerKey
         AND Receipt.ReceiptDate >= @ReceiptDate AND Receipt.ReceiptDate < DATEADD(dd, 1, @ReceiptDate)
         AND Receipt.ContainerType = @Shipmode
         AND Receipt.Warehousereference = @DocRef
         AND Receipt.ReceiptKey = @ReceiptNumber
         ORDER BY SKU

         OPEN Sku_Cur
         FETCH NEXT FROM Sku_Cur INTO @Sku

         WHILE (@@fetch_status <> -1)
         BEGIN
            -- 19022002 change field from containerkey to otherunit1		SELECT @ProdQty = Sum(QtyReceived), @CaseCnt = Sum(cast(rd.containerkey as integer))
            SELECT @ProdQty = Sum(QtyReceived), @CaseCnt = Sum(rd.otherunit1)
            FROM ReceiptDetail RD (nolock), Receipt RH (nolock)
            WHERE RD.ReceiptKey = RH.ReceiptKey
            AND RD.Storerkey = @StorerKey
            AND RD.Sku = @Sku
            AND RH.ReceiptDate >= @ReceiptDate AND RH.ReceiptDate < DATEADD(dd, 1, @ReceiptDate)
            AND RH.ContainerType = @Shipmode
            AND RH.Warehousereference = @DocRef
            --										AND RH.ReceiptKey = @ReceiptNumber
            GROUP By Sku
            IF @ProdQty >= 0
            Begin
               SELECT @ProdQty = @ProdQty
            End
         Else
            Begin
               SELECT @ProdQty = 0
            End
            /*									SELECT @Casecnt = Pack.CaseCnt
            FROM SKU (nolock), Pack (nolock)
            WHERE Pack.Packkey = Sku.Packkey
            AND Sku.Storerkey = @Storerkey
            AND Sku.Sku = @Sku
            */
            IF @Casecnt > 0
            Begin
               SELECT @Casecnt = @Casecnt
            End
         Else
            Begin
               SELECT @Casecnt = 0
            End

            select @prodCat = busr5 from sku (nolock)
            where storerkey = @storerkey and sku = @sku
            if @prodcat = 'FOOTWEAR'
            begin
               --										select @FW = @FW + Floor(@ProdQty/@Casecnt)
               select @FW = @FW + @CaseCnt
            end
            if @prodcat = 'APPAREL'
            begin
               --										select @APP = @APP + Floor(@ProdQty/@Casecnt)
               select @APP = @APP + @CaseCnt
            end
            if @prodcat = 'EQUIP'
            begin
               --										select @EQ = @EQ + Floor(@ProdQty/@Casecnt)
               select @EQ = @EQ + @CaseCnt
            end
            if @prodcat = 'ACCESSORY'
            begin
               --										select @ACC = @ACC + Floor(@ProdQty/@Casecnt)
               select @ACC = @ACC + @CaseCnt
            end
            if @prodcat = 'BSSA'
            begin
               --										select @BSSA = @BSSA + Floor(@ProdQty/@Casecnt)
               select @BSSA = @BSSA + @CaseCnt
            end

            SELECT @TotalQty = @TotalQty + @ProdQty
            FETCH NEXT FROM Sku_Cur INTO @Sku
         END  /* cursor loop */

         CLOSE      Sku_Cur
         DEALLOCATE Sku_Cur
         SELECT @TotalCase = @FW + @APP + @BSSA + @EQ + @ACC

         if @predocref = @docref
         begin
            INSERT INTO #Result
            (ReceiptDate, Day, ShipMode, DocRef, FW, APP,
            BSSA, EQ, ACC, TotalCase, CBM, TotalQty, ReceiptNumber,
            ETA_TAT, ETA_Port, Doc_Rel)
            VALUES
            (Null, Null, Null, Null, @FW, @APP,
            @BSSA, @EQ, @ACC, @TotalCase, Null, @TotalQty, @ReceiptNumber,
            Null, Null, @Doc_Rel)
         end
      else
         begin
            INSERT INTO #Result
            (ReceiptDate, Day, ShipMode, DocRef, FW, APP,
            BSSA, EQ, ACC, TotalCase, CBM, TotalQty, ReceiptNumber,
            ETA_TAT, ETA_Port, Doc_Rel)
            VALUES
            (@ReceiptDate, @Day, @ShipMode_s, @DocRef, @FW, @APP,
            @BSSA, @EQ, @ACC, @TotalCase, @CBM, @TotalQty, @ReceiptNumber,
            @ETA_TAT, @ETA_Port, @Doc_Rel)
            select @predocref = @docref
         end
         SELECT @TotalQty = 0, @FW = 0, @APP = 0, @BSSA = 0, @EQ = 0, @CBM = '0', @ACC = 0
         FETCH NEXT FROM DOCREF_Cur INTO @DocRef, @ReceiptNumber, @Doc_Rel, @ETA_Port, @ETA_TAT
      END  /* cursor loop */

      CLOSE      DOCREF_Cur
      DEALLOCATE DOCREF_Cur
      SELECT @ShipMode_S = NULL
      FETCH NEXT FROM Container_Cur INTO @ShipMode
   END  /* cursor loop */

   CLOSE      Container_Cur
   DEALLOCATE Container_Cur
   FETCH NEXT FROM CUR_1 INTO @ReceiptDate
END  /* cursor loop */

CLOSE      CUR_1
DEALLOCATE CUR_1
SELECT Week, ReceiptDate, Day, ShipMode, DocRef, ETA_TAT, ETA_Port, Doc_Rel, FW, APP,
BSSA, EQ, ACC, TotalCase, CBM, TotalQty, ReceiptNumber, Remarks, Ops_staff, Hours
FROM #RESULT
--ORDER BY ReceiptDate, ShipMode, DocRef, ReceiptNumber
DROP TABLE #RESULT
END


GO