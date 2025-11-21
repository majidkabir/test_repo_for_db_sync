SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830ExtInfVLT                                    */
/*                                                                      */
/*                                                                      */
/* Date         Author   Purposes                                       */
/* 5/15/2024    PPA374   check if MBOL EXISTS AND STAGE is provided     */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_830ExtInfVLT] (
   @nMobile       INT,            
   @nFunc         INT,            
   @cLangCode     NVARCHAR( 3),   
   @nStep         INT,            
   @nInputKey     INT,            
   @cFacility     NVARCHAR( 5),    
   @cStorerKey    NVARCHAR( 15),  
   @cPickSlipNo   NVARCHAR( 10),  
   @cPickZone     NVARCHAR( 10),   
   @cLOC          NVARCHAR( 10),  
   @cSuggLOC      NVARCHAR( 10) OUTPUT,   
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT  
) AS
BEGIN

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE
      @MBOL NVARCHAR(20),
      @WAVENO NVARCHAR (20),
      @FULLALL int,
      @STAGE NVARCHAR(20),
      @STAGEExists int,
      @LINKexists int

      SELECT TOP 1 @MBOL = MBOLKey FROM ORDERS (NOLOCK)
      WHERE orderkey =
      (SELECT OrderKey FROM PICKHEADER (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo)

      SELECT TOP 1 @WAVENO = WaveKey FROM WAVEDETAIL (NOLOCK)
      WHERE orderkey = (SELECT OrderKey FROM PICKHEADER (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo)

      SELECT TOP 1 @FULLALL = IIF(sum(openqty)=sum(qtypicked)+sum(qtyallocated),1,0) FROM ORDERDETAIL (NOLOCK) WHERE orderkey = 
      (SELECT TOP 1 OrderKey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)

      SELECT TOP 1 @STAGE = OtherReference FROM MBOL (NOLOCK) WHERE MbolKey = @MBOL

      SELECT TOP 1 @STAGEExists = case when EXISTS
      (SELECT loc FROM loc (NOLOCK) WHERE facility = 'UK001' AND LocationType = 'STAGEOB' AND loc = @STAGE)
      THEN 1 ELSE 0 END

      SELECT TOP 1 @LINKexists = case when @STAGE in (SELECT code FROM CODELKUP (NOLOCK) WHERE LISTNAME = 'HUSQDOORLN')
      THEN 1 ELSE 0 END

      IF @nStep = 1 AND @MBOL = ''
      BEGIN
         SET @nErrNo = 217910
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoShipReference
         GOTO Quit
      END
      ELSE IF @nStep = 1 AND @FULLALL = 0
      BEGIN
         SET @nErrNo = 217911
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not100%Allocated
         GOTO Quit
      END
      ELSE IF @nStep = 1 AND @STAGEExists = 0
      BEGIN
         SET @nErrNo = 217912
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadOtherReference
         GOTO Quit
      END

   /***********************************************************************************************
                                           Standard suggest LOC
   ***********************************************************************************************/
   BEGIN

      DECLARE @cOrderKey   NVARCHAR( 10)
      DECLARE @cLoadKey    NVARCHAR( 10)
      DECLARE @cZone       NVARCHAR( 18)
      DECLARE @cLogicalLOC NVARCHAR( 18)
      DECLARE @cNewSuggLOC NVARCHAR( 18)
      DECLARE @cPickConfirmStatus NVARCHAR( 1)

      SET @cOrderKey = ''
      SET @cLoadKey = ''
      SET @cZone = ''
      SET @cNewSuggLOC = ''

      SET @cPickZone = case when isnull(@cPickZone,'') <> ''
      OR  (SELECT TOP 1 C_String30 FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = ''
      THEN @cPickZone 
      ELSE (SELECT TOP 1 C_String30 FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile)
   END

      -- Get storer config
      SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
      IF @cPickConfirmStatus = '0'
         SET @cPickConfirmStatus = '5'

      -- Get loc info
      SET @cLogicalLOC = ''
      SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC

      -- Get PickHeader info
      SELECT TOP 1
         @cOrderKey = OrderKey,
         @cLoadKey = ExternOrderKey,
         @cZone = Zone
      FROM dbo.PickHeader WITH (NOLOCK)
      WHERE PickHeaderKey = @cPickSlipNo

      WHILE (1=1)
      BEGIN
         IF (SELECT TOP 1 isnull(C_String29,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = '1'
         BEGIN
            UPDATE rdt.RDTMOBREC
            SET C_String29 = '', c_string30 = '', I_Field05 = '', O_Field05 ='', V_String35=''
            WHERE Mobile = @nMobile

            SET @cNewSuggLOC = 'Enter Zone'
            GOTO skip1
         END

         -- Cross dock PickSlip
         IF @cZone IN ('XD', 'LB', 'LP')
         BEGIN
            IF (@cPickZone<>'')
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  AND  LOC.PickZone = @cPickZone
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
            ELSE
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.RefKeyLookup RKL WITH (NOLOCK)
                  JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE RKL.PickSlipNo = @cPickSlipNo
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC

         END
         -- Discrete PickSlip
         ELSE IF @cOrderKey <> ''
         BEGIN
            IF @cPickZone<>''
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  AND LOC.Pickzone=@cPickZone
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC   
            ELSE
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.OrderKey = @cOrderKey
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
         END
         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
         BEGIN
            IF @cPickZone<>''
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey  
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  AND LOC.Pickzone=@cPickZone
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
            ELSE
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
                  JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey  
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
         END
         -- Custom PickSlip
         ELSE
         BEGIN
            IF @cPickZone<>''
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  AND LOC.PickZone=@cPickZone
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
            ELSE
               SELECT TOP 1
                  @cNewSuggLOC = LOC.LOC
               FROM dbo.PickDetail PD WITH (NOLOCK)
                  JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.QTY > 0
                  AND PD.Status <> '4'
                  AND PD.Status < @cPickConfirmStatus
                  AND (LOC.LogicalLocation > @cLogicalLOC
                  OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
         END

      skip1:
         UPDATE rdt.RDTMOBREC
         SET C_String30 = case when I_Field05 = '' THEN c_string30 ELSE I_Field05 END
         WHERE Mobile = @nMobile

         IF (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = ''
         BEGIN
            SET @cNewSuggLOC = 'Enter Zone'
         END

         -- Found suggest LOC
         IF @nStep NOT in (1,2)
            AND NOT EXISTS 
            (SELECT 1 FROM pickdetail (NOLOCK)
            WHERE orderkey = 
            (SELECT TOP 1 orderkey FROM pickheader (NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo)
            AND Storerkey = @cStorerKey
            AND status = 0
            AND loc in (SELECT loc FROM loc (NOLOCK) WHERE PickZone = (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) 
            AND Facility = @cFacility))
         BEGIN
            UPDATE rdt.RDTMOBREC
            SET C_String30 = '', C_String29 = '1'
            WHERE Mobile = @nMobile

            SET @nErrNo = 217913
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMoreTaskInZone
            SET @nErrNo = -1
            BREAK
         END

         DECLARE @orderkey nvarchar(20)

         SELECT TOP 1 @orderkey = orderkey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo

         IF @cNewSuggLOC <> ''
            BREAK
         ELSE
         BEGIN
            -- Search FROM begining again
            IF @cLOC <> ''
            BEGIN
               SET @cLOC = ''
               SET @cLogicalLOC = ''
               CONTINUE
            END   
            ELSE
            BEGIN
               SET @nErrNo = 217914
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMoreTask
               SET @nErrNo = -1
               BREAK
            END
         END
      END

      IF @cNewSuggLOC <> ''
         SET @cSuggLOC = @cNewSuggLOC
Quit:
   END
END

GO