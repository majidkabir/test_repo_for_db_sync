SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: isp515LblNoDecode01                                 */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date         Rev  Author      Purposes                               */  
/* 2021-04-07   1.0  Chermaine   WMS-16638 Created                      */  
/************************************************************************/  
CREATE PROCEDURE [dbo].[isp515LblNoDecode01]  
   @c_LabelNo          NVARCHAR(40),  
   @c_Storerkey        NVARCHAR(15),  
   @c_ReceiptKey       NVARCHAR(10),  
   @c_POKey            NVARCHAR(10),  
   @c_LangCode         NVARCHAR(3),  
   @c_oFieled01        NVARCHAR(20) OUTPUT,  
   @c_oFieled02        NVARCHAR(20) OUTPUT,  
   @c_oFieled03        NVARCHAR(20) OUTPUT,  
   @c_oFieled04        NVARCHAR(20) OUTPUT,  
   @c_oFieled05        NVARCHAR(20) OUTPUT,  
   @c_oFieled06        NVARCHAR(20) OUTPUT,  
   @c_oFieled07        NVARCHAR(20) OUTPUT,  
   @c_oFieled08        NVARCHAR(20) OUTPUT,  
   @c_oFieled09        NVARCHAR(20) OUTPUT,  
   @c_oFieled10        NVARCHAR(20) OUTPUT,  
   @b_Success          INT = 1      OUTPUT,  
   @n_ErrNo            INT          OUTPUT,   
   @c_ErrMsg           NVARCHAR(250) OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   -- Get session info
   DECLARE @nFunc INT
   DECLARE @nStep INT
   DECLARE @cLangCode NVARCHAR( 3)
   DECLARE @cUCC      NVARCHAR( 20)
   DECLARE @cFacility NVARCHAR( 5)
   DECLARE @cFromLOC  NVARCHAR( 10)
   
   
   SELECT 
      @nFunc = Func, 
      @nStep = Step, 
      @cLangCode = Lang_Code,
      @cFacility = Facility,
      @cFromLOC  = V_String1
   FROM rdt.rdtMobRec WITH (NOLOCK)
   WHERE UserName = SUSER_SNAME()

   IF @nFunc IN (515) -- MoveBySKU_lottable
   BEGIN
      IF @nStep = 3 -- SKU
      BEGIN
         DECLARE @nRowCount   INT
         DECLARE @cSKU        NVARCHAR(20) = ''
         DECLARE @cStatus     NVARCHAR(10)
         DECLARE @cLottable02 NVARCHAR(30)
         DECLARE @cSuggToLoc  NVARCHAR(10) 
         
         -- Get serial info
         SELECT 
            @cSKU = SKU, 
            @cStatus = STATUS,
            @cUCC = UCCNo,
            @cLottable02 = userdefine03
         FROM SerialNo WITH (NOLOCK)
         WHERE StorerKey = @c_StorerKey
            AND SerialNo = @c_LabelNo
            
         SET @nRowCount = @@ROWCOUNT 
         
         IF @nRowCount = 1
         BEGIN
            -- Check status
            IF @cStatus NOT IN ('1')
            BEGIN
               SET @n_ErrNo = 158151
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --InvalidStatus
               GOTO Quit
            END

            IF NOT EXISTS( SELECT 1 
               FROM SKU WITH (NOLOCK) 
               WHERE StorerKey = @c_Storerkey 
                  AND SKU = @cSKU 
                  AND SerialNoCapture IN ('1', '2'))-- 1=inbound and outbound, 2=inbound only
            BEGIN
               SET @n_ErrNo = 158152
               SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --SKU SNOCap Off
               GOTO Quit
            END
            
            --suggest loc
            SELECT TOP 1 @cSuggToLoc = Loc.Loc   
            FROM dbo.LotxLocxID LLI WITH (NOLOCK)   
            INNER JOIN  dbo.Loc Loc WITH (NOLOCK) ON Loc.Loc = LLI.Loc   
            JOIN dbo.LOTATTRIBUTE La WITH (NOLOCK) ON (LLI.SKU = La.SKU AND LLI.Lot = La.Lot AND LLI.storerKey = La.StorerKey)
            GROUP BY Loc.Loc, Loc.Facility, Loc.PutawayZone, SUBSTRING(LLI.SKU,1,9), Loc.LocLevel, La.Lottable02
            HAVING Loc.Facility = @cFacility  
            --AND Loc.PutawayZone = @cPutawayZone  
            AND SUBSTRING(LLI.SKU,1,9) = @cSKU  
            AND Loc.LocLevel = '1'
            AND La.Lottable02 = @cLottable02
            AND SUM(LLI.Qty) > 0   
            AND Loc.Loc <> @cFromLoc  
            ORDER BY SUM(LLI.Qty-LLI.QtyAllocated-LLI.QtyPicked), Loc.Loc  

            SET @c_oFieled01 = @cSKU         -- SKU
            SET @c_oFieled02 = @c_LabelNo    -- SerialNo
            SET @c_oFieled03 = @cSuggToLoc   -- SuggestLoc
            SET @c_oFieled05 = '1'           -- QTY
            SET @c_oFieled08 = @cLottable02  --lot02
         END
         
         -- Check not serial no
         ELSE IF @nRowCount = 0
         BEGIN
            SET @n_ErrNo = 158153
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --Not a SNO
            GOTO Quit
         END

         -- Check duplicate serialno
         ELSE
         BEGIN
            SET @n_ErrNo = 158154
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_ErrNo, @cLangCode, 'DSP') --Duplicate SNO
            GOTO Quit
         END
      END
   END

Quit:

END

GO