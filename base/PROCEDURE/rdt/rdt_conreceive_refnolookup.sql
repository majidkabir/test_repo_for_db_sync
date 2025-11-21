SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_ConReceive_RefNoLookup                                */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Search multiple columns, lookup ASN                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-06-17   1.0  Chermaine  WMS-17244 Created                             */
/******************************************************************************/
CREATE PROC [RDT].[rdt_ConReceive_RefNoLookup](
    @nMobile      INT
   ,@nFunc        INT
   ,@cLangCode    NVARCHAR( 3)
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cFacility    NVARCHAR( 5)
   ,@cStorerKey   NVARCHAR( 15)
   ,@cSKU         NVARCHAR( 20)  -- Optional, lookup by RefNo + SKU
   ,@cRefNo       NVARCHAR( 20)  OUTPUT
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
   DECLARE @cDataType      NVARCHAR( 128)
   DECLARE @cStorerGroup   NVARCHAR( 20)
   DECLARE @nRowCount      INT
   DECLARE @n_Err          INT
   DECLARE @nRowRef        INT
   DECLARE @curCR          CURSOR

   -- Get storer config
   SET @cColumnName = rdt.RDTGetConfig( @nFunc, 'RefNoLookupColumn', @cStorerKey)
   
   SET @nRowCount = 0
   SET @cStorerGroup = ISNULL(@cStorerGroup,'')
   
   -- Clear log
   IF EXISTS( SELECT 1 FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile)
   BEGIN
      SET @curCR = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RowRef FROM rdt.rdtConReceiveLog WITH (NOLOCK) WHERE Mobile = @nMobile
      OPEN @curCR
      FETCH NEXT FROM @curCR INTO @nRowRef
      WHILE @@FETCH_STATUS = 0
      BEGIN
         DELETE rdt.rdtConReceiveLog WHERE RowRef = @nRowRef 
         FETCH NEXT FROM @curCR INTO @nRowRef
      END
   END

   /***********************************************************************************************
                                              Custom lookup
   ***********************************************************************************************/
   -- Lookup by SP
   IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cColumnName AND type = 'P')
   BEGIN
      SET @cSQL = 'EXEC rdt.' + RTRIM( @cColumnName) +
         ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, ' +
         ' @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT'
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
         ' @nErrNo       INT            OUTPUT, ' +
         ' @cErrMsg      NVARCHAR( 20)  OUTPUT'

      EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
         @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cSKU, 
         @cRefNo OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT

      GOTO Quit
   END
   
   /***********************************************************************************************
                                             Standard lookup
   ***********************************************************************************************/
   
   SET @cDataType = ''
   SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName

   -- Check lookup field
   IF @cDataType = ''
   BEGIN
      SET @nErrNo = 169251
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad RefNoSetup
      GOTO Quit
   END
      
   -- Check data is correct type
   IF @cDataType = 'nvarchar' SET @n_Err = 1                                ELSE
   IF @cDataType = 'datetime' SET @n_Err = rdt.rdtIsValidDate( @cRefNo)     ELSE 
   IF @cDataType = 'int'      SET @n_Err = rdt.rdtIsInteger(   @cRefNo)     ELSE 
   IF @cDataType = 'float'    SET @n_Err = rdt.rdtIsValidQTY(  @cRefNo, 20)
   IF @n_Err = 0
   BEGIN
      SET @nErrNo = 169252
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid RefNo
      EXEC rdt.rdtSetFocusField @nMobile, 3 -- RefNo
      GOTO Quit
   END
   
   -- Insert log
      SET @cSQL = 
         ' INSERT INTO rdt.rdtConReceiveLog (Mobile, ReceiptKey) ' + 
         ' SELECT @nMobile, ReceiptKey ' + 
         ' FROM dbo.Receipt WITH (NOLOCK) ' + 
         ' WHERE Facility = @cFacility ' + 
            ' AND Status <> ''9'' ' + 
            CASE WHEN @cDataType IN ('int', 'float') 
                 THEN ' AND ISNULL( ' + @cColumnName + ', 0) = @cRefNo ' 
                 ELSE ' AND ISNULL( ' + @cColumnName + ', '''') = @cRefNo ' 
            END + 
            CASE WHEN @cStorerGroup = '' 
                 THEN ' AND StorerKey = @cStorerKey ' 
                 ELSE ' AND EXISTS( SELECT 1 FROM StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerGroup AND StorerKey = @cStorerKey )' 
            END + 
         ' ORDER BY ReceiptKey ' + 
         ' SELECT @nErrNo = @@ERROR, @nRowCount = @@ROWCOUNT ' 
      SET @cSQLParam =
         ' @nMobile      INT, ' + 
         ' @cFacility    NVARCHAR(5),  ' + 
         ' @cStorerGroup NVARCHAR(20), ' + 
         ' @cStorerKey   NVARCHAR(15), ' + 
         ' @cColumnName  NVARCHAR(20), ' +  
         ' @cRefNo       NVARCHAR(20), ' + 
         ' @nRowCount    INT OUTPUT,   ' + 
         ' @nErrNo       INT OUTPUT    '
      EXEC sp_ExecuteSQL @cSQL, @cSQLParam, 
         @nMobile, 
         @cFacility, 
         @cStorerGroup, 
         @cStorerKey, 
         @cColumnName, 
         @cRefNo, 
         @nRowCount OUTPUT, 
         @nErrNo    OUTPUT

      IF @nErrNo <> 0
         GOTO Quit

      -- Check RefNo in ASN
      IF @nRowCount = 0
      BEGIN
         SET @nErrNo = 169253
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END
Quit:

END

GO