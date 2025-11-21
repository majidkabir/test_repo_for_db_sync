SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: [rdt_727InquiryUCCPLT]                                 */
/* Copyright      : Maersk                                                 */
/* Customer       : Granite                                                */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2024-09-06 1.0  SK         Inquiry Based on the LOC, LPN, UCC           */
/***************************************************************************/
CREATE   PROC [RDT].[rdt_727InquiryUCCPLT] (
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

   DECLARE @tUCC TABLE  
   (  
      RowRef      INT IDENTITY( 1, 1), 
      UCC         NVARCHAR( 20)
   )  
   
   DECLARE @cLabel_LOC     NVARCHAR( 20)
   DECLARE @cLabel_PLT     NVARCHAR( 20)
   DECLARE @cLabel_UCC     NVARCHAR( 20)
   DECLARE @cLabel_UCCNo   NVARCHAR( 20)

   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @cLOC           NVARCHAR( 10)
   DECLARE @cUCC           NVARCHAR( 20)
   DECLARE @nRowRef        INT
   DECLARE @nRowCount      INT
   DECLARE @nPage          INT
   DECLARE @nTotalPage     INT
   DECLARE @i              INT
   DECLARE @curUCC         CURSOR
   DECLARE @curUCC1        CURSOR
   DECLARE @nTotalUCC      INT
   DECLARE @nPLTTotal      INT
   DECLARE @cPrm1          NVARCHAR(20)  
   DECLARE @cPrm2          NVARCHAR(20) 

   SET @nErrNo = 0

   SET @c_oFieled11   =   ''
   SET @c_oFieled12   =   ''

   -- Get session info
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   -- Get Param1 info
   SELECT @cPrm1 = CASE WHEN @cParam1 <> '' THEN @cParam1 ELSE V_String3 END FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
   -- Get Param2 info
   SELECT @cPrm2 = CASE WHEN @cParam2 <> '' THEN @cParam2 ELSE V_String4 END  FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile


   -- Get label
   SET @cLabel_LOC = @cParam1   --rdt.rdtgetmessage( 186003, @cLangCode, 'DSP') --LOC:
   SET @cLabel_PLT = rdt.rdtgetmessage( 181552, @cLangCode, 'DSP') --LP:
   SET @cLabel_UCC  = rdt.rdtgetmessage( 181553, @cLangCode, 'DSP') -- UCC COUNT: 
   SET @cLabel_UCCNo  = rdt.rdtgetmessage( 181604, @cLangCode, 'DSP') -- UCC NO Label: 
   

    -- Parameter mapping
    SET @cLOC = CASE WHEN @cParam1 = '' THEN '%' ELSE @cParam1 END 
   SET @cID = CASE WHEN @cParam2 <> '' THEN @cParam2 ELSE '%' END   

   -- GET Pallet Count
   SELECT @nPLTTotal = Count(distinct lli.ID) 
   FROM   BI.V_LOTxLOCxID (NOLOCK) lli
   JOIN BI.V_LOTATTRIBUTE (NOLOCK) la ON (lli.Lot=la.Lot)  
   LEFT JOIN UCC (nolock) UCC ON lli.SKU = UCC.SKU AND lli.StorerKey = UCC.Storerkey and lli.loc =UCC.loc and lli.id=UCC.id 
   WHERE
      lli.StorerKey = @cStorerKey
   AND lli.Loc like @cLOC
   AND lli.id  like @cID
   AND lli.qty > 0 
   AND Ucc.Uccno is not null 


   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module, input screen
      BEGIN
         -- Check blank
         IF @cParam1 = '' AND @cParam2 = '' 
         BEGIN
            SET @nErrNo = 224801
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID OR LOC
            GOTO Quit
         END

         -- Get UCC info
         INSERT INTO @tUCC (UCC)
         SELECT DISTINCT UCC.Uccno
         FROM   BI.V_LOTxLOCxID (NOLOCK) lli
         JOIN BI.V_LOTATTRIBUTE (NOLOCK) la ON (lli.Lot=la.Lot)  
         LEFT JOIN UCC (nolock) UCC ON lli.SKU = UCC.SKU AND lli.StorerKey = UCC.Storerkey and lli.loc =UCC.loc and lli.id=UCC.id 
         WHERE
            lli.StorerKey = @cStorerKey
            AND lli.Loc LIKE @cLOC
            AND lli.id  LIKE @cID
            AND lli.qty > 0 
            AND Ucc.Uccno IS NOT NULL 
         
         -- GET Count
         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount = 0
         BEGIN

            SET @nErrNo = 224802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- No Records
            GOTO Quit
         END
         
         -- Get counter
         SET @nPage = 1
         SET @nTotalPage = CEILING( @nRowCount / 6.0)

         SELECT @nTotalUCC =  Count(UCC) from @tUCC

         IF @cLOC = '%'
            BEGIN
               SET @c_oFieled01 = 'LOC : ' 
            END
         ELSE
            BEGIN
               SET @c_oFieled01 = 'LOC : '+ RTRIM( @cLabel_LOC)
            END
            
         IF @cID = '%'
            BEGIN
               SET @c_oFieled02 = 'TOTAL ID : '+ CAST(@nPLTTotal AS NVARCHAR( 5))  
            END
         ELSE
         BEGIN
            SET @c_oFieled02 = RTRIM( @cLabel_PLT) + ' ' + RTRIM( @cID)
         END

         SET @c_oFieled03 = RTRIM( @cLabel_UCC) + ' ' + CAST( @nTotalUCC AS NVARCHAR( 5))  -- CAST( @nPage AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
         SET @c_oFieled04 = RTRIM( @cLabel_UCCNo) 
         SET @c_oFieled05 = ''
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = ''
         SET @c_oFieled08 = ''
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = ''
  
         -- Populate case ID
         SET @i = 1
         SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UCC
            FROM @tUCC
            ORDER BY UCC
         OPEN @curUCC
         FETCH NEXT FROM @curUCC INTO @cUCC
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @c_oFieled05 = @cUCC ELSE
            IF @i = 2 SET @c_oFieled06 = @cUCC ELSE
            IF @i = 3 SET @c_oFieled07 = @cUCC ELSE
            IF @i = 4 SET @c_oFieled08 = @cUCC ELSE
            IF @i = 5 SET @c_oFieled09 = @cUCC ELSE
            IF @i = 6 SET @c_oFieled10 = @cUCC 
         
            SET @i = @i + 1
            IF @i > 6
               BREAK
         
            FETCH NEXT FROM @curUCC INTO @cUCC
         END

         CLOSE @curUCC
         DEALLOCATE @curUCC

         SET @nNextPage = 1  
      END

      IF @nStep  IN (3, 4) -- Inquiry sub module, result screen
      BEGIN
       
       -- Param mapping
         SET @cUCC = @c_oFieled10  -- Last case ID of page

         -- No next page
         IF @cUCC = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
         
         -- Get case ID info
         INSERT INTO @tUCC (UCC)
         SELECT DISTINCT UCC.Uccno
         FROM BI.V_LOTxLOCxID (NOLOCK) lli
         JOIN BI.V_LOTATTRIBUTE (NOLOCK) la ON (lli.Lot=la.Lot)  
         LEFT JOIN UCC (nolock) UCC ON lli.SKU = UCC.SKU AND lli.StorerKey = UCC.Storerkey and lli.loc =UCC.loc and lli.id=UCC.id 
         WHERE
            lli.StorerKey = @cStorerKey
            AND lli.Loc like @cLOC
            AND lli.id  like @cID
            AND lli.qty > 0 
            AND Ucc.Uccno is not null 

         SET @nRowCount = @@ROWCOUNT
      
         -- Get next record
         SET @nRowRef = 0
         SELECT TOP 1 
            @nRowRef = RowRef 
         FROM @tUCC 
         WHERE UCC > @cUCC 
         ORDER BY UCC
         
         -- No next record
         IF @nRowRef = 0
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
         -- Get counter
         SET @nTotalPage = CEILING( @nRowCount / 6.0)
         SET @nPage = CEILING( @nRowRef / 6.0)

         SELECT @nTotalUCC =  Count(UCC) from @tUCC

         IF @cLOC = '%'
            BEGIN
            SET @c_oFieled01 = 'LOC : '   
            END
         ELSE
            BEGIN
            SET @c_oFieled01 = 'LOC : '+ RTRIM( @cLabel_LOC)
            END
         
         IF @cID = '%'
            BEGIN
            SET @c_oFieled02 = 'TOTAL ID : '+ CAST(@nPLTTotal AS NVARCHAR( 5))  
            END
         ELSE
         BEGIN
            SET @c_oFieled02 = RTRIM( @cLabel_PLT) + ' ' + RTRIM( @cID)
         END
         SET @c_oFieled03 = RTRIM( @cLabel_UCC) + ' ' + CAST( @nTotalUCC AS NVARCHAR( 5))  -- CAST( @nPage AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
         SET @c_oFieled04 = RTRIM( @cLabel_UCCNo) 
         SET @c_oFieled05 = ''
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = ''
         SET @c_oFieled08 = ''
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = ''
       
         -- Populate case ID
         SET @i = 1
         SET @curUCC1 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UCC
            FROM @tUCC
            WHERE UCC > @cUCC
            ORDER BY UCC
         OPEN @curUCC1
         FETCH NEXT FROM @curUCC1 INTO @cUCC
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @c_oFieled05 = @cUCC ELSE
            IF @i = 2 SET @c_oFieled06 = @cUCC ELSE
            IF @i = 3 SET @c_oFieled07 = @cUCC ELSE
            IF @i = 4 SET @c_oFieled08 = @cUCC ELSE
            IF @i = 5 SET @c_oFieled09 = @cUCC ELSE
            IF @i = 6 SET @c_oFieled10 = @cUCC 
         
            SET @i = @i + 1
            
            IF @i > 6
               BREAK
            
            FETCH NEXT FROM @curUCC1 INTO @cUCC
         END

         CLOSE @curUCC1
         DEALLOCATE @curUCC1
         
         SET @nNextPage = 1 

      END
   END

Quit:

END

GO