SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ExtVal19                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purposes: Customized validation for Levis US                         */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 2024/06/18 1.0  Jackc       FCR-392 created                          */
/************************************************************************/

CREATE   PROC rdt.rdt_838ExtVal19 (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cPickSlipNo      NVARCHAR( 10),
   @cFromDropID      NVARCHAR( 20),
   @nCartonNo        INT,
   @cLabelNo         NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cUCCNo           NVARCHAR( 20),
   @cCartonType      NVARCHAR( 10),
   @cCube            NVARCHAR( 10),
   @cWeight          NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cSerialNo        NVARCHAR( 30),
   @nSerialQTY       INT,
   @cOption          NVARCHAR( 1),
   @cPackDtlRefNo    NVARCHAR( 20), 
   @cPackDtlRefNo2   NVARCHAR( 20), 
   @cPackDtlUPC      NVARCHAR( 30), 
   @cPackDtlDropID   NVARCHAR( 20), 
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30),
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nTotalPick       INT,
            @nTotalPack       INT,
            @nCartonPick      INT,
            @nCartonPack      INT,
            @cOrderKey        NVARCHAR( 10),
            @cLoadKey         NVARCHAR( 10),
            @cZone            NVARCHAR( 18),
            @cCartTrkLabelNo  NVARCHAR( 20),

            @bDebugFlag       BINARY

   IF @nFunc = 838 -- Pack
   BEGIN
      IF @nStep = 2 -- statistic screen
      BEGIN
         IF @nInputKey = 1
         BEGIN
            -- Get total pick and total pack from RDTMOBREC
            --V_Integer4     = @nTotalPick,
            --V_Integer5     = @nTotalPack,
            SELECT @nCartonPick = ISNULL(V_Integer4,0)
                  ,@nCartonPack = ISNULL(V_Integer5,0)
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF @bDebugFlag = 1
               SELECT @nCartonPack AS CartonPack, @nCartonPick AS CartonPick

            IF @nCartonPick = 0
            BEGIN
               SET @nErrNo = 217501
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Nothing Picked
               GOTO Quit
            END

            IF @nCartonPick < @nCartonPack
            BEGIN
               SET @nErrNo = 217502
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --PickedMoreThanPacked
               GOTO Quit
            END

            IF @cOption = '1'
            BEGIN
               SELECT TOP 1
                  @cOrderKey = OrderKey,
                  @cLoadKey = ExternOrderKey,
                  @cZone = Zone
               FROM dbo.PickHeader WITH (NOLOCK)
               WHERE PickHeaderKey = @cPickSlipNo

               -- Get total pick and total pack
               SELECT @nTotalPack = ISNULL( SUM( PD.QTY), 0)
               FROM dbo.PackDetail PD WITH (NOLOCK)
               WHERE PD.PickSlipNo = @cPickSlipNo

               IF @cZone IN ('XD', 'LB', 'LP')
               BEGIN
                  SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  WHERE RKL.PickSlipNo = @cPickSlipNo
                     AND PD.Status <= '5'
                     AND PD.Status <> '4'  
               END -- zone

               -- Discrete PickSlip
               ELSE IF @cOrderKey <> ''
               BEGIN
                  SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.OrderKey = @cOrderKey
                     AND PD.Status <= '5'
                     AND PD.Status <> '4'
               END -- discrete
                           
               -- Conso PickSlip
               ELSE IF @cLoadKey <> ''
               BEGIN
                  SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                     JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  WHERE LPD.LoadKey = @cLoadKey  
                     AND PD.Status <= '5'
                     AND PD.Status <> '4'
               END -- load
               
               -- Custom PickSlip
               ELSE
               BEGIN
                  SELECT @nTotalPick = ISNULL( SUM( PD.QTY), 0)
                  FROM dbo.PickDetail PD WITH (NOLOCK)
                  WHERE PD.PickSlipNo = @cPickSlipNo
                     AND PD.Status <= '5'
                     AND PD.Status <> '4'
               END -- Custom

               IF @bDebugFlag = 1
                  SELECT @nTotalPack AS TotalPack, @nTotalPick AS TotalPick, @cZone AS Zone, @cOrderKey AS OrderKey, @cLoadKey AS LoadKey

               IF @nTotalPick = @nTotalPack
               BEGIN
                  SET @nErrNo = 217503
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid Option
                  GOTO Quit
               END
            END -- Option 1

         END
      END -- step2
   END

Quit:

END

GO