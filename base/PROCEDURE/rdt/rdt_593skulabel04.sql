SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593SKULabel04                                      */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-10-03 1.0  Ung      WMS-6462 Created                               */
/* 2018-12-24 1.1  ChewKP   Performance Tuning (ChewKP01)                  */
/* 2019-04-22 1.2  ChewKP   WMS-8593 Add EventLog (ChewKP02)               */
/* 2021-05-18 1.3  YeeKung  WMS-17053 change asn to fromloc                */
/*                          (yeekung01)                                    */
/* 2023-02-17 1.4  YeeKung  JSM-128558 Add block (yeekung02)               */ 
/* 2022-07-15 1.5  Ung      WMS-20224 Add new mapping                      */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_593SKULabel04] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- ASN
   @cParam2    NVARCHAR(20),  -- RSO
   @cParam3    NVARCHAR(20),  -- SKU/UPC
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT           OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success     INT
   DECLARE @cLabelPrinter NVARCHAR( 10)
   DECLARE @cPaperPrinter NVARCHAR( 10)

   DECLARE @cReceiptKey   NVARCHAR( 10)
   DECLARE @cRDLineNo     NVARCHAR( 5)
   DECLARE @cLottable01   NVARCHAR( 20)
   DECLARE @cSKU          NVARCHAR( 20)
   DECLARE @cFromLOC      NVARCHAR( 10)
   DECLARE @cFromID       NVARCHAR( 18)
   DECLARE @cLOT          NVARCHAR( 10)
   DECLARE @cSuggestedLOC NVARCHAR( 10)

   DECLARE @cChkStorerKey NVARCHAR( 15)
   DECLARE @cChkFacility  NVARCHAR( 5)
   DECLARE @nRowRef       INT

   -- Parameter mapping
   SET @cFromLOC = @cParam1
   SET @cLottable01 = @cParam2 -- RSO
   SET @cSKU = @cParam3

   -- Check blank
   IF @cFromLOC = ''
   BEGIN
      SET @nErrNo = 129951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ASN
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
      GOTO Quit
   END


   -- Get facility
   DECLARE @cFacility NVARCHAR(5)
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile -- (ChewKP01)

   -- Check blank
   IF @cLottable01 = ''
   BEGIN
      SET @nErrNo = 129955
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
      EXEC rdt.rdtSetFocusField @nMobile, 4 -- ID
      GOTO Quit
   END
        -- Check blank
   IF @cSKU = ''
   BEGIN
      SET @nErrNo = 129957
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need SKU/UPC
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      GOTO Quit
   END

   -- Get SKU barcode count
   DECLARE @nSKUCnt INT
   EXEC rdt.rdt_GETSKUCNT
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU
      ,@nSKUCnt     = @nSKUCnt       OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT

   -- Check SKU/UPC
   IF @nSKUCnt = 0
   BEGIN
      SET @nErrNo = 129958
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid SKU
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      GOTO Quit
   END

   -- Check multi SKU barcode
   IF @nSKUCnt > 1
   BEGIN
      SET @nErrNo = 129959
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarCod
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      GOTO Quit
   END

   -- Get SKU code
   EXEC rdt.rdt_GETSKU
       @cStorerKey  = @cStorerKey
      ,@cSKU        = @cSKU          OUTPUT
      ,@bSuccess    = @b_Success     OUTPUT
      ,@nErr        = @nErrNo        OUTPUT
      ,@cErrMsg     = @cErrMsg       OUTPUT

   -- Get SKU label not yet printed
   SET @nRowRef = 0
   SELECT TOP 1
      @nRowRef = RowRef,
      @cSuggestedLOC = SuggestedLoc
   FROM RFPutaway RF WITH (NOLOCK)
      JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = RF.LOT)
      JOIN LOC WITH (NOLOCK) ON (RF.SuggestedLOC = LOC.LOC)
   WHERE RF.FromLOC = @cFromLOC
      -- AND FromID = @cFromID -- LoseID upon Exceed calc putaway
      AND RF.StorerKey = @cStorerKey
      AND RF.SKU = @cSKU
      AND LA.Lottable01 = @cLottable01
      AND RF.QTY > RF.QTYPrinted
      AND ISNULL( RF.UDF01, '') = '' -- piece only
   ORDER BY LOC.LocationGroup

   IF @nRowRef = 0
   BEGIN
      SET @nErrNo = 129962
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over scanned
      EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU
      GOTO Quit
   END

   -- Mark 1 QTY as printed    
   UPDATE RFPutaway SET    
      QTYPrinted = QTYPrinted + 1    
   WHERE RowRef = @nRowRef   
   AND QTY > QTYPrinted    
   --IF @@ERROR <> 0    
   --BEGIN    
   --   SET @nErrNo = 129963    
   --   SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RFLog Fail    
   --   EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU    
   --   GOTO Quit    
   --END    
   --(yeekung02)(work)  
   IF @@ROWCOUNT =0  
   BEGIN  
      SELECT TOP 1     
         @nRowRef = RowRef,     
         @cSuggestedLOC = SuggestedLoc    
      FROM RFPutaway RF WITH (NOLOCK)    
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LA.LOT = RF.LOT)    
      WHERE RF.FromLOC = @cFromLOC    
         -- AND FromID = @cFromID -- LoseID upon Exceed calc putaway    
         AND RF.StorerKey = @cStorerKey    
         AND RF.SKU = @cSKU    
         AND LA.Lottable01 = @cLottable01    
         AND RF.QTY > RF.QTYPrinted    
  
  
      IF @nRowRef = 0    
      BEGIN    
         SET @nErrNo = 129962    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over scanned    
         EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU    
         GOTO Quit    
      END    
    
      -- Mark 1 QTY as printed    
      UPDATE RFPutaway SET    
         QTYPrinted = QTYPrinted + 1    
      WHERE RowRef = @nRowRef   
      IF @@ERROR <> 0    
      BEGIN    
         SET @nErrNo = 129963    
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD RFLog Fail    
         EXEC rdt.rdtSetFocusField @nMobile, 6 --SKU    
         GOTO Quit    
      END    
   END  

   -- Get login info
   SELECT
      @cLabelPrinter = Printer,
      @cPaperPrinter = Printer_Paper,
      @cFacility = Facility
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Storer configure
   DECLARE @cSKULabel NVARCHAR(10)
   SET @cSKULabel = rdt.rdtGetConfig( @nFunc, 'SKULabel', @cStorerKey)

   IF @cSKULabel <> ''
   BEGIN
      -- Report params
      DECLARE @tSKULabel AS VariableTable
      INSERT INTO @tSKULabel (Variable, Value) VALUES
         ( '@cFromLOC',       @cFromLOC),
         ( '@cSKU',           @cSKU),
         ( '@cLottable01',    @cLottable01),
         ( '@cSuggestedLOC',  @cSuggestedLOC)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, 1, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,
         @cSKULabel, -- Report type
         @tSKULabel, -- Report params
         'rdt_593SKULabel04',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

   -- (ChewKP02)
   EXEC RDT.rdt_STD_EventLog
    @cActionType = '3',
        --@cUserID     = @cUserName,
        @nMobileNo   = @nMobile,
        @nFunctionID = @nFunc,
        @cFacility   = @cFacility,
        @cStorerKey  = @cStorerkey,
        @cReceiptKey = @cReceiptKey,
        @cLottable01 = @cLottable01,
        @cSKU        = @cSKU,
        @nStep       = @nStep

Quit:


GO