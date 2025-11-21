SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry12                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-01-28 1.0  Ung        WMS-18845 Created                            */
/***************************************************************************/

CREATE PROC [RDT].[rdt_727Inquiry12] (
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
      ID          NVARCHAR( 18),
      UCCNo       NVARCHAR( 20),  
      SKU         NVARCHAR( 20),  
      QTY         INT
   )  
   
   DECLARE @cLabel_PalletID NVARCHAR( 20)
   DECLARE @cLabel_UCC      NVARCHAR( 20)
   DECLARE @cLabel_SKU      NVARCHAR( 20)
   DECLARE @cLabel_QTY      NVARCHAR( 20)

   DECLARE @cFacility   NVARCHAR( 5)
   DECLARE @cUCCNo      NVARCHAR( 20)
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cDescr      NVARCHAR( 60)
   DECLARE @nQTY        INT
   DECLARE @cCounter    NVARCHAR( 10)
   DECLARE @nRowCount   INT
   DECLARE @nRowRef     INT

   SET @nErrNo = 0

   -- Get session info
   SELECT @cFacility = Facility FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module, input screen
      BEGIN
         -- Parameter mapping
         SET @cUCCNo = @cParam1

         -- Check blank
         IF @cUCCNo = '' 
         BEGIN
            SET @nErrNo = 181601
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need UCC
            GOTO QUIT
         END
  
         -- Get UCC info
         INSERT INTO @tUCC (ID, UCCNo, SKU, QTY)
         SELECT ID, UCCNo, SKU, SUM( QTY) 
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND UCCNo = @cUCCNo
            AND Status <> '9'
         GROUP BY ID, UCCNo, SKU

         -- Check UCC
         SET @nRowCount = @@ROWCOUNT
         IF @nRowCount = 0
         BEGIN
            SET @nErrNo = 181602
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid UCC
            GOTO QUIT
         END
               
         -- Get 1st record
         SELECT TOP 1 
            @nRowRef = RowRef, 
            @cID = ID, 
            @cSKU = SKU, 
            @nQTY = QTY
         FROM @tUCC
         ORDER BY ID, SKU
         
         -- Get SKU info
         SELECT @cDescr = Descr 
         FROM dbo.SKU WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND SKU = @cSKU
         
         -- Get counter
         SET @cCounter = CAST( @nRowRef AS NVARCHAR(3)) + '/' + CAST( @nRowCount AS NVARCHAR(3))
         SET @cCounter = rdt.rdtRightAlign( @cCounter, 10)        

         -- Get label
         SET @cLabel_PalletID = rdt.rdtgetmessage( 181603, @cLangCode, 'DSP') --PALLET ID:
         SET @cLabel_UCC      = rdt.rdtgetmessage( 181604, @cLangCode, 'DSP') --UCC NO:
         SET @cLabel_SKU      = rdt.rdtgetmessage( 181605, @cLangCode, 'DSP') --SKU:
         SET @cLabel_QTY      = rdt.rdtgetmessage( 181606, @cLangCode, 'DSP') --QTY:
         
         SET @c_oFieled01 = @cLabel_PalletID --PALLET ID: 
         SET @c_oFieled02 = @cID
         SET @c_oFieled03 = ''
         SET @c_oFieled04 = @cLabel_UCC --UCC NO: 
         SET @c_oFieled05 = @cUCCNo
         SET @c_oFieled06 = ''
         SET @c_oFieled07 = LEFT( @cLabel_SKU, 10) + @cCounter --SKU:
         SET @c_oFieled08 = @cSKU
         SET @c_oFieled09 = ''
         SET @c_oFieled10 = RTRIM( @cLabel_QTY) + ' ' + CAST( @nQTY AS NVARCHAR( 5)) --QTY:
         -- SET @c_oFieled09 = rdt.rdtFormatString( @cDescr, 1, 20)
         -- SET @c_oFieled10 = rdt.rdtFormatString( @cDescr, 21, 20)
         -- SET @c_oFieled11 = '' --reserved
         
      	SET @nNextPage = 1  
      END
   
      IF @nStep IN (3, 4) -- Inquiry sub module, result screen
      BEGIN
         -- Param mapping
         SET @cUCCNo = @cParam1
         SET @cSKU = @c_oFieled08  -- SKU
         
         -- Get UCC info
         INSERT INTO @tUCC (ID, UCCNo, SKU, QTY)
         SELECT ID, UCCNo, SKU, SUM( QTY) 
         FROM rdt.rdtPreReceiveSort WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
            AND Facility = @cFacility
            AND UCCNo = @cUCCNo
            AND Status <> '9'
         GROUP BY ID, UCCNo, SKU

         SET @nRowCount = @@ROWCOUNT

         -- Get next record
         SELECT TOP 1 
            @nRowRef = RowRef, 
            @cID = ID, 
            @cSKU = SKU, 
            @nQTY = QTY
         FROM @tUCC
         WHERE SKU > @cSKU
         ORDER BY ID, SKU
         
         -- Next record
         IF @@ROWCOUNT = 0
            SET @nErrNo = -1
         ELSE
         BEGIN
            -- Get SKU info
            SELECT @cDescr = Descr 
            FROM dbo.SKU WITH (NOLOCK) 
            WHERE StorerKey = @cStorerKey
               AND SKU = @cSKU
         
            -- Get counter
            SET @cCounter = CAST( @nRowRef AS NVARCHAR(3)) + '/' + CAST( @nRowCount AS NVARCHAR(3))
            SET @cCounter = rdt.rdtRightAlign( @cCounter, 10)        

            -- Get label
            SET @cLabel_PalletID = rdt.rdtgetmessage( 181603, @cLangCode, 'DSP') --PALLET ID:
            SET @cLabel_UCC      = rdt.rdtgetmessage( 181604, @cLangCode, 'DSP') --UCC NO:
            SET @cLabel_SKU      = rdt.rdtgetmessage( 181605, @cLangCode, 'DSP') --SKU:
            SET @cLabel_QTY      = rdt.rdtgetmessage( 181606, @cLangCode, 'DSP') --QTY:
            
            SET @c_oFieled01 = @cLabel_PalletID --PALLET ID: 
            SET @c_oFieled02 = @cID
            SET @c_oFieled03 = ''
            SET @c_oFieled04 = @cLabel_UCC --UCC NO: 
            SET @c_oFieled05 = @cUCCNo
            SET @c_oFieled06 = ''
            SET @c_oFieled07 = LEFT( @cLabel_SKU, 10) + @cCounter --SKU:
            SET @c_oFieled08 = @cSKU
            SET @c_oFieled09 = ''
            SET @c_oFieled10 = RTRIM( @cLabel_QTY) + ' ' + CAST( @nQTY AS NVARCHAR( 5)) --QTY:
            -- SET @c_oFieled09 = rdt.rdtFormatString( @cDescr, 1, 20)
            -- SET @c_oFieled10 = rdt.rdtFormatString( @cDescr, 21, 20)
            -- SET @c_oFieled11 = '' --reserved
            
            SET @nNextPage = 1 
         END
      END
   END

Quit:

END

GO