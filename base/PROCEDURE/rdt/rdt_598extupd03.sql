SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_598ExtUpd03                                           */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Extended putaway                                                  */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 17-04-2018  Ung       1.0   WMS-4043 Created                               */
/* 24-02-2020  Leong     1.1   INC1049672 - Revise BT Cmd parameters.         */
/******************************************************************************/

CREATE PROC [RDT].[rdt_598ExtUpd03] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cRefNo       NVARCHAR( 20),
   @cColumnName  NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cID          NVARCHAR( 18),
   @cSKU         NVARCHAR( 20),
   @cLottable01  NVARCHAR( 18),
   @cLottable02  NVARCHAR( 18),
   @cLottable03  NVARCHAR( 18),
   @dLottable04  DATETIME,
   @dLottable05  DATETIME,
   @cLottable06  NVARCHAR( 30),
   @cLottable07  NVARCHAR( 30),
   @cLottable08  NVARCHAR( 30),
   @cLottable09  NVARCHAR( 30),
   @cLottable10  NVARCHAR( 30),
   @cLottable11  NVARCHAR( 30),
   @cLottable12  NVARCHAR( 30),
   @dLottable13  DATETIME,
   @dLottable14  DATETIME,
   @dLottable15  DATETIME,
   @nQTY         INT,
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptKey  NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 598 -- Container receive
   BEGIN
      IF @nStep = 6 -- QTY
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cPickAndDropLOC  NVARCHAR( 10)
            DECLARE @cFitCasesInAisle NVARCHAR( 1)
            DECLARE @nPABookingKey    INT
            DECLARE @cPrinter         NVARCHAR( 10)
            DECLARE @cUserName        NVARCHAR( 18)
            DECLARE @cSubreasonCode   NVARCHAR( 10)

            -- Get login info
            SELECT
               @cSubReasonCode = I_Field11,
               @cPrinter = Printer,
               @cUserName = SUSER_SNAME()
            FROM rdt.rdtMobRec WITH (NOLOCK)
            WHERE Mobile = @nMobile

            -- Calc putaway
            IF @cSubReasonCode = '' -- Exclude VAS pallet
            BEGIN
               SET @nPABookingKey = 0

               -- Putaway
               EXEC rdt.rdt_1819ExtPASP10
                  @nFunc            = @nFunc,
                  @nMobile          = @nMobile,
                  @cLangCode        = @cLangCode,
                  @cUserName        = @cUserName,
                  @cStorerKey       = @cStorerKey,
                  @cFacility        = @cFacility,
                  @cFromLOC         = @cLOC,
                  @cID              = @cID,
                  @cSuggLOC         = @cSuggToLOC        OUTPUT,
                  @cPickAndDropLOC  = @cPickAndDropLOC   OUTPUT,
                  @cFitCasesInAisle = @cFitCasesInAisle  OUTPUT,
                  @nPABookingKey    = @nPABookingKey     OUTPUT,
                  @nErrNo           = @nErrNo            OUTPUT,
                  @cErrMsg          = @cErrMsg           OUTPUT
            END

            IF @cPrinter <> '' AND @cID <> ''
            BEGIN
               -- Print label
               EXEC dbo.isp_BT_GenBartenderCommand
                   @cPrinterID     = @cPrinter
                  ,@c_LabelType    = 'PALLETLABEL02'
                  ,@c_userid       = @cUserName
                  ,@c_Parm01       = '' -- @cReceiptKey -- Multi ReceiptKey
                  ,@c_Parm02       = @cID
                  ,@c_Parm03       = ''
                  ,@c_Parm04       = ''
                  ,@c_Parm05       = ''
                  ,@c_Parm06       = ''
                  ,@c_Parm07       = ''
                  ,@c_Parm08       = ''
                  ,@c_Parm09       = ''
                  ,@c_Parm10       = ''
                  ,@c_StorerKey    = @cStorerKey
                  ,@c_NoCopy       = '1'  --@c_NoCopy
                  ,@b_Debug        = '0'  --@b_Debug
                  ,@c_Returnresult = 'N'  --@c_Returnresult
                  ,@n_err          = @nErrNo  OUTPUT
                  ,@c_errmsg       = @cErrMsg OUTPUT
            END
         END
      END
   END

Quit:
END

GO