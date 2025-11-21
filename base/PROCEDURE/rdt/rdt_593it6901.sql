SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Store procedure: rdt_593IT6901                                          */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2018-12-03 1.0  ChewKP   WMS-6444 Created                               */
/* 2019-11-08 1.1  James    WMS-11076 Add print by ID (james01)            */
/* 2020-02-18 1.2  Ung      LWP-55 Performance tuning                      */
/* 2022-11-29 1.3  LZG      JSM-110201 - Extended @cPrintOption (ZG01)     */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593IT6901] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(60),  -- OrderKey
   @cParam2    NVARCHAR(60),
   @cParam3    NVARCHAR(60),
   @cParam4    NVARCHAR(60),
   @cParam5    NVARCHAR(60),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @b_Success     INT

   DECLARE @cDataWindow             NVARCHAR( 50)
          ,@cTargetDB               NVARCHAR( 20)
          ,@cLabelPrinter           NVARCHAR( 10)
          ,@cPaperPrinter           NVARCHAR( 10)
          ,@cQty                    NVARCHAR( 5)
          ,@nQTY                    INT
          ,@cSKU                    NVARCHAR( 20)
          ,@cCOO                    NVARCHAR( 20)
          ,@cLot                    NVARCHAR( 12)
          ,@n_Err                   INT
          ,@c_ErrMsg                NVARCHAR( 20)
          ,@cUserName               NVARCHAR( 18)
          ,@cFacility               NVARCHAR(  5)
          ,@cLottable02             NVARCHAR( 18)
          ,@cIT69                   NVARCHAR( 29)
          ,@cLoc                    NVARCHAR( 10)
          ,@cPrintOption            NVARCHAR( 2)   -- ZG01
          ,@cLabelLot               NVARCHAR( 12)
          ,@cID                     NVARCHAR( 18)

   DECLARE @curIT69 CURSOR
   DECLARE @tOutBoundList AS VariableTable

   SELECT @cFacility = Facility,
          @cUserName = UserName,
          @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper
   FROM rdt.rdtmobrec WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SELECT TOP 1 @cPrintOption = LabelSerialNo
   FROM dbo.BartenderLabelCfg WITH (NOLOCK)
   WHERE LabelType = 'IT69LABEL'
   AND Key01 = 'SKU'
   AND StorerKey = @cStorerKey

   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 132803
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   IF @cOption IN ( '6', '8')
   BEGIN
      IF @cOption = '6'
      BEGIN
         -- Parameter mapping
         SET @cLoc = @cParam1
         SET @CID = ''  -- (james01)

         -- Check if it is blank
         IF ISNULL(@cLoc, '') = ''
         BEGIN
            SET @nErrNo = 132801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LocReq
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
            GOTO Quit
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK)
                         WHERE Loc = @cLoc
                         AND Facility = @cFacility )
         BEGIN
            SET @nErrNo = 132802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLoc
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
            GOTO Quit
         END
         SET @curIT69 = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LLI.SKU, LA.Lottable02, SUM( LLI.QTY)
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.LOC = @cLOC
               AND LLI.QTY > 0
            GROUP BY LLI.SKU, LA.Lottable02
            ORDER BY LLI.SKU, LA.Lottable02
      END

      -- (james01)
      IF @cOption = '8'
      BEGIN
         -- Parameter mapping
         SET @cID = @cParam1
         SET @cLoc = ''

         -- Check if it is blank
         IF ISNULL(@cID, '') = ''
         BEGIN
            SET @nErrNo = 132807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Id Req
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
            GOTO Quit
         END

         IF NOT EXISTS ( SELECT 1 FROM dbo.LOTxLOCxID AS lli WITH (NOLOCK)
                         JOIN dbo.LOC AS l WITH (NOLOCK) ON ( lli.Loc = l.Loc)
                         WHERE lli.StorerKey = @cStorerKey
                         AND   lli.ID = @cID
                         AND   lli.Qty > 0
                         AND   l.Facility = @cFacility )
         BEGIN
            SET @nErrNo = 132808
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Id
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
            GOTO Quit
         END

         SET @curIT69 = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT LLI.SKU, LA.Lottable02, SUM( LLI.QTY)
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)
               JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (LA.LOT = LLI.LOT)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.ID = @cID
               AND LLI.QTY > 0
            GROUP BY LLI.SKU, LA.Lottable02
            ORDER BY LLI.SKU, LA.Lottable02
      END

      OPEN @curIT69
      FETCH NEXT FROM @curIT69 INTO @cSKU, @cLottable02, @nQTY
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @cCOO = RIGHT(@cLottable02,2)
         SET @cLabelLot = Substring(@cLottable02,1,12)

         DELETE FROM @tOutBoundList
         INSERT INTO @tOutBoundList (Variable, Value) VALUES
            ( '@cSKU',     @cSKU),
            ( '@cCOO',     @cCOO),
            ( '@cLot',     @cLabelLot),
            ( '@cQty',     CAST( @nQTY AS NVARCHAR( 5))),
            ( '@cOption',  @cPrintOption)

         -- Print label
         EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
            'IT69LABEL',    -- Report type
            @tOutBoundList, -- Report params
            'rdt_593IT6901',
            @nErrNo  OUTPUT,
            @cErrMsg OUTPUT
         IF @nErrNo <> 0
            GOTO Quit

         FETCH NEXT FROM @curIT69 INTO @cSKU, @cLottable02, @nQTY
      END
   END

   --SELECT @cParam1 '@cParam1' , @cParam2 '@@cParam2' , @cParam3 '@@cParam3' , @cParam4 '@@cParam4' , @cParam5 '@@cParam5'
   IF @cOption = '7'
   BEGIN
      SET @cIT69 = @cParam1
      SET @cQty  = @cParam3

      IF ISNULL( @cIT69 , '' ) = ''
      BEGIN
         SET @nErrNo = 132804
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelReq
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1
         GOTO Quit
      END

      IF ISNULL( @cQty , '' ) = ''
      BEGIN
         SET @nErrNo = 132805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --QtyReq
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1
         GOTO Quit
      END

      IF rdt.rdtIsValidQTY( @cQty, 0) = 0
      BEGIN
         SET @nErrNo = 132806
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidQty
         EXEC rdt.rdtSetFocusField @nMobile, 3 -- Param1
         GOTO Quit
      END

--      IT69 scanned data: 070179123040002201807100173CN
--      07 last 2 digits of the season code
--      0179123040002 -> WMS SKU
--      RIGHT(lotattribute.Lottable02,2)->[COO]
--      lotxlocxid.lot-> Lot
--      Additional info:
--      LOT#
--      201807100173

      --SUBSTRING(@cIT69,1,2) = Substring(lotattribute.lottable01,5,2)
      SET @cSKU = SUBSTRING(@cIT69,3,13)
      SET @cLot = SUBSTRING(@cIT69,16,12)
      SET @cCOO = SUBSTRING(@cIT69,28,2)

      --SELECT @cSKU '@cSKU' , @cCOO '@cCOO' , @cLot '@cLot' , @cQty '@cQty' , @cPrintOption '@cPrintOption' , @cLabelPrinter '@cLabelPrinter'

      DELETE FROM @tOutBoundList

      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cSKU',  @cSKU)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cCOO',  @cCOO)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLot',  @cLot)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cQty',  @cQty)
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cOption',  @cPrintOption)

      -- Print label
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',
         'IT69LABEL', -- Report type
         @tOutBoundList, -- Report params
         'rdt_593IT6901',
         @nErrNo  OUTPUT,
         @cErrMsg OUTPUT
      IF @nErrNo <> 0
         GOTO Quit
   END

Quit:

GO