SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_606RefNoLKUP02                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author   Ver.  Purposes                                        */
/* 2022-09-06  yeekung  1.0   WMS-20703 Created                               */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_606RefNoLKUP02]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerGroup NVARCHAR( 20),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10)  OUTPUT,
   @cPOKey       NVARCHAR( 10)  OUTPUT,
   @cRefNo       NVARCHAR( 20)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT

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

   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cColumnName    NVARCHAR( 30)
   DECLARE @cUDF02         NVARCHAR( 60)
   DECLARE @cUDF03         NVARCHAR( 60)
   DECLARE @nReceiptField  INT
   DECLARE @nOrderField    INT
   DECLARE @curColumn      CURSOR

   SET @nTranCount = @@TRANCOUNT
   SET @nReceiptField = 0
   SET @nOrderField = 0

   IF @cStorerGroup <> ''
      SET @curColumn = CURSOR FOR
         SELECT C.UDF01, C.UDF02,C.UDF03
         FROM CodeLKUP C WITH (NOLOCK)
         WHERE ListName = 'RefReceipt'
            AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = C.StorerKey)
            AND Code2 = @nFunc
         ORDER BY Short
   ELSE
      SET @curColumn = CURSOR FOR
         SELECT UDF01, UDF02,UDF03
         FROM CodeLKUP WITH (NOLOCK)
         WHERE ListName = 'RefReceipt'
            AND StorerKey = @cStorerKey
            AND Code2 = @nFunc
         ORDER BY Short

   OPEN @curColumn
   FETCH NEXT FROM @curColumn INTO @cColumnName, @cUDF02,@cUDF03
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- Check max lookup field (for performance, ref field might not indexed)
      SET @nReceiptField = @nReceiptField + 1
      IF @nReceiptField > 3
      BEGIN
         SET @nErrNo = 191001
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Max 3 RefField
         GOTO Quit
      END

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
            SET @nErrNo = 191002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
            GOTO Quit
         END

         IF ISNULL( @cUDF02, '') = ''
            SET @cUDF02 = ''

         SET @cSQL =
            ' SELECT @cReceiptKey = ReceiptKey ' +
            ' FROM dbo.Receipt WITH (NOLOCK) ' +
            ' WHERE Facility = @cFacility ' +
               ' AND Status NOT IN (''9'', ''CANC'') ' +
               ' AND ASNStatus <> ''CANC'' ' +
               CASE WHEN @cDataType IN ('int', 'float')
                    THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo '
                    ELSE CASE WHEN @cUDF02 = '' THEN ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo '
                                                ELSE CASE WHEN @cUDF03 = '=' THEN ' AND ISNULL( ' + @cColumnName + ', '''') = ' +@cUDF02 
                                                          WHEN @cUDF03 = 'Like' THEN ' AND '+ @cColumnName + ' like' +'''%''+' + @cUDF02 +'+''%'''
                                                          ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = ' +@cUDF02 END
                                                END
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
            ' @cRefNo       NVARCHAR(30), ' +
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
            SET @nErrNo = 191003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Multi ASN
            GOTO Quit
         END

         IF @cReceiptKey <> ''
            BREAK
      END

      FETCH NEXT FROM @curColumn INTO @cColumnName, @cUDF02,@cUDF03
   END

   -- Receipt not found
   IF @cReceiptKey = ''
   BEGIN
      SET @nErrNo = 191004
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ASN NotFound
      GOTO Quit
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_606RefNoLKUP02
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO