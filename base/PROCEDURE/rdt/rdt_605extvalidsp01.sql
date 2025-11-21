SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_605ExtValidSP01                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2022-01-21  1.0  YeeKung     WMS-18676 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_605ExtValidSP01] (
   @nMobile      INT,          
   @nFunc        INT,          
   @cLangCode    NVARCHAR( 3), 
   @nStep        INT,          
   @nInputKey    INT,          
   @cFacility    NVARCHAR( 5), 
   @cStorerKey   NVARCHAR( 15),
   @cReceiptKey  NVARCHAR( 10),
   @cRefNo       NVARCHAR( 20),
   @cID          NVARCHAR( 18),
   @nErrNo             INT            OUTPUT,
   @cErrMsg            NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTotalID INT,
           @nQTY     INT,
           @nSafeQty INT,
           @cSKU     NVARCHAR(20),
			  @cRDLineNo NVARCHAR(20)

	IF @nStep IN(2)
	BEGIN

		SELECT @cSKU=V_SKU,
				 @cRDLineNo = V_String9
		from rdt.rdtmobrec (nolock)
		where mobile=@nMobile

      SET @cSKU=''

		-- Get 1st line  
		IF @cSKU = ''  
			SELECT TOP 1   
				@cSKU = SKU,   
				@nQTY = QTYExpected
			FROM dbo.ReceiptDetail WITH (NOLOCK)   
			WHERE ReceiptKey = @cReceiptKey  
				AND ToID = @cID  
				AND BeforeReceivedQTY = 0  
			ORDER BY SKU, ReceiptLineNumber   
		ELSE  
		BEGIN  
			-- Get same SKU, next line  
			SELECT TOP 1   
				@cSKU = SKU,   
				@nQTY = QTYExpected 
			FROM dbo.ReceiptDetail WITH (NOLOCK)   
			WHERE ReceiptKey = @cReceiptKey  
				AND ToID = @cID  
				AND SKU = @cSKU  
				AND BeforeReceivedQTY = 0  
				AND ReceiptLineNumber > @cRDLineNo  
			ORDER BY ReceiptLineNumber   
  
			-- Get next SKU  
			IF @@ROWCOUNT = 0  
				SELECT TOP 1   
					@cSKU = SKU,   
					@nQTY = QTYExpected,   
					@cRDLineNo = ReceiptLineNumber   
				FROM dbo.ReceiptDetail WITH (NOLOCK)   
				WHERE ReceiptKey = @cReceiptKey  
					AND ToID = @cID  
					AND SKU > @cSKU  
					AND BeforeReceivedQTY = 0  
				ORDER BY SKU, ReceiptLineNumber   
		END  

		SELECT @nQTY=sum(qty)
		from lotxlocxid LLI(nolock)
		JOIN loc l ON LLI.loc=l.loc
		where sku=@cSKU
			--AND QtyExpected >0
			AND (l.LocationType='pick' OR l.loc =	case when @cFacility='BJE01' then 'BJE-STG'
																	  when @cFacility='GIK01' then 'IKEA-NSTG'
																     when @cFacility='KSE01' then 'IK-STG' END)
	   and l.Facility=@cFacility

		SELECT @nSafeQty= short
		FROM codelkup (NOLOCK) 
		WHERE listname='IKEAFPSKU'
		AND Storerkey =@cStorerKey
		AND code =@csku
		AND code2 IN('',@cFacility)

		IF (@nQTY<=@nSafeQty) and ISNULL(@nSafeQty,'') not in(0,'')
		BEGIN
			SET @nErrNo = 180851 
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ExceedQTY    
			SET @nErrNo=0
			GOTO quit 
		END
	END
END
Quit:    

GO