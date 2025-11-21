SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_FinalizeVASWorkOrder                                  */
/* Copyright      : Maersk WMS                                                */
/*                                                                            */
/* Purpose: Finalize work orders                                              */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 2024-02-28 1.0  NLT013       Created First Version (UWP-15257)             */
/******************************************************************************/

CREATE PROCEDURE [rdt].[rdt_FinalizeVASWorkOrder] (
   @nFunc                INT,
   @nMobile              INT,
   @cLangCode            NVARCHAR( 3),
   @cStorerKey           NVARCHAR( 15),
   @cFacility            NVARCHAR( 5),

   @cPalletID            NVARCHAR( 18),  --pallet id for inbound or outbound

   @nErrNo               INT                   OUTPUT,
   @cErrMsg              NVARCHAR( 20)         OUTPUT
) AS
BEGIN

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
   @cWorkOrderKey         NVARCHAR( 10),
   @cExternWorkOrderKey   NVARCHAR( 10),
   @cExternLineNo         NVARCHAR( 5),

   @nSuccess              INT,
   @nErrorNumber          INT,
   @cErrorMessage         NVARCHAR( 250),
   @nRowCount             INT
   
   --Initialize error number and error message
   SET @nErrNo           = 0;
   SET @cErrMsg          = ''

   SET @cWorkOrderKey    = ''

   -- Validate StorerKey
   IF @cStorerKey = ''
   BEGIN
      SET @nErrNo = 211707
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need StorerKey'
      GOTO Quit
   END

   -- Validate Facility
   IF @cFacility = ''
   BEGIN
      SET @nErrNo = 211708
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need Facility'
      GOTO Quit
   END

   -- Validate ID
   IF @cPalletID = ''
   BEGIN
      SET @nErrNo = 211701
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Need ID'
      GOTO Quit
   END

   SELECT @cWorkOrderKey = wod.WorkOrderKey
   FROM dbo.WorkOrderDetail AS wod WITH(NOLOCK)
   INNER JOIN dbo.WorkOrder AS wo WITH(NOLOCK)
      ON wod.StorerKey = wo.StorerKey
      and wod.WorkOrderKey = wo.WorkOrderKey
   WHERE wo.Facility                                 = @cFacility
      AND wo.StorerKey                               = @cStorerKey
      AND ISNULL(wod.WkOrdUdef1, '-1')               = @cPalletID
      AND wo.status = 0

   IF @cWorkOrderKey IS NULL OR @cWorkOrderKey = ''
      GOTO Quit

   EXEC [dbo].[isp_FinalizeWorkOrder] 
      @cWorkOrderKey, 
      @nSuccess        OUTPUT,
      @nErrorNumber    OUTPUT,
      @cErrorMessage   OUTPUT
   
   IF @nSuccess = 0
   BEGIN
      SET @nErrNo = 211716
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Finalize WorkOrder Fail'
      GOTO Quit
   END

Quit:

END

GO