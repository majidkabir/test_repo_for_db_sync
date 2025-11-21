SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_GenLabelNoSP01                                  */
/* Copyright: IDS                                                       */
/* Called From: rdt_Cluster_Pick_ConfirmTask                            */
/* Purpose: Generate label no                                           */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date         Rev  Author     Purposes                                */
/* 15-Sep-2017  1.0  James      WNS2447.Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_GenLabelNoSP01](
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @nStep                     INT,
   @nInputKey                 INT,
   @cFacility                 NVARCHAR( 5),
   @cStorerkey                NVARCHAR( 15),
   @cWaveKey                  NVARCHAR( 10),
   @cLoadKey                  NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cPutAwayZone              NVARCHAR( 10),
   @cPickZone                 NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cSKU                      NVARCHAR( 20),
   @nQty                      INT,
   @cDropID                   NVARCHAR( 20),
   @cLabelNo                  NVARCHAR( 20) OUTPUT,
   @nCartonNo                 INT           OUTPUT,
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT  
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @bSuccess INT

   EXEC [dbo].[isp_GLBL11] 
         @c_PickSlipNo   = @cPickZone
      ,  @n_CartonNo     = @nCartonNo
      ,  @c_LabelNo      = @cLabelNo   OUTPUT 



GO