SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP06                                      */
/* Purpose: Validate Pallet DropID                                            */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author  Purposes                                           */
/* 2017-08-17 1.0  Ung     WMS-2718 Created                                   */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP06] (
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
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1641 -- Build pallet
   BEGIN
      IF @nStep = 3 -- UCC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Some carton on pallet
            IF EXISTS( SELECT 1 FROM dbo.DropIDDetail WITH (NOLOCK) WHERE DropID = @cDropID) 
            BEGIN 
               DECLARE @cChkCaseID     NVARCHAR( 20)
               DECLARE @cChkPickSlipNo NVARCHAR( 10)
               DECLARE @cChkOrderKey   NVARCHAR( 10)
               DECLARE @cPickSlipNo    NVARCHAR( 10)
               DECLARE @cOrderKey      NVARCHAR( 10)
   
               -- Get first carton
               SELECT TOP 1 
                  @cChkCaseID = ChildID
               FROM dbo.DropIDDetail WITH (NOLOCK) 
               WHERE DropID = @cDropID 
               ORDER BY ChildID
               
               -- Get first carton info
               SELECT @cChkPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cChkCaseID 
               SELECT @cChkOrderKey = OrderKey FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cChkPickSlipNo 
               
               -- Get current carton info
               SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cUCCNo
               SELECT @cOrderKey = OrderKey FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo 
   
               -- Check pallet same order
               IF @cChkOrderKey <> @cOrderKey
               BEGIN
                  SET @nErrNo = 113901
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff order
                  GOTO Quit
               END
            END
         END
      END
   END

Quit:

END

GO