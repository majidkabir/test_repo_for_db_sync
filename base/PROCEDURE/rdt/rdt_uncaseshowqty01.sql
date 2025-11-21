SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_UnCaseShowQty01                                 */
/* Purpose: VAP uncasing module for DGE. Calc and show the qty          */
/*          Show remining qty only if busr3 = DGE-GEN.                  */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2016-02-02 1.0  James      SOS315942. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_UnCaseShowQty01] (
   @nMobile          INT, 
   @nFunc            INT, 
   @nStep            INT, 
   @nInputKey        INT, 
   @cLangCode        NVARCHAR( 3),  
   @cStorerkey       NVARCHAR( 15), 
   @cJobKey          NVARCHAR( 10),
   @cWorkOrderKey    NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cSKU             NVARCHAR( 20),
   @cTtl_PltQty      NVARCHAR( 7)  OUTPUT, 
   @cTtl_RemQty      NVARCHAR( 7)  OUTPUT, 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @nTtl_IDQty        INT,
           @nTtl_PltUnCased   INT,
           @nTtl_JobQty       INT,
           @nTtl_Uncased      INT,
           @nTtl_PltQty       INT,
           @nTtl_RemQty       INT

         SELECT @nTtl_Uncased = 0, @nTtl_JobQty = 0, @nTtl_PltUnCased = 0, 
                @nTtl_IDQty = 0, @nTtl_PltQty = 0, @nTtl_RemQty = 0

   IF EXISTS ( SELECT 1 FROM dbo.SKU WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey
               AND   SKU = @cSKU
               AND   BUSR3 = 'DGE-GEN')
   BEGIN                   
      SELECT @nTtl_Uncased = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
      WHERE U.WorkOrderKey = @cWorkOrderKey
      AND   U.Status < '9'
      AND   SKU.BUSR3 = 'DGE-GEN'
      AND   SKU.StorerKey = @cStorerKey

      SELECT @nTtl_JobQty = ISNULL( SUM( Qty), 0)
      FROM dbo.WorkOrderRequestInputs WRI WITH (NOLOCK) 
      JOIN dbo.SKU SKU WITH (NOLOCK) ON ( WRI.SKU = SKU.SKU AND WRI.StorerKey = SKU.StorerKey)
      WHERE WRI.WorkOrderKey = @cWorkOrderKey
      AND   SKU.BUSR3 = 'DGE-GEN'
      AND   SKU.StorerKey = @cStorerKey

      SELECT @nTtl_PltUnCased = ISNULL( SUM( QTY), 0)
      FROM dbo.WorkOrder_UnCasing WITH (NOLOCK) 
      WHERE WorkOrderKey = @cWorkOrderKey
      AND   ID = @cID
      AND   [Status] < '9'

      SELECT @nTtl_IDQty = ISNULL( SUM( QTY), 0) 
      FROM dbo.WorkOrderJobMove WITH (NOLOCK) 
      WHERE JobKey = @cJobKey 
      AND   ID = @cID
      AND   [Status] = '0'

      --IF SUSER_SNAME() = 'wmsgt'
      --BEGIN
      --   SELECT '@nTtl_PltQty', @nTtl_PltQty, '@nTtl_PltUnCased', @nTtl_PltUnCased, '@nTtl_JobQty', @nTtl_JobQty, '@nTtl_Uncased', @nTtl_Uncased
      --   SELECT '@cWorkOrderKey', @cWorkOrderKey, '@cStorerKey', @cStorerKey, '@cSKU', @cSKU
      --END

      SET @nTtl_PltQty = CASE WHEN ( @nTtl_PltQty - @nTtl_PltUnCased) < 0 THEN 0 ELSE ( @nTtl_PltQty - @nTtl_PltUnCased) END
      SET @nTtl_RemQty = CASE WHEN ( @nTtl_JobQty - @nTtl_Uncased) < 0 THEN 0 ELSE ( @nTtl_JobQty - @nTtl_Uncased) END

      IF @nTtl_PltQty <= 0 
         SET @cTtl_PltQty = ''
      ELSE
         SET @cTtl_PltQty = @nTtl_PltQty

      IF @nTtl_RemQty <= 0 
         SET @cTtl_RemQty = '' 
      ELSE 
         SET @cTtl_RemQty = @nTtl_RemQty
   END
   ELSE
   BEGIN
      SET @cTtl_PltQty = ''
      SET @cTtl_RemQty = '' 
   END


GO