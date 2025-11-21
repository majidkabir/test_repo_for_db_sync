SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_579ExtUpd01                                           */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 05-03-2018 1.0  Ung      WMS-4202 Created                                  */
/******************************************************************************/

CREATE PROC [RDT].[rdt_579ExtUpd01] (
   @nMobile     INT,
   @nFunc       INT,
   @nScn        INT,
   @nStep       INT,
   @nInputKey   INT,
   @cLangCode   NVARCHAR( 3) ,
   @cStorerkey  NVARCHAR( 15),
   @cFacility   NVARCHAR( 5) ,
   @cType       NVARCHAR( 10), 
   @cLoadKey    NVARCHAR( 10),
   @cUCCNo      NVARCHAR( 20),
   @cScan       NVARCHAR( 5), 
   @cTotal      NVARCHAR( 5), 
   @cPOS        NVARCHAR( 20), 
   @cSortInf1   NVARCHAR( 20), 
   @cSortInf2   NVARCHAR( 20), 
   @cSortInf3   NVARCHAR( 20), 
   @cSortInf4   NVARCHAR( 20), 
   @cSortInf5   NVARCHAR( 20), 
   @nErrNo      INT           OUTPUT,
   @cErrMsg     NVARCHAR(20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nFunc = 579 -- Sort case
   BEGIN
      IF @nStep = 2 -- UCC / SKU
      BEGIN
         IF @nInputKey = 0 -- ESC
         BEGIN
            DECLARE @i         INT
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
                         
            DECLARE @curLoad CURSOR
            SET @curLoad = CURSOR FOR
               SELECT 
                  A.LoadKey, SUM( A.Total), SUM( A.Sorted)
               FROM
               (
                  SELECT 
                     L.RowRef, LPD.LoadKey, 
                     CAST( SUM( PD.QTY) / Pack.CaseCnt AS INT) AS Total, 
                     CAST( SUM( CASE WHEN PD.CaseID = 'SORTED' THEN PD.QTY ELSE 0 END) / Pack.CaseCnt AS INT) AS Sorted
                  FROM rdt.rdtSortCaseLog L WITH (NOLOCK) 
                     JOIN LoadPlanDetail LPD WITH (NOLOCK) ON (LPD.LoadKey = L.LoadKey)
                     JOIN PickDetail PD WITH (NOLOCK) ON (PD.OrderKey = LPD.OrderKey)
                     JOIN SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
                     JOIN Pack WITH (NOLOCK) ON (Pack.PackKey = SKU.PackKey)
                  WHERE L.Mobile = @nMobile
                     AND PD.QTY > 0
                     AND PD.Status < '5'
                     AND PD.Status <> '4' -- Short
                     AND PD.UOM = '2'
                     -- AND PD.CaseID = 'SORTED'
                     AND Pack.CaseCnt > 0
                  GROUP BY L.RowRef, LPD.LoadKey, PD.SKU, Pack.CaseCnt
               ) AS A
               GROUP BY A.RowRef, A.LoadKey
               ORDER BY A.RowRef, A.LoadKey
               
            OPEN @curLoad
            FETCH NEXT FROM @curLoad INTO @cLoadKey, @nTotal, @nSorted
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SET @cMsg = 
                  RIGHT( '0' + CAST( @i AS NVARCHAR(2)), 2) + '-' + 
                  @cLoadKey + '=' + 
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
                  
               FETCH NEXT FROM @curLoad INTO @cLoadKey, @nTotal, @nSorted
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
      END
   END
END

GO