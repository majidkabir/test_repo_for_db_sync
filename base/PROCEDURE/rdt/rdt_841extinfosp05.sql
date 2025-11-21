SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_841ExtInfoSP05                                  */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2023-03-20 1.0  yeekung  WMS-17410. Created                          */
/************************************************************************/

CREATE   PROC [RDT].[rdt_841ExtInfoSP05] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   NVARCHAR(3),
   @nStep       INT,
   @cStorerKey  NVARCHAR(15),
   @cDropID     NVARCHAR(20),
   @cSKU        NVARCHAR(20),
   @cPickSlipNo NVARCHAR(10),
   @cLoadKey    NVARCHAR(20),
   @cWavekey    NVARCHAR(20),
   @nInputKey   INT,
   @cSerialNo   NVARCHAR( 30),
   @nSerialQTY   INT,
   @cExtendedinfo  NVARCHAR( 20) OUTPUT,
   @nErrNo      INT       OUTPUT,
   @cErrMsg     CHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cCompany    NVARCHAR(20)
   DECLARE @cOrderKey   NVARCHAR(10)


   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
      	SELECT
      	   @cOrderKey = V_OrderKey
      	FROM rdt.RDTMOBRECáá (nolock)
         WHERE Mobile = @nMobile

      	SELECT @cCompany = RIGHT(M_Company,20)   
      	FROM orders (NOLOCK)
      	WHERE storerKey = @cStorerKey
      	AND OrderKey = @cOrderKey

         SET @cExtendedinfo =  @cCompany 
      END
   END


QUIT:


GO