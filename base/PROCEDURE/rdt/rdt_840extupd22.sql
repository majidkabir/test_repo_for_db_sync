SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840ExtUpd22                                     */
/* Purpose: Print delivery notes and return notes                       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2022-10-24  1.0  James      WMS-21040. Created                       */
/************************************************************************/

CREATE   PROC [RDT].[rdt_840ExtUpd22] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR( 3),
   @nStep       INT,
   @nInputKey   INT,
   @cStorerkey  NVARCHAR( 15),
   @cOrderKey   NVARCHAR( 10),
   @cPickSlipNo NVARCHAR( 10),
   @cTrackNo    NVARCHAR( 20),
   @cSKU        NVARCHAR( 20),
   @nCartonNo   INT,
   @cSerialNo   NVARCHAR( 30),
   @nSerialQTY  INT,
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTranCount           INT
   DECLARE @cOrdType             NVARCHAR( 1)
   DECLARE @cDelNotes            NVARCHAR( 10)
   DECLARE @tDelNotes            VARIABLETABLE
   DECLARE @cPaperPrinter        NVARCHAR( 10)
   DECLARE @cPlatform            NVARCHAR( 20)
   DECLARE @cRtnNotes            NVARCHAR( 10)
   DECLARE @tRtnNotes            VARIABLETABLE
   DECLARE @cFacility            NVARCHAR( 5)
   DECLARE @cC_ISOCntryCode      NVARCHAR( 10)
   DECLARE @cDelNotesN           NVARCHAR( 10)
   DECLARE @tDelNotesN           VARIABLETABLE
   DECLARE @cRtnNotesN           NVARCHAR( 10)
   DECLARE @tRtnNotesN           VARIABLETABLE

   SET @nErrNo = 0
   
   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cOrdType = DocType,
                @cC_ISOCntryCode = C_ISOCntryCode,
                @cFacility = Facility
         FROM dbo.Orders WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey

         SELECT @cPlatform = [Platform]
         FROM dbo.OrderInfo WITH (NOLOCK)
         WHERE OrderKey = @cOrderKey
         
         IF @cOrdType = 'E' AND @cPlatform <> 'FF'
         BEGIN
            SELECT @cPaperPrinter = Printer_Paper
            FROM rdt.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF @cC_ISOCntryCode = 'KR' -- print korean version
            BEGIN
               SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'PREDELNOTE', @cStorerKey)
               IF @cDelNotes = '0'
                  SET @cDelNotes = ''

               SET @cRtnNotes = rdt.RDTGetConfig( @nFunc, 'PRERTNNOTE', @cStorerKey)
               IF @cRtnNotes = '0'
                  SET @cRtnNotes = ''

               IF @cDelNotes <> ''
               BEGIN
                  INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                  INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                  INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)

                 -- Print label
                 EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                    @cDelNotes, -- Report type
                    @tDelNotes, -- Report params
                    'rdt_840ExtUpd22',
                    @nErrNo  OUTPUT,
                    @cErrMsg OUTPUT
                    
                  IF @nErrNo <> 0
                     GOTO Quit
               END

               IF @cRtnNotes <> ''
               BEGIN
                  INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                  INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                  INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)

                 -- Print label
                 EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                    @cRtnNotes, -- Report type
                    @tRtnNotes, -- Report params
                    'rdt_840ExtUpd22',
                    @nErrNo  OUTPUT,
                    @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
            ELSE  -- @cC_ISOCntryCode = 'KR' print english version
            BEGIN
               SET @cDelNotesN = rdt.RDTGetConfig( @nFunc, 'PREDELNOTEN', @cStorerKey)
               IF @cDelNotesN = '0'
                  SET @cDelNotesN = ''

               SET @cRtnNotesN = rdt.RDTGetConfig( @nFunc, 'PRERTNNOTEN', @cStorerKey)
               IF @cRtnNotesN = '0'
                  SET @cRtnNotesN = ''

               IF @cDelNotesN <> ''
               BEGIN
                  INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                  INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                  INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)

                 -- Print label
                 EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                    @cDelNotesN, -- Report type
                    @tDelNotesN, -- Report params
                    'rdt_840ExtUpd22',
                    @nErrNo  OUTPUT,
                    @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END

               IF @cRtnNotesN <> ''
               BEGIN
                  INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)
                  INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
                  INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)

                  -- Print label
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,
                    @cRtnNotesN, -- Report type
                    @tRtnNotesN, -- Report params
                    'rdt_840ExtUpd22',
                    @nErrNo  OUTPUT,
                    @cErrMsg OUTPUT

                  IF @nErrNo <> 0
                     GOTO Quit
               END
            END
         END
      END
   END


   Quit:



GO