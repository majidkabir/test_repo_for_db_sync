SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_810ExtUpd01                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: HnM print dummy pickslip                                    */
/*                                                                      */
/* Called from:                                                         */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 01-10-2014  1.0  Ung          SOS317493 Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_810ExtUpd01] (
   @nMobile    INT,
   @nFunc      INT, 
   @cLangCode  NVARCHAR( 3),
   @nStep      INT,
   @nInputKey  INT,
   @cStorerKey NVARCHAR( 15),
   @cCartID    NVARCHAR( 10),
   @cOrderKey  NVARCHAR( 10),
   @cLightLoc  NVARCHAR( 10),
   @cToteID    NVARCHAR( 20),
   @bSuccess   INT            OUTPUT, 
   @nErrNo     INT            OUTPUT,
   @cErrMsg    NVARCHAR( 20)  OUTPUT   -- screen limitation, 20 NVARCHAR max
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 810 -- PTL order assign
   BEGIN
      IF @nStep = 2 -- Order
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Check order status
            IF NOT EXISTS( SELECT 1 FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND Status = '3')
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- OrderNotScanIn
            END
         END
      END
   END
END

GO