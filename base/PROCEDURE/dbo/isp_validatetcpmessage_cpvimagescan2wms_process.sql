SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* SP: isp_ValidateTCPMessage_CPVImageScan2WMS_Process                        */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: SG Cooper Vision image scanner will send TCPSocket message to WMS */
/*          listener, and call a SP to check format and reply to sender.      */
/*          Then it trigger QCommander call this SP to process the message    */
/*                                                                            */
/* Date         Author   Ver      Purposes                                    */
/* 2019-09-26   Ung      1.0      WMS-10026 Created                           */
/* 2019-10-24   Ung      1.1      WMS-10026 Remove SKU checking               */
/* 2019-11-04   Ung      1.2      WMS-10026 Multi SKU master lot, auto select */
/*                                SKU in OrderDetail                          */
/******************************************************************************/

CREATE PROC [dbo].[isp_ValidateTCPMessage_CPVImageScan2WMS_Process](
     @nSerialNo INT
 )
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE 
       @cDataString     NVARCHAR( MAX)
      ,@cStorerKey      NVARCHAR( 15)
      ,@cOrderKey       NVARCHAR( 10)
      ,@cSKU            NVARCHAR( 20)
      ,@nMaxRow         INT
      ,@nRowCount       INT
      ,@dExpiryDate     DATETIME
      ,@nShelfLife      INT 
      ,@nInnerPack      INT
      ,@dToday          DATETIME
      ,@cBarcode        NVARCHAR( 60)
      ,@cMasterLOT      NVARCHAR( 60)
      ,@cLottable07     NVARCHAR( 30)
      ,@cLottable08     NVARCHAR( 30)
      ,@dExternLottable04 DATETIME
      ,@cExternLotStatus  NVARCHAR(10)
      ,@nTranCount      INT
      ,@nTotal          INT
      ,@nScan           INT
      ,@nErrNo          INT
      ,@cErrMsg         NVARCHAR( 255)

   DECLARE @tSplit TABLE 
   (
      RowRef INT IDENTITY( 1, 1),
      Value  NVARCHAR( 255), 
      PRIMARY KEY CLUSTERED (RowRef)
   )

   SET @nTranCount = @@TRANCOUNT
   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT 
      @cDataString = ISNULL( RTRIM( DATA) ,''), 
      @cStorerKey = StorerKey
   FROM dbo.TCPSocket_INLog WITH (NOLOCK)
   WHERE SerialNo = @nSerialNo

   -- Parse by comma
   INSERT INTO @tSplit (Value)
   SELECT Value FROM STRING_SPLIT( @cDataString, ',')
   
   SET @nMaxRow = @@ROWCOUNT

   -- Get param value
   SELECT @cOrderKey = Value FROM @tSplit WHERE RowRef = 2

   -- Ignore SKU, due to user might mix up label (OrderKey, SKU) on stock. 
   -- OrderKey is guarantee correct. SKU can be retrieve from master LOT
   SET @cSKU = '' 
   
   -- Get order info
   DECLARE @cChkStorerKey NVARCHAR( 15)
   DECLARE @cStatus       NVARCHAR( 10)
   DECLARE @cSOStatus     NVARCHAR( 10)
   SELECT 
      @cChkStorerKey = StorerKey, 
      @cStatus = Status,
      @cSOStatus = SOStatus
   FROM Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey
   
   -- Check order valid
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 142651
      SET @cErrMsg = 
         'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
         'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Invalid order'
      
      INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Remark)
      VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cErrMsg)
      GOTO Quit
   END
   
   -- Check different storer
   IF @cChkStorerKey <> @cStorerKey
   BEGIN
      SET @nErrNo = 142652
      SET @cErrMsg = 
         'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
         'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Different storer'

      INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Remark)
      VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cErrMsg)
      GOTO Quit
   END

   -- Check status
   IF @cStatus = '5'
   BEGIN
      SET @nErrNo = 142653
      SET @cErrMsg = 
         'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
         'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Order picked'

      INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Remark)
      VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cErrMsg)
      GOTO Quit
   END

   -- Check status
   IF @cSOStatus = 'CANC'
   BEGIN
      SET @nErrNo = 142654
      SET @cErrMsg = 
         'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
         'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Order CANCEL'

      INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Remark)
      VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cErrMsg)
      GOTO Quit
   END

   BEGIN TRAN
   SAVE TRAN CPVImageScan2WMS

   -- Loop master LOT
   DECLARE @curSplit CURSOR
   SET @curSplit = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Value FROM @tSplit 
      WHERE RowRef >= 5 AND RowRef <= @nMaxRow
      ORDER BY RowRef
   OPEN @curSplit
   FETCH NEXT FROM @curSplit INTO @cBarcode
   WHILE @@FETCH_STATUS = 0
   BEGIN
      SET @cSKU = ''
      
      -- Check blank
      IF @cBarcode = ''
      BEGIN
         SET @nErrNo = 142656
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'blank master LOT'

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cErrMsg)

         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO RollbackTran
      END

      -- In future MasterLOT could > 30 chars, need to use 2 lottables field
      SET @cLottable07 = ''
      SET @cLottable08 = ''

      -- Decode to abstract master LOT
      EXEC rdt.rdt_Decode 0, 631, 'ENG', 2, 1, @cStorerKey, '', @cBarcode, 
         @cLottable07 = @cLottable07 OUTPUT, 
         @cLottable08 = @cLottable08 OUTPUT, 
         @nErrNo  = @nErrNo  OUTPUT, 
         @cErrMsg = @cErrMsg OUTPUT
      IF @nErrNo <> 0
      BEGIN
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + @cErrMsg

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Lottable07, Lottable08, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cLottable07, @cLottable08, @cErrMsg)

         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO RollbackTran
      END

      -- Check barcode format
      IF @cLottable07 = '' AND @cLottable08 = ''
      BEGIN
         SET @nErrNo = 142657
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Invalid format'

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Lottable07, Lottable08, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cLottable07, @cLottable08, @cErrMsg)

         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO RollbackTran
      END
      
      SELECT @cMasterLOT = @cLottable07 + @cLottable08
      
      -- Get master LOT info
      SELECT 
         @cSKU = SKU, 
         @cExternLotStatus = ExternLotStatus,
         @dExternLottable04 = ExternLottable04
      FROM ExternLotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ExternLOT = @cMasterLOT

      SET @nRowCount = @@ROWCOUNT

      -- Check SKU in order
      IF @nRowCount = 1
      BEGIN
         -- Check SKU in order
         IF NOT EXISTS( SELECT TOP 1 1
            FROM OrderDetail WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey
               AND StorerKey = @cStorerKey
               AND SKU = @cSKU)
         BEGIN
            SET @nErrNo = 142655
            SET @cErrMsg = 
               'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
               'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'SKU NotInOrder'

            INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Lottable07, Lottable08, Remark)
            VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cLottable07, @cLottable08, @cErrMsg)

            FETCH NEXT FROM @curSplit INTO @cBarcode
            CONTINUE
            --GOTO RollbackTran
         END
      END

      -- Check master LOT valid
      ELSE IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 142658
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Invalid master LOT'

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Lottable07, Lottable08, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cLottable07, @cLottable08, @cErrMsg)
         
         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO RollbackTran
      END

      -- Check multi SKU extern LOT
      ELSE -- IF @nRowCount > 1
      BEGIN
         SELECT 
            @cSKU = LA.SKU, 
            @cExternLotStatus = LA.ExternLotStatus,
            @dExternLottable04 = LA.ExternLottable04
         FROM ExternLotAttribute LA WITH (NOLOCK)
            JOIN OrderDetail OD WITH (NOLOCK) ON (OD.StorerKey = LA.StorerKey AND OD.SKU = LA.SKU)
         WHERE OD.OrderKey = @cOrderKey
            AND OD.StorerKey = @cStorerKey
            AND LA.ExternLOT = @cMasterLOT
         
         SET @nRowCount = @@ROWCOUNT

         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 142663
            SET @cErrMsg = 
               'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
               'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'SKU NotInOrder'

            INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Lottable07, Lottable08, Remark)
            VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cLottable07, @cLottable08, @cErrMsg)

            FETCH NEXT FROM @curSplit INTO @cBarcode
            CONTINUE
            --GOTO RollbackTran
         END
         
         ELSE IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 142664
            SET @cErrMsg = 
               'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
               'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Multi SKU LOT'

            INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Lottable07, Lottable08, Remark)
            VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cLottable07, @cLottable08, @cErrMsg)

            FETCH NEXT FROM @curSplit INTO @cBarcode
            CONTINUE
            --GOTO RollbackTran
         END
      END
      
      -- Check master LOT status
      IF @cExternLotStatus <> 'ACTIVE'
      BEGIN
         SET @nErrNo = 142659
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Inactive LOT'

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cErrMsg)

         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO RollbackTran
      END
      
      -- Get SKU info
      SELECT 
         @nShelfLife = SKU.ShelfLife, 
         @nInnerPack = Pack.InnerPack
      FROM SKU WITH (NOLOCK) 
         JOIN Pack WITH (NOLOCK) ON (SKU.PackKey = Pack.PackKey)
      WHERE SKU.StorerKey = @cStorerKey 
         AND SKU.SKU = @cSKU
      
      -- Calc expiry date
      SET @dToday = CONVERT( DATE, GETDATE())
      SET @dExpiryDate = @dExternLottable04
      IF @nShelfLife > 0
         SET @dExpiryDate = DATEADD( dd, -@nShelfLife, @dExternLottable04)

      -- Check expired stock
      IF @dExpiryDate < @dToday
      BEGIN
         SET @nErrNo = 142660
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Stock expired'

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cErrMsg)

         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO RollbackTran
      END

      -- Get scan QTY again, due to multi user
      SELECT @nScan = ISNULL( SUM( QTY), 0)
      FROM rdt.rdtCPVOrderLog WITH (NOLOCK)
      WHERE OrderKey = @cOrderKey
         AND SKU = @cSKU

      -- Get total QTY
      SELECT @nTotal = ISNULL( SUM( OD.OpenQTY), 0)
      FROM dbo.Orders O WITH (NOLOCK)
         JOIN dbo.OrderDetail OD WITH (NOLOCK) ON ( O.OrderKey = OD.OrderKey AND O.StorerKey = OD.StorerKey)
      WHERE O.OrderKey = @cOrderKey
         AND O.StorerKey = @cStorerKey
         AND OD.SKU = @cSKU

      -- Check balance
      IF @nScan + @nInnerPack > @nTotal
      BEGIN
         SET @nErrNo = 142661
         SET @cErrMsg = 
            'TCPSocket_Inlog.SerialNo=' + CAST( @nSerialNo AS NVARCHAR( 10)) + '. ' + 
            'Error=' + CAST( @nErrNo AS NVARCHAR( 6)) + ' ' + 'Fully scanned'

         INSERT INTO rdt.rdtCPVOrderLog (Mobile, OrderKey, StorerKey, SKU, Barcode, Remark)
         VALUES (0, @cOrderKey, @cStorerKey, @cSKU, @cBarcode, @cErrMsg)
         
         FETCH NEXT FROM @curSplit INTO @cBarcode
         CONTINUE
         --GOTO Quit
      END

      -- Insert log
      INSERT INTO rdt.rdtCPVOrderLog 
         (Mobile, OrderKey, StorerKey, SKU, QTY, Barcode, Lottable07, Lottable08)
      VALUES
         (0, @cOrderKey, @cStorerKey, @cSKU, @nInnerPack, @cBarcode, @cLottable07, @cLottable08)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 142662
         SET @cErrMsg = 'INS LOG Fail'
         GOTO RollbackTran
      END

      FETCH NEXT FROM @curSplit INTO @cBarcode
   END

   COMMIT TRAN CPVImageScan2WMS
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN CPVImageScan2WMS
Quit:
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN
END

GO