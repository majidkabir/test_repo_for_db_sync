SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1813ExtValid02                                        */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-07-17 1.0  ChewKP   WMS-1992 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1813ExtValid02] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFromID          NVARCHAR( 20), 
   @cOption          NVARCHAR( 1), 
   @cSKU             NVARCHAR( 20), 
   @nQty             INT, 
   @cToID            NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 1813
BEGIN
   
   DECLARE @cPickSlipNo NVARCHAR(10) 
          ,@cOrderKey   NVARCHAR(10) 
          ,@cSortCode   NVARCHAR(13)
          ,@cRoute      NVARCHAR(10) 
          ,@cExternOrderKey NVARCHAR(30) 
          ,@cPalletSortCode NVARCHAR(13) 


   SET @nErrNo = 0

   IF @nStep = 1 -- From  id
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   PalletKey = @cFromID
                     AND  [Status] <> '9')
         BEGIN
            SET @nErrNo = 112301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletNotclosed
            GOTO Quit               
         END
      END
   END

   IF @nStep = 4 -- To ID 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   PalletKey = @cToID
                     AND  [Status] <> '9')
         BEGIN
            SET @nErrNo = 112302
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletNotclosed
            GOTO Quit               
         END
      END
   END
   
   IF @nStep = 5 -- To ID 
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                     AND   PalletKey = @cToID
                     AND  [Status] <> '9')
         BEGIN
            SET @nErrNo = 112303
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- PalletNotclosed
            GOTO Quit               
         END
      END
   END
END

Quit:





GO