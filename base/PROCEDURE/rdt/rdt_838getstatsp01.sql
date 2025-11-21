SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838GetStatSP01                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 15-Mar-2018 1.0  James       WMS3845 Created                         */
/* 13-Jun-2018 1.1  JihHaur     Slow response when @cFromDropID = ''(JH01)*/
/* 12-Jul-2018 1.2  Ung         WMS-5490 Add sorting process            */
/************************************************************************/

CREATE PROC [RDT].[rdt_838GetStatSP01] (
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

   DECLARE @cOrderKey   NVARCHAR( 10)
   DECLARE @cLoadKey    NVARCHAR( 10)
   DECLARE @cZone       NVARCHAR( 18)
   DECLARE @cDropID     NVARCHAR( 20)
   DECLARE @cRefNo      NVARCHAR( 20)
   DECLARE @cRefNo2     NVARCHAR( 30)
   DECLARE @cPickStatus NVARCHAR( 1)

   DECLARE @tPickZone TABLE 
   (
      PickZone NVARCHAR( 10) PRIMARY KEY CLUSTERED  
   )

   IF @cFromDropID = ''
      SET @cPickStatus = '0'
   ELSE
      SET @cPickStatus = '5'

   INSERT INTO @tPickZone (PickZone)
   SELECT Code2
   FROM dbo.CodelkUp WITH (NOLOCK)
   WHERE ListName = 'ALLSorting'
      AND StorerKey = @cStorerKey
      AND Code = @cPackDtlDropID

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

   /***********************************************************************************************
                                                PackDetail
   ***********************************************************************************************/
   SELECT @nTotalPack = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND DropID = @cFromDropID
      AND Refno = @cPackDtlDropID

   SELECT @nTotalCarton = COUNT( DISTINCT PD.LabelNo)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND DropID = @cFromDropID
      AND Refno = @cPackDtlDropID
   
   IF @cType = 'CURRENT'
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cDropID = DropID, 
         @cRefNo = RefNo, 
         @cRefNo2 = RefNo2
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo = @nCartonNo
         AND DropID = @cFromDropID
         AND Refno = @cPackDtlDropID
      ORDER BY CartonNo
   
   IF @cType = 'NEXT'
   BEGIN
      SELECT TOP 1 
         @nCartonNo = CartonNo, 
         @cLabelNo = LabelNo, 
         @cDropID = DropID, 
         @cRefNo = RefNo, 
         @cRefNo2 = RefNo2
      FROM dbo.PackDetail PD WITH (NOLOCK)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND CartonNo > @nCartonNo
         AND DropID = @cFromDropID
         AND Refno = @cPackDtlDropID
      ORDER BY CartonNo
   
      IF @@ROWCOUNT = 0
      BEGIN
         SELECT TOP 1 
            @nCartonNo = CartonNo, 
            @cLabelNo = LabelNo, 
            @cDropID = DropID, 
            @cRefNo = RefNo, 
            @cRefNo2 = RefNo2
         FROM dbo.PackDetail PD WITH (NOLOCK)
         WHERE PD.PickSlipNo = @cPickSlipNo
            AND DropID = @cFromDropID
            AND Refno = @cPackDtlDropID
         ORDER BY CartonNo   
   
         IF @@ROWCOUNT = 0
            SELECT 
               @nCartonNo = 0, 
               @cLabelNo = '', 
               @cDropID = '', 
               @cRefNo = '', 
               @cRefNo2 = ''
      END
   END
   
   SELECT 
      @nCartonSKU = COUNT( DISTINCT PD.SKU), 
      @nCartonQTY = ISNULL( SUM( PD.QTY), 0)
   FROM dbo.PackDetail PD WITH (NOLOCK)
   WHERE PD.PickSlipNo = @cPickSlipNo
      AND CartonNo = @nCartonNo
      AND LabelNo = @cLabelNo
      AND Refno = @cPackDtlDropID

   -- Storer configure
   DECLARE @cCustomCartonNo NVARCHAR(1)
   DECLARE @cCustomCartonID NVARCHAR(1)
   SET @cCustomCartonNo = rdt.rdtGetConfig( @nFunc, 'CustomCartonNo', @cStorerKey)
   SET @cCustomCartonID = rdt.rdtGetConfig( @nFunc, 'CustomCartonID', @cStorerKey)
   
   -- Get customm carton no / label no
   SELECT 
      @cCustomNo = 
         CASE @cCustomCartonNo 
            WHEN '1' THEN LEFT( @cDropID, 5)
            WHEN '2' THEN LEFT( @cRefNo, 5)
            WHEN '3' THEN LEFT( @cRefNo2, 5)
            ELSE CAST( @nCartonNo AS NVARCHAR(5))
         END, 
      @cCustomID = 
         CASE @cCustomCartonID 
            WHEN '1' THEN @cDropID
            WHEN '2' THEN @cRefNo
            WHEN '3' THEN LEFT( @cRefNo2, 20)
            ELSE @cLabelNo
         END
   IF @cCustomNo = ''
      SET @cCustomNo = '0'

   /***********************************************************************************************
                                                PickDetail
   ***********************************************************************************************/
   -- Cross dock PickSlip
   IF @cZone IN ('XD', 'LB', 'LP')
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.DropID = @cFromDropID
         AND PD.Status >= @cPickStatus
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
         JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE RKL.PickSlipNo = @cPickSlipNo
         AND PD.DropID = @cFromDropID
         AND PD.Status = '4'
   END

   -- Discrete PickSlip
   ELSE IF @cOrderKey <> ''
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.DropID = @cFromDropID
         AND PD.Status >= @cPickStatus
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE PD.OrderKey = @cOrderKey
         AND PD.DropID = @cFromDropID
         AND PD.Status = '4'
   END
               
   -- Conso PickSlip
   ELSE IF @cLoadKey <> ''
   BEGIN
      IF @cFromDropID = 'SORTED'
      BEGIN
		   SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.Status <> '4'

         SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.Status = '4'
      END
      ELSE IF @cFromDropID = ''   --(JH01)
      BEGIN
		   SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.DropID = ''
            AND PD.Status >= @cPickStatus
            AND PD.Status <> '4'

         SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.DropID = ''
            AND PD.Status = '4'
      END
      ELSE
      BEGIN
		   SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.DropID = @cFromDropID
            AND PD.Status >= @cPickStatus
            AND PD.Status <> '4'

         SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
            JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.DropID = @cFromDropID
            AND PD.Status = '4'
		END       --(JH01)
   END
   
   -- Custom PickSlip
   ELSE
   BEGIN
      SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.DropID = @cFromDropID
         AND PD.Status >= @cPickStatus
         AND PD.Status <> '4'

      SELECT @nTotalShort = ISNULL( SUM( PD.QTY), 0)
      FROM dbo.PickDetail PD WITH (NOLOCK)
         JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         JOIN @tPickZone t ON (LOC.PickZone = t.PickZone)
      WHERE PD.PickSlipNo = @cPickSlipNo
         AND PD.DropID = @cFromDropID
         AND PD.Status = '4'
   END

END

GO