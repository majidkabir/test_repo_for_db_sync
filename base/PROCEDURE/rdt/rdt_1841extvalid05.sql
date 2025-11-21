SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/******************************************************************************/
/* Store procedure: rdt_1841ExtValid05                                        */
/* Copyright      : MAERSK                                                    */
/* Customer: For Amazon                                                       */
/* Called from    : rdtfnc_PrePalletizeSort                                   */
/* Purpose: Check UserDefine02 in UCC                                         */
/*                                                                            */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2023-10-23  1.0.0  XLL045       FCR-1066. Created                          */
/******************************************************************************/

CREATE   PROCEDURE rdt.rdt_1841ExtValid05
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cReceiptKey    NVARCHAR( 10),
   @cLane          NVARCHAR( 10),
   @cUCC           NVARCHAR( 20),
   @cToID          NVARCHAR( 18),
   @cSKU           NVARCHAR( 20),
   @nQty           INT,
   @cOption        NVARCHAR( 1),
   @cPosition      NVARCHAR( 20),
   @tExtValidVar   VariableTable READONLY,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
   @cUserDefine02        NVARCHAR( 20)='',
   @cDisAllowMixPallet   NVARCHAR( 50),
   @cColumn              NVARCHAR( 30)  

   SET @cDisAllowMixPallet = ISNULL(rdt.RDTGetConfig( @nFunc, 'DisAllowMixPallet', @cStorerKey),'')

   IF @nFunc = 1841
   BEGIN 
      IF @nStep = 3 -- ToID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cDisAllowMixPallet <> '0'
            BEGIN
               
               DECLARE LIST CURSOR FOR 
               SELECT Code2 FROM codelkup (NOLOCK) WHERE Listname = @cDisAllowMixPallet 
               AND Storerkey = @cStorerKey AND Code = '1841'
               OPEN LIST
               FETCH NEXT FROM LIST INTO @cColumn
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  IF @cColumn = 'UserDefine02'
                  BEGIN
                     SELECT TOP 1 @cUserDefine02 = ISNULL(RD.UserDefine02,'')
                     FROM dbo.Receipt R WITH (NOLOCK)
                        INNER JOIN dbo.ReceiptDetail RD WITH (NOLOCK) ON R.ReceiptKey  = RD.ReceiptKey
                     WHERE R.Facility = @cFacility AND R.StorerKey = @cStorerKey
                        AND R.ReceiptKey = @cReceiptKey
                        AND RD.ToId = @cToID
                     ORDER BY RD.ReceiptLineNumber
                     IF @cUserDefine02 <> '' AND @cUserDefine02 <> @cPosition
                     BEGIN
                        SET @nErrNo = 147744
                        SET @cErrMsg = rdt.rdtgetmessageLong( @nErrNo, @cLangCode, 'DSP') --147744 Mix Position Not Allowed
                        GOTO CLOSELIST
                     END
                     GOTO CLOSELIST
                  END
                  FETCH NEXT FROM LIST INTO @cColumn
               END
               GOTO CLOSELIST
            END
         END
      END
   END
   GOTO Quit
   CLOSELIST:
      CLOSE LIST
      DEALLOCATE LIST
      GOTO Quit
   Quit:

END
GO