SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_PTLPiece_Confirm_ASN                            */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Purpose: Confirm by order                                            */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 01-03-2021 1.0  YeeKung     WMS-16066 Created                        */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_PTLPiece_Confirm_ASN] (  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR( 3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR( 5)  
   ,@cStorerKey   NVARCHAR( 15)  
   ,@cLight       NVARCHAR( 1)  
   ,@cStation     NVARCHAR( 10)  
   ,@cMethod      NVARCHAR( 1)   
   ,@cSKU         NVARCHAR( 20)  
   ,@cIPAddress   NVARCHAR( 40) OUTPUT  
   ,@cPosition    NVARCHAR( 10) OUTPUT  
   ,@nErrNo       INT           OUTPUT  
   ,@cErrMsg      NVARCHAR(250) OUTPUT  
   ,@cResult01    NVARCHAR( 20) OUTPUT  
   ,@cResult02    NVARCHAR( 20) OUTPUT  
   ,@cResult03    NVARCHAR( 20) OUTPUT  
   ,@cResult04    NVARCHAR( 20) OUTPUT  
   ,@cResult05    NVARCHAR( 20) OUTPUT  
   ,@cResult06    NVARCHAR( 20) OUTPUT  
   ,@cResult07    NVARCHAR( 20) OUTPUT  
   ,@cResult08    NVARCHAR( 20) OUTPUT  
   ,@cResult09    NVARCHAR( 20) OUTPUT  
   ,@cResult10    NVARCHAR( 20) OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @bSuccess          INT  
   DECLARE @nTranCount        INT  
   DECLARE @nQTY           INT  
  
   DECLARE @cCartonID         NVARCHAR( 20)  
   DECLARE @cOrderKey         NVARCHAR( 10)  
   DECLARE @cPickDetailKey    NVARCHAR( 10)  
   DECLARE @cDisplay          NVARCHAR( 5)  
   DECLARE @cUpdateDropID     NVARCHAR( 1)  
   DECLARE @cPrintLabelSP     NVARCHAR( 20)  -- (cc01)  
   DECLARE @cReceiptkey       NVARCHAR( 20)
   DECLARE @cSKUUOM           NVARCHAR(5)
   DECLARE @cPOKey            NVARCHAR(20)
   DECLARE @cLoc              NVARCHAR(20)
     
   -- Handling transaction  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_PTLPiece_Confirm -- For rollback or commit only our own transaction  

   SELECT @cSKUUOM=V_UOM
   from rdt.rdtmobrec (NOLOCK)
   where mobile=@nMobile

   SET @cSKUUOM= 'PCE'

   -- Find PickDetail to offset  
   SET @cOrderKey = ''  
   SELECT TOP 1   
     @cReceiptkey=L.BatchKey 
     ,@cPOKey=RD.POKEY
     ,@nQty=RD.Beforereceivedqty
   FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)   
      JOIN receipt R WITH (NOLOCK) ON (R.Receiptkey = L.BatchKey)  
      JOIN receiptdetail RD WITH (NOLOCK) ON (RD.receiptkey = R.receiptkey)  
   WHERE L.Station = @cStation  
      AND RD.SKU = @cSKU 
   ORDER BY L.Position  

   IF @@ROWCOUNT=0
   BEGIN
       SELECT TOP 1   
        @cReceiptkey=L.BatchKey 
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)   
         JOIN receipt R WITH (NOLOCK) ON (R.Receiptkey = L.BatchKey)  
      WHERE L.Station = @cStation    
      ORDER BY L.Position  

      SET @nQty=1
   END

   SELECT @cLoc=loc,@cPosition=Position
   from rdt.rdtPTLPieceLog (NOLOCK)
   where sku=@csku
   and Station = @cStation 

   IF ISNULL(@cLoc,'')=''
   BEGIN
      SELECT TOP 1 @cLoc=PTL.loc
                  ,@cPosition=Position
      FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK)
      JOIN deviceprofile DP on (PTL.station=DP.deviceid  AND ptl.loc=dp.loc AND ptl.IPAddress=dp.IPAddress )
      WHERE Station = @cStation
      and sku=''
      order by DP.logicalPos

      UPDATE rdt.rdtPTLPieceLog With (rowlock)
      set sku=@csku
      ,UserDefine01='Batch1'
      where loc=@cloc
      and position=@cPosition
      and Station = @cStation 

      IF @@ERROR<>''
      BEGIN
         SET @nErrNo = 164851
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
         GOTO RollBackTran
      END
   END
  
   IF EXISTS (SELECT 1 from rdt.rdtPTLPieceLog (NOLOCK) where Station = @cStation and ISNULL(userdefine02,'')<>'' and loc<>@cLoc)
   BEGIN
      
      declare @cPreposition nvarchar(20),
              @cPreLoc NVARCHAR(20)


      SELECT @cPreposition=position,
             @cPreLoc=loc,
             @nQTY=CAST(userdefine02 AS INT)
      from rdt.rdtPTLPieceLog (NOLOCK) 
      where Station = @cStation 
      and ISNULL(userdefine02,'')<>'' 
      and loc<>@cLoc

      DECLARE @cLogicalName NVARCHAR(10)  
      SELECT @cLogicalName = LogicalName  ,
             @cIPAddress=IPAddress
      FROM DeviceProfile WITH (NOLOCK)  
      WHERE DeviceType = 'STATION'  
      AND DeviceID = @cStation  
      AND DevicePosition = @cPreposition  
      and loc=@cPreLoc

      set @cDisplay=SUBSTRING(@cLogicalName,1,2)+ CAST (@nQty AS NVARCHAR(2))
   
      -- EventLog  
      EXEC RDT.rdt_STD_EventLog  
        @cActionType = '3',   
        @nMobileNo   = @nMobile,  
        @nFunctionID = @nFunc,  
        @cFacility   = @cFacility,  
        @cStorerKey  = @cStorerkey,  
        @cReceiptkey = @cReceiptkey,  
        @cDropID     = @cPosition,   
        @cSKU        = @cSKU,  
        @cDeviceID   = @cStation,  
        @nQty        = @nQty     

      -- Draw matrix (and light up)  
      EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey  
         ,@cLight  
         ,@cStation  
         ,@cMethod  
         ,@cSKU  
         ,@cIPAddress   
         ,@cPreposition  
         ,@cDisplay  
         ,@nErrNo     OUTPUT  
         ,@cErrMsg    OUTPUT  
         ,@cResult01  OUTPUT  
         ,@cResult02  OUTPUT  
         ,@cResult03  OUTPUT  
         ,@cResult04  OUTPUT     
         ,@cResult05  OUTPUT  
         ,@cResult06  OUTPUT  
         ,@cResult07  OUTPUT  
         ,@cResult08  OUTPUT  
         ,@cResult09  OUTPUT  
         ,@cResult10  OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
   END
   ELSE
   BEGIN
       UPDATE rdt.rdtPTLPieceLog With (rowlock)
      set userdefine02= CAST(userdefine02 as int) +1
      where loc=@cloc
       and BatchKey=@cReceiptkey

      IF @@ERROR<>''
      BEGIN
         SET @nErrNo = 164852
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
         GOTO RollBackTran
      END

      IF NOT EXISTS (SELECT 1 FROM rdt.rdtPTLPieceLog (NOLOCK) 
                     WHERE loc=@cloc
                     AND userdefine03=@cReceiptkey
                     AND station=@cStation
                     AND position=@cPosition
                     AND UserDefine01<>''
                     )
      BEGIN
         UPDATE rdt.rdtPTLPieceLog With (rowlock)
         set UserDefine01='Batch1'
         where loc=@cloc
         and BatchKey=@cReceiptkey
         AND Position=@cPosition
         AND Station=@cStation
      END

      SET @cLight=0

       -- Draw matrix (and light up)  
      EXEC rdt.rdt_PTLPiece_Matrix @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey  
         ,@cLight  
         ,@cStation  
         ,@cMethod  
         ,@cSKU  
         ,@cIPAddress   
         ,@cPreposition  
         ,@cDisplay  
         ,@nErrNo     OUTPUT  
         ,@cErrMsg    OUTPUT  
         ,@cResult01  OUTPUT  
         ,@cResult02  OUTPUT  
         ,@cResult03  OUTPUT  
         ,@cResult04  OUTPUT  
         ,@cResult05  OUTPUT  
         ,@cResult06  OUTPUT  
         ,@cResult07  OUTPUT  
         ,@cResult08  OUTPUT  
         ,@cResult09  OUTPUT  
         ,@cResult10  OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
   END
  
   COMMIT TRAN rdt_PTLPiece_Confirm  
   GOTO Quit  
END
     
RollBackTran:  
   ROLLBACK TRAN rdt_PTLPiece_Confirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  


GO