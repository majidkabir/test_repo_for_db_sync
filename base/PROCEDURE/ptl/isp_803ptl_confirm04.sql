SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: isp_803PTL_Confirm04                                */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Purpose: Accept QTY in CS-PCS, format 9-999                          */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 19-03-2021 1.0  YeeKung  WMS-16066 Created                           */
/* 29-12-2021 1.1  YeeKung  WMS-18600 change addwho as rdtuser          */
/************************************************************************/

CREATE PROC [PTL].[isp_803PTL_Confirm04] (
   @cIPAddress    NVARCHAR(30), 
   @cPosition     NVARCHAR(20),
   @cFuncKey      NVARCHAR(2), 
   @nSerialNo     INT,
   @cInputValue   NVARCHAR(20),
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR(125) OUTPUT,  
   @cDebug        NVARCHAR( 1) = ''
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLangCode      NVARCHAR( 3)
   DECLARE @cUserName      NVARCHAR( 18)
   DECLARE @nTranCount     INT
   DECLARE @bSuccess       INT
   DECLARE @nFunc          INT
   DECLARE @nQTY           INT
   DECLARE @nPTLKey        INT
   DECLARE @nQTY_PTL       INT
   DECLARE @nQTY_PD        INT
   DECLARE @nQTY_Bal       INT
   DECLARE @nExpectedQTY   INT
   DECLARE @nGroupKey      INT
   DECLARE @nCartonNo      INT
   DECLARE @cStation       NVARCHAR( 10)
   DECLARE @cCartonID      NVARCHAR( 20)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cType          NVARCHAR( 10)
   DECLARE @cWaveKey       NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cPickDetailKey NVARCHAR( 10)
   DECLARE @cLightMode     NVARCHAR( 4)
   DECLARE @cOrderLineNumber NVARCHAR( 5)

   DECLARE @curPTL CURSOR
   DECLARE @curPD  CURSOR
   DECLARE @cPOKey NVARCHAR(20)
   DECLARE @cReceiptkey nvarchar(20)
   DECLARE @cSKUUOM nVARCHAR(10)
   DECLARE @nMobile INT
   DECLARE @cFacility NVARCHAR(20)
   DECLARE @cLoc NVARCHAR(20)
   DECLARE @clottable06 NVARCHAR(20)

   SET @nFunc = 803 -- PTL piece (rdt.rdtfnc_PTLPiece)

   -- Get light info
   DECLARE @cStorerKey NVARCHAR(15),
           @cmethod   NVARCHAR(10)

   SELECT TOP 1 
      @cStation = PTL.station, 
      @cStorerKey = PTL.StorerKey,
      @csku=PTL.sku
   FROM rdt.rdtPTLPieceLog PTL WITH (NOLOCK) 
   JOIN deviceprofile DP on (PTL.station=DP.deviceid and ptl.position = dp.deviceposition and PTL.loc=dp.loc)
   WHERE PTL.IPAddress = @cIPAddress 
      AND PTL.position = @cPosition 
      AND PTL.UserDefine02<>''
      AND PTL.UserDefine01<>''
   ORDER BY ptl.EditDate 

   -- Find PickDetail to offset  
   SET @cOrderKey = ''  
   SELECT TOP 1   
     @cReceiptkey=L.BatchKey 
     ,@nQty=CAST(L.Userdefine02 AS INT)
     ,@cCartonID=L.cartonid
     ,@cUserName=L.UserDefine01
     ,@cLoc=L.LOC
     ,@cmethod='1'
   FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)   
      JOIN receipt R WITH (NOLOCK) ON (R.Receiptkey = L.BatchKey)  
   WHERE L.Station = @cStation  
      AND L.SKU = @cSKU  
   ORDER BY L.Position  

   IF @@ROWCOUNT =0
   BEGIN
      SELECT TOP 1   
        @cReceiptkey=r.ReceiptKey 
        ,@nQty=CAST(L.Userdefine02 AS INT)
        ,@cCartonID=L.cartonid
        ,@cUserName=L.UserDefine01
        ,@cLoc=L.LOC
        ,@cmethod='2'
      FROM rdt.rdtPTLPieceLog L WITH (NOLOCK)   
         JOIN receipt R WITH (NOLOCK) ON (R.UserDefine10 = L.BatchKey AND r.ReceiptKey=l.UserDefine03)  
      WHERE L.Station = @cStation  
         AND L.SKU = @cSKU  
         AND l.position = @cPosition 
         AND l.UserDefine01<>''
      ORDER BY L.Position  
      
   END

   SELECT @nMobile=mobile,
         @cFacility=facility,
         @cUserName=username
   from rdt.rdtmobrec (NOLOCK)
   where V_String1=@cStation

   SELECT @clottable06=ExternReceiptKey
   FROM receipt (NOLOCK) 
   WHERE ReceiptKey=@cReceiptkey

   SET @cSKUUOM= 'PCE'

   -- Get storer config
   SET @cLightMode = rdt.RDTGetConfig( @nFunc, 'LightMode', @cStorerKey)

   -- Receive            
   EXEC rdt.rdt_Receive_V7            
      @nFunc         = @nFunc,            
      @nMobile       = @nMobile,            
      @cLangCode     = @cLangCode,            
      @nErrNo        = @nErrNo OUTPUT,            
      @cErrMsg       = @cErrMsg OUTPUT,            
      @cStorerKey    = @cStorerKey,            
      @cFacility     = @cFacility,            
      @cReceiptKey   = @cReceiptKey,            
      @cPOKey        = @cPOKey,            
      @cToLOC        = @cLoc,            
      @cToID         = @cCartonID,            
      @cSKUCode      = @cSKU,            
      @cSKUUOM       = @cSKUUOM,            
      @nSKUQTY       = @nQty,            
      @cUCC          = '',            
      @cUCCSKU       = '',            
      @nUCCQTY       = '',            
      @cCreateUCC    = '',            
      @cLottable01   = '',            
      @cLottable02   = '',            
      @cLottable03   = '',            
      @dLottable04   = '',            
      @dLottable05   = NULL,            
      @cLottable06   = @clottable06,            
      @cLottable07   = '',            
      @cLottable08   = '',            
      @cLottable09   = '',            
      @cLottable10   = '',            
      @cLottable11   = '',            
      @cLottable12   = '',            
      @dLottable13   = '',            
      @dLottable14   = '',            
      @dLottable15   = '',            
      @nNOPOFlag     = '',            
      @cConditionCode = '',            
      @cSubreasonCode = ''

   IF @nErrNo <> 0
      GOTO Quit

   UPDATE dbo.RECEIPTDETAIL WITH (ROWLOCK)
   SET QtyExpected=BeforeReceivedQty,
         AddWho= CASE WHEN ISNULL(AddWho,'')='lightsysuser' THEN @cUserName ELSE AddWho END --(yeekung01)
   WHERE ReceiptKey=@cReceiptkey

   IF @cmethod='1'
   BEGIN
      UPDATE RDt.rdtPTLPieceLog WITH (ROWLOCK)
      set userdefine02='',
          UserDefine01=''
      WHERE sku=@cSKU
      AND BatchKey=@cReceiptkey
      AND loc=@cLoc

      IF @@ERROR<>''
      BEGIN
         SET @nErrNo = 165001 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
         GOTO QUIT
      END
   END
   ELSE
   BEGIN
      UPDATE RDt.rdtPTLPieceLog WITH (ROWLOCK)
      set userdefine02='',
          UserDefine01=''
      WHERE sku=@cSKU
      AND UserDefine03=@cReceiptkey
      AND loc=@cLoc

      IF @@ERROR<>''
      BEGIN
         SET @nErrNo = 165002
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail
         GOTO QUIT
      END
   END

   ---- Off all lights
   --EXEC PTL.isp_PTL_TerminateModule
   --      @cStorerKey
   --   ,@nFunc
   --   ,@cStation
   --   ,'STATION'
   --   ,@bSuccess    OUTPUT
   --   ,@nErrNo       OUTPUT
   --   ,@cErrMsg      OUTPUT
   --IF @nErrNo <> 0
   --   GOTO Quit


   GOTO Quit

   

Quit:

END

GO