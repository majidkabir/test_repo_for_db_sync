SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855DisQty01                                     */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Check if VAS is needed or not                               */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author   Purposes                                   */
/* 2024-06-13  1.0  NLT013   FCR-267. Created                           */
/************************************************************************/
  
CREATE   PROC [RDT].[rdt_855DisQty01] (  
   @nMobile      INT,   
   @nFunc        INT,   
   @cLangCode    NVARCHAR( 3),   
   @nStep        INT,   
   @nInputKey    INT,   
   @cStorerKey   NVARCHAR( 15),    
   @cRefNo       NVARCHAR( 10),   
   @cPickslipNo  NVARCHAR( 10),   
   @cLoadKey     NVARCHAR( 10),   
   @cOrderKey    NVARCHAR( 10),   
   @cDropID      NVARCHAR( 20),   
   @cSKU         NVARCHAR( 20),    
   @nQty         INT,    
   @cOption      NVARCHAR( 1),    
   @nErrNo       INT           OUTPUT,    
   @cErrMsg      NVARCHAR( 20) OUTPUT,   
   @cID          NVARCHAR( 18) = '',  
   @cTaskDetailKey   NVARCHAR( 10) = '',  
   @cReasonCode  NVARCHAR(20) OUTPUT,
   @cDisableQTYField NVARCHAR(1) OUTPUT

) AS  
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF @nFunc = 855   -- Function ID
   BEGIN
      IF @nStep = 1  -- Drop ID
      BEGIN
         IF @nInputKey = 1  -- Enter
         BEGIN
            DECLARE @cFullAudit NVARCHAR(3)
            SELECT TOP 1 @cFullAudit = ISNULL(clk.UDF05, '') FROM dbo.WorkOrder wo WITH(NOLOCK)
            INNER JOIN dbo.WorkOrderDetail wod WITH(NOLOCK) ON wo.WorkOrderKey = wod.WorkOrderKey
            INNER JOIN dbo.PickDetail pkd WITH(NOLOCK) ON wod.StorerKey = pkd.StorerKey AND wod.ExternWorkOrderKey = pkd.OrderKey AND wod.ExternLineNo = pkd.OrderLinenumber
            INNER JOIN dbo.CODELKUP clk WITH(NOLOCK) ON wod.type = clk.Code
            WHERE pkd.StorerKey = @cStorerKey
               AND pkd.CaseID = @cDropID
               AND clk.LISTNAME = 'WKORDTYPE'
               AND (pkd.SKU = ISNULL(wod.WkOrdUdef1, '') OR ISNULL(wod.WkOrdUdef1, '') = '')

            IF ISNULL(@cFullAudit, '') = '100'
               SET @cDisableQTYField = '1'
            ELSE
               SET @cDisableQTYField = '0'
         END
      END
   END

Quit:
END  


GO