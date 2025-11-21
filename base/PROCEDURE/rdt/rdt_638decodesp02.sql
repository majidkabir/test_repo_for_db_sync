SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638DecodeSP02                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Decode SKU, populate OrderDetail to ReceiptDetail                 */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 27-08-2020  Ung       1.0   WMS-14617 Created                              */
/* 23-09-2022  YeeKung   1.1   WMS-20820 Extended refno length (yeekung01)    */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_638DecodeSP02] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 60), -- yeekung01
   @cLOC         NVARCHAR( 10),
   @cBarcode     NVARCHAR( 60),
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @nUCCQTY      INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @nRowCount   INT

   DECLARE @cSeason     NVARCHAR( 2)
   DECLARE @cLOT        NVARCHAR( 12)
   DECLARE @cCOO        NVARCHAR( 2)
   DECLARE @cDocType    NVARCHAR( 1)
   DECLARE @cTempSKU    NVARCHAR( 13)
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cDBName     NVARCHAR( 30) = ''
   DECLARE @cExternOrderKey NVARCHAR( 20)
   DECLARE @nOrderQTY   INT

   SET @cSeason = ''
   SET @cTempSKU = ''
   SET @cLOT = ''
   SET @cCOO = ''
   SET @cOrderKey = ''

   -- Get 2D barcode
   SET @cSeason = SUBSTRING( @cBarcode, 1, 2)
   SET @cTempSKU = SUBSTRING( @cBarcode, 3, 13)
   SET @cLOT = SUBSTRING( @cBarcode, 16, 12)
   SET @cCOO = SUBSTRING( @cBarcode, 28, 2)

   -- Get Receipt info
   SELECT @cDocType = DocType FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Check SKU valid
   IF @cTempSKU = ''
   BEGIN
      SET @nErrNo = 157951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU is blank
      GOTO Quit
   END

   -- Check season valid
   IF @cSeason = ''
   BEGIN
      SET @nErrNo = 157952
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Season IsBlank
      GOTO Quit
   END

   -- Check season valid
   IF @cLOT = ''
   BEGIN
      SET @nErrNo = 157953
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT Is Blank
      GOTO Quit
   END

   -- Check COO valid
   IF @cCOO = ''
   BEGIN
      SET @nErrNo = 157954
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COO Is Blank
      GOTO Quit
   END

   -- Get ASN info
   SELECT @cExternOrderKey = ExternReceiptKey FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

   -- Get order info
   SELECT @cOrderKey = OrderKey FROM Orders WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND ExternOrderKey = @cExternOrderKey
   IF @cOrderKey = ''
   BEGIN
      -- Get archive DB
      SELECT @cDBName = NSQLValue FROM dbo.NSQLConFig WITH (NOLOCK) WHERE ConfigKey = 'ArchiveDBName'
      IF @cDBName <> ''
      BEGIN
         SET @cDBName = RTRIM( @cDBName) + '.'
         SET @cSQL =
            ' SELECT @cOrderKey = OrderKey ' +
            ' FROM ' + @cDBName + 'dbo.Orders WITH (NOLOCK) ' +
            ' WHERE StorerKey = @cStorerKey ' +
               ' AND ExternOrderKey = @cExternOrderKey '
         SET @cSQLParam =
            ' @cStorerKey      NVARCHAR( 15), ' +
            ' @cExternOrderKey NVARCHAR( 20), ' +
            ' @cOrderKey       NVARCHAR( 10) OUTPUT '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cStorerKey,
            @cExternOrderKey,
            @cOrderKey OUTPUT
      END
   END

   -- Check order valid
   IF @cOrderKey = ''
   BEGIN
      SET @nErrNo = 157955
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotFound
      GOTO Quit
   END

   -- Check SKU not in order
   SET @nRowCount = 0
   SET @cSQL =
      ' SELECT TOP 1 @nRowCount = 1 ' +
      ' FROM ' + @cDBName + 'dbo.PickDetail WITH (NOLOCK) ' +
      ' WHERE OrderKey = @cOrderKey ' +
         ' AND SKU = @cTempSKU ' +
         ' AND QTY > 0 ' +
         ' AND Status = ''9'' '
   SET @cSQLParam =
      ' @cOrderKey   NVARCHAR( 10), ' +
      ' @cTempSKU    NVARCHAR( 20), ' +
      ' @nRowCount   INT OUTPUT '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cOrderKey,
      @cTempSKU,
      @nRowCount OUTPUT
   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 157956
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --SKU NotInOrder
      GOTO Quit
   END

   -- Get order QTY
   -- Note: LOT can be in archive or still in main DB
   SET @cSQL =
      ' SELECT @nOrderQTY = ISNULL( SUM( PD.QTY), 0) ' +
      ' FROM ' + @cDBName + 'dbo.PickDetail PD WITH (NOLOCK) ' +
         ' LEFT JOIN ' + @cDBName + 'dbo.LotAttribute LA1 WITH (NOLOCK) ON (PD.LOT = LA1.LOT) ' +
         ' LEFT JOIN dbo.LotAttribute LA2 WITH (NOLOCK) ON (PD.LOT = LA2.LOT) ' +
      ' WHERE PD.OrderKey = @cOrderKey ' +
         ' AND PD.SKU = @cTempSKU ' +
         ' AND PD.QTY > 0 ' +
         ' AND PD.Status = ''9'' ' +
         ' AND ((LA1.Lottable01 = SUBSTRING( @cLOT, 1, 6) AND LA1.Lottable02 = @cLOT + ''-'' + @cCOO) ' +
         '  OR  (LA2.Lottable01 = SUBSTRING( @cLOT, 1, 6) AND LA2.Lottable02 = @cLOT + ''-'' + @cCOO)) '
   SET @cSQLParam =
      ' @cOrderKey   NVARCHAR( 10), ' +
      ' @cTempSKU    NVARCHAR( 20), ' +
      ' @cLOT        NVARCHAR( 12), ' +
      ' @cCOO        NVARCHAR( 2),  ' +
      ' @nOrderQTY   INT OUTPUT '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cOrderKey,
      @cTempSKU,
      @cLOT,
      @cCOO,
      @nOrderQTY OUTPUT

   -- Check SKU LOT in order
   IF @nOrderQTY = 0
   BEGIN
      SET @nErrNo = 157957
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LOT NotMatch
      GOTO Quit
   END

   -- Get return QTY (across multiple ASN, due to different return date)
   DECLARE @nReturnQTY INT
   SELECT @nReturnQTY = ISNULL( SUM( BeforeReceivedQTY), 0)
   FROM ReceiptDetail WITH (NOLOCK)
   WHERE ExternReceiptKey = @cExternOrderKey
      AND StorerKey = @cStorerKey
      AND SKU = @cTempSKU
      AND Lottable01 = SUBSTRING( @cLOT, 1, 6)
      AND Lottable02 = @cLOT + '-' + @cCOO

   -- Check over return
   IF (@nReturnQTY + 1) > @nOrderQTY
   BEGIN
      SET @nErrNo = 157958
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over return
      GOTO Quit
   END

   -- Get OrderLineNumber (1 OrderDetail = 1 PickDetail = 1 QTY)
   DECLARE @cOrderLineNumber NVARCHAR( 5)
   SET @cSQL =
      ' SELECT @cOrderLineNumber = A.OrderLineNumber ' +
      ' FROM ' +
      ' ( ' +
         ' SELECT PD.OrderLineNumber, ROW_NUMBER() OVER (ORDER BY PD.OrderLineNumber) RowNumber ' +
         ' FROM ' + @cDBName + 'dbo.PickDetail PD WITH (NOLOCK) ' +
            ' LEFT JOIN ' + @cDBName + 'dbo.LotAttribute LA1 WITH (NOLOCK) ON (PD.LOT = LA1.LOT) ' +
            ' LEFT JOIN dbo.LotAttribute LA2 WITH (NOLOCK) ON (PD.LOT = LA2.LOT) ' +
         ' WHERE PD.OrderKey = @cOrderKey ' +
            ' AND PD.StorerKey = @cStorerKey ' +
            ' AND PD.SKU = @cTempSKU ' +
            ' AND PD.QTY > 0 ' +
            ' AND PD.Status = ''9'' ' +
            ' AND ((LA1.Lottable01 = SUBSTRING( @cLOT, 1, 6) AND LA1.Lottable02 = @cLOT + ''-'' + @cCOO) ' +
            '  OR  (LA2.Lottable01 = SUBSTRING( @cLOT, 1, 6) AND LA2.Lottable02 = @cLOT + ''-'' + @cCOO))' +
      ' ) A ' +
      ' WHERE A.RowNumber = (@nReturnQTY + 1) '
   SET @cSQLParam =
      ' @cOrderKey   NVARCHAR( 10), ' +
      ' @cStorerKey  NVARCHAR( 15), ' +
      ' @cTempSKU    NVARCHAR( 20), ' +
      ' @cLOT        NVARCHAR( 12), ' +
      ' @cCOO        NVARCHAR( 2),  ' +
      ' @nReturnQTY  INT,           ' +
      ' @cOrderLineNumber NVARCHAR( 5) OUTPUT '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cOrderKey,
      @cStorerKey,
      @cTempSKU,
      @cLOT,
      @cCOO,
      @nReturnQTY,
      @cOrderLineNumber OUTPUT

   -- Get ExternLineNo line
   DECLARE @cExternLineNo NVARCHAR( 5)
   SET @cSQL =
      ' SELECT @cExternLineNo = ExternLineNo ' +
      ' FROM ' + @cDBName + 'dbo.OrderDetail WITH (NOLOCK) ' +
      ' WHERE OrderKey = @cOrderKey ' +
         ' AND OrderLineNumber = @cOrderLineNumber '
   SET @cSQLParam =
      ' @cOrderKey         NVARCHAR( 10), ' +
      ' @cOrderLineNumber  NVARCHAR( 5),  ' +
      ' @cExternLineNo     NVARCHAR( 5) OUTPUT '
   EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
      @cOrderKey,
      @cOrderLineNumber,
      @cExternLineNo OUTPUT

   -- Populate OrderDetail to ReceiptDetail
   IF NOT EXISTS( SELECT 1
      FROM ReceiptDetail WITH (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey
         AND StorerKey = @cStorerKey
         AND SKU = @cTempSKU
         AND ExternReceiptKey = @cExternOrderKey
         AND ExternLineNo = @cExternLineNo)
   BEGIN
      -- Get new line no
      DECLARE @cNewReceiptLineNumber NVARCHAR(5) = ''
      SELECT @cNewReceiptLineNumber = RIGHT( '00000' + CAST( CAST( IsNULL( MAX( ReceiptLineNumber), 0) AS INT) + 1 AS NVARCHAR( 5)), 5)
      FROM dbo.ReceiptDetail (NOLOCK)
      WHERE ReceiptKey = @cReceiptKey

      DECLARE @nTranCount INT
      SET @nTranCount = @@TRANCOUNT
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_638DecodeSP02 -- For rollback or commit only our own transaction

      -- (1 OrderDetail 1 PickDetail 1 QTY)
      SET @cSQL =
         ' INSERT INTO ReceiptDetail ' +
            ' (ReceiptKey, ReceiptLineNumber, ExternReceiptKey, ExternLineNo, StorerKey, SKU, UOM, PackKey, ConditionCode, QTYExpected, ToLOC, ' +
             ' Userdefine01, Userdefine03, Userdefine08, Userdefine09, Lottable03, ' +
             ' Lottable01, Lottable02, Lottable12) ' +
         ' SELECT TOP 1 ' +
            ' @cReceiptKey, @cNewReceiptLineNumber, O.ExternOrderKey, OD.ExternLineNo, @cStorerKey, @cTempSKU, OD.UOM, OD.PackKey, ''OK'', 1, '''', ' +
            ' CASE WHEN O.Type = ''COD'' THEN '''' ELSE ''1'' END, OD.Userdefine03, O.BuyerPO, OD.ExternLineNo, ''RET'', ' +
            ' CASE WHEN LA1.Lottable01 IS NULL THEN LA2.Lottable01 ELSE LA1.Lottable01 END, ' +
            ' CASE WHEN LA1.Lottable02 IS NULL THEN LA2.Lottable02 ELSE LA1.Lottable02 END, ' +
            ' CASE WHEN LA1.Lottable12 IS NULL THEN LA2.Lottable12 ELSE LA1.Lottable12 END  ' +
         ' FROM ' + @cDBName + 'dbo.Orders O WITH (NOLOCK) ' +
            ' JOIN ' + @cDBName + 'dbo.OrderDetail OD WITH (NOLOCK) ON (O.OrderKey = OD.OrderKey) ' +
            ' JOIN ' + @cDBName + 'dbo.PickDetail PD WITH (NOLOCK) ON (OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber) ' +
            ' LEFT JOIN ' + @cDBName + 'dbo.LotAttribute LA1 WITH (NOLOCK) ON (PD.LOT = LA1.LOT) ' +
            ' LEFT JOIN dbo.LotAttribute LA2 WITH (NOLOCK) ON (PD.LOT = LA2.LOT) ' +
         ' WHERE O.OrderKey = @cOrderKey ' +
            ' AND PD.OrderLineNumber = @cOrderLineNumber ' +
            ' AND PD.QTY > 0 ' +
            ' AND PD.Status = ''9'' ' +
         ' SET @nErrNo = @@ERROR '
      SET @cSQLParam =
         ' @cReceiptKey             NVARCHAR( 10), ' +
         ' @cNewReceiptLineNumber   NVARCHAR( 5),  ' +
         ' @cOrderKey               NVARCHAR( 10), ' +
         ' @cOrderLineNumber        NVARCHAR( 5),  ' +
         ' @cStorerKey              NVARCHAR( 15), ' +
         ' @cTempSKU                NVARCHAR( 20), ' +
         ' @nErrNo                  INT OUTPUT     '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cReceiptKey,
         @cNewReceiptLineNumber,
         @cOrderKey,
         @cOrderLineNumber,
         @cStorerKey,
         @cTempSKU,
         @nErrNo OUTPUT
      IF @nErrNo <> 0
      BEGIN
         ROLLBACK TRAN rdt_638DecodeSP02
         WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
            COMMIT TRAN
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
         GOTO Quit
      END

      COMMIT TRAN rdt_638DecodeSP02
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
   END

   -- Return value
   IF @cTempSKU <> ''
   BEGIN
      SET @cSKU = @cTempSKU
      SET @cLottable01 = SUBSTRING( @cLOT, 1, 6)
      SET @cLottable02 = @cLOT + '-' + @cCOO
      SET @cLottable03 = 'RET'
   END

Quit:

END

GO