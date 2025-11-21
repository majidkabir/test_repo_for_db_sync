SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/      
/* Store procedure: rdt_803PTLAssign02                                        */      
/* Copyright      : Maersk                                                    */      
/*                     Ace Turtle                                             */      
/* Date       Rev  Author   Purposes                                          */      
/* 2022-11-01 1.0  JHU151    FCR-650 Created                                  */
/******************************************************************************/      
      
CREATE   PROC [RDT].[rdt_803PTLAssign02] (      
   @nMobile          INT,       
   @nFunc            INT,       
   @cLangCode        NVARCHAR( 3),       
   @nStep            INT,       
   @nInputKey        INT,       
   @cFacility        NVARCHAR( 5),       
   @cStorerKey       NVARCHAR( 15),        
   @cStation         NVARCHAR( 10),        
   @cMethod          NVARCHAR( 1),      
   @cType            NVARCHAR( 15), --POPULATE-IN/POPULATE-OUT/CHECK      
   @cInField01       NVARCHAR( 60) OUTPUT,  @cOutField01 NVARCHAR( 60) OUTPUT,  @cFieldAttr01 NVARCHAR( 1) OUTPUT,         
   @cInField02       NVARCHAR( 60) OUTPUT,  @cOutField02 NVARCHAR( 60) OUTPUT,  @cFieldAttr02 NVARCHAR( 1) OUTPUT,         
   @cInField03       NVARCHAR( 60) OUTPUT,  @cOutField03 NVARCHAR( 60) OUTPUT,  @cFieldAttr03 NVARCHAR( 1) OUTPUT,         
   @cInField04       NVARCHAR( 60) OUTPUT,  @cOutField04 NVARCHAR( 60) OUTPUT,  @cFieldAttr04 NVARCHAR( 1) OUTPUT,         
   @cInField05       NVARCHAR( 60) OUTPUT,  @cOutField05 NVARCHAR( 60) OUTPUT,  @cFieldAttr05 NVARCHAR( 1) OUTPUT,         
   @cInField06       NVARCHAR( 60) OUTPUT,  @cOutField06 NVARCHAR( 60) OUTPUT,  @cFieldAttr06 NVARCHAR( 1) OUTPUT,        
   @cInField07       NVARCHAR( 60) OUTPUT,  @cOutField07 NVARCHAR( 60) OUTPUT,  @cFieldAttr07 NVARCHAR( 1) OUTPUT,        
   @cInField08       NVARCHAR( 60) OUTPUT,  @cOutField08 NVARCHAR( 60) OUTPUT,  @cFieldAttr08 NVARCHAR( 1) OUTPUT,        
   @cInField09       NVARCHAR( 60) OUTPUT,  @cOutField09 NVARCHAR( 60) OUTPUT,  @cFieldAttr09 NVARCHAR( 1) OUTPUT,        
   @cInField10       NVARCHAR( 60) OUTPUT,  @cOutField10 NVARCHAR( 60) OUTPUT,  @cFieldAttr10 NVARCHAR( 1) OUTPUT,        
   @cInField11       NVARCHAR( 60) OUTPUT,  @cOutField11 NVARCHAR( 60) OUTPUT,  @cFieldAttr11 NVARCHAR( 1) OUTPUT,       
   @cInField12       NVARCHAR( 60) OUTPUT,  @cOutField12 NVARCHAR( 60) OUTPUT,  @cFieldAttr12 NVARCHAR( 1) OUTPUT,       
   @cInField13       NVARCHAR( 60) OUTPUT,  @cOutField13 NVARCHAR( 60) OUTPUT,  @cFieldAttr13 NVARCHAR( 1) OUTPUT,       
   @cInField14       NVARCHAR( 60) OUTPUT,  @cOutField14 NVARCHAR( 60) OUTPUT,  @cFieldAttr14 NVARCHAR( 1) OUTPUT,       
   @cInField15       NVARCHAR( 60) OUTPUT,  @cOutField15 NVARCHAR( 60) OUTPUT,  @cFieldAttr15 NVARCHAR( 1) OUTPUT,       
   @nScn             INT           OUTPUT,      
   @nErrNo           INT           OUTPUT,       
   @cErrMsg          NVARCHAR( 20) OUTPUT      
)      
AS      
BEGIN      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
   
   DECLARE @cUserDefine09 NVARCHAR(30)
   DECLARE @cUserDefine02 NVARCHAR(30)
   DECLARE @cLOC         NVARCHAR(10)
   DECLARE @cFromLOC     NVARCHAR(10)
   DECLARE @cPalletID    NVARCHAR(20)
   DECLARE @cTempPalletID    NVARCHAR(20)
   --DECLARE @cDropID      NVARCHAR(20)      
   DECLARE @nTotalDropID INT      
   DECLARE @cIPAddress   NVARCHAR(40)
   DECLARE @cPosition    NVARCHAR(10)
   DECLARE @cReceiptKey   NVARCHAR(10)
   DECLARE @cSKU         NVARCHAR( 20)    
   DECLARE @cChkStation  NVARCHAR( 10)    
   DECLARE @cWaveKey     NVARCHAR( 10)    
   DECLARE @cWaveKey2cHK NVARCHAR( 10)    
   DECLARE @nRowCOUNT    INT
   DECLARE @cPrefix      NVARCHAR( 10)
   DECLARE @nPosStart    INT
   DECLARE @nPosLength   INT
   DECLARE @nRowRef      INT
   DECLARE @nQTY         INT
      
   /***********************************************************************************************      
                                                POPULATE      
   ***********************************************************************************************/      
   IF @cType = 'POPULATE-IN'      
   BEGIN

      -- Prepare next screen var      
      SET @cOutField01 = ''
            
      -- Go to batch screen      
      SET @nScn = 4595
   END      
            
  
   IF @cType = 'POPULATE-OUT'      
   BEGIN      
      IF @nStep = 4
      BEGIN
      --IF @cMethod = '2'
      --BEGIN
         -- Handling transaction
         DECLARE @nTranCount INT
         SET @nTranCount = @@TRANCOUNT
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_PTLPiece_Move -- For rollback or commit only our own transaction

         -- rdtPTLPieceLog
         DECLARE @curDPL CURSOR
         SET @curDPL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Loc,DropID,CAST(UserDefine02 AS INT),SKU,RowRef,position,BatchKey
            FROM rdt.rdtPTLPieceLog WITH (NOLOCK)
            WHERE Station = @cStation
            ORDER BY DropID
         OPEN @curDPL
         FETCH NEXT FROM @curDPL INTO @cLOC,@cPalletID,@nQTY,@cSKU,@nRowRef,@cPosition,@cReceiptKey
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nQTY > 0
            BEGIN
               SELECT @cFromLoc = Loc
               FROM LOTxLOCxID WITH(NOLOCK)
               WHERE id = @cPalletID
               AND Qty > 0

               EXECUTE rdt.rdt_Move    
                  @nMobile     = @nMobile,    
                  @cLangCode   = @cLangCode,    
                  @nErrNo      = @nErrNo  OUTPUT,    
                  @cErrMsg     = @cErrMsg OUTPUT,    
                  @cSourceType = 'rdt_803PTLAssign02',    
                  @cStorerKey  = @cStorerKey,    
                  @cFacility   = @cFacility,    
                  @cFromLOC    = @cFromLoc,    
                  @cToLOC      = @cLOC, -- Final LOC    
                  @cFromID     = @cPalletID,    
                  @cToID       = '',    
                  @cSKU        = @cSKU,    
                  @nQty        = @nQTY,    
                  @nQTYAlloc   = 0,    
                  @cDropID     = '',  
                  --@cFromLOT    = @cPDLot,  
                  @nFunc       = 803
                  
               IF @nErrNo <> 0    
                  GOTO RollBackTran 
               
               UPDATE dbo.DeviceProfile
               SET Status = '0'
               WHERE storerkey = @cStorerKey
               AND DevicePosition = @cPosition
               AND DeviceID = @cStation
               
               
            EnD

            -- Update rdtPTLPieceLog
            DELETE rdt.rdtPTLPieceLog WHERE RowRef = @nRowRef
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 228801
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL LOG Fail
               GOTO RollBackTran
            END
            
            IF NOT EXISTS(SELECT 1 
                           FROM LOTxLOCxID WITH(NOLOCK)
                           WHERE StorerKey = @cStorerKey
                           AND ID = @cPalletID
                           AND (QTY - QtyAllocated - QtyPicked) > 0)
            BEGIN
               UPDATE RECEIPTDETAIL
                  SET UserDefine09 = 'Sorted'
               WHERE Receiptkey = @cReceiptKey
               AND storerkey = @cStorerKey
               AND ToId = @cPalletID               
            END
            FETCH NEXT FROM @curDPL INTO  @cLOC,@cPalletID,@nQTY,@cSKU,@nRowRef,@cPosition,@cReceiptKey
         END

         COMMIT TRAN rdt_PTLPiece_Move
         GOTO POPULATE_OUT_Quit
      
