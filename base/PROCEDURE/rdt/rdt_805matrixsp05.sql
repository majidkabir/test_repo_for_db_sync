SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_805MatrixSP05                                   */  
/* Copyright      : Mearsk                                              */  
/*                                                                      */  
/* Date       Rev  Author   Purposes                                    */  
/* 03-08-2021 1.0  YeeKung    WMS-17625 created                         */  
/* 26-11-2021 1.1  James      Perf tuning (james01)                     */  
/* 16-06-2023 1.2  Ung        WMS-22703 Add Method param                */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_805MatrixSP05] (  
    @nMobile    INT  
   ,@nFunc      INT  
   ,@cLangCode  NVARCHAR( 3)  
   ,@nStep      INT   
   ,@nInputKey  INT  
   ,@cFacility  NVARCHAR( 5)  
   ,@cStorerKey NVARCHAR( 15)  
   ,@cLight     NVARCHAR( 1)  
   ,@cStation1  NVARCHAR( 10)    
   ,@cStation2  NVARCHAR( 10)    
   ,@cStation3  NVARCHAR( 10)    
   ,@cStation4  NVARCHAR( 10)    
   ,@cStation5  NVARCHAR( 10)    
   ,@cMethod    NVARCHAR( 1)
   ,@cScanID    NVARCHAR( 20)  
   ,@cSKU       NVARCHAR( 20)  
   ,@nErrNo     INT            OUTPUT  
   ,@cErrMsg    NVARCHAR( 20)  OUTPUT  
   ,@cResult01  NVARCHAR( 20)  OUTPUT  
   ,@cResult02  NVARCHAR( 20)  OUTPUT  
   ,@cResult03  NVARCHAR( 20)  OUTPUT  
   ,@cResult04  NVARCHAR( 20)  OUTPUT  
   ,@cResult05  NVARCHAR( 20)  OUTPUT  
   ,@cResult06  NVARCHAR( 20)  OUTPUT  
   ,@cResult07  NVARCHAR( 20)  OUTPUT  
   ,@cResult08  NVARCHAR( 20)  OUTPUT  
   ,@cResult09  NVARCHAR( 20)  OUTPUT  
   ,@cResult10  NVARCHAR( 20)  OUTPUT  
   ,@nNextPage  INT = NULL     OUTPUT  -- NULL = refresh current page  
 )  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @bSuccess          INT  
   DECLARE @nPTLKey           BIGINT  
   DECLARE @cStation          NVARCHAR(10)  
   DECLARE @cIPAddress        NVARCHAR(40)  
   DECLARE @cPosition         NVARCHAR(10)  
   DECLARE @nCounter          INT  
   DECLARE @cQTY              NVARCHAR(20)  
   DECLARE @nQTY              INT  
   DECLARE @cLightMode        NVARCHAR(4)  
   DECLARE @cRow              NVARCHAR(2)  
   DECLARE @cDeviceID         NVARCHAR(20)  
   DECLARE @cUserName         NVARCHAR(18)   
   DECLARE @cLoc              NVARCHAR(10)   
   DECLARE @nSumqty           INT  
   DECLARE @cDeviceIP         NVARCHAR(40)  
   DECLARE @nRecOnPage        INT  
   DECLARE @nRecCount         INT  
   DECLARE @nMaxRecOnPage     INT  
   DECLARE @nFirstRecOnPage   INT  
  
   DECLARE @tPos TABLE  
   (  
      Seq       INT IDENTITY(1,1) NOT NULL,  
      PTLKey    BIGINT,  
      Station   NVARCHAR(10),   
      IPAddress NVARCHAR(40),  
      Position  NVARCHAR(5),  
      Loc       NVARCHAR(10),   
      QTY       NVARCHAR(5)  
   )  
  
   -- Page control  
   IF @nStep = 4 -- Matrix screen  
   BEGIN  
      IF @nInputKey = 1 -- ENTER  
         SET @nNextPage = @nNextPage + 1  
        
      IF @nInputKey = 0 -- ESC  
         SET @nNextPage = @nNextPage - 1  
     
      IF @nNextPage = 0  
         GOTO Quit  
   END  
   ELSE  
      -- Other screens  
      SET @nNextPage = 1 -- Always start from 1st page  
  
   SET @nMaxRecOnPage = 8  
   SET @nFirstRecOnPage = ((@nNextPage - 1) * @nMaxRecOnPage) + 1  
   SET @nRecOnPage = 0  
   SET @nRecCount = 0  
   SET @nSumQTY = 0  
        
   -- Get login info  
   SELECT @cUserName = UserName FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile     
  
   -- Get user info  
   SELECT @cLightMode = DefaultLightColor FROM rdt.rdtUser WITH (NOLOCK) WHERE UserName = @cUserName  
  
   -- Loop each PTL tran, insert POS with QTY  
   DECLARE @curPTLTran CURSOR  
   SET @curPTLTran = CURSOR FOR  
      SELECT T.PTLKey, T.IPAddress, T.DevicePosition, T.ExpectedQTY, T.Loc   
      FROM PTL.PTLTran T WITH (NOLOCK)  
         --JOIN dbo.DeviceProfile D WITH (NOLOCK) ON (D.DeviceID = T.DeviceID AND D.DevicePosition = T.DevicePosition AND D.StorerKey = T.StorerKey AND D.DeviceType = T.PTLType)   
      WHERE T.DeviceID IN (@cStation1, @cStation2, @cStation3, @cStation4, @cStation5)  
         --AND D.DeviceType = 'STATION'  
         --AND D.DeviceID <> ''  
         AND T.DropID = @cScanID  
         AND T.StorerKey = @cStorerKey  
         AND T.SKU = @cSKU  
         AND T.Status <> '9' -- Due to light on, set PTLTran.Status = 1  
      ORDER BY t.loc 
      --ORDER BY D.LogicalPOS, D.IPAddress, D.DevicePosition  
     
   OPEN @curPTLTran  
   FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY, @cLoc   
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @nRecCount = @nRecCount + 1  
  
      IF @nRecCount >= @nFirstRecOnPage AND -- Reach 1st record of the page  
         @nRecOnPage < @nMaxRecOnPage       -- Not yet fill up full page  
      BEGIN  
         INSERT INTO @tPos (PTLKey, Station, IPAddress, Position, Loc, QTY)  
         VALUES ( @nPTLKey, @cStation1 , @cDeviceIP , @cPosition, @cLoc , @nQTY)  
        
         SET @nRecOnPage = @nRecOnPage + 1  
      END  
        
      SET @nSumQTY =  @nSumQTY + @nQTY  
      FETCH NEXT FROM @curPTLTran INTO @nPTLKey, @cIPAddress, @cPosition, @nQTY, @cLoc   
   END  
  
   -- Exit matrix screen  
   IF NOT EXISTS( SELECT TOP 1 1 FROM @tPos)  
      SET @nNextPage = 0  
  
   SET @cResult01 = ''  
   SET @cResult02 = ''  
   SET @cResult03 = ''  
   SET @cResult04 = ''  
   SET @cResult05 = ''  
   SET @cResult06 = ''  
   SET @cResult07 = ''  
   SET @cResult08 = ''  
   SET @cResult09 = ''  
   SET @cResult10 = 'Enter for next Scn'  
  
   -- 2nd line, start listing  
   SET @nCounter = 1  
  
   -- Loop light position  
   DECLARE @curLightPos CURSOR  
   SET @curLightPos = CURSOR FOR  
      SELECT PTLKey, Station, IPAddress, Position, Loc, QTY  
      FROM @tPos  
      WHERE Qty > 0   
      ORDER BY Seq  
   OPEN @curLightPos  
   FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @cLoc, @nQty  
   WHILE @@FETCH_STATUS = 0  
   BEGIN  
      SET @cQTY = @cPosition + '-' + CAST( @nQty AS NVARCHAR( 5))  
  
      -- Calc which row to write  
      DECLARE @nWriteRow INT  
      SET @nWriteRow = @nCounter  
  
      -- Write to screen  
      -- IF @nWriteRow =  1 SET @cResult01 = @cResult01 + @cQTY ELSE    
      IF @nWriteRow =  1 SET @cResult01 = @cResult01 + @cQTY ELSE   
      IF @nWriteRow =  2 SET @cResult02 = @cResult02 + @cQTY ELSE   
      IF @nWriteRow =  3 SET @cResult03 = @cResult03 + @cQTY ELSE   
      IF @nWriteRow =  4 SET @cResult04 = @cResult04 + @cQTY ELSE   
      IF @nWriteRow =  5 SET @cResult05 = @cResult05 + @cQTY ELSE   
      IF @nWriteRow =  6 SET @cResult06 = @cResult06 + @cQTY ELSE   
      IF @nWriteRow =  7 SET @cResult07 = @cResult07 + @cQTY ELSE   
      IF @nWriteRow =  8 SET @cResult08 = @cResult08 + @cQTY ELSE   
      IF @nWriteRow =  9 SET @cResult09 = @cResult09 + @cQTY  
  
      SET @nCounter = @nCounter + 1  
      FETCH NEXT FROM @curLightPos INTO @nPTLKey, @cStation, @cIPAddress, @cPosition, @cLoc, @nQty  
   END  
  
Quit:  
  
END  

GO