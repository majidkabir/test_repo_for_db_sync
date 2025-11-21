SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620DropID01                                    */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Return Orders.ExternOrderKey as DropId                      */
/*                                                                      */
/* Called from: rdt_Cluster_Pick_DropID                                 */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-09-07  1.0  James      WMS-20636. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620DropID01] (
   @nMobile                   INT,
   @nFunc                     INT,
   @cLangCode                 NVARCHAR( 3),
   @cStorerkey                NVARCHAR( 15),
   @cUserName                 NVARCHAR( 15),
   @cFacility                 NVARCHAR( 5),
   @cLoadKey                  NVARCHAR( 10),
   @cPickSlipNo               NVARCHAR( 10),
   @cOrderKey                 NVARCHAR( 10),
   @cDropID                   NVARCHAR( 20) OUTPUT,
   @cSKU                      NVARCHAR( 20),
   @cActionFlag               NVARCHAR( 1),
   @nErrNo                    INT           OUTPUT,
   @cErrMsg                   NVARCHAR( 20) OUTPUT

)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount        INT,
           @nUpdate           INT,
           @cDropIDType       NVARCHAR( 10),
           @cLoadPickMethod   NVARCHAR( 10),
           @cPD_OrderKey      NVARCHAR( 10),
           @cPD_DropID        NVARCHAR( 20),
           @cExternOrderKey   NVARCHAR( 50)
           
   IF @cActionFlag = 'R'
   BEGIN
   	SELECT @cExternOrderKey = ExternOrderKey
   	FROM dbo.ORDERS WITH (NOLOCK)
   	WHERE OrderKey = @cOrderKey
   	
      SET @cDropID = @cExternOrderKey
   END

   Quit:

END

GO