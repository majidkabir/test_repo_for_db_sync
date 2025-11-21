SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_839DisableQTY03                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author     Purposes                                      */
/* 2022-03-09  1.0  yeekung      WMS-19113. Created                            */
/******************************************************************************/

CREATE PROC [RDT].[rdt_839DisableQTY03] (
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
   DECLARE @cZone          NVARCHAR( 10)
   DECLARE @cUDF02         NVARCHAR( 60)
   DECLARE @cUserDefine10  NVARCHAR( 10)
   DECLARE @cDocType       NVARCHAR( 10)

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''
   SET @cDisableQTYField = ''

   -- Get PickHeader info
   SELECT TOP 1
      @cOrderKey = OrderKey,
      @cLoadKey = ExternOrderKey,
      @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   IF ISNULL( @cOrderKey, '') = ''
      SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.LoadPlanDetail WITH (NOLOCK) WHERE LoadKey = @cLoadKey

   IF  ISNULL( @cOrderKey, '') = ''
      SELECT TOP 1 @cOrderKey = OrderKey FROM dbo.pickdetail WITH (NOLOCK) WHERE pickslipno = @cPickSlipNo

   SELECT @cUserDefine10   = UserDefine10,
          @cDocType        = DocType
   FROM dbo.ORDERS WITH (NOLOCK)
   WHERE OrderKey = @cOrderKey

   SELECT @cUDF02 = UDF02 
   FROM dbo.CODELKUP WITH (NOLOCK)
   WHERE Listname = 'OBType'
   AND   Storerkey = @cStorerKey
   AND   UDF01 = @cUserDefine10
   AND   code2 = @cDocType
   
   IF @cUDF02 = '0'
      SET @cDisableQTYField = '1'

   IF @cUDF02 = '1'
      SET @cDisableQTYField = '0'
END

GO