SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839DisableQTY01                                       */
/* Purpose: Disable Qty                                                       */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2022-04-20   YeeKung   1.0   WMS-19311 Created                             */
/******************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_839DisableQTY04] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cPickZone        NVARCHAR( 10),
   @cLOC             NVARCHAR( 10),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cDisableQTYField NVARCHAR( 1)   OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cOrderKey      NVARCHAR( 10)    
   DECLARE @cLoadKey       NVARCHAR( 10)    
   DECLARE @cZone          NVARCHAR( 18)
   DECLARE @cDoctype       NVARCHAR( 1)
      
   IF @nInputKey = 1
   BEGIN      

      SET @cOrderKey = ''    
      SET @cLoadKey = ''    
      SET @cZone = ''    
    
      -- Get PickHeader info    
      SELECT TOP 1    
         @cOrderKey = OrderKey,    
         @cLoadKey = ExternOrderKey,    
         @cZone = Zone    
      FROM dbo.PickHeader WITH (NOLOCK)    
      WHERE PickHeaderKey = @cPickSlipNo    
      
      SELECT @cDoctype=doctype
      FROM Orders (NOLOCK)
      WHERE ORDERKEY=@cOrderkey

      IF @cDoctype ='E'
         SET @cDisableQTYField='1'
      ELSE
         SET @cDisableQTYField='0'
   END


END

GO