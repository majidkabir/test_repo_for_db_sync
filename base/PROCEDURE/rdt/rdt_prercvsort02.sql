SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************************/
/* Store procedure: rdt_PreRcvSort02                                                   */
/*                                                                                     */
/* Purpose: Show carton position                                                       */
/*                                                                                     */
/* Called from: rdtfnc_PreReceiveSort2                                                 */
/*                                                                                     */
/* Modifications log:                                                                  */
/*                                                                                     */
/* Date        Rev  Author     Purposes                                                */
/* 28-Dec-2017 1.0  James      WMS3653 - Created                                       */
/* 07-Aug-2019 1.1  James      WMS10101 - Add show sku category (james01)              */
/* 10-Oct-2021 1.2  James      WMS-16337 - Display QC into Position (james02)          */
/***************************************************************************************/

CREATE PROC [RDT].[rdt_PreRcvSort02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cUCCNo           NVARCHAR( 20),  
   @cPosition01      NVARCHAR( 20)  OUTPUT,   
   @cPosition02      NVARCHAR( 20)  OUTPUT,   
   @cPosition03      NVARCHAR( 20)  OUTPUT,   
   @cPosition04      NVARCHAR( 20)  OUTPUT,   
   @cPosition05      NVARCHAR( 20)  OUTPUT,   
   @cPosition06      NVARCHAR( 20)  OUTPUT,   
   @cPosition07      NVARCHAR( 20)  OUTPUT,   
   @cPosition08      NVARCHAR( 20)  OUTPUT,   
   @cPosition09      NVARCHAR( 20)  OUTPUT,   
   @cPosition10      NVARCHAR( 20)  OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 20)  OUTPUT 
)
AS
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE 
      @cUCC_Facility NVARCHAR( 5),
      @cUCC_SKU      NVARCHAR( 20),
      @cLOC          NVARCHAR( 10), 
      @cLocType      NVARCHAR( 10), 
      @cReceiptKey   NVARCHAR( 10), 
      @cPOKey        NVARCHAR( 10), 
      @cOtherReference  NVARCHAR( 18),
      @cType         NVARCHAR( 20),
      @cPosition     NVARCHAR( 20),
      @cUserName     NVARCHAR( 18),
      @nTranCount    INT,
      @nTTL_CtnCount INT,
      @nRowref       INT,
      @nReleaseLOC   INT,
      @nMaxAllowedCtnPerPallet   INT,
      @nUCCMultiSKU  INT,
      @nSafe_Level   INT,
      @nUCC_Qty      INT,
      @nStockOnHand  INT,
      @nSortedQty    INT,
      @nIsQC         INT,
      @cLottable12   NVARCHAR( 30)

   DECLARE  @cErrMsg1    NVARCHAR( 20), 
            @cErrMsg2    NVARCHAR( 20),
            @cErrMsg3    NVARCHAR( 20), 
            @cErrMsg4    NVARCHAR( 20),
            @cErrMsg5    NVARCHAR( 20)

   DECLARE @cSKUCategory   NVARCHAR( 30)

   SET @cReceiptKey = @cParam1
   SET @nUCCMultiSKU = 0
   SET @cPosition = ''

   SET @nTranCount = @@TRANCOUNT

   BEGIN TRAN
   SAVE TRAN rdt_PreRcvSort02

   SELECT @cUserName = UserName FROM RDT.RDTMobRec WITH (NOLOCK) WHERE MOBILE = @nMobile

   -- If ucc rescan, just need to retrieve last scanned position and then update back the status [1] (just scanned)
   IF EXISTS ( SELECT 1 FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   ReceiptKey = @cReceiptKey
               AND   UCCNo = @cUCCNo
               AND   [Status] < '9' )
   BEGIN
      SELECT @cPosition = Loc, @cType = UDF02
      FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   UCCNo = @cUCCNo
      AND   [Status] < '9' 
      ORDER BY 1

      UPDATE [RDT].[rdtPreReceiveSort2Log] WITH (ROWLOCK) SET 
         [Status] = '1',
         EditWho = @cUserName,
         EditDate = GETDATE()
      WHERE StorerKey = @cStorerKey
      AND   ReceiptKey = @cReceiptKey
      AND   UCCNo = @cUCCNo
      AND   [Status] < '9'

      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 118451
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PreRcv Err
         SET @cPosition01 = ''
         GOTO RollBackTran
      END

      GOTO Display
   END

   SELECT TOP 1 @cPOKey = POKey
   FROM dbo.PODetail PODtl WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   UserDefine01 = @cUCCNo
   AND   EXISTS ( SELECT 1 FROM dbo.ReceiptDetail RD WITH (NOLOCK) 
                  WHERE PODtl.POKey = RD.POKey 
                  AND   ReceiptKey = @cReceiptKey 
                  AND   StorerKey = @cStorerKey)

   SELECT @cOtherReference = OtherReference
   FROM dbo.PO WITH (NOLOCK)
   WHERE POKey = @cPOKey

   SELECT TOP 1 @cLottable12 = POD.Lottable12
   FROM dbo.PODETAIL POD WITH (NOLOCK)
   JOIN dbo.RECEIPTDETAIL RD WITH (NOLOCK) 
      ON ( POD.ExternPOKey = RD.UserDefine03 AND POD.UserDefine01 = RD.UserDefine01 AND POD.Sku = RD.Sku)
   WHERE POD.POKey = @cPOKey
   ORDER BY 1
   
   -- This is stored in usd03 but udf03 only nvarchar(20)
   SET @cLottable12 = SUBSTRING( @cLottable12, 1, 20)
   
   -- Check if UCC mix sku
   IF EXISTS ( SELECT 1 
               FROM dbo.PODetail WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   POKey = @cPOKey 
               AND   UserDefine01 = @cUCCNo
               GROUP BY UserDefine01 
               HAVING COUNT( DISTINCT SKU) > 1)
      SET @nUCCMultiSKU = 1

   IF ISNULL( @cOtherReference, '') = ''
   BEGIN
      IF @nUCCMultiSKU = 1
      BEGIN
         SET @cType = 'SM'
         SET @cPosition = ''

         DECLARE @curInsLog   CURSOR
         SET @curInsLog = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT Sku, ISNULL( SUM( QtyOrdered), 0)
         FROM dbo.PODetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   POKey = @cPOKey 
         AND   UserDefine01 = @cUCCNo
         GROUP BY Sku
         ORDER BY Sku
         OPEN @curInsLog
         FETCH NEXT FROM @curInsLog INTO @cUCC_SKU, @nUCC_Qty
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @cPosition = ''
            BEGIN
               IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort2Log WITH (NOLOCK)
                               WHERE StorerKey = @cStorerKey 
                               AND   ReceiptKey = @cReceiptKey
                               AND   SUBSTRING( SKU, 1, 10) = SUBSTRING( @cUCC_SKU, 1, 10)
                               AND   UDF03 = @cLottable12)
                  SET @cPosition = 'QC'
            END

            INSERT INTO [RDT].[rdtPreReceiveSort2Log]
            (Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, UDF01, UDF02, UDF03, Status, AddWho, AddDate, EditWho, EditDate) 
            VALUES
            (@cFacility, @cStorerKey, @cReceiptKey, @cUCCNo, @cUCC_SKU, @nUCC_Qty, @cPosition, @cPOKey, @cType, @cLottable12, '1', @cUserName, GETDATE(), @cUserName, GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 118452
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PreRcv Err
               SET @cPosition01 = ''
               GOTO RollBackTran
            END
            
            FETCH NEXT FROM @curInsLog INTO @cUCC_SKU, @nUCC_Qty
         END
      END
      ELSE
      BEGIN

         SET @cType = 'S'

         -- Get sku, qty for ucc
         SELECT @cUCC_SKU = SKU, 
                @nUCC_Qty = SUM( QtyOrdered)
         FROM dbo.PODetail WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   POKey = @cPOKey 
         AND   UserDefine01 = @cUCCNo
         GROUP BY SKU

         -- Get inventory safe level for this sku
         SELECT @nSafe_Level = ISNULL( CAST( BUSR4 AS INT), 0)
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cUCC_SKU

         -- Get total qty on hand
         SELECT @nStockOnHand = ISNULL( SUM( Qty - QtyAllocated - QtyPicked - QtyReplen), 0)
         FROM dbo.LOTxLOCxID LLI WITH (NOLOCK)
         JOIN dbo.LOC LOC WITH (NOLOCK) ON ( LLI.LOC = LOC.LOC)
         WHERE LLI.StorerKey = @cStorerKey
         AND   LLI.SKU = @cUCC_SKU
         AND   LOC.Facility = @cFacility

         SELECT @nSortedQty = ISNULL( SUM( Qty), 0)
         FROM  [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   SKU = @cUCC_SKU
         AND   [Status] < '9'

         IF NOT EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort2Log WITH (NOLOCK)
                         WHERE StorerKey = @cStorerKey 
                         AND   ReceiptKey = @cReceiptKey
                         AND   SUBSTRING( SKU, 1, 10) = SUBSTRING( @cUCC_SKU, 1, 10)
                         AND   UDF03 = @cLottable12)
            SET @cPosition = 'QC'
         ELSE
            SET @cPosition = ''

         -- Check if it is first sku that been sort
         IF NOT EXISTS ( SELECT 1 FROM [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK) 
                         WHERE StorerKey = @cStorerKey
                         AND   ReceiptKey = @cReceiptKey
                         AND   SUBSTRING( SKU, 8, 3) = SUBSTRING( @cUCC_SKU, 8, 3)
                         AND   [Status] < '9')
         BEGIN
            IF @cPosition = ''
            BEGIN
               IF @nStockOnHand = 0 
                  SET @cPosition = 'QC Pick'
               ELSE
               BEGIN
                  IF @nSortedQty + @nStockOnHand >= @nSafe_Level
                     SET @cPosition = 'QC Buffer'
                  ELSE
                     SET @cPosition = 'QC Pick'
               END
            END

            INSERT INTO [RDT].[rdtPreReceiveSort2Log]
            (Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, UDF01, UDF02, UDF03, Status, AddWho, AddDate, EditWho, EditDate) 
            VALUES
            (@cFacility, @cStorerKey, @cReceiptKey, @cUCCNo, @cUCC_SKU, @nUCC_Qty, @cPosition, @cPOKey, @cType, @cLottable12, '1', @cUserName, GETDATE(), @cUserName, GETDATE())

            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 118453
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PreRcv Err
               SET @cPosition01 = ''
               GOTO RollBackTran
            END
         END
         ELSE
         BEGIN
            IF @cPosition = ''
            BEGIN
               IF @nSortedQty + @nStockOnHand >= @nSafe_Level
                  SET @cPosition = 'Buffer'
               ELSE
                  SET @cPosition = 'Pick'
            END

            IF NOT EXISTS ( SELECT 1 FROM  [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
                            WHERE StorerKey = @cStorerKey
                            AND   ReceiptKey = @cReceiptKey
                            AND   UCCNo = @cUCCNo)
            BEGIN
               INSERT INTO [RDT].[rdtPreReceiveSort2Log]
               (Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, UDF01, UDF02, UDF03, Status, AddWho, AddDate, EditWho, EditDate) 
               VALUES
               (@cFacility, @cStorerKey, @cReceiptKey, @cUCCNo, @cUCC_SKU, @nUCC_Qty, @cPosition, @cPOKey, @cType, @cLottable12, '1', @cUserName, GETDATE(), @cUserName, GETDATE())

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 118454
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PreRcv Err
                  SET @cPosition01 = ''
                  GOTO RollBackTran
               END
            END
         END
      END
   END
   ELSE
   BEGIN
      SET @cType = @cOtherReference

      IF NOT EXISTS ( SELECT 1 FROM  [RDT].[rdtPreReceiveSort2Log] WITH (NOLOCK)
                      WHERE StorerKey = @cStorerKey
                      AND   ReceiptKey = @cReceiptKey
                      AND   UCCNo = @cUCCNo)
      BEGIN
         INSERT INTO [RDT].[rdtPreReceiveSort2Log]
         (Facility, StorerKey, ReceiptKey, UCCNo, SKU, Qty, LOC, UDF01, UDF02, UDF03, Status, AddWho, AddDate, EditWho, EditDate) 
         VALUES
         (@cFacility, @cStorerKey, @cReceiptKey, @cUCCNo, @cUCC_SKU, @nUCC_Qty, '', @cPOKey, @cType, @cLottable12, '1', @cUserName, GETDATE(), @cUserName, GETDATE())

         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 118455
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Ins PreRcv Err
            SET @cPosition01 = ''
            GOTO RollBackTran
         END
      END
   END

   Display:
   SET @cPosition01 = 'TYPE: '
   SET @cPosition02 = @cType
   SET @cPosition03 = 'POSITION: '
   SET @cPosition04 = @cPosition

   SELECT TOP 1 @cSKUCategory = SKU.BUSR9 
   FROM dbo.PODetail PODtl WITH (NOLOCK)
   JOIN dbo.SKU SKU WITH (NOLOCK) ON ( PODtl.StorerKey = SKU.StorerKey AND PODtl.SKU = SKU.SKU)
   WHERE PODtl.StorerKey = @cStorerKey
   AND   PODtl.POKey = @cPOKey 
   AND   PODtl.UserDefine01 = @cUCCNo
   ORDER BY 1 DESC

   SET @cPosition05 = 'CATEGORY: '
   SET @cPosition06 = @cSKUCategory

   GOTO Quit

   RollBackTran:
         ROLLBACK TRAN rdt_PreRcvSort02
   Quit:
      WHILE @@TRANCOUNT > @nTranCount
         COMMIT TRAN

SET QUOTED_IDENTIFIER OFF

GO