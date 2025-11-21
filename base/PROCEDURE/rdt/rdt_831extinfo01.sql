SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_831ExtInfo01                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2019-08-22  1.0  Ung      WMS-10176 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_831ExtInfo01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nAfterStep     INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cWaveKey       NVARCHAR( 10),
   @cPWZone        NVARCHAR( 10),
   @cCartonID1     NVARCHAR( 20),
   @cCartonID2     NVARCHAR( 20),
   @cCartonID3     NVARCHAR( 20),
   @cCartonID4     NVARCHAR( 20),
   @cCartonID5     NVARCHAR( 20),
   @cCartonID6     NVARCHAR( 20),
   @cCartonID7     NVARCHAR( 20),
   @cCartonID8     NVARCHAR( 20),
   @cCartonID9     NVARCHAR( 20),
   @cCartonID      NVARCHAR( 20),
   @cPosition      NVARCHAR( 10),
   @cSuggLOC       NVARCHAR( 10),
   @cSuggSKU       NVARCHAR( 20),
   @nTaskQTY       INT,
   @nTotalQTY      INT,
   @cLOC           NVARCHAR( 10),
   @cSKU           NVARCHAR( 20),
   @nQTY           INT,
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @tVar           VariableTable  READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 831 -- Pick by carton ID
   BEGIN
      IF @nAfterStep = 3 AND  -- Carton ID
        (@nStep = 4 OR        -- LOC
         @nStep = 6)          -- Carton ID
      BEGIN
         DECLARE @cNotPick NVARCHAR( 1)
         DECLARE @cShort   NVARCHAR( 1)
         DECLARE @cMsg     NVARCHAR( 20)
         DECLARE @cMsg1    NVARCHAR( 20)
         DECLARE @cMsg2    NVARCHAR( 20)
         DECLARE @cMsg3    NVARCHAR( 20)
         DECLARE @cMsg4    NVARCHAR( 20)
         DECLARE @cMsg5    NVARCHAR( 20)
         DECLARE @cMsg6    NVARCHAR( 20)
         DECLARE @cMsg7    NVARCHAR( 20)
         DECLARE @cMsg8    NVARCHAR( 20)
         DECLARE @cMsg9    NVARCHAR( 20)
         DECLARE @i        INT
         
         SET @cMsg1 = ''
         SET @cMsg2 = ''
         SET @cMsg3 = ''
         SET @cMsg4 = ''
         SET @cMsg5 = ''
         SET @cMsg6 = ''
         SET @cMsg7 = ''
         SET @cMsg8 = ''
         SET @cMsg9 = ''

         SET @i = 1
         SET @cCartonID = ''
         
         -- Loop carton 1..9
         WHILE @i < 10
         BEGIN
            SET @cMsg = ''
            SET @cNotPick = ''
            SET @cShort = ''

            IF @i = 1 SET @cCartonID = @cCartonID1 ELSE
            IF @i = 2 SET @cCartonID = @cCartonID2 ELSE
            IF @i = 3 SET @cCartonID = @cCartonID3 ELSE
            IF @i = 4 SET @cCartonID = @cCartonID4 ELSE
            IF @i = 5 SET @cCartonID = @cCartonID5 ELSE
            IF @i = 6 SET @cCartonID = @cCartonID6 ELSE
            IF @i = 7 SET @cCartonID = @cCartonID7 ELSE
            IF @i = 8 SET @cCartonID = @cCartonID8 ELSE
            IF @i = 9 SET @cCartonID = @cCartonID9

            IF @cCartonID <> ''
            BEGIN               
               -- Check not pick
               IF EXISTS( SELECT TOP 1 1 
                  FROM WaveDetail WD WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
                     JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  WHERE WD.WaveKey = @cWaveKey
                     -- AND LOC.PutawayZone = @cPWZone
                     AND PD.CaseID = @cCartonID
                     AND PD.Status < '5'
                     AND PD.Status <> '4'
                     AND PD.QTY > 0)
                  SET @cNotPick = 'Y'

               -- Check short
               IF EXISTS( SELECT TOP 1 1 
                  FROM WaveDetail WD WITH (NOLOCK)
                     JOIN dbo.PickDetail PD WITH (NOLOCK) ON (WD.OrderKey = PD.OrderKey)
                     JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
                  WHERE WD.WaveKey = @cWaveKey
                     -- AND LOC.PutawayZone = @cPWZone
                     AND PD.CaseID = @cCartonID
                     AND PD.Status = '4'
                     AND PD.QTY > 0)
                  SET @cShort = 'Y'

               -- Set carton status
               SET @cMsg = 
                  CASE 
                     WHEN @cNotPick = 'Y' 
                     THEN RTRIM( rdt.rdtgetmessage( 143701, @cLangCode, 'DSP')) --MORE 
  
                     WHEN @cShort = 'Y' 
                     THEN RTRIM( rdt.rdtgetmessage( 143702, @cLangCode, 'DSP')) --SHORT
                     
                     ELSE RTRIM( rdt.rdtgetmessage( 143703, @cLangCode, 'DSP')) --END
                  END
            END

            -- Put position
            SET @cMsg = CAST( @i AS NVARCHAR(1)) + '. ' + @cMsg

            -- Set message
            IF @i = 1 SET @cMsg1 = @cMsg ELSE
            IF @i = 2 SET @cMsg2 = @cMsg ELSE
            IF @i = 3 SET @cMsg3 = @cMsg ELSE
            IF @i = 4 SET @cMsg4 = @cMsg ELSE
            IF @i = 5 SET @cMsg5 = @cMsg ELSE
            IF @i = 6 SET @cMsg6 = @cMsg ELSE
            IF @i = 7 SET @cMsg7 = @cMsg ELSE
            IF @i = 8 SET @cMsg8 = @cMsg ELSE
            IF @i = 9 SET @cMsg9 = @cMsg
         
            SET @i = @i + 1
         END

         -- Prompt each carton status
         EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cMsg1, @cMsg2, @cMsg3, @cMsg4, @cMsg5, @cMsg6, @cMsg7, @cMsg8, @cMsg9
         SET @nErrNo = 0
      END
      
      IF @nAfterStep = 6 -- Confirm carton ID
      BEGIN
         DECLARE @nPickQTY  INT = 0
         DECLARE @nCartonQTY INT = 0
         
         -- Get statistic of confirm carton
         SELECT TOP 1
            @nPickQTY = SUM( CASE WHEN PD.Status = '5' THEN PD.QTY ELSE 0 END), 
            @nCartonQTY = SUM( PD.QTY)
         FROM dbo.PickDetail PD WITH (NOLOCK)
         WHERE PD.StorerKey = @cStorerKey
            AND PD.CaseID = @cCartonID
            AND PD.Status <> '4'
            AND PD.QTY > 0

         -- Top up current task
         SET @nPickQTY = @nPickQTY + @nQTY
         SET @nCartonQTY = @nCartonQTY - (@nTaskQTY - @nQTY) -- Deduce current task short, if any
         
         -- Statistic
         SET @cExtendedInfo = 
            RTRIM( rdt.rdtgetmessage( 143704, @cLangCode, 'DSP')) + ' ' + --TOTAL: 
            CAST( @nPickQTY AS NVARCHAR(5)) + '/' + 
            CAST( @nCartonQTY AS NVARCHAR(5))
      END
   END
END

GO