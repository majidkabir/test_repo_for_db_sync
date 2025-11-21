SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_840NewCtnNoSP01                                 */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: New carton No display when previous carton already          */
/*          inserted into PackInfo                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2024-06-19 1.0  James    WMS-24295. Created                          */
/* 2024-11-08 1.1  PXL009   FCR-1118 Merged 1.0.8 from v0 branch        */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_840NewCtnNoSP01] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT,
   @cStorerkey                NVARCHAR( 15),
   @cOrderKey                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20),
   @cRefNo                    NVARCHAR( 40),
   @nCartonNo                 INT           OUTPUT,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT
) AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nNewCtn     INT = 0

   SET @nErrNo = 0
   
   -- This pickslip never packed anything before, set carton no = 0
   IF NOT EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo)  
      SET @nCartonNo = 1  
   ELSE
   BEGIN
      -- Get latest carton no for this carton
      SELECT @nCartonNo = MAX( PD.CartonNo)
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
      AND   PD.RefNo2 = @cDropID
      AND   NOT EXISTS ( SELECT 1
                           FROM dbo.PackInfo PIf WITH (NOLOCK)
                           WHERE PD.PickSlipNo = PIF.PickSlipNo
                           AND   PD.CartonNo = PIF.CartonNo)
               
      IF ISNULL( @nCartonNo, 0) = 0
         SELECT @nCartonNo = MAX( PD.CartonNo)
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
   END
   
   Quit:

GO