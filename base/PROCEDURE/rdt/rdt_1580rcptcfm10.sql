SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1580RcptCfm10                                      */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date       Rev  Author  Purposes                                        */
/* 2018-11-07 1.0  Ung     WMS-6864 Created                                */
/***************************************************************************/
CREATE PROC [RDT].[rdt_1580RcptCfm10](
   @nFunc          INT,
   @nMobile        INT,
   @cLangCode      NVARCHAR( 3),
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT, 
   @cStorerKey     NVARCHAR( 15),
   @cFacility      NVARCHAR( 5),
   @cReceiptKey    NVARCHAR( 10),
   @cPOKey         NVARCHAR( 10),
   @cToLOC         NVARCHAR( 10),
   @cToID          NVARCHAR( 18),
   @cSKUCode       NVARCHAR( 20),
   @cSKUUOM        NVARCHAR( 10),
   @nSKUQTY        INT,
   @cUCC           NVARCHAR( 20),
   @cUCCSKU        NVARCHAR( 20),
   @nUCCQTY        INT,
   @cCreateUCC     NVARCHAR( 1),
   @cLottable01    NVARCHAR( 18),
   @cLottable02    NVARCHAR( 18),
   @cLottable03    NVARCHAR( 18),
   @dLottable04    DATETIME,
   @dLottable05    DATETIME,
   @nNOPOFlag      INT,
   @cConditionCode NVARCHAR( 10),
   @cSubreasonCode NVARCHAR( 10), 
   @cReceiptLineNumber NVARCHAR( 5) OUTPUT, 
   @cSerialNo      NVARCHAR( 30) = '', 
   @nSerialQTY     INT = 0, 
   @nBulkSNO       INT = 0,
   @nBulkSNOQTY    INT = 0
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cMethod     NVARCHAR(1)
   DECLARE @cStation    NVARCHAR(10)
   DECLARE @cPosition   NVARCHAR(10)
   DECLARE @cItemClass  NVARCHAR(10)
   DECLARE @cSUSR3      NVARCHAR(18)
   DECLARE @cIPAddress  NVARCHAR(40)

   SET @cStation = ''
   SET @cPosition = ''
   SET @cItemClass = ''
   SET @cSUSR3 = ''

   -- Get ASN info
   SELECT 
      @cMethod = UserDefine01, 
      @cStation = UserDefine02
   FROM Receipt WITH (NOLOCK) 
   WHERE ReceiptKey = @cReceiptKey

   -- Check sort valid
   IF @cMethod NOT IN ('1', '2', '3')
   BEGIN
      SET @nErrNo = 131601
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --BadSortMethod
      GOTO Quit
   END
   
   -- Check station valid
   IF NOT EXISTS( SELECT TOP 1 1 
      FROM DeviceProfile WITH (NOLOCK)
      WHERE DeviceID = @cStation
         AND DeviceType = 'STATION'
         AND DeviceID <> '')
   BEGIN
      SET @nErrNo = 131602
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidStation
      GOTO Quit
   END
   
   -- Assign BY SKU
   IF @cMethod = '1'
   BEGIN
      -- Get assigned LOC with SKU
      SELECT @cPosition = Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station = @cStation
         AND SKU = @cSKUCode
   END

   -- Assign by material
   ELSE IF @cMethod = '2'
   BEGIN
      -- Get SKU info
      SELECT @cItemClass = ItemClass FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKUCode 
      
      -- Get assigned LOC with ItemClass
      SELECT @cPosition = Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station = @cStation
         AND ItemClass = @cItemClass
   END
   
   -- Assign by CGD (Category, Gender and Division)
   ELSE IF @cMethod = '3'
   BEGIN
      -- Get SKU info
      SELECT @cSUSR3 = SUSR3 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKUCode 
      
      -- Get assigned LOC with SUSR3
      SELECT @cPosition = Position
      FROM rdt.rdtPTLStationLog WITH (NOLOCK)
      WHERE Station = @cStation
         AND UserDefine01 = @cSUSR3
   END
   
   -- Assign position
   IF @cPosition = ''
   BEGIN
      -- Get position not yet assign
      SELECT TOP 1 
         @cIPAddress = DP.IPAddress, 
         @cPosition = DP.DevicePosition
      FROM DeviceProfile DP WITH (NOLOCK)
         LEFT JOIN rdt.rdtPTLStationLog L WITH (NOLOCK) ON (DP.DeviceID = L.Station AND DP.IPAddress = L.IPAddress AND DP.DevicePosition = L.Position)
      WHERE DeviceID = @cStation
         AND DeviceType = 'STATION'
         AND DeviceID <> ''
         AND Position IS NULL
      ORDER BY DP.DeviceID, DP.IPAddress, DP.DevicePosition

      IF @cPosition = ''
      BEGIN
         SET @nErrNo = 131603
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoMorePosition
         GOTO Quit
      END
      
      -- Save assign
      INSERT INTO rdt.rdtPTLStationLog (Station, IPAddress, Position, CartonID, Method, StorerKey, SKU, ItemClass, UserDefine01)
      VALUES (@cStation, @cIPAddress, @cPosition, @cPosition, @cMethod, @cStorerKey, @cSKUCode, @cItemClass, @cSUSR3)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 131604
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO Quit
      END
   END

   EXEC rdt.rdt_Receive    
      @nFunc          = @nFunc,
      @nMobile        = @nMobile,
      @cLangCode      = @cLangCode,
      @nErrNo         = @nErrNo  OUTPUT,
      @cErrMsg        = @cErrMsg OUTPUT,
      @cStorerKey     = @cStorerKey,
      @cFacility      = @cFacility,
      @cReceiptKey    = @cReceiptKey,
      @cPOKey         = @cPOKey,
      @cToLOC         = @cToLOC,
      @cToID          = @cTOID,
      @cSKUCode       = @cSKUCode,
      @cSKUUOM        = @cSKUUOM,
      @nSKUQTY        = @nSKUQTY,
      @cUCC           = @cUCC,
      @cUCCSKU        = @cUCCSKU,
      @nUCCQTY        = @nUCCQTY,
      @cCreateUCC     = @cCreateUCC,
      @cLottable01    = @cLottable01,
      @cLottable02    = @cLottable02,   
      @cLottable03    = @cLottable03,
      @dLottable04    = @dLottable04,
      @dLottable05    = @dLottable05,
      @nNOPOFlag      = @nNOPOFlag,
      @cConditionCode = @cConditionCode,
      @cSubreasonCode = @cSubreasonCode, 
      @cReceiptLineNumberOutput = @cReceiptLineNumber OUTPUT

   IF @nErrNo <> 0
      GOTO Quit

   -- Show position   
   DECLARE @cMsg1 NVARCHAR(20)   
   SET @nErrNo = 131605
   SET @cMsg1 = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
   SET @cMsg1 = RTRIM( @cMsg1) + ' '+ @cPosition
   EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cMsg1  
   SET @nErrNo = 0  
   
Quit:
   
END

GO