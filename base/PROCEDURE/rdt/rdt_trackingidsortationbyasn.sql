SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_TrackingIDSortationByASN                        */    
/* Copyright      : IDS                                                 */    
/*                                                                      */    
/* Called from: rdtfnc_TrackingIDSortationByASN                         */    
/*                                                                      */    
/* Purpose: Insert TrackingID                                           */    
/*                                                                      */    
/* Modifications log:                                                   */    
/* Date        Rev  Author   Purposes                                   */    
/* 2020-03-24  1.0  James    WMS-12432. Created                         */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_TrackingIDSortationByASN] (    
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cFacility        NVARCHAR( 5),
   @cStorerKey       NVARCHAR( 15),
   @cReceiptKey      NVARCHAR( 10),
   @cPOKey           NVARCHAR( 10),
   @cRefNo           NVARCHAR( 20),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cParentTrackID   NVARCHAR( 20),
   @cChildTrackID    NVARCHAR( 1000),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cType            NVARCHAR( 20),
   @nErrNo           INT          OUTPUT,    
   @cErrMsg          NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max    
) AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   DECLARE @cReceiveASN    NVARCHAR( 1)
   DECLARE @cTrackingIDKey NVARCHAR( 10)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cSKUUOM        NVARCHAR( 10)
   DECLARE @nTranCount     INT
   DECLARE @nCaseCnt       INT
   DECLARE @nRowCount      INT
   DECLARE @bSuccess       INT
   DECLARE @curClosePlt    CURSOR
   DECLARE @cLottable01    NVARCHAR( 18) 
   DECLARE @cLottable02    NVARCHAR( 18) 
   DECLARE @cLottable03    NVARCHAR( 18) 
   DECLARE @dLottable04    DATETIME      
   DECLARE @dLottable05    DATETIME      
   DECLARE @cLottable06    NVARCHAR( 30) 
   DECLARE @cLottable07    NVARCHAR( 30) 
   DECLARE @cLottable08    NVARCHAR( 30) 
   DECLARE @cLottable09    NVARCHAR( 30) 
   DECLARE @cLottable10    NVARCHAR( 30) 
   DECLARE @cLottable11    NVARCHAR( 30) 
   DECLARE @cLottable12    NVARCHAR( 30) 
   DECLARE @dLottable13    DATETIME      
   DECLARE @dLottable14    DATETIME      
   DECLARE @dLottable15    DATETIME
   DECLARE @nNOPOFlag      INT
   DECLARE @cConditionCode NVARCHAR( 10) = ''     
   DECLARE @cReceiptLineNumberOutput NVARCHAR( 5)
   DECLARE @cPosition      NVARCHAR( 10)
   

   SET @cReceiveASN = rdt.RDTGetConfig( @nFunc, 'ReceiveASN', @cStorerKey)        

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_TrackingIDSortationByASN  
   
   SELECT @nCaseCnt = PACK.CaseCnt
   FROM dbo.SKU SKU WITH (NOLOCK)
   JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
   WHERE SKU.StorerKey = @cStorerKey
   AND   SKU.Sku = @cSKU

   IF @cType = 'NEW'
   BEGIN
      SELECT @cPosition = SUBSTRING( O_FIELD15, 6, 2)
      FROM rdt.RDTMOBREC WITH (nolock)
      WHERE Mobile = @nMobile
      
      INSERT INTO dbo.TrackingID ( TrackingID, StorerKey, SKU, UOM, QTY, [Status], ParentTrackingID, ReceiptKey, DropID, Facility, UserDefine01) VALUES
      ( @cChildTrackID, @cStorerKey, @cSKU, '6', @nCaseCnt, '0', @cParentTrackID, @cReceiptKey, @cID, @cFacility, @cPosition)
      
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 150051
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- INS TRACKID ERR
         GOTO RollBackTran
      END
   
      IF @cReceiveASN = '1'
      BEGIN
         SELECT TOP 1
                @cSKUUOM = UOM,
                @cLottable01   = Lottable01,
                @cLottable02   = Lottable02,
                @cLottable03   = Lottable03,
                @dLottable04   = Lottable04,
                @dLottable05   = NULL,
                @cLottable06   = Lottable06,
                @cLottable07   = Lottable07,
                @cLottable08   = Lottable08,
                @cLottable09   = Lottable09,
                @cLottable10   = Lottable10,
                @cLottable11   = Lottable11,
                @cLottable12   = Lottable12,
                @dLottable13   = Lottable13,
                @dLottable14   = Lottable14,
                @dLottable15   = Lottable15
         FROM dbo.RECEIPTDETAIL WITH (NOLOCK)
         WHERE ReceiptKey = @cReceiptKey
         AND   Sku = @cSKU
         ORDER BY 1
      
         SET @nNOPOFlag = CASE WHEN @cPOkey = 'NOPO' THEN 1 ELSE 0 END
         
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
            @cToLOC        = @cLOC,
            @cToID         = @cID,
            @cSKUCode      = @cSKU,
            @cSKUUOM       = @cSKUUOM,
            @nSKUQTY       = @nCaseCnt,
            @cUCC          = '',
            @cUCCSKU       = '',
            @nUCCQTY       = '',
            @cCreateUCC    = '',
            @cLottable01   = @cLottable01,
            @cLottable02   = @cLottable02,
            @cLottable03   = @cLottable03,
            @dLottable04   = @dLottable04,
            @dLottable05   = NULL,
            @cLottable06   = @cLottable06,
            @cLottable07   = @cLottable07,
            @cLottable08   = @cLottable08,
            @cLottable09   = @cLottable09,
            @cLottable10   = @cLottable10,
            @cLottable11   = @cLottable11,
            @cLottable12   = @cLottable12,
            @dLottable13   = @dLottable13,
            @dLottable14   = @dLottable14,
            @dLottable15   = @dLottable15,
            @nNOPOFlag     = @nNOPOFlag,
            @cConditionCode = @cConditionCode,
            @cSubreasonCode = '', 
            @cReceiptLineNumberOutput = @cReceiptLineNumberOutput OUTPUT   
         
            IF @nErrNo <> 0
               GOTO RollBackTran
      END
   END

   IF @cType = 'CLOSEASN'
   BEGIN
      IF @cReceiveASN = '1'
      BEGIN
         EXEC dbo.ispFinalizeReceipt
             @c_ReceiptKey        = @cReceiptKey
            ,@b_Success           = @bSuccess   OUTPUT
            ,@n_err               = @nErrNo     OUTPUT
            ,@c_ErrMsg            = @cErrMsg    OUTPUT
            ,@c_ReceiptLineNumber = @cReceiptLineNumberOutput

         IF @nErrNo <> 0 OR @bSuccess = 0
         BEGIN
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')
            GOTO RollBackTran
         END
      END
      ELSE
      BEGIN
         SET @nErrNo = 150052
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- ReceiveASN Off
         GOTO RollBackTran
      END
   END

   IF @cType = 'RELEASELOC'
   BEGIN
      DECLARE @cLoc2Close  NVARCHAR( 10)
      DECLARE @nScanned    INT
      DECLARE @nPallet     INT
      
      SELECT @cLoc2Close = I_Field04
      FROM RDT.RDTMOBREC WITH (NOLOCK)
      WHERE Mobile = @nMobile
      
      DECLARE @curCloseLoc CURSOR
      SET @curCloseLoc = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
      SELECT ParentTrackingID, SKU 
      FROM dbo.TrackingID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
      AND   UserDefine01 = @cLoc2Close
      AND   [Status] = '0'
      AND   Facility = @cFacility
      AND   ReceiptKey = @cReceiptKey
      AND   UserDefine02 = ''
      GROUP BY ParentTrackingID, SKU
      ORDER BY ParentTrackingID
      OPEN @curCloseLoc
      FETCH NEXT FROM @curCloseLoc INTO @cParentTrackID, @cSKU 
      WHILE @@FETCH_STATUS = 0
      BEGIN
         SET @nScanned = 0
         SELECT @nScanned = ISNULL( SUM( Qty), 0)
         FROM dbo.TrackingID WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   UserDefine01 = @cLoc2Close
         AND   [Status] = '0'
         AND   Facility = @cFacility
         AND   ReceiptKey = @cReceiptKey
         AND   ParentTrackingID = @cParentTrackID

         SELECT @nPallet = PACK.Pallet
         FROM dbo.SKU SKU WITH (NOLOCK)
         JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
         WHERE SKU.StorerKey = @cStorerKey
         AND   SKU.Sku = @cSKU

         IF @nScanned <> @nPallet
         BEGIN
            SET @nErrNo = 150053
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Plt Not Full
            GOTO RollBackTran
         END
         ELSE
         BEGIN
            DECLARE @curClose CURSOR
            SET @curClose = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT TrackingIDKey
            FROM dbo.TrackingID WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey
            AND   UserDefine01 = @cLoc2Close
            AND   [Status] = '0'
            AND   Facility = @cFacility
            AND   ReceiptKey = @cReceiptKey
            AND   ParentTrackingID = @cParentTrackID
            OPEN @curClose
            FETCH NEXT FROM @curClose INTO @cTrackingIDKey
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.TrackingID SET 
                  UserDefine01 = '', 
                  UserDefine02 = 'LOC ' + RTRIM( @cLoc2Close) + ' PALLET FULL',
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE TrackingIDKey = @cTrackingIDKey

               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 150054
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- RELEASE ERR
                  GOTO RollBackTran
               END
      
               FETCH NEXT FROM @curClose INTO @cTrackingIDKey
            END
         END

         FETCH NEXT FROM @curCloseLoc INTO @cParentTrackID, @cSKU
      END
   END
   
   GOTO Quit  
  
   RollBackTran:  
      ROLLBACK TRAN rdt_TrackingIDSortationByASN  
  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN rdt_TrackingIDSortationByASN  

Fail:    
END    

GO