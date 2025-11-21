SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_727Inquiry25                                       */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Modifications log:       LVSUSA                                         */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2024-10-08 1.0  JHU151     FCR-948                                      */
/***************************************************************************/
CREATE     PROC [RDT].[rdt_727Inquiry25] (
   @nMobile      INT,
   @nFunc        INT,
   @nStep        INT,
   @cLangCode    NVARCHAR(3),
   @cStorerKey   NVARCHAR(15),
   @cOption      NVARCHAR(1),
   @cParam1      NVARCHAR(60),
   @cParam2      NVARCHAR(60),
   @cParam3      NVARCHAR(60),
   @cParam4      NVARCHAR(60),
   @cParam5      NVARCHAR(60),
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

   SET @nErrNo = 0
   DECLARE @cID         NVARCHAR(18)
   DECLARE @cLoc        NVARCHAR(10)
   DECLARE @cStatus     NVARCHAR(10)
   DECLARE @cShipRef    NVARCHAR(30)
   DECLARE @cCarton     NVARCHAR(20)
   DECLARE @nCartonCnt  INT
   DECLARE @cPreviousCarton  NVARCHAR( 20)

   DECLARE @nRowRef        INT
   DECLARE @nRowCount      INT
   DECLARE @nPage          INT
   DECLARE @nTotalPage     INT
   DECLARE @nTotalCase     INT
   DECLARE @i              INT
   DECLARE @curCase         CURSOR
   DECLARE @curCase1        CURSOR
   DECLARE @tCase TABLE  
   (  
      RowRef      INT IDENTITY( 1, 1), 
      CaseID         NVARCHAR( 20)
   ) 

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module
      BEGIN

         -- Parameter mapping
         SET @cID = @cParam1

         -- Check blank
         IF @cID = ''
         BEGIN
            SET @nErrNo = 209201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need ID
            GOTO Quit
         END
                  
         SELECT TOP 1 
            @cLoc = ISNULL( PLTD.Loc, ''),
            @cStatus = PLT.Status,
            @cShipRef = ISNULL(PLTD.UserDefine01,'')
         FROM dbo.PALLET PLT WITH (NOLOCK)
            JOIN dbo.PALLETDETAIL PLTD WITH (NOLOCK) ON (PLT.PalletKey = PLTD.PalletKey AND PLT.storerkey = PLTD.Storerkey)
         WHERE PLTD.Storerkey = @cStorerkey
            AND PLT.PalletKey = @cID
            AND PLT.Status IN ( '0', '5','9') -- 0=Open, 5=Closed, 9=Shipped
         
         -- Get Case info
         INSERT INTO @tCase (CaseID)
         SELECT DISTINCT
            PLTD.CaseId
         FROM dbo.PALLET PLT WITH (NOLOCK)
            JOIN dbo.PALLETDETAIL PLTD WITH (NOLOCK) ON (PLT.PalletKey = PLTD.PalletKey AND PLT.storerkey = PLTD.Storerkey)
         WHERE PLTD.Storerkey = @cStorerkey
            AND PLT.PalletKey = @cID
            AND PLT.Status IN ( '0', '5','9') -- 0=Open, 5=Closed, 9=Shipped
                 
         
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
         IF @nRowCount <= 2
         BEGIN
            SET @nTotalPage = 1
         END
         ELSE
         BEGIN
            SET @nTotalPage = CEILING( (@nRowCount - 2) / 9.0) + 1
         END
         

         SELECT @nTotalCase =  Count(CaseID) from @tCase

         -- Set Header
         SET @c_oFieled01 = 'PalletKey:'
         SET @c_oFieled02 = @cID
         SET @c_oFieled03 = 'Loc: ' + @cLoc
         SET @c_oFieled04 = 'Status: ' + @cStatus
         SET @c_oFieled05 = 'ShipRef: ' + @cShipRef
         SET @c_oFieled06 = 'Case Count: ' + CAST(@nTotalCase AS NVARCHAR(5))
         SET @c_oFieled07 = 'Case:'

         SET @c_oFieled10 = CAST( @nPage AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
  
         -- Populate case ID
         SET @i = 1
         SET @curCase = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT CaseID
            FROM @tCase
            ORDER BY CaseID
         OPEN @curCase
         FETCH NEXT FROM @curCase INTO @cCarton
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @c_oFieled08 = @cCarton ELSE
            IF @i = 2 SET @c_oFieled09 = @cCarton
         
            SET @i = @i + 1
            IF @i > 2
               BREAK
         
            FETCH NEXT FROM @curCase INTO @cCarton
         END

         CLOSE @curCase
         DEALLOCATE @curCase

         SET @nNextPage = 1  

      END

      IF @nStep  IN (3, 4) -- Inquiry sub module, result screen
      BEGIN
       
       -- Param mapping
         SET @cCarton = @c_oFieled10  -- Last case ID of page

         -- No next page
         IF @cCarton = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
         
         -- Get Case info
         INSERT INTO @tCase (CaseID)
         SELECT DISTINCT
            PLTD.CaseId
         FROM dbo.PALLET PLT WITH (NOLOCK)
            JOIN dbo.PALLETDETAIL PLTD WITH (NOLOCK) ON (PLT.PalletKey = PLTD.PalletKey AND PLT.storerkey = PLTD.Storerkey)
         WHERE PLTD.Storerkey = @cStorerkey
            AND PLT.PalletKey = @cID
            AND PLT.Status IN ( '0', '5','9') -- 0=Open, 5=Closed, 9=Shipped

         SET @nRowCount = @@ROWCOUNT
      
         -- Get next record
         SET @nRowRef = 0
         SELECT TOP 1 
            @nRowRef = RowRef 
         FROM @tCase 
         WHERE CaseID > @cCarton 
         ORDER BY CaseID
         
         -- No next record
         IF @nRowRef = 0
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         End

         -- Get counter
         IF @nRowCount <= 2
         BEGIN
            SET @nTotalPage = 1
         END
         ELSE
         BEGIN
            SET @nTotalPage = CEILING( (@nRowCount - 2) / 9.0) + 1
         END
         SET @nPage = CEILING( (@nRowRef + 7) / 9.0)


         SET @c_oFieled10 = CAST( @nPage AS NVARCHAR( 5)) + '/' + CAST( @nTotalPage AS NVARCHAR( 5))
  
       
         -- Populate case ID
         SET @i = 1
         SET @curCase1 = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT CaseID
            FROM @tCase
            WHERE CaseID > @cCarton
            ORDER BY CaseID
         OPEN @curCase1
         FETCH NEXT FROM @curCase1 INTO @cCarton
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @i = 1 SET @c_oFieled01 = @cCarton ELSE
            IF @i = 2 SET @c_oFieled02 = @cCarton ELSE
            IF @i = 3 SET @c_oFieled03 = @cCarton ELSE
            IF @i = 4 SET @c_oFieled04 = @cCarton ELSE
            IF @i = 5 SET @c_oFieled05 = @cCarton ELSE
            IF @i = 6 SET @c_oFieled06 = @cCarton ELSE
            IF @i = 7 SET @c_oFieled07 = @cCarton ELSE
            IF @i = 8 SET @c_oFieled08 = @cCarton ELSE
            IF @i = 9 SET @c_oFieled09 = @cCarton 
         
            SET @i = @i + 1
            
            IF @i > 9
               BREAK
            
            FETCH NEXT FROM @curCase1 INTO @cCarton
         END

         CLOSE @curCase1
         DEALLOCATE @curCase1
         
         SET @nNextPage = 1 

      END
   END

Quit:

END

GO