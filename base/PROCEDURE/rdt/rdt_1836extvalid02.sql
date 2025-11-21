SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/****************************************************************************/  
/* Store procedure: rdt_1836ExtValid02                                      */  
/* Copyright      : Maersk                                                  */    
/* Client         : Levis USA                                               */    
/* Purpose        : location checking                                       */
/*                  once location override happened                         */  
/*                                                                          */  
/* Modifications log:                                                       */  
/*                                                                          */  
/* Date         Author    Ver.    Purposes                                  */  
/* 2024-12-04   YYS027    1.0.0   FCR-1489 Created                          */  
/****************************************************************************/  
  
CREATE   PROCEDURE [RDT].[rdt_1836ExtValid02]  
   @nMobile         INT,  
   @nFunc           INT,  
   @cLangCode       NVARCHAR( 3),  
   @nStep           INT,  
   @nInputKey       INT,  
   @cTaskdetailKey  NVARCHAR( 10),  
   @cFinalLOC       NVARCHAR( 10),  
   @nErrNo          INT             OUTPUT,  
   @cErrMsg         NVARCHAR( 20)   OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nTranCount        INT
   DECLARE @cTaskKey          NVARCHAR( 10)
   DECLARE @cTaskType         NVARCHAR( 10)
   DECLARE @cCaseID           NVARCHAR( 20)
   DECLARE @cStorerKey        NVARCHAR( 15)
   DECLARE @cPickDetailKey    NVARCHAR( 15)
   DECLARE @cWaveKey          NVARCHAR( 10)
   DECLARE @cTDWaveKey        NVARCHAR( 10)
   DECLARE @cFacility         NVARCHAR( 5)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @cLot              NVARCHAR( 10)
   DECLARE @cLoc              NVARCHAR( 10)
   DECLARE @cId               NVARCHAR( 10)
   DECLARE @cSKU              NVARCHAR( 20)
   DECLARE @nQty              INT
   DECLARE @nPDQty            INT
   DECLARE @nBalQty           INT
   DECLARE @curTask           CURSOR
   DECLARE @curPD             CURSOR
   DECLARE @curCPK            CURSOR
   DECLARE @cAreakey          NVARCHAR(20)
   DECLARE @cFromLOC          NVARCHAR( 10)
   DECLARE @cSuggToLOC        NVARCHAR( 10)
   DECLARE @cSuggFinalLoc     NVARCHAR( 10)
   --DECLARE @nQty              INT
   DECLARE @cRefTaskKey       NVARCHAR( 10)
--   DECLARE @nIdx              INT
--   DECLARE @nCount        INT
--   DECLARE @pickkeys          TABLE(PickDetailKey    NVARCHAR( 15),ID INT)
   SET @nTranCount = @@TRANCOUNT

   SELECT @cFacility = FACILITY
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nFUNC=1836
   BEGIN
      IF @nStep = 1
      BEGIN
         IF (@nInputKey='1')
         BEGIN
            -- Get task info
            SELECT
               @cTaskType     = TaskType,
               @cStorerKey    = Storerkey,
               @cWaveKey      = WaveKey,
               @cAreakey      = Areakey,
               @cCaseID       = CaseID,    
               @cFromLOC      = FromLOC,    
               @cSuggToLOC    = ToLOC,
               @cSuggFinalLoc = finalloc,
               @cSKU          = Sku,
               @cLot          = Lot,
               @nQty          = Qty,   
               @cRefTaskKey   = RefTaskKey
            FROM dbo.TaskDetail WITH (NOLOCK)
            WHERE TaskdetailKey = @cTaskdetailKey

            --User is allowed to override the suggested location while scanning the final location on 1836, but the location scanned should meet below requirement.
            --Loc.LocationType = 'PICK'
            --Loc.LocationFlag <> 'DAMAGE' / 'HOLD'
            --Loc.PickZone = 'PICK'
            --If the final location does not meet the above requirement, please raise an error 'Invalid Location'.   
            IF NOT EXISTS(SELECT * FROM loc  (NOLOCK)  WHERE Loc.LocationType = 'PICK' AND Loc.LocationFlag NOT IN ( 'DAMAGE' , 'HOLD')
               AND Loc.PickZone = 'PICK' AND loc.Loc=@cFinalLOC )
            BEGIN
               SET @nErrNo = 230051   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Invalid Location
               GOTO QUIT
            END

         END
      END
   END
QUIT:

END  

GO