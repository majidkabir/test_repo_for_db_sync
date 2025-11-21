SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_993GetStatSP01                                  */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Get carton level info for LVSUSA                            */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2024-10-17 1.0  Jackc       FCR-946 created                          */
/************************************************************************/

CREATE PROC rdt.rdt_993GetStatSP01(
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cType           NVARCHAR( 10)  -- CURRENT/NEXT
   ,@cPickSlipNo     NVARCHAR( 10)
   ,@cFromDropID     NVARCHAR( 20)
   ,@cPackDtlDropID  NVARCHAR( 20)
   ,@nCartonNo       INT            OUTPUT
   ,@cLabelNo        NVARCHAR( 20)  OUTPUT
   ,@cCustomNo       NVARCHAR( 5)   OUTPUT
   ,@cCustomID       NVARCHAR( 20)  OUTPUT
   ,@nCartonSKU      INT            OUTPUT
   ,@nCartonQTY      INT            OUTPUT
   ,@nTotalCarton    INT            OUTPUT
   ,@nTotalPick      INT            OUTPUT
   ,@nTotalPack      INT            OUTPUT
   ,@nTotalShort     INT            OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR(250)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR(MAX)
   DECLARE @cSQLParam   NVARCHAR(MAX)
   DECLARE @cGetStatSP  NVARCHAR(20)

   DECLARE @cPackFilter NVARCHAR( MAX) = ''
   DECLARE @cPickFilter NVARCHAR( MAX) = ''
   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cRefNo      NVARCHAR( 20)
   DECLARE @cRefNo2     NVARCHAR( 30)
   DECLARE @nRowCount   INT = 0
   DECLARE @bDebugFlag  BINARY = 0

   DECLARE @tPSNO TABLE
   (
      PickSlipNo NVARCHAR(20) NOT NULL
   )

   DECLARE @tOrder TABLE
   (
      OrderKey NVARCHAR(10) NOT NULL
   )

   SET @cOrderKey = ''
   SET @cLoadKey = ''
   SET @cZone = ''

   INSERT INTO @tPSNO
      SELECT DISTINCT PH.PickSlipNO
      FROM PackHeader PH WITH (NOLOCK)
      JOIN PackDetail PD WITH (NOLOCK)
         ON PH.StorerKey = PD.StorerKey
         AND PH.PickSlipNo = PD.PickSlipNo
      WHERE PH.StorerKey = @cStorerKey
         AND PD.LabelNo = @cLabelNo

   IF @bDebugFlag = 1
   BEGIN
      SELECT 'PSNO List', @cLabelNo AS LabelNo
      SELECT * FROM @tPSNO
   END

   -- Get PickHeader Info
   INSERT INTO @tOrder
      SELECT DISTINCT OrderKey
      FROM PickHeader PKH WITH (NOLOCK)
      JOIN @tPSNO PSNO
      ON PKH.PickHeaderKey = PSNO.PickSlipNo
      WHERE 
         PKH.StorerKey = @cStorerKey
   
   IF @bDebugFlag = 1
   BEGIN
      SELECT 'Order List'
      SELECT * FROM @tOrder
   END

   /***********************************************************************************************
                                                PackDetail
   ***********************************************************************************************/
   -- Get Total Pack
   SELECT @nTotalPack = ISNULL( SUM (PD.QTY), 0)
   FROM PackDetail PD WITH (NOLOCK)
   JOIN @tPSNO PSNO
      ON PD.PickSlipNo = PSNO.PickSlipNo
   WHERE PD.StorerKey = @cStorerKey
      AND PD.LabelNo = @cLabelNo
   
   IF @bDebugFlag = 1
      SELECT @nTotalPack AS TotalPackQty
   
   SELECT 
      @nCartonSKU = COUNT( DISTINCT PD.SKU), 
      @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   JOIN @tPSNO PSNO
      ON PD.PickSlipNo = PSNO.PickSlipNo
   WHERE LabelNo = @cLabelNo

   IF @bDebugFlag = 1
      SELECT @nCartonSKU AS CartonSKU, @nCartonQty AS CartonQty

   /***********************************************************************************************
                                                PickDetail
   ***********************************************************************************************/

   -- Discrete PickSlip'

   SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN @tOrder ORD ON PD.OrderKey = ORD.OrderKey
   WHERE PD.Status <= '5'
      AND PD.Status <> '4'
      AND PD.CaseID = @cLabelNo
   
   IF @bDebugFlag = 1
      SELECT @nTotalPick AS TotalPick
   
  SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PickDetail PD WITH (NOLOCK)
   JOIN @tOrder ORD ON PD.OrderKey = ORD.OrderKey
   WHERE PD.Status = '4'
      AND PD.CaseID = @cLabelNo

   IF @bDebugFlag = 1
      SELECT @nTotalPick AS TotalPick

Quit:

END

GO