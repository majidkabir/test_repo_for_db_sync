SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593PalletLabel03                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2024-06-06 1.0  Dennis   FCR-401  Created                               */
/***************************************************************************/

CREATE   PROC rdt.rdt_593PalletLabel03 (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ASN NO
   @cParam2    NVARCHAR(20),  -- Qty
   @cParam3    NVARCHAR(20),  -- Prefix
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)
   DECLARE @cID           NVARCHAR( 20)
   DECLARE @cFacility     NVARCHAR( 5)
   DECLARE @cSKU          NVARCHAR( 20)
   DECLARE @cPalletLabel  NVARCHAR( 10)
   DECLARE @nRowCount     INT
   DECLARE 
   @nQty          INT,
   @cReceiptKey   NVARCHAR( 20),
   @cPrefix       NVARCHAR( 20),
   @cMaxpalletqtyprint NVARCHAR( 20),
   @cMaxCount     NVARCHAR( 20),
   @nMaxCount     INT,
   @cPrefixCode   NVARCHAR( 20),
   @cDoor         NVARCHAR( 20),
   @cTrailerID    NVARCHAR( 50)
   DECLARE @delimiter CHAR(1) = ','

   
   SET @cReceiptKey = @cParam1
   SET @cPrefix     = ISNULL(@cParam3,'')

   -- Get login info
   SELECT
      @cFacility = Facility,
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Check Receipt Key
   SELECT @cDoor = R.WAREHOUSEREFERENCE,@cTrailerID = R.ContainerKey
   FROM dbo.Receipt R WITH (NOLOCK)
   INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
   WHERE RD.ReceiptKey = @cReceiptKey AND R.Facility = @cFacility AND R.StorerKey = @cStorerKey
   SET @nRowCount = @@ROWCOUNT

   IF @nRowCount = 0
   BEGIN
      SET @nErrNo = 216401
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid ASN No
      GOTO Quit
   END

   IF @cParam2 <> '' AND RDT.rdtIsValidQTY( @cParam2, 0) = 0 OR ISNULL(@cParam2,'')=''
   BEGIN
      SET @nErrNo = 216402
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Qty
      GOTO Quit
   END
   SET @nQty = CAST( @cParam2 AS INT)

   SET @cMaxpalletqtyprint = rdt.RDTGetConfig( @nFunc, 'Maxpalletqtyprint', @cStorerKey)
   IF ISNULL(@cMaxpalletqtyprint,'0') = '0' OR CHARINDEX(@delimiter, @cMaxpalletqtyprint) = 0
   BEGIN
      SET @nErrNo = 216403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --216403MaxpalletqtyprintNotConfigured
      GOTO Quit
   END
   SET @cMaxCount = LEFT(@cMaxpalletqtyprint, CHARINDEX(@delimiter, @cMaxpalletqtyprint) - 1)
   SET @cPrefixCode =  SUBSTRING(@cMaxpalletqtyprint, CHARINDEX(@delimiter, @cMaxpalletqtyprint) + 1, LEN(@cMaxpalletqtyprint)) 
   IF ISNULL(@cMaxCount,'')='' OR (@cMaxCount <> '' AND RDT.rdtIsValidQTY( @cMaxCount, 0) = 0)
   BEGIN
      SET @nErrNo = 216403
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --216403MaxpalletqtyprintNotConfigured
      GOTO Quit
   END
   SET @nMaxCount = CAST( @cMaxCount AS INT)
   IF @nQTY > @nMaxCount
   BEGIN
      SET @nErrNo = 216404
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --216404Qty Entered More Than Max Allowed
      GOTO Quit
   END
   IF LEN(@cPrefix) > 5
   BEGIN
      SET @nErrNo = 216406
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --216406 Prefix Too Long
      GOTO Quit
   END
   IF NOT EXISTS 
   (SELECT 1 FROM dbo.CodeLKUP WITH (NOLOCK)
   WHERE ListName = @cPrefixCode
   AND Storerkey = @cStorerkey
   AND Code = @cPrefix)
   BEGIN
      SET @nErrNo = 216405
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --216405Prefix Not Match
      GOTO Quit
   END

   /*-------------------------------------------------------------------------------

                                      Print pallet label

   -------------------------------------------------------------------------------*/
   -- Get storer config
   SET @cPalletLabel = rdt.RDTGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
   IF @cPalletLabel = '0'
      SET @cPalletLabel = ''

   -- Check report setup
   IF @cPalletLabel = ''
   BEGIN
      SET @nErrNo = 119104
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --RPTypeNotSetup
      GOTO Quit
   END

   DECLARE @counter INT = 1,@b_success INT = 1
   DECLARE @cDate   NVARCHAR(10)
   SET @cDate = FORMAT(GETDATE(),  'd')

   WHILE @counter <= @nQty
   BEGIN
      DECLARE @tPalletLabel VariableTable
      EXECUTE dbo.nspg_GetKey
                  'ID',
                  7 ,
                  @cID               OUTPUT,
                  @b_success         OUTPUT,
                  @nErrNo            OUTPUT,
                  @cErrMsg           OUTPUT
      IF @b_success <> 1
      BEGIN
         SET @nErrNo = 59418
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --AutoGenID Fail
         GOTO Quit
      END
      SET @cID = CONCAT(@cPrefix , @cID)
      INSERT INTO @tPalletLabel (Variable, Value) VALUES
      ( '@cReceiptKey', @cReceiptKey),
      ( '@cID',        @cID),
      ( '@cDate',      @cDate),
      ( '@cDoor',      @cDoor),
      ( '@cTrailerID',      @cTrailerID)

      SET @nErrNo = 59418
      SET @cErrMsg = '@cReceiptKey' + @cReceiptKey --AutoGenID Fail
      GOTO Quit
   
      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
      @cPalletLabel, -- Report type
      @tPalletLabel, -- Report params
      'rdt_593PalletLabel03',
      @nErrNo  OUTPUT,
      @cErrMsg OUTPUT

      IF @nErrNo <> 0
         GOTO Quit
      DELETE FROM  @tPalletLabel
      SET @cID = ''
      SET @counter = @counter + 1
   END

Quit:

GO