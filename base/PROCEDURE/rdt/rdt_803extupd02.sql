SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_803ExtUpd02                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 13-07-2016 1.0  Ung      SOS368861 Created                                 */
/* 04-05-2017 1.1  Ung      WMS-1856 Fix sum with null                        */
/* 05-12-2017 1.2  Ung      WMS-3568 Add UpdateStatus                         */
/* 05-03-2018 1.3  Ung      WMS-3788 Add all completed                        */
/******************************************************************************/

CREATE PROC [RDT].[rdt_803ExtUpd02] (
   @nMobile      INT,           
   @nFunc        INT,           
   @cLangCode    NVARCHAR( 3),  
   @nStep        INT,           
   @nInputKey    INT,           
   @cFacility    NVARCHAR( 5),   
   @cStorerKey   NVARCHAR( 15), 
   @cStation     NVARCHAR( 10), 
   @cMethod      NVARCHAR( 1),  
   @cSKU         NVARCHAR( 20), 
   @cLastPos     NVARCHAR( 10), 
   @cOption      NVARCHAR( 1),  
   @nErrNo       INT            OUTPUT, 
   @cErrMsg      NVARCHAR( 20)  OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 803 -- PTLPiece
   BEGIN
      IF @nStep = 3 -- Matrix
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @i         INT
            DECLARE @cPosition NVARCHAR(10)
            DECLARE @cOrderKey NVARCHAR(10)
            DECLARE @cWaveKey  NVARCHAR(10)
            DECLARE @nTotal    INT
            DECLARE @nSorted   INT
            DECLARE @cMsg      NVARCHAR(20)
            DECLARE @cMsg01    NVARCHAR(20)
            DECLARE @cMsg02    NVARCHAR(20)
            DECLARE @cMsg03    NVARCHAR(20)
            DECLARE @cMsg04    NVARCHAR(20)
            DECLARE @cMsg05    NVARCHAR(20)
            DECLARE @cMsg06    NVARCHAR(20)
            DECLARE @cMsg07    NVARCHAR(20)
            DECLARE @cMsg08    NVARCHAR(20)
            DECLARE @cMsg09    NVARCHAR(20)
            DECLARE @cMsg10    NVARCHAR(20)
            DECLARE @cUpdateCaseID  NVARCHAR( 1)
            DECLARE @cUpdateStatus  NVARCHAR( 1)

            -- Storer config
            SET @cUpdateCaseID = rdt.RDTGetConfig( @nFunc, 'UpdateCaseID', @cStorerKey)    
            SET @cUpdateStatus = rdt.RDTGetConfig( @nFunc, 'UpdateStatus', @cStorerKey)
            IF @cUpdateStatus NOT IN ('0', '3', '5')
               SET @cUpdateStatus = '0'
                         
            SET @i = 1
            SET @cMsg = ''
            SET @cMsg01 = ''
            SET @cMsg02 = ''
            SET @cMsg03 = ''
            SET @cMsg04 = ''
            SET @cMsg05 = ''
            SET @cMsg06 = ''
            SET @cMsg07 = ''
            SET @cMsg08 = ''
            SET @cMsg09 = ''
            SET @cMsg10 = ''
                         
            -- Get WaveKey
            SELECT @cWaveKey = WaveKey FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) WHERE Station = @cStation 
            
            -- Have oustanding order
            IF EXISTS( SELECT 1 
				FROM WaveDetail WD WITH (NOLOCK) 
					JOIN Orders O WITH (NOLOCK) ON (WD.OrderKey = O.OrderKey)
				WHERE WD.WaveKey = @cWaveKey 
					AND O.Status < '5')
            BEGIN
               DECLARE @curPos CURSOR
               SET @curPos = CURSOR FOR
                  SELECT L.Position, L.OrderKey, 
                     SUM( PD.QTY), 
                     SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY 
                               WHEN @cUpdateCaseID <> '0' AND PD.CaseID <> '' THEN PD.QTY
                               WHEN @cUpdateStatus <> '0' AND PD.Status = @cUpdateStatus THEN PD.QTY
                               ELSE 0 
                          END)
                  FROM rdt.rdtPTLPieceLog L WITH (NOLOCK) 
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = L.OrderKey)
                  WHERE Station = @cStation
                     AND PD.QTY > 0
                     AND PD.Status <> '4'
                  GROUP BY L.Position, L.OrderKey
                  HAVING SUM( PD.QTY) <> 
                     SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY ELSE 0 END)
                  ORDER BY L.Position
                  
               OPEN @curPos
               FETCH NEXT FROM @curPos INTO @cPosition, @cOrderKey, @nTotal, @nSorted
               WHILE @@FETCH_STATUS = 0
               BEGIN
                  SET @cMsg = 
                     RTRIM( @cPosition) + '-' + 
                     @cOrderKey + '=' + 
                     CAST( ISNULL( @nSorted, 0) AS NVARCHAR(5)) + '/' + 
                     CAST( ISNULL( @nTotal, 0) AS NVARCHAR(5))
                  
                  IF @i = 1  SET @cMsg01 = @cMsg ELSE
                  IF @i = 2  SET @cMsg02 = @cMsg ELSE
                  IF @i = 3  SET @cMsg03 = @cMsg ELSE
                  IF @i = 4  SET @cMsg04 = @cMsg ELSE
                  IF @i = 5  SET @cMsg05 = @cMsg ELSE
                  IF @i = 6  SET @cMsg06 = @cMsg ELSE
                  IF @i = 7  SET @cMsg07 = @cMsg ELSE
                  IF @i = 8  SET @cMsg08 = @cMsg ELSE
                  IF @i = 9  SET @cMsg09 = @cMsg ELSE
                  IF @i = 10 SET @cMsg10 = @cMsg
                  
                  SET @i = @i + 1
                  IF @i > 10
                     BREAK
                     
                  FETCH NEXT FROM @curPos INTO @cPosition, @cOrderKey, @nTotal, @nSorted
               END
               
               -- Prompt outstanding
               IF @cMsg01 <> ''
                  EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, 
                     @cMsg01, 
                     @cMsg02, 
                     @cMsg03, 
                     @cMsg04, 
                     @cMsg05, 
                     @cMsg06, 
                     @cMsg07, 
                     @cMsg08, 
                     @cMsg09, 
                     @cMsg10
            END
            
            -- No outstanding order
            ELSE
            BEGIN
               SET @nErrNo = 123001
               SET @cMsg01 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Wave Completed
               EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo, @cErrMsg, 
                  @cMsg01
               SET @nErrNo = 0
            END
         END
      END
   END
END

GO