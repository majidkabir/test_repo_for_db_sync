SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_598RefNoLKUP01                                        */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2021-06-17   1.0  Chermaine  WMS-17244. Created                            */
/******************************************************************************/
CREATE PROC [RDT].[rdt_598RefNoLKUP01](
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
   DECLARE @nRowCount      INT
   DECLARE @cDataType      NVARCHAR(128)
   DECLARE @n_Err          INT
   DECLARE @cStorerGroup   NVARCHAR( 20)

   SET @nRowCount = 0
   SET @cStorerGroup = ISNULL(@cStorerGroup,'')

   -- Lookup columns
   SELECT @cColumnName = Code
   FROM CodeLKUP WITH (NOLOCK)
   WHERE ListName = 'REFNOLKUP'
      AND StorerKey = @cStorerKey
      AND Code2 = @cFacility
   ORDER BY Short
  
  IF @cColumnName <> ''
  BEGIN
  	   SET @cDataType = ''
      SELECT @cDataType = DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'Receipt' AND COLUMN_NAME = @cColumnName
      
      -- Check lookup field
      IF @cDataType = ''
      BEGIN
         SET @nErrNo = 169651
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
         SET @nErrNo = 169652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad RefNoSetup
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
            ' AND Rectype = ''Normal'' ' +
            ' AND Status = ''0'' ' +
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
         SET @nErrNo = 169653
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --RefNo NotInASN
         GOTO Quit
      END
  END
Quit:

END

GO