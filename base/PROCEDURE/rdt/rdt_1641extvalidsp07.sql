SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1641ExtValidSP07                                */
/* Purpose: Validate Pallet DropID                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-04-03 1.0  James      WMS8502 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP07] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cConsigneeKey       NVARCHAR(15),
           @dDelivery_Date      DATETIME,
           @cPltConsigneeKey    NVARCHAR(15),
           @dPltDelivery_Date   DATETIME,
           @cPltUCCNo           NVARCHAR( 20)

   IF @nStep = 3
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SET @nErrNo = 0

         SELECT TOP 1 @cPltUCCNo = ChildID
         FROM DropIDDetail WITH (NOLOCK)
         WHERE DropID = @cDropID
         ORDER BY 1

         -- 1st UCC then no need check anymore
         IF @@ROWCOUNT = 0
            GOTO Quit

         -- 1st UCC info
         SELECT @cPltConsigneeKey = O.ConsigneeKey,
                @dPltDelivery_Date = O.DeliveryDate
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         WHERE PD.DropID = @cPltUCCNo
         AND PD.Status >= '5'

         -- incoming UCC info
         SELECT @cConsigneeKey = O.ConsigneeKey,
                @dDelivery_Date = O.DeliveryDate
         FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.Orders O WITH (NOLOCK) ON PD.OrderKey = O.OrderKey
         WHERE PD.DropID = @cUCCNo
         AND PD.Status >= '5'

         IF @cPltConsigneeKey <> @cConsigneeKey
         BEGIN
            SET @nErrNo = 137351
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff Consignee'
            GOTO Quit
         END

         IF @dPltDelivery_Date <> @dDelivery_Date
         BEGIN
            SET @nErrNo = 137352
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Diff Delivery'
            GOTO Quit
         END
      END
   END

QUIT:

GO