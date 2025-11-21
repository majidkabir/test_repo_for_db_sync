SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_830SugLOCSPVLT                                  */
/*                                                                      */
/*                                                                      */
/* Date         Author   Purposes                                       */
/* 15/05/2024   PPA374   Check if MBOL EXISTS AND STAGE is provided     */
/* 01/07/2024   PPA374   Sets initial location and remembers pickzone   */
/* 07/02/2025   PPA374   Updating as per review comments                */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_830SugLOCSPVLT] (
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
   @STAGEExists int

   SELECT TOP 1 @MBOL = MBOLKey FROM ORDERS (NOLOCK)
   WHERE orderkey =
   (SELECT OrderKey FROM PICKHEADER (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo)

   SELECT TOP 1 @WAVENO = WaveKey FROM WAVEDETAIL (NOLOCK)
   WHERE orderkey = (SELECT OrderKey FROM PICKHEADER (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo)

   SELECT TOP 1 @FULLALL = IIF(sum(openqty)=sum(qtypicked)+sum(qtyallocated),1,0) FROM ORDERDETAIL (NOLOCK) WHERE  StorerKey = @cStorerKey
   AND orderkey = (SELECT TOP 1 OrderKey FROM PICKHEADER (NOLOCK) WHERE PickHeaderKey = @cPickSlipNo)

   SELECT TOP 1 @STAGE = OtherReference FROM MBOL (NOLOCK) WHERE MbolKey = @MBOL and Facility = @cFacility

   SELECT TOP 1 @STAGEExists = case when EXISTS
   (SELECT loc FROM loc (NOLOCK) WHERE facility = @cFacility AND LocationType = 'STAGEOB' AND loc = @STAGE)
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

      --Suggesting location from provided pick zone. If none is provided, suggesting location from "saved" zone.
      SET @cPickZone = CASE WHEN isnull(@cPickZone,'') <> '' OR  (SELECT TOP 1 C_String30 FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = ''
      THEN @cPickZone 
      ELSE (SELECT TOP 1 C_String30 FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile)
   END

   -- Get storer config
   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
   
   -- Get loc info
   SET @cLogicalLOC = ''
   SELECT @cLogicalLOC = LogicalLocation FROM LOC WITH (NOLOCK) WHERE LOC = @cLOC and Facility = @cFacility

   -- Get PickHeader info
   SELECT TOP 1
   @cOrderKey = OrderKey,
   @cLoadKey = ExternOrderKey,
   @cZone = Zone
   FROM dbo.PickHeader WITH (NOLOCK)
   WHERE PickHeaderKey = @cPickSlipNo

   WHILE (1=1)
   BEGIN
      --If everything is picked from the pick zone, system to ask user to enter the new zone
      IF (SELECT TOP 1 ISNULL(C_String29,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = '1'
      BEGIN
         UPDATE rdt.RDTMOBREC
         SET C_String29 = '', C_String30 = '', I_Field05 = '', O_Field05 ='', V_String35=''
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
            AND LOC.Facility = @cFacility
            AND PD.Storerkey = @cStorerKey
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND (LOC.LogicalLocation > @cLogicalLOC
            AND LOC.PickZone = @cPickZone
            OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
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
            AND LOC.Facility = @cFacility
            AND PD.Storerkey = @cStorerKey
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND (LOC.LogicalLocation > @cLogicalLOC
            OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC
      END
         
      -- Discrete PickSlip
      ELSE IF @cOrderKey <> ''
      BEGIN
         IF @cPickZone<>''
            SELECT TOP 1 @cNewSuggLOC = LOC.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
            AND LOC.Facility = @cFacility
            AND PD.Storerkey = @cStorerKey
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND (LOC.LogicalLocation > @cLogicalLOC
            AND LOC.Pickzone=@cPickZone
            OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC   
            
         ELSE
            SELECT TOP 1 @cNewSuggLOC = LOC.LOC
            FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
            WHERE PD.OrderKey = @cOrderKey
            AND LOC.Facility = @cFacility
            AND PD.Storerkey = @cStorerKey
            AND PD.QTY > 0
            AND PD.Status <> '4'
            AND PD.Status < @cPickConfirmStatus
            AND (LOC.LogicalLocation > @cLogicalLOC
            OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
            GROUP BY LOC.LogicalLocation, LOC.LOC
            ORDER BY LOC.LogicalLocation, LOC.LOC
         END
         
         -- Conso PickSlip
         ELSE IF @cLoadKey <> ''
         BEGIN
            IF @cPickZone<>''
               SELECT TOP 1 @cNewSuggLOC = LOC.LOC
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey  
               AND LOC.Facility = @cFacility
               AND PD.Storerkey = @cStorerKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               AND LOC.Pickzone=@cPickZone
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
            
            ELSE
               SELECT TOP 1 @cNewSuggLOC = LOC.LOC
               FROM dbo.LoadPlanDetail LPD WITH (NOLOCK) 
               JOIN dbo.PickDetail PD (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)    
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE LPD.LoadKey = @cLoadKey  
               AND LOC.Facility = @cFacility
               AND PD.Storerkey = @cStorerKey
               AND PD.QTY > 0
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
         END
         
         -- Custom PickSlip
         ELSE
         BEGIN
            IF @cPickZone<>''
               SELECT TOP 1 @cNewSuggLOC = LOC.LOC
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND LOC.Facility = @cFacility
               AND PD.Storerkey = @cStorerKey
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               AND LOC.PickZone=@cPickZone
               OR  (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
            
            ELSE
               SELECT TOP 1 @cNewSuggLOC = LOC.LOC
               FROM dbo.PickDetail PD WITH (NOLOCK)
               JOIN dbo.LOC WITH (NOLOCK) ON (LOC.LOC = PD.LOC)
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND PD.QTY > 0
               AND LOC.Facility = @cFacility
               AND PD.Storerkey = @cStorerKey
               AND PD.Status <> '4'
               AND PD.Status < @cPickConfirmStatus
               AND (LOC.LogicalLocation > @cLogicalLOC
               OR (LOC.LogicalLocation = @cLogicalLOC AND LOC.LOC > @cLOC))
               GROUP BY LOC.LogicalLocation, LOC.LOC
               ORDER BY LOC.LogicalLocation, LOC.LOC
         END

         skip1:
         UPDATE rdt.RDTMOBREC WITH(ROWLOCK)
         SET C_String30 = CASE WHEN I_Field05 = '' THEN c_string30 ELSE I_Field05 END
         WHERE Mobile = @nMobile

         IF (SELECT TOP 1 isnull(C_String30,'') FROM rdt.RDTMOBREC (NOLOCK) WHERE Mobile = @nMobile) = ''
         BEGIN
            SET @cNewSuggLOC = 'Enter Zone'
         END

         -- Found suggest LOC
         IF @nStep NOT IN (1,2) AND NOT EXISTS 
         (SELECT 1 FROM dbo.PICKDETAIL PD WITH(NOLOCK)
         WHERE orderkey = 
            (SELECT TOP 1 OrderKey FROM dbo.PICKHEADER WITH(NOLOCK)
            WHERE PickHeaderKey = @cPickSlipNo)
            AND Storerkey = @cStorerKey
            AND Status = 0
            AND Storerkey = @cStorerKey
            AND EXISTS (SELECT 1 FROM dbo.LOC L WITH(NOLOCK) WHERE PD.loc = L.loc 
            AND L.PickZone = 
               (SELECT TOP 1 ISNULL(C_String30,'') FROM rdt.RDTMOBREC WITH(NOLOCK) WHERE Mobile = @nMobile) 
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

         DECLARE @orderkey NVARCHAR(20)

         SELECT TOP 1 @orderkey = OrderKey FROM dbo.PICKHEADER WITH(NOLOCK) WHERE PickHeaderKey = @cPickSlipNo

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
   
   END
   Quit:
END

GO