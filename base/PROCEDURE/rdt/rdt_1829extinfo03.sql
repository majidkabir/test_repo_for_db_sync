SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1829ExtInfo03                                         */
/* Purpose: Display total UCC count of asn                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2018-Feb-05 1.0  James    WMS3858 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1829ExtInfo03] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15),
   @cParam1          NVARCHAR( 20),
   @cParam2          NVARCHAR( 20),
   @cParam3          NVARCHAR( 20),
   @cParam4          NVARCHAR( 20),
   @cParam5          NVARCHAR( 20),
   @cUCCNo           NVARCHAR( 20),
   @cExtendedInfo1   NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

   DECLARE @nCount         INT
   DECLARE @cReceiptKey    NVARCHAR( 10)
   DECLARE @cUserName      NVARCHAR( 18)

   SET @cReceiptKey = @cParam1
   
   SELECT @cUserName = UserName FROM RDT.RDTMobRec WITH (NOLOCK) WHERE MOBILE = @nMobile

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         SET @nCount = 0
         SELECT @nCount = COUNT( DISTINCT UCCNo)
         FROM rdt.rdtPreReceiveSort2Log WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   ReceiptKey = @cReceiptKey
         AND   [Status] < '9' 

         SET @cExtendedInfo1 = 'UCC SCANNED:' + CAST( @nCount AS NVARCHAR( 5))
      END   -- ENTER
   END   

Quit:



GO