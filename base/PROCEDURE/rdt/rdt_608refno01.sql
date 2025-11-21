SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_608RefNo01                                            */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 10-Jul-2017  Ung       1.0   WMS-2622 Share with rdt_607RefNo01            */
/* 08-Sep-2022  Ung       1.1   WMS-20348 Expand RefNo to 60 chars            */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_608RefNo01]
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @cFacility     NVARCHAR( 5),  
   @cStorerGroup  NVARCHAR( 20), 
   @cStorerKey    NVARCHAR( 15), 
   @cRefNo        NVARCHAR( 60), 
   @cReceiptKey   NVARCHAR(10)  OUTPUT, 
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err       INT
   DECLARE @bSuccess    INT
   DECLARE @nTranCount  INT
   DECLARE @nRowCount   INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cDataType   NVARCHAR( 128)
   
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cLOC        NVARCHAR(10)
   DECLARE @cColumnName NVARCHAR(30)
   DECLARE @curColumn   CURSOR
   
   SET @nTranCount = @@TRANCOUNT
   
   IF @cStorerGroup <> '' 
      SET @curColumn = CURSOR FOR
         SELECT Code 
         FROM CodeLKUP C WITH (NOLOCK) 
         WHERE ListName = 'RefReceipt' 
            AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = C.StorerKey)
            AND Code2 = @nFunc
         ORDER BY Short
   ELSE
      SET @curColumn = CURSOR FOR
         SELECT Code 
         FROM CodeLKUP WITH (NOLOCK) 
         WHERE ListName = 'RefReceipt' 
            AND StorerKey = @cStorerKey 
            AND Code2 = @nFunc
         ORDER BY Short
   
   OPEN @curColumn
   FETCH NEXT FROM @curColumn INTO @cColumnName
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Get lookup field data type
      SET @cDataType = ''
      SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName
      
      IF @cDataType <> ''
      BEGIN
         IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
         IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE 
         IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE 
         IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
                           
         -- Check data type
         IF @n_Err = 0
         BEGIN
            SET @nErrNo = 113751
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
            EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
            GOTO Quit
         END
         
         SET @cSQL = 
            ' SELECT @cReceiptKey = ReceiptKey ' + 
            ' FROM dbo.Receipt WITH (NOLOCK) ' + 
            ' WHERE Facility = @cFacility ' + 
               ' AND Status <> ''9'' ' + 
               CASE WHEN @cDataType IN ('int', 'float') 
                    THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo ' 
                    ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo ' 
               END + 
               CASE WHEN @cStorerGroup = '' 
                    THEN ' AND StorerKey = @cStorerKey ' 
                    ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = Receipt.StorerKey) ' 
               END + 
            ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT ' 
         SET @cSQLParam =
            ' @nMobile      INT, ' + 
            ' @cFacility    NVARCHAR(5),  ' + 
            ' @cStorerGroup NVARCHAR(20), ' + 
            ' @cStorerKey   NVARCHAR(15), ' + 
            ' @cColumnName  NVARCHAR(20), ' +  
            ' @cRefNo       NVARCHAR(20), ' + 
            ' @cReceiptKey  NVARCHAR(10) OUTPUT, ' + 
            ' @nRowCount    INT          OUTPUT, ' + 
            ' @nErrNo       INT          OUTPUT  '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
            @nMobile, 
            @cFacility, 
            @cStorerGroup, 
            @cStorerKey, 
            @cColumnName, 
            @cRefNo, 
            @cReceiptKey OUTPUT, 
            @nRowCount   OUTPUT, 
            @nErrNo      OUTPUT
   
         IF @nErrNo <> 0
            GOTO Quit
   
         -- Check RefNo in ASN
         IF @nRowCount > 1
         BEGIN
            SET @nErrNo = 113752
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi ASN
            GOTO Quit
         END

         IF @cReceiptKey <> ''
            BREAK            
      END
      FETCH NEXT FROM @curColumn INTO @cColumnName
   END

   -- Receipt not found
   IF @cReceiptKey = ''
   BEGIN
      -- Get Order info
      SET @cOrderKey = ''
      IF @cStorerGroup <> '' 
         SET @curColumn = CURSOR FOR
            SELECT Code 
            FROM CodeLKUP C WITH (NOLOCK) 
            WHERE ListName = 'RefOrders' 
               AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = C.StorerKey)
               AND Code2 = @nFunc
            ORDER BY Short
      ELSE
         SET @curColumn = CURSOR FOR
            SELECT Code 
            FROM CodeLKUP WITH (NOLOCK) 
            WHERE ListName = 'RefOrders' 
               AND StorerKey = @cStorerKey 
               AND Code2 = @nFunc
            ORDER BY Short
      
      OPEN @curColumn
      FETCH NEXT FROM @curColumn INTO @cColumnName
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Get lookup field data type
         SET @cDataType = ''
         SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Orders' AND COLUMN_NAME = @cColumnName
         
         IF @cDataType <> ''
         BEGIN
            IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
            IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE 
            IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE 
            IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
                              
            -- Check data type
            IF @n_Err = 0
            BEGIN
               SET @nErrNo = 113753
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
               EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
               GOTO Quit
            END
            
            SET @cSQL = 
               ' SELECT @cOrderKey = OrderKey ' + 
               ' FROM dbo.Orders WITH (NOLOCK) ' + 
               ' WHERE Facility = @cFacility ' + 
                  ' AND Status = ''9'' ' + 
                  CASE WHEN @cDataType IN ('int', 'float') 
                       THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo ' 
                       ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo ' 
                  END + 
                  CASE WHEN @cStorerGroup = '' 
                       THEN ' AND StorerKey = @cStorerKey ' 
                       ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = Receipt.StorerKey) ' 
                  END + 
               ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT ' 
            SET @cSQLParam =
               ' @nMobile      INT, ' + 
               ' @cFacility    NVARCHAR(5),  ' + 
               ' @cStorerGroup NVARCHAR(20), ' + 
               ' @cStorerKey   NVARCHAR(15), ' + 
               ' @cColumnName  NVARCHAR(20), ' +  
               ' @cRefNo       NVARCHAR(20), ' + 
               ' @cOrderKey    NVARCHAR(10) OUTPUT, ' + 
               ' @nRowCount    INT          OUTPUT, ' + 
               ' @nErrNo       INT          OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
               @nMobile, 
               @cFacility, 
               @cStorerGroup, 
               @cStorerKey, 
               @cColumnName, 
               @cRefNo, 
               @cOrderKey OUTPUT, 
               @nRowCount   OUTPUT, 
               @nErrNo      OUTPUT
      
            IF @nErrNo <> 0
               GOTO Quit
      
            -- Check multi Orders
            IF @nRowCount > 1
            BEGIN
               SET @nErrNo = 113754
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi Orders
               GOTO Quit
            END
   
            IF @cOrderKey <> ''
               BREAK
         END
         
         FETCH NEXT FROM @curColumn INTO @cColumnName
      END

      -- Order found
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 113755
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotFound
         GOTO Quit
      END
      ELSE
      BEGIN
         -- Get LOC info
         SET @cLOC = 'Y3RETN'
         
         -- Get new ReceiptKey
         DECLARE @cNewReceiptKey NVARCHAR( 10)
         EXECUTE dbo.nspg_GetKey
            'RECEIPT', 
            10 ,
            @cNewReceiptKey OUTPUT,
            @bSuccess       OUTPUT,
            @nErrNo         OUTPUT,
            @cErrMsg        OUTPUT
         IF @bSuccess <> 1
         BEGIN
            SET @nErrNo = 113756
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
            GOTO RollBackTran
         END

         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_608RefNo01 -- For rollback or commit only our own transaction

         -- Copy Orders to Receipt
         INSERT INTO Receipt
            (ReceiptKey, Facility, StorerKey, ExternReceiptKey, WarehouseReference, CarrierKey, RECType, PlaceOfDelivery, SellerName, CarrierName, SellerAddress1, DocType)
         SELECT 
            @cNewReceiptKey, @cFacility, @cStorerKey, OrderKey, BuyerPO, ConsigneeKey, Type, ShipperKey, B_Contact1, C_Contact1, C_Address1, 'R'
         FROM Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey 
         IF @@ERROR <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         
         -- Copy OrderDetail to ReceiptDetail
         INSERT INTO ReceiptDetail
            (ReceiptKey, ReceiptLineNumber, Userdefine01, Userdefine02, Userdefine03, Lottable02, StorerKey, SKU, QTYExpected, Packkey, UOM, ToLOC)
         SELECT 
            @cNewReceiptKey, OrderLineNumber, Userdefine01, Userdefine02, Userdefine03, Lottable02, StorerKey, SKU, ShippedQty, PackKey, UOM, @cLOC
         FROM OrderDetail WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey 
         IF @@ERROR <> 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
         
         SET @cReceiptKey = @cNewReceiptKey
      END
   END
   GOTO Quit

RollBackTran:  
   ROLLBACK TRAN rdt_608RefNo01 
Fail:  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN      
END

GO