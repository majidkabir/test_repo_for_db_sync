SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO



/******************************************************************************/
/* Store procedure: rdt_638RefNoLKUP03                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Lookup order populate to ASN                                      */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 26-08-2020   Ung       1.0   WMS-14617 Created                             */
/* 23-09-2022   YeeKung   1.1   WMS-20820 Extended refno length (yeekung01)   */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_638RefNoLKUP03]
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 60)  OUTPUT  --(yeekung01)
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

   DECLARE @bSuccess       INT
   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @nRowCount      INT
   DECLARE @cOperator      NVARCHAR( 10)
   DECLARE @cRefNoPattern  NVARCHAR( 22)

   SET @nRowCount = 0
   SET @cRefNoPattern = '%' + TRIM( @cRefNo) + '%' -- To support LIKE operator

   -- Receipt not yet found
   IF @cRefNo <> '' AND @cReceiptKey = ''
   BEGIN
      DECLARE @cDBName NVARCHAR(30) = ''
      DECLARE @cOrderKey NVARCHAR(10) = ''
      DECLARE @cExternOrderKey NVARCHAR(20)
      DECLARE @curSearch CURSOR

      -- Loop production and archive DB
      WHILE (1=1)
      BEGIN
         SET @curSearch = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT Code, Long
            FROM CodeLKUP WITH (NOLOCK)
            WHERE ListName = 'REFNOLKUP'
               AND StorerKey = @cStorerKey
               AND Code2 = @cFacility
            ORDER BY Short
         OPEN @curSearch
         FETCH NEXT FROM @curSearch INTO @cColumnName, @cOperator
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Check column valid
            SET @nRowCount = 0
            SET @cSQL =
               ' SELECT @nRowCount = 1 ' +
               ' FROM ' + @cDBName + 'INFORMATION_SCHEMA.COLUMNS ' +
               ' WHERE TABLE_NAME = ''Orders'' ' +
                  ' AND COLUMN_NAME = @cColumnName ' +
                  ' AND DATA_TYPE = ''nvarchar'' '
            SET @cSQLParam =
               ' @cColumnName    NVARCHAR(20), ' +
               ' @nRowCount      INT OUTPUT    '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cColumnName,
               @nRowCount OUTPUT
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 157851
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
               GOTO Quit
            END

            -- Check column indexed
            SET @nRowCount = 0
            SET @cSQL =
               CASE WHEN @cDBName = '' THEN '' ELSE ' USE ' + LEFT( @cDBName, LEN( @cDBName)-1) END +
               ' SELECT @nRowCount = 1 ' +
               ' FROM sys.index_columns (NOLOCK) ' +
               ' WHERE OBJECT_ID = OBJECT_ID( ''Orders'') ' +
                  ' AND COLUMNPROPERTY( object_id, @cColumnName, ''ColumnId'') = column_id '
            SET @cSQLParam =
               ' @cColumnName    NVARCHAR(20), ' +
               ' @nRowCount      INT OUTPUT    '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cColumnName,
               @nRowCount OUTPUT
            IF @nRowCount = 0
            BEGIN
               SET @nErrNo = 157852
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ColumnNoIndex
               GOTO Quit
            END

            -- Get order
            SET @cSQL =
               ' SELECT ' +
                  ' @cRefNo = O.' + @cColumnName + ', ' +
                  ' @cOrderKey = O.OrderKey, ' +
                  ' @cExternOrderKey = O.ExternOrderKey ' +
               ' FROM ' + @cDBName + 'dbo.Orders O WITH (NOLOCK) ' +
               ' WHERE O.Facility = @cFacility ' +
                  ' AND O.StorerKey = @cStorerKey ' +
                  CASE WHEN @cOperator = ''
                     THEN ' AND O.' + @cColumnName + ' = @cRefNo '
                     ELSE ' AND O.' + @cColumnName + ' LIKE @cRefNoPattern '
                  END
            SET @cSQLParam =
               ' @cFacility         NVARCHAR(5),  ' +
               ' @cStorerKey        NVARCHAR(15), ' +
               ' @cRefNoPattern     NVARCHAR(22), ' +
               ' @cRefNo            NVARCHAR(20) OUTPUT, ' +
               ' @cOrderKey         NVARCHAR(10) OUTPUT, ' +
               ' @cExternOrderKey   NVARCHAR(20) OUTPUT  '
            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @cFacility,
               @cStorerKey,
               @cRefNoPattern,
               @cRefNo           OUTPUT,
               @cOrderKey        OUTPUT,
               @cExternOrderKey  OUTPUT

            IF @cOrderKey <> ''
               BREAK

            FETCH NEXT FROM @curSearch INTO @cColumnName, @cOperator
         END

         -- Search archive DB
         IF @cOrderKey = '' AND @cDBName = ''
         BEGIN
            -- Get archive DB
            SELECT @cDBName = NSQLValue FROM dbo.NSQLConFig WITH (NOLOCK) WHERE ConfigKey = 'ArchiveDBName'
            IF @cDBName <> ''
            BEGIN
               SET @cDBName = RTRIM( @cDBName) + '.'
               CONTINUE
            END
         END

         BREAK
      END

      -- Order found
      IF @cOrderKey = ''
      BEGIN
         SET @nErrNo = 157853
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order NotFound
         GOTO Quit
      END

      -- Get open ASN
      SELECT @cReceiptKey = ReceiptKey
      FROM Receipt WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND ExternReceiptKey = @cExternOrderKey
         AND Status < '9'

      -- Create new ASN
      IF @cReceiptKey = ''
      BEGIN
         -- Get order QTY
         DECLARE @nOrderQTY INT
         SET @cSQL =
            ' SELECT @nOrderQTY = ISNULL( SUM( QTY), 0) ' +
            ' FROM ' + @cDBName + 'dbo.PickDetail WITH (NOLOCK) ' +
            ' WHERE OrderKey = @cOrderKey '
         SET @cSQLParam =
            ' @cOrderKey      NVARCHAR(10), ' +
            ' @nOrderQTY      INT OUTPUT    '
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @cOrderKey,
            @nOrderQTY OUTPUT

         -- Get ASN QTY (could be multiple ASN, due to received across different period)
         DECLARE @nReceiptQTY INT
         SELECT @nReceiptQTY = ISNULL( SUM( RD.BeforeReceivedQTY), 0)
         FROM Receipt R WITH (NOLOCK)
            JOIN ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
         WHERE R.StorerKey = @cStorerKey
            AND R.ExternReceiptKey = @cExternOrderKey

         -- Create ASN if not fully received
         IF @nReceiptQTY < @nOrderQTY
         BEGIN
            DECLARE @cNewReceiptKey NVARCHAR(10)
            EXECUTE dbo.nspg_GetKey
               'RECEIPT',
               10 ,
               @cNewReceiptKey OUTPUT,
               @bSuccess       OUTPUT,
               @nErrNo         OUTPUT,
               @cErrMsg        OUTPUT
            IF @bSuccess <> 1
            BEGIN
               SET @nErrNo = 157854
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail
               GOTO RollBackTran
            END

            DECLARE @nTranCount INT
            SET @nTranCount = @@TRANCOUNT
            BEGIN TRAN  -- Begin our own transaction
            SAVE TRAN rdt_638RefNoLKUP03 -- For rollback or commit only our own transaction

            -- Copy Orders to Receipt
            INSERT INTO Receipt
               (ReceiptKey, Facility, StorerKey, ExternReceiptKey, RecType, DocType)
            VALUES
               (@cNewReceiptKey, @cFacility, @cStorerKey, @cExternOrderKey, '', 'R')
            IF @@ERROR <> 0
            BEGIN
               ROLLBACK TRAN rdt_638RefNoLKUP03
               WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
                  COMMIT TRAN

               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            END

            COMMIT TRAN rdt_638RefNoLKUP03
            WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
               COMMIT TRAN

            SET @cReceiptKey = @cNewReceiptKey
         END
      END

      -- Check ASN populated
      IF @cReceiptKey = ''
      BEGIN
         SET @nErrNo = 157855
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN NotFound
         GOTO Quit
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_638RefNoLKUP03
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO