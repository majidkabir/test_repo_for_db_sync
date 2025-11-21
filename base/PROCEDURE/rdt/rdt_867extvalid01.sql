SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_867ExtValid01                                   */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Filter certain orders                                       */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2020-04-27  1.0  James       WMS-13041. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_867ExtValid01]
   @nMobile        INT, 
   @nFunc          INT,     
   @nStep          INT,      
   @cLangCode      NVARCHAR( 3),      
   @cUserName      NVARCHAR( 18),     
   @cFacility      NVARCHAR( 5),      
   @cStorerKey     NVARCHAR( 15),     
   @cOrderKey      NVARCHAR( 10),     
   @cSKU           NVARCHAR( 20),     
   @cTracKNo       NVARCHAR( 18),    
   @cSerialNo      NVARCHAR( 30),     
   @cExtValidate   VARIABLETABLE READONLY, 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey      INT
   
   SELECT @nInputKey = InputKey
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   IF @nStep = 1  -- Orderkey
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.ORDERS WITH (NOLOCK)
                     WHERE OrderKey = @cOrderKey
                     AND   DocType = 'E'
                     AND   [Type] = 'VIP')
         BEGIN
            SET @nErrNo = 151301
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- JITX Orders
            GOTO Quit
         END
      END
   END

Quit:
END

GO