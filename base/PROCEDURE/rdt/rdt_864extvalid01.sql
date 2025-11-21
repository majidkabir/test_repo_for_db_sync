SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_864ExtValid01                                         */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Validate if dropid to scan already contain other consignee        */
/*                                                                            */
/* Date        Author    Ver.  Purposes                                       */
/* 29-03-2018  James     1.0   WMS4127. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_864ExtValid01] (
   @nMobile         INT,
   @nFunc           INT,
   @nStep           INT,
   @nInputKey       INT,
   @cLangCode       NVARCHAR( 3),
   @cStorerkey      NVARCHAR( 15),
   @cID             NVARCHAR( 18),
   @cConsigneeKey   NVARCHAR( 15),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cDropID         NVARCHAR( 20),
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cDropID_Store     NVARCHAR( 15)

   IF @nFunc = 864 -- Pick To Drop ID
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF @nStep = 4 -- DROP ID
         BEGIN
            -- Check if drop id empty. If empty no need check
            IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK)
                        WHERE StorerKey = @cStorerkey
                        AND   DropID = @cDropID
                        AND   [Status] < '9') 
            BEGIN
               SELECT TOP 1 @cDropID_Store = O.ConsigneeKey
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.OrderDetail OD WITH (NOLOCK) 
                  ON ( PD.OrderKey = OD.OrderKey AND PD.OrderLineNumber = OD.OrderLineNumber)
               JOIN dbo.Orders O WITH (NOLOCK) ON ( OD.OrderKey = O.OrderKey)
               WHERE PD.StorerKey = @cStorerkey
               AND   PD.DropID = @cDropID
               AND   PD.Status < '9'
               ORDER BY 1

               IF @cDropID_Store <> @cConsigneeKey
               BEGIN
                  SET @nErrNo = 122701
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'TOID MIX STORE'
                  GOTO Quit
               END
            END
         END
      END   -- @@nInputKey = 1
   END

Quit:

END

GO