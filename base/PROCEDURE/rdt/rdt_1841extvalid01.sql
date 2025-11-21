SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1841ExtValid01                                        */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Purpose: Allow only 1 ASN 1 Lane 1 User                                    */
/*                                                                            */
/*                                                                            */
/* Date        Rev  Author       Purposes                                     */
/* 2021-04-12  1.0  James        WMS-16725. Created                           */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1841ExtValid01]
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
   
   DECLARE @cUserName      NVARCHAR( 18)
   
   SELECT @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   IF EXISTS ( SELECT 1 FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
               WHERE ReceiptKey = @cReceiptKey
               AND   Loc = @cLane
               AND   EditWho <> @cUserName
               AND   [Status] < '9')
   BEGIN
      SET @nErrNo = 165951
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Lane In Used
      GOTO Quit
   END
   
   Quit:

END


GO