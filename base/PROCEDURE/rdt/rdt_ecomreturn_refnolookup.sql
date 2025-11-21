SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_EcomReturn_RefNoLookup                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Search multiple columns, lookup ASN                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2020-06-17   1.0  Ung        WMS-13555 Created                             */
/******************************************************************************/
CREATE PROC [RDT].[rdt_EcomReturn_RefNoLookup](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 20)  OUTPUT
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

   -- Get storer config
   SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)

   /***********************************************************************************************
                                              Custom lookup
   ***********************************************************************************************/
   -- Lookup by SP
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cColumnName AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, ' +
         ' @cRefNo OUTPUT, @cReceiptKey OUTPUT, @nBalQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
      SET @cSQLParam =
         ' @nMobile      INT,           ' +
         ' @nFunc        INT,           ' +
         ' @cLangCode    NVARCHAR( 3),  ' +
         ' @nStep        INT,           ' +
         ' @nInputKey    INT,           ' +
         ' @cFacility    NVARCHAR( 5),  ' +
         ' @cStorerKey   NVARCHAR( 15), ' +
         ' @cSKU         NVARCHAR(20),  ' + 
         ' @cRefNo       NVARCHAR( 20)  OUTPUT, ' +
         ' @cReceiptKey  NVARCHAR( 10)  OUTPUT, ' +
         ' @nBalQTY      INT            OUTPUT, ' + 
         ' @nErrNo       INT            OUTPUT, ' +
         ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, 
         @cRefNo OUTPUT, @cReceiptKey OUTPUT, @nBalQTY OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END
   
   /***********************************************************************************************
                                             Standard lookup
   ***********************************************************************************************/
   DECLARE @nRowCount      INT
   DECLARE @cOperator      NVARCHAR( 10)
   DECLARE @cRefNoPattern  NVARCHAR( 22)

   SET @nRowCount = 0
   SET @cRefNoPattern = '%' + TRIM( @cRefNo) + '%' -- To support LIKE operator

   -- Lookup multi columns
   IF @cColumnName = 'MULTI'
   BEGIN
      DECLARE @curSearch CURSOR
      SET @curSearch = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
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
         IF NOT EXISTS( SELECT 1
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_NAME = 'Receipt' 
               AND COLUMN_NAME = @cColumnName
               AND DATA_TYPE = 'nvarchar')
         BEGIN
            SET @nErrNo = 154651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
            GOTO Quit
         END
         
         -- Check column indexed
         IF NOT EXISTS( SELECT TOP 1 1
            FROM sys.index_columns (NOLOCK) 
            WHERE OBJECT_ID = OBJECT_ID( 'Receipt') 
               AND COLUMNPROPERTY( object_id, @cColumnName, 'ColumnId') = column_id)
         BEGIN
            SET @nErrNo = 154652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ColumnNoIndex
            GOTO Quit
         END   

         SET @cSQL = 
            ' SELECT ' + 
               ' @cReceiptKey = R.ReceiptKey, ' + 
               ' @cRefNo = R.' + @cColumnName + 
            ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
               CASE WHEN @cSKU = '' THEN '' ELSE ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' END + 
            ' WHERE R.Facility = @cFacility ' + 
               ' AND R.StorerKey = @cStorerKey ' + 
               ' AND R.Status <> ''9'' ' + 
               CASE WHEN @cOperator = '' 
                  THEN ' AND R.' + @cColumnName + ' = @cRefNo ' 
                  ELSE ' AND R.' + @cColumnName + ' LIKE @cRefNoPattern '  
               END +
               CASE WHEN @cSKU = '' THEN '' ELSE ' AND RD.SKU = @cSKU ' END + 
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
         
         FETCH NEXT FROM @curSearch INTO @cColumnName, @cOperator
      END
   END

   -- Lookup single column
   ELSE
   BEGIN
      -- Check column valid
      IF NOT EXISTS( SELECT 1
         FROM INFORMATION_SCHEMA.COLUMNS 
         WHERE TABLE_NAME = 'Receipt' 
            AND COLUMN_NAME = @cColumnName
            AND DATA_TYPE = 'nvarchar')
      BEGIN
         SET @nErrNo = 154653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Column
         GOTO Quit
      END

      SET @cSQL = 
         ' SELECT ' + 
            ' @cReceiptKey = R.ReceiptKey, ' + 
            ' @cRefNo = R.' + @cColumnName + 
         ' FROM dbo.Receipt R WITH (NOLOCK) ' + 
            CASE WHEN @cSKU = '' THEN '' ELSE ' JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) ' END + 
         ' WHERE R.Facility = @cFacility ' + 
            ' AND R.StorerKey = @cStorerKey ' + 
            ' AND R.Status <> ''9'' ' + 
            ' AND R.' + @cColumnName + ' = @cRefNo ' +
            CASE WHEN @cSKU = '' THEN '' ELSE ' AND RD.SKU = @cSKU ' END + 
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

      IF @nErrNo <> 0
         GOTO Quit
   END

   -- Check RefNo in ASN
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 154654
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
      GOTO Quit
   END
   
   -- Check multi ASN 
   -- For RefNo + SKU, assumption is one ASN, no same SKU with multi lines
   IF @nRowCount > 1 
   BEGIN
      -- Rest ReceiptKey, coz don't know which ASN
      SET @cReceiptKey = ''

      DECLARE @cRefNoSKULookup NVARCHAR( 1)
      SET @cRefNoSKULookup = rdt.RDTGetConfig( @nFunc, 'RefNoSKULookup', @cStorerKey)
      
      IF @nStep = 1 AND @cRefNoSKULookup = '1' -- RefNo, ASN screen
         GOTO Quit -- Dont' prompt error, as step 3 scan SKU only lookup actual ASN. 
      ELSE
      BEGIN
         SET @nErrNo = 154655
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo MultiASN
         GOTO Quit
      END
   END

Quit:

END

GO