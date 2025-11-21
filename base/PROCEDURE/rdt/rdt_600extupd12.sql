SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_600ExtUpd12                                           */
/* Copyright    Maersk                                                        */
/*                                                                            */
/* Purpose: PMI Pallet and UCC length issue in RDT                            */
/*                                                                            */
/* Date           Author    Ver.       Purposes                               */
/* 2024-11-12 1.0  CYU027   FCR-759    UPDATE ID UDF01                        */
/******************************************************************************/

CREATE   PROC rdt.rdt_600ExtUpd12 (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cFacility    NVARCHAR( 5),
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cPOKey       NVARCHAR( 10),
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
   @nQTY         INT,            --pass in decode count
   @cReasonCode  NVARCHAR( 10),
   @cSuggToLOC   NVARCHAR( 10),
   @cFinalLOC    NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cUserDefine01       NVARCHAR( 60)

   BEGIN

      SELECT @cUserDefine01 = V_String12
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile

      IF @nFunc = 600
      BEGIN
         IF @nStep = 6 -- QTY screen
         BEGIN

            IF @nInputKey = 1
            BEGIN

               IF EXISTS(SELECT 1 FROM [dbo].[ID] WHERE [Id] = @cID)
               BEGIN
                  UPDATE [dbo].[ID] SET [UserDefine01] = ISNULL(@cUserDefine01, N'') WHERE [Id] = @cID
                  IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 226752
                        SET @cErrMsg = [rdt].[rdtGetMessage]( @nErrNo, @cLangCode, N'DSP') --'UpdUDF01Fail'
                        GOTO Quit
                     END
               END
            END

         END
      END
   END

Quit:

END

GO