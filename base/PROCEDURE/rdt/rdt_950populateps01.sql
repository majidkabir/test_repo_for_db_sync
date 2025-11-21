SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_950PopulatePS01                                       */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Purpose: Populate pick slip                                                */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 16-Aug-2016 1.0  Ung      SOS375224 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_950PopulatePS01] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5),
   @cStorerKey    NVARCHAR( 15),
	@cWaveKey      NVARCHAR( 10),
	@cLoadKey      NVARCHAR( 10),
   @cPickZone     NVARCHAR( 10),
   @cPKSlip_Cnt   NVARCHAR( 1), 
   @cCountry      NVARCHAR( 20),
   @cFromLoc      NVARCHAR( 10),
   @cToLoc        NVARCHAR( 10),
   @cPickSlipNo1  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo2  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo3  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo4  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo5  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo6  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo7  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo8  NVARCHAR( 10) OUTPUT,
   @cPickSlipNo9  NVARCHAR( 10) OUTPUT,
   @cPickSlipType NVARCHAR( 1)  OUTPUT,
   @nErrNo        INT           OUTPUT,
   @cErrMsg       NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @i           INT
   
   SET @i = 1
   SET @cPickSlipNo1 = ''
   SET @cPickSlipNo2 = ''
   SET @cPickSlipNo3 = ''
   SET @cPickSlipNo4 = ''
   SET @cPickSlipNo5 = ''
   SET @cPickSlipNo6 = ''
   SET @cPickSlipNo7 = ''
   SET @cPickSlipNo8 = ''
   SET @cPickSlipNo9 = ''

   -- Get the pickslip to display
   DECLARE @curPS CURSOR
   IF @cWaveKey <> ''
      SET @curPS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PH.PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)   
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.WaveDetail WD WITH (NOLOCK) ON (WD.Orderkey = O.Orderkey) 
         WHERE WD.WaveKey = @cWaveKey
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND ISNULL( O.C_Country, '') = CASE WHEN @cCountry = '' THEN ISNULL( O.C_Country, '') ELSE @cCountry END
            AND LOC.PickZone = CASE WHEN @cPickZone = '' THEN LOC.PickZone ELSE @cPickZone END
            AND PD.LOC >= CASE WHEN @cFromLOC = '' THEN PD.LOC ELSE @cFromLOC END
            AND PD.LOC <= CASE WHEN @cToLOC = '' THEN PD.LOC ELSE @cToLOC END
         GROUP BY PH.PickHeaderKey, O.Priority
         ORDER BY O.Priority, SUM( PD.QTY) DESC  -- Pickslip returned shd follow orders.priority, biggest unpick qty

   ELSE IF @cLoadKey <> ''
      SET @curPS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PH.PickHeaderKey
         FROM dbo.PickHeader PH WITH (NOLOCK)
            JOIN dbo.Orders O WITH (NOLOCK) ON (PH.Orderkey = O.Orderkey) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)   
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.Orderkey = O.Orderkey) 
         WHERE LPD.LoadKey = @cLoadKey
            AND PD.Status < '3'
            AND PD.QTY > 0
            AND ISNULL( O.C_Country, '') = CASE WHEN @cCountry = '' THEN ISNULL( O.C_Country, '') ELSE @cCountry END
            AND LOC.PickZone = CASE WHEN @cPickZone = '' THEN LOC.PickZone ELSE @cPickZone END
            AND PD.LOC >= CASE WHEN @cFromLOC = '' THEN PD.LOC ELSE @cFromLOC END
            AND PD.LOC <= CASE WHEN @cToLOC = '' THEN PD.LOC ELSE @cToLOC END
         GROUP BY PH.PickHeaderKey, O.Priority
         ORDER BY O.Priority, SUM( PD.QTY) DESC  -- Pickslip returned shd follow orders.priority, biggest unpick qty

   OPEN @curPS
   FETCH NEXT FROM @curPS INTO @cPickSlipNo
   WHILE @@FETCH_STATUS = 0
   BEGIN
      -- No zone and LOC range
      IF @cPickZone = '' AND @cFromLOC = ''
      BEGIN
         -- Check PickSlip locked by others
         IF EXISTS( SELECT TOP 1 1 
            FROM rdt.rdtDynamicPickLog WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND AddWho <> SUSER_NAME())
         BEGIN
            FETCH NEXT FROM @curPS INTO @cPickSlipNo
            CONTINUE
         END
      END
   
      -- Zone
      ELSE IF @cPickZone <> '' AND @cFromLOC = ''
      BEGIN
         -- Check PickSlip locked by others
         IF EXISTS( SELECT TOP 1 1 
            FROM rdt.rdtDynamicPickLog L WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo
               AND ((Zone = '' AND FromLOC = '')
               OR (Zone = @cPickZone)
               OR (Zone = '' AND EXISTS( SELECT 1 
                  FROM LOC WITH (NOLOCK) 
                  WHERE Facility = @cFacility
                     AND PickZone = @cPickZone 
                     AND LOC.LOC BETWEEN L.FromLOC AND L.ToLOC)))
               AND AddWho <> SUSER_NAME())
         BEGIN
            FETCH NEXT FROM @curPS INTO @cPickSlipNo
            CONTINUE
         END
      END
      
      -- LOC range
      ELSE IF @cPickZone = '' AND @cFromLOC <> ''
      BEGIN
         -- Check PickSlip locked by others
         IF EXISTS( SELECT TOP 1 1 
            FROM rdt.rdtDynamicPickLog L WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo 
               AND ((Zone = '' AND FromLOC = '')
               OR (Zone <> '' AND FromLOC = '' AND EXISTS( 
                  SELECT 1 
                  FROM LOC WITH (NOLOCK) 
                  WHERE Facility = @cFacility
                     AND PickZone = L.Zone 
                     AND LOC.LOC BETWEEN L.FromLOC AND L.ToLOC)))
               OR (Zone = '' AND FromLOC <> '' AND @cFromLOC >= L.FromLOC AND @cToLOC <= L.ToLOC)
               AND AddWho <> SUSER_NAME())
         BEGIN
            FETCH NEXT FROM @curPS INTO @cPickSlipNo
            CONTINUE
         END
      END
      
      IF @i = 1 SET @cPickSlipNo1 = @cPickSlipNo
      IF @i = 2 SET @cPickSlipNo2 = @cPickSlipNo
      IF @i = 3 SET @cPickSlipNo3 = @cPickSlipNo
      IF @i = 4 SET @cPickSlipNo4 = @cPickSlipNo
      IF @i = 5 SET @cPickSlipNo5 = @cPickSlipNo
      IF @i = 6 SET @cPickSlipNo6 = @cPickSlipNo
      IF @i = 7 SET @cPickSlipNo7 = @cPickSlipNo
      IF @i = 8 SET @cPickSlipNo8 = @cPickSlipNo
      IF @i = 9 SET @cPickSlipNo9 = @cPickSlipNo
      
      SET @i = @i + 1
      
      IF @i > @cPKSlip_Cnt
         BREAK

      FETCH NEXT FROM @curPS INTO @cPickSlipNo
   END
   
   -- Decide pick slip type
   IF @cPickSlipNo1 <> ''
      SET @cPickSlipType = 'D' -- Discrete
END

GO