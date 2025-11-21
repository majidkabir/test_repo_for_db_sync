SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROCEDURE [dbo].[ispPurgeDuplicateNIKEASN] 
AS
Declare @cShipID NVARCHAR(20),
        @cExternReceiptKey NVARCHAR(20),
        @cReceiptKey       NVARCHAR(10),
        @bReceiptFinalized int, 
        @cFinalizedReceiptKey NVARCHAR(10),
        @cStorerKey NVARCHAR(15),
        @nContinue int,
        @nProcess  int  

SET NOCOUNT ON

SELECT @cExternReceiptKey = SPACE(20) 

SELECT @cExternReceiptKey = SPACE(20)
SELECT @nProcess = 0 
WHILE 1=1
BEGIN
   SET ROWCOUNT 1

   SELECT @cStorerKey = StorerKey, 
          @cExternReceiptKey = ExternReceiptKey, 
          @cShipID = Signatory
   FROM   RECEIPT (NOLOCK)
   WHERE  StorerKey IN ('NIKECN', 'NIKESMI') -- AND ExternReceiptKey = '000001681'
   AND    ExternReceiptKey > @cExternReceiptKey
   GROUP By StorerKey, ExternReceiptKey, Signatory
   HAVING COUNT(Signatory) > 1
   ORDER By ExternReceiptKey

   IF @@ROWCOUNT = 0 
      BREAK 
   
   SET ROWCOUNT 0
   
   IF dbo.fnc_RTRIM(@cExternReceiptKey) IS NOT NULL AND dbo.fnc_RTRIM(@cExternReceiptKey) <> ''
   BEGIN
      SELECT @bReceiptFinalized = 0
      SELECT @cReceiptKey = SPACE(10)
      WHILE 1=1
      BEGIN
         IF @bReceiptFinalized = 0 
         BEGIN
            SELECT @cFinalizedReceiptKey = MIN(RECEIPT.ReceiptKey)
            FROM   RECEIPT (NOLOCK)
            JOIN   RECEIPTDETAIL (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
            WHERE  RECEIPT.StorerKey IN ('NIKECN', 'NIKESMI')
            AND    RECEIPT.ExternReceiptKey = @cExternReceiptKey
            AND    RECEIPT.Signatory = @cShipID 
            AND    RECEIPTDETAIL.FinalizeFlag = 'Y' AND QtyReceived > 0
            AND    RECEIPT.StorerKey = @cStorerKey
   
            IF dbo.fnc_RTRIM(@cFinalizedReceiptKey) IS NULL OR dbo.fnc_RTRIM(@cFinalizedReceiptKey) = ''
            BEGIN
               SELECT @cFinalizedReceiptKey = MIN(RECEIPT.ReceiptKey)
               FROM   RECEIPT (NOLOCK)
               WHERE  RECEIPT.StorerKey IN ('NIKECN', 'NIKESMI')
               AND    RECEIPT.ExternReceiptKey = @cExternReceiptKey
               AND    RECEIPT.Signatory = @cShipID 
               AND    RECEIPT.StorerKey = @cStorerKey
            END
            SELECT @bReceiptFinalized = 1 
         END
   
         IF dbo.fnc_RTRIM(@bReceiptFinalized) IS NULL 
            BREAK 
   
         IF @bReceiptFinalized = 1 
         BEGIN
            SELECT @cReceiptKey = MIN(RECEIPT.ReceiptKey)
            FROM   RECEIPT (NOLOCK)
            WHERE  RECEIPT.StorerKey IN ('NIKECN', 'NIKESMI')
            AND    RECEIPT.ExternReceiptKey = @cExternReceiptKey
            AND    RECEIPT.Signatory = @cShipID 
            AND    RECEIPT.ReceiptKey <> @cFinalizedReceiptKey
            AND    RECEIPT.ReceiptKey > @cReceiptKey
            AND    RECEIPT.StorerKey = @cStorerKey
         END
   
         IF dbo.fnc_RTRIM(@cReceiptKey) IS NULL 
            BREAK
   
   
         -- Same Row
         IF (SELECT COUNT(*) FROM RECEIPTDETAIL (NOLOCK)
           WHERE  ReceiptKey = @cFinalizedReceiptKey) = (SELECT COUNT(*) FROM RECEIPTDETAIL (NOLOCK)
           WHERE  ReceiptKey = @cReceiptKey) 
         BEGIN
            IF (SELECT COUNT(*) FROM RECEIPTDETAIL (NOLOCK)
               WHERE  ReceiptKey = @cReceiptKey 
               AND FinalizeFlag = 'Y' AND QtyReceived > 0 
               AND RECEIPTDETAIL.StorerKey = @cStorerKey) = 0
            BEGIN 
               Print 'Delete Duplicate ReceiptKey: ' + @cReceiptKey + ', Original ReceiptKey = ' + dbo.fnc_RTRIM(@cFinalizedReceiptKey) + ' Shipment ID: ' + dbo.fnc_RTRIM(@cShipID) +
                  ' Nike PO No:' + dbo.fnc_RTRIM(@cExternReceiptKey) + ' StorerKey = ' + dbo.fnc_RTRIM(@cStorerKey)
   
               BEGIN TRAN
   
               SELECT @nContinue = 1
   
               INSERT INTO ARCHIVE.dbo.DuplicateASN(ReceiptKey, ExternReceiptKey, ReceiptGroup, StorerKey, ReceiptDate, 
                              POKey, CarrierKey, CarrierName, CarrierAddress1, CarrierAddress2, CarrierCity, CarrierState, 
                              CarrierZip, CarrierReference, WarehouseReference, OriginCountry, DestinationCountry, VehicleNumber, 
                              VehicleDate, PlaceOfLoading, PlaceOfDischarge, PlaceofDelivery, IncoTerms, TermsNote, ContainerKey, 
                              Signatory, PlaceofIssue, OpenQty, Status, Notes, EffectiveDate, AddDate, AddWho, EditDate, EditWho, 
                              TrafficCop, ArchiveCop, ContainerType, ContainerQty, BilledContainerQty, RECType, ASNStatus, 
                              ASNReason, Facility, MBOLKey, Appointment_No, LoadKey, xDockFlag, UserDefine01, PROCESSTYPE)
               SELECT ReceiptKey, ExternReceiptKey, ReceiptGroup, StorerKey, ReceiptDate, 
                              POKey, CarrierKey, CarrierName, CarrierAddress1, CarrierAddress2, CarrierCity, CarrierState, 
                              CarrierZip, CarrierReference, WarehouseReference, OriginCountry, DestinationCountry, VehicleNumber, 
                              VehicleDate, PlaceOfLoading, PlaceOfDischarge, PlaceofDelivery, IncoTerms, TermsNote, ContainerKey, 
                              Signatory, PlaceofIssue, OpenQty, Status, Notes, EffectiveDate, AddDate, AddWho, EditDate, EditWho, 
                              TrafficCop, ArchiveCop, ContainerType, ContainerQty, BilledContainerQty, RECType, ASNStatus, 
                              ASNReason, Facility, MBOLKey, Appointment_No, LoadKey, xDockFlag, UserDefine01, PROCESSTYPE
               FROM RECEIPT (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               IF @@ERROR <> 0 
               BEGIN
                  SELECT @nContinue = 3
               END                           
   
   
               IF @nContinue = 1
               BEGIN
                  INSERT INTO  ARCHIVE.dbo.DuplicateASNDet(ReceiptKey, ReceiptLineNumber,  ExternReceiptKey,  ExternLineNo,  
                                       StorerKey,  POKey,  Sku,  AltSku,  Id,  Status,  DateReceived,  QtyExpected,  QtyAdjusted,  
                                       QtyReceived,  UOM,  PackKey,  VesselKey,  VoyageKey,  XdockKey,  ContainerKey,  ToLoc,  ToLot,  
                                       ToId,  ConditionCode,  Lottable01,  Lottable02,  Lottable03,  Lottable04,  Lottable05,  CaseCnt,  
                                       InnerPack,  Pallet,  Cube,  GrossWgt,  NetWgt,  OtherUnit1,  OtherUnit2,  UnitPrice,  ExtendedPrice,  
                                       EffectiveDate,  AddDate,  AddWho,  EditDate,  EditWho,  TrafficCop,  ArchiveCop,  TariffKey,  
                                       FreeGoodQtyExpected,  FreeGoodQtyReceived,  SubReasonCode,  FinalizeFlag,  DuplicateFrom,  
                                       BeforeReceivedQty,  PutawayLoc,  ExportStatus,  SplitPalletFlag,  POLineNumber,  LoadKey,  
                                       ExternPoKey)
                  SELECT ReceiptKey, ReceiptLineNumber,  ExternReceiptKey,  ExternLineNo,  
                        StorerKey,  POKey,  Sku,  AltSku,  Id,  Status,  DateReceived,  QtyExpected,  QtyAdjusted,  
                        QtyReceived,  UOM,  PackKey,  VesselKey,  VoyageKey,  XdockKey,  ContainerKey,  ToLoc,  ToLot,  
                        ToId,  ConditionCode,  Lottable01,  Lottable02,  Lottable03,  Lottable04,  Lottable05,  CaseCnt,  
                        InnerPack,  Pallet,  Cube,  GrossWgt,  NetWgt,  OtherUnit1,  OtherUnit2,  UnitPrice,  ExtendedPrice,  
                        EffectiveDate,  AddDate,  AddWho,  EditDate,  EditWho,  TrafficCop,  ArchiveCop,  TariffKey,  
                        FreeGoodQtyExpected,  FreeGoodQtyReceived,  SubReasonCode,  FinalizeFlag,  DuplicateFrom,  
                        BeforeReceivedQty,  PutawayLoc,  ExportStatus,  SplitPalletFlag,  POLineNumber,  LoadKey,  
                        ExternPoKey
                  FROM RECEIPTDETAIL (NOLOCK)
                  WHERE ReceiptKey = @cReceiptKey 
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @nContinue = 3
                  END                           
               END
   
               IF @nContinue = 1
               BEGIN
                  DELETE Receipt
                  WHERE  ReceiptKey = @cReceiptKey
                  IF @@ERROR <> 0 
                  BEGIN
                     SELECT @nContinue = 3
                  END                           
               END 
   
               IF @nContinue = 1
                  COMMIT TRAN
               ELSE
                  ROLLBACK TRAN

               SELECT @nProcess = 1
           END
        END
      END -- while loop 1
      IF @nProcess = 1
         BREAK 
   END -- if not null 
END

GO