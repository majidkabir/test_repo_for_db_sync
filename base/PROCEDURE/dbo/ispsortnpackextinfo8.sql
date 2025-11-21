SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: ispSortNPackExtInfo8                                */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author   Purposes                                   */  
/* 2020-May-31 1.0  Ung      WMS-13538 Created                          */  
/* 2020-Jul-14 1.1  Ung      WMS-14197 Change to permanent table        */
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispSortNPackExtInfo8]  
   @cLoadKey         NVARCHAR(10),  
   @cOrderKey        NVARCHAR(10),  
   @cConsigneeKey    NVARCHAR(15),  
   @cLabelNo         NVARCHAR(20) OUTPUT,  
   @cStorerKey       NVARCHAR(15),  
   @cSKU             NVARCHAR(20),  
   @nQTY             INT,   
   @cExtendedInfo    NVARCHAR(20) OUTPUT,  
   @cExtendedInfo2   NVARCHAR(20) OUTPUT,
   @cLangCode        NVARCHAR(3),           
   @bSuccess         INT          OUTPUT,   
   @nErrNo           INT          OUTPUT,   
   @cErrMsg          NVARCHAR(20) OUTPUT,   
   @nMobile          INT                    
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @nStep     INT
   DECLARE @nInputKey INT

   -- Get session info
   SELECT 
      @nStep = Step, 
      @nInputKey = InputKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 2 OR -- SKU, UCC
      @nStep = 3 OR -- LabelNo
      @nStep = 4    -- SKU, QTY
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cPosition NVARCHAR( 10) = ''

         -- Get consignee position
         SELECT @cPosition = SortLOC
         FROM rdt.rdtSortAndPackLOC WITH (NOLOCK)
         WHERE LoadKey = @cLoadKey
            AND ConsigneeKey = @cConsigneeKey
            AND StorerKey = @cStorerKey

         SET @cExtendedInfo = 'POS: ' + @cPosition
      END
   END

QUIT:  
END -- End Procedure  

GO