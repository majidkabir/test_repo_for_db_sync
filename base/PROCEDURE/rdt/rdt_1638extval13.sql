SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal13                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Validate case with same orderdetail.userdefine02 can be     */
/*          scan into same pallet                                       */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-05-08  1.0  James     WMS-16947 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal13] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 3 -- CaseID
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            IF @cPalletKey <> ''
            BEGIN
               DECLARE @cPickSlipNo          NVARCHAR( 10) = ''
               DECLARE @cOrderKey            NVARCHAR( 10) = ''
               DECLARE @cUserDefine02        NVARCHAR( 20) = ''
               DECLARE @cPalletUserDefine02  NVARCHAR( 20) = ''
               DECLARE @cOrderLineNumber     NVARCHAR( 5) = ''
               DECLARE @cPalletCaseID        NVARCHAR( 20) = ''
               DECLARE @cPalletPickSlipNo    NVARCHAR( 10) = ''
               DECLARE @cPalletOrderKey      NVARCHAR( 10) = ''
               DECLARE @cPalletOrderLineNumber  NVARCHAR( 5) = ''

               IF EXISTS(SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND PalletKey = @cPalletKey)
			      BEGIN
                  -- Get case info
                  SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCaseID
                  SELECT @cOrderKey = OrderKey, @cOrderLineNumber = OrderLineNumber FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE Storerkey = @cStorerkey AND CaseID = @cCaseID AND [Status] < '9'
                  SELECT @cUserDefine02 = UserDefine02 FROM dbo.OrderDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey AND OrderLineNumber = @cOrderLineNumber

                  SELECT TOP 1 @cPalletCaseID = CaseID FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE PalletKey = @cPalletKey ORDER BY 1
                  SELECT @cPalletPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cPalletCaseID
                  SELECT @cPalletOrderKey = OrderKey, @cPalletOrderLineNumber = OrderLineNumber FROM dbo.PICKDETAIL WITH (NOLOCK) WHERE Storerkey = @cStorerkey AND CaseID = @cPalletCaseID AND [Status] < '9'
                  SELECT @cPalletUserDefine02 = UserDefine02 FROM dbo.OrderDetail WITH (NOLOCK) WHERE OrderKey = @cPalletOrderKey AND OrderLineNumber = @cPalletOrderLineNumber

                  IF  (@cUserDefine02 <> @cPalletUserDefine02)
                  BEGIN
               	   SET @nErrNo = 167501
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff UDF02
                     GOTO Quit
                  END
                  
                  
               END
            END
         END
      END
   END
END

Quit:

SET QUOTED_IDENTIFIER OFF

GO