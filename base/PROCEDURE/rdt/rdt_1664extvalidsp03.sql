SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1664ExtValidSP03                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-08-14 1.0  Ung        WMS-5993 Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_1664ExtValidSP03] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerKey      NVARCHAR( 15),
   @cMBOLKey        NVARCHAR( 10),
   @cOrderKey       NVARCHAR( 10),
   @cTrackNo        NVARCHAR( 18),
   @nValid          INT            OUTPUT,
   @nErrNo          INT            OUTPUT,
   @cErrMsg         NVARCHAR( 20)  OUTPUT,
   @cErrMsg1        NVARCHAR( 20)  OUTPUT,
   @cErrMsg2        NVARCHAR( 20)  OUTPUT,
   @cErrMsg3        NVARCHAR( 20)  OUTPUT,
   @cErrMsg4        NVARCHAR( 20)  OUTPUT,
   @cErrMsg5        NVARCHAR( 20)  OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 1664 -- Track no to MBOL creation
BEGIN
   -- IF @nStep = 2 -- Track no
   -- BEGIN
      -- IF @nInputKey = 1 -- ENTER
      -- BEGIN
         -- Cannot Mix Route --
         IF EXISTS( SELECT TOP 1 1
            FROM dbo.OrderDetail OD WITH (NOLOCK)
               JOIN dbo.SKU WITH (NOLOCK) ON (OD.StorerKey = SKU.StorerKey AND OD.SKU = SKU.SKU)
            WHERE OD.OrderKey = @cOrderKey
               AND SKU.BUSR1 = 'Y'
               AND ISNULL( OD.Notes, '') = '')
         BEGIN
             SET @nErrNo = 127951
             SET @cErrMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OD NoteIsBlank
             
             SET @nValid = 0 -- Insert message queue
             GOTO QUIT
         END
      -- END
   -- END
END

Quit:


GO