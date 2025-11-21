SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_PTL_OrderPicking_GenAlert                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Generate Alert when Short Pick                              */
/*                                                                      */
/* Called from: rdtfnc_PTL_OrderPicking                                 */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 28-Feb-2013 1.0  ChewKP      Created                                 */
/************************************************************************/

CREATE PROC [RDT].[rdt_PTL_OrderPicking_GenAlert] (
     @nMobile          INT
    ,@nFunc            INT
    ,@cFacility        NVARCHAR(5)
    ,@cStorerKey       NVARCHAR( 15)  
    ,@cCartID          NVARCHAR( 10)  
    ,@cUserName        NVARCHAR( 18)  
    ,@cLangCode        NVARCHAR( 3)
    ,@nErrNo           INT          OUTPUT
    ,@cErrMsg          NVARCHAR(20) OUTPUT -- screen limitation, 20 char max
    ,@cSKU             NVARCHAR(20) 
    ,@cLoc             NVARCHAR(10) 
    ,@cLot             NVARCHAR(10) 
    ,@cReasonCode      NVARCHAR(10)
    
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   Declare @b_success             INT
   DECLARE @c_NewLineChar CHAR(2)     
           , @cOrderKey       NVARCHAR(10)
           , @cDropID         NVARCHAR(20)
           , @nExpectedQty    INT
           , @nQty            INT
           , @c_AlertMessage  NVARCHAR( 255)
           , @nPTLTranKey     INT
           
   
   SET @c_NewLineChar =  CHAR(13) + CHAR(10)
   
   DECLARE CursorPTLTranAlert CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
       
   SELECT OrderKey, SKU, Loc, Lot, DropID, ExpectedQTy, Qty, PTLKey
   FROM dbo.PTLTran WITH (NOLOCK)
   WHERE DeviceID = @cCartID
   AND Status     IN ('5','9')
   AND SKU        = @cSKU
   AND Loc        = @cLoc
   AND Lot        = @cLot
   AND StorerKey  = @cStorerKey
   ORDER BY OrderKey
   
   OPEN CursorPTLTranAlert            
   
   FETCH NEXT FROM CursorPTLTranAlert INTO @cOrderKey, @cSKU, @cLoc, @cLot, @cDropID, @nExpectedQty, @nQty, @nPTLTranKey
   
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      
      SET @c_AlertMessage = ''
      
       
      -- Log ReasonCode into Alert table
      IF @nExpectedQty <> @nQty 
      BEGIN
         
         UPDATE dbo.PTLTran
         SET Remarks = @cReasonCode
         WHERE PTLKey = @nPTLTranKey
      
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' DeviceID: ' + @cCartID  +  @c_NewLineChar   
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ReasonCode: ' + @cReasonCode + @c_NewLineChar 
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' OrderKey: ' + @cOrderKey + @c_NewLineChar  
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Location: ' + @cLoc + @c_NewLineChar  
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' SKU: ' + @cSKU + @c_NewLineChar  
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Lot: ' + @cLot + @c_NewLineChar  
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' ExpectedQty: ' + CAST(@nExpectedQty AS NVARCHAR(5)) + @c_NewLineChar  
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' Qty: ' + CAST(@nQty AS NVARCHAR(5)) + @c_NewLineChar  
         SET @c_AlertMessage = RTRIM(@c_AlertMessage) + ' UserKey: ' + @cUserName + @c_NewLineChar  
            
         EXEC nspLogAlert
                 @c_modulename       = 'PTL_OrderPick'     
               , @c_AlertMessage     = @c_AlertMessage   
               , @n_Severity         = '5'       
               , @b_success          = @b_success     OUTPUT       
               , @n_err              = @nErrNo        OUTPUT         
               , @c_errmsg           = @cErrMsg       OUTPUT      
               , @c_Activity	       = 'ReasonScn'
               , @c_Storerkey	       = @cStorerKey	   
               , @c_SKU	             = @cSKU
               , @c_UOM	             = ''	         
               , @c_UOMQty	          = ''	      
               , @c_Qty	             = ''
               , @c_Lot	             = ''         
               , @c_Loc	             = @cLoc
               , @c_ID	             = ''
               , @c_TaskDetailKey	 = ''
               , @c_UCCNo	          = ''
               
         IF @nErrNo <> 0
         BEGIN
             SET @cErrMsg = rdt.rdtgetmessage(@nErrNo ,@cLangCode ,'DSP') 
             GOTO Quit  
         END   
      END
            
      FETCH NEXT FROM CursorPTLTranAlert INTO @cOrderKey, @cSKU, @cLoc, @cLot, @cDropID, @nExpectedQty, @nQty, @nPTLTranKey
      
   END
   CLOSE CursorPTLTranAlert            
   DEALLOCATE CursorPTLTranAlert 
   
   
   
   
   
Quit:
END

GO