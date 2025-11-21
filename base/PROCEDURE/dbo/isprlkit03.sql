SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ispRLKIT03                                          */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Date       Rev  Author    Purposes                                   */
/* 02-08-2018 1.0  Ung       WMS-5380 Created                           */
/* 03-05-2019 1.1  Ung       WMS-5380 Fix ExternKitKey                  */
/* 09-05-2019 1.2  Ung       WMS-9094 Convert to Kit release SP         */
/************************************************************************/

CREATE PROC [dbo].[ispRLKIT03] (
   @c_KitKey         NVARCHAR(10),
   @b_success	      INT           OUTPUT, 
   @n_err	         INT           OUTPUT,
   @c_errmsg	      NVARCHAR(225) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
                              
   DECLARE @nRowRef           INT
   DECLARE @nTranCount        INT

   DECLARE @cStorerKey        NVARCHAR(15)
   DECLARE @cStatus           NVARCHAR(10)
   DECLARE @cUSRDEF3          NVARCHAR(18)
   DECLARE @cKitLineNumber    NVARCHAR(5)
   DECLARE @cNewKitLineNumber NVARCHAR(5)
   DECLARE @cSKU              NVARCHAR(20)
   DECLARE @cPackKey          NVARCHAR(10)
   DECLARE @cUOM              NVARCHAR(10)
   DECLARE @cLottable07       NVARCHAR(30)
   DECLARE @cLottable08       NVARCHAR(30)
   DECLARE @cLOT              NVARCHAR(10)
   DECLARE @cLOC              NVARCHAR(10)
   DECLARE @cID               NVARCHAR(18)
   DECLARE @nQTY_KD           INT
   DECLARE @nQTY_LLI          INT
   DECLARE @curLog CURSOR
   DECLARE @curKD  CURSOR
   DECLARE @curKit CURSOR

   DECLARE @n_continue int,  
           @n_starttcnt int

   SELECT @n_Continue = 1, @b_success = 1, @n_starttcnt = @@TRANCOUNT, @c_errmsg='', @n_err=0   

   -- Get kit info
   SELECT 
      @cStatus = Status, 
      @cUSRDEF3 = USRDEF3
   FROM Kit WITH (NOLOCK)
   WHERE KitKey = @c_KitKey

   -- Kit ready for alloc
   IF @cStatus = '0' AND      -- Open
      @cUSRDEF3 = 'PENDALLOC' 
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      
      -- Loop KitDetail (stamp LOT)
      SET @curKD = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT KitLineNumber, StorerKey, SKU, QTY, PackKey, UOM, Lottable07, Lottable08
         FROM KitDetail WITH (NOLOCK)
         WHERE KitKey = @c_KitKey
            AND Type = 'F' -- Child
            AND LOT = ''
         ORDER BY KitLineNumber
      OPEN @curKD 
      FETCH NEXT FROM @curKD INTO @cKitLineNumber, @cStorerKey, @cSKU, @nQTY_KD, @cPackKey, @cUOM, @cLottable07, @cLottable08
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Find stock
         WHILE @nQTY_KD > 0
         BEGIN
            -- Get available stock
            SELECT TOP 1 
               @cLOT = LLI.LOT, 
               @cLOC = LLI.LOC, 
               @cID = LLI.ID, 
               @nQTY_LLI = LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen
            FROM LOTxLOCxID LLI WITH (NOLOCK)
               JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
               JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
            WHERE LLI.StorerKey = @cStorerKey
               AND LLI.SKU = @cSKU
               AND LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked - LLI.QTYReplen > 0
               AND LA.Lottable07 = @cLottable07
               AND LA.Lottable08 = @cLottable08
               AND LOC.LocationFlag <> 'HOLD'
            
            IF @@ROWCOUNT = 0
            BEGIN
               SET @n_Continue = 3  
               SET @n_Err = 138251  
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' KitLineNumber: ' +  CAST( @cKitLineNumber AS NVARCHAR(5)) + ' : NO stock. (ispRLKIT03)'      
               GOTO QUIT_SP  
            END               

            -- Kit is exact match or less
            IF @nQTY_KD <= @nQTY_LLI
            BEGIN
               UPDATE KitDetail SET
                  LOT = @cLOT, 
                  LOC = @cLOC, 
                  ID = @cID, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE KitKey = @c_KitKey
                  AND KitLineNumber = @cKitLineNumber
                  AND Type = 'F' -- Child
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3  
                  SET @n_Err = 138252  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' KitLineNumber: ' +  CAST( @cKitLineNumber AS NVARCHAR(5)) + ' : Update LOTxLOCxID Fail. (ispRLKIT03)'      
                  GOTO QUIT_SP
               END
               
               -- Book the stock
               UPDATE LOTxLOCxID SET
                  QTYReplen = QTYReplen + @nQTY_KD, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME()
               WHERE LOT = @cLOT
                  AND LOC = @cLOC
                  AND ID = @cID
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3  
                  SET @n_Err = 138253  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' KitLineNumber: ' +  CAST( @cKitLineNumber AS NVARCHAR(5)) + ' : Update LOTxLOCxID Fail. (ispRLKIT03)'      
                  GOTO QUIT_SP
               END
               
               SET @nQTY_KD = 0
            END

            -- Kit have more
            IF @nQTY_KD > @nQTY_LLI
            BEGIN
               -- Get new KitLineNumber
               SELECT @cNewKitLineNumber = RIGHT( '00000' + CAST( CAST( MAX( KitLineNumber) AS INT) + 1 AS NVARCHAR(5)), 5)
               FROM KitDetail WITH (NOLOCK)
               WHERE KitKey = @c_KitKey
                  AND Type = 'F' -- Child
               
               -- Split new KitDetail to hold the balance
               INSERT INTO KitDetail (KitKey, KitLineNumber, Type, StorerKey, SKU, PackKey, UOM, Lottable07, Lottable08, ExternKitKey, ExpectedQTY, QTY)
               SELECT KitKey, @cNewKitLineNumber, Type, StorerKey, SKU, PackKey, UOM, Lottable07, Lottable08, ExternKitKey,  
                  ExpectedQTY - @nQTY_LLI, 
                  QTY - @nQTY_LLI
               FROM KitDetail WITH (NOLOCK)
               WHERE KitKey = @c_KitKey
                  AND KitLineNumber = @cKitLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3  
                  SET @n_Err = 138254  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' KitLineNumber: ' +  CAST( @cKitLineNumber AS NVARCHAR(5)) + ' : Insert KitDetail Fail. (ispRLKIT03)'      
                  GOTO QUIT_SP
               END
               
               -- Reduce original
               UPDATE KitDetail SET
                  ExpectedQTY = @nQTY_LLI, 
                  QTY = @nQTY_LLI, 
                  EditDate = GETDATE(), 
                  EditWho = SUSER_SNAME(), 
                  TrafficCop = NULL
               WHERE KitKey = @c_KitKey
                  AND KitLineNumber = @cKitLineNumber
               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3  
                  SET @n_Err = 138255  
                  SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' KitLineNumber: ' +  CAST( @cKitLineNumber AS NVARCHAR(5)) + ' : Update KitDetail Fail. (ispRLKIT03)'      
                  GOTO QUIT_SP
               END

               SET @nQTY_KD = @nQTY_KD - @nQTY_LLI
            END
         END

         FETCH NEXT FROM @curKD INTO @cKitLineNumber, @cStorerKey, @cSKU, @nQTY_KD, @cPackKey, @cUOM, @cLottable07, @cLottable08
      END

      -- Reset flag
      UPDATE Kit SET 
         USRDEF3 = '',  
         EditWho = SUSER_SNAME(), 
         EditDate = GETDATE() 
      WHERE KitKey = @c_KitKey
      IF @@ERROR <> 0
      BEGIN
         SET @n_Continue = 3  
         SET @n_Err = 138256
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ' Update Kit Fail. (ispRLKIT03)'      
         GOTO QUIT_SP
      END
   END
   ELSE
   BEGIN
      SET @n_Continue = 3  
      SET @n_Err = 131557  
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': KIT already finalized or RDT not yet close KIT (ispRLKIT03)'     
      GOTO QUIT_SP  
   END

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         ROLLBACK TRAN  
      END  
      ELSE  
      BEGIN  
         WHILE @@TRANCOUNT > @n_StartTCnt  
         BEGIN  
            COMMIT TRAN  
         END  
      END  
  
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispRLKIT03'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
END

GO