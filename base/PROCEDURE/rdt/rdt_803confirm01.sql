SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_803Confirm01                                    */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/*                     Ace Turtle                                       */      
/* Date       Rev  Author   Purposes                                    */      
/* 2022-11-01 1.0  JHU151    FCR-650 Created                            */ 
/************************************************************************/  
  
CREATE   PROC rdt.rdt_803Confirm01 (  
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
   DECLARE @nQTY              INT
   DECLARE @nSortedQTY        INT
  
   DECLARE @cUserDefine02     NVARCHAR(30)
   DECLARE @cPalletID         NVARCHAR(20)
   DECLARE @cLOC              NVARCHAR(10)
   DECLARE @cReceiptKey       NVARCHAR(10)
   DECLARE @nRowRef           INT
   
   -- get the lastest pallet info
   SELECT TOP 1
      --@cUserDefine02 = Lg.UserDefine02,
      @cPalletID = Lg.DropID,
      --@cPosition = Lg.Position,
      @nRowRef = Lg.RowRef
   FROM rdt.rdtPTLPieceLog Lg WITH(NOLOCK)
   INNER JOIN dbo.DeviceProfile DP
   ON Lg.Station = DP.DeviceID
   AND Lg.Position = DP.DevicePosition
   WHERE Lg.method = @cMethod
   --AND Position = @cPosition
   AND Lg.Station = @cStation
   --AND Lg.Sku = @cSKU
   --AND Lg.Status <> '9' -- Full
   ORDER BY RowRef DESC


   SELECT @nQTY = QTY - QtyAllocated - QtyPicked
   FROM LOTxLOCxID WITH(NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND ID = @cPalletID
   AND SKU = @cSKU

   SELECT
      @nSortedQTY = SUM(CAST(ISNULL(Lg.UserDefine02,'0') AS INT))
   FROM rdt.rdtPTLPieceLog Lg WITH(NOLOCK)
   WHERE Lg.method = @cMethod
   AND DropID = @cPalletID
   AND Lg.Station = @cStation
   AND Lg.Sku = @cSKU

   IF @nQTY = 0 OR @nQTY <= @nSortedQTY
   BEGIN
      SET @nErrNo = 228651      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No QTY to move      
      GOTO Quit   
   END


   SELECT TOP 1
      @cUserDefine02 = Lg.UserDefine02,
      @cPosition = Lg.Position,
      @nRowRef = Lg.RowRef
   FROM rdt.rdtPTLPieceLog Lg WITH(NOLOCK)
   INNER JOIN dbo.DeviceProfile DP
   ON Lg.Station = DP.DeviceID
   AND Lg.Position = DP.DevicePosition
   WHERE Lg.method = @cMethod
   AND Lg.DropID = @cPalletID
   AND Lg.Station = @cStation
   AND Lg.Sku = @cSKU
   AND DP.Status <> '9' -- Full
   ORDER BY RowRef DESC

   IF @nRowRef > 0
   BEGIN
      IF ISNULL(@cUserDefine02,'') = ''
      BEGIN
         SET @cUserDefine02 = '1'
      END
      ELSE
      BEGIN
         SET @cUserDefine02 = CAST(CAST(@cUserDefine02 AS INT) + 1 AS NVARCHAR(30))
      END
         
      UPDATE rdt.rdtPTLPieceLog
      SET UserDefine02 = @cUserDefine02
      WHERE RowRef = @nRowRef
   END
   ELSE -- assign new position
   BEGIN
      SELECT @cReceiptKey = Receiptkey
      FROM RECEIPTDETAIL WITH(NOLOCK)
      WHERE Storerkey = @cStorerkey
      AND ToId = @cPalletID

      -- same sku in other pallet
      SELECT TOP 1
         @cUserDefine02 = Lg.UserDefine02,
         @cPosition = Lg.Position,
         @cIPAddress = Lg.IPAddress,
         @cLOC = Lg.LOC,
         @nRowRef = Lg.RowRef
      FROM rdt.rdtPTLPieceLog Lg WITH(NOLOCK)
      INNER JOIN dbo.DeviceProfile DP
      ON Lg.Station = DP.DeviceID
      AND Lg.Position = DP.DevicePosition
      WHERE Lg.method = @cMethod
      --AND Lg.DropID = @cPalletID
      AND Lg.Station = @cStation
      AND Lg.Sku = @cSKU
      AND DP.Status <> '9' -- Full
      ORDER BY RowRef DESC

      IF @nRowRef > 0
      BEGIN
         -- Save assign      
         INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Loc, Position, Method, SourceKey, BatchKey, SKU,UserDefine02, DropID, StorerKey)     
         VALUES      
         (@cStation, @cIPAddress, @cLOC, @cPosition, @cMethod, @cPalletID, @cReceiptKey, @cSKU, '0', @cPalletID, @cStorerKey)    
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 228652      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
            GOTO Quit      
         END 
      END
      ELSE
      BEGIN
         -- get empty position
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

         -- Check enuf position in station      
         IF @@ROWCOUNT = 0
         BEGIN      
            SET @nErrNo = 228653      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not enuf Pos      
            --SET @cOutField01 = ''      
            GOTO Quit      
         END    
         
         -- Save assign      
         INSERT INTO rdt.rdtPTLPieceLog (Station, IPAddress, Loc, Position, Method, SourceKey, BatchKey, SKU, UserDefine02, DropID, StorerKey)     
         VALUES      
         (@cStation, @cIPAddress, @cLOC, @cPosition, @cMethod, @cPalletID, @cReceiptKey, @cSKU, '0', @cPalletID, @cStorerKey )    
         IF @@ERROR <> 0      
         BEGIN      
            SET @nErrNo = 228654      
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log fail      
            GOTO Quit      
         END
      END
   END

   SET @cResult01 = 'Move to'
   SET @cResult02 = @cPosition
   SET @cResult03 = '' 
   SET @cResult04 = '' 
   SET @cResult05 = '' 
   SET @cResult06 = '' 
   SET @cResult07 = '' 
   SET @cResult08 = '' 
   SET @cResult09 = ''  
   SET @cResult10 = '' 
Quit:   
END


GO