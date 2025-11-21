SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/
/* Store procedure: rdt_638RefNoLookup01                                      */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Search multiple columns, lookup TOP 1 ASN                         */
/*          1 tracking no might have multiple ASN, and same SKU in each ASN   */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-07-20   1.0  Ung        WMS-13555 Created                             */
/* 2022-09-23   1.1 YeeKung     WMS-20820 Extended refno length (yeekung02)   */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_638RefNoLookup01](
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
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL           NVARCHAR( MAX)
   DECLARE @cSQLParam      NVARCHAR( MAX)
   DECLARE @cColumnName    NVARCHAR( 20)
   DECLARE @nRowCount      INT
   DECLARE @cRefNoPattern  NVARCHAR( 22)

   SET @nRowCount = 0
   SET @cRefNoPattern = '' -- '%' + TRIM( @cRefNo) + '%' -- To support LIKE operator

   -- Lookup multi columns
   DECLARE @curSearch CURSOR
   SET @curSearch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT Code
      FROM CodeLKUP WITH (NOLOCK)
      WHERE ListName = 'REFNOLKUP'
         AND StorerKey = @cStorerKey
         AND Code2 = @cFacility
      ORDER BY Short
   OPEN @curSearch
   FETCH NEXT FROM @curSearch INTO @cColumnName
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check column valid
      IF NOT EXISTS( SELECT 1
         FROM INFORMATION_SCHEMA.COLUMNS
         WHERE TABLE_NAME = 'Receipt'
            AND COLUMN_NAME = @cColumnName
            AND DATA_TYPE = 'nvarchar')
      BEGIN
         SET @nErrNo = 155201
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
         GOTO Quit
      END

      -- Check column indexed
      IF NOT EXISTS( SELECT TOP 1 1
         FROM sys.index_columns (NOLOCK)
         WHERE OBJECT_ID = OBJECT_ID( 'Receipt')
            AND COLUMNPROPERTY( object_id, @cColumnName, 'ColumnId') = column_id)
      BEGIN
         SET @nErrNo = 155202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ColumnNoIndex
         GOTO Quit
      END

      SET @cSQL =
         ' SELECT TOP 1 ' +
            ' @cReceiptKey = R.ReceiptKey ' +
         ' FROM dbo.Receipt R WITH (NOLOCK) ' +
            CASE WHEN @cSKU = '' THEN '' ELSE ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' END +
         ' WHERE R.Facility = @cFacility ' +
            ' AND R.StorerKey = @cStorerKey ' +
            ' AND R.Status <> ''9'' ' +
            ' AND R.' + @cColumnName + ' = @cRefNo ' +
            CASE WHEN @cSKU = ''
               THEN ''
               ELSE ' AND RD.SKU = @cSKU ' +
                    ' AND RD.QTYExpected > BeforeReceivedQTY '
            END +
         ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT '
      SET @cSQLParam =
         ' @nMobile        INT, ' +
         ' @cFacility      NVARCHAR(5),  ' +
         ' @cStorerKey     NVARCHAR(15), ' +
         ' @cRefNoPattern  NVARCHAR(22), ' +
         ' @cSKU           NVARCHAR(20), ' +
         ' @cRefNo         NVARCHAR(20) OUTPUT, ' +
         ' @cReceiptKey    NVARCHAR(10) OUTPUT, ' +
         ' @nRowCount      INT          OUTPUT, ' +
         ' @nErrNo         INT          OUTPUT  '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile,
         @cFacility,
         @cStorerKey,
         @cRefNoPattern,
         @cSKU,
         @cRefNo      OUTPUT,
         @cReceiptKey OUTPUT,
         @nRowCount   OUTPUT,
         @nErrNo      OUTPUT

      IF @cReceiptKey <> ''
         BREAK

      FETCH NEXT FROM @curSearch INTO @cColumnName
   END

   -- Check RefNo in ASN
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 155203
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No RefNoSKU
      GOTO Quit
   END

   IF @nStep = 1 -- RefNo, ASN
      SET @cReceiptKey = ''

   ELSE IF @nStep = 3 -- SKU
   BEGIN
      SET @cSQL =
         ' SELECT @nBalQTY = SUM( QTYExpected - BeforeReceivedQTY) ' +
         ' FROM dbo.Receipt R WITH (NOLOCK) ' +
            ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' +
         ' WHERE R.Facility = @cFacility ' +
            ' AND R.StorerKey = @cStorerKey ' +
            ' AND R.Status <> ''9'' ' +
            ' AND R.' + @cColumnName + ' = @cRefNo '
      SET @cSQLParam =
         ' @cFacility  NVARCHAR(5),  ' +
         ' @cStorerKey NVARCHAR(15), ' +
         ' @cRefNo     NVARCHAR(20), ' +
         ' @nBalQTY    INT OUTPUT    '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @cFacility,
         @cStorerKey,
         @cRefNo,
         @nBalQTY OUTPUT
   END

Quit:

END

GO