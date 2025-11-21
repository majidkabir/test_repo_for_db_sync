SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry14                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-04-20 1.0  Ung        WMS-19513 Created                            */
/***************************************************************************/

CREATE PROC [RDT].[rdt_727Inquiry14] (
 	@nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(20),  
   @cParam2      NVARCHAR(20),  
   @cParam3      NVARCHAR(20),  
   @cParam4      NVARCHAR(20),  
   @cParam5      NVARCHAR(20),  
   @c_oFieled01  NVARCHAR(20) OUTPUT,  
   @c_oFieled02  NVARCHAR(20) OUTPUT,  
   @c_oFieled03  NVARCHAR(20) OUTPUT,  
   @c_oFieled04  NVARCHAR(20) OUTPUT,  
   @c_oFieled05  NVARCHAR(20) OUTPUT,  
   @c_oFieled06  NVARCHAR(20) OUTPUT,  
   @c_oFieled07  NVARCHAR(20) OUTPUT,  
   @c_oFieled08  NVARCHAR(20) OUTPUT,  
   @c_oFieled09  NVARCHAR(20) OUTPUT,  
   @c_oFieled10  NVARCHAR(20) OUTPUT,  
   @c_oFieled11  NVARCHAR(20) OUTPUT,  
   @c_oFieled12  NVARCHAR(20) OUTPUT,  
   @nNextPage    INT          OUTPUT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR(20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE @tCaseID TABLE  
   (  
      RowRef      INT IDENTITY( 1, 1), 
      CaseID      NVARCHAR( 20)
   )  
   
   DECLARE @cLabel_LOC   NVARCHAR( 20)
   DECLARE @cLabel_Total NVARCHAR( 20)
   DECLARE @cLabel_Page  NVARCHAR( 20)

   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cLOC        NVARCHAR( 10)
   DECLARE @cCaseID     NVARCHAR( 20)
   DECLARE @nRowRef     INT
   DECLARE @nRowCount   INT
   DECLARE @nPage       INT
   DECLARE @nTotalPage  INT
   DECLARE @i           INT
   DECLARE @curCaseID   CURSOR

   SET @nErrNo = 0

   -- Get session info
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get label
   SET @cLabel_LOC = rdt.rdtgetmessage( 186003, @cLangCode, 'DSP') --LOC:
   SET @cLabel_Total = rdt.rdtgetmessage( 186004, @cLangCode, 'DSP') --TOTAL:
   SET @cLabel_Page  = rdt.rdtgetmessage( 186005, @cLangCode, 'DSP') --PAGE:         

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module, input screen
      BEGIN
         -- Parameter mapping
         SET @cID = @cParam1

         -- Check blank
         IF @cID = '' 
         BEGIN
            SET @nErrNo = 186001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
            GOTO Quit
         END
  
         -- Get case ID info
         INSERT INTO @tCaseID (CaseID)
         SELECT DISTINCT PD.CaseID 
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND PD.ID = @cID
            AND PD.CaseID <> ''
            AND PD.Status <> '4'
            AND PD.QTY > 0
         ORDER BY PD.CaseID
         
         -- Check ID valid
         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 186002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID
            GOTO Quit
         END
         
         -- Get LOC
         SELECT TOP 1 
            @cLOC = PD.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND PD.ID = @cID
            AND PD.CaseID <> ''
            AND PD.Status <> '4'
            AND PD.QTY > 0
         ORDER BY PD.CaseID
         
         -- Get counter
         SET @nPage = 1
         SET @nTotalPage = CEILING( @nRowCount / 6.0)

         SET @c_oFieled01 = @cID
         SET @c_oFieled02 = RTRIM( @cLabel_LOC) + ' ' + @cLOC
         SET @c_oFieled03 = RTRIM( @cLabel_Total) + ' ' + CAST( @nRowCount AS NVARCHAR( 5))
         SET @c_oFieled04 = RTRIM( @cLabel_Page) + ' ' + CAST( @nPage AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
         SET @c_oFieled05 = ''
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = ''
         SET @c_oFieled08 = ''
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = ''
  
         -- Populate case ID
         SET @i = 1
         SET @curCaseID = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT CaseID
            FROM @tCaseID
            ORDER BY CaseID
         OPEN @curCaseID
         FETCH NEXT FROM @curCaseID INTO @cCaseID
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @c_oFieled05 = @cCaseID ELSE
            IF @i = 2 SET @c_oFieled06 = @cCaseID ELSE
            IF @i = 3 SET @c_oFieled07 = @cCaseID ELSE
            IF @i = 4 SET @c_oFieled08 = @cCaseID ELSE
            IF @i = 5 SET @c_oFieled09 = @cCaseID ELSE
            IF @i = 6 SET @c_oFieled10 = @cCaseID
         
            SET @i = @i + 1
            IF @i > 6
               BREAK
         
            FETCH NEXT FROM @curCaseID INTO @cCaseID
         END

      	SET @nNextPage = 1  
      END
   
      IF @nStep IN (3, 4) -- Inquiry sub module, result screen
      BEGIN
         -- Param mapping
         SET @cID = @cParam1
         SET @cCaseID = @c_oFieled10  -- Last case ID of page
         
         -- No next page
         IF @cCaseID = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
         
         -- Get case ID info
         INSERT INTO @tCaseID (CaseID)
         SELECT DISTINCT PD.CaseID 
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND PD.ID = @cID
            AND PD.CaseID <> ''
            AND PD.Status <> '4'
            AND PD.QTY > 0
         ORDER BY PD.CaseID
         SET @nRowCount = @@ROWCOUNT
      
         -- Get next record
         SET @nRowRef = 0
         SELECT TOP 1 
            @nRowRef = RowRef 
         FROM @tCaseID 
         WHERE CaseID > @cCaseID 
         ORDER BY CaseID
         
         -- No next record
         IF @nRowRef = 0
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
         
         -- Get LOC
         SELECT TOP 1 
            @cLOC = PD.LOC
         FROM dbo.PickDetail PD WITH (NOLOCK)
            JOIN dbo.LOC WITH (NOLOCK) ON (PD.LOC = LOC.LOC)
         WHERE PD.StorerKey = @cStorerKey
            AND LOC.Facility = @cFacility
            AND PD.ID = @cID
            AND PD.CaseID <> ''
            AND PD.Status <> '4'
            AND PD.QTY > 0
         ORDER BY PD.CaseID
         
         -- Get counter
         SET @nTotalPage = CEILING( @nRowCount / 6.0)
         SET @nPage = CEILING( @nRowRef / 6.0)

         SET @c_oFieled01 = @cID
         SET @c_oFieled02 = RTRIM( @cLabel_LOC) + ' ' + @cLOC
         SET @c_oFieled03 = RTRIM( @cLabel_Total) + ' ' + CAST( @nRowCount AS NVARCHAR( 5))
         SET @c_oFieled04 = RTRIM( @cLabel_Page) + ' ' + CAST( @nPage AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
         SET @c_oFieled05 = ''
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = ''
         SET @c_oFieled08 = ''
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = ''
  
         -- Populate case ID
         SET @i = 1
         SET @curCaseID = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT CaseID
            FROM @tCaseID
            WHERE CaseID > @cCaseID
            ORDER BY CaseID
         OPEN @curCaseID
         FETCH NEXT FROM @curCaseID INTO @cCaseID
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @c_oFieled05 = @cCaseID ELSE
            IF @i = 2 SET @c_oFieled06 = @cCaseID ELSE
            IF @i = 3 SET @c_oFieled07 = @cCaseID ELSE
            IF @i = 4 SET @c_oFieled08 = @cCaseID ELSE
            IF @i = 5 SET @c_oFieled09 = @cCaseID ELSE
            IF @i = 6 SET @c_oFieled10 = @cCaseID
         
            SET @i = @i + 1
            IF @i > 6
               BREAK
         
            FETCH NEXT FROM @curCaseID INTO @cCaseID
         END
         
         SET @nNextPage = 1 

      END
   END

Quit:

END

GO