SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_638ExtUpd03                                     */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-01-07 1.0  Ung        WMS-15663 Created                         */
/* 2022-09-23 1.1  YeeKung    WMS-20820 Extended refno length (yeekung01)*/
/************************************************************************/

CREATE   PROC [RDT].[rdt_638ExtUpd03] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
   @cReceiptKey   NVARCHAR( 10),
   @cRefNo        NVARCHAR( 60), --(yeekung01)
   @cID           NVARCHAR( 18),
   @cLOC          NVARCHAR( 10),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @cLottable01   NVARCHAR( 18),
   @cLottable02   NVARCHAR( 18),
   @cLottable03   NVARCHAR( 18),
   @dLottable04   DATETIME,
   @dLottable05   DATETIME,
   @cLottable06   NVARCHAR( 30),
   @cLottable07   NVARCHAR( 30),
   @cLottable08   NVARCHAR( 30),
   @cLottable09   NVARCHAR( 30),
   @cLottable10   NVARCHAR( 30),
   @cLottable11   NVARCHAR( 30),
   @cLottable12   NVARCHAR( 30),
   @dLottable13   DATETIME,
   @dLottable14   DATETIME,
   @dLottable15   DATETIME,
   @cData1        NVARCHAR( 60),
   @cData2        NVARCHAR( 60),
   @cData3        NVARCHAR( 60),
   @cData4        NVARCHAR( 60),
   @cData5        NVARCHAR( 60),
   @cOption       NVARCHAR( 1),
   @dArriveDate   DATETIME,
   @tExtUpdateVar VariableTable READONLY,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount           INT
   DECLARE @curRD                CURSOR
   DECLARE @cReceiptLineNumber   NVARCHAR( 5) = ''
   DECLARE @nReceived            INT = 0
   DECLARE @cIT69Label           NVARCHAR( 10)
   DECLARE @cCaseIDLabel         NVARCHAR( 10)

   SET @nErrNo = 0

   IF @nFunc = 638 -- ECOM return
   BEGIN
      IF @nStep = 1 -- RefNo, ASN
      BEGIN
         IF @nInputKey = 1
         BEGIN
            SET @cIT69Label = rdt.rdtGetConfig( @nFunc, 'IT69Label', @cStorerKey)
            IF @cIT69Label = '0'
               SET @cIT69Label = ''

            SET @cCaseIDLabel = rdt.rdtGetConfig( @nFunc, 'CaseIDLabel', @cStorerKey)
            IF @cCaseIDLabel = '0'
               SET @cCaseIDLabel = ''

            IF @cIT69Label <> '' OR @cCaseIDLabel <> ''
            BEGIN
               DECLARE @bSuccess    INT
               DECLARE @cUDF02      NVARCHAR( 30)
               DECLARE @cCOO        NVARCHAR( 20)
               DECLARE @cLabelLot   NVARCHAR( 12)
               DECLARE @cCaseID     NVARCHAR( 10)
               DECLARE @cLabelPrinter NVARCHAR(10)
               DECLARE @tIT69Label   AS VariableTable
               DECLARE @tCaseIDLabel AS VariableTable

               -- Get label printer
               SELECT @cLabelPrinter = Printer FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

               -- Get ReceiptInfo
               SELECT @cUDF02 = UserDefine02 FROM Receipt WITH (NOLOCK) WHERE ReceiptKey = @cReceiptKey

               IF @cUDF02 <> 'LabelPrinted'
               BEGIN
                  -- Loop ReceiptDetail
                  -- Print same label as FN593 option 8 - IT69Label BY ID.
                  SET @curRD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT RD.SKU, RD.Lottable02, RD.QTYExpected
                     FROM dbo.Receipt R WITH (NOLOCK)
                        JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey)
                     WHERE R.ReceiptKey = @cReceiptKey
                        AND RD.QTYExpected > 0
                  OPEN @curRD
                  FETCH NEXT FROM @curRD INTO @cSKU, @cLottable02, @nQTY
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     IF @cIT69Label <> ''
                     BEGIN
                        SET @cCOO = RIGHT(@cLottable02,2)
                        SET @cLabelLot = Substring(@cLottable02,1,12)

                        DELETE FROM @tIT69Label
                        INSERT INTO @tIT69Label (Variable, Value) VALUES
                           ( '@cSKU',     @cSKU),
                           ( '@cCOO',     @cCOO),
                           ( '@cLOT',     @cLabelLot),
                           ( '@cQTY',     CAST( @nQTY AS NVARCHAR( 5))),
                           ( '@cOption',  '8') --@cPrintOption

                        -- Print label
                        EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, '',
                           @cIT69LABEL, -- Report type
                           @tIT69Label, -- Report params
                           'rdt_638ExtUpd03',
                           @nErrNo  OUTPUT,
                           @cErrMsg OUTPUT
                        IF @nErrNo <> 0
                           GOTO Quit
                     END

                     IF @cCaseIDLabel <> ''
                     BEGIN
                     	WHILE @nQTY > 0
                     	BEGIN
                        	EXECUTE dbo.nspg_GetKey
                        		'CaseID',
                        		8,
                        		@cCaseID   OUTPUT,
                        		@bSuccess  OUTPUT,
                        		@nErrNo    OUTPUT,
                        		@cErrMsg   OUTPUT
                           IF @bSuccess <> 1
                              GOTO Quit

                           SET @cCaseID = 'RT' + @cCaseID

                           DELETE FROM @tCaseIDLabel
                           INSERT INTO @tCaseIDLabel (Variable, Value) VALUES
                              ( '@cCaseID', @cCaseID)

                           -- Print label
                           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, '',
                              @cCaseIDLabel, -- Report type
                              @tCaseIDLabel, -- Report params
                              'rdt_638ExtUpd03',
                              @nErrNo  OUTPUT,
                              @cErrMsg OUTPUT
                           IF @nErrNo <> 0
                              GOTO Quit

                           SET @nQTY = @nQTY - 1
                        END
                     END

                     FETCH NEXT FROM @curRD INTO @cSKU, @cLottable02, @nQTY
                  END

                  SET @nTranCount = @@TRANCOUNT
                  BEGIN TRAN
                  SAVE TRAN rdt_638ExtUpd03

                  UPDATE Receipt SET
                     UserDefine02 = 'LabelPrinted',
                     EditDate = GETDATE(),
                     EditWho = SUSER_SNAME()
                  WHERE ReceiptKey = @cReceiptKey
                  IF @@ERROR <> 0
                  BEGIN
                     ROLLBACK TRAN rdt_638ExtUpd03
                     WHILE @@TRANCOUNT > @nTranCount
                        COMMIT TRAN
                     GOTO Quit
                  END

                  WHILE @@TRANCOUNT > @nTranCount
                     COMMIT TRAN rdt_638ExtUpd03
               END
            END
         END
      END
   END

Quit:

END

GO