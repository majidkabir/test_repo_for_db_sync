SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtVal14                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Validate case with same orders.c_country and orders.type    */
/*          can be scan into same pallet                                */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 2021-10-29  1.0  James     WMS-18236 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtVal14] (
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
               DECLARE @cC_Country           NVARCHAR( 30) = ''
               DECLARE @cPalletC_Country     NVARCHAR( 30) = ''
               DECLARE @cOrdType             NVARCHAR( 10) = ''
               DECLARE @cPalletOrdType       NVARCHAR( 10) = ''
               DECLARE @cPalletCaseID        NVARCHAR( 20) = ''
               DECLARE @cPalletPickSlipNo    NVARCHAR( 10) = ''
               DECLARE @cPalletOrderKey      NVARCHAR( 10) = ''

               IF EXISTS(SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND PalletKey = @cPalletKey)
                  BEGIN
                  -- Get case info
                  SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cCaseID
                  SELECT @cOrderKey = OrderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo
                  SELECT @cC_Country = C_Country, @cOrdType = [Type] FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cOrderKey

                  SELECT TOP 1 @cPalletCaseID = CaseID FROM dbo.PALLETDETAIL WITH (NOLOCK) WHERE PalletKey = @cPalletKey ORDER BY 1
                  SELECT @cPalletPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND LabelNo = @cPalletCaseID
                  SELECT @cPalletOrderKey = OrderKey FROM dbo.PICKHEADER WITH (NOLOCK) WHERE PickHeaderKey = @cPalletPickSlipNo
                  SELECT @cPalletC_Country = C_Country, @cPalletOrdType = [Type] FROM dbo.ORDERS WITH (NOLOCK) WHERE OrderKey = @cPalletOrderKey

                  IF (@cC_Country <> @cPalletC_Country)
                  BEGIN
                   SET @nErrNo = 178251
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Country
                     GOTO Quit
                  END

                  IF (@cOrdType <> @cPalletOrdType)
                  BEGIN
                   SET @nErrNo = 178252
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Diff Ord Type
                     GOTO Quit
                  END
               END
            END
         END
      END
   END
END

Quit:

GO