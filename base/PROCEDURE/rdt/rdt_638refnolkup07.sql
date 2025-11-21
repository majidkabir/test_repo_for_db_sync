SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638RefNoLKUP07                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 07-06-2021  YeeKung    1.0   WMS-17175 Created                             */
/* 23-09-2022  YeeKung    1.1   WMS-20820 Extended refno length (yeekung01)   */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_638RefNoLKUP07]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 60)  OUTPUT --(yeekung01)
   ,@cReceiptKey  NVARCHAR( 10)  OUTPUT
   ,@nBalQTY      INT            OUTPUT
   ,@nErrNo       INT            OUTPUT
   ,@cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_err          INT
   DECLARE @bSuccess       INT
   DECLARE @nTranCount     INT
   DECLARE @nRowCount      INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cDataType      NVARCHAR( 128)

   DECLARE @cOrderKey      NVARCHAR(10)
   DECLARE @cLOC           NVARCHAR(10)
   DECLARE @cColumnName    NVARCHAR(30)
   DECLARE @nReceiptField  INT
   DECLARE @nOrderField    INT
   DECLARE @curColumn      CURSOR
   DECLARE @cNewReceiptKey NVARCHAR( 10)

   SET @nTranCount = @@TRANCOUNT
   SET @nReceiptField = 0
   SET @nOrderField = 0

   SELECT @cReceiptKey=receiptkey
   from RECEIPT (NOLOCK)
   where ExternReceiptKey=@cRefNo
   AND StorerKey=@cStorerKey
   AND status<>9

   -- Receipt not found
   IF @cReceiptKey = ''
   BEGIN
      IF rdt.RDTGetConfig( @nFunc, 'PopulateOrderToASN', @cStorerKey) = '1'
      BEGIN
         -- Get Order info
         SET @cOrderKey = ''
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
            -- Check max lookup field (for performance, ref field might not indexed)
            SET @nOrderField = @nOrderField + 1
            IF @nOrderField > 2
            BEGIN
               SET @nErrNo = 170301
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Max 2 RefField
               GOTO Quit
            END

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
                  SET @nErrNo = 170302
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
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
                     ' AND StorerKey = @cStorerKey ' +
                  ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
               SET @cSQLParam =
                  ' @nMobile      INT, ' +
                  ' @cFacility    NVARCHAR(5),  ' +
                  ' @cStorerKey   NVARCHAR(15), ' +
                  ' @cColumnName  NVARCHAR(20), ' +
                  ' @cRefNo       NVARCHAR(20), ' +
                  ' @cOrderKey    NVARCHAR(10) OUTPUT, ' +
                  ' @nRowCount    INT          OUTPUT, ' +
                  ' @nErrNo       INT          OUTPUT  '
               EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
                  @nMobile,
                  @cFacility,
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
                  SET @nErrNo = 170303
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
            SET @nErrNo = 170304
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotFound
            GOTO Quit
         END
         ELSE
         BEGIN
            IF NOT EXISTS(SELECT 1
                        FROM receipt R (nolock) join orders o (NOLOCK)
                        ON R.UserDefine01=o.externorderkey
                        WHERE o.OrderKey=@cOrderKey
                        AND R.storerkey=@cstorerkey)
            BEGIN


               EXECUTE dbo.nspg_GetKey
                  'RECEIPT',
                  10 ,
                  @cNewReceiptKey OUTPUT,
                  @bSuccess       OUTPUT,
                  @nErrNo         OUTPUT,
                  @cErrMsg        OUTPUT
               IF @bSuccess <> 1
               BEGIN
                  SET @nErrNo = 170305
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
                  GOTO RollBackTran
               END

               BEGIN TRAN  -- Begin our own transaction
               SAVE TRAN rdt_638RefNoLKUP07 -- For rollback or commit only our own transaction

               -- Copy Orders to Receipt
               INSERT INTO Receipt
                  (ReceiptKey, Facility, StorerKey, ExternReceiptKey, WarehouseReference,userdefine01,RecType,receiptgroup,doctype,ASNReason,Appointment_no,UserDefine02)
               SELECT
                  @cNewReceiptKey, @cFacility, @cStorerKey, externorderkey,externorderkey,externorderkey,'GRN','ECOM','R','12', '','Y'
               FROM Orders WITH (NOLOCK)
               WHERE OrderKey = @cOrderKey
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 170306
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsReceiptFail
                  GOTO RollBackTran
               END

               SET @cReceiptKey = @cNewReceiptKey
            END
            ELSE
            BEGIN
               SELECT @cReceiptKey=R.ReceiptKey
               FROM receipt R (nolock) join orders o (NOLOCK)
               ON R.UserDefine01=o.externorderkey
               WHERE o.OrderKey=@cOrderKey
               AND R.storerkey=@cstorerkey
            END
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 170307
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN NotFound
         GOTO Quit
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_638RefNoLKUP07
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO