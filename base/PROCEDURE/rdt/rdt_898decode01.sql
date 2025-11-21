SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/******************************************************************************/
/* Store procedure: rdt_898Decode01                                          */
/* Copyright: Maersk                                                          */
/*                                                                            */
/* Purpose: Decode PMI GS1 ID/UCC Label                                       */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 08-10-2024  CYU027
   1.0   Created                                        */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_898Decode01] (
   @nMobile             INT,
   @nFunc               INT,
   @cLangCode           NVARCHAR( 3),
   @nStep               INT,
   @nInputKey           INT,
   @cStorerKey          NVARCHAR( 15),
   @cReceiptKey         NVARCHAR( 10),
   @cPOKey              NVARCHAR( 10),
   @cLOC                NVARCHAR( 10),
   @cUCC                NVARCHAR( MAX)  OUTPUT,
   @nUCCQTY             INT            OUTPUT,
   @cUserDefine01       NVARCHAR(30)   OUTPUT,
   @cUserDefine02       NVARCHAR(30)   OUTPUT,
   @cUserDefine03       NVARCHAR(30)   OUTPUT,
   @cUserDefine04       NVARCHAR(30)   OUTPUT,
   @cUserDefine05       NVARCHAR(30)   OUTPUT,
   @cUserDefine06       NVARCHAR(30)   OUTPUT,
   @cUserDefine07       NVARCHAR(30)   OUTPUT,
   @cUserDefine08       NVARCHAR(30)   OUTPUT,
   @cUserDefine09       NVARCHAR(30)   OUTPUT,
   @cLottable01         NVARCHAR( 18)  OUTPUT,
   @cLottable02         NVARCHAR( 18)  OUTPUT,
   @cLottable03         NVARCHAR( 18)  OUTPUT,
   @dLottable04         DATETIME       OUTPUT,
   @dLottable05         DATETIME       OUTPUT,
   @cLottable06         NVARCHAR( 30)  OUTPUT,
   @cLottable07         NVARCHAR( 30)  OUTPUT,
   @cLottable08         NVARCHAR( 30)  OUTPUT,
   @cLottable09         NVARCHAR( 30)  OUTPUT,
   @cLottable10         NVARCHAR( 30)  OUTPUT,
   @cLottable11         NVARCHAR( 30)  OUTPUT,
   @cLottable12         NVARCHAR( 30)  OUTPUT,
   @dLottable13         DATETIME       OUTPUT,
   @dLottable14         DATETIME       OUTPUT,
   @dLottable15         DATETIME       OUTPUT,
   @nErrNo              INT            OUTPUT,
   @cErrMsg             NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLocalUCC AS NVARCHAR(20)
   DECLARE @cID AS NVARCHAR(18)

   IF @nFunc = 898 -- UCC receiving
   BEGIN
      IF @nStep = 3 -- ToID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cUCC <> '' --Barcode
            BEGIN
               IF LEN( LTRIM(RTRIM( @cUCC))) <> 25
               BEGIN
                  SET @nErrNo = 226801
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Quit
               END

               SET @cID = SUBSTRING( @cUCC, 8, 25)
               SET @cUserDefine08 = SUBSTRING( @cUCC,1 ,7)
               SET @cUCC = @cID

               GOTO Quit
            END
         END
      END

      IF @nStep = 6 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cUCC <> ''
            BEGIN
               IF LEN( LTRIM(RTRIM( @cUCC))) <> 40
               BEGIN
                  SET @nErrNo = 226802
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
                  GOTO Quit
               END

               SET @cLocalUCC = SUBSTRING( @cUCC, 21, 40)
               SET @cUserDefine09 = SUBSTRING( @cUCC,1 ,20)
               SET @cUCC = @cLocalUCC

               GOTO Quit
            END
         END
      END
   END

   Quit:

   UPDATE RDTMOBREC WITH (ROWLOCK) SET
     V_String38 = @cUserDefine08,
     V_String39 = @cUserDefine09
   WHERE Mobile = @nMobile

END

GO