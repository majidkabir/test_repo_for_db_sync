SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_950PickSlipSP01                                       */
/* Copyright      : IDS                                                       */
/*                                                                            */
/* Purpose: Populate pickslip for Pick And Pack function                      */
/*                                                                            */
/* Called from: rdtfnc_DynamicPick_PickAndPack                                */
/*                                                                            */
/* Exceed version: 5.4                                                        */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author      Purposes                                      */
/* 20-Mar-2018 1.0  James       WMS4107. Created                              */
/******************************************************************************/

CREATE PROC [RDT].[rdt_950PickSlipSP01] (
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
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cPriority   NVARCHAR(1),
           @nTotalQty   INT,
           @nLoop       INT,
           @cPickSlipNo NVARCHAR(10)

   SET @nLoop = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         -- Get the pickslip to display
         DECLARE @curDP  CURSOR
         SET @curDP = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT PD.PickSlipNo, O.Priority, SUM(PD.QTY)
            FROM dbo.WAVEDETAIL W WITH (NOLOCK) 
            JOIN dbo.Orders O WITH (NOLOCK) ON (W.Orderkey = O.Orderkey) 
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = O.OrderKey)   
            JOIN dbo.LOC L WITH (NOLOCK) ON (PD.LOC = L.LOC)
            WHERE W.WaveKey = @cWaveKey
               AND PD.Status < '3'
               AND L.PutawayZone = @cPickZone
               AND ISNULL( O.C_Country, '') = CASE WHEN @cCountry = '' THEN ISNULL( O.C_Country, '') ELSE @cCountry END
               AND PD.LOC >= CASE WHEN @cFromLoc = '' THEN PD.LOC ELSE @cFromLoc END
               AND PD.LOC <= CASE WHEN @cToLoc = '' THEN PD.LOC ELSE @cToLoc END
               AND NOT EXISTS
                  (SELECT 1 FROM RDT.RDTDynamicPickLog DPL WITH (NOLOCK)
                  WHERE DPL.PickSlipNo = PD.PickSlipNo
                     AND DPL.Zone = @cPickZone)
               GROUP BY PD.PickSlipNo, O.Priority
              HAVING SUM(PD.QTY) > 0
               ORDER BY O.Priority, SUM(PD.QTY) DESC  -- Pickslip returned shd follow orders.priority, biggest unpick qty
         OPEN @curDP
         FETCH NEXT FROM @curDP INTO @cPickSlipNo, @cPriority, @nTotalQty
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nLoop = 0 SET @cPickSlipNo1 = @cPickSlipNo
            IF @nLoop = 1 SET @cPickSlipNo2 = @cPickSlipNo
            IF @nLoop = 2 SET @cPickSlipNo3 = @cPickSlipNo
            IF @nLoop = 3 SET @cPickSlipNo4 = @cPickSlipNo
            IF @nLoop = 4 SET @cPickSlipNo5 = @cPickSlipNo
            IF @nLoop = 5 SET @cPickSlipNo6 = @cPickSlipNo
            IF @nLoop = 6 SET @cPickSlipNo7 = @cPickSlipNo
            IF @nLoop = 7 SET @cPickSlipNo8 = @cPickSlipNo
            IF @nLoop = 8 SET @cPickSlipNo9 = @cPickSlipNo
            SET @nLoop = @nLoop + 1
            IF @nLoop = @cPKSlip_Cnt BREAK

            FETCH NEXT FROM @curDP INTO @cPickSlipNo, @cPriority, @nTotalQty
         END
         CLOSE @curDP
         DEALLOCATE @curDP

         -- Decide pick slip type  
      IF @cPickSlipNo1 <> ''  
         SET @cPickSlipType = 'D' -- Discrete  
      END
   END
END

GO