RollBackTran:
      ROLLBACK TRAN rdt_PTLPiece_Move -- Only rollback change made here
POPULATE_OUT_Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN
      --EnD
      END
   END      

         
   /***********************************************************************************************      
                                                 CHECK      
   ***********************************************************************************************/      
   IF @cType = 'CHECK'      
   BEGIN      
      -- Screen mapping            
      SET @cPalletID = @cInField01

      SELECT @cUserDefine09 = UserDefine09,
             @cReceiptKey = Receiptkey
      FROM RECEIPTDETAIL WITH(NOLOCK)
      WHERE Storerkey = @cStorerkey
      AND ToId = @cPalletID
            
      -- Get total      
      SELECT @nTotalDropID = COUNT(1) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND SourceKey <> ''      
            
      -- Check finish assign      
      IF @cPalletID = '' AND @nTotalDropID > 0      
      BEGIN      
         GOTO Quit      
      END      
            
      -- Check blank      
      IF @cPalletID = ''       
      BEGIN      
         SET @nErrNo = 228802      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pallet ID required      
         GOTO Quit      
      END      

      IF NOT EXISTS(SELECT 1       
                  FROM dbo.LOTxLOCxID WITH (NOLOCK)       
                  WHERE ID = @cPalletID
                  AND StorerKey = @cStorerKey)
      BEGIN
         SET @nErrNo = 228804      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Different storer     
         SET @cOutField01 = ''      
         GOTO Quit  
      END

      IF NOT EXISTS(SELECT 1       
                  FROM dbo.LOTxLOCxID WITH (NOLOCK)       
                  WHERE ID = @cPalletID  
                  AND   (QTY - QtyAllocated - QtyPicked) > 0)
      BEGIN
         SET @nErrNo = 228803      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid ID     
         SET @cOutField01 = ''      
         GOTO Quit  
      END
      
      
      IF EXISTS(SELECT 1
                  FROM rdt.rdtPTLPieceLog WITH(NOLOCK)
                  WHERE station <> @cStation
                  AND sourcekey = @cPalletID
                  AND StorerKey = @cStorerKey
      )
      BEGIN
         SET @nErrNo = 228809      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ID being sorted at other station      
         SET @cOutField01 = ''      
         GOTO Quit 
      END


      IF EXISTS(SELECT 1
                  FROM rdt.rdtPTLPieceLog WITH(NOLOCK)
                  WHERE station = @cStation
                  AND sourcekey <> @cPalletID
                  AND StorerKey = @cStorerKey
      )
      BEGIN
         SET @nErrNo = 228810      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Another id is sorting     
         SET @cOutField01 = ''      
         GOTO Quit 
      END

      -- Check DropID valid      
      IF NOT EXISTS( SELECT 1 FROM RECEIPTDETAIL WITH (NOLOCK) 
               WHERE StorerKey = @cStorerKey AND ToId = @cPalletID AND UserDefine09 <> 'Sorted')      
      BEGIN      
         SET @nErrNo = 228805      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad PalletID      
         SET @cOutField01 = ''      
         GOTO Quit      
      END      
         
         /**
      -- Check DropID assigned      
      IF EXISTS( SELECT 1       
         FROM rdt.rdtPTLPieceLog WITH (NOLOCK)       
         WHERE StorerKey = @cStorerKey      
            AND Method = @cMethod      
            AND SourceKey = @cDropID)      
      BEGIN      
         SET @nErrNo = 158553      
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDAssigned      
         SET @cOutField01 = ''      
         GOTO Quit      
      END      
      **/

      DECLARE @curSKU CURSOR      
      SET @curSKU = CURSOR FOR      
      SELECT Sku       
      FROM dbo.LOTxLOCxID WITH (NOLOCK)       
      WHERE ID = @cPalletID  
      AND   (QTY - QtyAllocated - QtyPicked)> 0  
      GROUP BY SKU    
      ORDER BY SKU    
      OPEN @curSKU    
      FETCH NEXT FROM @curSKU INTO @cSKU    
      WHILE @@FETCH_STATUS = 0    
      Begin
         
         IF EXISTS(SELECT 1 
                  FROM rdt.rdtPTLPieceLog Lg WITH(NOLOCK)
                  INNER JOIN dbo.DeviceProfile DP
                  ON Lg.Station = DP.DeviceID
                  AND Lg.Position = DP.DevicePosition
                  WHERE Station = @cStation
                  AND Method = @cMethod
                  AND Sku = @cSKU
                  AND Status <> '9')
         BEGIN
            SELECT TOP 1      
               @cIPAddress = Lg.IPAddress,
               @cLOC = Lg.LOC,               
               @cPosition = Lg.Position      
            FROM rdt.rdtPTLPieceLog Lg WITH (NOLOCK)
            WHERE Station = @cStation
               AND Sku = @cSKU

            -- Save assign      
            INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Loc, Position, Method, SourceKey, BatchKey, SKU,UserDefine02, DropID, StorerKey)     
            VALUES      
            (@cStation, @cIPAddress, @cLOC, @cPosition, @cMethod, @cPalletID, @cReceiptKey, @cSKU, '0', @cPalletID, @cStorerKey )    
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 228806      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
               GOTO Quit      
            END 
         END
         ELSE
         BEGIN
            SELECT TOP 1      
               @cIPAddress = DP.IPAddress,
               @cLOC = DP.LOC,
               @cPosition = DP.DevicePosition      
            FROM dbo.DeviceProfile DP WITH (NOLOCK)      
            WHERE DP.DeviceType = 'STATION'      
               AND DP.DeviceID = @cStation
               --AND Status <> '9'
               AND NOT EXISTS( SELECT 1      
                  FROM rdt.rdtPTLPieceLog Log WITH (NOLOCK)      
                  WHERE Log.Station = @cStation      
                     AND Log.Position = DP.DevicePosition)
            ORDER BY DP.LogicalPos, DP.DevicePosition  

            SET @nRowCOUNT = @@ROWCOUNT

            -- Check enuf position in station      
            IF @nRowCOUNT = 0
            BEGIN      
               SET @nErrNo = 228807      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos      
               SET @cOutField01 = ''      
               GOTO Quit      
            END    
            
            -- Save assign      
            INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Loc, Position, Method, SourceKey, BatchKey, SKU, UserDefine02, DropID, StorerKey)     
            VALUES      
            (@cStation, @cIPAddress, @cLOC, @cPosition, @cMethod, @cPalletID, @cReceiptKey, @cSKU, '0', @cPalletID, @cStorerKey )    
            IF @@ERROR <> 0      
            BEGIN      
               SET @nErrNo = 228808      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
               GOTO Quit      
            END 

         END
         


         FETCH NEXT FROM @curSKU INTO  @cSKU    
      END    
      CLOSE @curSKU    
      DEALLOCATE @curSKU  
            
          
      -- Get total      
      --SELECT @nTotalDropID = COUNT( DISTINCT SourceKey) FROM rdt.rdtPTLPieceLog WITH (NOLOCK) WHERE Station = @cStation AND Method = @cMethod AND SourceKey <> ''      
      
      -- Prepare current screen var      
      SET @cOutField01 = '' -- DropID      
      --SET @cOutField02 = CAST( @nTotalDropID AS NVARCHAR(5))      
            
      -- Stay in current screen      
      --SET @nErrNo = -1       
      
   END      
      
Quit:      
      
END      

GO